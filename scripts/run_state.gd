extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const STATE_VERSION: int = 1
const COORDINATE_LIMIT: int = 1_000_000
const MAX_ACTIVE_MODULES: int = 3
const MAX_RUN_DROPS: int = 64
const MAX_WORM_CORES: int = 999
const MAX_RUN_SCRAP: int = 1_000_000_000
const VALID_FACINGS: Array[StringName] = [&"N", &"NE", &"E", &"SE", &"S", &"SW", &"W", &"NW"]

var _run_id: StringName
var _seed: int
var _phase: StringName = RuntimeIdsScript.RUN_PHASE_BOOTSTRAP
var _player_cell: Vector2i
var _facing: StringName
var _chassis: int
var _max_chassis: int
var _unbanked_scrap: int = 0
var _worm_cores: int = 0
var _first_worm_defeated: bool = false
var _run_drops: Array[Dictionary] = []
var _next_drop_sequence: int = 1
var _starter_relay_completed: bool = false
var _relay_objectives: Array[Dictionary] = []
var _completed_objective_ids: Array[StringName] = []
var _shutdown: bool = false
var _active_module_ids: Array[StringName] = [RuntimeIdsScript.MODULE_WORN_PLATES]
var _refit_purchase_used: bool = false
var _active_modifier_id: StringName = RuntimeIdsScript.MODIFIER_NEUTRAL
var _applied_event_ids: Dictionary = {}


func configure(
	run_id: StringName,
	seed: int,
	max_chassis: int,
	start_cell: Vector2i,
	facing: StringName,
) -> bool:
	if (
		not _is_valid_run_id(run_id)
		or max_chassis <= 0
		or not _is_valid_cell(start_cell)
		or facing not in VALID_FACINGS
	):
		return false
	_run_id = run_id
	_seed = seed
	_max_chassis = max_chassis
	_player_cell = start_cell
	_facing = facing
	_chassis = max_chassis
	return true


func transition_to(next_phase: StringName) -> bool:
	var allowed: Dictionary = {
		RuntimeIdsScript.RUN_PHASE_BOOTSTRAP: [RuntimeIdsScript.RUN_PHASE_HUNT],
		RuntimeIdsScript.RUN_PHASE_HUNT:
		[
			RuntimeIdsScript.RUN_PHASE_EXTRACTION_READY,
			RuntimeIdsScript.RUN_PHASE_FAILED,
		],
		RuntimeIdsScript.RUN_PHASE_EXTRACTION_READY:
		[
			RuntimeIdsScript.RUN_PHASE_SUCCEEDED,
			RuntimeIdsScript.RUN_PHASE_FAILED,
		],
		RuntimeIdsScript.RUN_PHASE_SUCCEEDED: [],
		RuntimeIdsScript.RUN_PHASE_FAILED: [],
	}
	if next_phase not in allowed.get(_phase, []):
		return false
	_phase = next_phase
	return true


func apply_event(event_id: StringName) -> bool:
	if not RuntimeIdsScript.is_event_id(event_id) or _applied_event_ids.has(event_id):
		return false
	_applied_event_ids[event_id] = true
	return true


func add_module(module_id: StringName) -> bool:
	if (
		module_id not in RuntimeIdsScript.catalog()[&"modules"]
		or module_id in _active_module_ids
		or _active_module_ids.size() >= MAX_ACTIVE_MODULES
	):
		return false
	_active_module_ids.append(module_id)
	return true


func has_module(module_id: StringName) -> bool:
	return module_id in _active_module_ids


func _configure_relay_objectives(objectives: Array[Dictionary]) -> bool:
	if not _relay_objectives.is_empty() or not _relay_layout_is_valid(objectives):
		return false
	_relay_objectives = objectives.duplicate(true)
	if _starter_relay_completed and _completed_objective_ids.is_empty():
		_completed_objective_ids.append(RuntimeIdsScript.OBJECTIVE_STARTER_RELAY)
	return true


