extends Node2D

const FaunaCombatScript: GDScript = preload("res://scripts/fauna_combat_catalog.gd")
const RIDGE_TEXTURE: Texture2D = preload("res://assets/vfx/worm/ridge_segment.png")
const BREACH_TEXTURE: Texture2D = preload("res://assets/vfx/worm/breach_plume.png")

const STATE_BURROW: StringName = &"burrow"
const STATE_INTERCEPT: StringName = &"intercept"
const STATE_EXPOSE: StringName = &"expose"
const STATE_WAKE_SWEEP: StringName = &"wake_sweep"
const STATE_POUNCE: StringName = &"pounce"
const STATE_EMBER_SALVO: StringName = &"ember_salvo"
const STATE_RECOVER: StringName = &"recover"
const ACTIVE_STATES: Array[StringName] = [
	&"burrow",
	&"intercept",
	&"expose",
	&"dive",
	&"skim",
	&"wake_sweep",
	&"stalk",
	&"pounce",
	&"brace",
	&"ember_salvo",
	&"recover",
	&"staggered",
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
			kind == FaunaCombatScript.WORM_KIND
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
	return {
		&"id": worm_id,
		&"kind": snapshot.get(&"kind", &"sandworm"),
		&"state": snapshot[&"state"],
		&"attack_pattern": snapshot.get(&"attack_pattern", &"breach"),
		&"attack_origin": snapshot.get(&"attack_origin", snapshot[&"position"]),
		&"target_grid": snapshot[&"committed_target"],
		&"target_screen": _grid_to_screen(snapshot[&"committed_target"] as Vector2),
		&"countdown": clampf(float(snapshot.get(&"state_remaining", 0.0)) / duration, 0.0, 1.0),
		&"target_radius": TARGET_RADIUS,
		&"safe_radius": SAFE_RADIUS,
		&"trail_points": get_trail_point_count(worm_id),
		&"breach_remaining": float(_breaches.get(worm_id, 0.0)),
		&"strike_targets": (snapshot.get(&"strike_targets", []) as Array).duplicate(),
		&"strike_pulses": int(snapshot.get(&"strike_pulses", 0)),
		&"resolved_pulses": int(snapshot.get(&"resolved_pulses", 0)),
	}


func _update_trail(worm_id: int, snapshot: Dictionary) -> void:
	var state: StringName = snapshot[&"state"] as StringName
	if snapshot.get(&"kind", &"sandworm") != &"sandworm":
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
	if snapshot.get(&"kind", &"sandworm") != &"sandworm":
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
		draw_polyline(screen_points, Color(dark, 0.58), 7.0, true)
		draw_polyline(screen_points, Color(light, 0.78), 3.0, true)
	for index: int in range(screen_points.size()):
		var alpha: float = 0.09 + 0.22 * float(index + 1) / float(screen_points.size())
		var scale: float = 0.22 + 0.08 * float(index + 1) / float(screen_points.size())
		_draw_texture_centered(RIDGE_TEXTURE, screen_points[index], scale, alpha)


func _draw_target(snapshot: Dictionary) -> void:
	var state: StringName = snapshot[&"state"] as StringName
	if state == STATE_WAKE_SWEEP:
		_draw_wake_sweep(snapshot)
		return
	if state == STATE_POUNCE:
		_draw_frost_pounce(snapshot)
		return
	if state == STATE_EMBER_SALVO:
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
	var kind: StringName = snapshot.get(&"kind", &"sandworm") as StringName
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
	var side: Vector2 = (
		direction.normalized().orthogonal() if not direction.is_zero_approx() else Vector2.UP
	)
	draw_line(start, target, Color(WETLAND, 0.22), 22.0, true)
	draw_dashed_line(start, target, WETLAND, 4.0, 12.0, true)
	for lane_side: float in [-1.0, 1.0]:
		draw_line(start + side * 27.0 * lane_side, target + side * 27.0 * lane_side, TEAL, 2.0)
	draw_arc(target, TARGET_RADIUS, 0.0, TAU, 28, WETLAND, 4.0)


func _draw_frost_pounce(snapshot: Dictionary) -> void:
	var start: Vector2 = _grid_to_screen(snapshot[&"attack_origin"] as Vector2)
	var target: Vector2 = _grid_to_screen(snapshot[&"committed_target"] as Vector2)
	draw_dashed_line(start, target, Color(ICE, 0.86), 3.0, 8.0, true)
	draw_circle(target, TARGET_RADIUS, Color(ICE_DARK, 0.22))
	draw_arc(target, TARGET_RADIUS, 0.0, TAU, 32, ICE, 5.0)
	draw_arc(target, SAFE_RADIUS, PI * 0.12, PI * 0.88, 20, TEAL, 4.0)
	draw_arc(target, SAFE_RADIUS, PI * 1.12, PI * 1.88, 20, TEAL, 4.0)


func _draw_ember_salvo(snapshot: Dictionary) -> void:
	var targets: Array = snapshot.get(&"strike_targets", []) as Array
	var resolved: int = int(snapshot.get(&"resolved_pulses", 0))
	for index: int in range(targets.size()):
		var center: Vector2 = _grid_to_screen(targets[index] as Vector2)
		var spent: bool = index < resolved
		var fill: Color = Color(CINDER_DARK, 0.08 if spent else 0.28 + float(index) * 0.06)
		var edge: Color = Color(CINDER, 0.3 if spent else 0.95)
		draw_circle(center, TARGET_RADIUS + 5.0, fill)
		draw_arc(center, TARGET_RADIUS + 5.0, 0.0, TAU, 32, edge, 4.0)
		if index + 1 == resolved + 1:
			draw_arc(center, SAFE_RADIUS, 0.0, TAU, 36, Color(TEAL, 0.66), 3.0)


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
	if kind != &"sandworm":
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
	return [RUST, SAND]


func _draw_texture_centered(
	texture: Texture2D, center: Vector2, scale: float, alpha: float
) -> void:
	var size: Vector2 = texture.get_size() * scale
	draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, Color(1.0, 1.0, 1.0, alpha))
