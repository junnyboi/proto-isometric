extends Node2D

const RIDGE_TEXTURE: Texture2D = preload("res://assets/vfx/worm/ridge_segment.png")
const BREACH_TEXTURE: Texture2D = preload("res://assets/vfx/worm/breach_plume.png")

const STATE_BURROW: StringName = &"burrow"
const STATE_INTERCEPT: StringName = &"intercept"
const STATE_EXPOSE: StringName = &"expose"
const ACTIVE_STATES: Array[StringName] = [&"burrow", &"intercept", &"expose", &"dive", &"staggered"]
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
const ICE: Color = Color("aeeeff")
const ICE_DARK: Color = Color("27688f")

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
		if state == STATE_EXPOSE and previous != STATE_EXPOSE:
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
		&"state": snapshot[&"state"],
		&"target_grid": snapshot[&"committed_target"],
		&"target_screen": _grid_to_screen(snapshot[&"committed_target"] as Vector2),
		&"countdown": clampf(float(snapshot.get(&"state_remaining", 0.0)) / duration, 0.0, 1.0),
		&"target_radius": TARGET_RADIUS,
		&"safe_radius": SAFE_RADIUS,
		&"trail_points": get_trail_point_count(worm_id),
		&"breach_remaining": float(_breaches.get(worm_id, 0.0)),
	}


func _update_trail(worm_id: int, snapshot: Dictionary) -> void:
	var state: StringName = snapshot[&"state"] as StringName
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
	if state not in [STATE_BURROW, STATE_INTERCEPT]:
		return
	var trail: Array = _trails.get(worm_id, []) as Array
	if trail.size() < 1:
		return
	var screen_points: PackedVector2Array = PackedVector2Array()
	for point: Variant in trail:
		screen_points.append(_grid_to_screen(point as Vector2))
	if screen_points.size() >= 2:
		var kind: StringName = snapshot.get(&"kind", &"sandworm") as StringName
		var dark: Color = MUD if kind == SKIMMER_KIND else ICE_DARK if kind == RIME_KIND else RUST
		var light: Color = WETLAND if kind == SKIMMER_KIND else ICE if kind == RIME_KIND else SAND
		draw_polyline(screen_points, Color(dark, 0.58), 7.0, true)
		draw_polyline(screen_points, Color(light, 0.78), 3.0, true)
	if snapshot.get(&"kind", &"sandworm") != &"sandworm":
		return
	for index: int in range(screen_points.size()):
		var alpha: float = 0.09 + 0.22 * float(index + 1) / float(screen_points.size())
		var scale: float = 0.22 + 0.08 * float(index + 1) / float(screen_points.size())
		_draw_texture_centered(RIDGE_TEXTURE, screen_points[index], scale, alpha)


func _draw_target(snapshot: Dictionary) -> void:
	if snapshot[&"state"] != STATE_INTERCEPT:
		return
	var current: Vector2 = _grid_to_screen(snapshot[&"position"] as Vector2)
	var target: Vector2 = _grid_to_screen(snapshot[&"committed_target"] as Vector2)
	var direction: Vector2 = target - current
	var angle: float = direction.angle() if not direction.is_zero_approx() else 0.0
	var duration: float = maxf(float(snapshot.get(&"state_duration", 0.0)), 0.001)
	var remaining: float = clampf(float(snapshot.get(&"state_remaining", 0.0)) / duration, 0.0, 1.0)
	var kind: StringName = snapshot.get(&"kind", &"sandworm") as StringName
	var warning: Color = WETLAND if kind == SKIMMER_KIND else ICE if kind == RIME_KIND else AMBER
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


func _draw_expose(worm_id: int, snapshot: Dictionary) -> void:
	if snapshot[&"state"] != STATE_EXPOSE:
		return
	var center: Vector2 = _grid_to_screen(snapshot[&"position"] as Vector2)
	var duration: float = maxf(float(snapshot.get(&"state_duration", 0.0)), 0.001)
	var remaining: float = clampf(float(snapshot.get(&"state_remaining", 0.0)) / duration, 0.0, 1.0)
	draw_arc(center, 36.0, -PI * 0.5, -PI * 0.5 + TAU * remaining, 32, TEAL, 4.0)
	draw_arc(center, 42.0, 0.0, TAU, 32, Color(AMBER, 0.32), 2.0)
	var kind: StringName = snapshot.get(&"kind", &"sandworm") as StringName
	if kind != &"sandworm":
		var accent: Color = WETLAND if kind == SKIMMER_KIND else ICE
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


func _draw_texture_centered(
	texture: Texture2D, center: Vector2, scale: float, alpha: float
) -> void:
	var size: Vector2 = texture.get_size() * scale
	draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, Color(1.0, 1.0, 1.0, alpha))
