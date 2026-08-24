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

	func draw_tile_edge_decals(_canvas: Node2D, cell: Vector2i) -> void:
		calls.append("decal:%s" % cell)

	func draw_tile_details(_canvas: Node2D, cell: Vector2i) -> void:
		calls.append("detail:%s" % cell)


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_transition_contract(cases)
	_test_irregular_mask_geometry(cases)
	_test_edge_decals(cases)
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
	_add(cases, "canonical owner emits each forward flat unlike edge once", transitions.size() == 2)
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
		"each shared edge has one canonical transition owner",
		not _has_edge(transitions, 0) and _has_edge(north_back, 2),
	)
	_add(
		cases,
		"shared-edge seed is independent of cell traversal order",
		(
			TerrainRendererScript.shared_edge_seed(center, north)
			== TerrainRendererScript.shared_edge_seed(north, center)
		),
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


static func _test_irregular_mask_geometry(cases: Array[Dictionary]) -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[Vector2(0.0, -22.5), Vector2(45.0, 0.0), Vector2(0.0, 22.5), Vector2(-45.0, 0.0)]
	)
	var seed: int = TerrainRendererScript.shared_edge_seed(Vector2i.ZERO, Vector2i.RIGHT)
	var mask: PackedVector2Array = TerrainRendererScript.transition_mask_points(
		points, 1, 0.2, seed
	)
	var repeat: PackedVector2Array = TerrainRendererScript.transition_mask_points(
		points, 1, 0.2, seed
	)
	var reverse: PackedVector2Array = TerrainRendererScript.transition_mask_points(
		points, 1, 0.2, seed, true
	)
	var expected_size: int = (TerrainRendererScript.TRANSITION_SEGMENTS + 1) * 2
	_add(
		cases,
		"irregular transition mask is a segmented ribbon polygon",
		mask.size() == expected_size
	)
	_add(cases, "irregular mask generation is deterministic", mask == repeat)
	var inner_depths: Array[float] = []
	var reverse_depths: Array[float] = []
	var center: Vector2 = Vector2.ZERO
	for index: int in range(TerrainRendererScript.TRANSITION_SEGMENTS + 1):
		var outer: Vector2 = mask[index]
		var inner: Vector2 = mask[mask.size() - 1 - index]
		inner_depths.append(outer.distance_to(inner) / outer.distance_to(center))
		var reverse_outer: Vector2 = reverse[index]
		var reverse_inner: Vector2 = reverse[reverse.size() - 1 - index]
		reverse_depths.append(
			reverse_outer.distance_to(reverse_inner) / reverse_outer.distance_to(center)
		)
	_add(
		cases,
		"irregular mask keeps the true shared edge while varying its inner profile",
		(
			mask[0] == points[1]
			and mask[TerrainRendererScript.TRANSITION_SEGMENTS] == points[2]
			and _float_range(inner_depths) > 0.015
		),
	)
	_add(
		cases,
		"reverse profile mirrors the canonical seam for the neighboring tile",
		_depth_profiles_mirror(inner_depths, reverse_depths),
	)
	_add(
		cases,
		"invalid edge indices cannot emit transition geometry",
		TerrainRendererScript.transition_mask_points(points, 5, 0.2, seed).is_empty(),
	)


static func _test_edge_decals(cases: Array[Dictionary]) -> void:
	_add(
		cases,
		"wetland and mud borders select organic reed and silt decals",
		TerrainRendererScript.edge_decal_family_for(&"sand", &"mud") == &"wetland",
	)
	_add(
		cases,
		"snow and ice borders select frost-shard decals",
		TerrainRendererScript.edge_decal_family_for(&"snow", &"blue_ice") == &"frost",
	)
	_add(
		cases,
		"sand and salt borders select crust-chip decals",
		TerrainRendererScript.edge_decal_family_for(&"sand", &"salt") == &"salt",
	)
	_add(
		cases,
		"lava borders select ember decals before generic volcanic fragments",
		TerrainRendererScript.edge_decal_family_for(&"volcanic_ash", &"lava") == &"ember",
	)
	var first: Vector2i = Vector2i(5, -18)
	var second: Vector2i = Vector2i(6, -18)
	var specs: Array[Dictionary] = TerrainRendererScript.edge_decal_specs_for(
		first, second, &"frost"
	)
	var reversed: Array[Dictionary] = TerrainRendererScript.edge_decal_specs_for(
		second, first, &"frost"
	)
	var bounded: bool = true
	for spec: Dictionary in specs:
		bounded = (
			bounded
			and float(spec[&"t"]) >= 0.08
			and float(spec[&"t"]) <= 0.92
			and absf(float(spec[&"side"])) == 1.0
			and float(spec[&"offset"]) >= 2.5
			and float(spec[&"offset"]) <= 7.0
			and float(spec[&"size"]) >= 2.4
			and float(spec[&"size"]) <= 6.2
		)
	_add(cases, "edge decal placement is traversal-order deterministic", specs == reversed)
	_add(cases, "edge decals remain sparse and inside their bounded seam corridor", bounded)


static func _test_surface_draw_order(cases: Array[Dictionary]) -> void:
	var surface: Node2D = TerrainSurfaceScript.new() as Node2D
	var renderer: RecordingRenderer = RecordingRenderer.new()
	surface.call("configure", renderer)
	var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT]
	surface.call("set_visible_cells", cells)
	surface.call("_draw")
	_add(
		cases,
		"terrain batches bases, masks, decals, then grid and hazard details",
		(
			renderer.calls
			== [
				"backdrop",
				"base:(0, 0)",
				"base:(1, 0)",
				"blend:(0, 0)",
				"blend:(1, 0)",
				"decal:(0, 0)",
				"decal:(1, 0)",
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


static func _float_range(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var minimum: float = values[0]
	var maximum: float = values[0]
	for value: float in values:
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
	return maximum - minimum


static func _depth_profiles_mirror(first: Array[float], second: Array[float]) -> bool:
	if first.size() != second.size():
		return false
	for index: int in range(first.size()):
		if not is_equal_approx(first[index], second[second.size() - 1 - index]):
			return false
	return true


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
