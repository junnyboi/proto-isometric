extends RefCounted

const OasisWetlandsScript: GDScript = preload("res://scripts/oasis_wetlands.gd")
const FrozenTundraScript: GDScript = preload("res://scripts/frozen_tundra.gd")
const LavaFieldsScript: GDScript = preload("res://scripts/lava_fields.gd")

const CHUNK_SIZE: int = 8
const STREAM_RADIUS: int = 2
const CULL_RADIUS: Vector2i = Vector2i(14, 14)
const COORDINATE_LIMIT: int = 1_000_000
const PLAYABLE_HALF_EXTENT: int = 72
const PLAYABLE_SIZE: Vector2i = Vector2i(145, 145)
const DEPLOYMENT_CELL: Vector2i = Vector2i(8, 10)
const STARTER_SIZE: Vector2i = Vector2i(18, 18)
const STARTER_RELAY: Vector2i = Vector2i(12, 6)
const SANCTUARY_RADIUS: float = 2.5

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
const STARTER_OUTPOSTS: Array[Vector2i] = [Vector2i(1, 10), Vector2i(8, 4), Vector2i(15, 8)]
const STARTER_SCRAP: Dictionary = {
	Vector2i(9, 9): 1,
	Vector2i(10, 7): 2,
	Vector2i(7, 13): 1,
	Vector2i(14, 8): 2,
}

var _terrain: Dictionary
var _elevation: Dictionary
var _blocked: Dictionary
var _rocks: Dictionary
var _scrap: Dictionary
var _outposts: Dictionary
var _loaded_chunks: Dictionary = {}
var _destroyed_rocks: Dictionary = {}
var _placed_rocks: Dictionary = {}
var _dropped_scrap: Dictionary = {}
var _collected_scrap: Dictionary = {}


func configure(
	terrain: Dictionary,
	elevation: Dictionary,
	blocked: Dictionary,
	rocks: Dictionary,
	scrap: Dictionary,
	outposts: Dictionary,
) -> void:
	_terrain = terrain
	_elevation = elevation
	_blocked = blocked
	_rocks = rocks
	_scrap = scrap
	_outposts = outposts


func stream_around(center: Vector2i) -> bool:
	var center_chunk: Vector2i = chunk_for_cell(center)
	var desired: Dictionary = {}
	for y: int in range(center_chunk.y - STREAM_RADIUS, center_chunk.y + STREAM_RADIUS + 1):
		for x: int in range(center_chunk.x - STREAM_RADIUS, center_chunk.x + STREAM_RADIUS + 1):
			var chunk: Vector2i = Vector2i(x, y)
			if _chunk_intersects_world(chunk):
				desired[chunk] = true
	var changed: bool = false
	for value: Variant in _loaded_chunks.keys():
		var loaded: Vector2i = value as Vector2i
		if not desired.has(loaded):
			_unload_chunk(loaded)
			changed = true
	for value: Variant in desired:
		var wanted: Vector2i = value as Vector2i
		if not _loaded_chunks.has(wanted):
			_load_chunk(wanted)
			changed = true
	return changed


func _ensure_cell(cell: Vector2i) -> void:
	if not is_valid_cell(cell):
		return
	var chunk: Vector2i = chunk_for_cell(cell)
	if not _loaded_chunks.has(chunk):
		_load_chunk(chunk)


func is_valid_cell(cell: Vector2i) -> bool:
	return absi(cell.x) <= PLAYABLE_HALF_EXTENT and absi(cell.y) <= PLAYABLE_HALF_EXTENT


func is_walkable(cell: Vector2i) -> bool:
	if not is_valid_cell(cell):
		return false
	_ensure_cell(cell)
	return not bool(_blocked.get(cell, false))


func terrain_at(cell: Vector2i) -> StringName:
	if not is_valid_cell(cell):
		return &"void"
	_ensure_cell(cell)
	return _terrain.get(cell, &"sand") as StringName


func _biome_at(cell: Vector2i) -> StringName:
	if FrozenTundraScript.contains(cell):
		return FrozenTundraScript.BIOME_FROZEN
	if LavaFieldsScript.contains(cell):
		return LavaFieldsScript.BIOME_LAVA
	return OasisWetlandsScript.biome_at(cell)


func _is_mud(cell: Vector2i) -> bool:
	return terrain_at(cell) == &"mud"


func _is_blue_ice(cell: Vector2i) -> bool:
	return terrain_at(cell) == &"blue_ice"


func place_rock(cell: Vector2i, robot_cell: Vector2i) -> bool:
	if not is_valid_cell(cell) or cell == robot_cell or _is_outpost(cell):
		return false
	_ensure_cell(cell)
	_placed_rocks[cell] = true
	_destroyed_rocks.erase(cell)
	_set_rock(cell)
	return true


