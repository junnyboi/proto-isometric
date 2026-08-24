extends RefCounted

const KilnheartBossScript: GDScript = preload("res://scripts/kilnheart_boss.gd")
const AMBER: Color = Color("ffb347")
const MAGMA: Color = Color("ff6b2c")
const DARK: Color = Color("4c1714")
const SAFE: Color = Color("57c8bd")
const TARGET_RADIUS: float = 34.0


static func draw_attack(
	canvas: Node2D,
	snapshot: Dictionary,
	tile_size: Vector2,
	map_origin: Vector2,
) -> void:
	var state: StringName = snapshot[&"state"] as StringName
	if state not in [KilnheartBossScript.STATE_WARNING, KilnheartBossScript.STATE_ATTACK]:
		return
	var pattern: StringName = snapshot.get(&"attack_pattern", &"") as StringName
	var countdown: float = _remaining_ratio(snapshot)
	var pulse: float = 0.5 + 0.5 * sin((1.0 - countdown) * PI * 8.0)
	var origin: Vector2 = _grid_to_screen(
		snapshot[&"attack_origin"] as Vector2, tile_size, map_origin
	)
	var target: Vector2 = _grid_to_screen(
		snapshot[&"committed_target"] as Vector2, tile_size, map_origin
	)
	if pattern == KilnheartBossScript.PATTERN_MAGMA_RAM:
		_draw_ram(canvas, origin, target, countdown, pulse)
	elif pattern == KilnheartBossScript.PATTERN_CALDERA_BARRAGE:
		_draw_barrage(canvas, snapshot, tile_size, map_origin, countdown, pulse)
	else:
		_draw_sweep(canvas, origin, target, countdown, pulse)
	_draw_marker(canvas, origin, pulse)


static func _draw_sweep(
	canvas: Node2D, origin: Vector2, target: Vector2, countdown: float, pulse: float
) -> void:
	var direction: Vector2 = target - origin
	var angle: float = direction.angle() if not direction.is_zero_approx() else 0.0
	var radius: float = 168.0
	var half_angle: float = KilnheartBossScript.SWEEP_HALF_ANGLE
	var points: PackedVector2Array = PackedVector2Array([origin])
	for step: int in range(25):
		var sample: float = lerpf(angle - half_angle, angle + half_angle, float(step) / 24.0)
		points.append(origin + Vector2.from_angle(sample) * radius)
	canvas.draw_colored_polygon(points, Color(DARK, 0.19 + pulse * 0.08))
	canvas.draw_arc(
		origin, radius, angle - half_angle, angle + half_angle, 32, Color(MAGMA, 0.9), 5.0
	)
	for side: float in [-1.0, 1.0]:
		var edge: Vector2 = origin + Vector2.from_angle(angle + half_angle * side) * radius
		canvas.draw_line(origin, edge, Color(AMBER, 0.78), 4.0)
	_draw_countdown(canvas, origin, 54.0, countdown)


static func _draw_ram(
	canvas: Node2D, origin: Vector2, target: Vector2, countdown: float, pulse: float
) -> void:
	var direction: Vector2 = (target - origin).normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var side: Vector2 = direction.orthogonal()
	var half_width: float = 38.0
	var lane: PackedVector2Array = PackedVector2Array(
		[
			origin + side * half_width,
			target + side * half_width,
			target - side * half_width,
			origin - side * half_width,
		]
	)
	canvas.draw_colored_polygon(lane, Color(DARK, 0.24 + pulse * 0.1))
	for lane_side: float in [-1.0, 1.0]:
		canvas.draw_line(
			origin + side * half_width * lane_side,
			target + side * half_width * lane_side,
			SAFE,
			4.0,
		)
	canvas.draw_dashed_line(origin, target, Color(MAGMA, 0.95), 7.0, 15.0, true)
	_draw_countdown(canvas, target, 44.0, countdown)


static func _draw_barrage(
	canvas: Node2D,
	snapshot: Dictionary,
	tile_size: Vector2,
	map_origin: Vector2,
	countdown: float,
	pulse: float,
) -> void:
	var resolved: int = int(snapshot.get(&"resolved_pulses", 0))
	var targets: Array = snapshot.get(&"strike_targets", []) as Array
	for index: int in range(targets.size()):
		var center: Vector2 = _grid_to_screen(targets[index] as Vector2, tile_size, map_origin)
		var spent: bool = index < resolved
		var fill_alpha: float = 0.08 if spent else 0.2 + pulse * 0.12
		var edge: Color = Color(DARK, 0.34) if spent else Color(MAGMA, 0.96)
		canvas.draw_circle(center, TARGET_RADIUS, Color(DARK, fill_alpha))
		canvas.draw_arc(center, TARGET_RADIUS, 0.0, TAU, 36, edge, 5.0 + pulse * 2.0)
		for pip: int in range(index + 1):
			canvas.draw_circle(center + Vector2((pip - index * 0.5) * 9.0, -46.0), 3.0, edge)
		if not spent:
			_draw_countdown(canvas, center, TARGET_RADIUS + 10.0, countdown)


static func _draw_countdown(
	canvas: Node2D, center: Vector2, radius: float, countdown: float
) -> void:
	canvas.draw_arc(
		center,
		radius,
		-PI * 0.5,
		-PI * 0.5 + TAU * countdown,
		40,
		AMBER,
		6.0,
	)


static func _draw_marker(canvas: Node2D, center: Vector2, pulse: float) -> void:
	var marker: Vector2 = center + Vector2(0.0, -58.0 - pulse * 5.0)
	var size: float = 9.0 + pulse * 3.0
	canvas.draw_colored_polygon(
		PackedVector2Array(
			[
				marker + Vector2(0.0, -size),
				marker + Vector2(size, 0.0),
				marker + Vector2(0.0, size),
				marker - Vector2(size, 0.0),
			]
		),
		Color(MAGMA, 0.88),
	)
	canvas.draw_circle(marker, 2.5, Color.WHITE)


static func _remaining_ratio(snapshot: Dictionary) -> float:
	var duration: float = maxf(float(snapshot.get(&"state_duration", 0.0)), 0.001)
	return clampf(float(snapshot.get(&"state_remaining", 0.0)) / duration, 0.0, 1.0)


static func _grid_to_screen(
	position: Vector2, tile_size: Vector2, map_origin: Vector2
) -> Vector2:
	return map_origin + Vector2(
		(position.x - position.y) * tile_size.x * 0.5,
		(position.x + position.y) * tile_size.y * 0.5,
	)
