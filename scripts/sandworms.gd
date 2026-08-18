extends Node2D

signal damage_tick(amount: int, source: StringName)

const DEFAULT_PROFILE: Resource = preload("res://data/combat/sandworm_default.tres")

const MAX_HEALTH: int = 4
const ATTACK_DAMAGE: int = 10
const DETECTION_RANGE: float = 8.0
const ATTACK_RANGE: float = 0.72
const MOVE_SPEED: float = 1.28
const ATTACK_COOLDOWN: float = 1.15
const EMERGE_SECONDS: float = 0.8
const DISPERSE_SECONDS: float = 1.25
const MAX_WORMS: int = 4

const STATE_BURROW: StringName = &"burrow"
const STATE_INTERCEPT: StringName = &"intercept"
const STATE_EXPOSE: StringName = &"expose"
const STATE_DIVE: StringName = &"dive"
const STATE_STAGGERED: StringName = &"staggered"
const STATE_DISPERSING: StringName = &"dispersing"
const STATE_DEFEATED: StringName = &"defeated"
const MISSING_POSITION: Vector2 = Vector2(-9999.0, -9999.0)
const SAND: Color = Color("d69a49")
const PALE_SAND: Color = Color("f0c77c")
const SHELL: Color = Color("7e3f2b")
const SHELL_DARK: Color = Color("351d19")
const HEALTH: Color = Color("e75d46")
const HEALTH_BACK: Color = Color("1a1110")

var _tile_size: Vector2 = Vector2(90.0, 45.0)
var _map_origin: Vector2 = Vector2(760.0, 70.0)
var _player_position: Vector2 = Vector2.ZERO
var _player_velocity: Vector2 = Vector2.ZERO
var _worms: Array[Dictionary] = []
var _next_id: int = 1
var _time: float = 0.0
var _spawn_timer: float = 7.0
var _auto_spawn: bool = true
var _outpost_linked: bool = false
var _last_attack_count: int = 0
var _profile: Resource = DEFAULT_PROFILE
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 0x5A6D701


func configure(
	tile_size: Vector2,
	map_origin: Vector2,
	profile: Resource = DEFAULT_PROFILE,
) -> bool:
	if profile == null or not profile.has_method("validate") or not bool(profile.call("validate")):
		return false
	_tile_size = tile_size
	_map_origin = map_origin
	_profile = profile
	return true


func set_auto_spawn(enabled: bool) -> void:
	_auto_spawn = enabled


func set_player_position(position: Vector2, velocity: Vector2 = Vector2.ZERO) -> void:
	_player_position = position
	_player_velocity = velocity


func set_outpost_linked(linked: bool) -> void:
	if linked and not _outpost_linked:
		disperse_all()
	_outpost_linked = linked


func disperse_all() -> void:
	for worm: Dictionary in _worms:
		_set_state(worm, STATE_DISPERSING, _p_float(&"disperse_seconds"))
	queue_redraw()