func _complete_next_relay(objective_id: StringName) -> bool:
	var index: int = _completed_objective_ids.size()
	if (
		index >= _relay_objectives.size()
		or _relay_objectives[index][&"objective_id"] != objective_id
	):
		return false
	_completed_objective_ids.append(objective_id)
	_starter_relay_completed = true
	if _completed_objective_ids.size() == 3 and _phase == RuntimeIdsScript.RUN_PHASE_HUNT:
		transition_to(RuntimeIdsScript.RUN_PHASE_EXTRACTION_READY)
	return true


func _get_relay_objectives() -> Array[Dictionary]:
	return _relay_objectives.duplicate(true)


func _place_drop(cell: Vector2i, cores: int, scrap: int, source_worm_id: int) -> Dictionary:
	if (
		not _is_valid_cell(cell)
		or cores < 0
		or scrap < 0
		or (cores == 0 and scrap == 0)
		or source_worm_id <= 0
		or _run_drops.size() >= MAX_RUN_DROPS
		or _next_drop_sequence > 999_999
		or _drop_conflicts(cell, source_worm_id)
	):
		return {}
	var drop: Dictionary = {
		&"drop_id": "drop.worm.%06d" % _next_drop_sequence,
		&"source_worm_id": source_worm_id,
		&"cell": [cell.x, cell.y],
		&"cores": cores,
		&"scrap": scrap,
	}
	_next_drop_sequence += 1
	_run_drops.append(drop)
	return drop.duplicate(true)


func _collect_drop_at(cell: Vector2i) -> Dictionary:
	for index: int in range(_run_drops.size()):
		var drop: Dictionary = _run_drops[index]
		if _decode_cell(drop[&"cell"]) != cell:
			continue
		var cores: int = int(drop[&"cores"])
		var scrap: int = int(drop[&"scrap"])
		if _worm_cores + cores > MAX_WORM_CORES or _unbanked_scrap + scrap > MAX_RUN_SCRAP:
			return {}
		_worm_cores += cores
		_unbanked_scrap += scrap
		_run_drops.remove_at(index)
		return drop.duplicate(true)
	return {}


func _get_run_drops() -> Array[Dictionary]:
	return _run_drops.duplicate(true)


func set_value(key: StringName, value: Variant) -> bool:
	var changed: bool = false
	match key:
		&"player_cell":
			changed = _set_player_cell(value)
		&"facing":
			changed = _set_facing(value)
		&"chassis":
			changed = _set_chassis(value)
		&"scrap":
			changed = _set_scrap(value)
		&"worm_cores":
			changed = _set_worm_cores(value)
		&"first_worm_defeated":
			changed = _set_first_worm_defeated(value)
		&"refit_purchase_used":
			changed = _set_refit_purchase_used(value)
		&"active_modifier_id":
			changed = _set_active_modifier(value)
		&"starter_relay_completed":
			changed = _set_starter_relay_completed(value)
		&"shutdown":
			changed = _set_shutdown(value)
	return changed


func get_value(key: StringName) -> Variant:
	var value: Variant = null
	match key:
		&"run_id":
			value = _run_id
		&"seed":
			value = _seed
		&"phase":
			value = _phase
		&"player_cell":
			value = _player_cell
		&"facing":
			value = _facing
		&"chassis":
			value = _chassis
		&"max_chassis":
			value = _max_chassis
		&"scrap":
			value = _unbanked_scrap
		&"worm_cores":
			value = _worm_cores
		&"first_worm_defeated":
			value = _first_worm_defeated
		&"starter_relay_completed":
			value = _starter_relay_completed
		&"completed_relays":
			value = _completed_objective_ids.size()
		&"relay_objectives":
			value = _relay_objectives.duplicate(true)
		&"completed_objective_ids":
			value = _completed_objective_ids.duplicate()
		&"shutdown":
			value = _shutdown
		&"active_module_ids":
			value = _active_module_ids.duplicate()
		&"refit_purchase_used":
			value = _refit_purchase_used
		&"active_modifier_id":
			value = _active_modifier_id
	return value


