extends RefCounted

const SaveRepositoryScript: GDScript = preload("res://scripts/save_repository.gd")

const TEST_ROOT: String = "/tmp/proto-isometric-ww03-repository.json"
const LEGACY_FIXTURE: String = "res://test/fixtures/save_schema_2_relay_true.json"


static func evaluate(
	world: RefCounted, run_snapshot: Dictionary, profile_snapshot: Dictionary
) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_clear_artifacts(TEST_ROOT)
	var repository: RefCounted = _repository(TEST_ROOT, world)
	_add_case(cases, "schema-3 repository configures", repository != null)
	_add_case(
		cases,
		"empty repository returns no state",
		(
			(repository.call("load_state") as Dictionary).is_empty()
			and repository.call("get_status") == &"empty"
		),
	)
	_test_commit_and_rotation(cases, repository, world, run_snapshot, profile_snapshot)
	_test_schema_three_module_default(cases, world, run_snapshot, profile_snapshot)
	_test_legacy_load_and_commit(cases, world)
	_test_primary_recovery(cases, world, run_snapshot, profile_snapshot)
	_test_backup_selection(cases, world, run_snapshot, profile_snapshot)
	_test_interrupted_temp(cases, world, run_snapshot, profile_snapshot)
	_test_future_quarantine(cases, world, run_snapshot, profile_snapshot)
	_test_corrupt_and_oversized(cases, world)
	_test_atomic_rejection(cases, world, run_snapshot, profile_snapshot)
	_clear_artifacts(TEST_ROOT)
	return cases


static func _test_commit_and_rotation(
	cases: Array[Dictionary],
	repository: RefCounted,
	world: RefCounted,
	run_snapshot: Dictionary,
	profile_snapshot: Dictionary,
) -> void:
	var world_snapshot: Dictionary = world.call("make_snapshot") as Dictionary
	_add_case(
		cases,
		"first schema-3 save commits",
		bool(repository.call("save_state", world_snapshot, run_snapshot, profile_snapshot)),
	)
	var first: Dictionary = _read_json(TEST_ROOT)
	_add_case(
		cases,
		"fresh save has the complete schema-3 envelope",
		(
			int(first.get("save_format_version", -1)) == 3
			and first.has("metadata")
			and first.has("world")
			and first.has("active_run")
			and first.has("profile")
			and int((first["metadata"] as Dictionary)["write_sequence"]) == 1
		),
	)
	_add_case(
		cases,
		"second schema-3 save rotates a retained backup",
		(
			bool(repository.call("save_state", world_snapshot, run_snapshot, profile_snapshot))
			and FileAccess.file_exists(TEST_ROOT + ".bak")
		),
	)
	var loaded: Dictionary = repository.call("load_state") as Dictionary
	_add_case(
		cases,
		"primary reload selects the highest committed sequence",
		(
			int((loaded[&"metadata"] as Dictionary)[&"write_sequence"]) == 2
			and repository.call("get_status") == &"loaded"
		),
	)
	_add_case(
		cases,
		"schema-3 reload preserves world run and profile sections",
		(
			loaded[&"world"] == world_snapshot
			and loaded[&"active_run"] == run_snapshot
			and loaded[&"profile"] == profile_snapshot
		),
	)


static func _test_schema_three_module_default(
	cases: Array[Dictionary],
	world: RefCounted,
	run_snapshot: Dictionary,
	profile_snapshot: Dictionary,
) -> void:
	_clear_artifacts(TEST_ROOT)
	var repository: RefCounted = _repository(TEST_ROOT, world)
	repository.call("save_state", world.call("make_snapshot"), run_snapshot, profile_snapshot)
	var legacy_envelope: Dictionary = _read_json(TEST_ROOT)
	var legacy_run: Dictionary = legacy_envelope[&"active_run"] as Dictionary
	legacy_run.erase(&"active_module_ids")
	legacy_envelope[&"active_run"] = legacy_run
	_write_text(TEST_ROOT, JSON.stringify(legacy_envelope))
	var reopened: RefCounted = _repository(TEST_ROOT, world)
	var loaded: Dictionary = reopened.call("load_state") as Dictionary
	_add_case(
		cases,
		"pre-module schema-three run defaults to Worn Plates",
		(
			not loaded.is_empty()
			and (
				"module.worn_plates"
				in ((loaded[&"active_run"] as Dictionary)[&"active_module_ids"] as Array)
			)
		),
	)


