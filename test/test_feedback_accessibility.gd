extends RefCounted

const CameraImpulseMixerScript: GDScript = preload("res://scripts/camera_impulse_mixer.gd")
const HapticRouterScript: GDScript = preload("res://scripts/haptic_router.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var camera: Camera2D = Camera2D.new()
	var mixer: RefCounted = CameraImpulseMixerScript.new() as RefCounted
	mixer.call("bind_camera", camera)
	mixer.call("set_intensity", 0.5)
	_add(
		cases,
		"low camera intensity scales an accepted impulse",
		(
			bool(mixer.call("submit", 0.2, 10.0, Vector2.RIGHT, 1))
			and camera.offset.length() <= 5.5
			and float(mixer.call("get_metrics")[&"intensity"]) == 0.5
		),
	)
	mixer.call("set_intensity", 0.0)
	var camera_before: Dictionary = mixer.call("get_metrics") as Dictionary
	_add(
		cases,
		"zero camera intensity clears work and rejects dispatch",
		(
			not bool(mixer.call("submit", 0.2, 10.0, Vector2.RIGHT, 2))
			and camera.offset == Vector2.ZERO
			and int(mixer.call("get_metrics")[&"submitted"]) == int(camera_before[&"submitted"])
		),
	)
	var haptics: RefCounted = HapticRouterScript.new() as RefCounted
	var profile: Dictionary = {
		&"haptic_duration_seconds": 0.05,
		&"haptic_weak": 0.8,
		&"haptic_strong": 1.0,
	}
	haptics.call("set_intensity", 0.5)
	var accepted: bool = bool(haptics.call("pulse", profile))
	var haptic_metrics: Dictionary = haptics.call("get_metrics") as Dictionary
	_add(
		cases,
		"low haptic intensity scales both motor amplitudes",
		(
			accepted
			and is_equal_approx(float(haptic_metrics[&"last_weak"]), 0.4)
			and is_equal_approx(float(haptic_metrics[&"last_strong"]), 0.5)
		),
	)
	haptics.call("set_intensity", 0.0)
	var requests_before: int = int(haptics.call("get_metrics")[&"requests"])
	_add(
		cases,
		"zero haptic intensity performs no dispatch work",
		(
			not bool(haptics.call("pulse", profile))
			and int(haptics.call("get_metrics")[&"requests"]) == requests_before
		),
	)
	camera.free()
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
