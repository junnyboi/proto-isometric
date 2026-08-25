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
	title.call("_layout_controls", false)
	var panel: Node = title.get_node("UILayer/UIRoot/ConceptCanvas/TitlePanel")
	var mission: Label = panel.get_node("Mission") as Label
	var begin: Button = panel.get_node("BeginButton") as Button
	var link: Label = panel.get_node("MissionRail/LinkStep/Action") as Label
	var guide: Label = title.get_node("UILayer/UIRoot/FieldGuidePanel/GuideText") as Label
	var language: Button = title.call("get_language_toggle") as Button
	var settings: CanvasLayer = AccessibilityPanelScript.new() as CanvasLayer
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(settings)
	var settings_language: Button = settings.call("get_language_button") as Button
	var move: Label = (
		title.get_node("UILayer/UIRoot/ConceptCanvas/ControlsStrip/MoveHint/Action") as Label
	)
	_add(
		cases,
		"Signal-First mission uses the English dictionary",
		mission.text == LocalizationScript.t(&"title.mission"),
	)
	_add(
		cases,
		"Signal-First rail uses semantic localization keys",
		link.text == LocalizationScript.t(&"title.step.link"),
	)
	_add(
		cases,
		"field guide teaches desktop touch farming and wilderness controls",
		(
			guide.text.contains("WASD")
			and guide.text.contains("TOUCH")
			and guide.text.contains("TILL")
			and guide.text.contains("WILDS")
		),
	)
	_add(
		cases,
		"launch action uses the English dictionary",
		begin.text == LocalizationScript.t(&"title.begin_new"),
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
		var access_rect: Rect2 = Rect2(Vector2(viewport.x - 208.0, 18.0), Vector2(190.0, 42.0))
		toggle_layouts_valid = (
			toggle_layouts_valid
			and language_rect.position.x >= 0.0
			and not language_rect.intersects(access_rect)
		)
	_add(cases, "landing language toggle stays clear of Access", toggle_layouts_valid)
	title.set("_layout", {&"viewport": Vector2(1280.0, 720.0), &"portrait": false})
	title.call("_layout_language_toggle")
	_add(
		cases,
		"desktop and mobile Signal-First artwork load",
		load(DESKTOP_ART) is Texture2D and load(MOBILE_ART) is Texture2D,
	)
	var title_music: AudioStream = load(TITLE_MUSIC_PATH) as AudioStream
	var title_music_metrics: Dictionary = title.call("get_title_music_metrics") as Dictionary
	_add(
		cases,
		"title briefing owns a long-form original Music-bus loop with bounded handoff",
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
		"landing toggle refreshes the complete title to Simplified Chinese",
		(
			LocalizationScript.get_locale() == &"zh-CN"
			and mission.text == LocalizationScript.t(&"title.mission")
			and link.text == LocalizationScript.t(&"title.step.link")
			and guide.text == LocalizationScript.t(&"title.field_guide")
			and move.text == LocalizationScript.t(&"title.control.move")
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
		"deployment state remains localized while the field initializes",
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
