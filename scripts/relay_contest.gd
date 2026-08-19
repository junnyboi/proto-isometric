extends Node2D

signal link_started(relay_cell: Vector2i)
signal completed(relay_cell: Vector2i)

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const IsometricControlsScript: GDScript = preload("res://scripts/isometric_controls.gd")

const LINK_RADIUS_CELLS: float = 2.5
const LINK_SECONDS: float = 3.5
const DORMANT_SECONDS: float = 0.45
const TEAL: Color = Color("4eb6aa")
const AMBER: Color = Color("f5a62d")
const DARK: Color = Color("162328")

var _tile_size: Vector2 = Vector2(90.0, 45.0)
var _map_origin: Vector2 = Vector2(760.0, 70.0)
var _relay_cell: Vector2i = Vector2i.ZERO
var _player_position: Vector2 = Vector2.ZERO
var _state: StringName = &"dormant"
var _state_time: float = 0.0
var _signal_time: float = 0.0
var _link_progress: float = 0.0
var _encounter_started: bool = false
var _completion_flash: float = 0.0


func configure(
	relay_cell: Vector2i,
	tile_size: Vector2,
	map_origin: Vector2,
	is_completed: bool = false,
) -> void:
	_relay_cell = relay_cell
	_tile_size = tile_size
	_map_origin = map_origin
	set_completed(is_completed)


func set_player_position(position: Vector2) -> void:
	_player_position = position


func advance(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	_signal_time += step
	_completion_flash = maxf(_completion_flash - step, 0.0)
	if _state == &"completed":
		queue_redraw()
		return
	_state_time += step
	if _state == &"dormant" and _state_time >= DORMANT_SECONDS:
		_state = &"signaling"
		_state_time = 0.0
	var inside: bool = _player_position.distance_to(Vector2(_relay_cell)) <= LINK_RADIUS_CELLS
	if _state == &"linking":
		if not inside:
			_state = &"signaling"
			_state_time = 0.0
			_link_progress = 0.0
		else:
			_link_progress = clampf(_link_progress + step / LINK_SECONDS, 0.0, 1.0)
			if _link_progress >= 1.0:
				_state = &"completed"
				_completion_flash = 0.8
				completed.emit(_relay_cell)
	elif inside and _state == &"signaling":
		_state = &"linking"
		_state_time = 0.0
		_link_progress = 0.0
		if not _encounter_started:
			_encounter_started = true
			link_started.emit(_relay_cell)
	queue_redraw()


func set_completed(value: bool) -> void:
	_state = &"completed" if value else &"dormant"
	_state_time = 0.0
	_link_progress = 1.0 if value else 0.0
	_encounter_started = value
	_completion_flash = 0.0
	queue_redraw()


func get_state() -> StringName:
	return _state


func get_progress() -> float:
	return _link_progress


func is_completed() -> bool:
	return _state == &"completed"


func get_relay_cell() -> Vector2i:
	return _relay_cell


func get_signal_hint() -> String:
	if is_completed():
		return LocalizationScript.t(&"relay.return_outpost")
	var delta: Vector2 = Vector2(_relay_cell) - _player_position
	var screen_delta: Vector2 = Vector2(delta.x - delta.y, delta.x + delta.y)
	var screen_direction: Vector2i = Vector2i(
		0 if absf(screen_delta.x) < 0.25 else (1 if screen_delta.x > 0.0 else -1),
		0 if absf(screen_delta.y) < 0.25 else (1 if screen_delta.y > 0.0 else -1),
	)
	var direction_name: StringName = IsometricControlsScript.direction_name(screen_direction)
	return (
		LocalizationScript
		. t(
			&"relay.signal",
			{
				"direction": LocalizationScript.t("direction.%s" % direction_name),
				"distance": "%.1f" % delta.length(),
			}
		)
	)


func _grid_to_screen(position: Vector2) -> Vector2:
	return (
		_map_origin
		+ Vector2(
			(position.x - position.y) * _tile_size.x * 0.5,
			(position.x + position.y) * _tile_size.y * 0.5,
		)
	)


func _draw() -> void:
	var center: Vector2 = _grid_to_screen(Vector2(_relay_cell))
	var pulse: float = 0.5 + 0.5 * sin(_signal_time * 3.2)
	draw_circle(center, 18.0, Color(DARK, 0.94))
	draw_circle(center + Vector2(0.0, -13.0), 8.0, TEAL if is_completed() else AMBER)
	if _state == &"completed":
		draw_arc(center, 46.0, 0.0, TAU, 42, TEAL, 5.0)
		if _completion_flash > 0.0:
			draw_arc(
				center,
				54.0 + (1.0 - _completion_flash / 0.8) * 82.0,
				0.0,
				TAU,
				48,
				Color(TEAL, _completion_flash),
				6.0,
			)
		return
	var signal_color: Color = TEAL
	signal_color.a = 0.32 + pulse * 0.38
	draw_arc(center, 48.0 + pulse * 16.0, 0.0, TAU, 42, signal_color, 3.0)
	if _state == &"linking":
		draw_arc(
			center,
			39.0,
			-PI * 0.5,
			-PI * 0.5 + TAU * _link_progress,
			42,
			AMBER,
			7.0,
		)
