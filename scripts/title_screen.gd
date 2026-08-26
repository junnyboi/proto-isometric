extends Node2D

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")

const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")
const AccessibilityPanelScript: GDScript = preload("res://scripts/accessibility_panel.gd")
const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")
const ResponsiveViewportScript: GDScript = preload("res://scripts/responsive_viewport.gd")
const WebSceneStateScript: GDScript = preload("res://scripts/web_scene_state.gd")
const FIELD_SCENE: PackedScene = preload("res://scenes/isometric_map.tscn")
const TITLE_DESKTOP: Texture2D = preload(
	"res://assets/title/protos_harvest_title_desktop.png"
)
const TITLE_MOBILE: Texture2D = preload(
	"res://assets/title/protos_harvest_title_mobile.png"
)
const START_BUTTON_ART: Texture2D = preload(
	"res://assets/ui/title/start_game_button.png"
)
const UI_HOVER_CUE: AudioStream = preload("res://assets/audio/ui_hover.wav")
const UI_CLICK_CUE: AudioStream = preload("res://assets/audio/ui_click.wav")
const UI_START_CLICK_CUE: AudioStream = preload("res://assets/audio/ui_start_click.wav")
const TITLE_MUSIC: AudioStream = preload("res://assets/audio/bgm_title.ogg")
const TITLE_MUSIC_VOLUME_DB: float = -9.0
const TITLE_MUSIC_FADE_SECONDS: float = 0.65
const SILENT_VOLUME_DB: float = -80.0
const START_HOVER_SCALE: float = 1.018
const START_HOVER_SECONDS: float = 0.12
const UI_HOVER_COOLDOWN_MS: int = 90

const AMBER: Color = Color("f3a21e")
const AMBER_HOVER: Color = Color("ffc35c")
const INK: Color = Color("0a0d12")
const PANEL_SOFT: Color = Color(0.025, 0.043, 0.057, 0.91)
const TEXT: Color = Color("edf0ed")
const TEAL: Color = Color("668f91")

var _background: TextureRect
var _content_group: Control
var _title_panel: Control
var _title_label: Label
var _mission_label: Label
var _begin_button: Button
var _language_toggle: Button
var _settings_panel: CanvasLayer
var _layout: Dictionary = {}
var _loading_complete: bool = false
var _field_visible: bool = false
var _audio_trigger_count: int = 0
var _hover_audio_trigger_count: int = 0
var _ui_feedback_control_count: int = 0
var _last_hover_audio_ms: int = -UI_HOVER_COOLDOWN_MS
var _title_music_player: AudioStreamPlayer
var _begin_hover_tween: Tween
var _begin_hover_active: bool = false


func _ready() -> void:
	_build_interface()
	_start_title_music()
	add_to_group("localization_listeners")
	_settings_panel = AccessibilityPanelScript.new() as CanvasLayer
	_settings_panel.connect(
		&"trigger_layout_changed",
		Callable(self, "_on_settings_trigger_layout_changed"),
	)
	add_child(_settings_panel)
	_connect_ui_feedback()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_complete_loading()
	_begin_button.grab_focus()
	WebSceneStateScript.set_state("title-ready")
	print("[PROTO_ISOMETRIC_READY]")


func _unhandled_input(event: InputEvent) -> void:
	if _loading_complete and _begin_button.visible and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_begin_pressed()


func _build_interface() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "UILayer"
	add_child(layer)

	var ui_root: Control = Control.new()
	ui_root.name = "UIRoot"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(ui_root)

	_background = TextureRect.new()
	_background.name = "GeneratedTitleArt"
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(_background)

	_content_group = Control.new()
	_content_group.name = "ConceptCanvas"
	ui_root.add_child(_content_group)

	_title_panel = Control.new()
	_title_panel.name = "TitlePanel"
	_content_group.add_child(_title_panel)
	_build_briefing()
	_build_language_toggle(ui_root)

