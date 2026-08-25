extends RefCounted

const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")

const MAX_OPTIONS: int = 32
const MAX_AFFECTED_CELLS: int = 16
const MAX_COST_ENTRIES: int = 16
const MAX_ARGUMENT_KEYS: int = 24
const CLOSE_ALWAYS: StringName = &"always"
const CLOSE_NEVER: StringName = &"never"
const CLOSE_ON_SUCCESS: StringName = &"on_success"
const CLOSE_BEHAVIORS: Array[StringName] = [CLOSE_ALWAYS, CLOSE_NEVER, CLOSE_ON_SUCCESS]
const KEYS: Array[StringName] = [
	&"action_id",
	&"provider_id",
	&"target_id",
	&"target_kind",
	&"target_subkind",
	&"operation",
	&"arguments",
	&"enabled",
	&"label_key",
	&"reason_key",
	&"priority",
	&"affected_cells",
	&"cost_preview",
	&"close_behavior",
]


static func build(
	action_id: StringName,
	provider_id: StringName,
	target_id: StringName,
	target_kind: StringName,
	target_subkind: StringName,
	operation: StringName,
	arguments: Dictionary = {},
	enabled: bool = true,
	label_key: StringName = &"",
	reason_key: StringName = &"",
	priority: int = 0,
	affected_cells: Array[Vector2i] = [],
	cost_preview: Array[Dictionary] = [],
	close_behavior: StringName = CLOSE_ON_SUCCESS,
) -> Dictionary:
	var normalized_arguments: Dictionary = CodecScript.canonical_dictionary(arguments)
	if not arguments.is_empty() and normalized_arguments.is_empty():
		return {}
	var normalized_cells: Array[Vector2i] = affected_cells.duplicate()
	normalized_cells.sort_custom(_cell_less)
	var normalized_costs: Array[Dictionary] = _normalize_costs(cost_preview)
	if not cost_preview.is_empty() and normalized_costs.is_empty():
		return {}
	var option: Dictionary = {
		&"action_id": action_id,
		&"provider_id": provider_id,
		&"target_id": target_id,
		&"target_kind": target_kind,
		&"target_subkind": target_subkind,
		&"operation": operation,
		&"arguments": normalized_arguments,
		&"enabled": enabled,
		&"label_key": label_key,
		&"reason_key": reason_key,
		&"priority": priority,
		&"affected_cells": normalized_cells,
		&"cost_preview": normalized_costs,
		&"close_behavior": close_behavior,
	}
	return option if validate(option) else {}


static func validate(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var option: Dictionary = value as Dictionary
	if option.keys() != KEYS:
		return false
	if (
		not option[&"action_id"] is StringName
		or not option[&"provider_id"] is StringName
		or not option[&"target_id"] is StringName
		or not option[&"target_kind"] is StringName
		or not option[&"target_subkind"] is StringName
		or not option[&"operation"] is StringName
		or not option[&"arguments"] is Dictionary
		or not option[&"enabled"] is bool
		or not option[&"label_key"] is StringName
		or not option[&"reason_key"] is StringName
		or not option[&"priority"] is int
		or not option[&"affected_cells"] is Array
		or not option[&"cost_preview"] is Array
		or not option[&"close_behavior"] is StringName
	):
		return false
	if (
		not _stable_id(option[&"action_id"], "interaction.action.")
		or not _stable_id(option[&"provider_id"], "interaction.provider.")
		or not _stable_id(option[&"target_id"])
		or not _stable_id(option[&"target_kind"])
		or (not str(option[&"target_subkind"]).is_empty() and not _stable_id(option[&"target_subkind"]))
		or not _stable_id(option[&"operation"])
		or not _stable_id(option[&"label_key"])
		or option[&"close_behavior"] not in CLOSE_BEHAVIORS
	):
		return false
	if not bool(option[&"enabled"]) and not _stable_id(option[&"reason_key"]):
		return false
	if bool(option[&"enabled"]) and not str(option[&"reason_key"]).is_empty():
		return false
	var arguments: Dictionary = option[&"arguments"] as Dictionary
	if (
		arguments.size() > MAX_ARGUMENT_KEYS
		or CodecScript.canonical_dictionary(arguments) != arguments
	):
		return false
	if not _cells_are_canonical(option[&"affected_cells"] as Array):
		return false
	return _costs_are_canonical(option[&"cost_preview"] as Array)


static func canonical_copy(value: Variant) -> Dictionary:
	if not validate(value):
		return {}
	return (value as Dictionary).duplicate(true)


static func sort_key(option: Dictionary) -> String:
	return "%08d|%s|%s|%s" % [
		int(option[&"priority"]) + 1_000_000,
		str(option[&"provider_id"]),
		str(option[&"action_id"]),
		str(option[&"target_id"]),
	]


static func _normalize_costs(costs: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if costs.size() > MAX_COST_ENTRIES:
		return result
	for cost: Dictionary in costs:
		if (
			cost.keys() != [&"cost_id", &"amount"]
			or not cost[&"cost_id"] is StringName
			or not cost[&"amount"] is int
		):
			return []
		var normalized: Dictionary = {
			&"cost_id": cost[&"cost_id"],
			&"amount": cost[&"amount"],
		}
		result.append(normalized)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"cost_id"]) < str(b[&"cost_id"])
	)
	return result


static func _costs_are_canonical(costs: Array) -> bool:
	if costs.size() > MAX_COST_ENTRIES:
		return false
	var previous: String = ""
	for cost_value: Variant in costs:
		if not cost_value is Dictionary:
			return false
		var cost: Dictionary = cost_value as Dictionary
		if cost.keys() != [&"cost_id", &"amount"]:
			return false
		if not cost[&"cost_id"] is StringName or not cost[&"amount"] is int:
			return false
		var cost_id: String = str(cost[&"cost_id"])
		if (
			not _stable_id(cost[&"cost_id"])
			or int(cost[&"amount"]) <= 0
			or (not previous.is_empty() and cost_id <= previous)
		):
			return false
		previous = cost_id
	return true


static func _cells_are_canonical(cells: Array) -> bool:
	if cells.is_empty() or cells.size() > MAX_AFFECTED_CELLS:
		return false
	var previous: Vector2i
	for index: int in cells.size():
		if not cells[index] is Vector2i:
			return false
		var cell: Vector2i = cells[index] as Vector2i
		if index > 0 and (cell == previous or _cell_less(cell, previous)):
			return false
		previous = cell
	return true


static func _stable_id(value: Variant, prefix: String = "") -> bool:
	if not value is StringName:
		return false
	var identifier: String = str(value)
	return (
		not identifier.is_empty()
		and identifier.length() <= 128
		and (prefix.is_empty() or identifier.begins_with(prefix))
	)


static func _cell_less(first: Vector2i, second: Vector2i) -> bool:
	return first.y < second.y or (first.y == second.y and first.x < second.x)
