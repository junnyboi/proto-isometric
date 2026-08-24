extends RefCounted

const KIND: StringName = &"kilnheart_colossus"
const PATTERN_FORGE_SWEEP: StringName = &"forge_sweep"
const PATTERN_MAGMA_RAM: StringName = &"magma_ram"
const PATTERN_CALDERA_BARRAGE: StringName = &"caldera_barrage"
const PATTERNS: Array[StringName] = [
	PATTERN_FORGE_SWEEP,
	PATTERN_MAGMA_RAM,
	PATTERN_CALDERA_BARRAGE,
]
const STATE_EMERGE: StringName = &"kilnheart_emerge"
const STATE_TRACK: StringName = &"kilnheart_track"
const STATE_WARNING: StringName = &"kilnheart_warning"
const STATE_ATTACK: StringName = &"kilnheart_attack"
const STATE_RECOVER: StringName = &"kilnheart_recover"
const STATE_STAGGERED: StringName = &"staggered"
const STATE_DISPERSING: StringName = &"dispersing"
const STATE_DEFEATED: StringName = &"defeated"
const MAX_HEALTH: int = 18
const SWEEP_DAMAGE: int = 10
const RAM_DAMAGE: int = 14
const BARRAGE_DAMAGE: int = 6
const TRACK_STOP_RANGE: float = 2.8
const SWEEP_RANGE: float = 4.1
const SWEEP_HALF_ANGLE: float = 0.96
const RAM_HALF_WIDTH: float = 0.82
const BARRAGE_RADIUS: float = 0.92
const BARRAGE_PULSES: int = 3
const MAX_TRANSITIONS: int = 8
const TEXTURE_PATHS: PackedStringArray = [
	"res://assets/enemies/kilnheart/kilnheart_idle.png",
	"res://assets/enemies/kilnheart/kilnheart_walk_a.png",
	"res://assets/enemies/kilnheart/kilnheart_walk_b.png",
	"res://assets/enemies/kilnheart/kilnheart_windup.png",
	"res://assets/enemies/kilnheart/kilnheart_attack.png",
	"res://assets/enemies/kilnheart/kilnheart_cracked.png",
	"res://assets/enemies/kilnheart/kilnheart_broken.png",
	"res://assets/enemies/kilnheart/kilnheart_defeat.png",
]


static func make_entity(enemy_id: int, position: Vector2, emerge_seconds: float) -> Dictionary:
	var duration: float = maxf(emerge_seconds, 0.05)
	return {
		&"id": enemy_id,
		&"kind": KIND,
		&"position": position,
		&"direction": Vector2.DOWN,
		&"health": MAX_HEALTH,
		&"max_health": MAX_HEALTH,
		&"armor_stage": 0,
		&"is_boss": true,
		&"age": 0.0,
		&"hit_flash": 0.0,
		&"state": STATE_EMERGE,
		&"state_elapsed": 0.0,
		&"state_remaining": duration,
		&"state_duration": duration,
		&"intercept_start": position,
		&"committed_target": position,
		&"attack_serial": 0,
		&"resolved_attack_serial": 0,
		&"attack_pattern": PATTERN_FORGE_SWEEP,
		&"attack_cycle": 0,
		&"strike_targets": [],
		&"strike_pulses": 0,
		&"resolved_pulses": 0,
		&"reward_emitted": false,
		&"feedback_direction": Vector2.ZERO,
		&"feedback_time": 0.0,
		&"feedback_duration": 0.0,
		&"feedback_strength": 0,
		&"move_audio_remaining": 0.1,
		&"move_audio_serial": 0,
	}