func _build_briefing() -> void:
	_title_label = _make_label("TitleLabel", LocalizationScript.t(&"title.name"), 56, TEXT)
	_title_panel.add_child(_title_label)

	_mission_label = _make_label(
		"Mission",
		LocalizationScript.t(&"title.mission"),
		15,
		TEXT,
	)
	_mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_panel.add_child(_mission_label)

	_begin_button = Button.new()
	_begin_button.name = "BeginButton"
	_begin_button.text = LocalizationScript.t(&"title.start_game")
	_begin_button.visible = false
	_begin_button.disabled = true
	_begin_button.focus_mode = Control.FOCUS_ALL
	_begin_button.add_theme_font_size_override("font_size", 26)
	_begin_button.add_theme_color_override("font_color", INK)
	_begin_button.add_theme_color_override("font_hover_color", INK)
	_begin_button.add_theme_color_override("font_focus_color", INK)
	_begin_button.add_theme_color_override("font_pressed_color", TEXT)
	_begin_button.add_theme_stylebox_override(
		"normal", _make_textured_button_style(Color.WHITE)
	)
	(
		_begin_button
			. add_theme_stylebox_override(
				"hover",
				_make_textured_button_style(Color(1.14, 1.09, 0.96, 1.0)),
			)
	)
	(
		_begin_button
		. add_theme_stylebox_override(
			"focus",
			_make_textured_button_style(Color(1.1, 1.06, 0.94, 1.0)),
		)
	)
	(
		_begin_button
		. add_theme_stylebox_override(
			"pressed",
			_make_textured_button_style(Color(0.72, 0.72, 0.72, 1.0)),
		)
	)
	_begin_button.add_theme_stylebox_override(
		"disabled", _make_textured_button_style(Color(0.58, 0.58, 0.58, 0.62))
	)
	_begin_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin_button.pressed.connect(_on_begin_pressed)
	_title_panel.add_child(_begin_button)


func _build_language_toggle(ui_root: Control) -> void:
	_language_toggle = Button.new()
	_language_toggle.name = "LanguageToggle"
	_language_toggle.focus_mode = Control.FOCUS_ALL
	_language_toggle.clip_text = true
	_language_toggle.add_theme_font_size_override("font_size", 14)
	_language_toggle.add_theme_color_override("font_color", TEXT)
	_language_toggle.add_theme_color_override("font_hover_color", AMBER)
	_language_toggle.add_theme_color_override("font_focus_color", AMBER)
	_language_toggle.add_theme_stylebox_override(
		"normal", _make_compact_button_style(Color(0.02, 0.035, 0.05, 0.82), TEAL, 1)
	)
	_language_toggle.add_theme_stylebox_override(
		"hover", _make_compact_button_style(PANEL_SOFT, AMBER, 1)
	)
	_language_toggle.add_theme_stylebox_override(
		"focus", _make_compact_button_style(PANEL_SOFT, AMBER, 2)
	)
	_language_toggle.add_theme_stylebox_override(
		"pressed", _make_compact_button_style(Color(0.04, 0.055, 0.06, 0.96), AMBER, 1)
	)
	_language_toggle.add_theme_stylebox_override(
		"disabled", _make_compact_button_style(Color(0.02, 0.035, 0.05, 0.72), TEAL, 1)
	)
	_language_toggle.pressed.connect(_on_language_pressed)
	ui_root.add_child(_language_toggle)
	_refresh_language_toggle()


