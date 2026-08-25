extends Node2D

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")

const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")
const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const AccessibilityPanelScript: GDScript = preload("res://scripts/accessibility_panel.gd")
const SaveRepositoryScript: GDScript = preload("res://scripts/save_repository.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
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
const BEGIN_CUE: AudioStream = preload("res://assets/audio/ui_begin.wav")
const TITLE_MUSIC: AudioStream = preload("res://assets/audio/bgm_title.ogg")
const TITLE_MUSIC_VOLUME_DB: float = -9.0
const TITLE_MUSIC_FADE_SECONDS: float = 0.65
const SILENT_VOLUME_DB: float = -80.0

const AMBER: Color = Color("f3a21e")
const AMBER_HOVER: Color = Color("ffc35c")
const INK: Color = Color("0a0d12")
const PANEL: Color = Color(0.018, 0.027, 0.043, 0.96)
const PANEL_SOFT: Color = Color(0.025, 0.043, 0.057, 0.91)
const TEXT: Color = Color("edf0ed")
const MUTED: Color = Color("789095")
const TEAL: Color = Color("668f91")

var _background: TextureRect
var _content_group: Control
var _title_panel: Control
var _title_label: Label
var _mission_label: Label
var _mission_rail: Control
var _subtitle: Label
var _begin_button: Button
var _cta_keycap: Label
var _controls_strip: Control
var _field_guide_button: Button
var _field_guide_panel: ColorRect
var _field_guide_close: Button
var _language_toggle: Button
var _layout: Dictionary = {}
var _field_visible: bool = false
var _audio_trigger_count: int = 0
var _title_music_player: AudioStreamPlayer


func _ready() -> void:
	_build_interface()
	_start_title_music()
	add_to_group("localization_listeners")
	add_child(AccessibilityPanelScript.new())
	_apply_save_metadata()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_begin_button.grab_focus()
	WebSceneStateScript.set_state("title-ready")
	print("[PROTO_ISOMETRIC_READY]")


func _unhandled_input(event: InputEvent) -> void:
	if _field_guide_panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_set_field_guide_visible(false)
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F1:
			get_viewport().set_input_as_handled()
			_set_field_guide_visible(not _field_guide_panel.visible)
			return
	if _begin_button.visible and event.is_action_pressed("ui_accept"):
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
	_build_controls_strip()
	_build_field_guide(ui_root)
	_build_language_toggle(ui_root)

func _build_briefing() -> void:
	var eyebrow: Label = _make_label(
		"Eyebrow",
		LocalizationScript.t(&"title.eyebrow"),
		14,
		AMBER,
	)
	_title_panel.add_child(eyebrow)

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

	_mission_rail = Control.new()
	_mission_rail.name = "MissionRail"
	_title_panel.add_child(_mission_rail)
	_add_rail_step("LinkStep", &"title.step.link")
	_add_rail_step("EndureStep", &"title.step.endure")
	_add_rail_step("ExtractStep", &"title.step.extract")

	_subtitle = _make_label(
		"RunStatus",
		LocalizationScript.t(&"title.no_active_record"),
		13,
		MUTED,
	)
	_title_panel.add_child(_subtitle)

	_begin_button = Button.new()
	_begin_button.name = "BeginButton"
	_begin_button.text = LocalizationScript.t(&"title.begin_new")
	_begin_button.focus_mode = Control.FOCUS_ALL
	_begin_button.add_theme_font_size_override("font_size", 26)
	_begin_button.add_theme_color_override("font_color", INK)
	_begin_button.add_theme_color_override("font_hover_color", INK)
	_begin_button.add_theme_color_override("font_focus_color", INK)
	_begin_button.add_theme_color_override("font_pressed_color", TEXT)
	_begin_button.add_theme_stylebox_override("normal", _make_button_style(AMBER, INK, 2))
	(
		_begin_button
		. add_theme_stylebox_override(
			"hover",
			_make_button_style(AMBER_HOVER, TEXT, 2),
		)
	)
	(
		_begin_button
		. add_theme_stylebox_override(
			"focus",
			_make_button_style(AMBER_HOVER, TEXT, 3),
		)
	)
	(
		_begin_button
		. add_theme_stylebox_override(
			"pressed",
			_make_button_style(Color("8f5610"), TEXT, 2),
		)
	)
	_begin_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_begin_button.pressed.connect(_on_begin_pressed)
	_title_panel.add_child(_begin_button)

	_cta_keycap = _make_label("Keycap", LocalizationScript.t(&"title.key_enter"), 13, INK)
	_cta_keycap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cta_keycap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cta_keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_begin_button.add_child(_cta_keycap)


func _add_rail_step(node_name: String, action_key: StringName) -> void:
	var step: Control = Control.new()
	step.name = node_name
	step.set_meta(&"action_key", action_key)
	_mission_rail.add_child(step)
	var number_label: Label = _make_label(
		"Number", LocalizationScript.t("%s.number" % action_key), 22, AMBER
	)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	step.add_child(number_label)
	var action_label: Label = _make_label("Action", LocalizationScript.t(action_key), 14, AMBER)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step.add_child(action_label)


func _build_controls_strip() -> void:
	_controls_strip = Control.new()
	_controls_strip.name = "ControlsStrip"
	_content_group.add_child(_controls_strip)
	_add_control_hint("MoveHint")
	_add_control_hint("RunHint")
	_add_control_hint("SmashHint")

	_field_guide_button = Button.new()
	_field_guide_button.name = "FieldGuideButton"
	_field_guide_button.text = LocalizationScript.t(&"title.field_guide_button_desktop")
	_field_guide_button.focus_mode = Control.FOCUS_ALL
	_field_guide_button.add_theme_font_size_override("font_size", 14)
	_field_guide_button.add_theme_color_override("font_color", AMBER)
	_field_guide_button.add_theme_color_override("font_hover_color", TEXT)
	_field_guide_button.add_theme_color_override("font_focus_color", TEXT)
	(
		_field_guide_button
		. add_theme_stylebox_override(
			"normal",
			_make_button_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0),
		)
	)
	(
		_field_guide_button
		. add_theme_stylebox_override(
			"hover",
			_make_button_style(PANEL_SOFT, AMBER, 1),
		)
	)
	(
		_field_guide_button
		. add_theme_stylebox_override(
			"focus",
			_make_button_style(PANEL_SOFT, AMBER, 2),
		)
	)
	_field_guide_button.pressed.connect(_toggle_field_guide)
	_controls_strip.add_child(_field_guide_button)