func break_rock(cell: Vector2i) -> bool:
	_ensure_cell(cell)
	if not bool(_rocks.get(cell, false)):
		return false
	if _base_terrain(cell) == &"rock":
		_destroyed_rocks[cell] = true
	_placed_rocks.erase(cell)
	_rocks.erase(cell)
	_blocked.erase(cell)
	_terrain[cell] = _surface_for(cell, &"sand")
	_elevation[cell] = 0
	_dropped_scrap[cell] = int(_dropped_scrap.get(cell, 0)) + 2
	_scrap[cell] = int(_scrap.get(cell, 0)) + 2
	return true


func place_scrap(cell: Vector2i, amount: int) -> bool:
	if amount <= 0 or not is_walkable(cell):
		return false
	_dropped_scrap[cell] = int(_dropped_scrap.get(cell, 0)) + amount
	_scrap[cell] = int(_scrap.get(cell, 0)) + amount
	return true


func collect_scrap(cell: Vector2i) -> int:
	_ensure_cell(cell)
	var amount: int = int(_scrap.get(cell, 0))
	if amount <= 0:
		return 0
	_scrap.erase(cell)
	_dropped_scrap.erase(cell)
	if _generated_scrap_amount(cell) > 0:
		_collected_scrap[cell] = true
	return amount


func visible_cells(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(center.y - CULL_RADIUS.y, center.y + CULL_RADIUS.y + 1):
		for x: int in range(center.x - CULL_RADIUS.x, center.x + CULL_RADIUS.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			if is_valid_cell(cell):
				_ensure_cell(cell)
				cells.append(cell)
	cells.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			var first_diagonal: int = a.x + a.y
			var second_diagonal: int = b.x + b.y
			return (
				first_diagonal < second_diagonal
				or (first_diagonal == second_diagonal and a.y < b.y)
			)
	)
	return cells


func get_loaded_chunk_count() -> int:
	return _loaded_chunks.size()


func get_active_cell_count() -> int:
	return _terrain.size()


func get_render_cell_limit() -> int:
	return (CULL_RADIUS.x * 2 + 1) * (CULL_RADIUS.y * 2 + 1)


func get_cull_radius() -> Vector2i:
	return CULL_RADIUS


func _get_playable_size() -> Vector2i:
	return PLAYABLE_SIZE


func _get_starter_relay_cell() -> Vector2i:
	return STARTER_RELAY


func _relay_candidate_is_valid(cell: Vector2i) -> bool:
	return (
		is_valid_cell(cell)
		and not _is_outpost(cell)
		and _base_terrain(cell) in [&"sand", &"salt", &"ruin"]
		and not _placed_rocks.has(cell)
	)


func _is_in_sanctuary(position: Vector2, radius: float = SANCTUARY_RADIUS) -> bool:
	var center: Vector2i = Vector2i(position.round())
	var extent: int = ceili(maxf(radius, 0.0))
	for y: int in range(center.y - extent, center.y + extent + 1):
		for x: int in range(center.x - extent, center.x + extent + 1):
			var cell: Vector2i = Vector2i(x, y)
			if _is_outpost(cell) and Vector2(cell).distance_to(position) <= radius:
				return true
	return false


func is_cell_loaded(cell: Vector2i) -> bool:
	return _loaded_chunks.has(chunk_for_cell(cell))


func chunk_for_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(cell.x) / float(CHUNK_SIZE)), floori(float(cell.y) / float(CHUNK_SIZE))
	)


func make_snapshot() -> Dictionary:
	return {
		"destroyed_rocks": _encode_cells(_destroyed_rocks),
		"placed_rocks": _encode_cells(_placed_rocks),
		"dropped_scrap": _encode_amounts(_dropped_scrap),
		"collected_scrap": _encode_cells(_collected_scrap),
	}


func is_valid_snapshot(snapshot: Dictionary, robot_cell: Vector2i) -> bool:
	var schema: int = int(snapshot.get("schema", -1))
	if schema == 1:
		return _legacy_snapshot_is_valid(snapshot, robot_cell)
	if schema != 2:
		return false
	return (
		_cell_array_is_valid(snapshot.get("destroyed_rocks", null))
		and _cell_array_is_valid(snapshot.get("placed_rocks", null), robot_cell)
		and _cell_array_is_valid(snapshot.get("collected_scrap", null))
		and _amount_array_is_valid(snapshot.get("dropped_scrap", null))
	)


func apply_snapshot(snapshot: Dictionary) -> void:
	_destroyed_rocks.clear()
	_placed_rocks.clear()
	_dropped_scrap.clear()
	_collected_scrap.clear()
	if int(snapshot.get("schema", -1)) == 1:
		_apply_legacy_snapshot(snapshot)
	else:
		_decode_cells(snapshot["destroyed_rocks"] as Array, _destroyed_rocks)
		_decode_cells(snapshot["placed_rocks"] as Array, _placed_rocks)
		_decode_cells(snapshot["collected_scrap"] as Array, _collected_scrap)
		_decode_amounts(snapshot["dropped_scrap"] as Array, _dropped_scrap)
	_clear_active_chunks()


