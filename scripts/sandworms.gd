extends Node2D

signal damage_tick(amount: int, source: StringName)
signal defeated(worm_id: int, position: Vector2)
signal telegraph_started(kind: StringName, worm_id: int, attack_serial: int)

const FaunaCombatScript: GDScript = preload("res://scripts/fauna_combat_catalog.gd")
const FaunaTelegraphAudioScript: GDScript = preload("res://scripts/fauna_telegraph_audio.gd")
const DEFAULT_PROFILE: Resource = preload("res://data/combat/sandworm_default.tres")
const MUD_SKIMMER_TEXTURE: Texture2D = preload("res://assets/enemies/mud_skimmer.png")
const RIME_STALKER_TEXTURE: Texture2D = preload("res://assets/enemies/rime_stalker.png")
const CINDER_CRAWLER_TEXTURE: Texture2D = preload("res://assets/enemies/cinder_crawler.png")

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
const STATE_SKIM: StringName = &"skim"
const STATE_WAKE_WARNING: StringName = &"wake_warning"
const STATE_WAKE_SWEEP: StringName = &"wake_sweep"
const STATE_STALK: StringName = &"stalk"
const STATE_POUNCE_WARNING: StringName = &"pounce_warning"
const STATE_POUNCE: StringName = &"pounce"
const STATE_BRACE: StringName = &"brace"
const STATE_SALVO_WARNING: StringName = &"salvo_warning"
const STATE_EMBER_SALVO: StringName = &"ember_salvo"
const STATE_RECOVER: StringName = &"recover"
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
const SKIMMER_KIND: StringName = &"mud_skimmer"
const RIME_KIND: StringName = &"rime_stalker"
const CINDER_KIND: StringName = &"cinder_crawler"
const WORM_KIND: StringName = &"sandworm"
const SKIMMER_EMERGE_SECONDS: float = 0.45
const RIME_EMERGE_SECONDS: float = 0.6
const CINDER_EMERGE_SECONDS: float = 0.5
const MUD: Color = Color("2d281f")
const WETLAND: Color = Color("75a06c")

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
var _world: RefCounted
var _active_biome: StringName = &"desert"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hovered_enemy_id: int = -1
var _telegraph_audio: Node


func _ready() -> void:
	_rng.seed = 0x5A6D701
	_telegraph_audio = FaunaTelegraphAudioScript.new() as Node
	_telegraph_audio.name = "FaunaTelegraphAudio"
	add_child(_telegraph_audio)
	telegraph_started.connect(_on_telegraph_started)


func _on_telegraph_started(kind: StringName, enemy_id: int, attack_serial: int) -> void:
	var worm: Dictionary = _find_worm(enemy_id)
	var position: Vector2 = (
		_grid_to_screen(worm[&"position"] as Vector2) if not worm.is_empty() else Vector2.ZERO
	)
	_telegraph_audio.call("play_warning", kind, enemy_id, attack_serial, position)


func configure(
	tile_size: Vector2,
	map_origin: Vector2,
	profile: Resource = DEFAULT_PROFILE,
	world: RefCounted = null,
) -> bool:
	if profile == null:
		profile = DEFAULT_PROFILE
	if profile == null or not profile.has_method("validate") or not bool(profile.call("validate")):
		return false
	_tile_size = tile_size
	_map_origin = map_origin
	_profile = profile
	_world = world
	return true


func set_auto_spawn(enabled: bool) -> void:
	_auto_spawn = enabled


func _set_active_biome(biome: StringName) -> void:
	if biome != _active_biome:
		clear_worms()
	_active_biome = biome


func set_player_position(position: Vector2, velocity: Vector2 = Vector2.ZERO) -> void:
	_sync_biome(position)
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
		worm[&"feedback_time"] = maxf(float(worm[&"feedback_time"]) - step, 0.0)
		_advance_worm(worm, step)
		if _state_expired(worm) and worm[&"state"] in [STATE_DISPERSING, STATE_DEFEATED]:
			_worms.remove_at(index)
	queue_redraw()


