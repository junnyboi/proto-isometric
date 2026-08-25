extends RefCounted

const BiomeDestructiblesScript: GDScript = preload("res://scripts/biome_destructibles.gd")

const TERRAIN_TEXTURE_PERIOD_CELLS: float = 4.0
const TERRAIN_UV_VARIATION: float = 0.035
const WALKER_FOOT_SAMPLE_OFFSETS: Array[Vector2] = [Vector2(-24.0, 0.0), Vector2(24.0, 0.0)]
const SAND: Color = Color("d79a45")
const SAND_LIGHT: Color = Color("e8b861")
const SALT: Color = Color("d8d0b5")
const ROCK: Color = Color("934d35")
const WETLAND: Color = Color("879b55")
const MUD: Color = Color("2d281f")
const SNOW: Color = Color("dce8ed")
const BLUE_ICE: Color = Color("36a8c8")
const LAVA_BASALT: Color = Color("252326")
const VOLCANIC_ASH: Color = Color("8c8a86")
const LAVA: Color = Color("ff5a12")
const WOODLAND_GRASS: Color = Color("738b4d")
const GRID_LINE: Color = Color(0.18, 0.12, 0.08, 0.32)
const EDGE_NEIGHBORS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]
const TRANSITION_DEPTHS: Array[float] = [0.28, 0.18, 0.09]
const TRANSITION_ALPHAS: Array[float] = [0.07, 0.12, 0.20]
const TRANSITION_SEGMENTS: int = 6
const TRANSITION_IRREGULARITY: float = 0.34
const HAZARD_TRANSITION_DEPTH_SCALE: float = 0.68
const HAZARD_TRANSITION_ALPHA_SCALE: float = 0.70
const EDGE_DECAL_COUNTS: Dictionary = {
	&"wetland": 5,
	&"frost": 4,
	&"salt": 5,
	&"volcanic": 4,
	&"ember": 4,
	&"neutral": 3,
}
const TERRAIN_BLEND_COLORS: Dictionary = {
	&"sand": Color("c67832"),
	&"salt": Color("d9cfbd"),
	&"rock": Color("874627"),
	&"wetland": Color("9c9249"),
	&"mud": Color("251f19"),
	&"snow": Color("ccd6df"),
	&"blue_ice": Color("55b3da"),
	&"lava_basalt": Color("28292b"),
	&"volcanic_ash": Color("7e7e7d"),
	&"lava": Color("8c2511"),
	&"woodland_grass": Color("647e43"),
	&"farm_soil": Color("5c3b2b"),
}
const TEXTURES: Dictionary = {
	&"sand": preload("res://assets/textures/terrain/desert_sand.png"),
	&"salt": preload("res://assets/textures/terrain/salt_crust.png"),
	&"rock": preload("res://assets/textures/terrain/iron_rock.png"),
	&"wetland": preload("res://assets/textures/terrain/oasis_wetland.png"),
	&"mud": preload("res://assets/textures/terrain/dark_mud.png"),
	&"snow": preload("res://assets/textures/terrain/tundra_snow.png"),
	&"blue_ice": preload("res://assets/textures/terrain/blue_ice.png"),
	&"lava_basalt": preload("res://assets/textures/terrain/lava_basalt.png"),
	&"volcanic_ash": preload("res://assets/textures/terrain/volcanic_ash.png"),
	&"lava": preload("res://assets/textures/terrain/lava_flow.png"),
	&"woodland_grass": preload("res://assets/textures/terrain/woodland_grass.png"),
	&"farm_soil": preload("res://assets/textures/terrain/farm_soil.png"),
}

var _terrain: Dictionary
var _elevation: Dictionary
var _terrain_textures: Dictionary
var _tile_size: Vector2
var _map_origin: Vector2
var _biome_at: Callable


func configure(
	terrain: Dictionary,
	elevation: Dictionary,
	terrain_textures: Dictionary,
	tile_size: Vector2,
	map_origin: Vector2,
) -> void:
	_terrain = terrain
	_elevation = elevation
	_terrain_textures = terrain_textures
	_tile_size = tile_size
	_map_origin = map_origin


func set_biome_lookup(biome_at: Callable) -> void:
	_biome_at = biome_at


func grid_to_screen(cell: Vector2i) -> Vector2:
	var elevation_pixels: float = float(_elevation.get(cell, 0)) * 10.0
	return (
		_map_origin
		+ Vector2(
			float(cell.x - cell.y) * _tile_size.x * 0.5,
			float(cell.x + cell.y) * _tile_size.y * 0.5 - elevation_pixels,
		)
	)


