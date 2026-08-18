extends Resource

@export var alert_level: int = 0
@export var worm_count: int = 0
@export var tornado_count: int = 0
@export var broad_storm_count: int = 0
@export var rearm_seconds: float = 4.0


func validate() -> bool:
	return (
		alert_level >= 1
		and alert_level <= 3
		and worm_count >= 0
		and worm_count <= 1
		and tornado_count >= 0
		and tornado_count <= 2
		and broad_storm_count >= 0
		and broad_storm_count <= 1
		and is_finite(rearm_seconds)
		and rearm_seconds >= 1.0
		and rearm_seconds <= 15.0
	)