func spawn_worm(position: Vector2, emerge_seconds: float = -1.0) -> int:
	if _worms.size() >= _p_int(&"max_worms"):
		return -1
	var worm_id: int = _next_id
	_next_id += 1
	var kind: StringName = WORM_KIND
	if _active_biome == &"oasis":
		kind = SKIMMER_KIND
	elif _active_biome == &"frozen":
		kind = RIME_KIND
	elif _active_biome == &"lava":
		kind = CINDER_KIND
	var default_emerge: float = _initial_state_seconds(kind)
	var spawn_seconds: float = default_emerge if emerge_seconds < 0.0 else maxf(emerge_seconds, 0.0)
	var initial_state: StringName = FaunaCombatScript.initial_state(kind)
	(
		_worms
		. append(
			{
				&"id": worm_id,
				&"kind": kind,
				&"position": position,
				&"direction": Vector2.DOWN,
				&"health": _p_int(&"max_health"),
				&"age": 0.0,
				&"hit_flash": 0.0,
				&"state": initial_state,
				&"state_elapsed": 0.0,
				&"state_remaining": spawn_seconds,
				&"state_duration": spawn_seconds,
				&"intercept_start": position,
				&"committed_target": position,
				&"attack_serial": 0,
				&"resolved_attack_serial": 0,
				&"resume_state": initial_state,
				&"resume_remaining": 0.0,
				&"attack_pattern": FaunaCombatScript.attack_pattern(kind),
				&"strike_targets": [],
				&"strike_pulses": 0,
				&"resolved_pulses": 0,
				&"reward_emitted": false,
				&"feedback_direction": Vector2.ZERO,
				&"feedback_time": 0.0,
				&"feedback_duration": 0.0,
				&"feedback_strength": 0,
			}
		)
	)
	queue_redraw()
	return worm_id


func clear_worms() -> void:
	_worms.clear()
	_hovered_enemy_id = -1
	queue_redraw()


func get_worm_count() -> int:
	return _worms.size()


func get_health(worm_id: int) -> int:
	var worm: Dictionary = _find_worm(worm_id)
	return int(worm.get(&"health", 0))


func get_worm_position(worm_id: int) -> Vector2:
	var worm: Dictionary = _find_worm(worm_id)
	return worm.get(&"position", MISSING_POSITION) as Vector2


func _get_enemy_kind(worm_id: int) -> StringName:
	var worm: Dictionary = _find_worm(worm_id)
	return worm.get(&"kind", WORM_KIND) as StringName


func _get_enemy_label(worm_id: int) -> StringName:
	var kind: StringName = _get_enemy_kind(worm_id)
	if kind == SKIMMER_KIND:
		return &"enemy.mud_skimmer.name"
	if kind == RIME_KIND:
		return &"enemy.rime_stalker.name"
	if kind == CINDER_KIND:
		return &"enemy.cinder_crawler.name"
	return &"enemy.sandworm.name"


func _get_active_biome() -> StringName:
	return _active_biome


func get_state(worm_id: int) -> StringName:
	var worm: Dictionary = _find_worm(worm_id)
	return worm.get(&"state", &"missing") as StringName


func get_last_attack_count() -> int:
	return _last_attack_count


func _set_hovered_enemy(worm_id: int) -> void:
	if worm_id == _hovered_enemy_id:
		return
	_hovered_enemy_id = worm_id
	queue_redraw()


func _get_hovered_enemy() -> int:
	return _hovered_enemy_id


func _get_character_hover_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for worm: Dictionary in _worms:
		var state: StringName = worm[&"state"] as StringName
		if state in [STATE_DISPERSING, STATE_DEFEATED]:
			continue
		var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
		var center: Vector2 = _grid_to_screen(worm[&"position"] as Vector2)
		(
			targets
			. append(
				{
					&"id": int(worm[&"id"]),
					&"kind": kind,
					&"name_key": _get_enemy_label(int(worm[&"id"])),
					&"state": state,
					&"screen_position": center + Vector2(0.0, -24.0),
					&"hover_radius": 56.0,
					&"health": int(worm[&"health"]),
					&"max_health": _p_int(&"max_health"),
					&"attack_damage": FaunaCombatScript.damage(kind, _profile),
					&"attack_range": FaunaCombatScript.attack_range(kind, _profile),
				}
			)
		)
	return targets


