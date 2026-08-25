extends RefCounted

const PROFILE_SAND: StringName = &"sand"
const PROFILE_WETLAND: StringName = &"wetland"
const PROFILE_FROZEN: StringName = &"frozen"
const PROFILE_VOLCANIC: StringName = &"volcanic"
const PROFILE_OFFSETS: Dictionary = {
	PROFILE_SAND: 11.0,
	PROFILE_WETLAND: 37.0,
	PROFILE_FROZEN: 71.0,
	PROFILE_VOLCANIC: 103.0,
}
const PROFILE_KINDS: Dictionary = {
	PROFILE_SAND: [&"sand", &"gust", &"grit"],
	PROFILE_WETLAND: [&"rain", &"mist", &"ripple"],
	PROFILE_FROZEN: [&"snowflake", &"ice_grain", &"snow_drift"],
	PROFILE_VOLCANIC: [&"ash", &"ember", &"cinder"],
}


static func normalize_profile(profile: StringName) -> StringName:
	if profile in [&"mud", &"wetland", &"water", &"oasis"]:
		return PROFILE_WETLAND
	if profile in [&"snow", &"blue_ice", &"ice", &"frozen"]:
		return PROFILE_FROZEN
	if profile in [&"lava", &"lava_basalt", &"volcanic_ash", &"volcanic"]:
		return PROFILE_VOLCANIC
	return PROFILE_SAND


static func class_counts(profile: StringName, count: int) -> Dictionary:
	var normalized: StringName = normalize_profile(profile)
	var kinds: Array = PROFILE_KINDS[normalized] as Array
	var primary: int = clampi(roundi(float(count) * 0.6), 0, count)
	var secondary: int = clampi(roundi(float(count) * 0.25), 0, count - primary)
	return {
		kinds[0]: primary,
		kinds[1]: secondary,
		kinds[2]: maxi(count - primary - secondary, 0),
	}


static func snapshot(
	index: int,
	count: int,
	profile: StringName,
	time: float,
	draw_rect: Rect2,
	intensity: float,
) -> Dictionary:
	var normalized: StringName = normalize_profile(profile)
	var counts: Dictionary = class_counts(normalized, count)
	var kinds: Array = PROFILE_KINDS[normalized] as Array
	var primary: int = int(counts[kinds[0]])
	var secondary: int = int(counts[kinds[1]])
	var kind: StringName = kinds[0] as StringName
	if index >= primary + secondary:
		kind = kinds[2] as StringName
	elif index >= primary:
		kind = kinds[1] as StringName
	var offset: float = float(PROFILE_OFFSETS[normalized])
	var seed: float = float(index) + offset
	var velocity: Vector2 = _velocity_for(kind, seed, intensity)
	var origin: Vector2 = Vector2(
		draw_rect.position.x + fposmod(seed * 173.31, draw_rect.size.x),
		draw_rect.position.y + fposmod(seed * 97.17, draw_rect.size.y),
	)
	var position: Vector2 = origin + velocity * time
	position.x = draw_rect.position.x + fposmod(
		position.x - draw_rect.position.x, draw_rect.size.x
	)
	position.y = draw_rect.position.y + fposmod(
		position.y - draw_rect.position.y, draw_rect.size.y
	)
	var pulse: float = 0.72 + 0.28 * sin(time * 1.7 + seed * 2.13)
	return {
		&"kind": kind,
		&"position": position,
		&"velocity": velocity,
		&"size": _size_for(kind, seed, intensity),
		&"rotation": fposmod(time * (0.4 + fmod(seed, 5.0) * 0.09) + seed, TAU),
		&"alpha": _alpha_for(kind) * pulse * clampf(intensity, 0.0, 1.0),
		&"profile": normalized,
	}


static func draw_particle(canvas: CanvasItem, particle: Dictionary, strength: float) -> void:
	var kind: StringName = particle[&"kind"] as StringName
	var position: Vector2 = particle[&"position"] as Vector2
	var velocity: Vector2 = particle[&"velocity"] as Vector2
	var size: float = float(particle[&"size"])
	var rotation: float = float(particle[&"rotation"])
	var alpha: float = float(particle[&"alpha"]) * clampf(strength, 0.0, 1.0)
	var color: Color = _color_for(kind)
	color.a = alpha
	match kind:
		&"sand":
			canvas.draw_line(position, position + velocity.normalized() * size, color, 1.2)
		&"gust":
			_draw_ribbon(canvas, position, velocity.normalized(), size, color)
		&"grit":
			canvas.draw_circle(position, maxf(size * 0.12, 0.8), color)
		&"rain":
			canvas.draw_line(position, position + velocity.normalized() * size, color, 1.15)
		&"mist":
			canvas.draw_circle(position, size, color)
		&"ripple":
			canvas.draw_arc(position, size, 0.0, PI, 10, color, 1.0)
		&"snowflake":
			_draw_snowflake(canvas, position, size, color, rotation)
		&"ice_grain":
			canvas.draw_circle(position, maxf(size * 0.18, 0.9), color)
		&"snow_drift":
			_draw_drift(canvas, position, size, color)
		&"ash":
			_draw_ash(canvas, position, size, color, rotation)
		&"ember":
			_draw_ember(canvas, position, velocity, size, color)
		&"cinder":
			canvas.draw_line(position, position - velocity.normalized() * size, color, 1.4)


