extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

var _avatar: Node2D
var _enemies: Node2D
var _presentation_count: int = 0


func bind_sources(avatar: Node2D, enemies: Node2D) -> bool:
	_avatar = avatar
	_enemies = enemies
	return _avatar != null and _enemies != null


func present(event: Dictionary, profile: Dictionary) -> bool:
	var event_id: StringName = event.get(&"event_id", &"") as StringName
	if event_id == RuntimeIdsScript.EVENT_SMASH_WHIFF:
		return false
	var direction: Vector2 = event.get(&"direction", Vector2.RIGHT) as Vector2
	var strength: int = int(event.get(&"strength", 0))
	var hold: float = float(profile.get(&"local_hold_seconds", 0.0))
	if _avatar != null:
		_avatar.call("_apply_impact_presentation", hold, direction, strength)
	var target_id: int = int(event.get(&"target_id", -1))
	if target_id >= 0 and _enemies != null:
		_enemies.call("present_hit_feedback", target_id, direction, strength, hold)
	_presentation_count += 1
	return true


func get_presentation_count() -> int:
	return _presentation_count
