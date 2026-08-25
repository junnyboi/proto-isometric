extends Node2D

const STATE_HIDDEN: StringName = &"hidden"
const STATE_VALID: StringName = &"valid"
const STATE_CONTEXT: StringName = &"context"
const STATE_BLOCKED: StringName = &"blocked"
const STATES: Array[StringName] = [STATE_HIDDEN, STATE_VALID, STATE_CONTEXT, STATE_BLOCKED]

const VALID_COLOR: Color = Color(0.30, 0.86, 0.66, 0.92)
const CONTEXT_COLOR: Color = Color(0.96, 0.69, 0.22, 0.94)
const BLOCKED_COLOR: Color = Color(0.92, 0.32, 0.27, 0.88)

var _state: StringName = STATE_HIDDEN
var _cell: Vector2i = Vector2i.ZERO
var _grid_to_screen: Callable
var _tile_size: Vector2 = Vector2(90.0, 45.0)
var _redraw_request_count: int = 0


func configure(grid_to_screen: Callable, tile_size: Vector2 = Vector2(90.0, 45.0)) -> bool:
	if not grid_to_screen.is_valid() or tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return false
	_grid_to_screen = grid_to_screen
	_tile_size = tile_size
	return true


func present(result: Dictionary, context_mode: bool = false) -> void:
	var next_cell: Vector2i = result.get(&"target_cell", _cell) as Vector2i
	var next_state: StringName = STATE_BLOCKED
	if bool(result.get(&"valid", false)):
		next_state = STATE_CONTEXT if context_mode else STATE_VALID
	_set_snapshot(next_cell, next_state)


func hide_reticle() -> void:
	_set_snapshot(_cell, STATE_HIDDEN)


func get_snapshot() -> Dictionary:
	return {&"cell": _cell, &"state": _state}


func get_redraw_request_count() -> int:
	return _redraw_request_count


func _set_snapshot(cell: Vector2i, state: StringName) -> void:
	if state not in STATES or (cell == _cell and state == _state):
		return
	_cell = cell
	_state = state
	_redraw_request_count += 1
	queue_redraw()


func _draw() -> void:
	if _state == STATE_HIDDEN or not _grid_to_screen.is_valid():
		return
	var center: Vector2 = _grid_to_screen.call(_cell) as Vector2
	var half_width: float = _tile_size.x * 0.42
	var half_height: float = _tile_size.y * 0.42
	var diamond: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -half_height),
		center + Vector2(half_width, 0.0),
		center + Vector2(0.0, half_height),
		center + Vector2(-half_width, 0.0),
		center + Vector2(0.0, -half_height),
	])
	var color: Color = VALID_COLOR
	if _state == STATE_CONTEXT:
		color = CONTEXT_COLOR
	elif _state == STATE_BLOCKED:
		color = BLOCKED_COLOR
	draw_colored_polygon(diamond.slice(0, 4), Color(color, 0.12))
	draw_polyline(diamond, Color(0.04, 0.06, 0.08, 0.9), 7.0, true)
	draw_polyline(diamond, color, 3.0, true)