static func occupied_cells_for(position: Vector2, screen_to_grid: Callable) -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	if not screen_to_grid.is_valid():
		return occupied
	for offset: Vector2 in WALKER_FOOT_SAMPLE_OFFSETS:
		var cell: Vector2i = screen_to_grid.call(position + offset) as Vector2i
		if cell not in occupied:
			occupied.append(cell)
	return occupied


func draw_tile(canvas: Node2D, cell: Vector2i) -> void:
	var center: Vector2 = grid_to_screen(cell)
	var height: float = float(_elevation.get(cell, 0)) * 10.0
	var points: PackedVector2Array = tile_points(cell)
	var terrain_id: StringName = display_terrain_at(cell)
	var color: Color = SAND if (cell.x + cell.y) % 2 == 0 else SAND_LIGHT
	var obstacle_palette: Dictionary = {}
	if terrain_id == &"salt":
		color = SALT
	elif terrain_id == &"rock":
		obstacle_palette = obstacle_palette_at(cell)
		color = obstacle_palette[&"top"] as Color
	elif terrain_id == &"wetland":
		color = WETLAND
	elif terrain_id == &"mud":
		color = MUD
	elif terrain_id == &"snow":
		color = SNOW
	elif terrain_id == &"blue_ice":
		color = BLUE_ICE
	elif terrain_id == &"lava_basalt":
		color = LAVA_BASALT
	elif terrain_id == &"volcanic_ash":
		color = VOLCANIC_ASH
	elif terrain_id == &"lava":
		color = LAVA
	elif terrain_id == &"woodland_grass":
		color = WOODLAND_GRASS

	if height > 0.0:
		(
			canvas
			. draw_colored_polygon(
				PackedVector2Array(
					[
						points[1],
						points[1] + Vector2(0.0, height),
						points[2] + Vector2(0.0, height),
						points[2],
					]
				),
				(
					obstacle_palette[&"right"] as Color
					if not obstacle_palette.is_empty()
					else color.darkened(0.38)
				),
			)
		)
		(
			canvas
			. draw_colored_polygon(
				PackedVector2Array(
					[
						points[2],
						points[2] + Vector2(0.0, height),
						points[3] + Vector2(0.0, height),
						points[3],
					]
				),
				(
					obstacle_palette[&"left"] as Color
					if not obstacle_palette.is_empty()
					else color.darkened(0.52)
				),
			)
		)

	canvas.draw_colored_polygon(points, color)
	var terrain_texture: Texture2D = _terrain_textures.get(terrain_id) as Texture2D
	if terrain_id == &"rock" and _biome_for(cell) != &"desert":
		terrain_texture = null
	if terrain_texture != null:
		canvas.draw_polygon(points, terrain_tints(cell), terrain_uvs(cell), terrain_texture)


func draw_tile_transitions(canvas: Node2D, cell: Vector2i) -> void:
	var points: PackedVector2Array = tile_points(cell)
	for transition: Dictionary in transition_descriptors_for(cell):
		var edge: int = int(transition[&"edge"])
		var neighbor: Vector2i = transition[&"neighbor"] as Vector2i
		var neighbor_points: PackedVector2Array = tile_points(neighbor)
		var opposite_edge: int = (edge + 2) % 4
		var scale: float = float(transition[&"scale"])
		var source_color: Color = transition[&"source_color"] as Color
		var neighbor_color: Color = transition[&"neighbor_color"] as Color
		var seed: int = int(transition[&"seed"])
		for index: int in range(TRANSITION_DEPTHS.size()):
			var depth: float = TRANSITION_DEPTHS[index] * scale
			var source_band: PackedVector2Array = transition_mask_points(
				points, edge, depth, seed, false
			)
			var neighbor_band: PackedVector2Array = transition_mask_points(
				neighbor_points, opposite_edge, depth, seed, true
			)
			var alpha: float = TRANSITION_ALPHAS[index] * float(transition[&"alpha_scale"])
			canvas.draw_colored_polygon(source_band, Color(neighbor_color, alpha))
			canvas.draw_colored_polygon(neighbor_band, Color(source_color, alpha))


