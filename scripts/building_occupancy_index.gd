extends RefCounted

const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")


static func build(farm: Dictionary) -> Dictionary:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var construction: Dictionary = homestead.get(&"construction", {}) as Dictionary
	var normalized: Dictionary = SectionsScript.validate_construction(construction)
	if normalized.is_empty():
		return {}
	var by_cell: Dictionary = {}
	var by_instance: Dictionary = {}
	for building: Dictionary in normalized[&"buildings"] as Array[Dictionary]:
		var instance_id: StringName = StringName(str(building[&"instance_id"]))
		if by_instance.has(instance_id):
			return {}
		by_instance[instance_id] = building.duplicate(true)
		for encoded: Array in building[&"footprint"] as Array[Array]:
			var cell: Vector2i = Vector2i(int(encoded[0]), int(encoded[1]))
			if by_cell.has(cell):
				return {}
			by_cell[cell] = instance_id
	return {&"by_cell": by_cell, &"by_instance": by_instance}


static func instance_at(index: Dictionary, cell: Vector2i) -> StringName:
	return index.get(&"by_cell", {}).get(cell, &"") as StringName


static func building_at(index: Dictionary, cell: Vector2i) -> Dictionary:
	var instance_id: StringName = instance_at(index, cell)
	return building(index, instance_id)


static func building(index: Dictionary, instance_id: StringName) -> Dictionary:
	var record: Variant = index.get(&"by_instance", {}).get(instance_id)
	return (record as Dictionary).duplicate(true) if record is Dictionary else {}


static func occupied_cells(
	index: Dictionary, exempt_instance: StringName = &""
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var exempt: Dictionary = building(index, exempt_instance)
	var exempt_cells: Dictionary = {}
	for encoded: Array in exempt.get(&"footprint", []) as Array[Array]:
		exempt_cells[Vector2i(int(encoded[0]), int(encoded[1]))] = true
	for value: Variant in index.get(&"by_cell", {}):
		var cell: Vector2i = value as Vector2i
		if not exempt_cells.has(cell):
			result.append(cell)
	result.sort_custom(_cell_precedes)
	return result


static func _cell_precedes(first: Vector2i, second: Vector2i) -> bool:
	return first.y < second.y or (first.y == second.y and first.x < second.x)
