extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const STATE_VERSION: int = 1
const MAX_OFFER_SIZE: int = 2
const MAX_SUMMARY_FIELDS: int = 16

var _banked_relay_data: int = 0
var _banked_scrap: int = 0
var _success_count: int = 0
var _failure_count: int = 0
var _pending_modifier_offer: Array[StringName] = []
var _selected_next_modifier: StringName = RuntimeIdsScript.MODIFIER_NEUTRAL
var _last_run_summary: Dictionary = {}


func bank(relay_data: int, scrap: int) -> bool:
	if relay_data < 0 or scrap < 0:
		return false
	_banked_relay_data += relay_data
	_banked_scrap += scrap
	return true


func record_result(succeeded: bool, summary: Dictionary = {}) -> bool:
	if summary.size() > MAX_SUMMARY_FIELDS or not _is_safe_summary(summary):
		return false
	if succeeded:
		_success_count += 1
	else:
		_failure_count += 1
	_last_run_summary = summary.duplicate(true)
	return true


func set_modifier_offer(offer: Array) -> bool:
	if not _pending_modifier_offer.is_empty() or offer.size() > MAX_OFFER_SIZE:
		return false
	var unique: Dictionary = {}
	var typed_offer: Array[StringName] = []
	for raw_modifier: Variant in offer:
		var modifier_id: StringName = StringName(str(raw_modifier))
		if modifier_id not in RuntimeIdsScript.catalog()[&"modifiers"] or unique.has(modifier_id):
			return false
		unique[modifier_id] = true
		typed_offer.append(modifier_id)
	_pending_modifier_offer = typed_offer
	return true


func select_next_modifier(modifier_id: StringName) -> bool:
	if modifier_id not in _pending_modifier_offer:
		return false
	_selected_next_modifier = modifier_id
	_pending_modifier_offer.clear()
	return true


func get_value(key: StringName) -> Variant:
	return (
		{
			&"banked_relay_data": _banked_relay_data,
			&"banked_scrap": _banked_scrap,
			&"success_count": _success_count,
			&"failure_count": _failure_count,
			&"pending_modifier_offer": _pending_modifier_offer.duplicate(),
			&"selected_next_modifier": _selected_next_modifier,
			&"last_run_summary": _last_run_summary.duplicate(true),
		}
		. get(key)
	)


func to_dictionary() -> Dictionary:
	var offer: Array[String] = []
	for modifier_id: StringName in _pending_modifier_offer:
		offer.append(String(modifier_id))
	return {
		&"state_version": STATE_VERSION,
		&"banked_relay_data": _banked_relay_data,
		&"banked_scrap": _banked_scrap,
		&"success_count": _success_count,
		&"failure_count": _failure_count,
		&"pending_modifier_offer": offer,
		&"selected_next_modifier": String(_selected_next_modifier),
		&"last_run_summary": _last_run_summary.duplicate(true),
	}


func restore_dictionary(snapshot: Dictionary) -> bool:
	var validated: Dictionary = _validate_dictionary(snapshot)
	if validated.is_empty():
		return false
	_banked_relay_data = int(validated[&"banked_relay_data"])
	_banked_scrap = int(validated[&"banked_scrap"])
	_success_count = int(validated[&"success_count"])
	_failure_count = int(validated[&"failure_count"])
	_pending_modifier_offer = validated[&"pending_modifier_offer"] as Array[StringName]
	_selected_next_modifier = validated[&"selected_next_modifier"] as StringName
	_last_run_summary = validated[&"last_run_summary"] as Dictionary
	return true


func _validate_dictionary(snapshot: Dictionary) -> Dictionary:
	if not _has_typed_fields(snapshot) or int(snapshot["state_version"]) != STATE_VERSION:
		return {}
	var relay_data: int = int(snapshot.get("banked_relay_data", -1))
	var scrap: int = int(snapshot.get("banked_scrap", -1))
	var successes: int = int(snapshot.get("success_count", -1))
	var failures: int = int(snapshot.get("failure_count", -1))
	var raw_offer: Variant = snapshot.get("pending_modifier_offer", null)
	var selected: StringName = StringName(str(snapshot.get("selected_next_modifier", "")))
	var summary: Variant = snapshot.get("last_run_summary", null)
	if (
		relay_data < 0
		or scrap < 0
		or successes < 0
		or failures < 0
		or not raw_offer is Array
		or (raw_offer as Array).size() > MAX_OFFER_SIZE
		or selected not in RuntimeIdsScript.catalog()[&"modifiers"]
		or not summary is Dictionary
		or (summary as Dictionary).size() > MAX_SUMMARY_FIELDS
		or not _is_safe_summary(summary as Dictionary)
	):
		return {}
	var offer: Array[StringName] = []
	for raw_modifier: Variant in raw_offer as Array:
		if not raw_modifier is String and not raw_modifier is StringName:
			return {}
		var modifier_id: StringName = StringName(str(raw_modifier))
		if modifier_id not in RuntimeIdsScript.catalog()[&"modifiers"] or modifier_id in offer:
			return {}
		offer.append(modifier_id)
	return {
		&"banked_relay_data": relay_data,
		&"banked_scrap": scrap,
		&"success_count": successes,
		&"failure_count": failures,
		&"pending_modifier_offer": offer,
		&"selected_next_modifier": selected,
		&"last_run_summary": (summary as Dictionary).duplicate(true),
	}


func _is_safe_summary(summary: Dictionary) -> bool:
	for key: Variant in summary:
		if str(key).length() > 64:
			return false
		var value: Variant = summary[key]
		if typeof(value) not in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]:
			return false
		if (value is String or value is StringName) and str(value).length() > 128:
			return false
	return true


func _has_typed_fields(snapshot: Dictionary) -> bool:
	return (
		snapshot.get("state_version") is int
		and snapshot.get("banked_relay_data") is int
		and snapshot.get("banked_scrap") is int
		and snapshot.get("success_count") is int
		and snapshot.get("failure_count") is int
		and snapshot.get("pending_modifier_offer") is Array
		and (
			snapshot.get("selected_next_modifier") is String
			or snapshot.get("selected_next_modifier") is StringName
		)
		and snapshot.get("last_run_summary") is Dictionary
	)
