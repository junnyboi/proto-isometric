extends CanvasLayer

signal preferences_changed(snapshot: Dictionary)
signal training_resume_requested
signal training_reset_requested
signal training_help_requested

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")

var _preferences: RefCounted
var _panel: ColorRect
var _buttons: Dictionary = {}
var _access_button: Button
var _title_label: Label
var _vfx_label: Label
var _vfx_slider: HSlider
var _audio_labels: Dictionary = {}
var _audio_sliders: Dictionary = {}
var _trigger_bottom_clearance: float = 0.0


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
	_apply_layout()
	if _panel.visible:
		(_audio_sliders[&"master_volume"] as HSlider).grab_focus()


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


func _cycle_intensity(key: StringName) -> void:
	var intensity: float = float(get_preferences()[key]) + 0.5
	if intensity > 1.0:
		intensity = 0.0
	_preferences.call("set_value", key, intensity)
	_commit()


func _cycle_effects_quality() -> void:
	var tiers: Array[StringName] = [&"full", &"reduced", &"minimal"]
	var current: StringName = get_preferences()[&"effects_quality"] as StringName
	var next_index: int = (tiers.find(current) + 1) % tiers.size()
	_preferences.call("set_value", &"effects_quality", tiers[next_index])
	_commit()


func _set_audio_volume(percent: float, key: StringName) -> void:
	var volume: float = snappedf(clampf(percent, 0.0, 100.0) / 100.0, 0.05)
	if not bool(_preferences.call("set_value", key, volume)):
		return
	if key == &"sfx_volume":
		_preferences.call("set_value", &"sfx_enabled", volume > 0.0)
	_commit()


func _reset_audio_defaults() -> void:
	if not bool(_preferences.call("reset_audio_defaults")):
		return
	_commit()


func _set_vfx_intensity(percent: float) -> void:
	var intensity: float = snappedf(clampf(percent, 0.0, 100.0) / 100.0, 0.1)
	if not bool(_preferences.call("set_value", &"vfx_intensity", intensity)):
		return
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


func _resume_training() -> void:
	training_resume_requested.emit()


func _reset_training() -> void:
	training_reset_requested.emit()


func _open_training_help() -> void:
	_panel.visible = false
	_apply_layout()
	training_help_requested.emit()


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
	_refresh_audio_slider(snapshot, &"master_volume", &"access.master_volume")
	_refresh_audio_slider(snapshot, &"sfx_volume", &"access.sfx_volume")
	_refresh_audio_slider(snapshot, &"music_volume", &"access.music_volume")
	_refresh_audio_slider(snapshot, &"ambience_volume", &"access.ambience_volume")
	var vfx_percent: int = roundi(float(snapshot[&"vfx_intensity"]) * 100.0)
	_vfx_label.text = LocalizationScript.t(&"access.vfx_intensity", {"percent": vfx_percent})
	_vfx_slider.set_value_no_signal(vfx_percent)
	_vfx_slider.tooltip_text = _vfx_label.text
	(_buttons[&"ui_scale"] as Button).text = LocalizationScript.t(
		&"access.ui_scale", {"percent": roundi(float(snapshot[&"ui_scale"]) * 100.0)}
	)
	(_buttons[&"camera_shake"] as Button).text = (
		LocalizationScript
		. t(
			&"access.camera_shake",
			{"state": _intensity_label(snapshot, &"camera_shake_intensity")},
		)
	)
	(_buttons[&"reduced_flash"] as Button).text = LocalizationScript.t(
		&"access.reduced_flash", {"state": _on_off(snapshot, &"reduced_flash")}
	)
	(_buttons[&"effects_quality"] as Button).text = (
		LocalizationScript
		. t(
			&"access.effects_quality",
			{"state": LocalizationScript.t("common.quality.%s" % snapshot[&"effects_quality"])},
		)
	)
	(_buttons[&"haptics"] as Button).text = LocalizationScript.t(
		&"access.haptics", {"state": _intensity_label(snapshot, &"haptic_intensity")}
	)
	(_buttons[&"left_handed"] as Button).text = LocalizationScript.t(
		&"access.left_handed", {"state": _on_off(snapshot, &"left_handed")}
	)
	(_buttons[&"audio_defaults"] as Button).text = LocalizationScript.t(
		&"access.reset_audio_defaults"
	)
	var locale: String = str(LocalizationScript.get_locale())
	(_buttons[&"locale"] as Button).text = (
		LocalizationScript
		. t(
			&"access.language",
			{"language": LocalizationScript.t("common.locale_short.%s" % locale)},
		)
	)
	(_buttons[&"training_resume"] as Button).text = LocalizationScript.t(
		&"access.resume_training"
	)
	(_buttons[&"training_reset"] as Button).text = LocalizationScript.t(
		&"access.reset_training"
	)
	(_buttons[&"training_help"] as Button).text = LocalizationScript.t(&"access.training_help")