func _add_control_hint(node_name: String) -> void:
	var hint: Control = Control.new()
	hint.name = node_name
	_controls_strip.add_child(hint)
	var action_label: Label = _make_label("Action", "", 12, MUTED)
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_child(action_label)
	var input_label: Label = _make_label("Input", "", 12, TEXT)
	input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	(
		input_label
		. add_theme_stylebox_override(
			"normal",
			_make_panel_style(Color(0.025, 0.04, 0.055, 0.82), MUTED, 1),
		)
	)
	hint.add_child(input_label)


func _build_field_guide(ui_root: Control) -> void:
	_field_guide_panel = ColorRect.new()
	_field_guide_panel.name = "FieldGuidePanel"
	_field_guide_panel.color = PANEL
	_field_guide_panel.visible = false
	_field_guide_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(_field_guide_panel)

	var title: Label = _make_label(
		"Title", LocalizationScript.t(&"title.field_guide_title"), 24, TEXT
	)
	_field_guide_panel.add_child(title)
	var guide: Label = _make_label(
		"Guide",
		LocalizationScript.t(&"title.field_guide"),
		15,
		TEXT,
	)
	guide.name = "GuideText"
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_constant_override("line_spacing", 6)
	_field_guide_panel.add_child(guide)

	_field_guide_close = Button.new()
	_field_guide_close.name = "CloseButton"
	_field_guide_close.text = LocalizationScript.t(&"title.return_briefing")
	_field_guide_close.focus_mode = Control.FOCUS_ALL
	_field_guide_close.add_theme_font_size_override("font_size", 15)
	_field_guide_close.add_theme_color_override("font_color", INK)
	_field_guide_close.add_theme_color_override("font_hover_color", INK)
	(
		_field_guide_close
		. add_theme_stylebox_override(
			"normal",
			_make_button_style(AMBER, INK, 2),
		)
	)
	(
		_field_guide_close
		. add_theme_stylebox_override(
			"hover",
			_make_button_style(AMBER_HOVER, TEXT, 2),
		)
	)
	_field_guide_close.pressed.connect(_close_field_guide)
	_field_guide_panel.add_child(_field_guide_close)


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
	_language_toggle.pressed.connect(_cycle_locale)
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


