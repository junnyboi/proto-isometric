extends CanvasLayer

signal preferences_changed(snapshot: Dictionary)

const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")

var _preferences: RefCounted
var _panel: ColorRect
var _buttons: Dictionary = {}
var _access_button: Button


func _ready() -> void:
	layer = 30
	name = "Accessibility"
	add_to_group("accessibility_panel")
	_preferences = PlayerPreferencesScript.new() as RefCounted
	_preferences.call("load_preferences")
	_build_interface()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	_refresh()


func get_preferences() -> Dictionary:
	return _preferences.call("to_dictionary") as Dictionary


func is_panel_visible() -> bool:
	return _panel.visible


func _toggle_panel() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		(_buttons[&"ui_scale"] as Button).grab_focus()


func _toggle_boolean(key: StringName) -> void:
	var snapshot: Dictionary = get_preferences()
	_preferences.call("set_value", key, not bool(snapshot[key]))
	_commit()


func _cycle_scale() -> void:
	var scale: float = float(get_preferences()[&"ui_scale"]) + 0.1
	if scale > 1.25:
		scale = 0.85
	_preferences.call("set_value", &"ui_scale", snappedf(scale, 0.05))
	_commit()


func _reset_training() -> void:
	_preferences.call("set_value", &"onboarding_seen", false)
	_commit()


func _commit() -> void:
	_preferences.call("save_preferences")
	_refresh()
	preferences_changed.emit(get_preferences())


func _refresh() -> void:
	var snapshot: Dictionary = get_preferences()
	(_buttons[&"ui_scale"] as Button).text = (
		"UI SCALE  %d%%" % roundi(float(snapshot[&"ui_scale"]) * 100.0)
	)
	(_buttons[&"camera_shake"] as Button).text = (
		"CAMERA SHAKE  %s" % _on_off(snapshot, &"camera_shake")
	)
	(_buttons[&"reduced_flash"] as Button).text = (
		"REDUCED FLASH  %s" % _on_off(snapshot, &"reduced_flash")
	)
	(_buttons[&"haptics"] as Button).text = "HAPTICS  %s" % _on_off(snapshot, &"haptics")
	(_buttons[&"left_handed"] as Button).text = (
		"LEFT-HANDED  %s" % _on_off(snapshot, &"left_handed")
	)
	(_buttons[&"sfx_enabled"] as Button).text = "SFX  %s" % _on_off(snapshot, &"sfx_enabled")
	(_buttons[&"onboarding_seen"] as Button).text = "RESET TRAINING"


func _on_off(snapshot: Dictionary, key: StringName) -> String:
	return "ON" if bool(snapshot[key]) else "OFF"


func _build_interface() -> void:
	var access: Button = Button.new()
	_access_button = access
	access.name = "AccessibilityButton"
	access.text = "ACCESS"
	access.position = Vector2(1138.0, 18.0)
	access.size = Vector2(124.0, 42.0)
	access.pressed.connect(_toggle_panel)
	add_child(access)
	_panel = ColorRect.new()
	_panel.name = "AccessibilityPanel"
	_panel.position = Vector2(820.0, 78.0)
	_panel.size = Vector2(442.0, 540.0)
	_panel.color = Color(0.025, 0.035, 0.04, 0.97)
	_panel.visible = false
	add_child(_panel)
	var title: Label = Label.new()
	title.text = "ACCESSIBILITY"
	title.position = Vector2(28.0, 20.0)
	title.size = Vector2(380.0, 44.0)
	title.add_theme_font_size_override("font_size", 26)
	_panel.add_child(title)
	_add_button(&"ui_scale", 78.0, _cycle_scale)
	_add_button(&"camera_shake", 138.0, _toggle_boolean.bind(&"camera_shake"))
	_add_button(&"reduced_flash", 198.0, _toggle_boolean.bind(&"reduced_flash"))
	_add_button(&"haptics", 258.0, _toggle_boolean.bind(&"haptics"))
	_add_button(&"left_handed", 318.0, _toggle_boolean.bind(&"left_handed"))
	_add_button(&"sfx_enabled", 378.0, _toggle_boolean.bind(&"sfx_enabled"))
	_add_button(&"onboarding_seen", 438.0, _reset_training)


func _add_button(key: StringName, y: float, callback: Callable) -> void:
	var button: Button = Button.new()
	button.name = String(key).to_pascal_case()
	button.position = Vector2(28.0, y)
	button.size = Vector2(386.0, 46.0)
	button.pressed.connect(callback)
	_panel.add_child(button)
	_buttons[key] = button


func _apply_layout() -> void:
	if _panel == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var scale_factor: float = minf(1.0, minf(viewport_size.x / 470.0, viewport_size.y / 580.0))
	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = Vector2(viewport_size.x - _panel.size.x * scale_factor - 18.0, 72.0)
	_access_button.position = Vector2(viewport_size.x - _access_button.size.x - 18.0, 18.0)
