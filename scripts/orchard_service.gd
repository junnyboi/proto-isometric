extends RefCounted

const FarmOccupancyScript: GDScript = preload("res://scripts/farm_occupancy_service.gd")
const InventoryScript: GDScript = preload("res://scripts/inventory_service.gd")
const OrchardCatalogScript: GDScript = preload("res://scripts/orchard_catalog.gd")
const ToolScript: GDScript = preload("res://scripts/tool_service.gd")

const CHUNK_SIZE: int = 8


static func plant(
	farm: Dictionary,
	cell: Vector2i,
	sapling_item_id: StringName,
	absolute_day: int,
	world_cell_clear: Callable = Callable(),
) -> Dictionary:
	var species_id: StringName = OrchardCatalogScript.species_for_sapling(sapling_item_id)
	var reason: StringName = placement_reason(farm, cell, world_cell_clear)
	if species_id == &"":
		reason = &"invalid_sapling"
	if reason != &"":
		return _result(false, farm, reason, cell)
	var removed: Dictionary = InventoryScript.remove(
		farm, InventoryScript.ROBOT_ID, sapling_item_id, 1
	)
	if not bool(removed[&"ok"]):
		return _result(false, farm, &"missing_sapling", cell)
	var candidate: Dictionary = removed[&"candidate"] as Dictionary
	var orchard: Dictionary = (candidate[&"orchard"] as Dictionary).duplicate(true)
	var trees: Array = (orchard[&"trees"] as Array).duplicate(true)
	trees.append({
		&"tree_id": "tree.planted.%d.%d" % [cell.x, cell.y],
		&"species_id": str(species_id),
		&"cell": [cell.x, cell.y],
		&"planted_day": absolute_day,
		&"growth_points": 0,
		&"harvest_sequence": 0,
	})
	trees.sort_custom(_tree_precedes)
	orchard[&"trees"] = trees
	candidate[&"orchard"] = orchard
	return _result(true, candidate, &"", cell)


static func harvest(farm: Dictionary, tree_id: StringName) -> Dictionary:
	var index: int = _tree_index(farm, tree_id)
	if index < 0:
		return _result(false, farm, &"missing_tree", Vector2i.ZERO)
	var source_tree: Dictionary = (farm[&"orchard"][&"trees"] as Array)[index]
	var species_id: StringName = StringName(str(source_tree[&"species_id"]))
	var cell: Vector2i = _cell(source_tree)
	if not OrchardCatalogScript.is_mature(species_id, int(source_tree[&"growth_points"])):
		return _result(false, farm, &"tree_not_mature", cell)
	var spent: Dictionary = ToolScript.spend(farm, ToolScript.TOOL_CONTEXT)
	if not bool(spent[&"ok"]):
		return _result(false, farm, spent[&"reason"] as StringName, cell)
	var definition: Dictionary = OrchardCatalogScript.definition(species_id)
	var yield_count: int = OrchardCatalogScript.deterministic_yield(
		species_id,
		cell,
		int(source_tree[&"planted_day"]),
		int(source_tree[&"harvest_sequence"]),
	)
	var credited: Dictionary = InventoryScript.credit_with_overflow(
		spent[&"candidate"] as Dictionary,
		definition[&"harvest_item_id"] as StringName,
		yield_count,
	)
	if not bool(credited[&"ok"]):
		return _result(false, farm, &"inventory_full", cell)
	var candidate: Dictionary = credited[&"candidate"] as Dictionary
	var trees: Array = (candidate[&"orchard"][&"trees"] as Array).duplicate(true)
	var tree: Dictionary = (trees[index] as Dictionary).duplicate(true)
	tree[&"growth_points"] = int(definition[&"regrow_points"])
	tree[&"harvest_sequence"] = int(tree[&"harvest_sequence"]) + 1
	trees[index] = tree
	(candidate[&"orchard"] as Dictionary)[&"trees"] = trees
	var result: Dictionary = _result(true, candidate, &"", cell)
	result[&"item_id"] = definition[&"harvest_item_id"]
	result[&"yield_count"] = yield_count
	return result


static func remove_immature(farm: Dictionary, tree_id: StringName) -> Dictionary:
	var index: int = _tree_index(farm, tree_id)
	if index < 0:
		return _result(false, farm, &"missing_tree", Vector2i.ZERO)
	var tree: Dictionary = (farm[&"orchard"][&"trees"] as Array)[index]
	var species_id: StringName = StringName(str(tree[&"species_id"]))
	var cell: Vector2i = _cell(tree)
	if OrchardCatalogScript.is_mature(species_id, int(tree[&"growth_points"])):
		return _result(false, farm, &"mature_tree_protected", cell)
	var spent: Dictionary = ToolScript.spend(farm, ToolScript.TOOL_CONTEXT)
	if not bool(spent[&"ok"]):
		return _result(false, farm, spent[&"reason"] as StringName, cell)
	var sapling_id: StringName = (
		OrchardCatalogScript.definition(species_id)[&"sapling_item_id"] as StringName
	)
	var credited: Dictionary = InventoryScript.credit_with_overflow(
		spent[&"candidate"] as Dictionary, sapling_id, 1
	)
	if not bool(credited[&"ok"]):
		return _result(false, farm, &"inventory_full", cell)
	var candidate: Dictionary = credited[&"candidate"] as Dictionary
	var trees: Array = (candidate[&"orchard"][&"trees"] as Array).duplicate(true)
	trees.remove_at(index)
	(candidate[&"orchard"] as Dictionary)[&"trees"] = trees
	return _result(true, candidate, &"", cell)


