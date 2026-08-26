extends Camera2D

const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")
const ResponsiveViewportScript: GDScript = preload("res://scripts/responsive_viewport.gd")
const MIN_USER_ZOOM: float = 0.7
const MAX_USER_ZOOM: float = 1.3
const USER_ZOOM_STEP: float = 0.1
const PINCH_ZOOM_STEP: float = 0.01
const MIN_PINCH_DISTANCE: float = 24.0
const CONTROL_SIZE: Vector2 = Vector2(48.0, 44.0)
const LANDSCAPE_ZOOM_TOP: float = -76.0
const LANDSCAPE_ZOOM_BOTTOM: float = -24.0
const PORTRAIT_ZOOM_TOP: float = -232.0
const PORTRAIT_ZOOM_BOTTOM: float = -180.0

var _preferences: RefCounted
var _user_zoom: float = 1.0
var _mobile_controls: CanvasLayer
var _touch_points: Dictionary = {}
var _pinch_active: bool = false
var _pinch_indices: Array[int] = []
var _pinch_start_distance: float = 0.0
var _pinch_start_zoom: float = 1.0
var _pinch_changed: bool = false
var _zoom_panel: PanelContainer
var _zoom_out_button: Button
var _zoom_in_button: Button
var _zoom_label: Label


func _ready() -> void:
	_preferences = PlayerPreferencesScript.new() as RefCounted
	var snapshot: Dictionary = _preferences.call("load_preferences") as Dictionary
	_user_zoom = float(snapshot.get(&"camera_zoom", 1.0))
	_build_zoom_controls()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_responsive_zoom()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
		return
	if event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		adjust_user_zoom(1)
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		adjust_user_zoom(-1)
	else:
		return
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func get_responsive_zoom() -> float:
	return (
		float(ResponsiveViewportScript.camera_zoom(get_viewport().get_visible_rect().size))
		* _user_zoom
	)


func get_user_zoom() -> float:
	return _user_zoom


func is_pinching() -> bool:
	return _pinch_active


func get_pinch_snapshot() -> Dictionary:
	return {
		&"active": _pinch_active,
		&"touch_count": _touch_points.size(),
		&"start_distance": _pinch_start_distance,
		&"start_zoom": _pinch_start_zoom,
		&"changed": _pinch_changed,
	}


func bind_mobile_controls(controls: CanvasLayer) -> void:
	_mobile_controls = controls
	if controls != null and not controls.is_connected("layout_changed", _layout_zoom_controls):
		controls.connect("layout_changed", _layout_zoom_controls)
	if controls != null and not controls.is_connected(
		"modal_input_changed", _on_modal_input_changed
	):
		controls.connect("modal_input_changed", _on_modal_input_changed)
	_layout_zoom_controls()
	_on_modal_input_changed(
		bool(controls.call("is_modal_input_suppressed")) if controls != null else false
	)


func adjust_user_zoom(steps: int) -> bool:
	var next_zoom: float = _user_zoom + float(steps) * USER_ZOOM_STEP
	return _set_user_zoom(next_zoom, true, USER_ZOOM_STEP)


func _set_user_zoom(value: float, persist: bool, step: float) -> bool:
	var next_zoom: float = snappedf(clampf(value, MIN_USER_ZOOM, MAX_USER_ZOOM), step)
	if is_equal_approx(next_zoom, _user_zoom):
		return false
	_user_zoom = next_zoom
	if persist:
		_persist_user_zoom()
	_refresh_zoom_controls()
	if is_inside_tree():
		_apply_responsive_zoom()
	return true


func _handle_screen_touch(touch: InputEventScreenTouch) -> void:
	var handled: bool = _pinch_active
	if touch.pressed:
		if _accepts_pinch_position(touch.position):
			_touch_points[touch.index] = touch.position
			handled = _try_begin_pinch() or handled
	else:
		var was_pinching: bool = _pinch_active and touch.index in _pinch_indices
		_touch_points.erase(touch.index)
		if was_pinching:
			_end_pinch()
			handled = true
	if handled:
		_mark_input_handled()


func _handle_screen_drag(drag: InputEventScreenDrag) -> void:
	if not _touch_points.has(drag.index):
		return
	_touch_points[drag.index] = drag.position
	if not _pinch_active:
		_try_begin_pinch()
	if not _pinch_active:
		return
	var distance: float = _pinch_distance()
	if distance <= 0.0 or _pinch_start_distance <= 0.0:
		return
	var target_zoom: float = _pinch_start_zoom * distance / _pinch_start_distance
	_pinch_changed = _set_user_zoom(target_zoom, false, PINCH_ZOOM_STEP) or _pinch_changed
	_mark_input_handled()


func _try_begin_pinch() -> bool:
	if _pinch_active or _touch_points.size() < 2:
		return false
	var indices: Array = _touch_points.keys()
	indices.sort()
	var first: int = int(indices[0])
	var second: int = int(indices[1])
	var distance: float = (_touch_points[first] as Vector2).distance_to(
		_touch_points[second] as Vector2
	)
	if distance < MIN_PINCH_DISTANCE:
		return false
	_pinch_indices.assign([first, second])
	_pinch_start_distance = distance
	_pinch_start_zoom = _user_zoom
	_pinch_changed = false
	_pinch_active = true
	if _mobile_controls != null:
		_mobile_controls.call("set_pinch_active", true)
	return true


