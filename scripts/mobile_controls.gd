extends CanvasLayer

signal smash_pressed

const TEAL: Color = Color("4eb6aa")
const AMBER: Color = Color("f5a62d")
const INK: Color = Color("11171b")
const JOYSTICK_RADIUS: float = 76.0
const KNOB_RADIUS: float = 31.0
const DEAD_ZONE: float = 12.0
const SMASH_SIZE: Vector2 = Vector2(154.0, 154.0)
const VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 720.0)

var _mobile_device: bool = false
var _controls_enabled: bool = true
var _touch_index: int = -1
var _touch_origin: Vector2 = Vector2.ZERO
var _touch_position: Vector2 = Vector2.ZERO
var _drive_vector: Vector2 = Vector2.ZERO
var _joystick: Control
var _smash_button: Button


func _ready() -> void:
	layer = 6
	_mobile_device = _detect_mobile_device()
	_build_joystick()
	_build_smash_button()
	_apply_visibility()


func _input(event: InputEvent) -> void:
	if not _mobile_device or not _controls_enabled:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			begin_touch(touch.index, touch.position)
		else:
			end_touch(touch.index)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		drag_touch(drag.index, drag.position)


func get_drive_vector() -> Vector2:
	return _drive_vector


func is_mobile_device() -> bool:
	return _mobile_device


func is_joystick_visible() -> bool:
	return _joystick != null and _joystick.visible


func get_smash_button() -> Button:
	return _smash_button


func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	if not enabled:
		_cancel_joystick()
	_apply_visibility()


func force_mobile(enabled: bool) -> void:
	_mobile_device = enabled
	_cancel_joystick()
	_apply_visibility()


func begin_touch(index: int, position: Vector2) -> bool:
	if not _mobile_device or not _controls_enabled or _touch_index >= 0:
		return false
	if _smash_button != null and _smash_button.get_global_rect().has_point(position):
		return false
	_touch_index = index
	_touch_origin = _clamp_origin(position)
	_touch_position = _touch_origin
	_drive_vector = Vector2.ZERO
	_joystick.position = _touch_origin - Vector2.ONE * JOYSTICK_RADIUS
	_joystick.visible = true
	_joystick.queue_redraw()
	return true


func drag_touch(index: int, position: Vector2) -> Vector2:
	if index != _touch_index:
		return _drive_vector
	_touch_position = position
	_update_drive_vector()
	_joystick.queue_redraw()
	return _drive_vector


func end_touch(index: int) -> bool:
	if index != _touch_index:
		return false
	_cancel_joystick()
	return true


func trigger_smash() -> void:
	if _mobile_device and _controls_enabled:
		smash_pressed.emit()


func _detect_mobile_device() -> bool:
	if OS.has_feature("mobile"):
		return true
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return false
	var result: Variant = (
		JavaScriptBridge
		. eval(
			(
				"new URLSearchParams(location.search).get('mobile')==='1' || "
				+ "navigator.maxTouchPoints>0 || matchMedia('(pointer: coarse)').matches || "
				+ "/Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent)"
			),
			true,
		)
	)
	return bool(result)


func _build_joystick() -> void:
	_joystick = Control.new()
	_joystick.name = "FloatingJoystick"
	_joystick.size = Vector2.ONE * JOYSTICK_RADIUS * 2.0
	_joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick.visible = false
	_joystick.draw.connect(_draw_joystick)
	add_child(_joystick)


func _build_smash_button() -> void:
	_smash_button = Button.new()
	_smash_button.name = "SmashButton"
	_smash_button.position = VIEWPORT_SIZE - SMASH_SIZE - Vector2(42.0, 42.0)
	_smash_button.size = SMASH_SIZE
	_smash_button.text = "SMASH"
	_smash_button.focus_mode = Control.FOCUS_NONE
	_smash_button.add_theme_font_size_override("font_size", 24)
	_smash_button.add_theme_color_override("font_color", Color("fff4dc"))
	_smash_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	_smash_button.add_theme_stylebox_override("normal", _button_style(Color(INK, 0.82), AMBER, 4.0))
	_smash_button.add_theme_stylebox_override(
		"pressed", _button_style(Color(AMBER, 0.9), Color.WHITE, 6.0)
	)
	_smash_button.add_theme_stylebox_override(
		"hover", _button_style(Color(INK, 0.9), Color("ffc66a"), 5.0)
	)
	_smash_button.button_down.connect(func() -> void: _smash_button.scale = Vector2(0.95, 0.95))
	_smash_button.button_up.connect(func() -> void: _smash_button.scale = Vector2.ONE)
	_smash_button.pressed.connect(trigger_smash)
	add_child(_smash_button)


func _button_style(fill: Color, border: Color, width: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(int(width))
	style.corner_radius_top_left = 77
	style.corner_radius_top_right = 77
	style.corner_radius_bottom_left = 77
	style.corner_radius_bottom_right = 77
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	style.shadow_size = 12
	return style


func _apply_visibility() -> void:
	if _smash_button != null:
		_smash_button.visible = _mobile_device and _controls_enabled
	if _joystick != null and (not _mobile_device or not _controls_enabled):
		_joystick.visible = false


func _clamp_origin(position: Vector2) -> Vector2:
	var margin: float = JOYSTICK_RADIUS + 16.0
	return Vector2(
		clampf(position.x, margin, VIEWPORT_SIZE.x - margin),
		clampf(position.y, margin, VIEWPORT_SIZE.y - margin),
	)


func _update_drive_vector() -> void:
	var offset: Vector2 = _touch_position - _touch_origin
	var distance: float = offset.length()
	if distance <= DEAD_ZONE:
		_drive_vector = Vector2.ZERO
		return
	var strength: float = clampf((distance - DEAD_ZONE) / (JOYSTICK_RADIUS - DEAD_ZONE), 0.0, 1.0)
	_drive_vector = offset.normalized() * smoothstep(0.0, 1.0, strength)


func _cancel_joystick() -> void:
	_touch_index = -1
	_drive_vector = Vector2.ZERO
	if _joystick != null:
		_joystick.visible = false
		_joystick.queue_redraw()


func _draw_joystick() -> void:
	var center: Vector2 = Vector2.ONE * JOYSTICK_RADIUS
	var knob_offset: Vector2 = _drive_vector * (JOYSTICK_RADIUS - KNOB_RADIUS - 7.0)
	_joystick.draw_circle(center, JOYSTICK_RADIUS, Color(INK, 0.55))
	_joystick.draw_arc(center, JOYSTICK_RADIUS - 3.0, 0.0, TAU, 48, Color(TEAL, 0.82), 5.0)
	_joystick.draw_circle(center + knob_offset, KNOB_RADIUS, Color(TEAL, 0.9))
	_joystick.draw_circle(center + knob_offset, KNOB_RADIUS * 0.52, Color(INK, 0.78))
	(
		_joystick
		. draw_arc(
			center + knob_offset,
			KNOB_RADIUS - 2.0,
			0.0,
			TAU,
			32,
			Color("d9fff9"),
			3.0,
		)
	)
