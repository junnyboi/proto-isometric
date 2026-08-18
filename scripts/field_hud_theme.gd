extends Resource

const DRIVE_DESIGN_SIZE: Vector2 = Vector2(430.0, 294.0)
const OUTPOST_DESIGN_SIZE: Vector2 = Vector2(386.0, 252.0)
const CHARGE_DESIGN_SIZE: Vector2 = Vector2(150.0, 12.0)
const SMASH_DESIGN_SIZE: Vector2 = Vector2(154.0, 154.0)
const LAYOUT_KEYS: Array[StringName] = [
	&"viewport",
	&"safe_bounds",
	&"drive_panel",
	&"drive_scale",
	&"outpost_panel",
	&"outpost_scale",
	&"mobile_charge",
	&"mobile_charge_scale",
	&"smash_button",
]

@export var safe_inset_left: float = 28.0
@export var safe_inset_top: float = 28.0
@export var safe_inset_right: float = 28.0
@export var safe_inset_bottom: float = 28.0
@export var panel_gap: float = 22.0
@export var mobile_gap: float = 16.0
@export var landscape_breakpoint: float = 900.0


func make_layout(viewport_size: Vector2, mobile: bool) -> Dictionary:
	var viewport: Vector2 = Vector2(maxf(viewport_size.x, 320.0), maxf(viewport_size.y, 320.0))
	var safe: Rect2 = _safe_bounds(viewport)
	var landscape: bool = safe.size.x >= safe.size.y or safe.size.x >= landscape_breakpoint
	var panel_scales: Vector2 = _panel_scales(safe, landscape, mobile)
	var drive_rect: Rect2 = Rect2(safe.position, DRIVE_DESIGN_SIZE * panel_scales.x)
	var outpost_position: Vector2 = _outpost_position(safe, drive_rect, panel_scales.y, landscape)
	var outpost_rect: Rect2 = Rect2(outpost_position, OUTPOST_DESIGN_SIZE * panel_scales.y)
	var smash_rect: Rect2 = _smash_rect(safe, mobile)
	var charge_scale: float = minf(1.0, safe.size.x / CHARGE_DESIGN_SIZE.x)
	var charge_size: Vector2 = CHARGE_DESIGN_SIZE * charge_scale
	var charge_x: float = smash_rect.position.x + (smash_rect.size.x - charge_size.x) * 0.5
	var charge_position: Vector2 = Vector2(
		clampf(charge_x, safe.position.x, safe.end.x - charge_size.x),
		smash_rect.position.y - mobile_gap - charge_size.y,
	)
	return {
		&"viewport": viewport,
		&"safe_bounds": safe,
		&"drive_panel": drive_rect,
		&"drive_scale": panel_scales.x,
		&"outpost_panel": outpost_rect,
		&"outpost_scale": panel_scales.y,
		&"mobile_charge": Rect2(charge_position, charge_size),
		&"mobile_charge_scale": charge_scale,
		&"smash_button": smash_rect,
	}


func touch_exclusions(layout: Dictionary, mobile: bool) -> Array[Rect2]:
	if not validate_layout(layout, mobile):
		return []
	var result: Array[Rect2] = [layout[&"drive_panel"] as Rect2, layout[&"outpost_panel"] as Rect2]
	if mobile:
		result.append(layout[&"mobile_charge"] as Rect2)
		result.append(layout[&"smash_button"] as Rect2)
	return result


func clamp_touch_origin(position: Vector2, layout: Dictionary, radius: float) -> Vector2:
	var safe: Rect2 = layout[&"safe_bounds"] as Rect2
	var margin: float = maxf(radius + mobile_gap, 1.0)
	return Vector2(
		clampf(position.x, safe.position.x + margin, safe.end.x - margin),
		clampf(position.y, safe.position.y + margin, safe.end.y - margin),
	)