func decode_cell(value: Variant) -> Vector2i:
	if not value is Array or (value as Array).size() != 2:
		return Vector2i(COORDINATE_LIMIT + 1, COORDINATE_LIMIT + 1)
	var coordinates: Array = value as Array
	if (
		(not coordinates[0] is int and not coordinates[0] is float)
		or (not coordinates[1] is int and not coordinates[1] is float)
	):
		return Vector2i(COORDINATE_LIMIT + 1, COORDINATE_LIMIT + 1)
	var cell: Vector2i = Vector2i(int(coordinates[0]), int(coordinates[1]))
	return (
		cell
		if _is_valid_storage_cell(cell)
		else Vector2i(COORDINATE_LIMIT + 1, COORDINATE_LIMIT + 1)
	)


func _load_chunk(chunk: Vector2i) -> void:
	_loaded_chunks[chunk] = true
	var start: Vector2i = chunk * CHUNK_SIZE
	for y: int in range(start.y, start.y + CHUNK_SIZE):
		for x: int in range(start.x, start.x + CHUNK_SIZE):
			var cell: Vector2i = Vector2i(x, y)
			if is_valid_cell(cell):
				_generate_cell(cell)


func _unload_chunk(chunk: Vector2i) -> void:
	var start: Vector2i = chunk * CHUNK_SIZE
	for y: int in range(start.y, start.y + CHUNK_SIZE):
		for x: int in range(start.x, start.x + CHUNK_SIZE):
			var cell: Vector2i = Vector2i(x, y)
			_terrain.erase(cell)
			_elevation.erase(cell)
			_blocked.erase(cell)
			_rocks.erase(cell)
			_scrap.erase(cell)
			_outposts.erase(cell)
	_loaded_chunks.erase(chunk)


func _clear_active_chunks() -> void:
	_terrain.clear()
	_elevation.clear()
	_blocked.clear()
	_rocks.clear()
	_scrap.clear()
	_outposts.clear()
	_loaded_chunks.clear()


func _generate_cell(cell: Vector2i) -> void:
	var base_terrain: StringName = _base_terrain(cell)
	if _destroyed_rocks.has(cell) and base_terrain == &"rock":
		base_terrain = &"sand"
	var terrain_id: StringName = _surface_for(cell, base_terrain)
	if _placed_rocks.has(cell):
		terrain_id = &"rock"
	_terrain[cell] = terrain_id
	_elevation[cell] = 2 if terrain_id == &"rock" else 0
	if terrain_id == &"rock":
		_rocks[cell] = true
		_blocked[cell] = true
	if _is_outpost(cell):
		_outposts[cell] = true
		_terrain[cell] = &"ruin"
		_elevation[cell] = 0
		_rocks.erase(cell)
		_blocked.erase(cell)
	var amount: int = int(_dropped_scrap.get(cell, 0))
	if amount <= 0 and not _collected_scrap.has(cell):
		amount = _generated_scrap_amount(cell)
	if amount > 0 and not _blocked.has(cell):
		_scrap[cell] = amount


func _set_rock(cell: Vector2i) -> void:
	_terrain[cell] = &"rock"
	_elevation[cell] = 2
	_rocks[cell] = true
	_blocked[cell] = true
	_outposts.erase(cell)
	_scrap.erase(cell)


func _base_terrain(cell: Vector2i) -> StringName:
	if cell == STARTER_RELAY:
		return &"ruin"
	if cell in STARTER_ROCKS:
		return &"rock"
	var value: int = posmod(cell.x * 19 + cell.y * 31 + cell.x * cell.y * 7, 100)
	if value < 11:
		return &"salt"
	if value < 18:
		return &"ruin"
	if not _is_starter_region(cell) and value < 23:
		return &"rock"
	return &"sand"


func _surface_for(cell: Vector2i, base_terrain: StringName) -> StringName:
	var sanctuary: bool = _is_in_sanctuary(Vector2(cell))
	if _biome_at(cell) == FrozenTundraScript.BIOME_FROZEN:
		return FrozenTundraScript.surface_for(cell, base_terrain, sanctuary)
	if _biome_at(cell) == LavaFieldsScript.BIOME_LAVA:
		return LavaFieldsScript.surface_for(cell, base_terrain, sanctuary)
	return OasisWetlandsScript.surface_for(cell, base_terrain, sanctuary)


func _is_outpost(cell: Vector2i) -> bool:
	return (
		cell in STARTER_OUTPOSTS
		or (not _is_starter_region(cell) and posmod(_cell_hash(cell, 0x0A77), 257) == 0)
	)


