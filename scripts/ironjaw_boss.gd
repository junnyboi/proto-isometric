extends RefCounted

const KIND: StringName = &"ironjaw_apex"
const MAX_HEALTH: int = 12
const ATTACK_DAMAGE: int = 12
const BODY_SEGMENTS: int = 6
const CRACKED_HEALTH: int = 8
const BROKEN_HEALTH: int = 4
const PATTERN_CROWN_BREACH: StringName = &"crown_breach"
const PATTERN_FAULTLINE_RUSH: StringName = &"faultline_rush"
const PATTERN_RINGQUAKE: StringName = &"ringquake"
const CROWN_SPACING: float = 1.65
const CROWN_RADIUS: float = 0.9
const FAULTLINE_HALF_WIDTH: float = 0.88
const FAULTLINE_OVERSHOOT: float = 3.4
const RING_RADII: Array[float] = [0.95, 1.9, 2.85]
const RING_HALF_WIDTH: float = 0.42


static func make_entity(enemy_id: int, position: Vector2, emerge_seconds: float) -> Dictionary:
	return {
		&"id": enemy_id,
		&"kind": KIND,
		&"is_boss": true,
		&"position": position,
		&"direction": Vector2.DOWN,
		&"health": MAX_HEALTH,
		&"max_health": MAX_HEALTH,
		&"armor_stage": 0,
		&"age": 0.0,
		&"hit_flash": 0.0,
		&"state": &"burrow",
		&"state_elapsed": 0.0,
		&"state_remaining": emerge_seconds,
		&"state_duration": emerge_seconds,
		&"intercept_start": position,
		&"committed_target": position,
		&"attack_serial": 0,
		&"resolved_attack_serial": 0,
		&"resume_state": &"burrow",
		&"resume_remaining": 0.0,
		&"attack_pattern": PATTERN_CROWN_BREACH,
		&"strike_targets": [],
		&"strike_pulses": 0,
		&"resolved_pulses": 0,
		&"reward_emitted": false,
		&"feedback_direction": Vector2.ZERO,
		&"feedback_time": 0.0,
		&"feedback_duration": 0.0,
		&"feedback_strength": 0,
	}


static func armor_stage(health: int) -> int:
	if health <= BROKEN_HEALTH:
		return 2
	if health <= CRACKED_HEALTH:
		return 1
	return 0


static func pattern_for_stage(stage: int) -> StringName:
	if stage >= 2:
		return PATTERN_RINGQUAKE
	if stage == 1:
		return PATTERN_FAULTLINE_RUSH
	return PATTERN_CROWN_BREACH


static func state_duration(state: StringName, stage: int) -> float:
	var clamped: int = clampi(stage, 0, 2)
	if state == &"burrow":
		return [0.72, 0.58, 0.44][clamped]
	if state == &"intercept":
		return [0.94, 0.72, 0.56][clamped]
	if state == &"expose":
		return [2.15, 1.85, 1.62][clamped]
	if state == &"dive":
		return [0.62, 0.5, 0.4][clamped]
	if state == &"staggered":
		return max_stagger_seconds(clamped)
	if state == &"dispersing":
		return 1.25
	if state == &"defeated":
		return 0.9
	return 0.0


static func break_stagger_seconds(stage: int) -> float:
	return 1.1 if stage == 1 else 0.72


static func max_stagger_seconds(stage: int) -> float:
	return [1.1, 0.72, 0.42][clampi(stage, 0, 2)]


static func lead_target(
	position: Vector2, player: Vector2, velocity: Vector2, stage: int
) -> Dictionary:
	var lead_seconds: float = [0.42, 0.32, 0.22][clampi(stage, 0, 2)]
	var lead_distance: float = [1.6, 1.35, 1.0][clampi(stage, 0, 2)]
	var target: Vector2 = player + (velocity * lead_seconds).limit_length(lead_distance)
	var direction: Vector2 = target - position
	direction = Vector2.DOWN if direction.is_zero_approx() else direction.normalized()
	if stage == 1:
		target += direction * FAULTLINE_OVERSHOOT
	return {&"target": target, &"direction": direction}


static func strike_targets(
	pattern: StringName, target: Vector2, direction: Vector2
) -> Array[Vector2]:
	if pattern == PATTERN_CROWN_BREACH:
		var lateral: Vector2 = direction.orthogonal()
		return [target - lateral * CROWN_SPACING, target, target + lateral * CROWN_SPACING]
	return [target]


