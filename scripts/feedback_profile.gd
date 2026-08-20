extends Resource

@export var profile_id: StringName = &"feedback.none"
@export_range(0.0, 0.12, 0.001) var local_hold_seconds: float = 0.0
@export_range(0.0, 0.4, 0.001) var camera_duration_seconds: float = 0.0
@export_range(0.0, 12.0, 0.1) var camera_strength: float = 0.0
@export_range(0, 32, 1) var particle_count: int = 0
@export_range(0.0, 1.0, 0.01) var haptic_weak: float = 0.0
@export_range(0.0, 1.0, 0.01) var haptic_strong: float = 0.0
@export_range(0.0, 0.3, 0.001) var haptic_duration_seconds: float = 0.0
@export_range(0, 100, 1) var priority: int = 0


func validate() -> bool:
	return (
		str(profile_id).begins_with("feedback.")
		and local_hold_seconds >= 0.0
		and local_hold_seconds <= 0.12
		and camera_duration_seconds >= 0.0
		and camera_duration_seconds <= 0.4
		and camera_strength >= 0.0
		and camera_strength <= 12.0
		and particle_count >= 0
		and particle_count <= 32
		and haptic_weak >= 0.0
		and haptic_weak <= 1.0
		and haptic_strong >= 0.0
		and haptic_strong <= 1.0
		and haptic_duration_seconds >= 0.0
		and haptic_duration_seconds <= 0.3
		and priority >= 0
		and priority <= 100
	)


func to_dictionary() -> Dictionary:
	return {
		&"profile_id": profile_id,
		&"local_hold_seconds": local_hold_seconds,
		&"camera_duration_seconds": camera_duration_seconds,
		&"camera_strength": camera_strength,
		&"particle_count": particle_count,
		&"haptic_weak": haptic_weak,
		&"haptic_strong": haptic_strong,
		&"haptic_duration_seconds": haptic_duration_seconds,
		&"priority": priority,
	}