func get_combat_snapshot(worm_id: int) -> Dictionary:
	var worm: Dictionary = _find_worm(worm_id)
	if worm.is_empty():
		return {}
	return {
		&"id": int(worm[&"id"]),
		&"kind": worm.get(&"kind", WORM_KIND),
		&"state": worm[&"state"],
		&"position": worm[&"position"],
		&"direction": worm[&"direction"],
		&"health": int(worm[&"health"]),
		&"state_elapsed": float(worm[&"state_elapsed"]),
		&"state_remaining": float(worm[&"state_remaining"]),
		&"state_duration": float(worm[&"state_duration"]),
		&"attack_origin": worm[&"intercept_start"],
		&"committed_target": worm[&"committed_target"],
		&"attack_serial": int(worm[&"attack_serial"]),
		&"resolved_attack_serial": int(worm[&"resolved_attack_serial"]),
		&"attack_pattern": worm[&"attack_pattern"],
		&"strike_targets": (worm[&"strike_targets"] as Array).duplicate(),
		&"strike_pulses": int(worm[&"strike_pulses"]),
		&"resolved_pulses": int(worm[&"resolved_pulses"]),
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
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	if (
		worm.is_empty()
		or not FaunaCombatScript.vulnerable(kind, worm[&"state"] as StringName)
		or damage <= 0
	):
		return false
	worm[&"health"] = maxi(int(worm[&"health"]) - damage, 0)
	worm[&"hit_flash"] = 0.18
	if int(worm[&"health"]) <= 0:
		if not bool(worm[&"reward_emitted"]):
			worm[&"reward_emitted"] = true
			defeated.emit(int(worm[&"id"]), worm[&"position"] as Vector2)
		_set_state(worm, STATE_DEFEATED, _p_float(&"defeated_seconds"))
	queue_redraw()
	return true


func present_hit_feedback(
	worm_id: int, direction: Vector2, strength: int, hold_seconds: float
) -> bool:
	var worm: Dictionary = _find_worm(worm_id)
	if worm.is_empty():
		return false
	worm[&"feedback_direction"] = (
		Vector2.RIGHT if direction.is_zero_approx() else direction.normalized()
	)
	worm[&"feedback_duration"] = maxf(0.1, hold_seconds + 0.08)
	worm[&"feedback_time"] = float(worm[&"feedback_duration"])
	worm[&"feedback_strength"] = clampi(strength, 0, 2)
	queue_redraw()
	return true


func get_feedback_offset(worm_id: int) -> Vector2:
	return _feedback_offset(_find_worm(worm_id))


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
		var elapsed_before: float = float(worm[&"state_elapsed"])
		_advance_state_motion(worm, state, consumed)
		worm[&"state_elapsed"] = elapsed_before + consumed
		worm[&"state_remaining"] = state_remaining - consumed
		if state == STATE_EMBER_SALVO and not emitted_attack:
			emitted_attack = _resolve_salvo_pulses(worm, elapsed_before, elapsed_before + consumed)
		remaining -= consumed
		if not _state_expired(worm) or state in [STATE_DISPERSING, STATE_DEFEATED]:
			break
		var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
		if FaunaCombatScript.tracking_state(kind, state) and not _player_detected(worm):
			_set_state(worm, state, _state_duration(kind, state))
			break
		emitted_attack = _transition_state(worm, not emitted_attack) or emitted_attack
		transitions += 1


func _advance_state_motion(worm: Dictionary, state: StringName, delta: float) -> void:
	if delta <= 0.0:
		return
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	if state in [STATE_INTERCEPT, STATE_WAKE_SWEEP, STATE_POUNCE]:
		var duration: float = maxf(float(worm[&"state_duration"]), 0.001)
		var progress: float = clampf((float(worm[&"state_elapsed"]) + delta) / duration, 0.0, 1.0)
		worm[&"position"] = (worm[&"intercept_start"] as Vector2).lerp(
			worm[&"committed_target"] as Vector2, progress
		)
	elif FaunaCombatScript.tracking_state(kind, state) and kind != WORM_KIND:
		_advance_surface_tracking(worm, delta)
	elif state == STATE_DISPERSING:
		var away: Vector2 = (worm[&"position"] as Vector2) - _player_position
		if away.is_zero_approx():
			away = Vector2.RIGHT
		var disperse_speed: float = (
			_p_float(&"burrow_speed")
			if kind == WORM_KIND
			else FaunaCombatScript.value(kind, &"move_speed", _p_float(&"burrow_speed"))
		)
		worm[&"direction"] = away.normalized()
		worm[&"position"] = (
			(worm[&"position"] as Vector2) + away.normalized() * disperse_speed * 2.2 * delta
		)


func _transition_state(worm: Dictionary, may_attack: bool) -> bool:
	var state: StringName = worm[&"state"] as StringName
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	if kind != WORM_KIND:
		return _transition_native_state(worm, state, may_attack)
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


func _transition_native_state(worm: Dictionary, state: StringName, may_attack: bool) -> bool:
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	if state == FaunaCombatScript.initial_state(kind):
		_commit_native_warning(worm)
		return false
	if state == FaunaCombatScript.warning_state(kind):
		_begin_native_attack(worm)
		return false
	if state == FaunaCombatScript.attack_state(kind):
		var attacked: bool = false
		if kind != CINDER_KIND and may_attack:
			attacked = _resolve_attack(worm)
		_set_state(worm, STATE_RECOVER, _state_duration(kind, STATE_RECOVER))
		return attacked
	if state == STATE_RECOVER:
		var initial: StringName = FaunaCombatScript.initial_state(kind)
		_set_state(worm, initial, _state_duration(kind, initial))
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
	telegraph_started.emit(WORM_KIND, int(worm[&"id"]), int(worm[&"attack_serial"]))


func _commit_native_warning(worm: Dictionary) -> void:
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	var position: Vector2 = worm[&"position"] as Vector2
	var lead_seconds: float = FaunaCombatScript.value(kind, &"lead_seconds")
	var lead_distance: float = FaunaCombatScript.value(kind, &"lead_distance")
	var target: Vector2 = (
		_player_position + (_player_velocity * lead_seconds).limit_length(lead_distance)
	)
	var direction: Vector2 = target - position
	direction = Vector2.DOWN if direction.is_zero_approx() else direction.normalized()
	if kind == SKIMMER_KIND:
		target += direction * FaunaCombatScript.value(kind, &"overshoot")
	worm[&"direction"] = direction
	worm[&"intercept_start"] = position
	worm[&"committed_target"] = target
	worm[&"attack_serial"] = int(worm[&"attack_serial"]) + 1
	worm[&"resolved_pulses"] = 0
	worm[&"strike_targets"] = _salvo_targets(target, direction) if kind == CINDER_KIND else [target]
	worm[&"strike_pulses"] = 3 if kind == CINDER_KIND else 1
	var warning_state: StringName = FaunaCombatScript.warning_state(kind)
	_set_state(worm, warning_state, _state_duration(kind, warning_state))
	telegraph_started.emit(kind, int(worm[&"id"]), int(worm[&"attack_serial"]))


func _begin_native_attack(worm: Dictionary) -> void:
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	worm[&"intercept_start"] = worm[&"position"]
	var attack_state: StringName = FaunaCombatScript.attack_state(kind)
	_set_state(worm, attack_state, _state_duration(kind, attack_state))


func _resolve_attack(worm: Dictionary) -> bool:
	var attack_serial: int = int(worm[&"attack_serial"])
	if attack_serial <= int(worm[&"resolved_attack_serial"]):
		return false
	worm[&"resolved_attack_serial"] = attack_serial
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	var attack_distance: float = (worm[&"position"] as Vector2).distance_to(_player_position)
	if kind == SKIMMER_KIND:
		attack_distance = _distance_to_segment(
			_player_position,
			worm[&"intercept_start"] as Vector2,
			worm[&"committed_target"] as Vector2,
		)
	if attack_distance > FaunaCombatScript.attack_range(kind, _profile):
		return false
	_last_attack_count += 1
	damage_tick.emit(FaunaCombatScript.damage(kind, _profile), kind)
	return true


func _resolve_salvo_pulses(worm: Dictionary, elapsed_before: float, elapsed_after: float) -> bool:
	var duration: float = maxf(float(worm[&"state_duration"]), 0.001)
	var before: int = mini(floori(elapsed_before / duration * 3.0), 3)
	var after: int = mini(floori((elapsed_after + 0.00001) / duration * 3.0), 3)
	var emitted: bool = false
	var targets: Array = worm[&"strike_targets"] as Array
	for pulse: int in range(maxi(before, int(worm[&"resolved_pulses"])), after):
		worm[&"resolved_pulses"] = pulse + 1
		if pulse >= targets.size() or emitted:
			continue
		if (
			(targets[pulse] as Vector2).distance_to(_player_position)
			> FaunaCombatScript.attack_range(CINDER_KIND, _profile)
		):
			continue
		_last_attack_count += 1
		damage_tick.emit(FaunaCombatScript.damage(CINDER_KIND, _profile), CINDER_KIND)
		emitted = true
	return emitted


func _resume_after_stagger(worm: Dictionary) -> void:
	var resume_state: StringName = worm[&"resume_state"] as StringName
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	if not FaunaCombatScript.legal_primary_state(kind, resume_state):
		resume_state = FaunaCombatScript.initial_state(kind)
	var remaining: float = maxf(float(worm[&"resume_remaining"]), 0.05)
	_set_state(worm, resume_state, remaining)


func _advance_surface_tracking(worm: Dictionary, delta: float) -> void:
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	var position: Vector2 = worm[&"position"] as Vector2
	var to_player: Vector2 = _player_position - position
	if to_player.is_zero_approx():
		return
	var direction: Vector2 = to_player.normalized()
	if kind == SKIMMER_KIND:
		var side: float = -1.0 if int(worm[&"id"]) % 2 == 0 else 1.0
		direction = (direction * 0.42 + direction.orthogonal() * side * 0.58).normalized()
	worm[&"direction"] = direction
	var speed: float = FaunaCombatScript.value(kind, &"move_speed")
	var step: float = minf(speed * delta, maxf(to_player.length() - 1.35, 0.0))
	worm[&"position"] = position + direction * step


func _salvo_targets(target: Vector2, direction: Vector2) -> Array[Vector2]:
	var lateral: Vector2 = direction.orthogonal()
	return [target - lateral * 0.95, target, target + lateral * 0.95]


func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment: Vector2 = finish - start
	if segment.is_zero_approx():
		return point.distance_to(start)
	var progress: float = clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * progress)


