extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

static var _next_sequence_id: int = 1


static func create(
	event_id: StringName,
	position: Vector2,
	direction: Vector2,
	strength: int,
	material: StringName,
	target_id: int = -1,
	metadata: Dictionary = {},
) -> Dictionary:
	var sequence_id: int = _next_sequence_id
	_next_sequence_id += 1
	var normalized_direction: Vector2 = (
		Vector2.RIGHT if direction.is_zero_approx() else direction.normalized()
	)
	return {
		&"event_id": event_id,
		&"sequence_id": sequence_id,
		&"position": position,
		&"direction": normalized_direction,
		&"strength": clampi(strength, 0, 2),
		&"material": material,
		&"target_id": target_id,
		&"metadata": metadata.duplicate(true),
		&"issued_usec": Time.get_ticks_usec(),
	}


static func validate(event: Dictionary) -> bool:
	return (
		RuntimeIdsScript.is_event_id(event.get(&"event_id", &""))
		and int(event.get(&"sequence_id", 0)) > 0
		and event.get(&"position") is Vector2
		and event.get(&"direction") is Vector2
		and not (event.get(&"direction") as Vector2).is_zero_approx()
		and int(event.get(&"strength", -1)) >= 0
		and int(event.get(&"strength", -1)) <= 2
		and event.get(&"material") is StringName
		and event.get(&"metadata", {}) is Dictionary
		and int(event.get(&"issued_usec", 0)) >= 0
	)


static func reset_sequence_for_tests() -> void:
	_next_sequence_id = 1
