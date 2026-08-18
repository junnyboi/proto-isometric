extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const STATE_VERSION: int = 1
const COORDINATE_LIMIT: int = 1_000_000
const VALID_FACINGS: Array[StringName] = [&"N", &"NE", &"E", &"SE", &"S", &"SW", &"W", &"NW"]

var _run_id: StringName
var _seed: int
var _phase: StringName = RuntimeIdsScript.RUN_PHASE_BOOTSTRAP
var _player_cell: Vector2i
var _facing: StringName
var _chassis: int
var _max_chassis: int
var _unbanked_scrap: int = 0
var _starter_relay_completed: bool = false
var _shutdown: bool = false
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
		&"starter_relay_completed":
			changed = _set_starter_relay_completed(value)
		&"shutdown":
			changed = _set_shutdown(value)
	return changed


func get_value(key: StringName) -> Variant:
	return (
		{
			&"run_id": _run_id,
			&"seed": _seed,
			&"phase": _phase,
			&"player_cell": _player_cell,
			&"facing": _facing,
			&"chassis": _chassis,
			&"max_chassis": _max_chassis,
			&"scrap": _unbanked_scrap,
			&"starter_relay_completed": _starter_relay_completed,
			&"shutdown": _shutdown,
		}
		. get(key)
	)


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
		&"starter_relay_completed": _starter_relay_completed,
		&"shutdown": _shutdown,
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
	_starter_relay_completed = bool(validated[&"starter_relay_completed"])
	_shutdown = bool(validated[&"shutdown"])
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
	if not value is int or int(value) < 0:
		return false
	_unbanked_scrap = int(value)
	return true


func _set_starter_relay_completed(value: Variant) -> bool:
	if not value is bool or not bool(value) or _starter_relay_completed:
		return false
	_starter_relay_completed = true
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
	var relay_completed: Variant = snapshot.get("starter_relay_completed", null)
	var shutdown: Variant = snapshot.get("shutdown", null)
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
		or not relay_completed is bool
		or not shutdown is bool
		or not applied_events is Array
		or (bool(shutdown) and (chassis != 0 or phase != RuntimeIdsScript.RUN_PHASE_FAILED))
	):
		return {}
	var event_set: Dictionary = {}
	for raw_event: Variant in applied_events as Array:
		if not raw_event is String and not raw_event is StringName:
			return {}
		var event_id: StringName = StringName(str(raw_event))
		if not RuntimeIdsScript.is_event_id(event_id) or event_set.has(event_id):
			return {}
		event_set[event_id] = true
	return {
		&"run_id": run_id,
		&"seed": int(snapshot.get("seed", 0)),
		&"phase": phase,
		&"player_cell": player_cell,
		&"facing": facing,
		&"chassis": chassis,
		&"max_chassis": max_chassis,
		&"unbanked_scrap": scrap,
		&"starter_relay_completed": bool(relay_completed),
		&"shutdown": bool(shutdown),
		&"applied_event_ids": event_set,
	}


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


func _sorted_string_keys(values: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: Variant in values:
		result.append(str(key))
	result.sort()
	return result