func _make_compact_button_style(
	color: Color, border_color: Color, border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = _make_button_style(color, border_color, border_width)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
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
	_layout_field_guide()
	_layout_language_toggle()


func _apply_landscape_layout() -> void:
	_title_panel.position = Vector2(62.0, 132.0)
	_title_panel.size = Vector2(560.0, 470.0)
	var eyebrow: Label = _title_panel.get_node("Eyebrow") as Label
	eyebrow.position = Vector2(0.0, 0.0)
	eyebrow.size = Vector2(520.0, 28.0)
	eyebrow.add_theme_font_size_override("font_size", 14)
	_title_label.position = Vector2(0.0, 30.0)
	_title_label.size = Vector2(560.0, 90.0)
	_title_label.add_theme_font_size_override("font_size", 56)
	_mission_label.position = Vector2(0.0, 128.0)
	_mission_label.size = Vector2(555.0, 48.0)
	_mission_label.add_theme_font_size_override("font_size", 15)
	_mission_rail.position = Vector2(0.0, 190.0)
	_mission_rail.size = Vector2(530.0, 92.0)
	_layout_rail(false)
	_subtitle.position = Vector2(0.0, 336.0)
	_subtitle.size = Vector2(520.0, 28.0)
	_subtitle.add_theme_font_size_override("font_size", 13)
	_begin_button.position = Vector2(0.0, 370.0)
	_begin_button.size = Vector2(475.0, 84.0)
	_begin_button.add_theme_font_size_override("font_size", 26)
	_cta_keycap.position = Vector2(365.0, 17.0)
	_cta_keycap.size = Vector2(82.0, 38.0)
	_cta_keycap.add_theme_font_size_override("font_size", 13)
	(
		_cta_keycap
		. add_theme_stylebox_override(
			"normal",
			_make_panel_style(Color(1.0, 1.0, 1.0, 0.08), Color(0.1, 0.1, 0.1, 0.24), 1),
		)
	)
	_controls_strip.position = Vector2(32.0, 644.0)
	_controls_strip.size = Vector2(1216.0, 56.0)
	_layout_controls(false)


func _apply_portrait_layout() -> void:
	_title_panel.position = Vector2(40.0, 58.0)
	_title_panel.size = Vector2(640.0, 1010.0)
	var eyebrow: Label = _title_panel.get_node("Eyebrow") as Label
	eyebrow.position = Vector2(0.0, 0.0)
	eyebrow.size = Vector2(620.0, 38.0)
	eyebrow.add_theme_font_size_override("font_size", 20)
	_title_label.position = Vector2(0.0, 42.0)
	_title_label.size = Vector2(640.0, 96.0)
	_title_label.add_theme_font_size_override("font_size", 62)
	_mission_label.position = Vector2(0.0, 146.0)
	_mission_label.size = Vector2(620.0, 60.0)
	_mission_label.add_theme_font_size_override("font_size", 16)
	_mission_rail.position = Vector2(58.0, 708.0)
	_mission_rail.size = Vector2(524.0, 118.0)
	_layout_rail(true)
	_subtitle.position = Vector2(0.0, 842.0)
	_subtitle.size = Vector2(620.0, 28.0)
	_subtitle.add_theme_font_size_override("font_size", 13)
	_begin_button.position = Vector2(0.0, 880.0)
	_begin_button.size = Vector2(640.0, 128.0)
	_begin_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin_button.add_theme_font_size_override("font_size", 42)
	_cta_keycap.visible = false
	_controls_strip.position = Vector2(40.0, 1080.0)
	_controls_strip.size = Vector2(640.0, 160.0)
	_layout_controls(true)


func _layout_rail(portrait: bool) -> void:
	var step_width: float = 150.0 if portrait else 130.0
	var gap: float = 37.0 if portrait else 65.0
	var steps: Array[Node] = _mission_rail.get_children()
	for index: int in range(steps.size()):
		var step: Control = steps[index] as Control
		step.position = Vector2(float(index) * (step_width + gap), 0.0)
		step.size = Vector2(step_width, _mission_rail.size.y)
		var number_label: Label = step.get_node("Number") as Label
		number_label.position = Vector2((step_width - 58.0) * 0.5, 0.0)
		number_label.size = Vector2(58.0, 58.0)
		number_label.add_theme_font_size_override("font_size", 28 if portrait else 22)
		(
			number_label
			. add_theme_stylebox_override(
				"normal",
				_make_panel_style(Color(0.0, 0.0, 0.0, 0.18), AMBER, 2),
			)
		)
		var action_label: Label = step.get_node("Action") as Label
		action_label.position = Vector2(0.0, 68.0)
		action_label.size = Vector2(step_width, 32.0)
		action_label.add_theme_font_size_override("font_size", 18 if portrait else 14)


func _layout_controls(portrait: bool) -> void:
	var move_hint: Control = _controls_strip.get_node("MoveHint") as Control
	var run_hint: Control = _controls_strip.get_node("RunHint") as Control
	var smash_hint: Control = _controls_strip.get_node("SmashHint") as Control
	_cta_keycap.visible = not portrait
	if portrait:
		_layout_control_hint(
			move_hint,
			Vector2(0.0, 0.0),
			LocalizationScript.t(&"title.control.move_touch"),
			LocalizationScript.t(&"title.control.drive_icon"),
			true,
		)
		_layout_control_hint(
			run_hint,
			Vector2(213.0, 0.0),
			LocalizationScript.t(&"title.control.run_touch"),
			LocalizationScript.t(&"title.control.run_icon"),
			true,
		)
		_layout_control_hint(
			smash_hint,
			Vector2(426.0, 0.0),
			LocalizationScript.t(&"title.control.smash_touch"),
			LocalizationScript.t(&"title.control.smash_icon"),
			true,
		)
		_field_guide_button.position = Vector2(174.0, 112.0)
		_field_guide_button.size = Vector2(292.0, 48.0)
		_field_guide_button.text = LocalizationScript.t(&"title.field_guide_button_mobile")
		_field_guide_button.add_theme_font_size_override("font_size", 18)
	else:
		_layout_control_hint(
			move_hint,
			Vector2(0.0, 0.0),
			LocalizationScript.t(&"title.control.move"),
			LocalizationScript.t(&"title.control.move_input"),
			false,
		)
		_layout_control_hint(
			run_hint,
			Vector2(214.0, 0.0),
			LocalizationScript.t(&"title.control.run"),
			LocalizationScript.t(&"title.control.run_input"),
			false,
		)
		_layout_control_hint(
			smash_hint,
			Vector2(414.0, 0.0),
			LocalizationScript.t(&"title.control.smash"),
			LocalizationScript.t(&"title.control.smash_input"),
			false,
		)
		_field_guide_button.position = Vector2(1044.0, 5.0)
		_field_guide_button.size = Vector2(172.0, 42.0)
		_field_guide_button.text = LocalizationScript.t(&"title.field_guide_button_desktop")
		_field_guide_button.add_theme_font_size_override("font_size", 14)


func _layout_control_hint(
	hint: Control,
	position: Vector2,
	action: String,
	input: String,
	portrait: bool,
) -> void:
	hint.position = position
	hint.size = Vector2(213.0 if portrait else 190.0, 96.0 if portrait else 48.0)
	var action_label: Label = hint.get_node("Action") as Label
	var input_label: Label = hint.get_node("Input") as Label
	if portrait:
		input_label.position = Vector2(8.0, 16.0)
		input_label.size = Vector2(62.0, 62.0)
		input_label.add_theme_font_size_override("font_size", 28)
		action_label.position = Vector2(82.0, 18.0)
		action_label.size = Vector2(123.0, 64.0)
		action_label.text = action
		action_label.add_theme_font_size_override("font_size", 18)
	else:
		action_label.position = Vector2(0.0, 5.0)
		action_label.size = Vector2(58.0, 38.0)
		action_label.text = action
		action_label.add_theme_font_size_override("font_size", 12)
		input_label.position = Vector2(64.0, 7.0)
		input_label.size = Vector2(98.0, 34.0)
		input_label.text = input
		input_label.add_theme_font_size_override("font_size", 12)


func _layout_field_guide() -> void:
	var viewport: Vector2 = _layout[&"viewport"] as Vector2
	var portrait: bool = bool(_layout[&"portrait"])
	var panel_size: Vector2 = (
		Vector2(minf(viewport.x - 28.0, 680.0), minf(viewport.y - 36.0, 500.0))
		if portrait
		else Vector2(minf(viewport.x - 64.0, 760.0), minf(viewport.y - 64.0, 430.0))
	)
	_field_guide_panel.size = panel_size
	_field_guide_panel.position = (viewport - panel_size) * 0.5
	var title: Label = _field_guide_panel.get_node("Title") as Label
	title.position = Vector2(28.0, 22.0)
	title.size = Vector2(panel_size.x - 56.0, 42.0)
	var guide: Label = _field_guide_panel.get_node("GuideText") as Label
	guide.position = Vector2(28.0, 78.0)
	guide.size = Vector2(panel_size.x - 56.0, panel_size.y - 160.0)
	guide.add_theme_font_size_override("font_size", 13 if portrait else 15)
	_field_guide_close.position = Vector2(28.0, panel_size.y - 66.0)
	_field_guide_close.size = Vector2(panel_size.x - 56.0, 44.0)


func _layout_language_toggle() -> void:
	var viewport: Vector2 = _layout[&"viewport"] as Vector2
	var portrait: bool = bool(_layout[&"portrait"])
	_language_toggle.size = Vector2(166.0 if portrait else 250.0, 42.0)
	_language_toggle.add_theme_font_size_override("font_size", 12 if portrait else 14)
	_language_toggle.position = Vector2(
		viewport.x - 190.0 - _language_toggle.size.x - 34.0,
		18.0,
	)


func _toggle_field_guide() -> void:
	_set_field_guide_visible(not _field_guide_panel.visible)


func _close_field_guide() -> void:
	_set_field_guide_visible(false)


func _set_field_guide_visible(value: bool) -> void:
	_field_guide_panel.visible = value
	if not is_inside_tree():
		return
	if value:
		_field_guide_close.grab_focus()
	else:
		_field_guide_button.grab_focus()


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
	if _field_visible:
		return
	_prepare_field_entry()
	_trigger_begin_audio()
	await _fade_out_title_music()
	_enter_field()


func _prepare_field_entry() -> void:
	_field_visible = true
	_begin_button.disabled = true
	_begin_button.text = LocalizationScript.t(&"title.deploying")
	WebSceneStateScript.set_state("field-loading")
	print("[PROTO_ISOMETRIC_BEGIN]")


func _enter_field() -> void:
	var field: Node = FIELD_SCENE.instantiate()
	if field == null:
		_field_visible = false
		_begin_button.disabled = false
		_apply_save_metadata()
		push_error("Field scene instantiation failed.")
		return
	get_tree().root.add_child(field)
	get_tree().current_scene = field
	queue_free()


func _apply_save_metadata() -> void:
	var repository: RefCounted = SaveRepositoryScript.new() as RefCounted
	var world: RefCounted = InfiniteWorldScript.new() as RefCounted
	if not bool(repository.call("configure", "user://walkers-wake-world.json", world, "title")):
		return
	var envelope: Dictionary = repository.call("load_state") as Dictionary
	if envelope.is_empty():
		_begin_button.text = LocalizationScript.t(&"title.begin_new")
		_subtitle.text = LocalizationScript.t(&"title.no_active_record")
		return
	var run: Dictionary = envelope.get(&"active_run", {}) as Dictionary
	var profile: Dictionary = envelope.get(&"profile", {}) as Dictionary
	var phase: StringName = StringName(str(run.get(&"phase", RuntimeIdsScript.RUN_PHASE_HUNT)))
	var terminal: bool = (
		phase in [RuntimeIdsScript.RUN_PHASE_SUCCEEDED, RuntimeIdsScript.RUN_PHASE_FAILED]
	)
	_begin_button.text = LocalizationScript.t(
		&"title.begin_review" if terminal else &"title.begin_continue"
	)
	_subtitle.text = (
		LocalizationScript.t(&"title.terminal_ready")
		if terminal
		else LocalizationScript.t(
			&"title.active_ready", {&"relay": int(run.get(&"completed_relays", 0))}
		)
	)
	var banked_total: int = (
		int(profile.get(&"banked_relay_data", 0))
		+ int(profile.get(&"banked_scrap", 0))
		+ int(profile.get(&"banked_cores", 0))
	)
	if banked_total > 0 and not terminal:
		_subtitle.text += LocalizationScript.t(
			&"title.bank_suffix", {&"bank": "%03d" % banked_total}
		)


func _on_locale_changed(_locale: StringName) -> void:
	_refresh_localized_text()
	if _field_visible:
		_begin_button.text = LocalizationScript.t(&"title.deploying")
	else:
		_apply_save_metadata()


func _refresh_localized_text() -> void:
	if _title_panel == null:
		return
	(_title_panel.get_node("Eyebrow") as Label).text = LocalizationScript.t(&"title.eyebrow")
	_title_label.text = LocalizationScript.t(&"title.name")
	_mission_label.text = LocalizationScript.t(&"title.mission")
	for step: Node in _mission_rail.get_children():
		var action_key: StringName = step.get_meta(&"action_key", &"") as StringName
		(step.get_node("Number") as Label).text = LocalizationScript.t("%s.number" % action_key)
		(step.get_node("Action") as Label).text = LocalizationScript.t(action_key)
	_cta_keycap.text = LocalizationScript.t(&"title.key_enter")
	(_field_guide_panel.get_node("Title") as Label).text = LocalizationScript.t(
		&"title.field_guide_title"
	)
	(_field_guide_panel.get_node("GuideText") as Label).text = LocalizationScript.t(
		&"title.field_guide"
	)
	_field_guide_close.text = LocalizationScript.t(&"title.return_briefing")
	_refresh_language_toggle()
	_layout_controls(bool(_layout.get(&"portrait", false)))


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


func is_field_guide_visible() -> bool:
	return _field_guide_panel.visible


func get_field_guide_button() -> Button:
	return _field_guide_button


func get_language_toggle() -> Button:
	return _language_toggle


func is_audio_ready() -> bool:
	return (
		BEGIN_CUE != null
		and TITLE_MUSIC != null
		and get_node_or_null("/root/AudioService") != null
	)


func get_audio_trigger_count() -> int:
	return _audio_trigger_count


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
	if is_instance_valid(_title_music_player):
		_title_music_player.stop()


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


func _trigger_begin_audio() -> void:
	_audio_trigger_count += 1
	var preferences: Dictionary = (
		(PlayerPreferencesScript.new() as RefCounted).call("load_preferences") as Dictionary
	)
	if (
		bool(preferences.get(&"sfx_enabled", true))
		and BEGIN_CUE != null
	):
		var service: Node = get_node_or_null("/root/AudioService")
		if service != null:
			service.call("play_global", BEGIN_CUE, AudioServiceScript.BUS_UI, 1.0, -5.0, 2)