func _initial_state_seconds(kind: StringName) -> float:
	if kind == WORM_KIND:
		return _p_float(&"spawn_burrow_seconds")
	if kind == SKIMMER_KIND:
		return SKIMMER_EMERGE_SECONDS
	if kind == RIME_KIND:
		return RIME_EMERGE_SECONDS
	return CINDER_EMERGE_SECONDS


func _state_duration(kind: StringName, state: StringName) -> float:
	return FaunaCombatScript.state_duration(kind, state, _profile)


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


func _sync_biome(position: Vector2) -> void:
	if _world == null:
		return
	var next_biome: StringName = _world.call("_biome_at", Vector2i(position.round())) as StringName
	_set_active_biome(next_biome)


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


func _feedback_offset(worm: Dictionary) -> Vector2:
	if worm.is_empty() or float(worm.get(&"feedback_time", 0.0)) <= 0.0:
		return Vector2.ZERO
	var duration: float = maxf(float(worm.get(&"feedback_duration", 0.1)), 0.001)
	var ratio: float = clampf(float(worm[&"feedback_time"]) / duration, 0.0, 1.0)
	var direction: Vector2 = worm.get(&"feedback_direction", Vector2.RIGHT) as Vector2
	var screen_direction: Vector2 = (
		Vector2(
			(direction.x - direction.y) * _tile_size.x * 0.5,
			(direction.x + direction.y) * _tile_size.y * 0.5,
		)
		. normalized()
	)
	return (
		screen_direction * (6.0 + float(worm.get(&"feedback_strength", 0)) * 3.0) * sin(ratio * PI)
	)