func _end_pinch() -> void:
	if not _pinch_active:
		return
	var changed: bool = _pinch_changed
	_pinch_active = false
	_pinch_indices.clear()
	_pinch_start_distance = 0.0
	_pinch_start_zoom = _user_zoom
	_pinch_changed = false
	if _mobile_controls != null:
		_mobile_controls.call("set_pinch_active", false)
	if changed:
		_persist_user_zoom()


func _pinch_distance() -> float:
	if _pinch_indices.size() != 2:
		return 0.0
	var first: int = _pinch_indices[0]
	var second: int = _pinch_indices[1]
	if not _touch_points.has(first) or not _touch_points.has(second):
		return 0.0
	return (_touch_points[first] as Vector2).distance_to(_touch_points[second] as Vector2)


func _accepts_pinch_position(position: Vector2) -> bool:
	if _zoom_panel != null and _zoom_panel.get_global_rect().has_point(position):
		return false
	if is_inside_tree():
		var accessibility: Node = get_tree().get_first_node_in_group("accessibility_panel")
		if (
			accessibility != null
			and accessibility.has_method("blocks_world_touch")
			and bool(accessibility.call("blocks_world_touch", position))
		):
			return false
	if _mobile_controls != null and _mobile_controls.has_method("is_pinch_candidate"):
		return bool(_mobile_controls.call("is_pinch_candidate", position))
	return true


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _apply_responsive_zoom() -> void:
	var value: float = get_responsive_zoom()
	zoom = Vector2.ONE * value


func _build_zoom_controls() -> void:
	if has_node("CameraZoomLayer"):
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CameraZoomLayer"
	layer.layer = 45
	add_child(layer)
	_zoom_panel = PanelContainer.new()
	_zoom_panel.name = "CameraZoomPanel"
	_zoom_panel.anchor_left = 0.5
	_zoom_panel.anchor_top = 1.0
	_zoom_panel.anchor_right = 0.5
	_zoom_panel.anchor_bottom = 1.0
	_zoom_panel.offset_left = -94.0
	_zoom_panel.offset_right = 94.0
	_layout_zoom_controls()
	_zoom_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_zoom_panel.add_theme_stylebox_override("panel", _control_panel_style())
	layer.add_child(_zoom_panel)
	var controls: HBoxContainer = HBoxContainer.new()
	controls.name = "ZoomControls"
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 6)
	_zoom_panel.add_child(controls)
	_zoom_out_button = _make_zoom_button("ZoomOutButton", "-")
	_zoom_out_button.pressed.connect(adjust_user_zoom.bind(-1))
	controls.add_child(_zoom_out_button)
	_zoom_label = Label.new()
	_zoom_label.name = "ZoomLabel"
	_zoom_label.custom_minimum_size = Vector2(64.0, CONTROL_SIZE.y)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zoom_label.add_theme_color_override("font_color", Color("d8d0b5"))
	_zoom_label.add_theme_font_size_override("font_size", 15)
	controls.add_child(_zoom_label)
	_zoom_in_button = _make_zoom_button("ZoomInButton", "+")
	_zoom_in_button.pressed.connect(adjust_user_zoom.bind(1))
	controls.add_child(_zoom_in_button)
	_refresh_zoom_controls()


func _on_viewport_resized() -> void:
	_apply_responsive_zoom()
	_layout_zoom_controls()


func _layout_zoom_controls() -> void:
	if _zoom_panel == null:
		return
	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280.0, 720.0)
	)
	var portrait: bool = viewport_size.y > viewport_size.x
	var left_handed: bool = _mobile_controls != null and bool(_mobile_controls.get("_left_handed"))
	var portrait_anchor: float = 1.0 if left_handed else 0.0
	_zoom_panel.anchor_left = portrait_anchor if portrait else 0.5
	_zoom_panel.anchor_right = portrait_anchor if portrait else 0.5
	_zoom_panel.offset_left = (-198.0 if left_handed else 10.0) if portrait else -94.0
	_zoom_panel.offset_right = (-10.0 if left_handed else 198.0) if portrait else 94.0
	_zoom_panel.offset_top = PORTRAIT_ZOOM_TOP if portrait else LANDSCAPE_ZOOM_TOP
	_zoom_panel.offset_bottom = PORTRAIT_ZOOM_BOTTOM if portrait else LANDSCAPE_ZOOM_BOTTOM


func _on_modal_input_changed(suppressed: bool) -> void:
	if _zoom_panel != null:
		_zoom_panel.visible = not suppressed


func _make_zoom_button(node_name: String, text: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = CONTROL_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", Color("f0a93b"))
	button.add_theme_font_size_override("font_size", 24)
	return button


func _control_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.9)
	style.border_color = Color(0.18, 0.72, 0.72, 0.78)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	return style


func _persist_user_zoom() -> void:
	if _preferences == null:
		return
	_preferences.call("set_value", &"camera_zoom", _user_zoom)
	_preferences.call("save_preferences")


func _refresh_zoom_controls() -> void:
	if _zoom_label == null:
		return
	_zoom_label.text = "%d%%" % roundi(_user_zoom * 100.0)
	_zoom_out_button.disabled = _user_zoom <= MIN_USER_ZOOM + 0.001
	_zoom_in_button.disabled = _user_zoom >= MAX_USER_ZOOM - 0.001
