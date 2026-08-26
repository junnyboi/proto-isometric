extends RefCounted

const CatalogScript: GDScript = preload("res://scripts/construction_blueprint_catalog.gd")

const CHUNK_SIZE: int = 8


static func build_records(farm: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var construction: Dictionary = homestead.get(&"construction", {}) as Dictionary
	for building: Dictionary in construction.get(&"buildings", []) as Array[Dictionary]:
		var blueprint_id: StringName = StringName(str(building[&"blueprint_id"]))
		var definition: Dictionary = CatalogScript.definition(blueprint_id)
		if definition.is_empty():
			continue
		var raw_anchor: Array = building[&"anchor"] as Array
		var state: StringName = StringName(str(building[&"state"]))
		result.append(
			{
				&"cell": Vector2i(int(raw_anchor[0]), int(raw_anchor[1])),
				&"type": &"structure",
				&"stable_id": StringName(str(building[&"instance_id"])),
				&"texture": CatalogScript.texture_for(blueprint_id, state),
				&"draw_size": definition[&"draw_size"],
				&"draw_offset": definition[&"draw_offset"],
				&"construction_state": state,
				&"orientation": int(building[&"orientation"]),
			}
		)
	result.sort_custom(_record_precedes)
	return result


static func build_chunk_indexes(farm: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for record: Dictionary in build_records(farm):
		var cell: Vector2i = record[&"cell"] as Vector2i
		var chunk: Vector2i = Vector2i(
			floori(float(cell.x) / float(CHUNK_SIZE)),
			floori(float(cell.y) / float(CHUNK_SIZE)),
		)
		if not result.has(chunk):
			result[chunk] = []
		(result[chunk] as Array).append(record.duplicate(true))
	return result


static func presentation_cells(farm: Dictionary) -> Array[Vector2i]:
	var unique: Dictionary = {}
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var construction: Dictionary = homestead.get(&"construction", {}) as Dictionary
	for building: Dictionary in construction.get(&"buildings", []) as Array[Dictionary]:
		for encoded: Array in building[&"footprint"] as Array[Array]:
			unique[Vector2i(int(encoded[0]), int(encoded[1]))] = true
	var result: Array[Vector2i] = []
	for value: Variant in unique:
		result.append(value as Vector2i)
	result.sort_custom(_cell_precedes)
	return result


static func _record_precedes(first: Dictionary, second: Dictionary) -> bool:
	var first_cell: Vector2i = first[&"cell"] as Vector2i
	var second_cell: Vector2i = second[&"cell"] as Vector2i
	var first_diagonal: int = first_cell.x + first_cell.y
	var second_diagonal: int = second_cell.x + second_cell.y
	if first_diagonal != second_diagonal:
		return first_diagonal < second_diagonal
	return str(first[&"stable_id"]) < str(second[&"stable_id"])


static func _cell_precedes(first: Vector2i, second: Vector2i) -> bool:
	return first.y < second.y or (first.y == second.y and first.x < second.x)