func _draw() -> void:
	for worm: Dictionary in _worms:
		_draw_worm(worm)


func _draw_worm(worm: Dictionary) -> void:
	var center: Vector2 = _grid_to_screen(worm[&"position"] as Vector2) + _feedback_offset(worm)
	var state: StringName = worm[&"state"] as StringName
	var progress: float = _state_progress(worm)
	var alpha: float = 1.0
	if state in [STATE_DISPERSING, STATE_DEFEATED]:
		alpha = 1.0 - progress
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	if kind == SKIMMER_KIND:
		_draw_skimmer(center, worm, state, progress, alpha)
		return
	if kind == RIME_KIND:
		_draw_native_enemy(
			center,
			worm,
			state,
			progress,
			alpha,
			RIME_STALKER_TEXTURE,
			Color("aeeeff"),
			Color("27688f")
		)
		return
	if kind == CINDER_KIND:
		_draw_native_enemy(
			center,
			worm,
			state,
			progress,
			alpha,
			CINDER_CRAWLER_TEXTURE,
			Color("ff9b2f"),
			Color("8f2414"),
		)
		return
	_draw_sand_wake(center, worm, alpha)
	if state in [STATE_BURROW, STATE_INTERCEPT]:
		var warning: Color = PALE_SAND if state == STATE_BURROW else Color("f5a62d")
		draw_arc(center, 19.0 + progress * 18.0, 0.0, TAU, 28, Color(warning, 0.5), 3.0)
		return
	if state == STATE_DIVE:
		alpha *= 1.0 - progress
	_draw_exposed_body(center, worm, alpha)