func validate_layout(layout: Dictionary, mobile: bool) -> bool:
	if layout.size() != LAYOUT_KEYS.size():
		return false
	for key: StringName in LAYOUT_KEYS:
		if not layout.has(key):
			return false
	var safe: Rect2 = layout[&"safe_bounds"] as Rect2
	var drive: Rect2 = layout[&"drive_panel"] as Rect2
	var outpost: Rect2 = layout[&"outpost_panel"] as Rect2
	if (
		safe.size.x <= 0.0
		or safe.size.y <= 0.0
		or not safe.encloses(drive)
		or not safe.encloses(outpost)
	):
		return false
	if drive.intersects(outpost):
		return false
	return not mobile or _mobile_layout_is_valid(layout, safe, drive, outpost)


func _mobile_layout_is_valid(
	layout: Dictionary,
	safe: Rect2,
	drive: Rect2,
	outpost: Rect2,
) -> bool:
	var charge: Rect2 = layout[&"mobile_charge"] as Rect2
	var smash: Rect2 = layout[&"smash_button"] as Rect2
	return (
		safe.encloses(charge)
		and safe.encloses(smash)
		and not charge.intersects(smash)
		and not drive.intersects(charge)
		and not outpost.intersects(charge)
		and not drive.intersects(smash)
		and not outpost.intersects(smash)
	)


func _safe_bounds(viewport: Vector2) -> Rect2:
	var left: float = minf(safe_inset_left, viewport.x * 0.2)
	var right: float = minf(safe_inset_right, viewport.x * 0.2)
	var top: float = minf(safe_inset_top, viewport.y * 0.2)
	var bottom: float = minf(safe_inset_bottom, viewport.y * 0.2)
	return Rect2(Vector2(left, top), viewport - Vector2(left + right, top + bottom))


func _panel_scales(safe: Rect2, landscape: bool, mobile: bool) -> Vector2:
	var control_height: float = SMASH_DESIGN_SIZE.y + CHARGE_DESIGN_SIZE.y + mobile_gap * 2.0
	if landscape:
		var combined_width: float = DRIVE_DESIGN_SIZE.x + OUTPOST_DESIGN_SIZE.x
		var available_height: float = safe.size.y - (control_height if mobile else 0.0)
		var width_scale: float = (safe.size.x - panel_gap) / combined_width
		var height_scale: float = (
			available_height / maxf(DRIVE_DESIGN_SIZE.y, OUTPOST_DESIGN_SIZE.y)
		)
		var scale: float = minf(1.0, minf(width_scale, height_scale))
		return Vector2(scale, scale)
	var available_height: float = safe.size.y - (control_height if mobile else 0.0)
	var width_scale: float = minf(
		safe.size.x / DRIVE_DESIGN_SIZE.x, safe.size.x / OUTPOST_DESIGN_SIZE.x
	)
	var height_scale: float = (
		(available_height - panel_gap) / (DRIVE_DESIGN_SIZE.y + OUTPOST_DESIGN_SIZE.y)
	)
	var scale: float = minf(1.0, minf(width_scale, height_scale))
	return Vector2(scale, scale)


func _outpost_position(
	safe: Rect2,
	drive_rect: Rect2,
	outpost_scale: float,
	landscape: bool,
) -> Vector2:
	if landscape:
		return Vector2(safe.end.x - OUTPOST_DESIGN_SIZE.x * outpost_scale, safe.position.y)
	return Vector2(
		safe.end.x - OUTPOST_DESIGN_SIZE.x * outpost_scale,
		drive_rect.end.y + panel_gap,
	)


func _smash_rect(safe: Rect2, mobile: bool) -> Rect2:
	if not mobile:
		return Rect2(safe.end, Vector2.ZERO)
	var scale: float = minf(1.0, safe.size.x / (SMASH_DESIGN_SIZE.x * 2.4))
	var size: Vector2 = SMASH_DESIGN_SIZE * scale
	return Rect2(safe.end - size, size)
