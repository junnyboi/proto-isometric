extends RefCounted

const SaveMigratorScript: GDScript = preload("res://scripts/save_migrator.gd")
const RunStateScript: GDScript = preload("res://scripts/run_state.gd")
const ProfileStateScript: GDScript = preload("res://scripts/profile_state.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")

const FIXTURE_SCHEMA_ONE: String = "res://test/fixtures/save_schema_1.json"
const FIXTURE_RELAY_FALSE: String = "res://test/fixtures/save_schema_2_relay_false.json"
const FIXTURE_RELAY_TRUE: String = "res://test/fixtures/save_schema_2_relay_true.json"
const FIXTURE_SHUTDOWN: String = "res://test/fixtures/save_schema_2_shutdown.json"


static func evaluate(world: RefCounted) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var migrator: RefCounted = SaveMigratorScript.new() as RefCounted
	_add_case(
		cases,
		"legacy migrator configures with the world validator",
		bool(migrator.call("configure", world, 100)),
	)
	_test_schema_one(cases, migrator)
	_test_schema_two_relay_false(cases, migrator)
	_test_schema_two_relay_true(cases, migrator)
	_test_schema_two_shutdown(cases, migrator)
	_test_strict_rejections(cases, migrator)
	return cases


static func _test_schema_one(cases: Array[Dictionary], migrator: RefCounted) -> void:
	var source: Dictionary = _load_fixture(FIXTURE_SCHEMA_ONE)
	var original: Dictionary = source.duplicate(true)
	var migrated: Dictionary = migrator.call("migrate", source) as Dictionary
	_add_case(
		cases,
		"schema 1 fixture migrates to a schema-5 envelope",
		_is_envelope(migrated, 1) and int(migrator.call("get_source_version")) == 1,
	)
	_add_case(cases, "schema 1 migration does not mutate its input", source == original)
	if migrated.is_empty():
		return
	var world: Dictionary = migrated[&"world"] as Dictionary
	var run: Dictionary = migrated[&"active_run"] as Dictionary
	_add_case(
		cases,
		"schema 1 preserves finite-world rock and scrap semantics",
		(
			world[&"destroyed_rocks"] == [[3, 15]]
			and world[&"placed_rocks"] == [[16, 6]]
			and world[&"collected_scrap"] == [[9, 9]]
			and (
				world[&"dropped_scrap"]
				== [
					{&"cell": [10, 7], &"amount": 2},
					{&"cell": [14, 8], &"amount": 2},
					{&"cell": [6, 10], &"amount": 7},
					{&"cell": [7, 13], &"amount": 1},
				]
			)
		),
	)
	_add_case(
		cases,
		"schema 1 preserves run values with relay conservatively incomplete",
		(
			run[&"run_id"] == "run.legacy.v1"
			and run[&"player_cell"] == [8, 10]
			and run[&"facing"] == "NW"
			and int(run[&"chassis"]) == 73
			and int(run[&"unbanked_scrap"]) == 37
			and int(run[&"worm_cores"]) == 0
			and (run[&"run_drops"] as Array).is_empty()
			and int(run[&"next_drop_sequence"]) == 1
			and not bool(run[&"starter_relay_completed"])
			and (run[&"applied_event_ids"] as Array).is_empty()
		),
	)
	_add_case(cases, "schema 1 canonical world arrays are sorted", _world_is_sorted(world))
	var second: Dictionary = migrator.call("migrate", source) as Dictionary
	_add_case(cases, "schema 1 canonical migration is deterministic", migrated == second)
	(migrated[&"world"] as Dictionary)[&"destroyed_rocks"] = [[0, 0]]
	_add_case(
		cases,
		"schema 1 migration result is detached from later migrations",
		(migrator.call("migrate", source) as Dictionary)[&"world"] != migrated[&"world"],
	)