func to_dictionary() -> Dictionary:
	return {
		&"state_version": STATE_VERSION,
		&"run_id": String(_run_id),
		&"seed": _seed,
		&"phase": String(_phase),
		&"player_cell": [_player_cell.x, _player_cell.y],
		&"facing": String(_facing),
		&"chassis": _chassis,
		&"max_chassis": _max_chassis,
		&"unbanked_scrap": _unbanked_scrap,
		&"worm_cores": _worm_cores,
		&"first_worm_defeated": _first_worm_defeated,
		&"run_drops": _run_drops.duplicate(true),
		&"next_drop_sequence": _next_drop_sequence,
		&"starter_relay_completed": _starter_relay_completed,
		&"relay_objectives": _relay_objectives.duplicate(true),
		&"completed_objective_ids": _string_names(_completed_objective_ids),
		&"shutdown": _shutdown,
		&"active_module_ids": _string_names(_active_module_ids),
		&"refit_purchase_used": _refit_purchase_used,
		&"active_modifier_id": String(_active_modifier_id),
		&"applied_event_ids": _sorted_string_keys(_applied_event_ids),
	}


func restore_dictionary(snapshot: Dictionary) -> bool:
	var validated: Dictionary = _validate_dictionary(snapshot)
	if validated.is_empty():
		return false
	_run_id = validated[&"run_id"] as StringName
	_seed = int(validated[&"seed"])
	_phase = validated[&"phase"] as StringName
	_player_cell = validated[&"player_cell"] as Vector2i
	_facing = validated[&"facing"] as StringName
	_chassis = int(validated[&"chassis"])
	_max_chassis = int(validated[&"max_chassis"])
	_unbanked_scrap = int(validated[&"unbanked_scrap"])
	_worm_cores = int(validated[&"worm_cores"])
	_first_worm_defeated = bool(validated[&"first_worm_defeated"])
	_run_drops = validated[&"run_drops"] as Array[Dictionary]
	_next_drop_sequence = int(validated[&"next_drop_sequence"])
	_starter_relay_completed = bool(validated[&"starter_relay_completed"])
	_relay_objectives.clear()
	for objective: Dictionary in validated[&"relay_objectives"] as Array:
		_relay_objectives.append(objective.duplicate(true))
	_completed_objective_ids.clear()
	for objective_id: StringName in validated[&"completed_objective_ids"] as Array:
		_completed_objective_ids.append(objective_id)
	_shutdown = bool(validated[&"shutdown"])
	_active_module_ids = validated[&"active_module_ids"] as Array[StringName]
	_refit_purchase_used = bool(validated[&"refit_purchase_used"])
	_active_modifier_id = validated[&"active_modifier_id"] as StringName
	_applied_event_ids = validated[&"applied_event_ids"] as Dictionary
	return true


func legacy_snapshot() -> Dictionary:
	return {
		&"scrap_total": _unbanked_scrap,
		&"chassis": _chassis,
		&"robot_cell": [_player_cell.x, _player_cell.y],
		&"facing": String(_facing),
		&"relay_completed": _starter_relay_completed,
	}


func restore_legacy_snapshot(snapshot: Dictionary, player_cell: Vector2i) -> bool:
	var candidate: Dictionary = to_dictionary()
	candidate[&"player_cell"] = [player_cell.x, player_cell.y]
	candidate[&"facing"] = str(snapshot.get("facing", ""))
	candidate[&"chassis"] = int(snapshot.get("chassis", _max_chassis))
	candidate[&"unbanked_scrap"] = int(snapshot.get("scrap_total", -1))
	candidate[&"starter_relay_completed"] = bool(snapshot.get("relay_completed", false))
	candidate[&"shutdown"] = false
	candidate[&"phase"] = String(RuntimeIdsScript.RUN_PHASE_HUNT)
	return restore_dictionary(candidate)


