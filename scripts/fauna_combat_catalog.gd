extends RefCounted

const WORM_KIND: StringName = &"sandworm"
const SKIMMER_KIND: StringName = &"mud_skimmer"
const RIME_KIND: StringName = &"rime_stalker"
const CINDER_KIND: StringName = &"cinder_crawler"

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

const PATTERN_BREACH: StringName = &"breach"
const PATTERN_WAKE_LINE: StringName = &"wake_line"
const PATTERN_FROST_POUNCE: StringName = &"frost_pounce"
const PATTERN_EMBER_SALVO: StringName = &"ember_salvo"
const BOUNCE_HEIGHT: float = 4.0
const BOUNCE_RATE: float = 5.6
const DISPERSE_OPAQUE_FRACTION: float = 0.18
const RETREAT_SPEED_MULTIPLIER: float = 0.75

const FAUNA: Dictionary = {
	SKIMMER_KIND:
	{
		&"initial_state": STATE_SKIM,
		&"warning_state": STATE_WAKE_WARNING,
		&"attack_state": STATE_WAKE_SWEEP,
		&"pattern": PATTERN_WAKE_LINE,
		&"damage": 6,
		&"attack_range": 0.82,
		&"move_speed": 1.62,
		&"tracking_seconds": 0.8,
		&"warning_seconds": 0.62,
		&"attack_seconds": 0.5,
		&"recover_seconds": 1.05,
		&"lead_seconds": 0.24,
		&"lead_distance": 0.95,
		&"overshoot": 2.15,
	},
	RIME_KIND:
	{
		&"initial_state": STATE_STALK,
		&"warning_state": STATE_POUNCE_WARNING,
		&"attack_state": STATE_POUNCE,
		&"pattern": PATTERN_FROST_POUNCE,
		&"damage": 10,
		&"attack_range": 0.78,
		&"move_speed": 0.98,
		&"tracking_seconds": 1.1,
		&"warning_seconds": 0.9,
		&"attack_seconds": 0.36,
		&"recover_seconds": 1.35,
		&"lead_seconds": 0.15,
		&"lead_distance": 0.62,
		&"overshoot": 0.0,
	},
	CINDER_KIND:
	{
		&"initial_state": STATE_BRACE,
		&"warning_state": STATE_SALVO_WARNING,
		&"attack_state": STATE_EMBER_SALVO,
		&"pattern": PATTERN_EMBER_SALVO,
		&"damage": 5,
		&"attack_range": 0.86,
		&"move_speed": 0.54,
		&"tracking_seconds": 1.15,
		&"warning_seconds": 1.1,
		&"attack_seconds": 1.56,
		&"recover_seconds": 1.6,
		&"lead_seconds": 0.3,
		&"lead_distance": 1.05,
		&"overshoot": 0.0,
	},
}


static func is_burrower(kind: StringName) -> bool:
	return kind == WORM_KIND


static func is_native(kind: StringName) -> bool:
	return FAUNA.has(kind)


static func initial_state(kind: StringName) -> StringName:
	if kind == WORM_KIND:
		return STATE_BURROW
	return FAUNA.get(kind, {}).get(&"initial_state", STATE_STALK) as StringName


static func attack_state(kind: StringName) -> StringName:
	if kind == WORM_KIND:
		return STATE_INTERCEPT
	return FAUNA.get(kind, {}).get(&"attack_state", STATE_POUNCE) as StringName


static func warning_state(kind: StringName) -> StringName:
	return FAUNA.get(kind, {}).get(&"warning_state", STATE_POUNCE_WARNING) as StringName


static func attack_pattern(kind: StringName) -> StringName:
	if kind == WORM_KIND:
		return PATTERN_BREACH
	return FAUNA.get(kind, {}).get(&"pattern", PATTERN_FROST_POUNCE) as StringName


static func tracking_state(kind: StringName, state: StringName) -> bool:
	return state == initial_state(kind)


static func bounce_offset(time: float, enemy_id: int, kind: StringName, state: StringName) -> float:
	if kind == WORM_KIND or not tracking_state(kind, state):
		return 0.0
	return absf(sin(time * BOUNCE_RATE + float(enemy_id) * 0.73)) * BOUNCE_HEIGHT


static func dispersal_alpha(remaining: float, duration: float) -> float:
	var progress: float = 1.0 - clampf(remaining / maxf(duration, 0.001), 0.0, 1.0)
	var fade_progress: float = clampf(
		(progress - DISPERSE_OPAQUE_FRACTION) / (1.0 - DISPERSE_OPAQUE_FRACTION),
		0.0,
		1.0,
	)
	return 1.0 - smoothstep(0.0, 1.0, fade_progress)