static func strike_pulses(pattern: StringName) -> int:
	return RING_RADII.size() if pattern == PATTERN_RINGQUAKE else 1


static func expose_offset(stage: int) -> float:
	return [0.92, 1.08, 0.84][clampi(stage, 0, 2)]


static func commit_attack(worm: Dictionary, player: Vector2, velocity: Vector2) -> void:
	var stage: int = int(worm.get(&"armor_stage", 0))
	var lead: Dictionary = lead_target(worm[&"position"] as Vector2, player, velocity, stage)
	var direction: Vector2 = lead[&"direction"] as Vector2
	var target: Vector2 = lead[&"target"] as Vector2
	var pattern: StringName = pattern_for_stage(stage)
	worm[&"direction"] = direction
	worm[&"intercept_start"] = worm[&"position"]
	worm[&"committed_target"] = target
	worm[&"attack_serial"] = int(worm[&"attack_serial"]) + 1
	worm[&"attack_pattern"] = pattern
	worm[&"strike_targets"] = strike_targets(pattern, target, direction)
	worm[&"strike_pulses"] = strike_pulses(pattern)
	worm[&"resolved_pulses"] = 0


static func crossed_pulses(
	elapsed_before: float, elapsed_after: float, duration: float, resolved: int
) -> Array[int]:
	var total: int = RING_RADII.size()
	var safe_duration: float = maxf(duration, 0.001)
	var before: int = mini(floori(elapsed_before / safe_duration * float(total)), total)
	var after: int = mini(floori((elapsed_after + 0.00001) / safe_duration * float(total)), total)
	var pulses: Array[int] = []
	for pulse: int in range(maxi(before, resolved), after):
		pulses.append(pulse)
	return pulses


static func crown_hits(player: Vector2, targets: Array) -> bool:
	for target: Variant in targets:
		if player.distance_to(target as Vector2) <= CROWN_RADIUS:
			return true
	return false


static func faultline_hits(player: Vector2, start: Vector2, finish: Vector2) -> bool:
	return _distance_to_segment(player, start, finish) <= FAULTLINE_HALF_WIDTH


static func ring_hits(player: Vector2, center: Vector2, pulse: int) -> bool:
	if pulse < 0 or pulse >= RING_RADII.size():
		return false
	return absf(player.distance_to(center) - RING_RADII[pulse]) <= RING_HALF_WIDTH


static func committed_attack_hits(worm: Dictionary, player: Vector2) -> bool:
	var pattern: StringName = worm[&"attack_pattern"] as StringName
	if pattern == PATTERN_CROWN_BREACH:
		return crown_hits(player, worm[&"strike_targets"] as Array)
	return faultline_hits(
		player, worm[&"intercept_start"] as Vector2, worm[&"committed_target"] as Vector2
	)


static func resolve_ring_pulses(
	worm: Dictionary,
	elapsed_before: float,
	elapsed_after: float,
	player: Vector2,
	sanctuary: bool,
) -> bool:
	var emitted: bool = false
	var pulses: Array[int] = crossed_pulses(
		elapsed_before,
		elapsed_after,
		float(worm[&"state_duration"]),
		int(worm[&"resolved_pulses"]),
	)
	for pulse: int in pulses:
		worm[&"resolved_pulses"] = pulse + 1
		if sanctuary or emitted:
			continue
		emitted = ring_hits(player, worm[&"committed_target"] as Vector2, pulse)
	return emitted


static func apply_damage(worm: Dictionary, damage: int) -> Dictionary:
	var old_stage: int = int(worm.get(&"armor_stage", 0))
	var health: int = maxi(int(worm[&"health"]) - maxi(damage, 0), 0)
	var new_stage: int = armor_stage(health)
	worm[&"health"] = health
	worm[&"armor_stage"] = new_stage
	worm[&"attack_pattern"] = pattern_for_stage(new_stage)
	return {
		&"health": health,
		&"old_stage": old_stage,
		&"new_stage": new_stage,
		&"armor_broke": new_stage > old_stage,
		&"defeated": health <= 0,
	}


static func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment: Vector2 = finish - start
	if segment.is_zero_approx():
		return point.distance_to(start)
	var progress: float = clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * progress)