func _set_player_cell(value: Variant) -> bool:
	if not value is Vector2i or not _is_valid_cell(value as Vector2i):
		return false
	_player_cell = value as Vector2i
	return true


func _set_facing(value: Variant) -> bool:
	var facing: StringName = value as StringName if value is StringName else StringName(str(value))
	if facing not in VALID_FACINGS:
		return false
	_facing = facing
	return true


func _set_chassis(value: Variant) -> bool:
	if (
		not value is int
		or int(value) < 0
		or int(value) > _max_chassis
		or (_shutdown and int(value) != 0)
	):
		return false
	_chassis = int(value)
	return true


func _set_scrap(value: Variant) -> bool:
	if not value is int or int(value) < 0 or int(value) > MAX_RUN_SCRAP:
		return false
	_unbanked_scrap = int(value)
	return true


func _set_worm_cores(value: Variant) -> bool:
	if not value is int or int(value) < 0 or int(value) > MAX_WORM_CORES:
		return false
	_worm_cores = int(value)
	return true


func _set_first_worm_defeated(value: Variant) -> bool:
	if not value is bool or not bool(value) or _first_worm_defeated:
		return false
	_first_worm_defeated = true
	return true


func _set_refit_purchase_used(value: Variant) -> bool:
	if not value is bool or not bool(value) or _refit_purchase_used:
		return false
	_refit_purchase_used = true
	return true


func _set_active_modifier(value: Variant) -> bool:
	var modifier_id: StringName = StringName(str(value))
	if modifier_id not in RuntimeIdsScript.catalog()[&"modifiers"]:
		return false
	_active_modifier_id = modifier_id
	return true


func _set_starter_relay_completed(value: Variant) -> bool:
	if not value is bool or not bool(value) or _starter_relay_completed:
		return false
	_starter_relay_completed = true
	if _completed_objective_ids.is_empty():
		_completed_objective_ids.append(RuntimeIdsScript.OBJECTIVE_STARTER_RELAY)
	return true


func _set_shutdown(value: Variant) -> bool:
	if (
		not value is bool
		or not bool(value)
		or _shutdown
		or _chassis != 0
		or not transition_to(RuntimeIdsScript.RUN_PHASE_FAILED)
	):
		return false
	_shutdown = true
	return true