static func _test_legacy_load_and_commit(cases: Array[Dictionary], world: RefCounted) -> void:
	_clear_artifacts(TEST_ROOT)
	var legacy_text: String = _read_text(LEGACY_FIXTURE)
	_write_text(TEST_ROOT, legacy_text)
	var repository: RefCounted = _repository(TEST_ROOT, world)
	var migrated: Dictionary = repository.call("load_state") as Dictionary
	_add_case(
		cases,
		"repository loads schema 2 as detached migrated state",
		(
			not migrated.is_empty()
			and repository.call("get_status") == &"migrated"
			and int((migrated[&"metadata"] as Dictionary)[&"migration_source"]) == 2
		),
	)
	_add_case(
		cases,
		"legacy primary remains untouched until a normal save",
		_read_text(TEST_ROOT) == legacy_text and not FileAccess.file_exists(TEST_ROOT + ".bak"),
	)
	var committed: bool = bool(
		repository.call(
			"save_state", migrated[&"world"], migrated[&"active_run"], migrated[&"profile"]
		)
	)
	var reloaded: Dictionary = repository.call("load_state") as Dictionary
	_add_case(
		cases,
		"migrated state commits and reloads canonically as schema 3",
		(
			committed
			and int(reloaded[&"save_format_version"]) == 3
			and reloaded[&"world"] == migrated[&"world"]
			and reloaded[&"active_run"] == migrated[&"active_run"]
			and reloaded[&"profile"] == migrated[&"profile"]
			and _read_text(TEST_ROOT + ".bak") == legacy_text
		),
	)


static func _test_primary_recovery(
	cases: Array[Dictionary],
	world: RefCounted,
	run_snapshot: Dictionary,
	profile_snapshot: Dictionary,
) -> void:
	_clear_artifacts(TEST_ROOT)
	var repository: RefCounted = _repository(TEST_ROOT, world)
	var world_snapshot: Dictionary = world.call("make_snapshot") as Dictionary
	repository.call("save_state", world_snapshot, run_snapshot, profile_snapshot)
	repository.call("save_state", world_snapshot, run_snapshot, profile_snapshot)
	_write_text(TEST_ROOT, "{corrupt primary")
	var recovered: Dictionary = repository.call("load_state") as Dictionary
	_add_case(
		cases,
		"corrupt primary recovers the valid backup",
		(
			not recovered.is_empty()
			and int((recovered[&"metadata"] as Dictionary)[&"write_sequence"]) == 1
			and repository.call("get_selected_source") == TEST_ROOT + ".bak"
			and repository.call("get_status") == &"recovered"
		),
	)
	_add_case(
		cases,
		"corrupt primary is quarantined rather than erased",
		(
			(repository.call("get_quarantine_paths") as Array).size() == 1
			and FileAccess.file_exists((repository.call("get_quarantine_paths") as Array)[0])
		),
	)
	_add_case(
		cases,
		"recovered state rewrites only on the next committed save",
		(
			not FileAccess.file_exists(TEST_ROOT)
			and bool(repository.call("save_state", world_snapshot, run_snapshot, profile_snapshot))
			and FileAccess.file_exists(TEST_ROOT)
		),
	)


static func _test_backup_selection(
	cases: Array[Dictionary],
	world: RefCounted,
	run_snapshot: Dictionary,
	profile_snapshot: Dictionary,
) -> void:
	_clear_artifacts(TEST_ROOT)
	var repository: RefCounted = _repository(TEST_ROOT, world)
	var world_snapshot: Dictionary = world.call("make_snapshot") as Dictionary
	repository.call("save_state", world_snapshot, run_snapshot, profile_snapshot)
	var primary: Dictionary = _read_json(TEST_ROOT)
	var backup: Dictionary = primary.duplicate(true)
	(primary["metadata"] as Dictionary)["write_sequence"] = 4
	(backup["metadata"] as Dictionary)["write_sequence"] = 9
	_write_json(TEST_ROOT, primary)
	_write_json(TEST_ROOT + ".bak", backup)
	var selected: Dictionary = repository.call("load_state") as Dictionary
	_add_case(
		cases,
		"valid backup with higher sequence wins deterministically",
		(
			int((selected[&"metadata"] as Dictionary)[&"write_sequence"]) == 9
			and repository.call("get_selected_source") == TEST_ROOT + ".bak"
		),
	)


