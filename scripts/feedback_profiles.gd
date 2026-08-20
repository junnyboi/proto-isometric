extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const WHIFF: Resource = preload("res://data/feedback/smash_whiff.tres")
const HIT: Resource = preload("res://data/feedback/smash_hit.tres")
const HEAVY_HIT: Resource = preload("res://data/feedback/smash_heavy_hit.tres")
const DEFEAT: Resource = preload("res://data/feedback/smash_defeat.tres")
const BREAK: Resource = preload("res://data/feedback/smash_break.tres")
const LOCOMOTION_START: Resource = preload("res://data/feedback/locomotion_start.tres")
const WALK_CONTACT: Resource = preload("res://data/feedback/locomotion_walk_contact.tres")
const RUN: Resource = preload("res://data/feedback/locomotion_run.tres")
const RUN_CONTACT: Resource = preload("res://data/feedback/locomotion_run_contact.tres")
const REVERSE: Resource = preload("res://data/feedback/locomotion_reverse.tres")
const BLOCKED: Resource = preload("res://data/feedback/locomotion_blocked.tres")
const STOP: Resource = preload("res://data/feedback/locomotion_stop.tres")
const CHARGE_LOW: Resource = preload("res://data/feedback/charge_low.tres")
const CHARGE_HIGH: Resource = preload("res://data/feedback/charge_high.tres")


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
		RuntimeIdsScript.EVENT_LOCOMOTION_START:
			return LOCOMOTION_START
		RuntimeIdsScript.EVENT_LOCOMOTION_WALK_CONTACT:
			return WALK_CONTACT
		RuntimeIdsScript.EVENT_LOCOMOTION_RUN:
			return RUN
		RuntimeIdsScript.EVENT_LOCOMOTION_RUN_CONTACT:
			return RUN_CONTACT
		RuntimeIdsScript.EVENT_LOCOMOTION_REVERSE:
			return REVERSE
		RuntimeIdsScript.EVENT_LOCOMOTION_BLOCKED:
			return BLOCKED
		RuntimeIdsScript.EVENT_LOCOMOTION_STOP:
			return STOP
		RuntimeIdsScript.EVENT_CHARGE_LOW:
			return CHARGE_LOW
		RuntimeIdsScript.EVENT_CHARGE_HIGH:
			return CHARGE_HIGH
	return null


static func validate() -> bool:
	for profile: Resource in [
		WHIFF,
		HIT,
		HEAVY_HIT,
		DEFEAT,
		BREAK,
		LOCOMOTION_START,
		WALK_CONTACT,
		RUN,
		RUN_CONTACT,
		REVERSE,
		BLOCKED,
		STOP,
		CHARGE_LOW,
		CHARGE_HIGH,
	]:
		if profile == null or not bool(profile.call("validate")):
			return false
	return true