func _validate_dictionary(snapshot: Dictionary) -> Dictionary:
	if not _has_typed_fields(snapshot) or int(snapshot["state_version"]) != STATE_VERSION:
		return {}
	var run_id: StringName = StringName(str(snapshot.get("run_id", "")))
	var phase: StringName = StringName(str(snapshot.get("phase", "")))
	var player_cell: Vector2i = _decode_cell(snapshot.get("player_cell", []))
	var facing: StringName = StringName(str(snapshot.get("facing", "")))
	var chassis: int = int(snapshot.get("chassis", -1))
	var max_chassis: int = int(snapshot.get("max_chassis", -1))
	var scrap: int = int(snapshot.get("unbanked_scrap", -1))
	var worm_cores: Variant = snapshot.get("worm_cores", 0)
	var run_drops: Variant = snapshot.get("run_drops", [])
	var prior_worm_reward: bool = (
		(worm_cores is int and int(worm_cores) > 0)
		or (run_drops is Array and not (run_drops as Array).is_empty())
	)
	var first_worm_defeated: Variant = snapshot.get("first_worm_defeated", prior_worm_reward)
	var next_drop_sequence: Variant = snapshot.get("next_drop_sequence", 1)
	var relay_completed: Variant = snapshot.get("starter_relay_completed", null)
	var relay_objectives: Variant = snapshot.get("relay_objectives", [])
	var completed_objectives: Variant = (
		snapshot
		. get(
			"completed_objective_ids",
			[String(RuntimeIdsScript.OBJECTIVE_STARTER_RELAY)] if bool(relay_completed) else [],
		)
	)
	var shutdown: Variant = snapshot.get("shutdown", null)
	var active_modules: Variant = snapshot.get(
		"active_module_ids", [String(RuntimeIdsScript.MODULE_WORN_PLATES)]
	)
	var refit_purchase_used: Variant = snapshot.get("refit_purchase_used", false)
	var active_modifier: StringName = StringName(
		str(snapshot.get("active_modifier_id", RuntimeIdsScript.MODIFIER_NEUTRAL))
	)
	var applied_events: Variant = snapshot.get("applied_event_ids", null)
	if (
		not _is_valid_run_id(run_id)
		or phase not in RuntimeIdsScript.catalog()[&"run_phases"]
		or player_cell == Vector2i(COORDINATE_LIMIT + 1, COORDINATE_LIMIT + 1)
		or facing not in VALID_FACINGS
		or max_chassis <= 0
		or chassis < 0
		or chassis > max_chassis
		or scrap < 0
		or scrap > MAX_RUN_SCRAP
		or not worm_cores is int
		or int(worm_cores) < 0
		or int(worm_cores) > MAX_WORM_CORES
		or not first_worm_defeated is bool
		or not run_drops is Array
		or (run_drops as Array).size() > MAX_RUN_DROPS
		or not next_drop_sequence is int
		or int(next_drop_sequence) <= 0
		or not relay_completed is bool
		or not relay_objectives is Array
		or not completed_objectives is Array
		or not shutdown is bool
		or not active_modules is Array
		or (active_modules as Array).size() > MAX_ACTIVE_MODULES
		or not refit_purchase_used is bool
		or active_modifier not in RuntimeIdsScript.catalog()[&"modifiers"]
		or not applied_events is Array
		or (bool(shutdown) and (chassis != 0 or phase != RuntimeIdsScript.RUN_PHASE_FAILED))
	):
		return {}
	var module_ids: Array[StringName] = _validate_module_ids(active_modules as Array)
	var relay_validation: Dictionary = _validate_relay_state(
		relay_objectives as Array, completed_objectives as Array, bool(relay_completed)
	)
	var drop_validation: Dictionary = _validate_run_drops(
		run_drops as Array, int(next_drop_sequence), player_cell
	)
	var event_validation: Dictionary = _validate_event_ids(applied_events as Array)
	if (
		module_ids.is_empty()
		or not bool(relay_validation.get(&"valid", false))
		or not bool(drop_validation.get(&"valid", false))
		or not bool(event_validation.get(&"valid", false))
	):
		return {}
	return {
		&"run_id": run_id,
		&"seed": int(snapshot.get("seed", 0)),
		&"phase": phase,
		&"player_cell": player_cell,
		&"facing": facing,
		&"chassis": chassis,
		&"max_chassis": max_chassis,
		&"unbanked_scrap": scrap,
		&"worm_cores": int(worm_cores),
		&"first_worm_defeated": bool(first_worm_defeated),
		&"run_drops": drop_validation[&"drops"],
		&"next_drop_sequence": int(next_drop_sequence),
		&"starter_relay_completed": bool(relay_completed),
		&"relay_objectives": relay_validation[&"objectives"],
		&"completed_objective_ids": relay_validation[&"completed"],
		&"shutdown": bool(shutdown),
		&"active_module_ids": module_ids,
		&"refit_purchase_used": bool(refit_purchase_used),
		&"active_modifier_id": active_modifier,
		&"applied_event_ids": event_validation[&"events"],
	}


