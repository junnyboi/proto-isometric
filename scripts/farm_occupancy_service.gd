extends RefCounted

const ClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")

const FIXED_SERVICE_CELLS: Array[Vector2i] = [
	Vector2i(6, 7),
	Vector2i(7, 7),
	Vector2i(8, 7),
	Vector2i(9, 7),
	Vector2i(10, 6),
]
const ORCHARD_CAPACITY: int = 512


static func occupied(
	farm: Dictionary, cell: Vector2i, include_orchard: bool = true
) -> bool:
	if cell in FIXED_SERVICE_CELLS:
		return true
	for plot: Dictionary in farm.get(&"plots", []) as Array[Dictionary]:
		if _cell(plot.get(&"cell")) == cell:
			return true
	for machine: Dictionary in farm.get(&"machines", []) as Array[Dictionary]:
		if _cell(machine.get(&"cell")) == cell:
			return true
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	if _cell((homestead.get(&"home", {}) as Dictionary).get(&"cell")) == cell:
		return true
	for facility: Dictionary in homestead.get(&"facilities", []) as Array[Dictionary]:
		if _cell(facility.get(&"cell")) == cell:
			return true
	var construction: Dictionary = homestead.get(&"construction", {}) as Dictionary
	for building: Dictionary in construction.get(&"buildings", []) as Array[Dictionary]:
		for encoded: Array in building.get(&"footprint", []) as Array[Array]:
			if _cell(encoded) == cell:
				return true
	if include_orchard:
		for tree: Dictionary in farm.get(&"orchard", {}).get(&"trees", []) as Array[Dictionary]:
			if _cell(tree.get(&"cell")) == cell:
				return true
	return false


static func orchard_reason(
	farm: Dictionary, cell: Vector2i, include_orchard: bool = true
) -> StringName:
	if is_orchard_path(cell):
		return &"protected_path"
	if cell in FIXED_SERVICE_CELLS:
		return &"farm_service_occupied"
	return &"farm_occupied" if occupied(farm, cell, include_orchard) else &""


static func is_orchard_path(cell: Vector2i) -> bool:
	return ClearingScript.is_farm_apron(cell) and (cell.y == 9 or cell.x == 12)


static func orchard_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index: int in ORCHARD_CAPACITY:
		result.append(Vector2i(256 + index % 32, index / 32))
	return result


static func _cell(value: Variant) -> Vector2i:
	if not value is Array or (value as Array).size() != 2:
		return Vector2i(1_000_001, 1_000_001)
	return Vector2i(int(value[0]), int(value[1]))
