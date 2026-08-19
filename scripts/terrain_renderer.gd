extends RefCounted

const TERRAIN_TEXTURE_PERIOD_CELLS: float = 4.0
const TERRAIN_UV_VARIATION: float = 0.035
const SAND: Color = Color("d79a45")
const SAND_LIGHT: Color = Color("e8b861")
const SALT: Color = Color("d8d0b5")
const ROCK: Color = Color("934d35")
const RUIN: Color = Color("39454a")
const WETLAND: Color = Color("879b55")
const MUD: Color = Color("2d281f")
const SNOW: Color = Color("dce8ed")
const BLUE_ICE: Color = Color("36a8c8")
const LAVA_BASALT: Color = Color("252326")
const VOLCANIC_ASH: Color = Color("8c8a86")
const LAVA: Color = Color("ff5a12")
const TEAL: Color = Color("4eb6aa")
const GRID_LINE: Color = Color(0.18, 0.12, 0.08, 0.32)
const TEXTURES: Dictionary = {
	&"sand": preload("res://assets/textures/terrain/desert_sand.png"),
	&"salt": preload("res://assets/textures/terrain/salt_crust.png"),
	&"rock": preload("res://assets/textures/terrain/iron_rock.png"),
	&"ruin": preload("res://assets/textures/terrain/ancient_ruin.png"),
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


func grid_to_screen(cell: Vector2i) -> Vector2:
	var elevation_pixels: float = float(_elevation.get(cell, 0)) * 10.0
	return (
		_map_origin
		+ Vector2(
			float(cell.x - cell.y) * _tile_size.x * 0.5,
			float(cell.x + cell.y) * _tile_size.y * 0.5 - elevation_pixels,
		)
	)


func draw_tile(canvas: Node2D, cell: Vector2i) -> void:
	var center: Vector2 = grid_to_screen(cell)
	var half: Vector2 = _tile_size * 0.5
	var height: float = float(_elevation.get(cell, 0)) * 10.0
	var points: PackedVector2Array = PackedVector2Array(
		[
			center + Vector2(0.0, -half.y),
			center + Vector2(half.x, 0.0),
			center + Vector2(0.0, half.y),
			center + Vector2(-half.x, 0.0),
		]
	)
	var terrain_id: StringName = _terrain.get(cell, &"sand") as StringName
	var color: Color = SAND if (cell.x + cell.y) % 2 == 0 else SAND_LIGHT
	if terrain_id == &"salt":
		color = SALT
	elif terrain_id == &"rock":
		color = ROCK
	elif terrain_id == &"ruin":
		color = RUIN
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
				color.darkened(0.38),
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
				color.darkened(0.52),
			)
		)

	canvas.draw_colored_polygon(points, color)
	var terrain_texture: Texture2D = _terrain_textures.get(terrain_id) as Texture2D
	if terrain_texture != null:
		canvas.draw_polygon(points, terrain_tints(cell), terrain_uvs(cell), terrain_texture)
	for edge: int in range(4):
		canvas.draw_line(points[edge], points[(edge + 1) % 4], GRID_LINE, 1.2)
	if terrain_id == &"ruin":
		canvas.draw_circle(center, 6.0, TEAL.darkened(0.15))
		canvas.draw_arc(center, 13.0, 0.0, TAU, 20, TEAL, 2.0)
	elif terrain_id == &"blue_ice":
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
