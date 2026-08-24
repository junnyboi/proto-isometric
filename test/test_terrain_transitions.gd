extends RefCounted

const TerrainRendererScript: GDScript = preload("res://scripts/terrain_renderer.gd")
const TerrainSurfaceScript: GDScript = preload("res://scripts/terrain_surface.gd")


class RecordingRenderer:
	extends RefCounted
	var calls: Array[String] = []

	func grid_to_screen(cell: Vector2i) -> Vector2:
		return Vector2(cell)

	func draw_world_backdrop(_canvas: Node2D, _center: Vector2) -> void:
		calls.append("backdrop")

	func draw_tile(_canvas: Node2D, cell: Vector2i) -> void:
		calls.append("base:%s" % cell)

	func draw_tile_transitions(_canvas: Node2D, cell: Vector2i) -> void:
		calls.append("blend:%s" % cell)

	func draw_tile_details(_canvas: Node2D, cell: Vector2i) -> void:
		calls.append("detail:%s" % cell)


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_transition_contract(cases)
	_test_band_geometry(cases)
	_test_surface_draw_order(cases)
	return cases


static func _test_transition_contract(cases: Array[Dictionary]) -> void:
	var center: Vector2i = Vector2i.ZERO
	var north: Vector2i = Vector2i(0, -1)
	var east: Vector2i = Vector2i(1, 0)
	var south: Vector2i = Vector2i(0, 1)
	var west: Vector2i = Vector2i(-1, 0)
	var terrain: Dictionary = {
		center: &"sand",
		north: &"wetland",
		east: &"snow",
		south: &"lava",
		west: &"rock",
	}
	var elevation: Dictionary = {west: 2}
	var renderer: RefCounted = TerrainRendererScript.new() as RefCounted
	renderer.call("configure", terrain, elevation, {}, Vector2(90.0, 45.0), Vector2.ZERO)
	var transitions: Array = renderer.call("transition_descriptors_for", center) as Array
	_add(
		cases,
		"flat unlike neighbors create one transition per shared edge",
		transitions.size() == 3
	)
	_add(
		cases,
		"raised obstacle boundaries are excluded from terrain blending",
		not _has_edge(transitions, 3)
	)
	var hazard: Dictionary = _transition_for_edge(transitions, 2)
	_add(
		cases,
		"lava transition depth and alpha remain narrower than ordinary terrain blends",
		float(hazard.get(&"scale", 1.0)) < 1.0 and float(hazard.get(&"alpha_scale", 1.0)) < 1.0,
	)
	var north_back: Array = renderer.call("transition_descriptors_for", north) as Array
	_add(
		cases,
		"adjacent terrain blending is symmetric across the shared edge",
		_has_edge(transitions, 0) and _has_edge(north_back, 2),
	)
	var uniform: RefCounted = TerrainRendererScript.new() as RefCounted
	(
		uniform
		. call(
			"configure",
			{center: &"snow", north: &"snow"},
			{},
			{},
			Vector2(90.0, 45.0),
			Vector2.ZERO,
		)
	)
	_add(
		cases,
		"same-material neighbors do not receive redundant blend overlays",
		(uniform.call("transition_descriptors_for", center) as Array).is_empty(),
	)


static func _test_band_geometry(cases: Array[Dictionary]) -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[Vector2(0.0, -22.5), Vector2(45.0, 0.0), Vector2(0.0, 22.5), Vector2(-45.0, 0.0)]
	)
	var band: PackedVector2Array = TerrainRendererScript.transition_band_points(points, 1, 0.2)
	var center: Vector2 = Vector2.ZERO
	_add(cases, "transition band is a four-point inset edge polygon", band.size() == 4)
	_add(
		cases,
		"transition band preserves the shared edge and lerps inward deterministically",
		(
			band[0] == points[1]
			and band[1] == points[2]
			and band[2].is_equal_approx(points[2].lerp(center, 0.2))
			and band[3].is_equal_approx(points[1].lerp(center, 0.2))
		),
	)
	_add(
		cases,
		"invalid edge indices cannot emit transition geometry",
		TerrainRendererScript.transition_band_points(points, 5, 0.2).is_empty(),
	)


static func _test_surface_draw_order(cases: Array[Dictionary]) -> void:
	var surface: Node2D = TerrainSurfaceScript.new() as Node2D
	var renderer: RecordingRenderer = RecordingRenderer.new()
	surface.call("configure", renderer)
	var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT]
	surface.call("set_visible_cells", cells)
	surface.call("_draw")
	_add(
		cases,
		"terrain batches bases, then blends, then grid and hazard details",
		(
			renderer.calls
			== [
				"backdrop",
				"base:(0, 0)",
				"base:(1, 0)",
				"blend:(0, 0)",
				"blend:(1, 0)",
				"detail:(0, 0)",
				"detail:(1, 0)",
			]
		),
	)
	surface.free()


static func _transition_for_edge(transitions: Array, edge: int) -> Dictionary:
	for transition: Dictionary in transitions:
		if int(transition[&"edge"]) == edge:
			return transition
	return {}


static func _has_edge(transitions: Array, edge: int) -> bool:
	return not _transition_for_edge(transitions, edge).is_empty()


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
