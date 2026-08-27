extends RefCounted

const SafeAreaScript: GDScript = preload("res://scripts/platform_safe_area.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")

const LAYOUT_WIDE_TERRAIN: StringName = &"wide_terrain"
const LAYOUT_WIDE_OBJECT: StringName = &"wide_object"
const LAYOUT_COMPACT_SIDE: StringName = &"compact_side"
const LAYOUT_PORTRAIT_SHEET: StringName = &"portrait_sheet"
const LAYOUT_PORTRAIT_COMPACT: StringName = &"portrait_compact"
const MIN_WORLD_APERTURE: float = 320.0

static func layout_for(
	viewport_size: Vector2,
	safe_insets: Dictionary = {},
	left_handed: bool = false,
	ui_scale: float = 1.0,
	mobile: bool = false,
	profile: StringName = &"terrain",
	row_count: int = OptionScript.MAX_OPTIONS,
) -> Dictionary:
	var safe_result: Dictionary = SafeAreaScript.resolve(viewport_size, safe_insets, ui_scale)
	var viewport: Vector2 = safe_result[&"viewport"] as Vector2
	var safe: Rect2 = safe_result[&"bounds"] as Rect2
	var scale_value: float = float(safe_result[&"ui_scale"])
	var row_height: float = maxf(44.0, 68.0 * scale_value)
	var portrait: bool = viewport.y > viewport.x
	var mode: StringName = LAYOUT_COMPACT_SIDE
	var popup: Rect2
	var inspection: Rect2 = Rect2()
	var aperture: Rect2
	if portrait:
		mode = (
			LAYOUT_PORTRAIT_COMPACT
			if safe.size.x < 360.0 or safe.size.y < 620.0
			else LAYOUT_PORTRAIT_SHEET
		)
		var fraction: float = 0.68 if mode == LAYOUT_PORTRAIT_COMPACT else 0.60
		var sheet_height: float = minf(safe.size.y * fraction, 720.0 * scale_value)
		popup = Rect2(
			Vector2(safe.position.x, safe.end.y - sheet_height),
			Vector2(safe.size.x, sheet_height),
		)
		aperture = Rect2(safe.position, Vector2(safe.size.x, popup.position.y - safe.position.y))
	else:
		var left_width: float = minf(
			clampf(safe.size.x * 0.29, 360.0, 480.0) * scale_value, safe.size.x
		)
		var right_minimum: float = 340.0 if profile == &"object" else 300.0
		var right_maximum: float = 460.0 if profile == &"object" else 420.0
		var right_width: float = (
			clampf(safe.size.x * 0.25, right_minimum, right_maximum) * scale_value
		)
		var gutter: float = 20.0 * scale_value
		var wide: bool = (
			not mobile
			and safe.size.x >= 1180.0
			and safe.size.y >= 650.0
			and safe.size.x - left_width - right_width - gutter * 2.0 >= MIN_WORLD_APERTURE
		)
		if wide:
			mode = LAYOUT_WIDE_OBJECT if profile == &"object" else LAYOUT_WIDE_TERRAIN
			popup = Rect2(safe.position, Vector2(left_width, safe.size.y))
			inspection = Rect2(
				Vector2(safe.end.x - right_width, safe.position.y),
				Vector2(right_width, safe.size.y),
			)
			aperture = Rect2(
				Vector2(popup.end.x + gutter, safe.position.y),
				Vector2(inspection.position.x - popup.end.x - gutter * 2.0, safe.size.y),
			)
		else:
			var width: float = minf(
				clampf(safe.size.x * 0.42, 320.0, 438.0) * scale_value, safe.size.x
			)
			var x: float = safe.end.x - width if mobile and left_handed else safe.position.x
			popup = Rect2(Vector2(x, safe.position.y), Vector2(width, safe.size.y))
			aperture = Rect2(safe.position, safe.size)
	var header: float = minf(190.0 * scale_value, popup.size.y * 0.42)
	var footer: float = minf(58.0 * scale_value, popup.size.y * 0.20)
	var rows: Rect2 = Rect2(
		popup.position + Vector2(0.0, header),
		Vector2(popup.size.x, maxf(popup.size.y - header - footer, 44.0)),
	)
	var panels: Array[Rect2] = [popup]
	if inspection.size.x > 0.0:
		panels.append(inspection)
	var toast_width: float = minf(maxf(safe.size.x * 0.34, 260.0), 460.0 * scale_value)
	var toast: Rect2 = Rect2(
		Vector2(safe.get_center().x - toast_width * 0.5, safe.position.y + 12.0),
		Vector2(toast_width, 96.0 * scale_value),
	)
	return {
		&"viewport": viewport,
		&"safe_bounds": safe,
		&"popup": popup,
		&"inspection": inspection,
		&"panel_rects": panels,
		&"world_aperture": aperture,
		&"row_viewport": rows,
		&"toast": toast,
		&"row_height": row_height,
		&"scroll_required": max(row_count, 0) * row_height > rows.size.y,
		&"left_handed": left_handed,
		&"ui_scale": scale_value,
		&"mobile": mobile,
		&"mode": mode,
	}