static func _test_interrupted_temp(
	cases: Array[Dictionary],
	world: RefCounted,
	run_snapshot: Dictionary,
	profile_snapshot: Dictionary,
) -> void:
	_clear_artifacts(TEST_ROOT)
	var repository: RefCounted = _repository(TEST_ROOT, world)
	var world_snapshot: Dictionary = world.call("make_snapshot") as Dictionary
	repository.call("save_state", world_snapshot, run_snapshot, profile_snapshot)
	var temporary: Dictionary = _read_json(TEST_ROOT)
	(temporary["metadata"] as Dictionary)["write_sequence"] = 999
	_write_json(TEST_ROOT + ".tmp", temporary)
	var loaded: Dictionary = repository.call("load_state") as Dictionary
	_add_case(
		cases,
		"uncommitted temporary save never outranks primary",
		(
			int((loaded[&"metadata"] as Dictionary)[&"write_sequence"]) == 1
			and repository.call("get_selected_source") == TEST_ROOT
		),
	)
	_add_case(
		cases,
		"interrupted temporary save is quarantined diagnostically",
		(
			not FileAccess.file_exists(TEST_ROOT + ".tmp")
			and (repository.call("get_quarantine_paths") as Array).size() == 1
		),
	)


static func _test_future_quarantine(
	cases: Array[Dictionary],
	world: RefCounted,
	run_snapshot: Dictionary,
	profile_snapshot: Dictionary,
) -> void:
	_clear_artifacts(TEST_ROOT)
	var repository: RefCounted = _repository(TEST_ROOT, world)
	_write_json(
		TEST_ROOT,
		{
			"save_format_version": 4,
			"metadata": {},
			"world": {},
			"active_run": null,
			"profile": {},
		},
	)
	var loaded: Dictionary = repository.call("load_state") as Dictionary
	var quarantine: Array = repository.call("get_quarantine_paths") as Array
	_add_case(
		cases,
		"future schema is quarantined with explicit incompatible status",
		(
			loaded.is_empty()
			and repository.call("get_status") == &"incompatible"
			and quarantine.size() == 1
			and FileAccess.file_exists(quarantine[0])
		),
	)
	_add_case(
		cases,
		"future schema blocks automatic overwrite",
		(
			bool(repository.call("is_write_blocked"))
			and not bool(
				repository.call(
					"save_state", world.call("make_snapshot"), run_snapshot, profile_snapshot
				)
			)
		),
	)
	_test_future_restart(cases, world, run_snapshot, profile_snapshot)


static func _test_future_restart(
	cases: Array[Dictionary],
	world: RefCounted,
	run_snapshot: Dictionary,
	profile_snapshot: Dictionary,
) -> void:
	var reopened: RefCounted = _repository(TEST_ROOT, world)
	var reopened_state: Dictionary = reopened.call("load_state") as Dictionary
	_add_case(
		cases,
		"future-schema write protection survives repository restart",
		(
			reopened_state.is_empty()
			and reopened.call("get_status") == &"incompatible"
			and bool(reopened.call("is_write_blocked"))
			and (reopened.call("get_quarantine_paths") as Array).size() == 1
			and not bool(
				reopened.call(
					"save_state", world.call("make_snapshot"), run_snapshot, profile_snapshot
				)
			)
		),
	)

	_clear_artifacts(TEST_ROOT)
	var primary_repository: RefCounted = _repository(TEST_ROOT, world)
	primary_repository.call(
		"save_state", world.call("make_snapshot"), run_snapshot, profile_snapshot
	)
	_write_json(TEST_ROOT + ".bak", {"save_format_version": 4})
	primary_repository.call("load_state")
	var backup_quarantine: Array = primary_repository.call("get_quarantine_paths") as Array
	var backup_reopened: RefCounted = _repository(TEST_ROOT, world)
	_add_case(
		cases,
		"future backup remains protected across repository restart",
		(
			primary_repository.call("get_status") == &"incompatible"
			and backup_quarantine.size() == 1
			and ".bak.quarantine.future." in str(backup_quarantine[0])
			and (backup_reopened.call("load_state") as Dictionary).is_empty()
			and bool(backup_reopened.call("is_write_blocked"))
		),
	)


