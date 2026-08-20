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
const STATE_WAKE_SWEEP: StringName = &"wake_sweep"
const STATE_STALK: StringName = &"stalk"
const STATE_POUNCE: StringName = &"pounce"
const STATE_BRACE: StringName = &"brace"
const STATE_EMBER_SALVO: StringName = &"ember_salvo"
const STATE_RECOVER: StringName = &"recover"
const STATE_STAGGERED: StringName = &"staggered"
const STATE_DISPERSING: StringName = &"dispersing"
const STATE_DEFEATED: StringName = &"defeated"

const PATTERN_BREACH: StringName = &"breach"
const PATTERN_WAKE_LINE: StringName = &"wake_line"
const PATTERN_FROST_POUNCE: StringName = &"frost_pounce"
const PATTERN_EMBER_SALVO: StringName = &"ember_salvo"

const FAUNA: Dictionary = {
	SKIMMER_KIND:
	{
		&"initial_state": STATE_SKIM,
		&"attack_state": STATE_WAKE_SWEEP,
		&"pattern": PATTERN_WAKE_LINE,
		&"damage": 8,
		&"attack_range": 0.9,
		&"move_speed": 1.72,
		&"tracking_seconds": 0.62,
		&"attack_seconds": 0.56,
		&"recover_seconds": 0.92,
		&"lead_seconds": 0.28,
		&"lead_distance": 1.1,
		&"overshoot": 2.3,
	},
	RIME_KIND:
	{
		&"initial_state": STATE_STALK,
		&"attack_state": STATE_POUNCE,
		&"pattern": PATTERN_FROST_POUNCE,
		&"damage": 12,
		&"attack_range": 0.82,
		&"move_speed": 1.08,
		&"tracking_seconds": 0.88,
		&"attack_seconds": 0.44,
		&"recover_seconds": 1.18,
		&"lead_seconds": 0.18,
		&"lead_distance": 0.72,
		&"overshoot": 0.0,
	},
	CINDER_KIND:
	{
		&"initial_state": STATE_BRACE,
		&"attack_state": STATE_EMBER_SALVO,
		&"pattern": PATTERN_EMBER_SALVO,
		&"damage": 6,
		&"attack_range": 0.92,
		&"move_speed": 0.58,
		&"tracking_seconds": 1.0,
		&"attack_seconds": 1.32,
		&"recover_seconds": 1.4,
		&"lead_seconds": 0.35,
		&"lead_distance": 1.25,
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


static func attack_pattern(kind: StringName) -> StringName:
	if kind == WORM_KIND:
		return PATTERN_BREACH
	return FAUNA.get(kind, {}).get(&"pattern", PATTERN_FROST_POUNCE) as StringName


static func tracking_state(kind: StringName, state: StringName) -> bool:
	return state == initial_state(kind)


static func vulnerable(kind: StringName, state: StringName) -> bool:
	return state == (STATE_EXPOSE if kind == WORM_KIND else STATE_RECOVER)


static func legal_primary_state(kind: StringName, state: StringName) -> bool:
	if kind == WORM_KIND:
		return state in [STATE_BURROW, STATE_INTERCEPT, STATE_EXPOSE, STATE_DIVE]
	if kind == SKIMMER_KIND:
		return state in [STATE_SKIM, STATE_WAKE_SWEEP, STATE_RECOVER]
	if kind == RIME_KIND:
		return state in [STATE_STALK, STATE_POUNCE, STATE_RECOVER]
	if kind == CINDER_KIND:
		return state in [STATE_BRACE, STATE_EMBER_SALVO, STATE_RECOVER]
	return false


static func state_duration(kind: StringName, state: StringName, profile: Resource) -> float:
	if kind == WORM_KIND:
		return float(profile.call("state_duration", state))
	var data: Dictionary = FAUNA.get(kind, {}) as Dictionary
	if state == initial_state(kind):
		return float(data.get(&"tracking_seconds", 0.75))
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
