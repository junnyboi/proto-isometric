extends RefCounted

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
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
