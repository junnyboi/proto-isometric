extends Node2D

const FaunaCombatScript: GDScript = preload("res://scripts/fauna_combat_catalog.gd")
const IronjawBossScript: GDScript = preload("res://scripts/ironjaw_boss.gd")
const KilnheartTelegraphScript: GDScript = preload("res://scripts/kilnheart_telegraph.gd")
const RIDGE_TEXTURE: Texture2D = preload("res://assets/vfx/worm/ridge_segment.png")
const BREACH_TEXTURE: Texture2D = preload("res://assets/vfx/worm/breach_plume.png")

const STATE_BURROW: StringName = &"burrow"
const STATE_INTERCEPT: StringName = &"intercept"
const STATE_EXPOSE: StringName = &"expose"
const STATE_WAKE_WARNING: StringName = &"wake_warning"
const STATE_WAKE_SWEEP: StringName = &"wake_sweep"
const STATE_POUNCE_WARNING: StringName = &"pounce_warning"
const STATE_POUNCE: StringName = &"pounce"
const STATE_SALVO_WARNING: StringName = &"salvo_warning"
const STATE_EMBER_SALVO: StringName = &"ember_salvo"
const STATE_RECOVER: StringName = &"recover"
const ACTIVE_STATES: Array[StringName] = [
	&"burrow",
	&"intercept",
	&"expose",
	&"dive",
	&"skim",
	&"wake_warning",
	&"wake_sweep",
	&"stalk",
	&"pounce_warning",
	&"pounce",
	&"brace",
	&"salvo_warning",
	&"ember_salvo",
	&"recover",
	&"staggered",
	&"kilnheart_emerge",
	&"kilnheart_track",
	&"kilnheart_warning",
	&"kilnheart_attack",
	&"kilnheart_recover",
]
const MAX_TRAIL_POINTS: int = 7
const MIN_TRAIL_DISTANCE: float = 0.18
const TARGET_RADIUS: float = 24.0
const SAFE_RADIUS: float = 44.0
const BREACH_SECONDS: float = 0.32
const AMBER: Color = Color("f5a62d")
const TEAL: Color = Color("4eb6aa")
const RUST: Color = Color("7e3f2b")
const SAND: Color = Color("d69a49")
const MUD: Color = Color("2d281f")
const WETLAND: Color = Color("75a06c")
const SKIMMER_KIND: StringName = &"mud_skimmer"
const RIME_KIND: StringName = &"rime_stalker"
const CINDER_KIND: StringName = &"cinder_crawler"
const BOSS_KIND: StringName = &"ironjaw_apex"
const KILNHEART_KIND: StringName = &"kilnheart_colossus"
const ICE: Color = Color("aeeeff")
const ICE_DARK: Color = Color("27688f")
const CINDER: Color = Color("ff9b2f")
const CINDER_DARK: Color = Color("8f2414")

var _tile_size: Vector2 = Vector2(90.0, 45.0)
var _map_origin: Vector2 = Vector2(760.0, 70.0)
var _snapshots: Dictionary = {}
var _trails: Dictionary = {}
var _previous_states: Dictionary = {}
var _breaches: Dictionary = {}


func configure(tile_size: Vector2, map_origin: Vector2) -> bool:
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		return false
	_tile_size = tile_size
	_map_origin = map_origin
	return true


