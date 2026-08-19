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
	_add(cases, "portrait camera zoom stays readable", portrait_zoom >= 0.649)
	_add(
		cases,
		"compact landscape preserves mobile overview",
		is_equal_approx(compact_landscape_zoom, ResponsiveViewportScript.MIN_CAMERA_ZOOM)
	)
	_add(
		cases,
		"reference desktop landscape tightens framing",
		is_equal_approx(landscape_zoom, ResponsiveViewportScript.DESKTOP_LANDSCAPE_CAMERA_ZOOM)
	)
	_add(
		cases,
		"large desktop keeps the same bounded world envelope",
		is_equal_approx(large_landscape_zoom, landscape_zoom * 1.5)
	)
	return cases


static func _test_title_layout(
	cases: Array[Dictionary],
	viewport: Vector2,
	portrait: bool,
) -> void:
	var layout: Dictionary = ResponsiveViewportScript.title_layout(viewport)
	var panel_size: Vector2 = (
		ResponsiveViewportScript.TITLE_PANEL_SIZE * float(layout[&"panel_scale"])
	)
	var panel: Rect2 = Rect2(layout[&"panel_position"] as Vector2, panel_size)
	var bounds: Rect2 = Rect2(Vector2.ZERO, viewport)
	var label: String = "%dx%d" % [roundi(viewport.x), roundi(viewport.y)]
	_add(cases, "%s title orientation is native" % label, bool(layout[&"portrait"]) == portrait)
	_add(cases, "%s title panel remains visible" % label, bounds.encloses(panel))
	_add(
		cases,
		"%s isometric field origin remains visible" % label,
		bounds.has_point(layout[&"field_origin"] as Vector2),
	)
	_add(
		cases,
		"%s status bar remains visible" % label,
		bounds.encloses(layout[&"status_rect"] as Rect2)
	)


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
