extends RefCounted

const DESIGN_SIZE: Vector2 = Vector2(1280.0, 720.0)
const PORTRAIT_DESIGN_SIZE: Vector2 = Vector2(720.0, 1280.0)
const TITLE_PANEL_SIZE: Vector2 = Vector2(560.0, 470.0)
const PORTRAIT_TITLE_PANEL_SIZE: Vector2 = Vector2(640.0, 1010.0)
const STATUS_DESIGN_SIZE: Vector2 = Vector2(1216.0, 56.0)
const BASE_CAMERA_ZOOM: float = 1.2
const DESKTOP_LANDSCAPE_CAMERA_ZOOM: float = 1.4
const DESKTOP_LANDSCAPE_MAX_ZOOM: float = 2.2
const MIN_CAMERA_ZOOM: float = 0.65
const GAMEPLAY_CAMERA_SCALE: float = 2.0
const DESKTOP_LANDSCAPE_MIN_SIZE: Vector2 = Vector2(1000.0, 600.0)


static func title_layout(raw_size: Vector2) -> Dictionary:
	var viewport: Vector2 = Vector2(maxf(raw_size.x, 320.0), maxf(raw_size.y, 320.0))
	var portrait: bool = viewport.y > viewport.x
	var design_size: Vector2 = PORTRAIT_DESIGN_SIZE if portrait else DESIGN_SIZE
	var scale_value: float = minf(viewport.x / design_size.x, viewport.y / design_size.y)
	var canvas_size: Vector2 = design_size * scale_value
	var canvas_position: Vector2 = (viewport - canvas_size) * 0.5
	var title_rect: Rect2 = (
		Rect2(Vector2(40.0, 58.0), PORTRAIT_TITLE_PANEL_SIZE)
		if portrait
		else Rect2(Vector2(62.0, 132.0), TITLE_PANEL_SIZE)
	)
	var controls_rect: Rect2 = (
		Rect2(Vector2(40.0, 1080.0), Vector2(640.0, 160.0))
		if portrait
		else Rect2(Vector2(32.0, 644.0), STATUS_DESIGN_SIZE)
	)
	return {
		&"viewport": viewport,
		&"portrait": portrait,
		&"design_size": design_size,
		&"canvas_position": canvas_position,
		&"canvas_scale": scale_value,
		&"canvas_rect": Rect2(canvas_position, canvas_size),
		&"title_rect": _scaled_rect(title_rect, canvas_position, scale_value),
		&"controls_rect": _scaled_rect(controls_rect, canvas_position, scale_value),
		&"cta_rect":
		_scaled_rect(
			(
				Rect2(Vector2(40.0, 938.0), Vector2(640.0, 128.0))
				if portrait
				else Rect2(Vector2(62.0, 502.0), Vector2(475.0, 84.0))
			),
			canvas_position,
			scale_value,
		),
		&"field_origin":
		(
			canvas_position
			+ (Vector2(360.0, 590.0) if portrait else Vector2(960.0, 395.0)) * scale_value
		),
		&"panel_position": canvas_position + title_rect.position * scale_value,
		&"panel_scale": scale_value,
		&"status_rect": _scaled_rect(controls_rect, canvas_position, scale_value),
		&"status_font_size": maxi(10, roundi(14.0 * scale_value)),
	}


static func camera_zoom(raw_size: Vector2) -> float:
	var viewport: Vector2 = Vector2(maxf(raw_size.x, 320.0), maxf(raw_size.y, 320.0))
	if (
		viewport.x >= DESKTOP_LANDSCAPE_MIN_SIZE.x
		and viewport.y >= DESKTOP_LANDSCAPE_MIN_SIZE.y
		and viewport.x >= viewport.y
	):
		var desktop_scale: float = maxf(viewport.x / DESIGN_SIZE.x, viewport.y / DESIGN_SIZE.y)
		return minf(
			DESKTOP_LANDSCAPE_CAMERA_ZOOM * desktop_scale * GAMEPLAY_CAMERA_SCALE,
			DESKTOP_LANDSCAPE_MAX_ZOOM,
		)
	var shortest_side: float = minf(viewport.x, viewport.y)
	return (
		GAMEPLAY_CAMERA_SCALE
		* clampf(
			BASE_CAMERA_ZOOM * shortest_side / DESIGN_SIZE.y,
			MIN_CAMERA_ZOOM,
			BASE_CAMERA_ZOOM,
		)
	)


static func _scaled_rect(rect: Rect2, offset: Vector2, scale_value: float) -> Rect2:
	return Rect2(offset + rect.position * scale_value, rect.size * scale_value)