static func advance(
	boss: Dictionary,
	delta: float,
	player: Vector2,
	player_velocity: Vector2,
	sanctuary: bool,
) -> Dictionary:
	var result: Dictionary = {&"telegraph": false, &"damage_events": [], &"movement": false}
	var start_position: Vector2 = boss[&"position"] as Vector2
	boss[&"move_audio_remaining"] = float(boss[&"move_audio_remaining"]) - maxf(delta, 0.0)
	var remaining: float = maxf(delta, 0.0)
	var transitions: int = 0
	while remaining > 0.00001 and transitions < MAX_TRANSITIONS:
		var state: StringName = boss[&"state"] as StringName
		if state == STATE_DISPERSING:
			_advance_disperse(boss, remaining, player)
			_consume(boss, remaining)
			break
		if state == STATE_DEFEATED:
			_consume(boss, remaining)
			break
		var state_remaining: float = maxf(float(boss[&"state_remaining"]), 0.0)
		var consumed: float = minf(remaining, state_remaining)
		var elapsed_before: float = float(boss[&"state_elapsed"])
		_advance_motion(boss, state, consumed, player)
		_consume(boss, consumed)
		if state == STATE_ATTACK:
			var events: Array = _attack_events(
				boss,
				elapsed_before,
				float(boss[&"state_elapsed"]),
				player,
				sanctuary,
			)
			(result[&"damage_events"] as Array).append_array(events)
		remaining -= consumed
		if float(boss[&"state_remaining"]) > 0.00001:
			break
		if _transition(boss, player, player_velocity):
			result[&"telegraph"] = true
		transitions += 1
	result[&"movement"] = (boss[&"position"] as Vector2).distance_to(start_position) > 0.001
	return result


static func vulnerable(state: StringName) -> bool:
	return state in [STATE_RECOVER, STATE_STAGGERED]


static func apply_damage(boss: Dictionary, damage: int) -> Dictionary:
	if damage <= 0:
		return {&"accepted": false, &"phase_changed": false, &"defeated": false}
	var previous_stage: int = int(boss.get(&"armor_stage", 0))
	boss[&"health"] = maxi(int(boss[&"health"]) - damage, 0)
	var next_stage: int = armor_stage(int(boss[&"health"]))
	boss[&"armor_stage"] = next_stage
	return {
		&"accepted": true,
		&"phase_changed": next_stage != previous_stage,
		&"defeated": int(boss[&"health"]) <= 0,
	}


static func stagger(boss: Dictionary, seconds: float) -> bool:
	if boss[&"state"] in [STATE_EMERGE, STATE_DISPERSING, STATE_DEFEATED]:
		return false
	_set_state(boss, STATE_STAGGERED, minf(maxf(seconds, 0.05), max_stagger_seconds()))
	return true


static func armor_stage(health: int) -> int:
	if health <= 6:
		return 2
	if health <= 12:
		return 1
	return 0


static func max_stagger_seconds() -> float:
	return 0.75


static func current_damage(boss: Dictionary) -> int:
	var pattern: StringName = boss.get(&"attack_pattern", PATTERN_FORGE_SWEEP) as StringName
	if pattern == PATTERN_MAGMA_RAM:
		return RAM_DAMAGE
	if pattern == PATTERN_CALDERA_BARRAGE:
		return BARRAGE_DAMAGE
	return SWEEP_DAMAGE


static func current_range(boss: Dictionary) -> float:
	var pattern: StringName = boss.get(&"attack_pattern", PATTERN_FORGE_SWEEP) as StringName
	if pattern == PATTERN_MAGMA_RAM:
		return 6.6
	if pattern == PATTERN_CALDERA_BARRAGE:
		return BARRAGE_RADIUS
	return SWEEP_RANGE


static func animation_key(boss: Dictionary, time: float) -> StringName:
	var state: StringName = boss[&"state"] as StringName
	if state == STATE_DEFEATED:
		return &"defeat"
	if state == STATE_WARNING:
		return &"windup"
	if state == STATE_ATTACK:
		return &"attack"
	if state == STATE_TRACK:
		return &"walk_a" if int(floor(time * 4.8)) % 2 == 0 else &"walk_b"
	var stage: int = int(boss.get(&"armor_stage", 0))
	if stage >= 2:
		return &"broken"
	if stage == 1:
		return &"cracked"
	return &"idle"


static func texture_paths() -> PackedStringArray:
	return TEXTURE_PATHS.duplicate()


