extends RefCounted

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const TitleScreenScript: GDScript = preload("res://scripts/title_screen.gd")

const DESKTOP_ART: String = "res://assets/title/title_scene_desktop.png"
const MOBILE_ART: String = "res://assets/title/title_scene_mobile.png"


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
		"field guide teaches desktop, touch, and exposed-enemy timing",
		(
			guide.text.contains("WASD")
			and guide.text.contains("TOUCH")
			and guide.text.contains("EXPOSED")
		),
	)
	_add(
		cases,
		"launch action uses the English dictionary",
		begin.text == LocalizationScript.t(&"title.begin_new"),
	)
	_add(
		cases,
		"desktop and mobile Signal-First artwork load",
		load(DESKTOP_ART) is Texture2D and load(MOBILE_ART) is Texture2D,
	)
	LocalizationScript.set_locale(&"zh-CN", false)
	title.call("_refresh_localized_text")
	_add(
		cases,
		"Signal-First title refreshes fully to Simplified Chinese",
		(
			mission.text == LocalizationScript.t(&"title.mission")
			and link.text == LocalizationScript.t(&"title.step.link")
			and guide.text == LocalizationScript.t(&"title.field_guide")
			and move.text == LocalizationScript.t(&"title.control.move")
		),
	)
	title.call("_prepare_field_entry")
	_add(
		cases,
		"deployment state remains localized while the field initializes",
		begin.disabled and begin.text == LocalizationScript.t(&"title.deploying"),
	)
	LocalizationScript.set_locale(&"en", false)
	title.free()
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
