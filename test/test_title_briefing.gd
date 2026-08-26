extends RefCounted

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const AccessibilityPanelScript: GDScript = preload("res://scripts/accessibility_panel.gd")
const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")
const TitleScreenScript: GDScript = preload("res://scripts/title_screen.gd")

const DESKTOP_ART: String = "res://assets/title/protos_harvest_title_desktop.png"
const MOBILE_ART: String = "res://assets/title/protos_harvest_title_mobile.png"
const TITLE_MUSIC_PATH: String = "res://assets/audio/bgm_title.ogg"


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	LocalizationScript.set_locale(&"en", false)
	var title: Node = TitleScreenScript.new()
	title.call("_build_interface")
	var panel: Node = title.get_node("UILayer/UIRoot/ConceptCanvas/TitlePanel")
	var mission: Label = panel.get_node("Mission") as Label
	var begin: Button = panel.get_node("BeginButton") as Button
	var language: Button = title.call("get_language_toggle") as Button
	var settings: CanvasLayer = AccessibilityPanelScript.new() as CanvasLayer
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(settings)
	var settings_language: Button = settings.call("get_language_button") as Button
	var settings_trigger: Button = settings.call("get_trigger_button") as Button
	_add(
		cases,
		"reduced title retains the localized homestead mission",
		mission.text == LocalizationScript.t(&"title.mission"),
	)
	var removed_paths: Array[NodePath] = [
		NodePath("Eyebrow"),
		NodePath("MissionRail"),
		NodePath("RunStatus"),
		NodePath("../ControlsStrip"),
		NodePath("../../FieldGuidePanel"),
	]
	var removed_nodes_absent: bool = true
	for path: NodePath in removed_paths:
		removed_nodes_absent = removed_nodes_absent and not panel.has_node(path)
	_add(
		cases,
		"eyebrow rail record controls and field guide are absent from the title",
		removed_nodes_absent,
	)
	_add(
		cases,
		"Start Game stays hidden until title loading completes",
		begin.disabled and not begin.visible and not bool(title.call("is_loading_complete")),
	)
	title.call("_complete_loading")
	_add(
		cases,
		"loading completion reveals one interactive localized Start Game action",
		(
			begin.visible
			and not begin.disabled
			and begin.focus_mode == Control.FOCUS_ALL
			and begin.text == LocalizationScript.t(&"title.start_game")
		),
	)
	_add(
		cases,
		"landing page exposes the bilingual language toggle",
		language != null and "EN / 简体中文" in language.text and "[EN]" in language.text,
	)
	var toggle_layouts_valid: bool = true
	for viewport: Vector2 in [Vector2(1280.0, 720.0), Vector2(390.0, 844.0)]:
		title.set("_layout", {&"viewport": viewport, &"portrait": viewport.y > viewport.x})
		title.call("_layout_language_toggle")
		var language_rect: Rect2 = Rect2(language.position, language.size)
		var settings_rect: Rect2 = AccessibilityPanelScript.trigger_rect_for(viewport)
		toggle_layouts_valid = (
			toggle_layouts_valid
			and language_rect.position.x >= 0.0
			and is_equal_approx(
				language_rect.end.x + (8.0 if viewport.y > viewport.x else 12.0),
				settings_rect.position.x,
			)
			and is_equal_approx(language_rect.position.y, settings_rect.position.y)
			and is_equal_approx(language_rect.size.y, settings_trigger.size.y)
			and (
				language.get_theme_font_size("font_size")
				== settings_trigger.get_theme_font_size("font_size")
			)
		)
	_add(
		cases,
		"language sits directly left of Settings with matching font size and height",
		toggle_layouts_valid,
	)
	_add(
		cases,
		"desktop and mobile title artwork load",
		load(DESKTOP_ART) is Texture2D and load(MOBILE_ART) is Texture2D,
	)
	var title_music: AudioStream = load(TITLE_MUSIC_PATH) as AudioStream
	var title_music_metrics: Dictionary = title.call("get_title_music_metrics") as Dictionary
	_add(
		cases,
		"title owns a long-form original Music-bus loop with bounded handoff",
		(
			title_music is AudioStreamOggVorbis
			and title_music.get_length() >= 80.0
			and title_music_metrics[&"stream_path"] == TITLE_MUSIC_PATH
			and title_music_metrics[&"bus"] == &"Music"
			and float(title_music_metrics[&"volume_db"]) <= -6.0
			and float(title_music_metrics[&"fade_seconds"]) > 0.0
			and float(title_music_metrics[&"fade_seconds"]) <= 1.0
		),
	)
	language.pressed.emit()
	title.call("_refresh_localized_text")
	_add(
		cases,
		"landing toggle refreshes retained title controls to Simplified Chinese",
		(
			LocalizationScript.get_locale() == &"zh-CN"
			and mission.text == LocalizationScript.t(&"title.mission")
			and begin.text == LocalizationScript.t(&"title.start_game")
			and "[简体中文]" in language.text
		),
	)
	var persisted: Dictionary = (
		(PlayerPreferencesScript.new() as RefCounted).call("load_preferences") as Dictionary
	)
	_add(cases, "landing toggle persists the selected locale", persisted[&"locale"] == &"zh-CN")
	_add(
		cases,
		"landing toggle synchronizes the settings-menu control",
		"[简体中文]" in settings_language.text,
	)
	title.call("_prepare_field_entry")
	_add(
		cases,
		"deployment state remains localized while gameplay initializes",
		begin.disabled and begin.text == LocalizationScript.t(&"title.deploying"),
	)
	language.pressed.emit()
	title.call("_refresh_localized_text")
	_add(cases, "landing toggle returns to English", LocalizationScript.get_locale() == &"en")
	settings.free()
	title.free()
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
