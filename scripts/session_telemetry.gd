extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const MAX_EVENTS: int = 64
const MAX_PAYLOAD_FIELDS: int = 8
const MAX_TEXT_LENGTH: int = 64

var _events: Array[Dictionary] = []
var _next_sequence: int = 1


func record(event_id: StringName, payload: Dictionary = {}) -> bool:
	if not RuntimeIdsScript.is_event_id(event_id):
		return false
	(
		_events
		. append(
			{
				&"sequence": _next_sequence,
				&"event_id": event_id,
				&"payload": _sanitize_payload(payload),
			}
		)
	)
	_next_sequence += 1
	while _events.size() > MAX_EVENTS:
		_events.pop_front()
	return true


func get_events() -> Array[Dictionary]:
	return _events.duplicate(true)


func get_summary() -> Dictionary:
	var counts: Dictionary = {}
	for event: Dictionary in _events:
		var event_id: StringName = event[&"event_id"] as StringName
		counts[event_id] = int(counts.get(event_id, 0)) + 1
	return {
		&"local_only": true,
		&"capacity": MAX_EVENTS,
		&"event_count": _events.size(),
		&"counts": counts,
	}


func clear() -> void:
	_events.clear()
	_next_sequence = 1


func _sanitize_payload(payload: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_key: Variant in payload:
		if result.size() >= MAX_PAYLOAD_FIELDS:
			break
		var key: String = str(raw_key).left(MAX_TEXT_LENGTH)
		if key.is_empty():
			continue
		var value: Variant = payload[raw_key]
		match typeof(value):
			TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
				result[key] = value
			TYPE_VECTOR2I:
				var cell: Vector2i = value as Vector2i
				result[key] = [cell.x, cell.y]
			_:
				result[key] = str(value).left(MAX_TEXT_LENGTH)
	return result