static func _transition(boss: Dictionary, player: Vector2, velocity: Vector2) -> bool:
	var state: StringName = boss[&"state"] as StringName
	if state == STATE_EMERGE:
		_set_state(boss, STATE_TRACK, _duration(boss, STATE_TRACK))
		return false
	if state == STATE_TRACK:
		_commit_attack(boss, player, velocity)
		return true
	if state == STATE_WARNING:
		boss[&"intercept_start"] = boss[&"position"]
		_set_state(boss, STATE_ATTACK, _duration(boss, STATE_ATTACK))
		return false
	if state == STATE_ATTACK:
		_set_state(boss, STATE_RECOVER, _duration(boss, STATE_RECOVER))
		return false
	_set_state(boss, STATE_TRACK, _duration(boss, STATE_TRACK))
	return false


static func _commit_attack(boss: Dictionary, player: Vector2, velocity: Vector2) -> void:
	var cycle: int = int(boss.get(&"attack_cycle", 0))
	var stage: int = int(boss.get(&"armor_stage", 0))
	var pattern: StringName = PATTERNS[(cycle + stage) % PATTERNS.size()]
	boss[&"attack_cycle"] = cycle + 1
	boss[&"attack_pattern"] = pattern
	boss[&"attack_serial"] = int(boss[&"attack_serial"]) + 1
	boss[&"resolved_pulses"] = 0
	var position: Vector2 = boss[&"position"] as Vector2
	var predicted: Vector2 = player + velocity.limit_length(1.35)
	var direction: Vector2 = predicted - position
	direction = Vector2.DOWN if direction.is_zero_approx() else direction.normalized()
	boss[&"direction"] = direction
	boss[&"intercept_start"] = position
	boss[&"committed_target"] = predicted
	boss[&"strike_pulses"] = BARRAGE_PULSES if pattern == PATTERN_CALDERA_BARRAGE else 1
	if pattern == PATTERN_MAGMA_RAM:
		var length: float = clampf(position.distance_to(predicted) + 1.25, 4.0, 6.6)
		boss[&"committed_target"] = position + direction * length
		boss[&"strike_targets"] = [boss[&"committed_target"]]
	elif pattern == PATTERN_CALDERA_BARRAGE:
		var side: Vector2 = direction.orthogonal()
		boss[&"strike_targets"] = [predicted - side * 1.35, predicted, predicted + side * 1.35]
	else:
		boss[&"strike_targets"] = [predicted]
	_set_state(boss, STATE_WARNING, _duration(boss, STATE_WARNING))


static func _advance_motion(
	boss: Dictionary, state: StringName, delta: float, player: Vector2
) -> void:
	if delta <= 0.0:
		return
	if state == STATE_TRACK:
		var position: Vector2 = boss[&"position"] as Vector2
		var offset: Vector2 = player - position
		if offset.length() <= TRACK_STOP_RANGE:
			return
		boss[&"direction"] = offset.normalized()
		var speed: float = 0.74 + float(boss.get(&"armor_stage", 0)) * 0.14
		boss[&"position"] = position + offset.normalized() * speed * delta
	elif state == STATE_ATTACK and boss[&"attack_pattern"] == PATTERN_MAGMA_RAM:
		var duration: float = maxf(float(boss[&"state_duration"]), 0.001)
		var progress: float = clampf((float(boss[&"state_elapsed"]) + delta) / duration, 0.0, 1.0)
		boss[&"position"] = (boss[&"intercept_start"] as Vector2).lerp(
			boss[&"committed_target"] as Vector2, progress
		)


static func _advance_disperse(boss: Dictionary, delta: float, player: Vector2) -> void:
	var away: Vector2 = (boss[&"position"] as Vector2) - player
	away = Vector2.RIGHT if away.is_zero_approx() else away.normalized()
	boss[&"direction"] = away
	boss[&"position"] = (boss[&"position"] as Vector2) + away * 1.7 * delta


