extends RefCounted

const WorldStateStoreScript: GDScript = preload("res://scripts/world_state_store.gd")
const SaveMigratorScript: GDScript = preload("res://scripts/save_migrator.gd")
const RunStateScript: GDScript = preload("res://scripts/run_state.gd")
const ProfileStateScript: GDScript = preload("res://scripts/profile_state.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const WorldMutationLedgerScript: GDScript = preload("res://scripts/world_mutation_ledger.gd")
const EnvelopeMigrationsScript: GDScript = preload(
	"res://scripts/save_envelope_migrations.gd"
)
const BudgetCatalogScript: GDScript = preload("res://scripts/persistence_budget_catalog.gd")
const StateHashScript: GDScript = preload("res://scripts/persistence_state_hash.gd")
const ConstructionLinksScript: GDScript = preload(
	"res://scripts/construction_envelope_links.gd"
)
const BrowserCapabilityScript: GDScript = preload(
	"res://scripts/browser_persistence_capability.gd"
)
const PreP6CompatibilityScript: GDScript = preload("res://scripts/pre_p6_save_compatibility.gd")

const FORMAT_VERSION: int = 5
const LEGACY_FORMAT_VERSION: int = 3
const PREVIOUS_FORMAT_VERSION: int = 4
const WORLD_GENERATION_VERSION: int = 1
const MAX_FILE_BYTES: int = 2_097_152
const MAX_WORLD_ITEMS: int = 100_000
const MAX_APPLIED_EVENTS: int = 128
const MAX_COORDINATE: int = 1_000_000
const MAX_WALLET: int = 1_000_000_000
const MAX_SEQUENCE: int = 9_007_199_254_740_991

const STATUS_EMPTY: StringName = &"empty"
const STATUS_LOADED: StringName = &"loaded"
const STATUS_MIGRATED: StringName = &"migrated"
const STATUS_RECOVERED: StringName = &"recovered"
const STATUS_CORRUPT: StringName = &"corrupt"
const STATUS_INCOMPATIBLE: StringName = &"incompatible"
const STATUS_SAVE_FAILED: StringName = &"save_failed"

var _path: String = ""
var _build_id: String = "development"
var _world_validator: RefCounted
var _file_store: RefCounted
var _migrator: RefCounted
var _status: StringName = STATUS_EMPTY
var _last_error: String = ""
var _selected_source: String = ""
var _write_sequence: int = 0
var _migration_source: int = 0
var _quarantine_paths: Array[String] = []
var _writes_blocked: bool = false
var _default_farm: Dictionary = {}
var _configured_default_mode: StringName = RuntimeIdsScript.MODE_FRESH_FARM
var _fault_injector: RefCounted
var _last_committed_envelope: Dictionary = {}
var _persistence_capability: Dictionary = {}

func configure(
	path: String,
	world_validator: RefCounted,
	build_id: String = "development",
	default_gameplay_mode: StringName = RuntimeIdsScript.MODE_FRESH_FARM,
) -> bool:
	_path = path
	_world_validator = world_validator
	_build_id = build_id.left(64) if not build_id.is_empty() else "development"
	_file_store = WorldStateStoreScript.new() as RefCounted
	_migrator = SaveMigratorScript.new() as RefCounted
	if (
		path.is_empty()
		or world_validator == null
		or not world_validator.has_method("is_valid_snapshot")
		or default_gameplay_mode not in RuntimeIdsScript.gameplay_mode_ids()
		or not bool(_file_store.call("configure", path))
		or not bool(_migrator.call("configure", world_validator, 100))
	):
		_last_error = "Save repository configuration failed."
		return false
	_configured_default_mode = default_gameplay_mode
	_reset_result()
	_persistence_capability = BrowserCapabilityScript.probe()
	if _persistence_capability[&"status"] != String(BrowserCapabilityScript.STATUS_AVAILABLE):
		push_warning(
			"Save storage is %s: %s. Progress may not survive browser cleanup."
			% [_persistence_capability[&"status"], _persistence_capability[&"reason"]]
		)
	return true

func load_state() -> Dictionary:
	_reset_result()
	if _file_store == null:
		_last_error = "Save repository is not configured."
		_status = STATUS_CORRUPT
		return {}
	var future_quarantine: Array[String] = _existing_quarantine("future")
	if not future_quarantine.is_empty():
		_quarantine_paths.assign(future_quarantine)
		_status = STATUS_INCOMPATIBLE
		_writes_blocked = true
		_last_error = "A save from a newer format remains preserved for recovery."
		return {}
	var primary: Dictionary = _read_candidate(_path)
	var backup: Dictionary = _read_candidate(_path + ".bak")
	var temporary: Dictionary = _read_candidate(_path + ".tmp", false)
	if _any_candidate_has_kind([primary, backup, temporary], &"future"):
		for candidate: Dictionary in [primary, backup, temporary]:
			_quarantine_invalid(candidate, "future")
		_status = STATUS_INCOMPATIBLE
		_writes_blocked = true
		_last_error = "A save from a newer format was preserved for recovery."
		return {}
	var candidates: Array[Dictionary] = []
	for candidate: Dictionary in [primary, backup, temporary]:
		if candidate[&"kind"] == &"valid":
			candidates.append(candidate)
		elif candidate[&"kind"] == &"invalid":
			_quarantine_invalid(candidate, "corrupt")
	if candidates.is_empty():
		if primary[&"kind"] == &"missing" and backup[&"kind"] == &"missing":
			_status = STATUS_EMPTY
		else:
			_status = STATUS_CORRUPT
			_last_error = "No valid primary or backup save remained."
		return {}
	candidates.sort_custom(_candidate_precedes)
	var selected: Dictionary = candidates[0]
	var envelope: Dictionary = (selected[&"envelope"] as Dictionary).duplicate(true)
	_selected_source = str(selected[&"path"])
	_write_sequence = int((envelope[&"metadata"] as Dictionary)[&"write_sequence"])
	_migration_source = int((envelope[&"metadata"] as Dictionary)[&"migration_source"])
	if selected[&"source_version"] in [1, 2, LEGACY_FORMAT_VERSION, PREVIOUS_FORMAT_VERSION]:
		_status = STATUS_MIGRATED
	elif _selected_source != _path or not _quarantine_paths.is_empty():
		_status = STATUS_RECOVERED
	else:
		_status = STATUS_LOADED
	_default_farm = (envelope[&"farm"] as Dictionary).duplicate(true)
	_last_committed_envelope = envelope.duplicate(true)
	return envelope

func save_state(
	world: Dictionary, active_run: Variant, profile: Dictionary, farm: Dictionary = {}
) -> bool:
	_last_error = ""
	if _writes_blocked:
		return _fail_save("Writes are blocked after an incompatible future save was preserved.")
	if _file_store == null:
		return _fail_save("Save repository is not configured.")
	var next_sequence: int = _write_sequence + 1
	if next_sequence <= 0 or next_sequence > MAX_SEQUENCE:
		return _fail_save("Save write sequence is exhausted.")
	var farm_candidate: Dictionary = (
		_default_farm.duplicate(true) if farm.is_empty() else farm.duplicate(true)
	)
	var envelope: Dictionary = _make_envelope(
		world, active_run, profile, farm_candidate, next_sequence
	)
	if envelope.is_empty():
		return _fail_save("Refused to write an invalid schema-5 state.")
	return _commit_envelope(envelope, next_sequence)

func save_candidate_envelope(source: Dictionary, farm_candidate: Dictionary) -> bool:
	if _writes_blocked:
		return _fail_save("Writes are blocked after an incompatible future save was preserved.")
	if _file_store == null or source.is_empty():
		return _fail_save("Save repository is not configured with a candidate source.")
	var next_sequence: int = _write_sequence + 1
	if next_sequence <= 0 or next_sequence > MAX_SEQUENCE:
		return _fail_save("Save write sequence is exhausted.")
	var envelope: Dictionary = _make_envelope(
		source.get(&"world", {}) as Dictionary,
		source.get(&"active_run"),
		source.get(&"profile", {}) as Dictionary,
		farm_candidate,
		next_sequence,
	)
	if envelope.is_empty():
		return _fail_save("Refused to write an invalid detached candidate envelope.")
	return _commit_envelope(envelope, next_sequence)

func _make_envelope(
	world: Dictionary,
	active_run: Variant,
	profile: Dictionary,
	farm: Dictionary,
	sequence: int,
) -> Dictionary:
	var envelope: Dictionary = {
		&"save_format_version": FORMAT_VERSION,
		&"metadata":
		{
			&"build_id": _build_id,
			&"world_generation_version": WORLD_GENERATION_VERSION,
			&"write_sequence": sequence,
			&"saved_at_unix": int(Time.get_unix_time_from_system()),
			&"migration_source": _migration_source,
		},
		&"world": world.duplicate(true),
		&"active_run": active_run.duplicate(true) if active_run is Dictionary else active_run,
		&"profile": profile.duplicate(true),
		&"farm": farm.duplicate(true),
	}
	if _last_committed_envelope.is_empty():
		envelope = StateHashScript.apply_initial(envelope)
	else:
		envelope = StateHashScript.apply_next(_last_committed_envelope, envelope)
	if envelope.is_empty():
		return {}
	return validate_envelope(envelope)

func _commit_envelope(envelope: Dictionary, sequence: int) -> bool:
	var preflight: Dictionary = BudgetCatalogScript.preflight(envelope)
	if not bool(preflight[&"ok"]):
		return _fail_save("Canonical save exceeds its persistence budget.")
	var encoded: String = BudgetCatalogScript.canonical_json(envelope)
	var temporary_path: String = _path + ".tmp"
	if not bool(
		_file_store.call("write_text", temporary_path, encoded, MAX_FILE_BYTES, _fault_injector)
	):
		return _fail_save(str(_file_store.call("get_last_error")))
	var temporary: Dictionary = _read_candidate(temporary_path, false)
	if (
		temporary[&"kind"] != &"valid"
		or (
			int(
				((temporary[&"envelope"] as Dictionary)[&"metadata"] as Dictionary)[&"write_sequence"]
			)
			!= sequence
			)
		):
		_file_store.call("remove", temporary_path)
		return _fail_save("Temporary save validation failed.")
	if not _rotate_validated_temp(temporary_path):
		return false
	_write_sequence = sequence
	_default_farm = (envelope[&"farm"] as Dictionary).duplicate(true)
	_last_committed_envelope = envelope.duplicate(true)
	_status = STATUS_LOADED
	_selected_source = _path
	return true

func validate_envelope(envelope: Dictionary) -> Dictionary:
	return _validate_envelope(envelope, true)


func validate_candidate_envelope(envelope: Dictionary) -> Dictionary:
	return _validate_envelope(envelope, false)


func _validate_envelope(envelope: Dictionary, verify_result_hash: bool) -> Dictionary:
	if not _exact_keys(
		envelope,
		[&"save_format_version", &"metadata", &"world", &"active_run", &"profile", &"farm"],
	):
		return {}
	var format_version: Variant = _json_integer(
		envelope.get(&"save_format_version"), 1, MAX_SEQUENCE
	)
	if format_version == null or int(format_version) != FORMAT_VERSION:
		return {}
	var pre_p6_hash_valid: bool = PreP6CompatibilityScript.raw_hash_is_valid(
		envelope, verify_result_hash
	)
	var metadata: Dictionary = _normalize_metadata(envelope.get(&"metadata"))
	var active_run: Variant = _normalize_run(envelope.get(&"active_run"))
	var profile: Dictionary = _normalize_profile(envelope.get(&"profile"))
	var farm: Dictionary = FarmSaveSchemaScript.validate(envelope.get(&"farm"))
	if (
		metadata.is_empty()
		or (active_run is bool and not bool(active_run))
		or profile.is_empty()
		or farm.is_empty()
	):
		return {}
	var robot_cell: Vector2i = Vector2i(MAX_COORDINATE + 1, MAX_COORDINATE + 1)
	if active_run is Dictionary:
		var cell: Array = (active_run as Dictionary)[&"player_cell"] as Array
		robot_cell = Vector2i(int(cell[0]), int(cell[1]))
	var world: Dictionary = _normalize_world(envelope.get(&"world"), robot_cell)
	if world.is_empty():
		return {}
	var normalized: Dictionary = {
		&"save_format_version": FORMAT_VERSION,
		&"metadata": metadata,
		&"world": world,
		&"active_run": active_run,
		&"profile": profile,
		&"farm": farm,
	}
	var revisions: Dictionary = farm[&"revisions"] as Dictionary
	if verify_result_hash and int(revisions[&"result_revision"]) > 0:
		if not StateHashScript.result_hash_matches(normalized):
			if not pre_p6_hash_valid:
				return {}
			revisions[&"result_hash"] = StateHashScript.state_hash(normalized)
			farm[&"revisions"] = revisions
			normalized[&"farm"] = farm
	return (
		normalized
		if ConstructionLinksScript.validate(normalized)
		and bool(BudgetCatalogScript.preflight(normalized)[&"ok"])
		else {}
	)
func set_fault_injector(injector: RefCounted) -> void:
	_fault_injector = injector
	if _file_store != null:
		_file_store.call("set_fault_injector", injector)

func get_last_committed_envelope() -> Dictionary:
	return _last_committed_envelope.duplicate(true)

func clear_committed() -> bool:
	if _file_store == null:
		return false
	var cleared: bool = true
	for candidate: String in [_path, _path + ".tmp", _path + ".bak"]:
		cleared = bool(_file_store.call("remove", candidate)) and cleared
	_reset_result()
	return cleared

func get_status() -> StringName:
	return _status

func get_last_error() -> String:
	return _last_error

func get_selected_source() -> String:
	return _selected_source

func get_write_sequence() -> int:
	return _write_sequence

func get_quarantine_paths() -> Array[String]:
	return _quarantine_paths.duplicate()

func is_write_blocked() -> bool:
	return _writes_blocked

func get_default_farm() -> Dictionary:
	return _default_farm.duplicate(true)

func get_gameplay_mode() -> StringName:
	return FarmSaveSchemaScript.mode_of(_default_farm)


func get_persistence_capability() -> Dictionary:
	return _persistence_capability.duplicate(true)


func _read_candidate(path: String, allow_legacy: bool = true) -> Dictionary:
	if not bool(_file_store.call("exists", path)):
		return _candidate(path, &"missing")
	var text: String = str(_file_store.call("read_text", path, MAX_FILE_BYTES))
	if not str(_file_store.call("get_last_error")).is_empty():
		return _candidate(path, &"invalid")
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return _candidate(path, &"invalid")
	var raw: Dictionary = parser.data as Dictionary
	if not _variant_is_bounded(raw):
		return _candidate(path, &"invalid")
	return _classify_candidate(path, raw, allow_legacy)

func _classify_candidate(path: String, raw: Dictionary, allow_legacy: bool) -> Dictionary:
	if raw.has("save_format_version"):
		return _classify_current(path, raw)
	if raw.has("schema"):
		var legacy_version: Variant = _json_integer(raw.get("schema"), 1, MAX_SEQUENCE)
		if legacy_version != null and int(legacy_version) > 2:
			return _candidate(path, &"future", {}, int(legacy_version))
	if not allow_legacy:
		return _candidate(path, &"invalid")
	var migrated: Dictionary = _migrator.call("migrate", raw) as Dictionary
	return (
		_candidate(path, &"valid", migrated, int(_migrator.call("get_source_version")))
		if not migrated.is_empty()
		else _candidate(path, &"invalid")
	)

func _classify_current(path: String, raw: Dictionary) -> Dictionary:
	var version: Variant = _json_integer(raw.get("save_format_version"), 1, MAX_SEQUENCE)
	if version == null:
		return _candidate(path, &"invalid")
	if int(version) > FORMAT_VERSION:
		return _candidate(path, &"future", {}, int(version))
	if int(version) in [LEGACY_FORMAT_VERSION, PREVIOUS_FORMAT_VERSION]:
		var migrated: Dictionary = _migrate_envelope(raw, int(version))
		return (
			_candidate(path, &"valid", migrated, int(version))
			if not migrated.is_empty()
			else _candidate(path, &"invalid")
		)
	if int(version) != FORMAT_VERSION:
		return _candidate(path, &"invalid")
	var current: Dictionary = validate_envelope(raw)
	return (
		_candidate(path, &"valid", current, FORMAT_VERSION)
		if not current.is_empty()
		else _candidate(path, &"invalid")
	)

func _migrate_envelope(raw: Dictionary, version: int) -> Dictionary:
	var arguments: Array[Callable] = [
		_normalize_metadata, _normalize_world, _normalize_run, _normalize_profile
	]
	if version == LEGACY_FORMAT_VERSION:
		return EnvelopeMigrationsScript.migrate_schema_three(
			raw, arguments[0], arguments[1], arguments[2], arguments[3]
		)
	return EnvelopeMigrationsScript.migrate_schema_four(
		raw, arguments[0], arguments[1], arguments[2], arguments[3]
	)

func _candidate(
	path: String,
	kind: StringName,
	envelope: Dictionary = {},
	source_version: int = 0,
) -> Dictionary:
	return {
		&"path": path,
		&"kind": kind,
		&"envelope": envelope,
		&"source_version": source_version,
	}

func _candidate_precedes(first: Dictionary, second: Dictionary) -> bool:
	var first_revision: int = _candidate_revision(first)
	var second_revision: int = _candidate_revision(second)
	return (
		first_revision > second_revision
		or (first_revision == second_revision and str(first[&"path"]) == _path)
	)
func _candidate_revision(candidate: Dictionary) -> int:
	var envelope: Dictionary = candidate[&"envelope"] as Dictionary
	var farm: Dictionary = envelope[&"farm"] as Dictionary
	return int((farm[&"revisions"] as Dictionary)[&"result_revision"])

func _any_candidate_has_kind(candidates: Array, kind: StringName) -> bool:
	for candidate: Dictionary in candidates:
		if candidate[&"kind"] == kind:
			return true
	return false

func _rotate_validated_temp(temporary_path: String) -> bool:
	var backup_path: String = _path + ".bak"
	if bool(_file_store.call("exists", _path)):
		if not _prepare_backup(temporary_path, backup_path):
			return false
	if _fault(&"rename"):
		return _fail_save("Injected rename phase failure.")
	if _fault(&"publish"):
		if bool(_file_store.call("exists", backup_path)):
			_file_store.call("rename", backup_path, _path)
		return _fail_save("Injected publish phase failure.")
	if not bool(_file_store.call("rename", temporary_path, _path)):
		var failure: String = str(_file_store.call("get_last_error"))
		if (
			bool(_file_store.call("exists", backup_path))
			and not bool(_file_store.call("exists", _path))
		):
			_file_store.call("rename", backup_path, _path)
		return _fail_save(failure)
	return true

func _prepare_backup(temporary_path: String, backup_path: String) -> bool:
	if _fault(&"backup"):
		_file_store.call("remove", temporary_path)
		return _fail_save("Injected backup phase failure.")
	if not bool(_file_store.call("remove", backup_path)):
		_file_store.call("remove", temporary_path)
		return _fail_save(str(_file_store.call("get_last_error")))
	if not bool(_file_store.call("rename", _path, backup_path)):
		_file_store.call("remove", temporary_path)
		return _fail_save(str(_file_store.call("get_last_error")))
	return true

func _quarantine_invalid(candidate: Dictionary, reason: String) -> void:
	if candidate[&"kind"] in [&"invalid", &"future"]:
		_quarantine(str(candidate[&"path"]), reason)

func _quarantine(source: String, reason: String) -> void:
	if not bool(_file_store.call("exists", source)):
		return
	var suffix: int = 1
	var target: String = "%s.quarantine.%s.%03d" % [source, reason, suffix]
	while bool(_file_store.call("exists", target)):
		suffix += 1
		target = "%s.quarantine.%s.%03d" % [source, reason, suffix]
	if bool(_file_store.call("rename", source, target)):
		_quarantine_paths.append(target)

func _existing_quarantine(reason: String) -> Array[String]:
	var matches: Array[String] = []
	var directory: DirAccess = DirAccess.open(_path.get_base_dir())
	if directory == null:
		return matches
	var prefixes: Array[String] = [
		_path.get_file() + ".quarantine.%s." % reason,
		_path.get_file() + ".bak.quarantine.%s." % reason,
		_path.get_file() + ".tmp.quarantine.%s." % reason,
	]
	for file_name: String in directory.get_files():
		for prefix: String in prefixes:
			if file_name.begins_with(prefix):
				matches.append(_path.get_base_dir().path_join(file_name))
				break
	matches.sort()
	return matches

func _normalize_metadata(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var metadata: Dictionary = value as Dictionary
	if not _exact_keys(
		metadata,
		[
			&"build_id",
			&"world_generation_version",
			&"write_sequence",
			&"saved_at_unix",
			&"migration_source",
		],
	):
		return {}
	var build_id: Variant = metadata.get(&"build_id")
	var world_version: Variant = _json_integer(
		metadata.get(&"world_generation_version"), 1, MAX_SEQUENCE
	)
	var sequence: Variant = _json_integer(metadata.get(&"write_sequence"), 0, MAX_SEQUENCE)
	var saved_at: Variant = _json_integer(metadata.get(&"saved_at_unix"), 0, MAX_SEQUENCE)
	var migration: Variant = _json_integer(metadata.get(&"migration_source"), 0, 2)
	if (
		not build_id is String
		or (build_id as String).is_empty()
		or (build_id as String).length() > 64
		or world_version == null
		or int(world_version) != WORLD_GENERATION_VERSION
		or sequence == null
		or saved_at == null
		or migration == null
	):
		return {}
	return {
		&"build_id": build_id,
		&"world_generation_version": WORLD_GENERATION_VERSION,
		&"write_sequence": int(sequence),
		&"saved_at_unix": int(saved_at),
		&"migration_source": int(migration),
	}

func _normalize_world(value: Variant, robot_cell: Vector2i) -> Dictionary:
	if not value is Dictionary:
		return {}
	var world: Dictionary = value as Dictionary
	var world_keys: Array[StringName] = [
		&"destroyed_rocks", &"placed_rocks", &"dropped_scrap", &"collected_scrap"
	]
	if world.has(&"mutation_ledger"):
		world_keys.append(&"mutation_ledger")
	if not _exact_keys(
		world,
		world_keys,
	):
		return {}
	var destroyed: Variant = _normalize_cells(world.get(&"destroyed_rocks"))
	var placed: Variant = _normalize_cells(world.get(&"placed_rocks"))
	var dropped: Variant = _normalize_amounts(world.get(&"dropped_scrap"))
	var collected: Variant = _normalize_cells(world.get(&"collected_scrap"))
	if destroyed == null or placed == null or dropped == null or collected == null:
		return {}
	if (
		_cell_arrays_overlap(destroyed as Array, placed as Array)
		or _amounts_overlap_cells(dropped as Array, collected as Array)
		or _amounts_overlap_cells(dropped as Array, placed as Array)
	):
		return {}
	var normalized: Dictionary = {
		&"destroyed_rocks": destroyed,
		&"placed_rocks": placed,
		&"dropped_scrap": dropped,
		&"collected_scrap": collected,
	}
	if world.has(&"mutation_ledger"):
		var with_ledger: Dictionary = _normalize_mutation_ledger(normalized, world[&"mutation_ledger"])
		if with_ledger.is_empty():
			return {}
		normalized = with_ledger
	var legacy_view: Dictionary = normalized.duplicate(true)
	legacy_view.erase(&"mutation_ledger")
	legacy_view[&"schema"] = 2
	if not bool(_world_validator.call("is_valid_snapshot", legacy_view, robot_cell)):
		normalized.clear()
	return normalized

func _normalize_mutation_ledger(normalized: Dictionary, value: Variant) -> Dictionary:
	var ledger: Dictionary = WorldMutationLedgerScript.validate(value)
	if ledger.is_empty():
		return {}
	var adapted: Dictionary = WorldMutationLedgerScript.legacy_arrays_exact(normalized, ledger)
	if (
		adapted.is_empty()
		or adapted[&"destroyed_rocks"] != normalized[&"destroyed_rocks"]
		or adapted[&"placed_rocks"] != normalized[&"placed_rocks"]
	):
		return {}
	var result: Dictionary = normalized.duplicate(true)
	result[&"mutation_ledger"] = ledger
	return result

func _normalize_run(value: Variant) -> Variant:
	if value == null:
		return null
	if not value is Dictionary:
		return false
	return _normalize_run_dictionary(value as Dictionary)

func _normalize_run_dictionary(run: Dictionary) -> Variant:
	var events: Variant = run.get(&"applied_event_ids")
	var run_keys: Variant = _run_keys(run)
	if run_keys == null:
		return false
	var modules: Variant = run.get(
		&"active_module_ids", [String(RuntimeIdsScript.MODULE_WORN_PLATES)]
	)
	var run_drops: Variant = run.get(&"run_drops", [])
	var relay_objectives: Variant = run.get(&"relay_objectives", [])
	var completed_objectives: Variant = (
		run
		. get(
			&"completed_objective_ids",
			(
				[String(RuntimeIdsScript.OBJECTIVE_STARTER_RELAY)]
				if bool(run.get(&"starter_relay_completed", false))
				else []
			),
		)
	)
	if (
		not _exact_keys(run, run_keys as Array[StringName])
		or not events is Array
		or (events as Array).size() > MAX_APPLIED_EVENTS
		or not modules is Array
		or (modules as Array).size() > RunStateScript.MAX_ACTIVE_MODULES
		or not run_drops is Array
		or (run_drops as Array).size() > RunStateScript.MAX_RUN_DROPS
		or not relay_objectives is Array
		or not completed_objectives is Array
	):
		return false
	var normalized_drops: Variant = _normalize_reward_drops(run_drops as Array)
	var normalized_relays: Variant = _normalize_relay_objectives(relay_objectives as Array)
	if normalized_drops == null or normalized_relays == null:
		return false
	var normalized: Dictionary = run.duplicate(true)
	normalized[&"active_module_ids"] = (modules as Array).duplicate()
	normalized[&"relay_objectives"] = normalized_relays
	normalized[&"completed_objective_ids"] = (completed_objectives as Array).duplicate()
	normalized[&"refit_purchase_used"] = run.get(&"refit_purchase_used", false)
	normalized[&"active_modifier_id"] = run.get(
		&"active_modifier_id", String(RuntimeIdsScript.MODIFIER_NEUTRAL)
	)
	normalized[&"worm_cores"] = run.get(&"worm_cores", 0)
	normalized[&"run_drops"] = normalized_drops
	normalized[&"next_drop_sequence"] = run.get(&"next_drop_sequence", 1)
	if not _normalize_run_numbers(normalized):
		return false
	var player_cell: Variant = _normalize_cell(normalized.get(&"player_cell"))
	if (
		player_cell == null
		or not normalized.get(&"run_id") is String
		or not normalized.get(&"phase") is String
		or not normalized.get(&"facing") is String
		or not normalized.get(&"starter_relay_completed") is bool
		or not normalized.get(&"shutdown") is bool
		or not normalized.get(&"refit_purchase_used") is bool
		or not normalized.get(&"active_modifier_id") is String
		or (
			normalized.has(&"first_worm_defeated")
			and not normalized.get(&"first_worm_defeated") is bool
		)
	):
		return false
	normalized[&"player_cell"] = player_cell
	return _restore_normalized_run(normalized)

func _run_keys(run: Dictionary) -> Variant:
	var keys: Array[StringName] = [
		&"state_version",
		&"run_id",
		&"seed",
		&"phase",
		&"player_cell",
		&"facing",
		&"chassis",
		&"max_chassis",
		&"unbanked_scrap",
		&"starter_relay_completed",
		&"shutdown",
		&"applied_event_ids",
	]
	for optional: StringName in [
		&"active_module_ids",
		&"refit_purchase_used",
		&"active_modifier_id",
		&"first_worm_defeated",
	]:
		if run.has(optional):
			keys.append(optional)
	var groups: Array[Array] = [
		[&"relay_objectives", &"completed_objective_ids"],
		[&"worm_cores", &"run_drops", &"next_drop_sequence"],
	]
	for group: Array in groups:
		var count: int = 0
		for key: StringName in group:
			count += int(run.has(key))
		if count not in [0, group.size()]:
			return null
		if count == group.size():
			keys.append_array(group)
	return keys

func _normalize_run_numbers(run: Dictionary) -> bool:
	for key: StringName in [
		&"state_version",
		&"seed",
		&"chassis",
		&"max_chassis",
		&"unbanked_scrap",
		&"worm_cores",
		&"next_drop_sequence",
	]:
		var maximum: int = MAX_SEQUENCE
		if key == &"unbanked_scrap":
			maximum = MAX_WALLET
		elif key == &"worm_cores":
			maximum = RunStateScript.MAX_WORM_CORES
		var number: Variant = _json_integer(run.get(key), 0, maximum)
		if number == null:
			return false
		run[key] = int(number)
	return true

func _restore_normalized_run(normalized: Dictionary) -> Variant:
	if not _run_string_arrays_are_valid(
		normalized[&"applied_event_ids"] as Array, normalized[&"active_module_ids"] as Array
	):
		return false
	var state: RefCounted = RunStateScript.new() as RefCounted
	if (
		not bool(state.call("restore_dictionary", normalized))
		or not _run_cross_invariants(normalized)
	):
		return false
	return state.call("to_dictionary") as Dictionary

func _run_string_arrays_are_valid(events: Array, modules: Array) -> bool:
	for event_id: Variant in events:
		if not event_id is String or (event_id as String).length() > 64:
			return false
	for module_id: Variant in modules:
		if not module_id is String or (module_id as String).length() > 64:
			return false
	return true

func _normalize_reward_drops(values: Array) -> Variant:
	var drops: Array[Dictionary] = []
	for value: Variant in values:
		var drop: Dictionary = value as Dictionary if value is Dictionary else {}
		if not _exact_keys(drop, [&"drop_id", &"source_worm_id", &"cell", &"cores", &"scrap"]):
			return null
		var source: Variant = _json_integer(drop[&"source_worm_id"], 1, MAX_SEQUENCE)
		var cores: Variant = _json_integer(drop[&"cores"], 0, RunStateScript.MAX_WORM_CORES)
		var scrap: Variant = _json_integer(drop[&"scrap"], 0, MAX_WALLET)
		var cell: Variant = _normalize_cell(drop[&"cell"])
		if (
			not drop[&"drop_id"] is String
			or source == null
			or cores == null
			or scrap == null
			or (int(cores) == 0 and int(scrap) == 0)
			or cell == null
		):
			return null
		(
			drops
			. append(
				{
					&"drop_id": str(drop[&"drop_id"]),
					&"source_worm_id": int(source),
					&"cell": cell,
					&"cores": int(cores),
					&"scrap": int(scrap),
				}
			)
		)
	return drops

func _normalize_relay_objectives(values: Array) -> Variant:
	var objectives: Array[Dictionary] = []
	for value: Variant in values:
		var objective: Dictionary = value as Dictionary if value is Dictionary else {}
		if not _exact_keys(objective, [&"objective_id", &"cell"]):
			return null
		var cell: Variant = _normalize_cell(objective[&"cell"])
		if (
			cell == null
			or (
				not objective[&"objective_id"] is String
				and not objective[&"objective_id"] is StringName
			)
		):
			return null
		objectives.append({&"objective_id": str(objective[&"objective_id"]), &"cell": cell})
	return objectives

func _normalize_profile(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var profile: Dictionary = value as Dictionary
	var profile_keys: Array[StringName] = [
		&"state_version",
		&"banked_relay_data",
		&"banked_scrap",
		&"success_count",
		&"failure_count",
		&"pending_modifier_offer",
		&"selected_next_modifier",
		&"last_run_summary",
	]
	if profile.has(&"banked_cores"):
		profile_keys.append(&"banked_cores")
	if not _exact_keys(
		profile,
		profile_keys,
	):
		return {}
	var normalized: Dictionary = profile.duplicate(true)
	normalized[&"banked_cores"] = profile.get(&"banked_cores", 0)
	for key: StringName in [
		&"state_version",
		&"banked_relay_data",
		&"banked_scrap",
		&"banked_cores",
		&"success_count",
		&"failure_count",
	]:
		var number: Variant = _json_integer(normalized.get(key), 0, MAX_WALLET)
		if number == null:
			return {}
		normalized[key] = int(number)
	if not normalized.get(&"selected_next_modifier") is String:
		return {}
	var state: RefCounted = ProfileStateScript.new() as RefCounted
	if not bool(state.call("restore_dictionary", normalized)):
		return {}
	return state.call("to_dictionary") as Dictionary

func _normalize_cells(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_WORLD_ITEMS:
		return null
	var result: Array[Array] = []
	var seen: Dictionary = {}
	for raw_cell: Variant in value as Array:
		var cell: Variant = _normalize_cell(raw_cell)
		if cell == null:
			return null
		var key: String = "%d,%d" % [int(cell[0]), int(cell[1])]
		if seen.has(key):
			return null
		seen[key] = true
		result.append(cell as Array)
	result.sort_custom(_cell_precedes)
	return result

func _normalize_amounts(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_WORLD_ITEMS:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_entry: Variant in value as Array:
		if (
			not raw_entry is Dictionary
			or not _exact_keys(raw_entry as Dictionary, [&"cell", &"amount"])
		):
			return null
		var cell: Variant = _normalize_cell((raw_entry as Dictionary).get(&"cell"))
		var amount: Variant = _json_integer((raw_entry as Dictionary).get(&"amount"), 1, 999)
		if cell == null or amount == null:
			return null
		var key: String = "%d,%d" % [int(cell[0]), int(cell[1])]
		if seen.has(key):
			return null
		seen[key] = true
		result.append({&"cell": cell, &"amount": int(amount)})
	result.sort_custom(_amount_precedes)
	return result

func _normalize_cell(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() != 2:
		return null
	var x: Variant = _json_integer(value[0], -MAX_COORDINATE, MAX_COORDINATE)
	var y: Variant = _json_integer(value[1], -MAX_COORDINATE, MAX_COORDINATE)
	return null if x == null or y == null else [int(x), int(y)]

func _json_integer(value: Variant, minimum: int, maximum: int) -> Variant:
	if not value is int and not value is float:
		return null
	var number: float = float(value)
	if not is_finite(number) or number != floor(number) or number < minimum or number > maximum:
		return null
	return int(number)

func _variant_is_bounded(value: Variant, depth: int = 0) -> bool:
	if depth > 8:
		return false
	if value is Dictionary:
		return _dictionary_is_bounded(value as Dictionary, depth)
	if value is Array:
		return _array_is_bounded(value as Array, depth)
	return not value is String or (value as String).length() <= 256

func _dictionary_is_bounded(value: Dictionary, depth: int) -> bool:
	if value.size() > 128:
		return false
	for child: Variant in value.values():
		if not _variant_is_bounded(child, depth + 1):
			return false
	return true

func _array_is_bounded(value: Array, depth: int) -> bool:
	if value.size() > MAX_WORLD_ITEMS:
		return false
	for child: Variant in value:
		if not _variant_is_bounded(child, depth + 1):
			return false
	return true

func _exact_keys(value: Dictionary, expected: Array[StringName]) -> bool:
	if value.size() != expected.size():
		return false
	for key: StringName in expected:
		if not value.has(key):
			return false
	return true

func _cell_precedes(first: Array, second: Array) -> bool:
	return first[1] < second[1] or (first[1] == second[1] and first[0] < second[0])

func _amount_precedes(first: Dictionary, second: Dictionary) -> bool:
	return _cell_precedes(first[&"cell"] as Array, second[&"cell"] as Array)

func _cell_arrays_overlap(first: Array, second: Array) -> bool:
	var seen: Dictionary = {}
	for cell: Array in first:
		seen["%d,%d" % [int(cell[0]), int(cell[1])]] = true
	for cell: Array in second:
		if seen.has("%d,%d" % [int(cell[0]), int(cell[1])]):
			return true
	return false

func _amounts_overlap_cells(amounts: Array, cells: Array) -> bool:
	var amount_cells: Array = []
	for entry: Dictionary in amounts:
		amount_cells.append(entry[&"cell"])
	return _cell_arrays_overlap(amount_cells, cells)

func _run_cross_invariants(run: Dictionary) -> bool:
	var relay_event: String = "event.relay.completed"
	return (
		bool(run[&"starter_relay_completed"])
		== (relay_event in (run[&"applied_event_ids"] as Array))
	)

func _fault(phase: StringName) -> bool:
	return (
		_fault_injector != null
		and _fault_injector.has_method("should_fail")
		and bool(_fault_injector.call("should_fail", phase))
	)

func _fail_save(message: String) -> bool:
	_status = STATUS_SAVE_FAILED
	_last_error = message
	return false

func _reset_result() -> void:
	_status = STATUS_EMPTY
	_last_error = ""
	_selected_source = ""
	_write_sequence = 0
	_migration_source = 0
	_quarantine_paths.clear()
	_writes_blocked = false
	_last_committed_envelope.clear()
	_default_farm = FarmSaveSchemaScript.make_neutral(_configured_default_mode)
