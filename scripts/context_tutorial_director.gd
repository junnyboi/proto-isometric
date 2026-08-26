extends RefCounted

signal state_changed(snapshot: Dictionary)
signal persistence_failed(reason: StringName)

const StateScript: GDScript = preload("res://scripts/context_tutorial_state.gd")
const EventScript: GDScript = preload("res://scripts/context_tutorial_event.gd")

var _state: Dictionary = {}
var _commit: Callable
var _relevance_mask: int = StateScript.INITIAL_RELEVANCE_MASK
var _commit_count: int = 0


func configure(state: Dictionary, commit: Callable, legacy_onboarding_seen: bool = false) -> bool:
	var valid: Dictionary = StateScript.validate(state)
	if valid.is_empty() or not commit.is_valid():
		return false
	_state = valid
	_commit = commit
	var migrated: Dictionary = StateScript.migrate_legacy(_state, legacy_onboarding_seen)
	if migrated != _state:
		_persist(migrated)
	return true


func get_state() -> Dictionary:
	return _state.duplicate(true)


func get_current_lesson() -> int:
	return StateScript.current_lesson(_state, _relevance_mask)


func get_relevance_mask() -> int:
	return _relevance_mask


func get_commit_count() -> int:
	return _commit_count


func record_event(event: StringName, payload: Dictionary = {&"success": true}) -> Dictionary:
	return ingest({&"event_type": event, &"success": bool(payload.get(&"success", false))})


func ingest(event: Dictionary) -> Dictionary:
	var valid_event: Dictionary = EventScript.validate(event)
	if valid_event.is_empty():
		return {
			&"ok": false, &"changed": false, &"candidate": _state.duplicate(true),
			&"lesson": -1, &"reason": &"invalid_event",
		}
	var transition: Dictionary = StateScript.apply_event(
		_state,
		valid_event[&"event_type"] as StringName,
		{&"success": bool(valid_event[&"success"])},
	)
	if not bool(transition[&"ok"]) or not bool(transition[&"changed"]):
		return transition
	if not _persist(transition[&"candidate"] as Dictionary):
		transition[&"ok"] = false
		transition[&"changed"] = false
		transition[&"candidate"] = _state.duplicate(true)
		transition[&"reason"] = &"persistence_failed"
	return transition


func suppress() -> bool:
	return _persist_if_changed(StateScript.set_suppressed(_state, true))


func resume() -> bool:
	return _persist_if_changed(StateScript.set_suppressed(_state, false))


func reset_training() -> bool:
	return _persist_if_changed(StateScript.reset(_state))


func set_lesson_relevant(lesson: int, relevant: bool = true) -> bool:
	if lesson < 0 or lesson >= StateScript.LESSON_COUNT:
		return false
	var before: int = _relevance_mask
	if relevant:
		_relevance_mask |= 1 << lesson
	else:
		_relevance_mask &= ~(1 << lesson)
	if before != _relevance_mask:
		state_changed.emit(_state.duplicate(true))
	return true


func is_suppressed() -> bool:
	return bool(_state.get(&"suppressed", false))


func _persist_if_changed(candidate: Dictionary) -> bool:
	return false if candidate.is_empty() or candidate == _state else _persist(candidate)


func _persist(candidate: Dictionary) -> bool:
	var valid: Dictionary = StateScript.validate(candidate)
	if valid.is_empty():
		return false
	var result: Variant = _commit.call(valid.duplicate(true))
	var committed: Dictionary = _committed_state(result, valid)
	if committed.is_empty():
		persistence_failed.emit(&"tutorial_commit_failed")
		return false
	_state = committed
	_commit_count += 1
	state_changed.emit(_state.duplicate(true))
	return true


func _committed_state(result: Variant, fallback: Dictionary) -> Dictionary:
	if result is bool:
		return fallback if bool(result) else {}
	if not result is Dictionary:
		return {}
	var response: Dictionary = result as Dictionary
	if not bool(response.get(&"ok", false)):
		return {}
	return StateScript.validate(response.get(&"tutorial", fallback))