func _refresh_audio_slider(snapshot: Dictionary, key: StringName, label_key: StringName) -> void:
	var volume: float = float(snapshot[key])
	if key == &"sfx_volume" and not bool(snapshot.get(&"sfx_enabled", true)):
		volume = 0.0
	var percent: int = roundi(volume * 100.0)
	var label: Label = _audio_labels[key] as Label
	var slider: HSlider = _audio_sliders[key] as HSlider
	label.text = LocalizationScript.t(label_key, {"percent": percent})
	slider.set_value_no_signal(percent)
	slider.tooltip_text = label.text


func _on_off(snapshot: Dictionary, key: StringName) -> String:
	return (
		LocalizationScript.t(&"common.on")
		if bool(snapshot[key])
		else LocalizationScript.t(&"common.off")
	)


func _intensity_label(snapshot: Dictionary, key: StringName) -> String:
	var intensity: float = float(snapshot[key])
	if intensity <= 0.0:
		return LocalizationScript.t(&"common.intensity.off")
	if intensity < 1.0:
		return LocalizationScript.t(&"common.intensity.low")
	return LocalizationScript.t(&"common.intensity.full")


func _on_locale_changed(_locale: StringName) -> void:
	_preferences.call("load_preferences")
	_refresh()


func get_language_button() -> Button:
	return _buttons.get(&"locale") as Button


func get_vfx_intensity_slider() -> HSlider:
	return _vfx_slider


func get_audio_volume_slider(key: StringName) -> HSlider:
	return _audio_sliders.get(key) as HSlider


func get_trigger_button() -> Button:
	return _access_button


func set_trigger_bottom_clearance(clearance: float) -> void:
	_trigger_bottom_clearance = maxf(clearance, 0.0)
	_apply_layout()


func blocks_world_touch(position: Vector2) -> bool:
	if _access_button != null and _access_button.get_global_rect().has_point(position):
		return true
	return _panel != null and _panel.visible and _panel.get_global_rect().has_point(position)


func _build_interface() -> void:
	var access: Button = Button.new()
	_access_button = access
	access.name = "AccessibilityButton"
	access.text = LocalizationScript.t(&"access.button")
	access.position = Vector2(1072.0, 660.0)
	access.size = Vector2(190.0, 42.0)
	access.add_theme_font_size_override("font_size", 17)
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
	_panel.size = Vector2(442.0, 1010.0)
	_panel.color = Color(0.025, 0.035, 0.04, 0.97)
	_panel.visible = false
	add_child(_panel)
	_title_label = Label.new()
	_title_label.name = "AccessibilityTitle"
	_title_label.position = Vector2(28.0, 20.0)
	_title_label.size = Vector2(380.0, 44.0)
	_title_label.add_theme_font_size_override("font_size", 29)
	_panel.add_child(_title_label)
	_add_audio_slider(&"master_volume", &"access.master_volume", 78.0)
	_add_audio_slider(&"sfx_volume", &"access.sfx_volume", 136.0)
	_add_audio_slider(&"music_volume", &"access.music_volume", 194.0)
	_add_audio_slider(&"ambience_volume", &"access.ambience_volume", 252.0)
	_add_button(&"audio_defaults", 310.0, _reset_audio_defaults)
	_add_vfx_slider(368.0)
	_add_button(&"ui_scale", 438.0, _cycle_scale)
	_add_button(&"camera_shake", 494.0, _cycle_intensity.bind(&"camera_shake_intensity"))
	_add_button(&"reduced_flash", 550.0, _toggle_boolean.bind(&"reduced_flash"))
	_add_button(&"effects_quality", 606.0, _cycle_effects_quality)
	_add_button(&"haptics", 662.0, _cycle_intensity.bind(&"haptic_intensity"))
	_add_button(&"left_handed", 718.0, _toggle_boolean.bind(&"left_handed"))
	_add_button(&"locale", 774.0, _cycle_locale)
	_add_button(&"training_resume", 830.0, _resume_training)
	_add_button(&"training_reset", 886.0, _reset_training)
	_add_button(&"training_help", 942.0, _open_training_help)