func advance(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	if step <= 0.0:
		return
	_time += step
	if _auto_spawn and not _outpost_linked:
		_advance_spawner(step)
	for index: int in range(_worms.size() - 1, -1, -1):
		var worm: Dictionary = _worms[index]
		worm[&"age"] = float(worm[&"age"]) + step
		worm[&"hit_flash"] = maxf(float(worm[&"hit_flash"]) - step, 0.0)
		_advance_worm(worm, step)
		if _state_expired(worm) and worm[&"state"] in [STATE_DISPERSING, STATE_DEFEATED]:
			_worms.remove_at(index)
	queue_redraw()


func spawn_worm(position: Vector2, emerge_seconds: float = -1.0) -> int:
	if _worms.size() >= _p_int(&"max_worms"):
		return -1
	var worm_id: int = _next_id
	_next_id += 1
	var spawn_seconds: float = (
		_p_float(&"spawn_burrow_seconds") if emerge_seconds < 0.0 else maxf(emerge_seconds, 0.0)
	)
	(
		_worms
		. append(
			{
				&"id": worm_id,
				&"position": position,
				&"direction": Vector2.DOWN,
				&"health": _p_int(&"max_health"),
				&"age": 0.0,
				&"hit_flash": 0.0,
				&"state": STATE_BURROW,
				&"state_elapsed": 0.0,
				&"state_remaining": spawn_seconds,
				&"state_duration": spawn_seconds,
				&"intercept_start": position,
				&"committed_target": position,
				&"attack_serial": 0,
				&"resolved_attack_serial": 0,
				&"resume_state": STATE_BURROW,
				&"resume_remaining": 0.0,
			}
		)
	)
	queue_redraw()
	return worm_id


func clear_worms() -> void:
	_worms.clear()
	queue_redraw()


func get_worm_count() -> int:
	return _worms.size()


func get_health(worm_id: int) -> int:
	var worm: Dictionary = _find_worm(worm_id)
	return int(worm.get(&"health", 0))


func get_worm_position(worm_id: int) -> Vector2:
	var worm: Dictionary = _find_worm(worm_id)
	return worm.get(&"position", MISSING_POSITION) as Vector2


func get_state(worm_id: int) -> StringName:
	var worm: Dictionary = _find_worm(worm_id)
	return worm.get(&"state", &"missing") as StringName


func get_last_attack_count() -> int:
	return _last_attack_count


func get_combat_snapshot(worm_id: int) -> Dictionary:
	var worm: Dictionary = _find_worm(worm_id)
	if worm.is_empty():
		return {}
	return {
		&"id": int(worm[&"id"]),
		&"state": worm[&"state"],
		&"position": worm[&"position"],
		&"direction": worm[&"direction"],
		&"health": int(worm[&"health"]),
		&"state_elapsed": float(worm[&"state_elapsed"]),
		&"state_remaining": float(worm[&"state_remaining"]),
		&"state_duration": float(worm[&"state_duration"]),
		&"committed_target": worm[&"committed_target"],
		&"attack_serial": int(worm[&"attack_serial"]),
		&"resolved_attack_serial": int(worm[&"resolved_attack_serial"]),
	}


func get_combat_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for worm: Dictionary in _worms:
		snapshots.append(get_combat_snapshot(int(worm[&"id"])))
	return snapshots


func find_target(target_cell: Vector2i) -> int:
	var target: Vector2 = Vector2(target_cell)
	var best_id: int = -1
	var best_distance: float = 0.86
	for worm: Dictionary in _worms:
		if worm[&"state"] in [STATE_DISPERSING, STATE_DEFEATED]:
			continue
		var distance: float = (worm[&"position"] as Vector2).distance_to(target)
		if distance <= best_distance:
			best_distance = distance
			best_id = int(worm[&"id"])
	return best_id


func hit_worm(worm_id: int, damage: int = 1) -> bool:
	var worm: Dictionary = _find_worm(worm_id)
	if worm.is_empty() or worm[&"state"] != STATE_EXPOSE or damage <= 0:
		return false
	worm[&"health"] = maxi(int(worm[&"health"]) - damage, 0)
	worm[&"hit_flash"] = 0.18
	if int(worm[&"health"]) <= 0:
		_set_state(worm, STATE_DEFEATED, _p_float(&"defeated_seconds"))
	queue_redraw()
	return true


func stagger_worm(worm_id: int, seconds: float = -1.0) -> bool:
	var worm: Dictionary = _find_worm(worm_id)
	if worm.is_empty() or worm[&"state"] in [STATE_DISPERSING, STATE_DEFEATED]:
		return false
	var requested: float = _p_float(&"stagger_seconds") if seconds < 0.0 else maxf(seconds, 0.0)
	var bounded: float = minf(requested, _p_float(&"maximum_stagger_seconds"))
	if worm[&"state"] == STATE_STAGGERED:
		worm[&"state_remaining"] = minf(
			maxf(float(worm[&"state_remaining"]), bounded), _p_float(&"maximum_stagger_seconds")
		)
		worm[&"state_duration"] = maxf(
			float(worm[&"state_duration"]), float(worm[&"state_remaining"])
		)
	else:
		worm[&"resume_state"] = worm[&"state"]
		worm[&"resume_remaining"] = float(worm[&"state_remaining"])
		_set_state(worm, STATE_STAGGERED, bounded)
	worm[&"hit_flash"] = 0.28
	queue_redraw()
	return true


func _advance_spawner(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0 or _worms.size() >= _p_int(&"max_worms"):
		return
	var angle: float = _rng.randf_range(0.0, TAU)
	var radius: float = _rng.randf_range(5.5, 8.5)
	spawn_worm(_player_position + Vector2(cos(angle), sin(angle)) * radius)
	_spawn_timer = _rng.randf_range(10.0, 16.0)


func _advance_worm(worm: Dictionary, delta: float) -> void:
	var remaining: float = delta
	var transitions: int = 0
	var emitted_attack: bool = false
	while remaining > 0.00001 and transitions < _p_int(&"maximum_transitions_per_advance"):
		var state: StringName = worm[&"state"] as StringName
		var state_remaining: float = maxf(float(worm[&"state_remaining"]), 0.0)
		var consumed: float = minf(remaining, state_remaining)
		_advance_state_motion(worm, state, consumed)
		worm[&"state_elapsed"] = float(worm[&"state_elapsed"]) + consumed
		worm[&"state_remaining"] = state_remaining - consumed
		remaining -= consumed
		if not _state_expired(worm) or state in [STATE_DISPERSING, STATE_DEFEATED]:
			break
		if state == STATE_BURROW and not _player_detected(worm):
			_set_state(worm, STATE_BURROW, _p_float(&"burrow_seconds"))
			break
		emitted_attack = _transition_state(worm, not emitted_attack) or emitted_attack
		transitions += 1


func _advance_state_motion(worm: Dictionary, state: StringName, delta: float) -> void:
	if delta <= 0.0:
		return
	if state == STATE_INTERCEPT:
		var duration: float = maxf(float(worm[&"state_duration"]), 0.001)
		var progress: float = clampf((float(worm[&"state_elapsed"]) + delta) / duration, 0.0, 1.0)
		worm[&"position"] = (worm[&"intercept_start"] as Vector2).lerp(
			worm[&"committed_target"] as Vector2, progress
		)
	elif state == STATE_DISPERSING:
		var away: Vector2 = (worm[&"position"] as Vector2) - _player_position
		if away.is_zero_approx():
			away = Vector2.RIGHT
		worm[&"direction"] = away.normalized()
		worm[&"position"] = (
			(worm[&"position"] as Vector2)
			+ away.normalized() * _p_float(&"burrow_speed") * 2.2 * delta
		)


func _transition_state(worm: Dictionary, may_attack: bool) -> bool:
	var state: StringName = worm[&"state"] as StringName
	if state == STATE_BURROW:
		_commit_intercept(worm)
		return false
	if state == STATE_INTERCEPT:
		worm[&"position"] = (
			(worm[&"committed_target"] as Vector2)
			- (worm[&"direction"] as Vector2) * _p_float(&"expose_offset")
		)
		_set_state(worm, STATE_EXPOSE, _p_float(&"expose_seconds"))
		return _resolve_attack(worm) if may_attack else false
	if state == STATE_EXPOSE:
		_set_state(worm, STATE_DIVE, _p_float(&"dive_seconds"))
		return false
	if state == STATE_DIVE:
		_set_state(worm, STATE_BURROW, _p_float(&"burrow_seconds"))
		return false
	if state == STATE_STAGGERED:
		_resume_after_stagger(worm)
	return false


func _commit_intercept(worm: Dictionary) -> void:
	var position: Vector2 = worm[&"position"] as Vector2
	var raw_lead: Vector2 = _player_velocity * _p_float(&"maximum_lead_seconds")
	var lead: Vector2 = raw_lead.limit_length(_p_float(&"maximum_lead_distance"))
	var target: Vector2 = _player_position + lead
	var direction: Vector2 = target - position
	worm[&"direction"] = Vector2.DOWN if direction.is_zero_approx() else direction.normalized()
	worm[&"intercept_start"] = position
	worm[&"committed_target"] = target
	worm[&"attack_serial"] = int(worm[&"attack_serial"]) + 1
	_set_state(worm, STATE_INTERCEPT, _p_float(&"intercept_seconds"))


func _resolve_attack(worm: Dictionary) -> bool:
	var attack_serial: int = int(worm[&"attack_serial"])
	if attack_serial <= int(worm[&"resolved_attack_serial"]):
		return false
	worm[&"resolved_attack_serial"] = attack_serial
	if (worm[&"position"] as Vector2).distance_to(_player_position) > _p_float(&"attack_range"):
		return false
	_last_attack_count += 1
	damage_tick.emit(_p_int(&"attack_damage"), &"sandworm")
	return true


func _resume_after_stagger(worm: Dictionary) -> void:
	var resume_state: StringName = worm[&"resume_state"] as StringName
	if resume_state not in [STATE_BURROW, STATE_INTERCEPT, STATE_EXPOSE, STATE_DIVE]:
		resume_state = STATE_BURROW
	var remaining: float = maxf(float(worm[&"resume_remaining"]), 0.05)
	_set_state(worm, resume_state, remaining)


func _set_state(worm: Dictionary, state: StringName, duration: float) -> void:
	worm[&"state"] = state
	worm[&"state_elapsed"] = 0.0
	worm[&"state_remaining"] = maxf(duration, 0.0)
	worm[&"state_duration"] = maxf(duration, 0.0)


func _state_expired(worm: Dictionary) -> bool:
	return float(worm[&"state_remaining"]) <= 0.00001


func _player_detected(worm: Dictionary) -> bool:
	return (
		(worm[&"position"] as Vector2).distance_to(_player_position) <= _p_float(&"detection_range")
	)


func _find_worm(worm_id: int) -> Dictionary:
	for worm: Dictionary in _worms:
		if int(worm[&"id"]) == worm_id:
			return worm
	return {}


func _p_float(property: StringName) -> float:
	return float(_profile.get(property))


func _p_int(property: StringName) -> int:
	return int(_profile.get(property))


func _grid_to_screen(position: Vector2) -> Vector2:
	return (
		_map_origin
		+ Vector2(
			(position.x - position.y) * _tile_size.x * 0.5,
			(position.x + position.y) * _tile_size.y * 0.5,
		)
	)


func _draw() -> void:
	for worm: Dictionary in _worms:
		_draw_worm(worm)


func _draw_worm(worm: Dictionary) -> void:
	var center: Vector2 = _grid_to_screen(worm[&"position"] as Vector2)
	var state: StringName = worm[&"state"] as StringName
	var progress: float = _state_progress(worm)
	var alpha: float = 1.0
	if state in [STATE_DISPERSING, STATE_DEFEATED]:
		alpha = 1.0 - progress
	_draw_sand_wake(center, worm, alpha)
	if state in [STATE_BURROW, STATE_INTERCEPT]:
		var warning: Color = PALE_SAND if state == STATE_BURROW else Color("f5a62d")
		draw_arc(center, 19.0 + progress * 18.0, 0.0, TAU, 28, Color(warning, 0.5), 3.0)
		return
	if state == STATE_DIVE:
		alpha *= 1.0 - progress
	_draw_exposed_body(center, worm, alpha)


func _draw_exposed_body(center: Vector2, worm: Dictionary, alpha: float) -> void:
	var direction: Vector2 = worm[&"direction"] as Vector2
	var screen_direction: Vector2 = (
		(_grid_to_screen(direction) - _grid_to_screen(Vector2.ZERO)).normalized()
	)
	var side: Vector2 = screen_direction.orthogonal()
	var head: Vector2 = center + Vector2(0.0, -18.0)
	for segment: int in range(4, 0, -1):
		var phase: float = _time * 6.0 + float(segment) * 0.8
		var segment_center: Vector2 = (
			head - screen_direction * float(segment) * 17.0 + side * sin(phase) * 6.0
		)
		var shell: Color = SHELL.lightened(float(4 - segment) * 0.035)
		shell.a = alpha
		draw_circle(segment_center, 15.0 - float(segment) * 1.3, shell)
		draw_arc(segment_center, 11.0, PI, TAU, 12, Color(SHELL_DARK, alpha), 3.0)
	var head_color: Color = Color.WHITE if float(worm[&"hit_flash"]) > 0.0 else SHELL
	head_color.a = alpha
	draw_circle(head, 19.0, head_color)
	draw_arc(head, 20.0, 0.0, TAU, 24, Color(SHELL_DARK, alpha), 4.0)
	var mouth: Vector2 = head + screen_direction * 12.0
	draw_circle(mouth, 8.0, Color(SHELL_DARK, alpha))
	for tooth: int in range(3):
		draw_circle(mouth + side * float(tooth - 1) * 5.0, 1.7, Color(PALE_SAND, alpha))
	_draw_health_bar(head + Vector2(0.0, -35.0), int(worm[&"health"]), alpha)


func _state_progress(worm: Dictionary) -> float:
	var duration: float = maxf(float(worm[&"state_duration"]), 0.001)
	return clampf(float(worm[&"state_elapsed"]) / duration, 0.0, 1.0)


func _draw_sand_wake(center: Vector2, worm: Dictionary, alpha: float) -> void:
	var direction: Vector2 = worm[&"direction"] as Vector2
	var screen_direction: Vector2 = (
		(_grid_to_screen(direction) - _grid_to_screen(Vector2.ZERO)).normalized()
	)
	for mote: int in range(18):
		var phase: float = float(mote) * 2.399 + _time * 4.5
		var trail: float = float(mote % 7) * 8.0
		var point: Vector2 = (
			center - screen_direction * trail + Vector2(cos(phase) * 18.0, sin(phase) * 7.0)
		)
		draw_circle(
			point, 2.0 + float(mote % 3), Color(SAND, (0.18 + float(mote % 4) * 0.07) * alpha)
		)


func _draw_health_bar(position: Vector2, health: int, alpha: float) -> void:
	var width: float = 58.0
	draw_rect(
		Rect2(position - Vector2(width * 0.5, 4.0), Vector2(width, 8.0)),
		Color(HEALTH_BACK, 0.88 * alpha)
	)
	var ratio: float = clampf(float(health) / float(_p_int(&"max_health")), 0.0, 1.0)
	draw_rect(
		Rect2(position - Vector2(width * 0.5 - 2.0, 2.0), Vector2((width - 4.0) * ratio, 4.0)),
		Color(HEALTH, alpha),
	)