func draw_tile_edge_decals(canvas: Node2D, cell: Vector2i) -> void:
	var points: PackedVector2Array = tile_points(cell)
	var center: Vector2 = grid_to_screen(cell)
	for transition: Dictionary in transition_descriptors_for(cell):
		var edge: int = int(transition[&"edge"])
		var start: Vector2 = points[edge]
		var finish: Vector2 = points[(edge + 1) % 4]
		var tangent: Vector2 = (finish - start).normalized()
		var inward: Vector2 = (center - (start + finish) * 0.5).normalized()
		var family: StringName = transition[&"decal_family"] as StringName
		var neighbor: Vector2i = transition[&"neighbor"] as Vector2i
		var specs: Array[Dictionary] = edge_decal_specs_for(cell, neighbor, family)
		for index: int in range(specs.size()):
			var spec: Dictionary = specs[index]
			var position: Vector2 = start.lerp(finish, float(spec[&"t"]))
			position += inward * float(spec[&"offset"]) * float(spec[&"side"])
			_draw_edge_decal(canvas, family, position, tangent, inward, spec, index)


func _draw_edge_decal(
	canvas: Node2D,
	family: StringName,
	position: Vector2,
	tangent: Vector2,
	inward: Vector2,
	spec: Dictionary,
	index: int,
) -> void:
	var size: float = float(spec[&"size"])
	var lean: float = float(spec[&"lean"])
	var direction: Vector2 = inward.rotated(lean)
	match family:
		&"wetland":
			if index % 2 == 0:
				var reed_size: float = size * 1.35
				(
					canvas
					. draw_line(
						position - direction * reed_size * 0.25,
						position + direction * reed_size,
						Color(0.34, 0.42, 0.18, 0.58),
						1.6,
					)
				)
				(
					canvas
					. draw_line(
						position,
						position + direction.rotated(-0.42) * reed_size * 0.74,
						Color(0.47, 0.51, 0.23, 0.42),
						1.2,
					)
				)
			else:
				canvas.draw_circle(position, size * 0.34, Color(0.12, 0.09, 0.06, 0.44))
		&"frost":
			(
				canvas
				. draw_colored_polygon(
					PackedVector2Array(
						[
							position - tangent * size * 0.48,
							position + direction * size,
							position + tangent * size * 0.38,
						]
					),
					Color(0.78, 0.92, 0.97, 0.52),
				)
			)
			(
				canvas
				. draw_line(
					position,
					position + direction * size * 0.72,
					Color(0.28, 0.67, 0.82, 0.58),
					1.0,
				)
			)
		&"salt":
			(
				canvas
				. draw_colored_polygon(
					PackedVector2Array(
						[
							position - tangent * size * 0.55,
							position - direction * size * 0.28,
							position + tangent * size * 0.45,
							position + direction * size * 0.32,
						]
					),
					Color(0.91, 0.86, 0.74, 0.58),
				)
			)
			if index % 2 == 0:
				(
					canvas
					. draw_line(
						position - tangent * size,
						position + tangent * size * 0.8,
						Color(0.72, 0.62, 0.44, 0.38),
						0.9,
					)
				)
		&"ember":
			_draw_volcanic_fragment(canvas, position, tangent, direction, size)
			if index % 2 == 0:
				(
					canvas
					. draw_circle(
						position + direction * size * 0.52,
						maxf(1.0, size * 0.18),
						Color(1.0, 0.43, 0.08, 0.72),
					)
				)
		&"volcanic":
			_draw_volcanic_fragment(canvas, position, tangent, direction, size)
		_:
			canvas.draw_circle(position, size * 0.32, Color(0.33, 0.29, 0.25, 0.42))


func _draw_volcanic_fragment(
	canvas: Node2D, position: Vector2, tangent: Vector2, direction: Vector2, size: float
) -> void:
	(
		canvas
		. draw_colored_polygon(
			PackedVector2Array(
				[
					position - tangent * size * 0.52,
					position + direction * size * 0.46,
					position + tangent * size * 0.44,
					position - direction * size * 0.25,
				]
			),
			Color(0.11, 0.11, 0.13, 0.62),
		)
	)


func draw_tile_details(canvas: Node2D, cell: Vector2i) -> void:
	var center: Vector2 = grid_to_screen(cell)
	var points: PackedVector2Array = tile_points(cell)
	var terrain_id: StringName = display_terrain_at(cell)
	for edge: int in range(4):
		canvas.draw_line(points[edge], points[(edge + 1) % 4], GRID_LINE, 1.2)
	if terrain_id == &"blue_ice":
		canvas.draw_line(
			center + Vector2(-23.0, 4.0),
			center + Vector2(19.0, -6.0),
			Color(0.75, 0.96, 1.0, 0.42),
			1.5
		)
	elif terrain_id == &"lava":
		var closed: PackedVector2Array = points.duplicate()
		closed.append(points[0])
		canvas.draw_polyline(closed, Color(1.0, 0.76, 0.18, 0.58), 2.0)


