extends RefCounted

const AtmosphereScript: GDScript = preload("res://scripts/desert_atmosphere.gd")
const OutpostInterfaceScript: GDScript = preload("res://scripts/outpost_interface.gd")
const RunTerminalFlowScript: GDScript = preload("res://scripts/run_terminal_flow.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_add(
		cases,
		"atmosphere maps every shipped biome surface to a distinct profile",
		(
			AtmosphereScript.profile_for_surface(&"sand") == &"sand"
			and AtmosphereScript.profile_for_surface(&"mud") == &"wetland"
			and AtmosphereScript.profile_for_surface(&"blue_ice") == &"frozen"
			and AtmosphereScript.profile_for_surface(&"lava") == &"volcanic"
		),
	)
	var atmosphere: Node2D = AtmosphereScript.new() as Node2D
	var maximum: float = 0.0
	for _index: int in range(120):
		atmosphere.call("advance", 0.05)
		maximum = maxf(maximum, float(atmosphere.call("get_punctuation_strength")))
	_add(cases, "ambient punctuation breathes without spawning new nodes", maximum > 0.9)
	_add(
		cases,
		"ambient punctuation keeps the fixed 96-mark budget",
		int(atmosphere.call("get_particle_count")) == 96
	)
	_add(
		cases,
		"terminal reward hierarchy settles within 240 milliseconds",
		RunTerminalFlowScript.SUMMARY_REVEAL_SECONDS == 0.24,
	)
	_add(
		cases,
		"outpost response settles within 160 milliseconds",
		OutpostInterfaceScript.INTERACTION_PULSE_SECONDS == 0.16,
	)
	atmosphere.free()
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