func sync_combat_snapshots(snapshots: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	for raw: Dictionary in snapshots:
		var worm_id: int = int(raw.get(&"id", -1))
		var state: StringName = raw.get(&"state", &"missing") as StringName
		if worm_id < 0 or state not in ACTIVE_STATES:
			continue
		var snapshot: Dictionary = raw.duplicate(true)
		_snapshots[worm_id] = snapshot
		seen[worm_id] = true
		_update_trail(worm_id, snapshot)
		var previous: StringName = _previous_states.get(worm_id, &"missing") as StringName
		var kind: StringName = snapshot.get(&"kind", FaunaCombatScript.WORM_KIND) as StringName
		if (
			kind in [FaunaCombatScript.WORM_KIND, BOSS_KIND]
			and state == STATE_EXPOSE
			and previous != STATE_EXPOSE
		):
			_breaches[worm_id] = BREACH_SECONDS
		_previous_states[worm_id] = state
	_remove_unseen(seen)
	queue_redraw()


func advance(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	for worm_id: Variant in _breaches.keys():
		_breaches[worm_id] = maxf(float(_breaches[worm_id]) - step, 0.0)
		if is_zero_approx(float(_breaches[worm_id])):
			_breaches.erase(worm_id)
	queue_redraw()


func clear() -> void:
	_snapshots.clear()
	_trails.clear()
	_previous_states.clear()
	_breaches.clear()
	queue_redraw()


func get_trail_point_count(worm_id: int) -> int:
	return (_trails.get(worm_id, []) as Array).size()


func get_telegraph_snapshot(worm_id: int) -> Dictionary:
	var snapshot: Dictionary = _snapshots.get(worm_id, {}) as Dictionary
	if snapshot.is_empty():
		return {}
	var duration: float = maxf(float(snapshot.get(&"state_duration", 0.0)), 0.001)
	var state: StringName = snapshot[&"state"] as StringName
	var kind: StringName = snapshot.get(&"kind", &"sandworm") as StringName
	var warning_active: bool = FaunaCombatScript.warning(kind, state)
	if kind == BOSS_KIND:
		warning_active = state == STATE_INTERCEPT
	elif kind == KILNHEART_KIND:
		warning_active = state == &"kilnheart_warning"
	var countdown: float = clampf(float(snapshot.get(&"state_remaining", 0.0)) / duration, 0.0, 1.0)
	return {
		&"id": worm_id,
		&"kind": snapshot.get(&"kind", &"sandworm"),
		&"state": snapshot[&"state"],
		&"attack_pattern": snapshot.get(&"attack_pattern", &"breach"),
		&"attack_origin": snapshot.get(&"attack_origin", snapshot[&"position"]),
		&"target_grid": snapshot[&"committed_target"],
		&"target_screen": _grid_to_screen(snapshot[&"committed_target"] as Vector2),
		&"countdown": countdown,
		&"warning_active": warning_active,
		&"warning_countdown": countdown if warning_active else 0.0,
		&"target_radius": TARGET_RADIUS * (
			1.6 if kind == KILNHEART_KIND else (1.35 if kind == BOSS_KIND else 1.0)
		),
		&"safe_radius": SAFE_RADIUS,
		&"trail_points": get_trail_point_count(worm_id),
		&"breach_remaining": float(_breaches.get(worm_id, 0.0)),
		&"strike_targets": (snapshot.get(&"strike_targets", []) as Array).duplicate(),
		&"strike_pulses": int(snapshot.get(&"strike_pulses", 0)),
		&"resolved_pulses": int(snapshot.get(&"resolved_pulses", 0)),
	}


func _update_trail(worm_id: int, snapshot: Dictionary) -> void:
	var state: StringName = snapshot[&"state"] as StringName
	if snapshot.get(&"kind", &"sandworm") not in [&"sandworm", BOSS_KIND]:
		return
	if state not in [STATE_BURROW, STATE_INTERCEPT]:
		return
	var position: Vector2 = snapshot[&"position"] as Vector2
	var trail: Array = _trails.get(worm_id, []) as Array
	if trail.is_empty() or (trail.back() as Vector2).distance_to(position) >= MIN_TRAIL_DISTANCE:
		trail.append(position)
	while trail.size() > MAX_TRAIL_POINTS:
		trail.pop_front()
	_trails[worm_id] = trail


func _remove_unseen(seen: Dictionary) -> void:
	for worm_id: Variant in _snapshots.keys():
		if bool(seen.get(worm_id, false)):
			continue
		_snapshots.erase(worm_id)
		_trails.erase(worm_id)
		_previous_states.erase(worm_id)
		_breaches.erase(worm_id)


func _grid_to_screen(position: Vector2) -> Vector2:
	return (
		_map_origin
		+ Vector2(
			(position.x - position.y) * _tile_size.x * 0.5,
			(position.x + position.y) * _tile_size.y * 0.5,
		)
	)


func _draw() -> void:
	for worm_id: Variant in _snapshots:
		var snapshot: Dictionary = _snapshots[worm_id] as Dictionary
		_draw_trail(int(worm_id), snapshot)
		_draw_target(snapshot)
		_draw_expose(int(worm_id), snapshot)


func _draw_trail(worm_id: int, snapshot: Dictionary) -> void:
	var state: StringName = snapshot[&"state"] as StringName
	var kind: StringName = snapshot.get(&"kind", &"sandworm") as StringName
	if kind not in [&"sandworm", BOSS_KIND]:
		return
	if state not in [STATE_BURROW, STATE_INTERCEPT]:
		return
	var trail: Array = _trails.get(worm_id, []) as Array
	if trail.size() < 1:
		return
	var screen_points: PackedVector2Array = PackedVector2Array()
	for point: Variant in trail:
		screen_points.append(_grid_to_screen(point as Vector2))
	if screen_points.size() >= 2:
		var dark: Color = RUST
		var light: Color = SAND
		var width_scale: float = 1.55 if kind == BOSS_KIND else 1.0
		draw_polyline(screen_points, Color(dark, 0.58), 7.0 * width_scale, true)
		draw_polyline(screen_points, Color(light, 0.78), 3.0 * width_scale, true)
	for index: int in range(screen_points.size()):
		var alpha: float = 0.09 + 0.22 * float(index + 1) / float(screen_points.size())
		var scale: float = 0.22 + 0.08 * float(index + 1) / float(screen_points.size())
		_draw_texture_centered(RIDGE_TEXTURE, screen_points[index], scale, alpha)


func _draw_target(snapshot: Dictionary) -> void:
	var state: StringName = snapshot[&"state"] as StringName
	var kind: StringName = snapshot.get(&"kind", &"sandworm") as StringName
	if kind == KILNHEART_KIND:
		KilnheartTelegraphScript.draw_attack(self, snapshot, _tile_size, _map_origin)
		return
	if kind == BOSS_KIND:
		_draw_boss_attack(snapshot)
		return
	if state in [STATE_WAKE_WARNING, STATE_WAKE_SWEEP]:
		_draw_wake_sweep(snapshot)
		return
	if state in [STATE_POUNCE_WARNING, STATE_POUNCE]:
		_draw_frost_pounce(snapshot)
		return
	if state in [STATE_SALVO_WARNING, STATE_EMBER_SALVO]:
		_draw_ember_salvo(snapshot)
		return
	if state != STATE_INTERCEPT:
		return
	var current: Vector2 = _grid_to_screen(snapshot[&"position"] as Vector2)
	var target: Vector2 = _grid_to_screen(snapshot[&"committed_target"] as Vector2)
	var direction: Vector2 = target - current
	var angle: float = direction.angle() if not direction.is_zero_approx() else 0.0
	var duration: float = maxf(float(snapshot.get(&"state_duration", 0.0)), 0.001)
	var remaining: float = clampf(float(snapshot.get(&"state_remaining", 0.0)) / duration, 0.0, 1.0)
	var warning: Color = _kind_colors(kind)[1]
	draw_dashed_line(current, target, Color(warning, 0.68), 2.0, 10.0, true)
	draw_arc(target, TARGET_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * remaining, 32, warning, 4.0)
	draw_arc(target, TARGET_RADIUS + 7.0, angle - 0.5, angle + 0.5, 10, Color(warning, 0.42), 2.0)
	draw_arc(target, SAFE_RADIUS, angle + PI * 0.55, angle + PI * 1.45, 20, Color(TEAL, 0.82), 4.0)
	for side: float in [-1.0, 1.0]:
		var lateral: Vector2 = (
			direction.normalized().orthogonal() * side
			if not direction.is_zero_approx()
			else Vector2.RIGHT * side
		)
		draw_line(target + lateral * 35.0, target + lateral * 48.0, TEAL, 3.0)


func _draw_wake_sweep(snapshot: Dictionary) -> void:
	var start: Vector2 = _grid_to_screen(snapshot[&"attack_origin"] as Vector2)
	var target: Vector2 = _grid_to_screen(snapshot[&"committed_target"] as Vector2)
	var direction: Vector2 = target - start
	var warning: bool = snapshot[&"state"] == STATE_WAKE_WARNING
	var countdown: float = _remaining_ratio(snapshot)
	var pulse: float = _warning_pulse(countdown)
	var side: Vector2 = (
		direction.normalized().orthogonal() if not direction.is_zero_approx() else Vector2.UP
	)
	var danger: Color = AMBER if warning else WETLAND
	draw_line(start, target, Color(danger, 0.16 + pulse * 0.18), 26.0, true)
	draw_dashed_line(start, target, Color(danger, 0.72 + pulse * 0.28), 5.0, 12.0, true)
	for lane_side: float in [-1.0, 1.0]:
		draw_line(start + side * 29.0 * lane_side, target + side * 29.0 * lane_side, TEAL, 3.0)
	draw_arc(target, TARGET_RADIUS, 0.0, TAU, 28, danger, 4.0 + pulse * 2.0)
	if warning:
		_draw_countdown_ring(target, TARGET_RADIUS + 10.0, countdown, danger)
		_draw_warning_marker(start, danger, pulse)
		_draw_lane_chevrons(start, target, side, danger)


func _draw_frost_pounce(snapshot: Dictionary) -> void:
	var start: Vector2 = _grid_to_screen(snapshot[&"attack_origin"] as Vector2)
	var target: Vector2 = _grid_to_screen(snapshot[&"committed_target"] as Vector2)
	var warning: bool = snapshot[&"state"] == STATE_POUNCE_WARNING
	var countdown: float = _remaining_ratio(snapshot)
	var pulse: float = _warning_pulse(countdown)
	var danger: Color = AMBER if warning else ICE
	draw_dashed_line(start, target, Color(danger, 0.82 + pulse * 0.18), 4.0, 8.0, true)
	draw_circle(target, TARGET_RADIUS, Color(ICE_DARK, 0.18 + pulse * 0.18))
	draw_arc(target, TARGET_RADIUS, 0.0, TAU, 32, danger, 5.0 + pulse * 2.0)
	draw_arc(target, SAFE_RADIUS, PI * 0.12, PI * 0.88, 20, TEAL, 4.0)
	draw_arc(target, SAFE_RADIUS, PI * 1.12, PI * 1.88, 20, TEAL, 4.0)
	if warning:
		_draw_countdown_ring(target, TARGET_RADIUS + 11.0, countdown, danger)
		_draw_warning_marker(start, danger, pulse)
		_draw_pounce_arrow(start, target, danger)


func _draw_ember_salvo(snapshot: Dictionary) -> void:
	var targets: Array = snapshot.get(&"strike_targets", []) as Array
	var resolved: int = int(snapshot.get(&"resolved_pulses", 0))
	var warning: bool = snapshot[&"state"] == STATE_SALVO_WARNING
	var countdown: float = _remaining_ratio(snapshot)
	var pulse: float = _warning_pulse(countdown)
	for index: int in range(targets.size()):
		var center: Vector2 = _grid_to_screen(targets[index] as Vector2)
		var spent: bool = index < resolved
		var fill_alpha: float = 0.08 if spent else 0.24 + float(index) * 0.06 + pulse * 0.12
		var fill: Color = Color(CINDER_DARK, fill_alpha)
		var edge: Color = Color(AMBER if warning else CINDER, 0.3 if spent else 0.95)
		draw_circle(center, TARGET_RADIUS + 5.0, fill)
		draw_arc(center, TARGET_RADIUS + 5.0, 0.0, TAU, 32, edge, 4.0 + pulse * 2.0)
		for tick: int in range(index + 1):
			draw_circle(center + Vector2(float(tick - index / 2.0) * 8.0, -38.0), 2.5, edge)
		if warning:
			_draw_countdown_ring(center, TARGET_RADIUS + 12.0, countdown, edge)
		if index + 1 == resolved + 1:
			draw_arc(center, SAFE_RADIUS, 0.0, TAU, 36, Color(TEAL, 0.66), 3.0)
	if warning:
		_draw_warning_marker(_grid_to_screen(snapshot[&"attack_origin"] as Vector2), AMBER, pulse)


func _draw_boss_attack(snapshot: Dictionary) -> void:
	var state: StringName = snapshot[&"state"] as StringName
	var pattern: StringName = snapshot.get(&"attack_pattern", &"") as StringName
	if state not in [STATE_INTERCEPT, STATE_EXPOSE]:
		return
	var countdown: float = _remaining_ratio(snapshot)
	var pulse: float = _warning_pulse(countdown)
	var origin: Vector2 = _grid_to_screen(snapshot[&"attack_origin"] as Vector2)
	var target: Vector2 = _grid_to_screen(snapshot[&"committed_target"] as Vector2)
	if pattern == IronjawBossScript.PATTERN_CROWN_BREACH:
		for raw: Variant in snapshot.get(&"strike_targets", []) as Array:
			var center: Vector2 = _grid_to_screen(raw as Vector2)
			draw_circle(center, 34.0, Color(RUST, 0.18 + pulse * 0.12))
			draw_arc(center, 34.0, 0.0, TAU, 36, AMBER, 5.0 + pulse * 2.0)
			_draw_countdown_ring(center, 43.0, countdown, AMBER)
		draw_dashed_line(origin, target, Color(AMBER, 0.75), 4.0, 10.0, true)
	elif pattern == IronjawBossScript.PATTERN_FAULTLINE_RUSH:
		var direction: Vector2 = (target - origin).normalized()
		var side: Vector2 = direction.orthogonal()
		draw_line(origin, target, Color(RUST, 0.23 + pulse * 0.12), 64.0, true)
		draw_dashed_line(origin, target, Color(AMBER, 0.9), 6.0, 14.0, true)
		for lane_side: float in [-1.0, 1.0]:
			draw_line(origin + side * 32.0 * lane_side, target + side * 32.0 * lane_side, TEAL, 4.0)
		_draw_countdown_ring(target, 40.0, countdown, AMBER)
	else:
		var resolved: int = int(snapshot.get(&"resolved_pulses", 0))
		for index: int in range(IronjawBossScript.RING_RADII.size()):
			var radius: float = IronjawBossScript.RING_RADII[index] * 35.0
			var edge: Color = Color(RUST, 0.36) if index < resolved else Color(AMBER, 0.88)
			draw_arc(target, radius, 0.0, TAU, 48, edge, 4.0 + pulse)
		if state == STATE_INTERCEPT:
			_draw_countdown_ring(target, 112.0, countdown, AMBER)
	_draw_warning_marker(origin, AMBER, pulse)


func _remaining_ratio(snapshot: Dictionary) -> float:
	var duration: float = maxf(float(snapshot.get(&"state_duration", 0.0)), 0.001)
	return clampf(float(snapshot.get(&"state_remaining", 0.0)) / duration, 0.0, 1.0)


func _warning_pulse(countdown: float) -> float:
	return 0.5 + 0.5 * sin((1.0 - countdown) * PI * 8.0)


func _draw_countdown_ring(center: Vector2, radius: float, countdown: float, color: Color) -> void:
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * countdown, 40, color, 6.0)


func _draw_warning_marker(center: Vector2, color: Color, pulse: float) -> void:
	var offset: float = 48.0 + pulse * 5.0
	var marker: Vector2 = center + Vector2(0.0, -offset)
	var size: float = 8.0 + pulse * 3.0
	draw_colored_polygon(
		PackedVector2Array(
			[
				marker + Vector2(0.0, -size),
				marker + Vector2(size, 0.0),
				marker + Vector2(0.0, size),
				marker + Vector2(-size, 0.0),
			]
		),
		Color(color, 0.82),
	)
	draw_circle(marker, 2.5, Color.WHITE)


func _draw_lane_chevrons(start: Vector2, target: Vector2, side: Vector2, color: Color) -> void:
	var direction: Vector2 = (target - start).normalized()
	for progress: float in [0.3, 0.55, 0.8]:
		var center: Vector2 = start.lerp(target, progress)
		draw_line(center - direction * 8.0 + side * 7.0, center, color, 3.0)
		draw_line(center - direction * 8.0 - side * 7.0, center, color, 3.0)


func _draw_pounce_arrow(start: Vector2, target: Vector2, color: Color) -> void:
	var direction: Vector2 = (target - start).normalized()
	var side: Vector2 = direction.orthogonal()
	var tip: Vector2 = target - direction * (TARGET_RADIUS + 3.0)
	draw_line(tip - direction * 18.0 + side * 10.0, tip, color, 4.0)
	draw_line(tip - direction * 18.0 - side * 10.0, tip, color, 4.0)


func _draw_expose(worm_id: int, snapshot: Dictionary) -> void:
	var state: StringName = snapshot[&"state"] as StringName
	if state == STATE_RECOVER:
		_draw_recovery(snapshot)
		return
	if state != STATE_EXPOSE:
		return
	var center: Vector2 = _grid_to_screen(snapshot[&"position"] as Vector2)
	var duration: float = maxf(float(snapshot.get(&"state_duration", 0.0)), 0.001)
	var remaining: float = clampf(float(snapshot.get(&"state_remaining", 0.0)) / duration, 0.0, 1.0)
	draw_arc(center, 36.0, -PI * 0.5, -PI * 0.5 + TAU * remaining, 32, TEAL, 4.0)
	draw_arc(center, 42.0, 0.0, TAU, 32, Color(AMBER, 0.32), 2.0)
	var kind: StringName = snapshot.get(&"kind", &"sandworm") as StringName
	if kind not in [&"sandworm", BOSS_KIND]:
		var accent: Color = _kind_colors(kind)[1]
		draw_arc(center, 48.0, 0.0, TAU, 36, Color(accent, 0.48), 3.0)
		return
	var breach: float = float(_breaches.get(worm_id, 0.0))
	if breach > 0.0:
		_draw_texture_centered(
			BREACH_TEXTURE,
			center + Vector2(0.0, 10.0),
			0.22,
			0.6 * breach / BREACH_SECONDS,
		)


func _draw_recovery(snapshot: Dictionary) -> void:
	var center: Vector2 = _grid_to_screen(snapshot[&"position"] as Vector2)
	var duration: float = maxf(float(snapshot.get(&"state_duration", 0.0)), 0.001)
	var remaining: float = clampf(float(snapshot.get(&"state_remaining", 0.0)) / duration, 0.0, 1.0)
	var kind: StringName = snapshot.get(&"kind", &"sandworm") as StringName
	var accent: Color = _kind_colors(kind)[1]
	draw_arc(center, 38.0, -PI * 0.5, -PI * 0.5 + TAU * remaining, 32, TEAL, 5.0)
	draw_arc(center, 46.0, 0.0, TAU, 36, Color(accent, 0.52), 3.0)


func _kind_colors(kind: StringName) -> Array[Color]:
	if kind == SKIMMER_KIND:
		return [MUD, WETLAND]
	if kind == RIME_KIND:
		return [ICE_DARK, ICE]
	if kind == CINDER_KIND:
		return [CINDER_DARK, CINDER]
	if kind == BOSS_KIND:
		return [Color("3b1815"), AMBER]
	if kind == KILNHEART_KIND:
		return [Color("4c1714"), Color("ff6b2c")]
	return [RUST, SAND]


func _draw_texture_centered(
	texture: Texture2D, center: Vector2, scale: float, alpha: float
) -> void:
	var size: Vector2 = texture.get_size() * scale
	draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, Color(1.0, 1.0, 1.0, alpha))
