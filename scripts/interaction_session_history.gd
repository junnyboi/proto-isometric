extends RefCounted

const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const ExecutionResultScript: GDScript = preload("res://scripts/interaction_execution_result.gd")

const MAX_RECORDS: int = 16
const MAX_PROJECTED_RECORDS: int = 8
const RECORD_KEYS: Array[StringName] = [
	&"sequence",
	&"result_id",
	&"action_id",
	&"target_id",
	&"target_cell",
	&"ok",
	&"mutated",
	&"title_key",
	&"body_key",
	&"parameters",
	&"reason_key",
]

var _records: Array[Dictionary] = []
var _next_sequence: int = 1
var _seen_result_ids: Dictionary = {}


func append_result(value: Variant, operation_descriptor: Dictionary = {}) -> bool:
	if not ExecutionResultScript.validate(value, operation_descriptor):
		return false
	var result: Dictionary = value as Dictionary
	var result_id: StringName = result[&"result_id"] as StringName
	if _seen_result_ids.has(result_id):
		return false
	var view: Dictionary = result[&"view"] as Dictionary
	var record: Dictionary = {
		&"sequence": _next_sequence,
		&"result_id": result_id,
		&"action_id": result[&"action_id"],
		&"target_id": result[&"target_id"],
		&"target_cell": result[&"target_cell"],
		&"ok": result[&"ok"],
		&"mutated": result[&"mutated"],
		&"title_key": view[&"title_key"],
		&"body_key": view[&"body_key"],
		&"parameters": (view[&"parameters"] as Dictionary).duplicate(true),
		&"reason_key": result[&"reason_key"],
	}
	if not validate_record(record):
		return false
	_records.append(record)
	_seen_result_ids[result_id] = true
	_next_sequence += 1
	if _records.size() > MAX_RECORDS:
		_records.pop_front()
	return true


func records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in _records:
		result.append(record.duplicate(true))
	return result


func project_for_target(target_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _stable_id(target_id):
		return result
	for index: int in range(_records.size() - 1, -1, -1):
		var record: Dictionary = _records[index]
		if record[&"target_id"] != target_id:
			continue
		result.append(record.duplicate(true))
		if result.size() == MAX_PROJECTED_RECORDS:
			break
	return result


func clear() -> void:
	_records.clear()
	_seen_result_ids.clear()


func size() -> int:
	return _records.size()


static func validate_record(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var record: Dictionary = value as Dictionary
	if record.keys() != RECORD_KEYS:
		return false
	if (
		not record[&"sequence"] is int
		or int(record[&"sequence"]) <= 0
		or not _stable_id(record[&"result_id"], "interaction.result.")
		or not _stable_id(record[&"action_id"], "interaction.action.")
		or not _stable_id(record[&"target_id"])
		or not record[&"target_cell"] is Vector2i
		or not record[&"ok"] is bool
		or not record[&"mutated"] is bool
		or not _stable_id(record[&"title_key"])
		or not _stable_id(record[&"body_key"])
		or not record[&"parameters"] is Dictionary
		or not record[&"reason_key"] is StringName
	):
		return false
	if bool(record[&"mutated"]) and not bool(record[&"ok"]):
		return false
	if bool(record[&"ok"]) and record[&"reason_key"] != &"":
		return false
	if not bool(record[&"ok"]) and not _stable_id(
		record[&"reason_key"],
		"interaction.reason.",
	):
		return false
	var parameters: Dictionary = record[&"parameters"] as Dictionary
	return CodecScript.canonical_dictionary(parameters) == parameters


static func _stable_id(value: Variant, prefix: String = "") -> bool:
	if not value is StringName:
		return false
	var identifier: String = str(value)
	return (
		not identifier.is_empty()
		and identifier.length() <= CodecScript.MAX_TEXT_LENGTH
		and (prefix.is_empty() or identifier.begins_with(prefix))
	)
