extends CanvasLayer

signal preferences_changed(snapshot: Dictionary)

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")

var _preferences: RefCounted
var _panel: ColorRect
var _buttons: Dictionary = {}
var _access_button: Button
var _title_label: Label


func _ready() -> void:
	layer = 30
	name = "Accessibility"
	add_to_group("accessibility_panel")
	_preferences = PlayerPreferencesScript.new() as RefCounted
	_preferences.call("load_preferences")
	_build_interface()
	add_to_group("localization_listeners")
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


func _cycle_locale() -> void:
	_preferences.call("load_preferences")
	var current: StringName = LocalizationScript.get_locale()
	var next_locale: StringName = &"zh-CN" if current == &"en" else &"en"
	if not bool(_preferences.call("set_value", &"locale", next_locale)):
		return
	_preferences.call("save_preferences")
	LocalizationScript.set_locale(next_locale)
	_refresh()
	preferences_changed.emit(get_preferences())


func _reset_training() -> void:
	_preferences.call("set_value", &"onboarding_seen", false)
	_commit()


func _commit() -> void:
	_preferences.call("save_preferences")
	_refresh()
	preferences_changed.emit(get_preferences())


func _refresh() -> void:
	if _access_button == null or _title_label == null:
		return
	var snapshot: Dictionary = get_preferences()
	_access_button.text = LocalizationScript.t(&"access.button")
	_title_label.text = LocalizationScript.t(&"access.title")
	(_buttons[&"ui_scale"] as Button).text = LocalizationScript.t(
		&"access.ui_scale", {"percent": roundi(float(snapshot[&"ui_scale"]) * 100.0)}
	)
	(_buttons[&"camera_shake"] as Button).text = LocalizationScript.t(
		&"access.camera_shake", {"state": _on_off(snapshot, &"camera_shake")}
	)
	(_buttons[&"reduced_flash"] as Button).text = LocalizationScript.t(
		&"access.reduced_flash", {"state": _on_off(snapshot, &"reduced_flash")}
	)
	(_buttons[&"haptics"] as Button).text = LocalizationScript.t(
		&"access.haptics", {"state": _on_off(snapshot, &"haptics")}
	)
	(_buttons[&"left_handed"] as Button).text = LocalizationScript.t(
		&"access.left_handed", {"state": _on_off(snapshot, &"left_handed")}
	)
	(_buttons[&"sfx_enabled"] as Button).text = LocalizationScript.t(
		&"access.sfx", {"state": _on_off(snapshot, &"sfx_enabled")}
	)
	var locale: String = str(LocalizationScript.get_locale())
	(_buttons[&"locale"] as Button).text = (
		LocalizationScript
		. t(
			&"access.language",
			{"language": LocalizationScript.t("common.locale_short.%s" % locale)},
		)
	)
	(_buttons[&"onboarding_seen"] as Button).text = LocalizationScript.t(&"access.reset_training")


func _on_off(snapshot: Dictionary, key: StringName) -> String:
	return (
		LocalizationScript.t(&"common.on")
		if bool(snapshot[key])
		else LocalizationScript.t(&"common.off")
	)


func _on_locale_changed(_locale: StringName) -> void:
	_preferences.call("load_preferences")
	_refresh()


func get_language_button() -> Button:
	return _buttons.get(&"locale") as Button


func _build_interface() -> void:
	var access: Button = Button.new()
	_access_button = access
	access.name = "AccessibilityButton"
	access.text = LocalizationScript.t(&"access.button")
	access.position = Vector2(1072.0, 18.0)
	access.size = Vector2(190.0, 42.0)
	access.add_theme_font_size_override("font_size", 14)
	access.add_theme_color_override("font_color", Color("a9b5b5"))
	access.add_theme_color_override("font_hover_color", Color("f3a21e"))
	access.add_theme_color_override("font_focus_color", Color("f3a21e"))
	(
		access
		. add_theme_stylebox_override(
			"normal",
			_make_access_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.36, 0.45, 0.47, 0.55), 1),
		)
	)
	(
		access
		. add_theme_stylebox_override(
			"hover",
			_make_access_style(Color(0.02, 0.035, 0.05, 0.92), Color("f3a21e"), 1),
		)
	)
	(
		access
		. add_theme_stylebox_override(
			"focus",
			_make_access_style(Color(0.02, 0.035, 0.05, 0.96), Color("f3a21e"), 2),
		)
	)
	access.pressed.connect(_toggle_panel)
	add_child(access)
	_panel = ColorRect.new()
	_panel.name = "AccessibilityPanel"
	_panel.position = Vector2(820.0, 78.0)
	_panel.size = Vector2(442.0, 548.0)
	_panel.color = Color(0.025, 0.035, 0.04, 0.97)
	_panel.visible = false
	add_child(_panel)
	_title_label = Label.new()
	_title_label.name = "AccessibilityTitle"
	_title_label.position = Vector2(28.0, 20.0)
	_title_label.size = Vector2(380.0, 44.0)
	_title_label.add_theme_font_size_override("font_size", 26)
	_panel.add_child(_title_label)
	_add_button(&"ui_scale", 78.0, _cycle_scale)
	_add_button(&"camera_shake", 134.0, _toggle_boolean.bind(&"camera_shake"))
	_add_button(&"reduced_flash", 190.0, _toggle_boolean.bind(&"reduced_flash"))
	_add_button(&"haptics", 246.0, _toggle_boolean.bind(&"haptics"))
	_add_button(&"left_handed", 302.0, _toggle_boolean.bind(&"left_handed"))
	_add_button(&"sfx_enabled", 358.0, _toggle_boolean.bind(&"sfx_enabled"))
	_add_button(&"locale", 414.0, _cycle_locale)
	_add_button(&"onboarding_seen", 470.0, _reset_training)


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
	var scale_factor: float = minf(1.0, minf(viewport_size.x / 470.0, viewport_size.y / 590.0))
	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = Vector2(viewport_size.x - _panel.size.x * scale_factor - 18.0, 72.0)
	_access_button.position = Vector2(viewport_size.x - _access_button.size.x - 18.0, 18.0)


func _make_access_style(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style
