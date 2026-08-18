extends Control

const AMBER: Color = Color("f5a62d")
const TEAL: Color = Color("4eb6aa")
const BONE: Color = Color("d8d0b5")

var _coordinator: RefCounted


func _ready() -> void:
	name = "ExpeditionRadar"
	position = Vector2(1072.0, 76.0)
	size = Vector2(188.0, 188.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(coordinator: RefCounted) -> bool:
	_coordinator = coordinator
	return coordinator != null


func _process(_delta: float) -> void:
	queue_redraw()


func get_objective_count() -> int:
	return _objectives().size()


func _draw() -> void:
	if _coordinator == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.04, 0.86))
	draw_rect(Rect2(Vector2.ZERO, size), Color(TEAL, 0.42), false, 2.0)
	var center: Vector2 = size * 0.5
	draw_circle(center, 4.5, BONE)
	var player: Vector2 = Vector2(_coordinator.call("get_run_value", &"player_cell"))
	var completed: int = int(_coordinator.call("get_run_value", &"completed_relays"))
	var objectives: Array = _objectives()
	for index: int in range(objectives.size()):
		var cell_value: Array = (objectives[index] as Dictionary)[&"cell"] as Array
		var offset: Vector2 = Vector2(float(cell_value[0]), float(cell_value[1])) - player
		var point: Vector2 = center + offset.limit_length(78.0)
		var color: Color = TEAL if index < completed else AMBER
		draw_line(center, point, Color(color, 0.18), 1.0)
		draw_circle(point, 5.0 if index == completed else 3.5, color)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(10.0, 20.0),
		"ROUTE %d/3" % completed,
		HORIZONTAL_ALIGNMENT_LEFT,
		120.0,
		14,
		BONE,
	)


func _objectives() -> Array:
	return (
		_coordinator.call("get_run_value", &"relay_objectives") as Array
		if _coordinator != null
		else []
	)
