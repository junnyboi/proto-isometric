extends RefCounted

const MobileControlsScript: GDScript = preload("res://scripts/mobile_controls.gd")
const ResponsiveCameraScript: GDScript = preload("res://scripts/responsive_camera.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var camera: Camera2D = ResponsiveCameraScript.new() as Camera2D
	_add(
		cases,
		"camera zoom begins at one hundred percent",
		is_equal_approx(float(camera.call("get_user_zoom")), 1.0)
	)
	_add(
		cases,
		"camera zoom in advances ten percent",
		(
			bool(camera.call("adjust_user_zoom", 1))
			and is_equal_approx(float(camera.call("get_user_zoom")), 1.1)
		)
	)
	camera.call("adjust_user_zoom", 20)
	_add(
		cases,
		"camera zoom in is capped at one hundred thirty percent",
		(
			is_equal_approx(float(camera.call("get_user_zoom")), 1.3)
			and not bool(camera.call("adjust_user_zoom", 1))
		)
	)
	var wheel_down: InputEventMouseButton = InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	camera.call("_input", wheel_down)
	_add(
		cases,
		"mouse wheel down zooms out ten percent",
		is_equal_approx(float(camera.call("get_user_zoom")), 1.2)
	)
	camera.call("adjust_user_zoom", -20)
	_add(
		cases,
		"camera zoom out is capped at seventy percent",
		(
			is_equal_approx(float(camera.call("get_user_zoom")), 0.7)
			and not bool(camera.call("adjust_user_zoom", -1))
		)
	)
	camera.call("_build_zoom_controls")
	var panel: PanelContainer = camera.get_node("CameraZoomLayer/CameraZoomPanel") as PanelContainer
	var zoom_out: Button = panel.get_node("ZoomControls/ZoomOutButton") as Button
	var zoom_in: Button = panel.get_node("ZoomControls/ZoomInButton") as Button
	var label: Label = panel.get_node("ZoomControls/ZoomLabel") as Label
	_add(
		cases,
		"camera zoom controls are centered above the bottom edge",
		is_equal_approx(panel.anchor_left, 0.5) and is_equal_approx(panel.anchor_top, 1.0)
	)
	_add(
		cases,
		"camera zoom buttons meet touch target size",
		(
			zoom_out.custom_minimum_size.x >= 44.0
			and zoom_out.custom_minimum_size.y >= 44.0
			and zoom_in.custom_minimum_size.x >= 44.0
			and zoom_in.custom_minimum_size.y >= 44.0
		)
	)
	_add(
		cases,
		"camera zoom label reports the active percentage",
		label.text == "70%" and zoom_out.disabled and not zoom_in.disabled
	)
	zoom_in.emit_signal("pressed")
	_add(
		cases,
		"on-screen plus button zooms in",
		is_equal_approx(float(camera.call("get_user_zoom")), 0.8) and label.text == "80%"
	)
	camera.free()
	_test_pinch_zoom(cases)
	return cases


static func _test_pinch_zoom(cases: Array[Dictionary]) -> void:
	var camera: Camera2D = ResponsiveCameraScript.new() as Camera2D
	var mobile_controls: CanvasLayer = MobileControlsScript.new() as CanvasLayer
	mobile_controls.call("force_mobile", true)
	camera.call("bind_mobile_controls", mobile_controls)
	camera.call("_input", _touch(3, Vector2(100.0, 120.0), true))
	camera.call("_input", _touch(8, Vector2(200.0, 120.0), true))
	_add(
		cases,
		"two separated touches begin mobile pinch zoom",
		bool(camera.call("is_pinching")) and bool(mobile_controls.call("is_pinch_active"))
	)
	_add(
		cases,
		"pinch mode suppresses floating joystick capture",
		not bool(mobile_controls.call("begin_touch", 12, Vector2(80.0, 80.0)))
	)
	camera.call("_input", _drag(8, Vector2(225.0, 120.0)))
	_add(
		cases,
		"pinch spread applies smooth proportional zoom",
		is_equal_approx(float(camera.call("get_user_zoom")), 1.25)
	)
	camera.call("_input", _drag(8, Vector2(300.0, 120.0)))
	_add(
		cases,
		"pinch zoom respects the one hundred thirty percent cap",
		is_equal_approx(float(camera.call("get_user_zoom")), 1.3)
	)
	camera.call("_input", _touch(3, Vector2(100.0, 120.0), false))
	_add(
		cases,
		"releasing either pinch finger ends gesture arbitration",
		not bool(camera.call("is_pinching")) and not bool(mobile_controls.call("is_pinch_active"))
	)
	var snapshot: Dictionary = camera.call("get_pinch_snapshot") as Dictionary
	_add(
		cases,
		"pinch release retains only still-active touch state",
		not bool(snapshot[&"active"]) and int(snapshot[&"touch_count"]) == 1
	)
	camera.free()
	mobile_controls.free()


static func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


static func _drag(index: int, position: Vector2) -> InputEventScreenDrag:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = position
	return event


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
