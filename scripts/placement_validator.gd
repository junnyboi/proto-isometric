extends RefCounted

const CatalogScript: GDScript = preload("res://scripts/construction_blueprint_catalog.gd")
const ClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")
const HomesteadScript: GDScript = preload("res://scripts/homestead_service.gd")
const OccupancyScript: GDScript = preload("res://scripts/building_occupancy_index.gd")
const PathSafetyScript: GDScript = preload("res://scripts/path_safety_service.gd")


static func evaluate(
	farm: Dictionary,
	world: RefCounted,
	blueprint_id: StringName,
	anchor: Vector2i,
	orientation: int,
	exempt_instance: StringName = &"",
	actor_cells: Array[Vector2i] = [],
) -> Dictionary:
	if world == null or not world.has_method("is_walkable"):
		return _result(false, &"world_unavailable", [], Vector2i.ZERO, {})
	var blueprint: Dictionary = CatalogScript.definition(blueprint_id)
	if blueprint.is_empty() or orientation < 0 or orientation > 3:
		return _result(false, &"invalid_blueprint", [], Vector2i.ZERO, {})
	var cells: Array[Vector2i] = CatalogScript.footprint(blueprint_id, anchor, orientation)
	var entrance: Vector2i = CatalogScript.entrance(blueprint_id, anchor, orientation)
	if cells.is_empty() or not PathSafetyScript.in_bounds(entrance):
		return _result(false, &"outside_build_zone", cells, entrance, {})
	var index: Dictionary = OccupancyScript.build(farm)
	if index.is_empty():
		return _result(false, &"invalid_occupancy", cells, entrance, {})
	var exempt_cells: Dictionary = _record_cells(OccupancyScript.building(index, exempt_instance))
	var actor_set: Dictionary = {}
	for cell: Vector2i in actor_cells:
		actor_set[cell] = true
	for cell: Vector2i in cells:
		var reason: StringName = _cell_reason(
			farm, world, index, cell, exempt_instance, exempt_cells, actor_set
		)
		if reason != &"":
			return _result(false, reason, cells, entrance, {})
	if actor_set.has(entrance):
		return _result(false, &"entrance_occupied", cells, entrance, {})
	if not _base_walkable(world, entrance, exempt_cells):
		return _result(false, &"entrance_blocked", cells, entrance, {})
	if blueprint_id == CatalogScript.FISHING_PLATFORM and not _touches_pond(cells):
		return _result(false, &"requires_pond_edge", cells, entrance, {})
	var blocked: Dictionary = _planning_blocked(world, farm, exempt_cells)
	for cell: Vector2i in cells:
		blocked[cell] = true
	var required: Array[Vector2i] = PathSafetyScript.required_gate_approaches()
	required.append(entrance)
	for existing: Dictionary in index[&"by_instance"].values():
		if str(existing[&"instance_id"]) == str(exempt_instance):
			continue
		required.append(_entrance_for(existing))
	var path: Dictionary = PathSafetyScript.validate(blocked, ClearingScript.CENTER, required)
	if not bool(path[&"ok"]):
		return _result(false, &"blocks_settlement_paths", cells, entrance, path)
	return _result(true, &"", cells, entrance, path)


static func find_nearby(
	farm: Dictionary,
	world: RefCounted,
	blueprint_id: StringName,
	origin: Vector2i,
	actor_cells: Array[Vector2i] = [],
) -> Dictionary:
	for radius: int in range(1, 10):
		for offset: Vector2i in _ring(radius):
			var result: Dictionary = evaluate(
				farm, world, blueprint_id, origin + offset, 0, &"", actor_cells
			)
			if bool(result[&"ok"]):
				return result
	return _result(false, &"no_safe_site_nearby", [], origin, {})


