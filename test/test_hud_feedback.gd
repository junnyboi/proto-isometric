extends RefCounted

const FieldHUDScript: GDScript = preload("res://scripts/field_hud.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_add(
		cases,
		"charge threshold events target the charge HUD only",
		(
			FieldHUDScript.feedback_target_for(&"event.charge.low") == &"charge"
			and FieldHUDScript.feedback_target_for(&"event.charge.high") == &"charge"
			and FieldHUDScript.feedback_target_for(&"event.smash.hit") == &""
		),
	)
	var deltas: Dictionary = (
		FieldHUDScript
		. state_reward_deltas(
			{&"run_scrap": 4, &"worm_cores": 1, &"completed_relays": 1},
			{&"run_scrap": 7, &"worm_cores": 2, &"completed_relays": 2},
		)
	)
	_add(
		cases,
		"resource and relay gains produce positive presentation deltas",
		int(deltas[&"scrap"]) == 3 and int(deltas[&"cores"]) == 1 and int(deltas[&"relays"]) == 1,
	)
	deltas = (
		FieldHUDScript
		. state_reward_deltas(
			{&"run_scrap": 7, &"worm_cores": 2, &"completed_relays": 2},
			{&"run_scrap": 3, &"worm_cores": 1, &"completed_relays": 1},
		)
	)
	_add(
		cases,
		"resource spending never masquerades as a reward pulse",
		int(deltas[&"scrap"]) == 0 and int(deltas[&"cores"]) == 0 and int(deltas[&"relays"]) == 0,
	)
	_add(
		cases,
		"HUD micro-motion is capped at 180 milliseconds",
		FieldHUDScript.HUD_PULSE_SECONDS == 0.18
	)
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