static func _test_schema_two_relay_false(cases: Array[Dictionary], migrator: RefCounted) -> void:
	var source: Dictionary = _load_fixture(FIXTURE_RELAY_FALSE)
	var migrated: Dictionary = migrator.call("migrate", source) as Dictionary
	var run: Dictionary = migrated.get(&"active_run", {}) as Dictionary
	_add_case(
		cases,
		"schema 2 relay-false fixture preserves world and run values",
		(
			_is_envelope(migrated, 2)
			and run[&"run_id"] == "run.legacy.v2"
			and run[&"player_cell"] == [31, -11]
			and run[&"facing"] == "SW"
			and int(run[&"chassis"]) == 62
			and int(run[&"unbanked_scrap"]) == 84
			and int(run[&"worm_cores"]) == 0
			and (run[&"run_drops"] as Array).is_empty()
			and not bool(run[&"starter_relay_completed"])
			and run[&"phase"] == String(RuntimeIdsScript.RUN_PHASE_HUNT)
		),
	)
	if migrated.is_empty():
		return
	var world: Dictionary = migrated[&"world"] as Dictionary
	_add_case(
		cases,
		"schema 2 world deltas are lossless and canonical",
		(
			world[&"destroyed_rocks"] == [[4, 4], [3, 15], [-9, 21]]
			and world[&"placed_rocks"] == [[25, -7], [16, 6]]
			and (
				world[&"dropped_scrap"]
				== [
					{&"cell": [40, -12], &"amount": 9},
					{&"cell": [18, 20], &"amount": 4},
				]
			)
			and world[&"collected_scrap"] == [[14, 8], [7, 13], [99, 101]]
			and _world_is_sorted(world)
		),
	)
	var reordered: Dictionary = source.duplicate(true)
	for key: String in ["destroyed_rocks", "placed_rocks", "dropped_scrap", "collected_scrap"]:
		(reordered[key] as Array).reverse()
	_add_case(
		cases,
		"schema 2 canonical output is equal across input ordering",
		migrated == (migrator.call("migrate", reordered) as Dictionary),
	)


static func _test_schema_two_relay_true(cases: Array[Dictionary], migrator: RefCounted) -> void:
	var source: Dictionary = _load_fixture(FIXTURE_RELAY_TRUE)
	var migrated: Dictionary = migrator.call("migrate", source) as Dictionary
	var run_snapshot: Dictionary = migrated.get(&"active_run", {}) as Dictionary
	var events: Array = run_snapshot.get(&"applied_event_ids", []) as Array
	_add_case(
		cases,
		"schema 2 relay completion records one stable migration event without reward",
		(
			_is_envelope(migrated, 2)
			and bool(run_snapshot[&"starter_relay_completed"])
			and events == [String(RuntimeIdsScript.EVENT_RELAY_COMPLETED)]
			and int(run_snapshot[&"unbanked_scrap"]) == 123
			and int((migrated[&"profile"] as Dictionary)[&"banked_relay_data"]) == 0
		),
	)
	var restored: RefCounted = RunStateScript.new() as RefCounted
	var restored_ok: bool = bool(restored.call("restore_dictionary", run_snapshot))
	_add_case(
		cases,
		"relay migration event remains idempotent after RunState restore",
		(
			restored_ok
			and not bool(restored.call("apply_event", RuntimeIdsScript.EVENT_RELAY_COMPLETED))
		),
	)


static func _test_schema_two_shutdown(cases: Array[Dictionary], migrator: RefCounted) -> void:
	var source: Dictionary = _load_fixture(FIXTURE_SHUTDOWN)
	var migrated: Dictionary = migrator.call("migrate", source) as Dictionary
	var run: Dictionary = migrated.get(&"active_run", {}) as Dictionary
	_add_case(
		cases,
		"schema 2 zero chassis restores failed shutdown without banking scrap",
		(
			_is_envelope(migrated, 2)
			and int(run[&"chassis"]) == 0
			and bool(run[&"shutdown"])
			and run[&"phase"] == String(RuntimeIdsScript.RUN_PHASE_FAILED)
			and int(run[&"unbanked_scrap"]) == 205
			and int((migrated[&"profile"] as Dictionary)[&"banked_scrap"]) == 0
		),
	)
	var restored: RefCounted = RunStateScript.new() as RefCounted
	_add_case(
		cases,
		"migrated shutdown uses the exact restorable RunState shape",
		bool(restored.call("restore_dictionary", run)),
	)


