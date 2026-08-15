extends Node2D

const HEAT_HAZE_SHADER: Shader = preload("res://shaders/heat_haze.gdshader")

var _terrain: Dictionary = {}
var _grid_size: Vector2i = Vector2i.ZERO
var _tile_size: Vector2 = Vector2.ZERO
var _map_origin: Vector2 = Vector2.ZERO


func configure(
	terrain: Dictionary, grid_size: Vector2i, tile_size: Vector2, map_origin: Vector2
) -> void:
	_terrain = terrain
	_grid_size = grid_size
	_tile_size = tile_size
	_map_origin = map_origin


func _ready() -> void:
	z_index = 1
	var haze_material: ShaderMaterial = ShaderMaterial.new()
	haze_material.shader = HEAT_HAZE_SHADER
	material = haze_material
	queue_redraw()


func _draw() -> void:
	for y: int in range(_grid_size.y):
		for x: int in range(_grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			if not has_haze_at(cell):
				continue
			draw_colored_polygon(_tile_polygon(cell), Color.WHITE)


func has_haze_at(cell: Vector2i) -> bool:
	return _terrain.get(cell, &"sand") == &"sand"


func get_haze_tile_count() -> int:
	var count: int = 0
	for y: int in range(_grid_size.y):
		for x: int in range(_grid_size.x):
			if has_haze_at(Vector2i(x, y)):
				count += 1
	return count


func refresh_mask() -> void:
	queue_redraw()


func _tile_polygon(cell: Vector2i) -> PackedVector2Array:
	var center: Vector2 = (
		_map_origin
		+ Vector2(
			float(cell.x - cell.y) * _tile_size.x * 0.5,
			float(cell.x + cell.y) * _tile_size.y * 0.5,
		)
	)
	var half: Vector2 = _tile_size * 0.5
	return PackedVector2Array(
		[
			center + Vector2(0.0, -half.y),
			center + Vector2(half.x, 0.0),
			center + Vector2(0.0, half.y),
			center + Vector2(-half.x, 0.0),
		]
	)