static func _attack_events(
	boss: Dictionary,
	before: float,
	after: float,
	player: Vector2,
	sanctuary: bool,
) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var pattern: StringName = boss[&"attack_pattern"] as StringName
	if pattern == PATTERN_CALDERA_BARRAGE:
		return _barrage_events(boss, before, after, player, sanctuary)
	var duration: float = maxf(float(boss[&"state_duration"]), 0.001)
	var impact: float = duration * (0.58 if pattern == PATTERN_MAGMA_RAM else 0.42)
	if before < impact and after + 0.00001 >= impact:
		boss[&"resolved_attack_serial"] = int(boss[&"attack_serial"])
		if not sanctuary and _single_attack_hits(boss, player):
			events.append({&"amount": current_damage(boss), &"source": KIND})
	return events


static func _barrage_events(
	boss: Dictionary,
	before: float,
	after: float,
	player: Vector2,
	sanctuary: bool,
) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var duration: float = maxf(float(boss[&"state_duration"]), 0.001)
	var first: int = mini(floori(before / duration * BARRAGE_PULSES), BARRAGE_PULSES)
	var last: int = mini(floori((after + 0.00001) / duration * BARRAGE_PULSES), BARRAGE_PULSES)
	var targets: Array = boss[&"strike_targets"] as Array
	for pulse: int in range(maxi(first, int(boss[&"resolved_pulses"])), last):
		boss[&"resolved_pulses"] = pulse + 1
		if not sanctuary and pulse < targets.size():
			if (targets[pulse] as Vector2).distance_to(player) <= BARRAGE_RADIUS:
				events.append({&"amount": BARRAGE_DAMAGE, &"source": KIND})
	boss[&"resolved_attack_serial"] = int(boss[&"attack_serial"])
	return events


static func _single_attack_hits(boss: Dictionary, player: Vector2) -> bool:
	var pattern: StringName = boss[&"attack_pattern"] as StringName
	var start: Vector2 = boss[&"intercept_start"] as Vector2
	var finish: Vector2 = boss[&"committed_target"] as Vector2
	if pattern == PATTERN_MAGMA_RAM:
		return _distance_to_segment(player, start, finish) <= RAM_HALF_WIDTH
	var direction: Vector2 = (finish - start).normalized()
	var to_player: Vector2 = player - start
	if to_player.length() > SWEEP_RANGE or to_player.is_zero_approx():
		return false
	return direction.dot(to_player.normalized()) >= cos(SWEEP_HALF_ANGLE)


static func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment: Vector2 = finish - start
	if segment.is_zero_approx():
		return point.distance_to(start)
	var progress: float = clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * progress)


static func _duration(boss: Dictionary, state: StringName) -> float:
	var stage: int = int(boss.get(&"armor_stage", 0))
	if state == STATE_TRACK:
		return maxf(1.25, 2.1 - stage * 0.32)
	if state == STATE_WARNING:
		var base: float = 1.05
		if boss[&"attack_pattern"] == PATTERN_MAGMA_RAM:
			base = 0.92
		elif boss[&"attack_pattern"] == PATTERN_CALDERA_BARRAGE:
			base = 1.2
		return maxf(0.64, base - stage * 0.12)
	if state == STATE_ATTACK:
		return 1.32 if boss[&"attack_pattern"] == PATTERN_CALDERA_BARRAGE else 0.82
	if state == STATE_RECOVER:
		return maxf(0.72, 1.12 - stage * 0.14)
	if state == STATE_STAGGERED:
		return max_stagger_seconds()
	if state in [STATE_DISPERSING, STATE_DEFEATED]:
		return 1.2
	return 0.0


static func _set_state(boss: Dictionary, state: StringName, duration: float) -> void:
	boss[&"state"] = state
	boss[&"state_elapsed"] = 0.0
	boss[&"state_remaining"] = maxf(duration, 0.0)
	boss[&"state_duration"] = maxf(duration, 0.0)


static func _consume(boss: Dictionary, seconds: float) -> void:
	boss[&"state_elapsed"] = float(boss[&"state_elapsed"]) + seconds
	boss[&"state_remaining"] = maxf(float(boss[&"state_remaining"]) - seconds, 0.0)
