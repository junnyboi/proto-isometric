extends RefCounted

const WorldObjectsScript: GDScript = preload("res://scripts/world_objects.gd")
const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const TILE_SIZE: Vector2 = Vector2(90.0, 45.0)
const MAP_ORIGIN: Vector2 = Vector2(760.0, 70.0)


static func evaluate(world: RefCounted) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var outpost: Vector2i = InfiniteWorldScript.SAFE_STARTER_OUTPOST
	var service_only: Vector2i = Vector2i(8, 4)
	var projection: Callable = func(cell: Vector2i) -> Vector2:
		return (
			MAP_ORIGIN
			+ Vector2(
				float(cell.x - cell.y) * TILE_SIZE.x * 0.5,
				float(cell.x + cell.y) * TILE_SIZE.y * 0.5,
			)
		)
	var renderer: Node2D = WorldObjectsScript.new() as Node2D
	(
		renderer
		. call(
			"configure",
			{},
			{},
			{outpost: true, service_only: true, Vector2i(15, 8): true},
			projection,
			Callable(),
			TILE_SIZE,
			InfiniteWorldScript.SANCTUARY_RADIUS,
		)
	)
	renderer.call("bind_world", world, Callable())
	var visible_cells: Array[Vector2i] = [outpost, service_only, Vector2i(15, 8)]
	renderer.call("set_visible_cells", visible_cells)
	_add(
		cases,
		"sanctuary renderer uses world-owned radius",
		is_equal_approx(
			float(renderer.call("get_sanctuary_radius")),
			InfiniteWorldScript.SANCTUARY_RADIUS,
		),
	)
	_add(
		cases,
		"three starter services expose only one sanctuary boundary",
		int(renderer.call("get_visible_sanctuary_count")) == 1,
	)
	_add(
		cases,
		"procedural sanctuary policy retains exactly one quarter of outposts",
		InfiniteWorldScript.SANCTUARY_OUTPOST_DIVISOR == 4,
	)
	var points: PackedVector2Array = renderer.call("get_sanctuary_boundary_points", outpost)
	var center: Vector2 = projection.call(outpost) as Vector2
	var expected_first: Vector2 = (
		center
		+ Vector2(
			InfiniteWorldScript.SANCTUARY_RADIUS * TILE_SIZE.x * 0.5,
			InfiniteWorldScript.SANCTUARY_RADIUS * TILE_SIZE.y * 0.5,
		)
	)
	_add(cases, "sanctuary boundary is a smooth closed footprint", points.size() == 48)
	_add(
		cases,
		"sanctuary boundary projects the exact gameplay radius",
		points[0].is_equal_approx(expected_first),
	)
	_add(
		cases,
		"gameplay sanctuary accepts a point just inside the ring",
		bool(world.call("_is_in_sanctuary", Vector2(3.49, 10.0))),
	)
	_add(
		cases,
		"gameplay sanctuary rejects a point just outside the ring",
		not bool(world.call("_is_in_sanctuary", Vector2(3.51, 10.0))),
	)
	_add(
		cases,
		"service-only starter outpost does not suppress enemies",
		not bool(world.call("_is_in_sanctuary", Vector2(service_only))),
	)
	var culled_cells: Array[Vector2i] = []
	renderer.call("set_visible_cells", culled_cells)
	_add(
		cases,
		"culled outposts expose no sanctuary boundary",
		int(renderer.call("get_visible_sanctuary_count")) == 0,
	)
	renderer.free()
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
