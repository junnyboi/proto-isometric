extends Node2D

const CatalogScript: GDScript = preload("res://scripts/construction_blueprint_catalog.gd")

var _grid_to_screen: Callable
var _blueprint_id: StringName = &""
var _anchor: Vector2i = Vector2i.ZERO
var _orientation: int = 0
var _preview: Dictionary = {}


func configure(grid_to_screen: Callable) -> bool:
	if not grid_to_screen.is_valid():
		return false
	_grid_to_screen = grid_to_screen
	return true


func present(
	blueprint_id: StringName,
	anchor: Vector2i,
	orientation: int,
	preview: Dictionary,
) -> void:
	_blueprint_id = blueprint_id
	_anchor = anchor
	_orientation = orientation
	_preview = preview.duplicate(true)
	visible = true
	queue_redraw()


func clear() -> void:
	_preview.clear()
	visible = false
	queue_redraw()


func _draw() -> void:
	if not visible or not _grid_to_screen.is_valid() or _preview.is_empty():
		return
	var valid: bool = bool(_preview.get(&"ok", false))
	var fill: Color = Color("3fd7c2") if valid else Color("e85d5d")
	fill.a = 0.32
	var outline: Color = Color("c7fff5") if valid else Color("ffd0d0")
	for cell: Vector2i in _preview.get(&"cells", []) as Array[Vector2i]:
		_draw_cell(cell, fill, outline)
	var entrance: Vector2i = _preview.get(&"entrance", _anchor) as Vector2i
	_draw_cell(entrance, Color(0.94, 0.76, 0.25, 0.34), Color("ffe7a0"))
	var definition: Dictionary = CatalogScript.definition(_blueprint_id)
	if definition.is_empty():
		return
	var texture: Texture2D = CatalogScript.texture_for(_blueprint_id, &"complete")
	if texture == null:
		return
	var center: Vector2 = _grid_to_screen.call(_anchor) as Vector2
	var size: Vector2 = definition[&"draw_size"] as Vector2
	var offset: Vector2 = definition[&"draw_offset"] as Vector2
	var rect: Rect2 = Rect2(center + offset - size * 0.5, size)
	draw_texture_rect(texture, rect, false, Color(1.0, 1.0, 1.0, 0.58))


func _draw_cell(cell: Vector2i, fill: Color, outline: Color) -> void:
	var center: Vector2 = _grid_to_screen.call(cell) as Vector2
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -16.0),
		center + Vector2(32.0, 0.0),
		center + Vector2(0.0, 16.0),
		center + Vector2(-32.0, 0.0),
	])
	draw_colored_polygon(points, fill)
	for index: int in 4:
		draw_line(points[index], points[(index + 1) % 4], outline, 2.0, true)
