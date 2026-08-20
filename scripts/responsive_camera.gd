extends Camera2D

const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")
const ResponsiveViewportScript: GDScript = preload("res://scripts/responsive_viewport.gd")
const MIN_USER_ZOOM: float = 0.7
const MAX_USER_ZOOM: float = 1.3
const USER_ZOOM_STEP: float = 0.1
const CONTROL_SIZE: Vector2 = Vector2(48.0, 44.0)

var _preferences: RefCounted
var _user_zoom: float = 1.0
var _zoom_out_button: Button
var _zoom_in_button: Button
var _zoom_label: Label


func _ready() -> void:
	_preferences = PlayerPreferencesScript.new() as RefCounted
	var snapshot: Dictionary = _preferences.call("load_preferences") as Dictionary
	_user_zoom = float(snapshot.get(&"camera_zoom", 1.0))
	_build_zoom_controls()
	get_viewport().size_changed.connect(_apply_responsive_zoom)
	_apply_responsive_zoom()


func _input(event: InputEvent) -> void:
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


func adjust_user_zoom(steps: int) -> bool:
	var next_zoom: float = snappedf(
		clampf(_user_zoom + float(steps) * USER_ZOOM_STEP, MIN_USER_ZOOM, MAX_USER_ZOOM),
		USER_ZOOM_STEP,
	)
	if is_equal_approx(next_zoom, _user_zoom):
		return false
	_user_zoom = next_zoom
	_persist_user_zoom()
	_refresh_zoom_controls()
	if is_inside_tree():
		_apply_responsive_zoom()
	return true


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
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "CameraZoomPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -94.0
	panel.offset_top = -76.0
	panel.offset_right = 94.0
	panel.offset_bottom = -24.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _control_panel_style())
	layer.add_child(panel)
	var controls: HBoxContainer = HBoxContainer.new()
	controls.name = "ZoomControls"
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 6)
	panel.add_child(controls)
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