func _validate_module_ids(values: Array) -> Array[StringName]:
	var module_ids: Array[StringName] = []
	for raw_module: Variant in values:
		if not raw_module is String and not raw_module is StringName:
			return []
		var module_id: StringName = StringName(str(raw_module))
		if module_id not in RuntimeIdsScript.catalog()[&"modules"] or module_id in module_ids:
			return []
		module_ids.append(module_id)
	return module_ids if RuntimeIdsScript.MODULE_WORN_PLATES in module_ids else []


func _validate_relay_state(objectives: Array, completed: Array, starter_done: bool) -> Dictionary:
	if objectives.is_empty():
		var legacy_completed: Array[StringName] = []
		if starter_done:
			legacy_completed.append(RuntimeIdsScript.OBJECTIVE_STARTER_RELAY)
		return {
			&"valid": completed.is_empty() or completed == _string_names(legacy_completed),
			&"objectives": [],
			&"completed": legacy_completed,
		}
	if not _relay_layout_is_valid(objectives) or completed.size() > objectives.size():
		return {}
	var completed_ids: Array[StringName] = []
	for index: int in range(completed.size()):
		var objective_id: StringName = StringName(str(completed[index]))
		if objectives[index][&"objective_id"] != objective_id:
			return {}
		completed_ids.append(objective_id)
	if starter_done != (not completed_ids.is_empty()):
		return {}
	return {&"valid": true, &"objectives": objectives.duplicate(true), &"completed": completed_ids}


func _relay_layout_is_valid(objectives: Array) -> bool:
	if objectives.size() != 3:
		return false
	var expected: Array[StringName] = [
		RuntimeIdsScript.OBJECTIVE_STARTER_RELAY,
		RuntimeIdsScript.OBJECTIVE_RELAY_TWO,
		RuntimeIdsScript.OBJECTIVE_RELAY_THREE,
	]
	var cells: Dictionary = {}
	for index: int in range(3):
		var objective: Dictionary = objectives[index]
		if objective.size() != 2 or objective.get(&"objective_id") != expected[index]:
			return false
		var raw_cell: Variant = objective.get(&"cell", [])
		var cell: Vector2i = (
			raw_cell as Vector2i if raw_cell is Vector2i else _decode_cell(raw_cell)
		)
		if cell == Vector2i(COORDINATE_LIMIT + 1, COORDINATE_LIMIT + 1) or cells.has(cell):
			return false
		objective[&"cell"] = [cell.x, cell.y]
		cells[cell] = true
	return true


func _validate_event_ids(values: Array) -> Dictionary:
	var events: Dictionary = {}
	for raw_event: Variant in values:
		if not raw_event is String and not raw_event is StringName:
			return {}
		var event_id: StringName = StringName(str(raw_event))
		if not RuntimeIdsScript.is_event_id(event_id) or events.has(event_id):
			return {}
		events[event_id] = true
	return {&"valid": true, &"events": events}


func _validate_run_drops(values: Array, next_sequence: int, player_cell: Vector2i) -> Dictionary:
	if next_sequence > 1_000_000:
		return {}
	var drops: Array[Dictionary] = []
	var ids: Dictionary = {}
	var sources: Dictionary = {}
	var cells: Dictionary = {}
	for value: Variant in values:
		var drop: Dictionary = value as Dictionary if value is Dictionary else {}
		var normalized: Dictionary = _validate_run_drop(drop, next_sequence, player_cell)
		if normalized.is_empty():
			return {}
		if ids.has(normalized[&"drop_id"]) or sources.has(normalized[&"source_worm_id"]):
			return {}
		var normalized_cell: Array = normalized[&"cell"] as Array
		var cell_key: String = "%d,%d" % [int(normalized_cell[0]), int(normalized_cell[1])]
		if cells.has(cell_key):
			return {}
		ids[normalized[&"drop_id"]] = true
		sources[normalized[&"source_worm_id"]] = true
		cells[cell_key] = true
		drops.append(normalized)
	return {&"valid": true, &"drops": drops}