static func _velocity_for(kind: StringName, seed: float, intensity: float) -> Vector2:
	var gain: float = 0.72 + clampf(intensity, 0.0, 1.0) * 0.55
	match kind:
		&"sand", &"gust", &"grit":
			return Vector2(135.0 + fmod(seed * 13.0, 95.0), -14.0 - fmod(seed, 9.0)) * gain
		&"rain":
			return Vector2(22.0 + fmod(seed, 18.0), 250.0 + fmod(seed * 11.0, 95.0)) * gain
		&"mist":
			return Vector2(18.0 + fmod(seed, 12.0), -3.0) * gain
		&"ripple":
			return Vector2(6.0 + fmod(seed, 5.0), 5.0) * gain
		&"snowflake", &"ice_grain", &"snow_drift":
			return Vector2(42.0 + fmod(seed * 7.0, 42.0), 48.0 + fmod(seed, 34.0)) * gain
		&"ember":
			return Vector2(12.0 + fmod(seed, 20.0), -72.0 - fmod(seed * 5.0, 75.0)) * gain
		&"ash", &"cinder":
			return Vector2(28.0 + fmod(seed, 36.0), 54.0 + fmod(seed * 9.0, 62.0)) * gain
	return Vector2.ZERO


static func _size_for(kind: StringName, seed: float, intensity: float) -> float:
	var gain: float = 0.85 + clampf(intensity, 0.0, 1.0) * 0.25
	match kind:
		&"gust":
			return (34.0 + fmod(seed * 3.0, 42.0)) * gain
		&"rain":
			return (13.0 + fmod(seed, 15.0)) * gain
		&"mist":
			return (8.0 + fmod(seed, 12.0)) * gain
		&"ripple":
			return (5.0 + fmod(seed, 8.0)) * gain
		&"snow_drift":
			return (24.0 + fmod(seed, 34.0)) * gain
		&"ash":
			return (2.2 + fmod(seed, 3.8)) * gain
		&"ember":
			return (2.0 + fmod(seed, 2.8)) * gain
	return (4.0 + fmod(seed, 7.0)) * gain


static func _alpha_for(kind: StringName) -> float:
	if kind in [&"gust", &"mist", &"snow_drift"]:
		return 0.10
	if kind in [&"ember", &"rain", &"snowflake"]:
		return 0.31
	return 0.22


static func _color_for(kind: StringName) -> Color:
	match kind:
		&"sand":
			return Color("e8bb72")
		&"gust":
			return Color("f2d49a")
		&"grit":
			return Color("b87634")
		&"rain":
			return Color("b8d6d4")
		&"mist":
			return Color("7db0a8")
		&"ripple":
			return Color("b6d7ca")
		&"snowflake":
			return Color("f4fbff")
		&"ice_grain":
			return Color("b6e4ef")
		&"snow_drift":
			return Color("d8edf5")
		&"ash":
			return Color("a89b95")
		&"ember":
			return Color("ff9a3c")
		&"cinder":
			return Color("ffd16b")
	return Color.WHITE


static func _draw_ribbon(
	canvas: CanvasItem, position: Vector2, direction: Vector2, size: float, color: Color
) -> void:
	var side: Vector2 = direction.rotated(PI * 0.5) * 2.2
	canvas.draw_colored_polygon(
		PackedVector2Array([
			position - side,
			position + side,
			position + direction * size + side * 0.35,
			position + direction * size - side * 0.35,
		]),
		color,
	)


static func _draw_snowflake(
	canvas: CanvasItem, position: Vector2, size: float, color: Color, rotation: float
) -> void:
	for axis_index: int in range(2):
		var direction: Vector2 = Vector2.RIGHT.rotated(rotation + float(axis_index) * PI * 0.5)
		canvas.draw_line(
			position - direction * size * 0.35,
			position + direction * size * 0.35,
			color,
			1.0,
		)


static func _draw_drift(canvas: CanvasItem, position: Vector2, size: float, color: Color) -> void:
	canvas.draw_polyline(
		PackedVector2Array([
			position,
			position + Vector2(size * 0.35, -3.0),
			position + Vector2(size * 0.72, 2.0),
			position + Vector2(size, -1.0),
		]),
		color,
		1.3,
	)


static func _draw_ash(
	canvas: CanvasItem, position: Vector2, size: float, color: Color, rotation: float
) -> void:
	var right: Vector2 = Vector2.RIGHT.rotated(rotation) * size
	var down: Vector2 = right.rotated(PI * 0.5) * 0.55
	canvas.draw_colored_polygon(
		PackedVector2Array([
			position - right,
			position + down,
			position + right,
			position - down,
		]),
		color,
	)


static func _draw_ember(
	canvas: CanvasItem, position: Vector2, velocity: Vector2, size: float, color: Color
) -> void:
	canvas.draw_line(position, position - velocity.normalized() * size * 2.2, color, 1.2)
	canvas.draw_circle(position, size * 0.55, color)
