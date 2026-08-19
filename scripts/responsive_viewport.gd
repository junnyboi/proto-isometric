extends RefCounted

const DESIGN_SIZE: Vector2 = Vector2(1280.0, 720.0)
const TITLE_PANEL_SIZE: Vector2 = Vector2(540.0, 530.0)
const STATUS_DESIGN_SIZE: Vector2 = Vector2(1100.0, 48.0)
const BASE_CAMERA_ZOOM: float = 1.2
const MIN_CAMERA_ZOOM: float = 0.65


static func title_layout(raw_size: Vector2) -> Dictionary:
	var viewport: Vector2 = Vector2(maxf(raw_size.x, 320.0), maxf(raw_size.y, 320.0))
	var portrait: bool = viewport.y > viewport.x
	if portrait:
		return _portrait_title_layout(viewport)
	return _landscape_title_layout(viewport)


static func camera_zoom(raw_size: Vector2) -> float:
	var shortest_side: float = maxf(minf(raw_size.x, raw_size.y), 320.0)
	return clampf(
		BASE_CAMERA_ZOOM * shortest_side / DESIGN_SIZE.y, MIN_CAMERA_ZOOM, BASE_CAMERA_ZOOM
	)


static func _portrait_title_layout(viewport: Vector2) -> Dictionary:
	var horizontal_scale: float = (viewport.x - 32.0) / TITLE_PANEL_SIZE.x
	var vertical_scale: float = viewport.y * 0.44 / TITLE_PANEL_SIZE.y
	var panel_scale: float = minf(1.0, minf(horizontal_scale, vertical_scale))
	var panel_size: Vector2 = TITLE_PANEL_SIZE * panel_scale
	var panel_position: Vector2 = Vector2(
		(viewport.x - panel_size.x) * 0.5,
		maxf(62.0, viewport.y * 0.07),
	)
	var field_scale: float = clampf(viewport.x / 560.0, 0.58, 0.9)
	var field_origin: Vector2 = Vector2(
		viewport.x * 0.5,
		maxf(panel_position.y + panel_size.y + 72.0, viewport.y * 0.66),
	)
	return {
		&"viewport": viewport,
		&"portrait": true,
		&"panel_position": panel_position,
		&"panel_scale": panel_scale,
		&"status_rect": Rect2(Vector2(16.0, viewport.y - 42.0), Vector2(viewport.x - 32.0, 28.0)),
		&"status_font_size": 10,
		&"field_origin": field_origin,
		&"half_tile": Vector2(38.0, 19.0) * field_scale,
		&"accent_offset": Vector2.ZERO,
		&"accent_scale": 1.0,
	}


static func _landscape_title_layout(viewport: Vector2) -> Dictionary:
	var panel_scale: float = minf(
		1.0,
		minf(
			(viewport.x * 0.5 - 32.0) / TITLE_PANEL_SIZE.x, (viewport.y - 20.0) / TITLE_PANEL_SIZE.y
		),
	)
	var panel_size: Vector2 = TITLE_PANEL_SIZE * panel_scale
	var panel_position: Vector2 = Vector2(
		maxf(16.0, viewport.x * 0.06),
		maxf(8.0, (viewport.y - panel_size.y) * 0.5),
	)
	var scene_scale: float = minf(viewport.x / DESIGN_SIZE.x, viewport.y / DESIGN_SIZE.y)
	var compact: bool = viewport.y < 500.0
	var status_rect: Rect2 = (
		Rect2(
			Vector2(viewport.x * 0.62, viewport.y - 34.0),
			Vector2(viewport.x * 0.35, 24.0),
		)
		if compact
		else Rect2(
			Vector2(panel_position.x, viewport.y - 68.0),
			Vector2(minf(STATUS_DESIGN_SIZE.x, viewport.x - panel_position.x - 16.0), 48.0),
		)
	)
	return {
		&"viewport": viewport,
		&"portrait": false,
		&"panel_position": panel_position,
		&"panel_scale": panel_scale,
		&"status_rect": status_rect,
		&"status_font_size": maxi(9, roundi(15.0 * panel_scale)),
		&"field_origin": Vector2(viewport.x * 0.72, viewport.y * 0.24),
		&"half_tile": Vector2(38.0, 19.0) * scene_scale,
		&"accent_offset": panel_position - Vector2(88.0, 92.0) * panel_scale,
		&"accent_scale": panel_scale,
	}