static func _cell_reason(
	farm: Dictionary,
	world: RefCounted,
	index: Dictionary,
	cell: Vector2i,
	exempt_instance: StringName,
	exempt_cells: Dictionary,
	actors: Dictionary,
) -> StringName:
	if not PathSafetyScript.in_bounds(cell) or not ClearingScript.contains(cell):
		return &"outside_build_zone"
	if ClearingScript.is_protected_path(cell):
		return &"protected_path"
	if actors.has(cell):
		return &"actor_occupied"
	var occupant: StringName = OccupancyScript.instance_at(index, cell)
	if occupant != &"" and occupant != exempt_instance:
		return &"building_overlap"
	if not _base_walkable(world, cell, exempt_cells):
		return &"world_blocked"
	if _farm_occupied(farm, cell):
		return &"farm_occupied"
	return &""


static func _planning_blocked(
	world: RefCounted, farm: Dictionary, exempt_cells: Dictionary
) -> Dictionary:
	var blocked: Dictionary = {}
	for y: int in range(PathSafetyScript.MIN_CELL.y, PathSafetyScript.MAX_CELL.y + 1):
		for x: int in range(PathSafetyScript.MIN_CELL.x, PathSafetyScript.MAX_CELL.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			if not _base_walkable(world, cell, exempt_cells) or _farm_occupied(farm, cell):
				blocked[cell] = true
	return blocked


static func _base_walkable(
	world: RefCounted, cell: Vector2i, exempt_cells: Dictionary
) -> bool:
	if exempt_cells.has(cell):
		return true
	return bool(world.call("is_walkable", cell))


static func _farm_occupied(farm: Dictionary, cell: Vector2i) -> bool:
	for plot: Dictionary in farm.get(&"plots", []) as Array[Dictionary]:
		var encoded: Array = plot.get(&"cell", []) as Array
		if encoded.size() == 2 and Vector2i(int(encoded[0]), int(encoded[1])) == cell:
			return true
	for machine: Dictionary in farm.get(&"machines", []) as Array[Dictionary]:
		var encoded: Array = machine.get(&"cell", []) as Array
		if encoded.size() == 2 and Vector2i(int(encoded[0]), int(encoded[1])) == cell:
			return true
	for tree: Dictionary in farm.get(&"orchard", {}).get(&"trees", []) as Array[Dictionary]:
		var encoded: Array = tree.get(&"cell", []) as Array
		if encoded.size() == 2 and Vector2i(int(encoded[0]), int(encoded[1])) == cell:
			return true
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var home: Dictionary = homestead.get(&"home", {}) as Dictionary
	if _encoded_cell(home.get(&"cell")) == cell:
		return true
	for facility: Dictionary in homestead.get(&"facilities", []) as Array[Dictionary]:
		if _encoded_cell(facility.get(&"cell")) == cell:
			return true
	return false


static func _entrance_for(building: Dictionary) -> Vector2i:
	var anchor: Array = building[&"anchor"] as Array
	return CatalogScript.entrance(
		StringName(str(building[&"blueprint_id"])),
		Vector2i(int(anchor[0]), int(anchor[1])),
		int(building[&"orientation"]),
	)


static func _record_cells(building: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for encoded: Array in building.get(&"footprint", []) as Array[Array]:
		result[Vector2i(int(encoded[0]), int(encoded[1]))] = true
	return result


static func _encoded_cell(value: Variant) -> Vector2i:
	if not value is Array or (value as Array).size() != 2:
		return Vector2i(1_000_001, 1_000_001)
	return Vector2i(int(value[0]), int(value[1]))


static func _touches_pond(cells: Array[Vector2i]) -> bool:
	for cell: Vector2i in cells:
		if absi(cell.x - ClearingScript.POND_CELL.x) + absi(cell.y - ClearingScript.POND_CELL.y) == 1:
			return true
	return false


static func _ring(radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			if maxi(absi(x), absi(y)) == radius:
				result.append(Vector2i(x, y))
	result.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return result


static func _result(
	ok: bool,
	reason: StringName,
	cells: Array[Vector2i],
	entrance: Vector2i,
	path: Dictionary,
) -> Dictionary:
	return {
		&"ok": ok,
		&"reason": reason,
		&"cells": cells.duplicate(),
		&"entrance": entrance,
		&"path": path.duplicate(true),
	}