func _make_label(node_name: String, value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button_style(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = _make_panel_style(color, border_color, border_width)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	return style


func _make_textured_button_style(modulate: Color) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = START_BUTTON_ART
	style.modulate_color = modulate
	style.draw_center = true
	style.set_texture_margin(SIDE_LEFT, 26.0)
	style.set_texture_margin(SIDE_TOP, 20.0)
	style.set_texture_margin(SIDE_RIGHT, 26.0)
	style.set_texture_margin(SIDE_BOTTOM, 20.0)
	style.set_content_margin(SIDE_LEFT, 22.0)
	style.set_content_margin(SIDE_RIGHT, 22.0)
	return style


func _make_compact_button_style(
	color: Color, border_color: Color, border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = _make_button_style(color, border_color, border_width)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


func _make_panel_style(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	return style


func _apply_responsive_layout() -> void:
	_layout = ResponsiveViewportScript.title_layout(get_viewport().get_visible_rect().size)
	var portrait: bool = bool(_layout[&"portrait"])
	var design_size: Vector2 = _layout[&"design_size"] as Vector2
	_content_group.position = _layout[&"canvas_position"] as Vector2
	_content_group.size = design_size
	_content_group.scale = Vector2.ONE * float(_layout[&"canvas_scale"])
	_background.texture = TITLE_MOBILE if portrait else TITLE_DESKTOP
	if portrait:
		_apply_portrait_layout()
	else:
		_apply_landscape_layout()
	_begin_button.pivot_offset = _begin_button.size * 0.5
	_layout_language_toggle()


func _apply_landscape_layout() -> void:
	_title_panel.position = Vector2(62.0, 164.0)
	_title_panel.size = Vector2(560.0, 330.0)
	_title_label.position = Vector2(0.0, 0.0)
	_title_label.size = Vector2(560.0, 90.0)
	_title_label.add_theme_font_size_override("font_size", 56)
	_mission_label.position = Vector2(0.0, 96.0)
	_mission_label.size = Vector2(555.0, 56.0)
	_mission_label.add_theme_font_size_override("font_size", 15)
	_begin_button.position = Vector2(0.0, 188.0)
	_begin_button.size = Vector2(475.0, 84.0)
	_begin_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin_button.add_theme_font_size_override("font_size", 26)


func _apply_portrait_layout() -> void:
	_title_panel.position = Vector2(40.0, 96.0)
	_title_panel.size = Vector2(640.0, 1010.0)
	_title_label.position = Vector2(0.0, 0.0)
	_title_label.size = Vector2(640.0, 96.0)
	_title_label.add_theme_font_size_override("font_size", 62)
	_mission_label.position = Vector2(0.0, 104.0)
	_mission_label.size = Vector2(620.0, 60.0)
	_mission_label.add_theme_font_size_override("font_size", 16)
	_begin_button.position = Vector2(0.0, 880.0)
	_begin_button.size = Vector2(640.0, 128.0)
	_begin_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin_button.add_theme_font_size_override("font_size", 42)


func _layout_language_toggle() -> void:
	var viewport: Vector2 = _layout[&"viewport"] as Vector2
	var settings_rect: Rect2 = AccessibilityPanelScript.trigger_rect_for(viewport)
	if is_instance_valid(_settings_panel):
		var settings_button: Button = _settings_panel.call("get_trigger_button") as Button
		if settings_button != null:
			settings_rect = settings_button.get_rect()
	_on_settings_trigger_layout_changed(settings_rect)


func _on_settings_trigger_layout_changed(settings_rect: Rect2) -> void:
	if _language_toggle == null:
		return
	var viewport: Vector2 = _layout.get(&"viewport", Vector2(1280.0, 720.0)) as Vector2
	var live_viewport: Viewport = get_viewport()
	if live_viewport != null:
		viewport = live_viewport.get_visible_rect().size
	var portrait: bool = viewport.y > viewport.x
	var gap: float = 8.0 if portrait else 12.0
	_language_toggle.size = Vector2(166.0 if portrait else 250.0, settings_rect.size.y)
	_language_toggle.position = Vector2(
		maxf(settings_rect.position.x - gap - _language_toggle.size.x, 0.0),
		settings_rect.position.y,
	)
	_language_toggle.add_theme_font_size_override("font_size", 17)


func _on_language_pressed() -> void:
	_play_ui_click()
	_cycle_locale()


func _cycle_locale() -> void:
	var current: StringName = LocalizationScript.get_locale()
	var next_locale: StringName = &"zh-CN" if current == &"en" else &"en"
	var preferences: RefCounted = PlayerPreferencesScript.new() as RefCounted
	preferences.call("load_preferences")
	if not bool(preferences.call("set_value", &"locale", next_locale)):
		return
	preferences.call("save_preferences")
	LocalizationScript.set_locale(next_locale)


func _on_begin_pressed() -> void:
	if not _loading_complete or _field_visible:
		return
	_play_start_click()
	_prepare_field_entry()
	await _fade_out_title_music()
	_enter_field()


func _prepare_field_entry() -> void:
	_stop_begin_hover()
	_loading_complete = false
	_field_visible = true
	_begin_button.disabled = true
	_begin_button.text = LocalizationScript.t(&"title.deploying")
	WebSceneStateScript.set_state("field-loading")
	print("[PROTO_ISOMETRIC_BEGIN]")


func _enter_field() -> void:
	var field: Node = FIELD_SCENE.instantiate()
	if field == null:
		_field_visible = false
		_complete_loading()
		push_error("Field scene instantiation failed.")
		return
	get_tree().root.add_child(field)
	get_tree().current_scene = field
	queue_free()


func _on_locale_changed(_locale: StringName) -> void:
	_refresh_localized_text()


func _refresh_localized_text() -> void:
	if _title_panel == null:
		return
	_title_label.text = LocalizationScript.t(&"title.name")
	_mission_label.text = LocalizationScript.t(&"title.mission")
	_begin_button.text = LocalizationScript.t(
		&"title.deploying" if _field_visible else &"title.start_game"
	)
	_refresh_language_toggle()


func _refresh_language_toggle() -> void:
	if _language_toggle == null:
		return
	var locale: String = str(LocalizationScript.get_locale())
	_language_toggle.text = (
		LocalizationScript
		. t(
			&"title.language_toggle",
			{"language": LocalizationScript.t("common.locale_short.%s" % locale)},
		)
	)
	_language_toggle.tooltip_text = LocalizationScript.t(&"title.language_toggle_tooltip")


func is_title_visible() -> bool:
	return _title_panel.visible


func is_staging_visible() -> bool:
	return false


func get_begin_button() -> Button:
	return _begin_button


func get_title_label() -> Label:
	return _title_label


func get_language_toggle() -> Button:
	return _language_toggle


func is_loading_complete() -> bool:
	return _loading_complete


func is_audio_ready() -> bool:
	return (
		UI_HOVER_CUE != null
		and UI_CLICK_CUE != null
		and UI_START_CLICK_CUE != null
		and TITLE_MUSIC != null
		and START_BUTTON_ART != null
		and get_node_or_null("/root/AudioService") != null
	)


func get_audio_trigger_count() -> int:
	return _audio_trigger_count


func get_ui_feedback_metrics() -> Dictionary:
	return {
		&"hover_path": UI_HOVER_CUE.resource_path,
		&"click_path": UI_CLICK_CUE.resource_path,
		&"start_click_path": UI_START_CLICK_CUE.resource_path,
		&"bus": AudioServiceScript.BUS_UI,
		&"hover_triggers": _hover_audio_trigger_count,
		&"click_triggers": _audio_trigger_count,
		&"controls": _ui_feedback_control_count,
		&"idle_pulse_active": false,
		&"hover_scale": START_HOVER_SCALE,
		&"hover_seconds": START_HOVER_SECONDS,
		&"hover_motion_active": _begin_hover_active,
	}


func get_title_music_metrics() -> Dictionary:
	return {
		&"stream_path": TITLE_MUSIC.resource_path,
		&"bus": AudioServiceScript.BUS_MUSIC,
		&"volume_db": TITLE_MUSIC_VOLUME_DB,
		&"fade_seconds": TITLE_MUSIC_FADE_SECONDS,
		&"looping": bool(TITLE_MUSIC.get("loop")),
		&"playing": (
			is_instance_valid(_title_music_player)
			and _title_music_player.playing
		),
	}


func prepare_for_shutdown() -> void:
	_stop_begin_hover()
	if is_instance_valid(_title_music_player):
		_title_music_player.stop()


func _complete_loading() -> void:
	_loading_complete = true
	_begin_button.disabled = false
	_begin_button.visible = true
	_begin_button.text = LocalizationScript.t(&"title.start_game")
	_stop_begin_hover()


func _animate_begin_hover(hovered: bool) -> void:
	if not is_instance_valid(_begin_button):
		return
	_begin_hover_active = hovered and _loading_complete and not _begin_button.disabled
	if is_instance_valid(_begin_hover_tween):
		_begin_hover_tween.kill()
	_begin_button.pivot_offset = _begin_button.size * 0.5
	var target_scale: Vector2 = (
		Vector2.ONE * START_HOVER_SCALE if _begin_hover_active else Vector2.ONE
	)
	if not is_inside_tree():
		_begin_button.scale = target_scale
		return
	_begin_hover_tween = create_tween()
	(
		_begin_hover_tween
		. tween_property(
			_begin_button,
			"scale",
			target_scale,
			START_HOVER_SECONDS,
		)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)


func _stop_begin_hover() -> void:
	if is_instance_valid(_begin_hover_tween):
		_begin_hover_tween.kill()
	_begin_hover_tween = null
	_begin_hover_active = false
	if is_instance_valid(_begin_button):
		_begin_button.scale = Vector2.ONE


func _start_title_music() -> void:
	if TITLE_MUSIC == null or not is_inside_tree() or is_instance_valid(_title_music_player):
		return
	TITLE_MUSIC.set("loop", true)
	_title_music_player = AudioStreamPlayer.new()
	_title_music_player.name = "TitleMusic"
	_title_music_player.stream = TITLE_MUSIC
	_title_music_player.bus = AudioServiceScript.BUS_MUSIC
	_title_music_player.volume_db = TITLE_MUSIC_VOLUME_DB
	add_child(_title_music_player)
	if DisplayServer.get_name() != "headless":
		_title_music_player.play()
	print(
		"[TITLE_MUSIC_READY] path=%s length=%.3f loop=%s"
		% [
			TITLE_MUSIC.resource_path,
			TITLE_MUSIC.get_length(),
			str(bool(TITLE_MUSIC.get("loop"))),
		]
	)


func _fade_out_title_music() -> void:
	if (
		DisplayServer.get_name() == "headless"
		or not is_instance_valid(_title_music_player)
		or not _title_music_player.playing
	):
		return
	var tween: Tween = create_tween()
	(
		tween
		. tween_property(
			_title_music_player,
			"volume_db",
			SILENT_VOLUME_DB,
			TITLE_MUSIC_FADE_SECONDS,
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	await tween.finished
	if is_instance_valid(_title_music_player):
		_title_music_player.stop()


func _connect_ui_feedback() -> void:
	_connect_hover_feedback(_begin_button)
	_begin_button.mouse_entered.connect(_animate_begin_hover.bind(true))
	_begin_button.mouse_exited.connect(_animate_begin_hover.bind(false))
	_connect_hover_feedback(_language_toggle)
	if is_instance_valid(_settings_panel):
		var settings_button: Button = _settings_panel.call("get_trigger_button") as Button
		if settings_button != null:
			_connect_hover_feedback(settings_button)
			settings_button.pressed.connect(_play_ui_click)


func _connect_hover_feedback(button: Button) -> void:
	button.mouse_entered.connect(_play_ui_hover.bind(button))
	button.focus_entered.connect(_play_ui_hover.bind(button))
	_ui_feedback_control_count += 1


func _play_ui_hover(button: Button) -> void:
	if button == null or button.disabled or not button.visible:
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_hover_audio_ms < UI_HOVER_COOLDOWN_MS:
		return
	_last_hover_audio_ms = now_ms
	if _play_ui_cue(UI_HOVER_CUE, -6.0, 1):
		_hover_audio_trigger_count += 1
		print("[TITLE_UI_HOVER] count=%d" % _hover_audio_trigger_count)


func _play_ui_click() -> void:
	if _play_ui_cue(UI_CLICK_CUE, -3.0, 2):
		_audio_trigger_count += 1
		print("[TITLE_UI_CLICK] count=%d" % _audio_trigger_count)


func _play_start_click() -> void:
	if _play_ui_cue(UI_START_CLICK_CUE, -1.5, 3):
		_audio_trigger_count += 1
		print("[TITLE_UI_CLICK] count=%d" % _audio_trigger_count)


func _play_ui_cue(stream: AudioStream, volume_db: float, priority: int) -> bool:
	if not is_inside_tree():
		return false
	var preferences: Dictionary = (
		(PlayerPreferencesScript.new() as RefCounted).call("load_preferences") as Dictionary
	)
	if not bool(preferences.get(&"sfx_enabled", true)) or stream == null:
		return false
	var service: Node = get_node_or_null("/root/AudioService")
	if service == null:
		return false
	return bool(
		service.call(
			"play_global",
			stream,
			AudioServiceScript.BUS_UI,
			1.0,
			volume_db,
			priority,
		)
	)