func transition_descriptors_for(cell: Vector2i) -> Array[Dictionary]:
	var transitions: Array[Dictionary] = []
	if not _terrain.has(cell) or int(_elevation.get(cell, 0)) != 0:
		return transitions
	var terrain_id: StringName = display_terrain_at(cell)
	if terrain_id == &"rock":
		return transitions
	for edge: int in range(EDGE_NEIGHBORS.size()):
		var neighbor_cell: Vector2i = cell + EDGE_NEIGHBORS[edge]
		if not _terrain.has(neighbor_cell) or int(_elevation.get(neighbor_cell, 0)) != 0:
			continue
		var neighbor_id: StringName = display_terrain_at(neighbor_cell)
		if neighbor_id == terrain_id or neighbor_id == &"rock":
			continue
		if not cell_precedes(cell, neighbor_cell):
			continue
		var hazard: bool = terrain_id == &"lava" or neighbor_id == &"lava"
		(
			transitions
			. append(
				{
					&"edge": edge,
					&"neighbor": neighbor_cell,
					&"source_terrain": terrain_id,
					&"neighbor_terrain": neighbor_id,
					&"source_color": TERRAIN_BLEND_COLORS.get(terrain_id, Color.WHITE),
					&"neighbor_color": TERRAIN_BLEND_COLORS.get(neighbor_id, Color.WHITE),
					&"decal_family": edge_decal_family_for(terrain_id, neighbor_id),
					&"seed": shared_edge_seed(cell, neighbor_cell),
					&"scale": HAZARD_TRANSITION_DEPTH_SCALE if hazard else 1.0,
					&"alpha_scale": HAZARD_TRANSITION_ALPHA_SCALE if hazard else 1.0,
				}
			)
		)
	return transitions


func tile_points(cell: Vector2i) -> PackedVector2Array:
	var center: Vector2 = grid_to_screen(cell)
	var half: Vector2 = _tile_size * 0.5
	return PackedVector2Array(
		[
			center + Vector2(0.0, -half.y),
			center + Vector2(half.x, 0.0),
			center + Vector2(0.0, half.y),
			center + Vector2(-half.x, 0.0),
		]
	)


static func transition_mask_points(
	points: PackedVector2Array,
	edge: int,
	depth: float,
	seed: int,
	reverse_profile: bool = false,
) -> PackedVector2Array:
	if points.size() != 4 or edge < 0 or edge >= 4:
		return PackedVector2Array()
	var center: Vector2 = (points[0] + points[1] + points[2] + points[3]) * 0.25
	var start: Vector2 = points[edge]
	var finish: Vector2 = points[(edge + 1) % 4]
	var result: PackedVector2Array = PackedVector2Array()
	var inner: PackedVector2Array = PackedVector2Array()
	for index: int in range(TRANSITION_SEGMENTS + 1):
		var t: float = float(index) / float(TRANSITION_SEGMENTS)
		var profile_index: int = TRANSITION_SEGMENTS - index if reverse_profile else index
		var edge_point: Vector2 = start.lerp(finish, t)
		var shaped_depth: float = depth * transition_depth_multiplier(seed, profile_index)
		result.append(edge_point)
		inner.append(edge_point.lerp(center, shaped_depth))
	for index: int in range(inner.size() - 1, -1, -1):
		result.append(inner[index])
	return result


static func transition_depth_multiplier(seed: int, sample_index: int) -> float:
	var t: float = float(sample_index) / float(TRANSITION_SEGMENTS)
	var envelope: float = sin(t * PI)
	var phase_a: float = seeded_unit(seed, 41) * TAU
	var phase_b: float = seeded_unit(seed, 67) * TAU
	var waves: float = sin(t * TAU + phase_a) * 0.18
	waves += sin(t * TAU * 2.0 + phase_b) * 0.08
	var jitter: float = (seeded_unit(seed, sample_index + 3) - 0.5) * TRANSITION_IRREGULARITY
	return clampf(1.0 + (waves + jitter) * envelope, 0.68, 1.36)


static func edge_decal_family_for(first: StringName, second: StringName) -> StringName:
	if first == &"lava" or second == &"lava":
		return &"ember"
	if first in [&"lava_basalt", &"volcanic_ash"] or second in [&"lava_basalt", &"volcanic_ash"]:
		return &"volcanic"
	if first in [&"snow", &"blue_ice"] or second in [&"snow", &"blue_ice"]:
		return &"frost"
	if first in [&"wetland", &"mud"] or second in [&"wetland", &"mud"]:
		return &"wetland"
	if first == &"salt" or second == &"salt":
		return &"salt"
	return &"neutral"


