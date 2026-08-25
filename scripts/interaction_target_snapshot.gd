extends RefCounted

const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")

const MAX_OPTION_INPUTS: int = OptionScript.MAX_OPTIONS
const INPUT_KEYS: Array[StringName] = [
	&"action_id",
	&"operation",
	&"arguments",
	&"enabled",
	&"label_key",
	&"reason_key",
	&"priority",
	&"cost_preview",
	&"close_behavior",
]
const KEYS: Array[StringName] = [
	&"target_cell",
	&"target_id",
	&"target_kind",
	&"target_subkind",
	&"target_title_key",
	&"state",
	&"option_inputs",
]


static func build(
	target_cell: Vector2i,
	target_id: StringName,
	target_kind: StringName,
	target_subkind: StringName,
	target_title_key: StringName,
	state: Dictionary = {},
	option_inputs: Array[Dictionary] = [],
) -> Dictionary:
	var normalized_state: Dictionary = CodecScript.canonical_dictionary(state)
	if not state.is_empty() and normalized_state.is_empty():
		return {}
	var normalized_inputs: Array[Dictionary] = []
	for option_input: Dictionary in option_inputs:
		var normalized: Dictionary = _normalize_input(option_input)
		if normalized.is_empty():
			return {}
		normalized_inputs.append(normalized)
	normalized_inputs.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return str(first[&"action_id"]) < str(second[&"action_id"])
	)
	var result: Dictionary = {
		&"target_cell": target_cell,
		&"target_id": target_id,
		&"target_kind": target_kind,
		&"target_subkind": target_subkind,
		&"target_title_key": target_title_key,
		&"state": normalized_state,
		&"option_inputs": normalized_inputs,
	}
	return result if validate(result) else {}


static func validate(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var target: Dictionary = value as Dictionary
	if target.keys() != KEYS:
		return false
	if (
		not target[&"target_cell"] is Vector2i
		or not target[&"target_id"] is StringName
		or not target[&"target_kind"] is StringName
		or not target[&"target_subkind"] is StringName
		or not target[&"target_title_key"] is StringName
		or not target[&"state"] is Dictionary
		or not target[&"option_inputs"] is Array
	):
		return false
	for key: StringName in [&"target_id", &"target_kind", &"target_subkind", &"target_title_key"]:
		if str(target[key]).is_empty() or str(target[key]).length() > 128:
			return false
	var state: Dictionary = target[&"state"] as Dictionary
	if CodecScript.canonical_dictionary(state) != state:
		return false
	var inputs: Array = target[&"option_inputs"] as Array
	if inputs.size() > MAX_OPTION_INPUTS:
		return false
	var previous: String = ""
	for input_value: Variant in inputs:
		if not input_value is Dictionary or not _input_is_valid(input_value as Dictionary):
			return false
		var action_id: String = str((input_value as Dictionary)[&"action_id"])
		if not previous.is_empty() and action_id <= previous:
			return false
		previous = action_id
	return true


static func _normalize_input(value: Dictionary) -> Dictionary:
	if value.keys() != INPUT_KEYS:
		return {}
	if not value[&"arguments"] is Dictionary or not value[&"cost_preview"] is Array:
		return {}
	var source_arguments: Dictionary = value[&"arguments"] as Dictionary
	var arguments: Dictionary = CodecScript.canonical_dictionary(source_arguments)
	if not source_arguments.is_empty() and arguments.is_empty():
		return {}
	var costs: Array[Dictionary] = []
	for cost_value: Variant in value[&"cost_preview"] as Array:
		if not cost_value is Dictionary:
			return {}
		var cost: Dictionary = cost_value as Dictionary
		if (
			cost.keys() != [&"cost_id", &"amount"]
			or not cost[&"cost_id"] is StringName
			or not cost[&"amount"] is int
		):
			return {}
		costs.append({&"cost_id": cost[&"cost_id"], &"amount": cost[&"amount"]})
	costs.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"cost_id"]) < str(b[&"cost_id"])
	)
	var result: Dictionary = {
		&"action_id": value[&"action_id"],
		&"operation": value[&"operation"],
		&"arguments": arguments,
		&"enabled": value[&"enabled"],
		&"label_key": value[&"label_key"],
		&"reason_key": value[&"reason_key"],
		&"priority": value[&"priority"],
		&"cost_preview": costs,
		&"close_behavior": value[&"close_behavior"],
	}
	return result if _input_is_valid(result) else {}


static func _input_is_valid(value: Dictionary) -> bool:
	if value.keys() != INPUT_KEYS:
		return false
	if (
		not value[&"action_id"] is StringName
		or not value[&"operation"] is StringName
		or not value[&"arguments"] is Dictionary
		or not value[&"enabled"] is bool
		or not value[&"label_key"] is StringName
		or not value[&"reason_key"] is StringName
		or not value[&"priority"] is int
		or not value[&"cost_preview"] is Array
		or not value[&"close_behavior"] is StringName
	):
		return false
	if (
		not str(value[&"action_id"]).begins_with("interaction.action.")
		or str(value[&"operation"]).is_empty()
	):
		return false
	if not bool(value[&"enabled"]) and str(value[&"reason_key"]).is_empty():
		return false
	if bool(value[&"enabled"]) and not str(value[&"reason_key"]).is_empty():
		return false
	var arguments: Dictionary = value[&"arguments"] as Dictionary
	if CodecScript.canonical_dictionary(arguments) != arguments:
		return false
	if (value[&"cost_preview"] as Array).size() > OptionScript.MAX_COST_ENTRIES:
		return false
	var previous: String = ""
	for cost_value: Variant in value[&"cost_preview"] as Array:
		if not cost_value is Dictionary:
			return false
		var cost: Dictionary = cost_value as Dictionary
		if (
			cost.keys() != [&"cost_id", &"amount"]
			or not cost[&"cost_id"] is StringName
			or not cost[&"amount"] is int
		):
			return false
		var cost_id: String = str(cost[&"cost_id"])
		if (
			cost_id.is_empty()
			or int(cost[&"amount"]) <= 0
			or (not previous.is_empty() and cost_id <= previous)
		):
			return false
		previous = cost_id
	return value[&"close_behavior"] in OptionScript.CLOSE_BEHAVIORS
