extends Node2D

var _renderer: RefCounted
var _performance_sampler: Node
var _visible_cells: Array[Vector2i] = []
var _rebuild_request_count: int = 0
var _batch_draw_count: int = 0


func _ready() -> void:
	name = "TerrainSurface"
	show_behind_parent = true
	z_index = -100


func configure(renderer: RefCounted, performance_sampler: Node = null) -> bool:
	_renderer = renderer
	_performance_sampler = performance_sampler
	return _renderer != null


func set_visible_cells(cells: Array[Vector2i]) -> bool:
	if cells == _visible_cells:
		return false
	_visible_cells = cells.duplicate()
	invalidate()
	return true


func invalidate() -> void:
	_rebuild_request_count += 1
	if _performance_sampler != null:
		_performance_sampler.call("increment_counter", &"terrain.rebuild_requests")
		_performance_sampler.call(
			"set_gauge", &"terrain.cached_cells", float(_visible_cells.size())
		)
	queue_redraw()


func get_cached_cell_count() -> int:
	return _visible_cells.size()


func get_rebuild_request_count() -> int:
	return _rebuild_request_count


func get_batch_draw_count() -> int:
	return _batch_draw_count


func _draw() -> void:
	if _renderer == null or _visible_cells.is_empty():
		return
	_batch_draw_count += 1
	if _performance_sampler != null:
		_performance_sampler.call("increment_counter", &"terrain.batch_draws")
	var center_cell: Vector2i = _visible_cells[_visible_cells.size() / 2]
	var center: Vector2 = _renderer.call("grid_to_screen", center_cell) as Vector2
	_renderer.call("draw_world_backdrop", self, center)
	for cell: Vector2i in _visible_cells:
		_renderer.call("draw_tile", self, cell)
