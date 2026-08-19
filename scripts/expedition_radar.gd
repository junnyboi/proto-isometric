extends Control

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")

const AMBER: Color = Color("f5a62d")
const TEAL: Color = Color("4eb6aa")
const BONE: Color = Color("d8d0b5")

var _coordinator: RefCounted
var _objectives: Array = []
var _player_cell: Vector2i = Vector2i.ZERO
var _completed_relays: int = 0
var _redraw_request_count: int = 0


func _ready() -> void:
	name = "ExpeditionRadar"
	size = Vector2(188.0, 188.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func configure(coordinator: RefCounted) -> bool:
	_coordinator = coordinator
	if coordinator == null:
		_objectives.clear()
		return false
	_objectives = coordinator.call("get_run_value", &"relay_objectives") as Array
	return sync_state(
		coordinator.call("get_run_value", &"player_cell") as Vector2i,
		int(coordinator.call("get_run_value", &"completed_relays")),
		true,
	)


func sync_state(player_cell: Vector2i, completed_relays: int, force: bool = false) -> bool:
	var bounded_completed: int = clampi(completed_relays, 0, _objectives.size())
	if not force and player_cell == _player_cell and bounded_completed == _completed_relays:
		return false
	_player_cell = player_cell
	_completed_relays = bounded_completed
	_request_redraw()
	return true


func get_objective_count() -> int:
	return _objectives.size()


func get_redraw_request_count() -> int:
	return _redraw_request_count


func _draw() -> void:
	if _coordinator == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.04, 0.86))
	draw_rect(Rect2(Vector2.ZERO, size), Color(TEAL, 0.42), false, 2.0)
	var center: Vector2 = size * 0.5
	draw_circle(center, 4.5, BONE)
	for index: int in range(_objectives.size()):
		var cell_value: Array = (_objectives[index] as Dictionary)[&"cell"] as Array
		var offset: Vector2 = (
			Vector2(float(cell_value[0]), float(cell_value[1])) - Vector2(_player_cell)
		)
		var point: Vector2 = center + offset.limit_length(78.0)
		var color: Color = TEAL if index < _completed_relays else AMBER
		draw_line(center, point, Color(color, 0.18), 1.0)
		draw_circle(point, 5.0 if index == _completed_relays else 3.5, color)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(10.0, 20.0),
		LocalizationScript.t(&"radar.route", {"completed": _completed_relays}),
		HORIZONTAL_ALIGNMENT_LEFT,
		120.0,
		14,
		BONE,
	)


func _apply_layout() -> void:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var portrait: bool = viewport.y > viewport.x
	var scale_value: float = minf(1.0, viewport.x / (560.0 if portrait else 1280.0))
	scale = Vector2.ONE * scale_value
	position = Vector2(
		viewport.x - size.x * scale_value - 18.0,
		viewport.y * 0.38 if portrait else 76.0,
	)


func _request_redraw() -> void:
	_redraw_request_count += 1
	queue_redraw()
