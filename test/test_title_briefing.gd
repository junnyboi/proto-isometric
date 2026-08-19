extends RefCounted

const TitleScreenScript: GDScript = preload("res://scripts/title_screen.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var title: Node = TitleScreenScript.new()
	title.call("_build_interface")
	var panel: Node = title.get_node("UILayer/UIRoot/TitlePanel")
	var story: Label = panel.get_node("Story") as Label
	var tutorial: Label = panel.get_node("Tutorial") as Label
	var objectives: Label = panel.get_node("Objectives") as Label
	var begin: Button = panel.get_node("BeginButton") as Button
	_add(cases, "launch story briefs Cardinal", story.text.contains("CARDINAL WAKES"))
	_add(
		cases,
		"launch tutorial teaches desktop and touch movement",
		tutorial.text.contains("WASD") and tutorial.text.contains("TAP-HOLD JOYSTICK"),
	)
	_add(
		cases,
		"launch tutorial teaches Smash and worm timing",
		(
			tutorial.text.contains("SMASH")
			and tutorial.text.contains("AVOID STORMS")
			and tutorial.text.contains("EXPOSED")
		),
	)
	_add(
		cases,
		"launch briefing states all expedition objectives",
		(
			objectives.text.contains("3 RELAYS")
			and objectives.text.contains("SURVIVE EACH ALERT")
			and objectives.text.contains("OUTPOST TO EXTRACT")
		),
	)
	_add(cases, "launch action names the expedition", begin.text.contains("NEW EXPEDITION"))
	title.free()
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