static func _test_strict_rejections(cases: Array[Dictionary], migrator: RefCounted) -> void:
	var valid: Dictionary = _load_fixture(FIXTURE_RELAY_FALSE)
	var numeric_string: Dictionary = valid.duplicate(true)
	numeric_string[&"scrap_total"] = "84"
	_add_case(
		cases,
		"migration rejects numeric strings",
		(migrator.call("migrate", numeric_string) as Dictionary).is_empty(),
	)
	var fractional: Dictionary = valid.duplicate(true)
	fractional[&"robot_cell"] = [31.5, -11.0]
	_add_case(
		cases,
		"migration rejects fractional numeric values",
		(migrator.call("migrate", fractional) as Dictionary).is_empty(),
	)
	var non_finite: Dictionary = valid.duplicate(true)
	non_finite[&"chassis"] = INF
	_add_case(
		cases,
		"migration rejects non-finite numeric values",
		(migrator.call("migrate", non_finite) as Dictionary).is_empty(),
	)
	var duplicate: Dictionary = valid.duplicate(true)
	duplicate[&"destroyed_rocks"] = [[4, 4], [4.0, 4.0]]
	_add_case(
		cases,
		"migration rejects duplicate cells after numeric normalization",
		(migrator.call("migrate", duplicate) as Dictionary).is_empty(),
	)
	var oversized: Dictionary = valid.duplicate(true)
	var too_many: Array = []
	too_many.resize(100_001)
	oversized[&"placed_rocks"] = too_many
	_add_case(
		cases,
		"migration rejects oversized arrays before decoding entries",
		(migrator.call("migrate", oversized) as Dictionary).is_empty(),
	)
	var future: Dictionary = valid.duplicate(true)
	future[&"schema"] = 6.0
	_add_case(
		cases,
		"migration rejects future schemas explicitly",
		(
			(
				(migrator.call("migrate", future) as Dictionary).is_empty()
				and int(migrator.call("get_source_version")) == 0
			)
				or int(migrator.call("get_source_version")) == 6
		),
	)
	var missing: Dictionary = valid.duplicate(true)
	missing.erase(&"facing")
	_add_case(
		cases,
		"migration rejects malformed required fields",
		(migrator.call("migrate", missing) as Dictionary).is_empty(),
	)
	var unknown: Dictionary = valid.duplicate(true)
	unknown[&"future_field"] = 1
	_add_case(
		cases,
		"migration rejects unknown legacy fields",
		(migrator.call("migrate", unknown) as Dictionary).is_empty(),
	)
	var default_profile: RefCounted = ProfileStateScript.new() as RefCounted
	var migrated: Dictionary = migrator.call("migrate", valid) as Dictionary
	_add_case(
		cases,
		"every migration emits the exact default ProfileState shape",
		migrated[&"profile"] == (default_profile.call("to_dictionary") as Dictionary),
	)


static func _load_fixture(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


static func _is_envelope(snapshot: Dictionary, source_version: int) -> bool:
	if snapshot.is_empty():
		return false
	var metadata: Dictionary = snapshot.get(&"metadata", {}) as Dictionary
	return (
		int(snapshot.get(&"save_format_version", -1)) == 5
		and snapshot.has(&"world")
		and snapshot.has(&"active_run")
		and snapshot.has(&"profile")
		and snapshot.has(&"farm")
		and (
			FarmSaveSchemaScript.mode_of(snapshot[&"farm"])
			== RuntimeIdsScript.MODE_LEGACY_EXPEDITION
		)
		and (
			(snapshot[&"farm"] as Dictionary)[&"migration_tokens"]
			== [String(RuntimeIdsScript.MIGRATION_FARM_V3_TO_V4)]
		)
		and metadata.get(&"build_id", "") == "legacy-migration"
		and int(metadata.get(&"world_generation_version", -1)) == 1
		and int(metadata.get(&"write_sequence", -1)) == 0
		and int(metadata.get(&"saved_at_unix", -1)) == 0
		and int(metadata.get(&"migration_source", -1)) == source_version
	)


static func _world_is_sorted(world: Dictionary) -> bool:
	for key: StringName in [&"destroyed_rocks", &"placed_rocks", &"collected_scrap"]:
		var cells: Array = world[key] as Array
		for index: int in range(1, cells.size()):
			if _cell_less(cells[index] as Array, cells[index - 1] as Array):
				return false
	var amounts: Array = world[&"dropped_scrap"] as Array
	for index: int in range(1, amounts.size()):
		var current: Dictionary = amounts[index] as Dictionary
		var previous: Dictionary = amounts[index - 1] as Dictionary
		if _cell_less(current[&"cell"] as Array, previous[&"cell"] as Array):
			return false
	return true


static func _cell_less(first: Array, second: Array) -> bool:
	return first[1] < second[1] or (first[1] == second[1] and first[0] < second[0])


static func _add_case(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