func _draw_skimmer(
	center: Vector2, worm: Dictionary, state: StringName, progress: float, alpha: float
) -> void:
	_draw_mud_wake(center, progress, alpha)
	if state == STATE_WAKE_SWEEP:
		alpha *= 0.78
	var size: Vector2 = MUD_SKIMMER_TEXTURE.get_size() * 0.23
	var tint: Color = Color("ffd27a") if int(worm[&"id"]) == _hovered_enemy_id else Color.WHITE
	tint.a = alpha
	draw_texture_rect(
		MUD_SKIMMER_TEXTURE,
		Rect2(center - size * Vector2(0.5, 0.66), size),
		false,
		tint,
	)
	if state in [STATE_RECOVER, STATE_STAGGERED]:
		_draw_health_bar(center + Vector2(0.0, -69.0), int(worm[&"health"]), alpha)


func _draw_native_enemy(
	center: Vector2,
	worm: Dictionary,
	state: StringName,
	progress: float,
	alpha: float,
	texture: Texture2D,
	wake_light: Color,
	wake_dark: Color,
) -> void:
	draw_arc(center, 18.0 + progress * 14.0, 0.0, TAU, 28, Color(wake_light, 0.7 * alpha), 3.0)
	for mote: int in range(10):
		var phase: float = float(mote) * 2.399 + _time * 3.2
		var point: Vector2 = center + Vector2(cos(phase) * 24.0, sin(phase) * 9.0)
		draw_circle(
			point, 2.0 + float(mote % 2), Color(wake_dark, (0.25 + mote % 3 * 0.08) * alpha)
		)
	if state in [STATE_POUNCE, STATE_EMBER_SALVO]:
		alpha *= 0.78
	var size: Vector2 = texture.get_size() * 0.23
	var tint: Color = Color("ffd27a") if int(worm[&"id"]) == _hovered_enemy_id else Color.WHITE
	tint.a = alpha
	draw_texture_rect(texture, Rect2(center - size * Vector2(0.5, 0.66), size), false, tint)
	if state in [STATE_RECOVER, STATE_STAGGERED]:
		_draw_health_bar(center + Vector2(0.0, -69.0), int(worm[&"health"]), alpha)


func _draw_mud_wake(center: Vector2, progress: float, alpha: float) -> void:
	draw_arc(center, 18.0 + progress * 14.0, 0.0, TAU, 28, Color(WETLAND, 0.7 * alpha), 3.0)
	for mote: int in range(10):
		var phase: float = float(mote) * 2.399 + _time * 3.2
		var point: Vector2 = center + Vector2(cos(phase) * 24.0, sin(phase) * 9.0)
		draw_circle(point, 2.0 + float(mote % 2), Color(MUD, (0.25 + mote % 3 * 0.08) * alpha))


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
	var head_color: Color = (
		Color("ffd27a")
		if int(worm[&"id"]) == _hovered_enemy_id
		else (Color.WHITE if float(worm[&"hit_flash"]) > 0.0 else SHELL)
	)
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
