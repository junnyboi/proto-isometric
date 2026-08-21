extends RefCounted

const IsometricControlsScript: GDScript = preload("res://scripts/isometric_controls.gd")
const MobileControlsScript: GDScript = preload("res://scripts/mobile_controls.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_controller_response(cases)
	_test_mobile_response(cases)
	return cases


static func _test_controller_response(cases: Array[Dictionary]) -> void:
	var inside_dead_zone: Vector2 = IsometricControlsScript.shape_controller_vector(
		Vector2(0.1, 0.0)
	)
	var low: Vector2 = IsometricControlsScript.shape_controller_vector(Vector2(0.25, 0.0))
	var medium: Vector2 = IsometricControlsScript.shape_controller_vector(Vector2(0.6, 0.0))
	var full: Vector2 = IsometricControlsScript.shape_controller_vector(Vector2.RIGHT)
	var diagonal: Vector2 = IsometricControlsScript.shape_controller_vector(Vector2(0.7, -0.7))
	_add(cases, "controller radial dead zone rejects stick drift", inside_dead_zone == Vector2.ZERO)
	_add(
		cases,
		"controller center response begins immediately outside dead zone",
		low.length() > 0.05,
	)
	_add(
		cases,
		"controller response is monotonic and reaches full speed",
		(
			low.length() < medium.length()
			and medium.length() < full.length()
			and is_equal_approx(full.length(), 1.0)
		),
	)
	_add(
		cases,
		"controller radial shaping preserves diagonal intent",
		diagonal.x > 0.0 and diagonal.y < 0.0 and absf(diagonal.length() - 0.98) < 0.03,
	)
	_add(
		cases,
		"controller output remains bounded under oversized raw input",
		IsometricControlsScript.shape_controller_vector(Vector2(2.0, -2.0)).length() <= 1.0,
	)


static func _test_mobile_response(cases: Array[Dictionary]) -> void:
	var controls: CanvasLayer = MobileControlsScript.new() as CanvasLayer
	controls.call("_build_joystick")
	controls.call("_build_smash_button")
	controls.call("force_mobile", true)
	_add(
		cases,
		"mobile feel layout accepts reference viewport",
		bool(controls.call("apply_layout", Vector2(1280.0, 720.0)))
	)
	var button: Button = controls.call("get_smash_button") as Button
	_add(
		cases,
		"mobile Smash activates on touch-down",
		button.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS,
	)
	_add(
		cases,
		"mobile Smash scales around its center",
		button.pivot_offset.is_equal_approx(button.size * 0.5),
	)
	var origin: Vector2 = Vector2(220.0, 600.0)
	_add(
		cases,
		"right-handed joystick owns the left thumb zone",
		bool(controls.call("begin_touch", 1, origin))
	)
	var low: Vector2 = controls.call("drag_touch", 1, origin + Vector2(20.0, 0.0)) as Vector2
	_add(
		cases,
		"mobile joystick responds outside its compact dead zone",
		low.length() > 0.05 and low.length() < 0.25,
	)
	controls.call("drag_touch", 1, origin + Vector2(75.0, 0.0))
	_add(
		cases,
		"mobile outer ring enters run with hysteresis",
		bool(controls.call("is_run_intended"))
	)
	controls.call("drag_touch", 1, origin + Vector2(50.0, 0.0))
	_add(
		cases,
		"mobile run exits before the stick reaches center",
		not bool(controls.call("is_run_intended"))
	)
	controls.call("drag_touch", 1, origin + Vector2(8.0, 0.0))
	_add(
		cases,
		"mobile center dead zone clears drive and stale run intent",
		(
			(controls.call("get_drive_vector") as Vector2) == Vector2.ZERO
			and not bool(controls.call("is_run_intended"))
		),
	)
	controls.call("end_touch", 1)
	_add(
		cases,
		"right-handed joystick rejects the Smash-side thumb zone",
		not bool(controls.call("begin_touch", 2, Vector2(1080.0, 600.0))),
	)
	controls.call("_apply_preferences", {&"left_handed": true, &"haptic_intensity": 1.0})
	controls.call("apply_layout", Vector2(1280.0, 720.0))
	_add(
		cases,
		"left-handed mode mirrors joystick ownership to the right thumb zone",
		bool(controls.call("begin_touch", 3, Vector2(1080.0, 600.0))),
	)
	controls.call("end_touch", 3)
	var before: int = int(controls.get("_last_smash_ack_msec"))
	controls.call("trigger_smash")
	var first: int = int(controls.get("_last_smash_ack_msec"))
	controls.call("trigger_smash")
	_add(
		cases,
		"mobile Smash acknowledgement is short and cooldown bounded",
		first >= before and int(controls.get("_last_smash_ack_msec")) == first,
	)
	controls.free()


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
