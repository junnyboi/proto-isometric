extends RefCounted

const COMPACT_PORTRAIT_MARGIN: float = 12.0
const LANDSCAPE_DESIGN_MARGIN: float = 18.0
const MIN_UI_SCALE: float = 0.85
const MAX_UI_SCALE: float = 1.25
const EDGE_KEYS: Array[StringName] = [&"left", &"top", &"right", &"bottom"]


static func resolve(
	viewport_size: Vector2,
	injected_insets: Dictionary = {},
	ui_scale: float = 1.0,
) -> Dictionary:
	var viewport: Vector2 = Vector2(maxf(viewport_size.x, 0.0), maxf(viewport_size.y, 0.0))
	var platform: Dictionary = clamp_insets(injected_insets, viewport)
	var margin: float = design_margin_for(viewport)
	var requested: Dictionary = {
		&"left": maxf(float(platform[&"left"]), margin),
		&"top": maxf(float(platform[&"top"]), margin),
		&"right": maxf(float(platform[&"right"]), margin),
		&"bottom": maxf(float(platform[&"bottom"]), margin),
	}
	var effective: Dictionary = clamp_insets(requested, viewport)
	var position := Vector2(float(effective[&"left"]), float(effective[&"top"]))
	var size := Vector2(
		maxf(viewport.x - position.x - float(effective[&"right"]), 0.0),
		maxf(viewport.y - position.y - float(effective[&"bottom"]), 0.0),
	)
	return {
		&"viewport": viewport,
		&"platform_insets": platform,
		&"insets": effective,
		&"bounds": Rect2(position, size),
		&"design_margin": margin,
		&"ui_scale": clampf(ui_scale, MIN_UI_SCALE, MAX_UI_SCALE),
	}


static func resolve_for_viewport(
	viewport: Viewport,
	injected_insets: Dictionary = {},
	ui_scale: float = 1.0,
) -> Dictionary:
	if viewport == null:
		return resolve(Vector2.ZERO, injected_insets, ui_scale)
	return resolve(viewport.get_visible_rect().size, injected_insets, ui_scale)


static func resolve_native(viewport: Viewport, ui_scale: float = 1.0) -> Dictionary:
	if viewport == null:
		return resolve(Vector2.ZERO, {}, ui_scale)
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	return resolve(viewport_size, native_insets(viewport_size), ui_scale)


static func native_insets(viewport_size: Vector2) -> Dictionary:
	var empty: Dictionary = zero_insets()
	var display_size: Vector2 = DisplayServer.screen_get_size()
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	if (
		display_size.x <= 0.0
		or display_size.y <= 0.0
		or viewport_size.x <= 0.0
		or viewport_size.y <= 0.0
		or safe_area.size.x <= 0
		or safe_area.size.y <= 0
	):
		return empty
	var scale := Vector2(viewport_size.x / display_size.x, viewport_size.y / display_size.y)
	var safe := Rect2(Vector2(safe_area.position) * scale, Vector2(safe_area.size) * scale)
	var visible := Rect2(Vector2.ZERO, viewport_size)
	safe = safe.intersection(visible)
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return empty
	return clamp_insets(
		{
			&"left": safe.position.x,
			&"top": safe.position.y,
			&"right": viewport_size.x - safe.end.x,
			&"bottom": viewport_size.y - safe.end.y,
		},
		viewport_size,
	)


static func clamp_insets(insets: Dictionary, viewport_size: Vector2) -> Dictionary:
	var viewport := Vector2(maxf(viewport_size.x, 0.0), maxf(viewport_size.y, 0.0))
	var result: Dictionary = zero_insets()
	for key: StringName in EDGE_KEYS:
		var limit: float = viewport.x if key in [&"left", &"right"] else viewport.y
		result[key] = clampf(_finite_number(insets.get(key, 0.0)), 0.0, limit)
	_fit_pair(result, &"left", &"right", viewport.x)
	_fit_pair(result, &"top", &"bottom", viewport.y)
	return result


static func design_margin_for(viewport_size: Vector2) -> float:
	if viewport_size.y > viewport_size.x and viewport_size.x < 600.0:
		return COMPACT_PORTRAIT_MARGIN
	return LANDSCAPE_DESIGN_MARGIN


static func zero_insets() -> Dictionary:
	return {&"left": 0.0, &"top": 0.0, &"right": 0.0, &"bottom": 0.0}


static func _fit_pair(
	values: Dictionary, first: StringName, second: StringName, limit: float
) -> void:
	var total: float = float(values[first]) + float(values[second])
	if total <= limit or total <= 0.0:
		return
	var ratio: float = limit / total
	values[first] = float(values[first]) * ratio
	values[second] = limit - float(values[first])


static func _finite_number(value: Variant) -> float:
	if not value is int and not value is float:
		return 0.0
	var number: float = float(value)
	return number if is_finite(number) else 0.0
