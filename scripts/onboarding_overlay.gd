extends CanvasLayer

const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")

var _preferences: RefCounted
var _panel: ColorRect
var _label: Label
var _stage: int = 0
var _elapsed: float = 0.0
var _completed: bool = false


func _ready() -> void:
	layer = 8
	name = "OnboardingOverlay"
	_preferences = PlayerPreferencesScript.new() as RefCounted
	var snapshot: Dictionary = _preferences.call("load_preferences") as Dictionary
	_completed = bool(snapshot.get(&"onboarding_seen", false))
	_build_interface()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	_panel.visible = not _completed


func _process(delta: float) -> void:
	if _completed:
		return
	_elapsed += maxf(delta, 0.0)
	if _elapsed >= float((_stage + 1) * 15):
		_advance()


func apply_state(state: RefCounted) -> void:
	if _completed or state == null:
		return
	var mobile: bool = bool(state.call("get_value", &"mobile_controls"))
	match _stage:
		0:
			_label.text = "MOVE // HOLD JOYSTICK" if mobile else "MOVE // WASD // SHIFT TO RUN"
		1:
			_label.text = "BUILD IMPACT WHILE MOVING // SMASH AT CONTACT"
			if float(state.call("get_value", &"impact_charge")) >= 0.4:
				_advance()
		2:
			_label.text = "FOLLOW THE TEAL SIGNAL // HOLD THE RELAY ZONE"
			if int(state.call("get_value", &"completed_relays")) > 0:
				_advance()


func is_completed() -> bool:
	return _completed


func get_stage() -> int:
	return _stage


func _advance() -> void:
	_stage += 1
	if _stage < 3:
		return
	_completed = true
	_panel.visible = false
	_preferences.call("set_value", &"onboarding_seen", true)
	_preferences.call("save_preferences")


func _build_interface() -> void:
	_panel = ColorRect.new()
	_panel.name = "OnboardingPanel"
	_panel.position = Vector2(350.0, 18.0)
	_panel.size = Vector2(580.0, 44.0)
	_panel.color = Color(0.025, 0.035, 0.04, 0.88)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_label = Label.new()
	_label.position = Vector2(12.0, 4.0)
	_label.size = Vector2(556.0, 36.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color("f5a62d"))
	_panel.add_child(_label)


func _apply_layout() -> void:
	if _panel == null:
		return
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var scale_factor: float = minf(1.0, viewport_width / 610.0)
	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = Vector2((viewport_width - _panel.size.x * scale_factor) * 0.5, 18.0)
