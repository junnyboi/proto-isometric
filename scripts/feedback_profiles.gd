extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const WHIFF: Resource = preload("res://data/feedback/smash_whiff.tres")
const HIT: Resource = preload("res://data/feedback/smash_hit.tres")
const HEAVY_HIT: Resource = preload("res://data/feedback/smash_heavy_hit.tres")
const DEFEAT: Resource = preload("res://data/feedback/smash_defeat.tres")
const BREAK: Resource = preload("res://data/feedback/smash_break.tres")


static func resolve(event_id: StringName) -> Dictionary:
	var profile: Resource = profile_resource(event_id)
	return profile.call("to_dictionary") as Dictionary if profile != null else {}


static func profile_resource(event_id: StringName) -> Resource:
	match event_id:
		RuntimeIdsScript.EVENT_SMASH_WHIFF:
			return WHIFF
		RuntimeIdsScript.EVENT_SMASH_HIT:
			return HIT
		RuntimeIdsScript.EVENT_SMASH_HEAVY_HIT:
			return HEAVY_HIT
		RuntimeIdsScript.EVENT_SMASH_DEFEAT:
			return DEFEAT
		RuntimeIdsScript.EVENT_SMASH_BREAK:
			return BREAK
	return null


static func validate() -> bool:
	for profile: Resource in [WHIFF, HIT, HEAVY_HIT, DEFEAT, BREAK]:
		if profile == null or not bool(profile.call("validate")):
			return false
	return true
