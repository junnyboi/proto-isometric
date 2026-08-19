extends RefCounted

const RunStateScript: GDScript = preload("res://scripts/run_state.gd")
const ProfileStateScript: GDScript = preload("res://scripts/profile_state.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const TARGET_VERSION: int = 3
const WORLD_GENERATION_VERSION: int = 1
const COORDINATE_LIMIT: int = 1_000_000
const LEGACY_GRID_SIZE: int = 18
const MAX_WORLD_ENTRIES: int = 100_000
const MAX_SCRAP_AMOUNT: int = 999
const MAX_WALLET: int = 1_000_000_000
const VALID_FACINGS: Array[StringName] = [&"N", &"NE", &"E", &"SE", &"S", &"SW", &"W", &"NW"]
const STARTER_ROCKS: Array[Vector2i] = [
	Vector2i(2, 3),
	Vector2i(3, 3),
	Vector2i(4, 4),
	Vector2i(12, 2),
	Vector2i(13, 3),
	Vector2i(14, 4),
	Vector2i(5, 12),
	Vector2i(6, 13),
	Vector2i(11, 12),
	Vector2i(12, 12),
	Vector2i(13, 11),
	Vector2i(15, 14),
	Vector2i(3, 15),
]
const STARTER_SCRAP: Dictionary = {
	Vector2i(9, 9): 1,
	Vector2i(10, 7): 2,
	Vector2i(7, 13): 1,
	Vector2i(14, 8): 2,
}

var _world_validator: RefCounted
var _max_chassis: int = 100
var _last_error: String = ""
var _source_version: int = 0


func configure(world_validator: RefCounted, max_chassis: int = 100) -> bool:
	_last_error = ""
	_source_version = 0
	if world_validator == null or not world_validator.has_method("is_valid_cell"):
		_last_error = "A world validator with is_valid_cell() is required."
		return false
	if max_chassis <= 0 or max_chassis > MAX_WALLET:
		_last_error = "Maximum chassis is out of range."
		return false
	_world_validator = world_validator
	_max_chassis = max_chassis
	return true


func migrate(snapshot: Dictionary) -> Dictionary:
	_last_error = ""
	_source_version = 0
	if _world_validator == null:
		_last_error = "SaveMigrator is not configured."
		return {}
	if not snapshot.has("schema"):
		_last_error = "Legacy save is missing schema."
		return {}
	var schema_result: Dictionary = _strict_integer(snapshot["schema"], 0, 2_147_483_647)
	if schema_result.is_empty():
		_last_error = "Legacy save schema must be a finite integral number."
		return {}
	_source_version = int(schema_result[&"value"])
	if _source_version not in [1, 2]:
		_last_error = "Unsupported or future save schema: %d." % _source_version
		return {}
	return _build_migration(snapshot)


func _build_migration(snapshot: Dictionary) -> Dictionary:
	var normalized: Dictionary = (
		_normalize_schema_one(snapshot) if _source_version == 1 else _normalize_schema_two(snapshot)
	)
	if normalized.is_empty():
		return {}
	var active_run: Dictionary = _make_active_run(normalized)
	if active_run.is_empty():
		return {}
	var profile: RefCounted = ProfileStateScript.new() as RefCounted
	return {
		&"save_format_version": TARGET_VERSION,
		&"metadata":
		{
			&"build_id": "legacy-migration",
			&"world_generation_version": WORLD_GENERATION_VERSION,
			&"write_sequence": 0,
			&"saved_at_unix": 0,
			&"migration_source": _source_version,
		},
		&"world": (normalized[&"world"] as Dictionary).duplicate(true),
		&"active_run": active_run,
		&"profile": profile.call("to_dictionary") as Dictionary,
	}


func get_last_error() -> String:
	return _last_error


func get_source_version() -> int:
	return _source_version


func _normalize_schema_one(snapshot: Dictionary) -> Dictionary:
	var header: Dictionary = _schema_one_header(snapshot)
	if header.is_empty():
		return {}
	var player_cell: Vector2i = header[&"player_cell"] as Vector2i
	var rocks: Dictionary = _decode_cell_array(
		snapshot["rocks"], LEGACY_GRID_SIZE * LEGACY_GRID_SIZE, true, player_cell
	)
	if rocks.is_empty() and not _last_error.is_empty():
		return {}
	var scrap: Dictionary = _decode_amount_array(
		snapshot["scrap"], LEGACY_GRID_SIZE * LEGACY_GRID_SIZE, true
	)
	if scrap.is_empty() and not _last_error.is_empty():
		return {}
	var rock_set: Dictionary = rocks[&"set"] as Dictionary
	for raw_scrap_cell: Variant in scrap[&"set"]:
		if rock_set.has(raw_scrap_cell):
			_last_error = "Schema 1 scrap cannot occupy a surviving rock cell."
			return {}
	var common: Dictionary = _normalize_common(snapshot, player_cell, false)
	if common.is_empty():
		return {}
	var destroyed: Dictionary = {}
	var placed: Dictionary = {}
	for starter_cell: Vector2i in STARTER_ROCKS:
		if not rock_set.has(starter_cell):
			destroyed[starter_cell] = true
	for raw_rock_cell: Variant in rock_set:
		var rock_cell: Vector2i = raw_rock_cell as Vector2i
		if rock_cell not in STARTER_ROCKS:
			placed[rock_cell] = true
	var collected: Dictionary = {}
	var scrap_set: Dictionary = scrap[&"set"] as Dictionary
	for raw_starter_scrap: Variant in STARTER_SCRAP:
		var starter_scrap: Vector2i = raw_starter_scrap as Vector2i
		if not scrap_set.has(starter_scrap):
			collected[starter_scrap] = true
	common[&"world"] = {
		&"destroyed_rocks": _encode_cells(destroyed),
		&"placed_rocks": _encode_cells(placed),
		&"dropped_scrap": (scrap[&"entries"] as Array).duplicate(true),
		&"collected_scrap": _encode_cells(collected),
	}
	return common


func _schema_one_header(snapshot: Dictionary) -> Dictionary:
	if not _contains_only(
		snapshot,
		["schema", "grid_size", "rocks", "scrap", "scrap_total", "chassis", "robot_cell", "facing"],
	):
		_last_error = "Schema 1 save contains unrecognized fields."
		return {}
	for field: String in ["grid_size", "rocks", "scrap", "scrap_total", "robot_cell", "facing"]:
		if not snapshot.has(field):
			_last_error = "Schema 1 save is missing required field: %s." % field
			return {}
	var grid: Variant = snapshot["grid_size"]
	if not grid is Array or (grid as Array).size() != 2:
		_last_error = "Schema 1 grid_size must be [18, 18]."
		return {}
	var grid_x: Dictionary = _strict_integer((grid as Array)[0], LEGACY_GRID_SIZE, LEGACY_GRID_SIZE)
	var grid_y: Dictionary = _strict_integer((grid as Array)[1], LEGACY_GRID_SIZE, LEGACY_GRID_SIZE)
	if grid_x.is_empty() or grid_y.is_empty():
		_last_error = "Schema 1 grid_size must be [18, 18]."
		return {}
	var player_result: Dictionary = _decode_cell(snapshot["robot_cell"], true)
	if player_result.is_empty():
		_last_error = "Schema 1 robot_cell is malformed or out of range."
		return {}
	return {&"player_cell": player_result[&"cell"]}


func _normalize_schema_two(snapshot: Dictionary) -> Dictionary:
	var header: Dictionary = _schema_two_header(snapshot)
	if header.is_empty():
		return {}
	var player_cell: Vector2i = header[&"player_cell"] as Vector2i
	var world: Dictionary = _schema_two_world(snapshot, player_cell)
	if world.is_empty():
		return {}
	var common: Dictionary = _normalize_common(snapshot, player_cell, true)
	if common.is_empty():
		return {}
	common[&"world"] = world
	return common


func _schema_two_header(snapshot: Dictionary) -> Dictionary:
	if not _contains_only(
		snapshot,
		[
			"schema",
			"destroyed_rocks",
			"placed_rocks",
			"dropped_scrap",
			"collected_scrap",
			"scrap_total",
			"chassis",
			"robot_cell",
			"facing",
			"relay_completed",
		],
	):
		_last_error = "Schema 2 save contains unrecognized fields."
		return {}
	for field: String in [
		"destroyed_rocks",
		"placed_rocks",
		"dropped_scrap",
		"collected_scrap",
		"scrap_total",
		"robot_cell",
		"facing",
	]:
		if not snapshot.has(field):
			_last_error = "Schema 2 save is missing required field: %s." % field
			return {}
	var player_result: Dictionary = _decode_cell(snapshot["robot_cell"], false)
	if player_result.is_empty():
		_last_error = "Schema 2 robot_cell is malformed or out of range."
		return {}
	return {&"player_cell": player_result[&"cell"]}


func _schema_two_world(snapshot: Dictionary, player_cell: Vector2i) -> Dictionary:
	var destroyed: Dictionary = _decode_cell_array(
		snapshot["destroyed_rocks"], MAX_WORLD_ENTRIES, false
	)
	if destroyed.is_empty() and not _last_error.is_empty():
		return {}
	var placed: Dictionary = _decode_cell_array(
		snapshot["placed_rocks"], MAX_WORLD_ENTRIES, false, player_cell
	)
	if placed.is_empty() and not _last_error.is_empty():
		return {}
	var dropped: Dictionary = _decode_amount_array(
		snapshot["dropped_scrap"], MAX_WORLD_ENTRIES, false
	)
	if dropped.is_empty() and not _last_error.is_empty():
		return {}
	var collected: Dictionary = _decode_cell_array(
		snapshot["collected_scrap"], MAX_WORLD_ENTRIES, false
	)
	if collected.is_empty() and not _last_error.is_empty():
		return {}
	if (
		_sets_overlap(destroyed[&"set"] as Dictionary, placed[&"set"] as Dictionary)
		or _sets_overlap(dropped[&"set"] as Dictionary, collected[&"set"] as Dictionary)
		or _sets_overlap(dropped[&"set"] as Dictionary, placed[&"set"] as Dictionary)
	):
		_last_error = "Schema 2 world delta sets contradict each other."
		return {}
	return {
		&"destroyed_rocks": (destroyed[&"cells"] as Array).duplicate(true),
		&"placed_rocks": (placed[&"cells"] as Array).duplicate(true),
		&"dropped_scrap": (dropped[&"entries"] as Array).duplicate(true),
		&"collected_scrap": (collected[&"cells"] as Array).duplicate(true),
	}


func _normalize_common(
	snapshot: Dictionary, player_cell: Vector2i, allow_relay: bool
) -> Dictionary:
	var scrap_result: Dictionary = _strict_integer(snapshot["scrap_total"], 0, MAX_WALLET)
	if scrap_result.is_empty():
		_last_error = "scrap_total must be a finite integral wallet value."
		return {}
	var chassis: int = _max_chassis
	if snapshot.has("chassis"):
		var chassis_result: Dictionary = _strict_integer(snapshot["chassis"], 0, _max_chassis)
		if chassis_result.is_empty():
			_last_error = "chassis must be a finite integral value within bounds."
			return {}
		chassis = int(chassis_result[&"value"])
	var facing_value: Variant = snapshot["facing"]
	if not facing_value is String and not facing_value is StringName:
		_last_error = "facing must be a direction string."
		return {}
	var facing: StringName = StringName(str(facing_value))
	if facing not in VALID_FACINGS:
		_last_error = "facing is not a recognized direction."
		return {}
	var relay_completed: bool = false
	if allow_relay and snapshot.has("relay_completed"):
		if not snapshot["relay_completed"] is bool:
			_last_error = "relay_completed must be a boolean."
			return {}
		relay_completed = bool(snapshot["relay_completed"])
	return {
		&"player_cell": player_cell,
		&"facing": facing,
		&"chassis": chassis,
		&"scrap": int(scrap_result[&"value"]),
		&"relay_completed": relay_completed,
	}


func _make_active_run(normalized: Dictionary) -> Dictionary:
	var run: RefCounted = RunStateScript.new() as RefCounted
	var run_id: StringName = StringName("run.legacy.v%d" % _source_version)
	if not bool(
		(
			run
			. call(
				"configure",
				run_id,
				0,
				_max_chassis,
				normalized[&"player_cell"] as Vector2i,
				normalized[&"facing"] as StringName,
			)
		)
	):
		_last_error = "Normalized legacy run could not be configured."
		return {}
	if not bool(run.call("transition_to", RuntimeIdsScript.RUN_PHASE_HUNT)):
		_last_error = "Normalized legacy run could not enter hunt phase."
		return {}
	if not bool(run.call("set_value", &"scrap", int(normalized[&"scrap"]))):
		_last_error = "Normalized legacy scrap could not be restored."
		return {}
	if not _restore_relay(run, bool(normalized[&"relay_completed"])):
		return {}
	if not _restore_chassis(run, int(normalized[&"chassis"])):
		return {}
	return run.call("to_dictionary") as Dictionary


func _restore_relay(run: RefCounted, completed: bool) -> bool:
	if not completed:
		return true
	if not bool(run.call("set_value", &"starter_relay_completed", true)):
		_last_error = "Legacy relay completion could not be restored."
		return false
	if not bool(run.call("apply_event", RuntimeIdsScript.EVENT_RELAY_COMPLETED)):
		_last_error = "Legacy relay migration event could not be recorded."
		return false
	return true


func _restore_chassis(run: RefCounted, chassis: int) -> bool:
	if chassis != _max_chassis and not bool(run.call("set_value", &"chassis", chassis)):
		_last_error = "Normalized legacy chassis could not be restored."
		return false
	if chassis == 0 and not bool(run.call("set_value", &"shutdown", true)):
		_last_error = "Legacy shutdown could not be restored."
		return false
	return true


func _decode_cell_array(
	value: Variant,
	maximum_size: int,
	legacy_bounds: bool,
	forbidden: Vector2i = Vector2i(COORDINATE_LIMIT + 1, COORDINATE_LIMIT + 1),
) -> Dictionary:
	if not value is Array:
		_last_error = "World cell delta must be an array."
		return {}
	var values: Array = value as Array
	if values.size() > maximum_size:
		_last_error = "World cell delta exceeds its size limit."
		return {}
	var seen: Dictionary = {}
	for entry: Variant in values:
		var decoded: Dictionary = _decode_cell(entry, legacy_bounds)
		if decoded.is_empty():
			_last_error = "World cell delta contains a malformed or out-of-range cell."
			return {}
		var cell: Vector2i = decoded[&"cell"] as Vector2i
		if cell == forbidden:
			_last_error = "A placed rock occupies the robot cell."
			return {}
		if seen.has(cell):
			_last_error = "World cell delta contains a duplicate cell."
			return {}
		seen[cell] = true
	return {&"cells": _encode_cells(seen), &"set": seen}


func _decode_amount_array(value: Variant, maximum_size: int, legacy_bounds: bool) -> Dictionary:
	if not value is Array:
		_last_error = "World scrap delta must be an array."
		return {}
	var values: Array = value as Array
	if values.size() > maximum_size:
		_last_error = "World scrap delta exceeds its size limit."
		return {}
	var amounts: Dictionary = {}
	for item: Variant in values:
		if (
			not item is Dictionary
			or not _contains_only(item as Dictionary, ["cell", "amount"])
			or not (item as Dictionary).has("cell")
			or not (item as Dictionary).has("amount")
		):
			_last_error = "World scrap delta contains a malformed entry."
			return {}
		var entry: Dictionary = item as Dictionary
		var decoded: Dictionary = _decode_cell(entry["cell"], legacy_bounds)
		var amount: Dictionary = _strict_integer(entry["amount"], 1, MAX_SCRAP_AMOUNT)
		if decoded.is_empty() or amount.is_empty():
			_last_error = "World scrap delta contains a malformed cell or amount."
			return {}
		var cell: Vector2i = decoded[&"cell"] as Vector2i
		if amounts.has(cell):
			_last_error = "World scrap delta contains a duplicate cell."
			return {}
		amounts[cell] = int(amount[&"value"])
	return {&"entries": _encode_amounts(amounts), &"set": amounts}


func _decode_cell(value: Variant, legacy_bounds: bool) -> Dictionary:
	if not value is Array or (value as Array).size() != 2:
		return {}
	var coordinates: Array = value as Array
	var minimum: int = 0 if legacy_bounds else -COORDINATE_LIMIT
	var maximum: int = LEGACY_GRID_SIZE - 1 if legacy_bounds else COORDINATE_LIMIT
	var x_result: Dictionary = _strict_integer(coordinates[0], minimum, maximum)
	var y_result: Dictionary = _strict_integer(coordinates[1], minimum, maximum)
	if x_result.is_empty() or y_result.is_empty():
		return {}
	var cell: Vector2i = Vector2i(int(x_result[&"value"]), int(y_result[&"value"]))
	var valid: bool = bool(
		(
			_world_validator.call("_is_valid_storage_cell", cell)
			if _world_validator.has_method("_is_valid_storage_cell")
			else _world_validator.call("is_valid_cell", cell)
		)
	)
	if not valid:
		return {}
	return {&"cell": cell}


func _strict_integer(value: Variant, minimum: int, maximum: int) -> Dictionary:
	if value is int:
		var integer: int = int(value)
		return {&"value": integer} if integer >= minimum and integer <= maximum else {}
	if value is float:
		var number: float = float(value)
		if not is_finite(number) or floor(number) != number:
			return {}
		if number < float(minimum) or number > float(maximum):
			return {}
		return {&"value": int(number)}
	return {}


func _sets_overlap(first: Dictionary, second: Dictionary) -> bool:
	for key: Variant in first:
		if second.has(key):
			return true
	return false


func _contains_only(value: Dictionary, allowed: Array[String]) -> bool:
	for key: Variant in value:
		if str(key) not in allowed:
			return false
	return true


func _encode_cells(source: Dictionary) -> Array[Array]:
	var result: Array[Array] = []
	for raw_cell: Variant in source:
		var cell: Vector2i = raw_cell as Vector2i
		result.append([cell.x, cell.y])
	result.sort_custom(
		func(a: Array, b: Array) -> bool: return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0])
	)
	return result


func _encode_amounts(source: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_cell: Variant in source:
		var cell: Vector2i = raw_cell as Vector2i
		result.append({&"cell": [cell.x, cell.y], &"amount": int(source[cell])})
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var first: Array = a[&"cell"] as Array
			var second: Array = b[&"cell"] as Array
			return first[1] < second[1] or (first[1] == second[1] and first[0] < second[0])
	)
	return result