func _generated_scrap_amount(cell: Vector2i) -> int:
	if STARTER_SCRAP.has(cell):
		return int(STARTER_SCRAP[cell])
	if _is_starter_region(cell) or _base_terrain(cell) == &"rock" or _is_outpost(cell):
		return 0
	return (
		1 + posmod(_cell_hash(cell, 0x5C4A9), 2)
		if posmod(_cell_hash(cell, 0x51A9), 173) == 0
		else 0
	)


func _is_starter_region(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < STARTER_SIZE.x and cell.y < STARTER_SIZE.y


func _cell_hash(cell: Vector2i, salt: int) -> int:
	var value: int = cell.x * 73856093 ^ cell.y * 19349663 ^ salt * 83492791
	value = (value ^ (value >> 13)) * 1274126177
	return value ^ (value >> 16)


func _chunk_intersects_world(chunk: Vector2i) -> bool:
	var start: Vector2i = chunk * CHUNK_SIZE
	var finish: Vector2i = start + Vector2i(CHUNK_SIZE - 1, CHUNK_SIZE - 1)
	return (
		finish.x >= -PLAYABLE_HALF_EXTENT
		and start.x <= PLAYABLE_HALF_EXTENT
		and finish.y >= -PLAYABLE_HALF_EXTENT
		and start.y <= PLAYABLE_HALF_EXTENT
	)


func _is_valid_storage_cell(cell: Vector2i) -> bool:
	return absi(cell.x) <= COORDINATE_LIMIT and absi(cell.y) <= COORDINATE_LIMIT


func _encode_cells(source: Dictionary) -> Array[Array]:
	var result: Array[Array] = []
	for value: Variant in source:
		var cell: Vector2i = value as Vector2i
		result.append([cell.x, cell.y])
	result.sort_custom(
		func(a: Array, b: Array) -> bool: return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0])
	)
	return result


func _encode_amounts(source: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in source:
		var cell: Vector2i = value as Vector2i
		result.append({"cell": [cell.x, cell.y], "amount": int(source[cell])})
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var first: Array = a["cell"] as Array
			var second: Array = b["cell"] as Array
			return first[1] < second[1] or (first[1] == second[1] and first[0] < second[0])
	)
	return result


func _cell_array_is_valid(
	value: Variant, forbidden: Vector2i = Vector2i(COORDINATE_LIMIT + 1, COORDINATE_LIMIT + 1)
) -> bool:
	if not value is Array or (value as Array).size() > 100_000:
		return false
	var seen: Dictionary = {}
	for entry: Variant in value as Array:
		var cell: Vector2i = decode_cell(entry)
		if not _is_valid_storage_cell(cell) or cell == forbidden or seen.has(cell):
			return false
		seen[cell] = true
	return true


func _amount_array_is_valid(value: Variant) -> bool:
	if not value is Array or (value as Array).size() > 100_000:
		return false
	var seen: Dictionary = {}
	for item: Variant in value as Array:
		if not item is Dictionary:
			return false
		var entry: Dictionary = item as Dictionary
		var cell: Vector2i = decode_cell(entry.get("cell", []))
		var amount: int = int(entry.get("amount", 0))
		if not _is_valid_storage_cell(cell) or seen.has(cell) or amount <= 0 or amount > 999:
			return false
		seen[cell] = true
	return true


func _legacy_snapshot_is_valid(snapshot: Dictionary, robot_cell: Vector2i) -> bool:
	var grid: Variant = snapshot.get("grid_size", null)
	return (
		grid is Array
		and (grid as Array) == [STARTER_SIZE.x, STARTER_SIZE.y]
		and _cell_array_is_valid(snapshot.get("rocks", null), robot_cell)
		and _amount_array_is_valid(snapshot.get("scrap", null))
	)


func _apply_legacy_snapshot(snapshot: Dictionary) -> void:
	var surviving: Dictionary = {}
	_decode_cells(snapshot["rocks"] as Array, surviving)
	for cell: Vector2i in STARTER_ROCKS:
		if not surviving.has(cell):
			_destroyed_rocks[cell] = true
	for value: Variant in surviving:
		var cell: Vector2i = value as Vector2i
		if cell not in STARTER_ROCKS:
			_placed_rocks[cell] = true
	_decode_amounts(snapshot["scrap"] as Array, _dropped_scrap)
	for value: Variant in STARTER_SCRAP:
		var cell: Vector2i = value as Vector2i
		if not _dropped_scrap.has(cell):
			_collected_scrap[cell] = true


func _decode_cells(values: Array, target: Dictionary) -> void:
	for value: Variant in values:
		target[decode_cell(value)] = true


func _decode_amounts(values: Array, target: Dictionary) -> void:
	for value: Variant in values:
		var entry: Dictionary = value as Dictionary
		target[decode_cell(entry["cell"])] = int(entry["amount"])
