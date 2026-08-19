extends RefCounted

const TitleScreenScript: GDScript = preload("res://scripts/title_screen.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var title: Node = TitleScreenScript.new()
	title.call("_build_interface")
	var panel: Node = title.get_node("UILayer/UIRoot/ConceptCanvas/TitlePanel")
	var mission: Label = panel.get_node("Mission") as Label
	var rail: Control = panel.get_node("MissionRail") as Control
	var begin: Button = panel.get_node("BeginButton") as Button
	var guide_panel: ColorRect = title.get_node("UILayer/UIRoot/FieldGuidePanel") as ColorRect
	var guide: Label = guide_panel.get_node("GuideText") as Label
	_add(
		cases,
		"launch mission names Cardinal's relay objective",
		mission.text.contains("LINK 3 RELAYS")
	)
	_add(
		cases,
		"launch mission states survival and extraction",
		(
			mission.text.contains("SURVIVE THE ALERT")
			and mission.text.contains("EXTRACT AT AN OUTPOST")
		),
	)
	_add(cases, "launch rail teaches link endure extract", rail.get_child_count() == 3)
	_add(
		cases,
		"field guide teaches desktop and touch movement",
		guide.text.contains("WASD") and guide.text.contains("TOUCH: DRAG AND HOLD"),
	)
	_add(
		cases,
		"field guide teaches Smash and exposed hunter timing",
		(
			guide.text.contains("SMASH")
			and guide.text.contains("HUNTERS")
			and guide.text.contains("EXPOSED")
		),
	)
	_add(cases, "launch action deploys Cardinal", begin.text == "DEPLOY CARDINAL")
	_add(
		cases,
		"field guide is keyboard and button accessible",
		title.call("get_field_guide_button") != null
	)
	title.free()
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
