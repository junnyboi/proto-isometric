extends RefCounted

const ResponsiveViewportScript: GDScript = preload("res://scripts/responsive_viewport.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_title_layout(cases, Vector2(390.0, 844.0), true)
	_test_title_layout(cases, Vector2(844.0, 390.0), false)
	_test_title_layout(cases, Vector2(1280.0, 720.0), false)
	var portrait_zoom: float = ResponsiveViewportScript.camera_zoom(Vector2(390.0, 844.0))
	var compact_landscape_zoom: float = ResponsiveViewportScript.camera_zoom(Vector2(844.0, 390.0))
	var landscape_zoom: float = ResponsiveViewportScript.camera_zoom(Vector2(1280.0, 720.0))
	var large_landscape_zoom: float = ResponsiveViewportScript.camera_zoom(Vector2(1920.0, 1080.0))
	_add(
		cases, "portrait camera zooms out for horizontal play space", portrait_zoom < landscape_zoom
	)
	_add(
		cases,
		"portrait camera is exactly twice the previous minimum",
		is_equal_approx(portrait_zoom, 1.3)
	)
	_add(
		cases,
		"compact landscape preserves mobile overview",
		is_equal_approx(
			compact_landscape_zoom,
			(
				ResponsiveViewportScript.MIN_CAMERA_ZOOM
				* ResponsiveViewportScript.GAMEPLAY_CAMERA_SCALE
			),
		),
	)
	_add(
		cases,
		"reference desktop landscape tightens framing",
		is_equal_approx(
			landscape_zoom,
			(
				ResponsiveViewportScript.DESKTOP_LANDSCAPE_CAMERA_ZOOM
				* ResponsiveViewportScript.GAMEPLAY_CAMERA_SCALE
			),
		),
	)
	_add(
		cases,
		"large desktop keeps the same bounded world envelope",
		is_equal_approx(large_landscape_zoom, landscape_zoom * 1.5),
	)
	return cases


static func _test_title_layout(
	cases: Array[Dictionary],
	viewport: Vector2,
	portrait: bool,
) -> void:
	var layout: Dictionary = ResponsiveViewportScript.title_layout(viewport)
	var bounds: Rect2 = Rect2(Vector2.ZERO, viewport)
	var label: String = "%dx%d" % [roundi(viewport.x), roundi(viewport.y)]
	_add(cases, "%s title orientation is native" % label, bool(layout[&"portrait"]) == portrait)
	_add(
		cases,
		"%s Signal-First canvas remains visible" % label,
		bounds.encloses(layout[&"canvas_rect"] as Rect2),
	)
	_add(
		cases,
		"%s title briefing remains visible" % label,
		bounds.encloses(layout[&"title_rect"] as Rect2),
	)
	_add(
		cases,
		"%s deployment CTA remains visible" % label,
		bounds.encloses(layout[&"cta_rect"] as Rect2),
	)
	_add(
		cases,
		"%s controls remain visible" % label,
		bounds.encloses(layout[&"controls_rect"] as Rect2),
	)
	_add(
		cases,
		"%s field focus remains visible" % label,
		bounds.has_point(layout[&"field_origin"] as Vector2),
	)


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