func _add_audio_slider(key: StringName, label_key: StringName, y: float) -> void:
	var label: Label = Label.new()
	label.name = "%sLabel" % String(key).to_pascal_case()
	label.position = Vector2(28.0, y)
	label.size = Vector2(228.0, 46.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	_panel.add_child(label)
	_audio_labels[key] = label
	var slider: HSlider = HSlider.new()
	slider.name = "%sSlider" % String(key).to_pascal_case()
	slider.position = Vector2(260.0, y)
	slider.size = Vector2(154.0, 46.0)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.tick_count = 5
	slider.ticks_on_borders = true
	slider.tooltip_text = LocalizationScript.t(label_key, {"percent": 100})
	slider.value_changed.connect(_set_audio_volume.bind(key))
	_panel.add_child(slider)
	_audio_sliders[key] = slider


func _add_vfx_slider(y: float) -> void:
	_vfx_label = Label.new()
	_vfx_label.name = "VfxIntensityLabel"
	_vfx_label.position = Vector2(28.0, y)
	_vfx_label.size = Vector2(228.0, 46.0)
	_vfx_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vfx_label.add_theme_font_size_override("font_size", 19)
	_panel.add_child(_vfx_label)
	_vfx_slider = HSlider.new()
	_vfx_slider.name = "VfxIntensitySlider"
	_vfx_slider.position = Vector2(260.0, y)
	_vfx_slider.size = Vector2(154.0, 46.0)
	_vfx_slider.min_value = 0.0
	_vfx_slider.max_value = 100.0
	_vfx_slider.step = 10.0
	_vfx_slider.tick_count = 11
	_vfx_slider.ticks_on_borders = true
	_vfx_slider.value_changed.connect(_set_vfx_intensity)
	_panel.add_child(_vfx_slider)


func _add_button(key: StringName, y: float, callback: Callable) -> void:
	var button: Button = Button.new()
	button.name = String(key).to_pascal_case()
	button.position = Vector2(28.0, y)
	button.size = Vector2(386.0, 46.0)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	_panel.add_child(button)
	_buttons[key] = button


func _apply_layout() -> void:
	if _panel == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var available_height: float = maxf(viewport_size.y - 90.0, 1.0)
	var scale_factor: float = minf(1.0, minf(viewport_size.x / 470.0, available_height / 1010.0))
	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = Vector2(viewport_size.x - _panel.size.x * scale_factor - 18.0, 72.0)
	_access_button.position = trigger_rect_for(
		viewport_size,
		_trigger_bottom_clearance,
		_panel.visible,
	).position


static func trigger_rect_for(
	viewport_size: Vector2,
	bottom_clearance: float = 0.0,
	panel_visible: bool = false,
) -> Rect2:
	var button_size: Vector2 = Vector2(190.0, 42.0)
	var button_x: float = maxf(viewport_size.x - button_size.x - 18.0, 0.0)
	var button_y: float = 18.0
	if not panel_visible:
		button_y = viewport_size.y - button_size.y - 18.0 - maxf(bottom_clearance, 0.0)
	button_y = clampf(button_y, 0.0, maxf(viewport_size.y - button_size.y, 0.0))
	return Rect2(Vector2(button_x, button_y), button_size)


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
