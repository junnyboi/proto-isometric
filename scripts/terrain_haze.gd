extends CanvasLayer

const HEAT_HAZE_SHADER: Shader = preload("res://shaders/heat_haze.gdshader")

var _grid_size: Vector2i = Vector2i.ZERO
var _tile_size: Vector2 = Vector2.ZERO
var _map_origin: Vector2 = Vector2.ZERO


func configure(grid_size: Vector2i, tile_size: Vector2, map_origin: Vector2) -> void:
	_grid_size = grid_size
	_tile_size = tile_size
	_map_origin = map_origin


func _ready() -> void:
	layer = 1
	follow_viewport_enabled = true
	var haze: Polygon2D = Polygon2D.new()
	haze.name = "HeatHaze"
	haze.polygon = _map_polygon()
	haze.color = Color.WHITE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = HEAT_HAZE_SHADER
	haze.material = material
	add_child(haze)


func _map_polygon() -> PackedVector2Array:
	var maximum: Vector2 = Vector2(_grid_size) - Vector2(0.5, 0.5)
	var corners: Array[Vector2] = [
		Vector2(-0.5, -0.5),
		Vector2(maximum.x, -0.5),
		maximum,
		Vector2(-0.5, maximum.y),
	]
	var points: PackedVector2Array = PackedVector2Array()
	for corner: Vector2 in corners:
		(
			points
			. append(
				(
					_map_origin
					+ Vector2(
						(corner.x - corner.y) * _tile_size.x * 0.5,
						(corner.x + corner.y) * _tile_size.y * 0.5,
					)
				)
			)
		)
	return points


func get_polygon_point_count() -> int:
	var haze: Polygon2D = get_node("HeatHaze") as Polygon2D
	return haze.polygon.size()
