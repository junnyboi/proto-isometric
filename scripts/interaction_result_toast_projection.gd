extends RefCounted

const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const ExecutionResultScript: GDScript = preload("res://scripts/interaction_execution_result.gd")

const MIN_DURATION_MSEC: int = 2500
const MAX_DURATION_MSEC: int = 5000
const SUCCESS_DURATION_MSEC: int = 3500
const FAILURE_DURATION_MSEC: int = 5000
const INFORMATION_DURATION_MSEC: int = 2500
const TONES: Array[StringName] = [&"failure", &"information", &"success"]
const KEYS: Array[StringName] = [
	&"toast_id",
	&"source_result_id",
	&"tone",
	&"title_key",
	&"body_key",
	&"parameters",
	&"reason_key",
	&"duration_msec",
]


static func build(
	value: Variant,
	operation_descriptor: Dictionary = {},
) -> Dictionary:
	if not ExecutionResultScript.validate(value, operation_descriptor):
		return {}
	var result: Dictionary = value as Dictionary
	var view: Dictionary = result[&"view"] as Dictionary
	var tone: StringName = _tone_for(result)
	var toast: Dictionary = {
		&"toast_id": StringName("interaction.toast.%s" % str(result[&"result_id"])),
		&"source_result_id": result[&"result_id"],
		&"tone": tone,
		&"title_key": view[&"title_key"],
		&"body_key": view[&"body_key"],
		&"parameters": (view[&"parameters"] as Dictionary).duplicate(true),
		&"reason_key": result[&"reason_key"],
		&"duration_msec": _duration_for(tone),
	}
	return toast if validate(toast) else {}


static func validate(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var toast: Dictionary = value as Dictionary
	if toast.keys() != KEYS:
		return false
	if (
		not _stable_id(toast[&"toast_id"], "interaction.toast.interaction.result.")
		or not _stable_id(toast[&"source_result_id"], "interaction.result.")
		or toast[&"tone"] not in TONES
		or not _stable_id(toast[&"title_key"])
		or not _stable_id(toast[&"body_key"])
		or not toast[&"parameters"] is Dictionary
		or not toast[&"reason_key"] is StringName
		or not toast[&"duration_msec"] is int
	):
		return false
	if str(toast[&"toast_id"]) != "interaction.toast.%s" % str(toast[&"source_result_id"]):
		return false
	if not _reason_matches_tone(toast[&"tone"], toast[&"reason_key"]):
		return false
	var duration: int = int(toast[&"duration_msec"])
	var parameters: Dictionary = toast[&"parameters"] as Dictionary
	return (
		duration >= MIN_DURATION_MSEC
		and duration <= MAX_DURATION_MSEC
		and CodecScript.canonical_dictionary(parameters) == parameters
	)


static func canonical_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if validate(value) else {}


static func should_replace(current: Variant, incoming: Variant) -> bool:
	if not validate(incoming):
		return false
	if not validate(current):
		return true
	var current_toast: Dictionary = current as Dictionary
	var incoming_toast: Dictionary = incoming as Dictionary
	if incoming_toast[&"source_result_id"] == current_toast[&"source_result_id"]:
		return false
	return (
		incoming_toast[&"tone"] == &"failure"
		or current_toast[&"tone"] == &"information"
	)


static func _tone_for(result: Dictionary) -> StringName:
	if not bool(result[&"ok"]):
		return &"failure"
	return &"success" if bool(result[&"mutated"]) else &"information"


static func _duration_for(tone: StringName) -> int:
	match tone:
		&"failure":
			return FAILURE_DURATION_MSEC
		&"success":
			return SUCCESS_DURATION_MSEC
	return INFORMATION_DURATION_MSEC


static func _reason_matches_tone(tone: Variant, reason_key: Variant) -> bool:
	if tone == &"failure":
		return _stable_id(reason_key, "interaction.reason.")
	return reason_key == &""


static func _stable_id(value: Variant, prefix: String = "") -> bool:
	if not value is StringName:
		return false
	var identifier: String = str(value)
	return (
		not identifier.is_empty()
		and identifier.length() <= CodecScript.MAX_TEXT_LENGTH
		and (prefix.is_empty() or identifier.begins_with(prefix))
	)