static func edge_decal_specs_for(
	cell: Vector2i, neighbor: Vector2i, family: StringName
) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var seed: int = shared_edge_seed(cell, neighbor)
	var count: int = int(EDGE_DECAL_COUNTS.get(family, EDGE_DECAL_COUNTS[&"neutral"]))
	for index: int in range(count):
		var interval: float = 1.0 / float(count)
		var jitter: float = (seeded_unit(seed, 101 + index) - 0.5) * interval * 0.62
		var t: float = clampf((float(index) + 0.5) * interval + jitter, 0.08, 0.92)
		(
			specs
			. append(
				{
					&"t": t,
					&"side": 1.0 if seeded_unit(seed, 151 + index) >= 0.5 else -1.0,
					&"offset": 2.5 + seeded_unit(seed, 201 + index) * 4.5,
					&"size": 2.4 + seeded_unit(seed, 251 + index) * 3.8,
					&"lean": (seeded_unit(seed, 301 + index) - 0.5) * 0.86,
				}
			)
		)
	return specs


static func cell_precedes(first: Vector2i, second: Vector2i) -> bool:
	return first.x < second.x or (first.x == second.x and first.y < second.y)


static func shared_edge_seed(first: Vector2i, second: Vector2i) -> int:
	var low: Vector2i = first if cell_precedes(first, second) else second
	var high: Vector2i = second if low == first else first
	return posmod(
		(
			(low.x + 257) * 73856093
			+ (low.y + 257) * 19349663
			+ (high.x + 257) * 83492791
			+ (high.y + 257) * 297121507
		),
		2147483647,
	)


static func seeded_unit(seed: int, channel: int) -> float:
	var value: int = posmod(seed + (channel + 1) * 104729, 2147483647)
	value = posmod(value * 48271, 2147483647)
	return float(value) / 2147483647.0


func obstacle_palette_at(cell: Vector2i) -> Dictionary:
	var biome: StringName = _biome_for(cell)
	var kind: StringName = BiomeDestructiblesScript.kind_for(biome, cell)
	return BiomeDestructiblesScript.block_palette_for(kind)


func _biome_for(cell: Vector2i) -> StringName:
	return _biome_at.call(cell) as StringName if _biome_at.is_valid() else &"desert"


func display_terrain_at(cell: Vector2i) -> StringName:
	var terrain_id: StringName = _terrain.get(cell, &"sand") as StringName
	if terrain_id != &"ruin":
		return terrain_id
	var counts: Dictionary = {}
	for offset: Vector2i in [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1),
		Vector2i(1, 1),
	]:
		var neighbor: StringName = _terrain.get(cell + offset, &"") as StringName
		if neighbor in [&"", &"ruin", &"rock"]:
			continue
		counts[neighbor] = int(counts.get(neighbor, 0)) + 1
	var display_id: StringName = &"sand"
	var best_count: int = 0
	for value: Variant in counts:
		var candidate: StringName = value as StringName
		var candidate_count: int = int(counts[candidate])
		if candidate_count > best_count:
			display_id = candidate
			best_count = candidate_count
	return display_id


func draw_world_backdrop(canvas: Node2D, robot_position: Vector2) -> void:
	var backdrop_origin: Vector2 = robot_position - Vector2(2000.0, 1500.0)
	canvas.draw_rect(Rect2(backdrop_origin, Vector2(4000.0, 3000.0)), Color("24170f"))


func terrain_uvs(cell: Vector2i) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in _terrain_grid_vertices(cell):
		var warp: Vector2 = (
			Vector2(
				sin(point.x * 0.31 + point.y * 0.17),
				cos(point.y * 0.27 - point.x * 0.13),
			)
			* TERRAIN_UV_VARIATION
		)
		result.append(point / TERRAIN_TEXTURE_PERIOD_CELLS + warp)
	return result


func terrain_tints(cell: Vector2i) -> PackedColorArray:
	var result: PackedColorArray = PackedColorArray()
	for point: Vector2 in _terrain_grid_vertices(cell):
		var wave: float = (
			(sin(point.x * 0.39) + cos(point.y * 0.33) + sin((point.x + point.y) * 0.16)) / 3.0
		)
		var brightness: float = 0.96 + wave * 0.055
		result.append(Color(brightness * 1.025, brightness, brightness * 0.96, 1.0))
	return result


func _terrain_grid_vertices(cell: Vector2i) -> Array[Vector2]:
	var center: Vector2 = Vector2(cell)
	return [
		center + Vector2(-0.5, -0.5),
		center + Vector2(0.5, -0.5),
		center + Vector2(0.5, 0.5),
		center + Vector2(-0.5, 0.5),
	]
