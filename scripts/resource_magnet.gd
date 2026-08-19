extends RefCounted


static func collect_world(
	world: RefCounted,
	center: Vector2i,
	radius_cells: int,
) -> Array[Dictionary]:
	var collected: Array[Dictionary] = []
	if world == null or radius_cells < 0:
		return collected
	for y: int in range(-radius_cells, radius_cells + 1):
		for x: int in range(-radius_cells, radius_cells + 1):
			var offset: Vector2i = Vector2i(x, y)
			if Vector2(offset).length() > float(radius_cells):
				continue
			var cell: Vector2i = center + offset
			var amount: int = int(world.call("collect_scrap", cell))
			if amount > 0:
				collected.append({&"cell": cell, &"amount": amount})
	return collected


static func collect_and_emit(
	world: RefCounted,
	effects: Node2D,
	grid_to_screen: Callable,
	destination: Vector2,
	center: Vector2i,
	radius_cells: int,
) -> int:
	var total: int = 0
	for resource: Dictionary in collect_world(world, center, radius_cells):
		var amount: int = int(resource[&"amount"])
		total += amount
		if effects != null and grid_to_screen.is_valid():
			var source_cell: Vector2i = resource[&"cell"] as Vector2i
			effects.call(
				"emit_scrap_pickup", grid_to_screen.call(source_cell), amount, destination
			)
	return total
