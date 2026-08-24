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
const TEAL: Color = Color("4eb6aa")
const AMBER: Color = Color("f5a62d")
const GRID_LINE: Color = Color(0.18, 0.12, 0.08, 0.32)
const EDGE_NEIGHBORS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]
const TRANSITION_DEPTHS: Array[float] = [0.28, 0.18, 0.09]
const TRANSITION_ALPHAS: Array[float] = [0.07, 0.12, 0.20]
const HAZARD_TRANSITION_DEPTH_SCALE: float = 0.68
const HAZARD_TRANSITION_ALPHA_SCALE: float = 0.70
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
		var scale: float = float(transition[&"scale"])
		var color: Color = transition[&"color"] as Color
		for index: int in range(TRANSITION_DEPTHS.size()):
			var band: PackedVector2Array = transition_band_points(
				points, edge, TRANSITION_DEPTHS[index] * scale
			)
			(
				canvas
				. draw_colored_polygon(
					band,
					Color(color, TRANSITION_ALPHAS[index] * float(transition[&"alpha_scale"])),
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
		var hazard: bool = terrain_id == &"lava" or neighbor_id == &"lava"
		(
			transitions
			. append(
				{
					&"edge": edge,
					&"neighbor": neighbor_cell,
					&"terrain": neighbor_id,
					&"color": TERRAIN_BLEND_COLORS.get(neighbor_id, Color.WHITE),
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


static func transition_band_points(
	points: PackedVector2Array, edge: int, depth: float
) -> PackedVector2Array:
	if points.size() != 4 or edge < 0 or edge >= 4:
		return PackedVector2Array()
	var center: Vector2 = (points[0] + points[1] + points[2] + points[3]) * 0.25
	var start: Vector2 = points[edge]
	var finish: Vector2 = points[(edge + 1) % 4]
	return PackedVector2Array(
		[start, finish, finish.lerp(center, depth), start.lerp(center, depth)]
	)


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


func draw_drive_vector(
	canvas: Node2D,
	robot_position: Vector2,
	screen_direction: Vector2i,
	velocity: Vector2,
	running: bool,
) -> void:
	var vector: Vector2 = Vector2(screen_direction).normalized()
	var start: Vector2 = robot_position + Vector2(0.0, 15.0)
	var finish: Vector2 = start + vector * (36.0 + minf(velocity.length() * 0.12, 30.0))
	canvas.draw_line(start, finish, TEAL, 4.0)
	canvas.draw_circle(finish, 5.0, AMBER if running else TEAL)


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