static func _test_corrupt_and_oversized(cases: Array[Dictionary], world: RefCounted) -> void:
	_clear_artifacts(TEST_ROOT)
	var repository: RefCounted = _repository(TEST_ROOT, world)
	_write_text(TEST_ROOT, "{not-json")
	_add_case(
		cases,
		"unreadable JSON is quarantined without silent deletion",
		(
			(repository.call("load_state") as Dictionary).is_empty()
			and repository.call("get_status") == &"corrupt"
			and (repository.call("get_quarantine_paths") as Array).size() == 1
		),
	)
	_clear_artifacts(TEST_ROOT)
	repository = _repository(TEST_ROOT, world)
	var oversized: String = "x".repeat(SaveRepositoryScript.MAX_FILE_BYTES + 1)
	_write_text(TEST_ROOT, oversized)
	_add_case(
		cases,
		"oversized save is rejected before JSON allocation",
		(
			(repository.call("load_state") as Dictionary).is_empty()
			and repository.call("get_status") == &"corrupt"
			and (repository.call("get_quarantine_paths") as Array).size() == 1
		),
	)


static func _test_atomic_rejection(
	cases: Array[Dictionary],
	world: RefCounted,
	run_snapshot: Dictionary,
	profile_snapshot: Dictionary,
) -> void:
	_clear_artifacts(TEST_ROOT)
	var repository: RefCounted = _repository(TEST_ROOT, world)
	var world_snapshot: Dictionary = world.call("make_snapshot") as Dictionary
	repository.call("save_state", world_snapshot, run_snapshot, profile_snapshot)
	var before: String = _read_text(TEST_ROOT)
	var invalid_world: Dictionary = world_snapshot.duplicate(true)
	invalid_world[&"destroyed_rocks"] = [[4, 4], [4, 4]]
	_add_case(
		cases,
		"invalid candidate cannot partially replace committed state",
		(
			not bool(repository.call("save_state", invalid_world, run_snapshot, profile_snapshot))
			and _read_text(TEST_ROOT) == before
			and not FileAccess.file_exists(TEST_ROOT + ".tmp")
		),
	)
	var overlapping_world: Dictionary = world_snapshot.duplicate(true)
	overlapping_world[&"destroyed_rocks"] = [[4, 4]]
	overlapping_world[&"placed_rocks"] = [[4, 4]]
	_add_case(
		cases,
		"schema-3 rejects contradictory world delta sets",
		(
			not bool(
				repository.call("save_state", overlapping_world, run_snapshot, profile_snapshot)
			)
			and _read_text(TEST_ROOT) == before
		),
	)
	var mismatched_run: Dictionary = run_snapshot.duplicate(true)
	mismatched_run[&"starter_relay_completed"] = true
	_add_case(
		cases,
		"schema-3 rejects relay state without its idempotency event",
		(
			not bool(
				repository.call("save_state", world_snapshot, mismatched_run, profile_snapshot)
			)
			and _read_text(TEST_ROOT) == before
		),
	)
	var envelope: Dictionary = _read_json(TEST_ROOT)
	var original: Dictionary = envelope.duplicate(true)
	_add_case(
		cases,
		"schema-3 validation is detached from its input",
		(
			not (repository.call("validate_envelope", envelope) as Dictionary).is_empty()
			and envelope == original
		),
	)
	envelope[&"unexpected"] = true
	_add_case(
		cases,
		"schema-3 rejects unknown fields instead of dropping them",
		(repository.call("validate_envelope", envelope) as Dictionary).is_empty(),
	)


static func _repository(path: String, world: RefCounted) -> RefCounted:
	var repository: RefCounted = SaveRepositoryScript.new() as RefCounted
	return repository if bool(repository.call("configure", path, world, "test-build")) else null


static func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	return parsed as Dictionary if parsed is Dictionary else {}


static func _write_json(path: String, value: Dictionary) -> void:
	_write_text(path, JSON.stringify(value, "", true, true))


static func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


static func _write_text(path: String, value: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(value)
	file.close()


static func _clear_artifacts(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path.get_base_dir())
	if directory == null:
		return
	var prefix: String = path.get_file()
	for file_name: String in directory.get_files():
		if file_name == prefix or file_name.begins_with(prefix + "."):
			directory.remove(file_name)


static func _add_case(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