static func warning(kind: StringName, state: StringName) -> bool:
	return is_native(kind) and state == warning_state(kind)


static func vulnerable(kind: StringName, state: StringName) -> bool:
	return state == (STATE_EXPOSE if kind == WORM_KIND else STATE_RECOVER)


static func legal_primary_state(kind: StringName, state: StringName) -> bool:
	if kind == WORM_KIND:
		return state in [STATE_BURROW, STATE_INTERCEPT, STATE_EXPOSE, STATE_DIVE]
	if kind == SKIMMER_KIND:
		return state in [STATE_SKIM, STATE_WAKE_WARNING, STATE_WAKE_SWEEP, STATE_RECOVER]
	if kind == RIME_KIND:
		return state in [STATE_STALK, STATE_POUNCE_WARNING, STATE_POUNCE, STATE_RECOVER]
	if kind == CINDER_KIND:
		return state in [STATE_BRACE, STATE_SALVO_WARNING, STATE_EMBER_SALVO, STATE_RECOVER]
	return false


static func state_duration(kind: StringName, state: StringName, profile: Resource) -> float:
	if kind == WORM_KIND:
		return float(profile.call("state_duration", state))
	var data: Dictionary = FAUNA.get(kind, {}) as Dictionary
	if state == initial_state(kind):
		return float(data.get(&"tracking_seconds", 0.75))
	if state == warning_state(kind):
		return float(data.get(&"warning_seconds", 0.75))
	if state == attack_state(kind):
		return float(data.get(&"attack_seconds", 0.65))
	if state == STATE_RECOVER:
		return float(data.get(&"recover_seconds", 1.0))
	if state == STATE_STAGGERED:
		return float(profile.get("stagger_seconds"))
	if state == STATE_DISPERSING:
		return float(profile.get("disperse_seconds"))
	if state == STATE_DEFEATED:
		return float(profile.get("defeated_seconds"))
	return 0.0


static func value(kind: StringName, key: StringName, fallback: float = 0.0) -> float:
	return float((FAUNA.get(kind, {}) as Dictionary).get(key, fallback))


static func damage(kind: StringName, profile: Resource) -> int:
	if kind == WORM_KIND:
		return int(profile.get("attack_damage"))
	return int(round(value(kind, &"damage")))


static func attack_range(kind: StringName, profile: Resource) -> float:
	if kind == WORM_KIND:
		return float(profile.get("attack_range"))
	return value(kind, &"attack_range")


static func make_entity(
	enemy_id: int,
	kind: StringName,
	position: Vector2,
	max_health: int,
	emerge_seconds: float,
) -> Dictionary:
	var initial: StringName = initial_state(kind)
	return {
		&"id": enemy_id,
		&"kind": kind,
		&"position": position,
		&"direction": Vector2.DOWN,
		&"health": max_health,
		&"age": 0.0,
		&"hit_flash": 0.0,
		&"state": initial,
		&"state_elapsed": 0.0,
		&"state_remaining": emerge_seconds,
		&"state_duration": emerge_seconds,
		&"intercept_start": position,
		&"committed_target": position,
		&"attack_serial": 0,
		&"resolved_attack_serial": 0,
		&"attack_pattern": attack_pattern(kind),
		&"strike_targets": [],
		&"strike_pulses": 0,
		&"resolved_pulses": 0,
		&"reward_emitted": false,
		&"feedback_direction": Vector2.ZERO,
		&"feedback_time": 0.0,
		&"feedback_duration": 0.0,
		&"feedback_strength": 0,
	}


static func salvo_targets(target: Vector2, direction: Vector2) -> Array[Vector2]:
	var lateral: Vector2 = direction.orthogonal()
	return [target - lateral * 0.95, target, target + lateral * 0.95]


static func distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment: Vector2 = finish - start
	if segment.is_zero_approx():
		return point.distance_to(start)
	var progress: float = clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * progress)


static func emerge_seconds(kind: StringName, sandworm_seconds: float) -> float:
	if kind == &"ironjaw_apex":
		return 1.0
	if kind == &"sandworm":
		return sandworm_seconds
	if kind == SKIMMER_KIND:
		return 0.45
	if kind == RIME_KIND:
		return 0.6
	return 0.5