func _validate_run_drop(drop: Dictionary, next_sequence: int, _player_cell: Vector2i) -> Dictionary:
	var required: Array[StringName] = [&"drop_id", &"source_worm_id", &"cell", &"cores", &"scrap"]
	if drop.size() != required.size():
		return {}
	for key: StringName in required:
		if not drop.has(key):
			return {}
	var sequence: int = _drop_id_sequence(drop[&"drop_id"])
	var cell: Vector2i = _decode_cell(drop[&"cell"])
	if (
		sequence <= 0
		or sequence >= next_sequence
		or not drop[&"source_worm_id"] is int
		or int(drop[&"source_worm_id"]) <= 0
		or cell == Vector2i(COORDINATE_LIMIT + 1, COORDINATE_LIMIT + 1)
		or not drop[&"cores"] is int
		or int(drop[&"cores"]) < 0
		or int(drop[&"cores"]) > MAX_WORM_CORES
		or not drop[&"scrap"] is int
		or int(drop[&"scrap"]) < 0
		or int(drop[&"scrap"]) > MAX_RUN_SCRAP
		or (int(drop[&"cores"]) == 0 and int(drop[&"scrap"]) == 0)
	):
		return {}
	return {
		&"drop_id": "drop.worm.%06d" % sequence,
		&"source_worm_id": int(drop[&"source_worm_id"]),
		&"cell": [cell.x, cell.y],
		&"cores": int(drop[&"cores"]),
		&"scrap": int(drop[&"scrap"]),
	}


func _drop_id_sequence(value: Variant) -> int:
	if not value is String and not value is StringName:
		return -1
	var drop_id: String = str(value)
	if not drop_id.begins_with("drop.worm."):
		return -1
	var suffix: String = drop_id.trim_prefix("drop.worm.")
	var sequence: int = suffix.to_int()
	return sequence if suffix == "%06d" % sequence else -1


func _drop_conflicts(cell: Vector2i, source_worm_id: int) -> bool:
	for drop: Dictionary in _run_drops:
		if _decode_cell(drop[&"cell"]) == cell or int(drop[&"source_worm_id"]) == source_worm_id:
			return true
	return false


func _decode_cell(value: Variant) -> Vector2i:
	if (
		not value is Array
		or (value as Array).size() != 2
		or not value[0] is int
		or not value[1] is int
	):
		return Vector2i(COORDINATE_LIMIT + 1, COORDINATE_LIMIT + 1)
	var cell: Vector2i = Vector2i(int(value[0]), int(value[1]))
	return cell if _is_valid_cell(cell) else Vector2i(COORDINATE_LIMIT + 1, COORDINATE_LIMIT + 1)


func _is_valid_cell(cell: Vector2i) -> bool:
	return absi(cell.x) <= COORDINATE_LIMIT and absi(cell.y) <= COORDINATE_LIMIT


func _is_valid_run_id(run_id: StringName) -> bool:
	var value: String = String(run_id)
	if not value.begins_with("run.") or value.length() > 64:
		return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 46:
			return false
	return true


func _has_typed_fields(snapshot: Dictionary) -> bool:
	return (
		snapshot.get("state_version") is int
		and (snapshot.get("run_id") is String or snapshot.get("run_id") is StringName)
		and snapshot.get("seed") is int
		and (snapshot.get("phase") is String or snapshot.get("phase") is StringName)
		and snapshot.get("player_cell") is Array
		and (snapshot.get("facing") is String or snapshot.get("facing") is StringName)
		and snapshot.get("chassis") is int
		and snapshot.get("max_chassis") is int
		and snapshot.get("unbanked_scrap") is int
		and snapshot.get("starter_relay_completed") is bool
		and snapshot.get("shutdown") is bool
		and snapshot.get("applied_event_ids") is Array
	)


func _string_names(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


func _sorted_string_keys(values: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: Variant in values:
		result.append(str(key))
	result.sort()
	return result
