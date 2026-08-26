extends Resource

@export_category("Identity and Damage")
@export var max_health: int = 4
@export var attack_damage: int = 10
@export var max_worms: int = 4

@export_category("Detection and Motion")
@export var detection_range: float = 8.0
@export var attack_range: float = 0.72
@export var burrow_speed: float = 1.28
@export var intercept_speed: float = 2.4
@export var maximum_lead_seconds: float = 0.45
@export var maximum_lead_distance: float = 1.75
@export var expose_offset: float = 0.68

@export_category("State Timings")
@export var spawn_burrow_seconds: float = 0.8
@export var burrow_seconds: float = 0.55
@export var intercept_seconds: float = 0.65
@export var expose_seconds: float = 1.6
@export var dive_seconds: float = 0.45
@export var stagger_seconds: float = 0.85
@export var maximum_stagger_seconds: float = 1.6
@export var disperse_seconds: float = 1.5
@export var defeated_seconds: float = 0.65

@export_category("Hard Bounds")
@export var maximum_transitions_per_advance: int = 8


func validate() -> bool:
	return (
		max_health == 4
		and attack_damage == 10
		and max_worms > 0
		and detection_range > attack_range
		and attack_range > 0.0
		and burrow_speed > 0.0
		and intercept_speed >= burrow_speed
		and maximum_lead_seconds >= 0.0
		and maximum_lead_distance >= 0.0
		and expose_offset > 0.0
		and expose_offset <= attack_range
		and spawn_burrow_seconds >= 0.0
		and burrow_seconds > 0.0
		and intercept_seconds > 0.0
		and expose_seconds > 0.0
		and dive_seconds > 0.0
		and stagger_seconds > 0.0
		and maximum_stagger_seconds >= stagger_seconds
		and disperse_seconds > 0.0
		and defeated_seconds > 0.0
		and maximum_transitions_per_advance >= 4
		and maximum_transitions_per_advance <= 16
	)


func timing_snapshot() -> Dictionary:
	return {
		&"burrow": burrow_seconds,
		&"intercept": intercept_seconds,
		&"expose": expose_seconds,
		&"dive": dive_seconds,
		&"staggered": stagger_seconds,
		&"dispersing": disperse_seconds,
		&"defeated": defeated_seconds,
	}


func state_duration(state: StringName) -> float:
	var durations: Dictionary = timing_snapshot()
	return float(durations.get(state, 0.0))
