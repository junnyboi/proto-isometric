extends RefCounted

const CENTER: Vector2i = Vector2i(8, 10)
const HOME_CELL: Vector2i = Vector2i(8, 4)
const POND_CELL: Vector2i = Vector2i(4, 9)
const FARM_APRON: Rect2i = Rect2i(10, 7, 6, 6)
const INNER_RADIUS: float = 9.0
const BUFFER_RADIUS: float = 10.0
const TREE_INNER_RADIUS: float = 10.0
const TREE_OUTER_RADIUS: float = 13.0
const RESERVE_RADIUS: float = 13.0
const DEFAULT_SEED: int = 0x48415256
const BIOME_WOODLAND: StringName = &"woodland"
const SURFACE_GRASS: StringName = &"woodland_grass"
const KIND_NONE: StringName = &""
const KIND_BROADLEAF: StringName = &"woodland_broadleaf_tree"
const KIND_CONIFER: StringName = &"woodland_conifer_tree"
const GATE_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]
const GATE_CELLS: Array[Vector2i] = [
	Vector2i(7, -3), Vector2i(8, -3),
	Vector2i(21, 9), Vector2i(21, 10),
	Vector2i(8, 23), Vector2i(9, 23),
	Vector2i(-5, 10), Vector2i(-5, 11),
]


static func classify(cell: Vector2i, world_seed: int = DEFAULT_SEED) -> Dictionary:
	var tree_kind: StringName = tree_kind_at(cell, world_seed)
	var clearing_surface: bool = contains(cell) or is_protected_path(cell)
	return {
		&"cell": cell,
		&"biome": BIOME_WOODLAND if contains(cell) else &"",
		&"surface": SURFACE_GRASS if clearing_surface else &"",
		&"inner_safe": is_inner_safe(cell),
		&"buffer_safe": is_buffer_safe(cell),
		&"farm_apron": is_farm_apron(cell),
		&"protected_path": is_protected_path(cell),
		&"gate": is_gate(cell),
		&"tree_belt": is_tree_belt(cell),
		&"tree_kind": tree_kind,
		&"obstacle": tree_kind != KIND_NONE,
		&"home": cell == HOME_CELL,
		&"pond": cell == POND_CELL,
	}


static func contains(cell: Vector2i) -> bool:
	return Vector2(cell).distance_to(Vector2(CENTER)) <= RESERVE_RADIUS


static func is_inner_safe(cell: Vector2i) -> bool:
	return Vector2(cell).distance_to(Vector2(CENTER)) <= INNER_RADIUS


static func is_buffer_safe(cell: Vector2i) -> bool:
	return Vector2(cell).distance_to(Vector2(CENTER)) <= BUFFER_RADIUS


static func is_farm_apron(cell: Vector2i) -> bool:
	return FARM_APRON.has_point(cell)


static func is_gate(cell: Vector2i) -> bool:
	return cell in GATE_CELLS


static func is_gate_buffer(cell: Vector2i) -> bool:
	for direction: Vector2i in GATE_DIRECTIONS:
		if _in_gate_lane(cell, direction, 9, 15):
			return true
	return false


static func is_protected_path(cell: Vector2i) -> bool:
	if is_farm_apron(cell) or is_gate_buffer(cell):
		return true
	if cell == HOME_CELL or cell == POND_CELL:
		return true
	var horizontal_home: bool = cell.y in [9, 10] and cell.x >= 4 and cell.x <= 15
	var vertical_home: bool = cell.x in [8, 9] and cell.y >= 4 and cell.y <= 10
	return horizontal_home or vertical_home


static func is_tree_belt(cell: Vector2i) -> bool:
	var distance: float = Vector2(cell).distance_to(Vector2(CENTER))
	return distance >= TREE_INNER_RADIUS and distance <= TREE_OUTER_RADIUS


static func tree_kind_at(cell: Vector2i, world_seed: int = DEFAULT_SEED) -> StringName:
	if not is_tree_belt(cell) or is_protected_path(cell):
		return KIND_NONE
	return KIND_BROADLEAF if posmod(cell_hash(cell, world_seed), 2) == 0 else KIND_CONIFER


static func is_obstacle(cell: Vector2i, world_seed: int = DEFAULT_SEED) -> bool:
	return tree_kind_at(cell, world_seed) != KIND_NONE


static func is_structure(cell: Vector2i) -> bool:
	return cell == HOME_CELL


static func gate_cells() -> Array[Vector2i]:
	return GATE_CELLS.duplicate()


static func protected_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(CENTER.y - 15, CENTER.y + 16):
		for x: int in range(CENTER.x - 15, CENTER.x + 16):
			var cell: Vector2i = Vector2i(x, y)
			if is_protected_path(cell):
				result.append(cell)
	return result


static func apron_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(FARM_APRON.position.y, FARM_APRON.end.y):
		for x: int in range(FARM_APRON.position.x, FARM_APRON.end.x):
			result.append(Vector2i(x, y))
	return result


static func tree_cells(world_seed: int = DEFAULT_SEED) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(CENTER.y - 13, CENTER.y + 14):
		for x: int in range(CENTER.x - 13, CENTER.x + 14):
			var cell: Vector2i = Vector2i(x, y)
			if is_obstacle(cell, world_seed):
				result.append(cell)
	return result


static func cell_hash(cell: Vector2i, world_seed: int = DEFAULT_SEED) -> int:
	var value: int = cell.x * 73856093 ^ cell.y * 19349663 ^ world_seed * 83492791
	value = (value ^ (value >> 13)) * 1274126177
	return value ^ (value >> 16)


static func _in_gate_lane(
	cell: Vector2i, direction: Vector2i, minimum_distance: int, maximum_distance: int
) -> bool:
	var delta: Vector2i = cell - CENTER
	var forward: int = delta.x * direction.x + delta.y * direction.y
	var lateral_direction: Vector2i = Vector2i(-direction.y, direction.x)
	var lateral: int = absi(delta.x * lateral_direction.x + delta.y * lateral_direction.y)
	return forward >= minimum_distance and forward <= maximum_distance and lateral <= 1