static func advance_day(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var calendar: Dictionary = candidate[&"calendar_weather"] as Dictionary
	var season_id: StringName = StringName(str(calendar[&"season_id"]))
	var trees: Array = (candidate[&"orchard"][&"trees"] as Array).duplicate(true)
	for index: int in trees.size():
		var tree: Dictionary = (trees[index] as Dictionary).duplicate(true)
		var species_id: StringName = StringName(str(tree[&"species_id"]))
		var thresholds: Array = OrchardCatalogScript.definition(species_id)[&"growth_thresholds"]
		tree[&"growth_points"] = mini(
			int(tree[&"growth_points"])
			+ OrchardCatalogScript.growth_increment(species_id, season_id),
			int(thresholds[3]),
		)
		trees[index] = tree
	(candidate[&"orchard"] as Dictionary)[&"trees"] = trees
	return candidate


static func tree_at(farm: Dictionary, cell: Vector2i) -> Dictionary:
	for tree: Dictionary in farm.get(&"orchard", {}).get(&"trees", []) as Array[Dictionary]:
		if _cell(tree) == cell:
			return tree.duplicate(true)
	return {}


static func placement_reason(
	farm: Dictionary, cell: Vector2i, world_cell_clear: Callable = Callable()
) -> StringName:
	var occupancy_reason: StringName = FarmOccupancyScript.orchard_reason(farm, cell)
	if occupancy_reason == &"protected_path":
		return &"tree_protected_path"
	if occupancy_reason != &"":
		return &"tree_cell_occupied"
	if world_cell_clear.is_valid() and not bool(world_cell_clear.call(cell)):
		return &"tree_world_blocked"
	return &""


static func build_chunk_indexes(farm: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for tree: Dictionary in farm.get(&"orchard", {}).get(&"trees", []) as Array[Dictionary]:
		var cell: Vector2i = _cell(tree)
		var chunk: Vector2i = Vector2i(
			floori(float(cell.x) / CHUNK_SIZE), floori(float(cell.y) / CHUNK_SIZE)
		)
		if not result.has(chunk):
			result[chunk] = []
		var species_id: StringName = StringName(str(tree[&"species_id"]))
		var definition: Dictionary = OrchardCatalogScript.definition(species_id)
		var stage: int = OrchardCatalogScript.stage_for(
			species_id, int(tree[&"growth_points"])
		)
		(result[chunk] as Array).append({
			&"cell": cell,
			&"type": &"structure",
			&"stable_id": StringName(str(tree[&"tree_id"])),
			&"texture": load(str(definition[&"texture_path"])) as Texture2D,
			&"atlas_region": Rect2(stage * 256, 0, 256, 320),
			&"draw_size": Vector2(168.0, 210.0),
			&"draw_offset": Vector2(0.0, -82.0),
		})
	return result


static func build_records(farm: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for records: Array in build_chunk_indexes(farm).values():
		result.append_array(records as Array[Dictionary])
	result.sort_custom(_record_precedes)
	return result


static func presentation_cells(farm: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tree: Dictionary in farm.get(&"orchard", {}).get(&"trees", []) as Array[Dictionary]:
		result.append(_cell(tree))
	return result


static func _tree_index(farm: Dictionary, tree_id: StringName) -> int:
	var trees: Array = farm.get(&"orchard", {}).get(&"trees", []) as Array
	for index: int in trees.size():
		if StringName(str((trees[index] as Dictionary)[&"tree_id"])) == tree_id:
			return index
	return -1


static func _cell(tree: Dictionary) -> Vector2i:
	var raw: Array = tree[&"cell"] as Array
	return Vector2i(int(raw[0]), int(raw[1]))


static func _tree_precedes(first: Dictionary, second: Dictionary) -> bool:
	return str(first[&"tree_id"]) < str(second[&"tree_id"])


static func _record_precedes(first: Dictionary, second: Dictionary) -> bool:
	return str(first[&"stable_id"]) < str(second[&"stable_id"])


static func _result(
	ok: bool, farm: Dictionary, reason: StringName, cell: Vector2i
) -> Dictionary:
	return {
		&"ok": ok,
		&"candidate": farm.duplicate(true),
		&"reason": reason,
		&"dirty_cells": [cell] if cell != Vector2i.ZERO else [],
	}
