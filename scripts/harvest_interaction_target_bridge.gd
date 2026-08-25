extends RefCounted

const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const TargetScript: GDScript = preload("res://scripts/interaction_target_snapshot.gd")

const DEFAULT_PRIORITY: int = 500


static func project(cell: Vector2i, legacy: Variant) -> Dictionary:
	if not legacy is Dictionary:
		return {}
	var source: Dictionary = legacy as Dictionary
	if bool(source.get(&"out_of_bounds", false)):
		return {}
	var kinds: Array[StringName] = _kinds(source)
	if kinds.is_empty():
		return {}
	var kind: StringName = _primary_kind(kinds)
	var subkind: StringName = _subkind(kind, source)
	var target_id: StringName = _target_id(cell, kind, subkind, source)
	var state: Dictionary = {
		&"blocked": bool(source.get(&"blocked", false)),
		&"home": bool(source.get(&"home", false)),
		&"machine": bool(source.get(&"machine", false)),
		&"tool_damage": bool(source.get(&"tool_damage", false)),
	}
	if source.get(&"target_state", {}) is Dictionary:
		for raw_key: Variant in source[&"target_state"] as Dictionary:
			if raw_key is StringName:
				state[raw_key] = (source[&"target_state"] as Dictionary)[raw_key]
	var inputs: Array[Dictionary] = []
	var input_values: Variant = source.get(&"option_inputs", [])
	if not input_values is Array:
		return {}
	for raw_input: Variant in input_values as Array:
		if not raw_input is Dictionary:
			return {}
		inputs.append((raw_input as Dictionary).duplicate(true))
	return TargetScript.build(
		cell,
		target_id,
		kind,
		subkind,
		StringName("interaction.target.%s.title" % str(subkind)),
		state,
		inputs,
	)


static func option_input(
	action_id: StringName,
	operation: StringName,
	arguments: Dictionary,
	enabled: bool = true,
	reason_key: StringName = &"",
	priority: int = DEFAULT_PRIORITY,
	cost_preview: Array[Dictionary] = [],
	close_behavior: StringName = OptionScript.CLOSE_ON_SUCCESS,
) -> Dictionary:
	return {
		&"action_id": action_id,
		&"operation": operation,
		&"arguments": arguments,
		&"enabled": enabled,
		&"label_key": StringName("%s.label" % str(action_id)),
		&"reason_key": reason_key,
		&"priority": priority,
		&"cost_preview": cost_preview,
		&"close_behavior": close_behavior,
	}


static func _kinds(source: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	var supplied: Variant = source.get(&"kinds", [])
	if not supplied is Array:
		return result
	for value: Variant in supplied as Array:
		if not value is StringName:
			continue
		var kind: StringName = value as StringName
		if kind in ResolverScript.PRIORITY and kind not in result:
			result.append(kind)
	return result


static func _primary_kind(kinds: Array[StringName]) -> StringName:
	for candidate: StringName in ResolverScript.PRIORITY:
		if candidate in kinds:
			return candidate
	return &""


static func _subkind(kind: StringName, source: Dictionary) -> StringName:
	var explicit: Variant = source.get(&"target_subkind", &"")
	if explicit is StringName and not str(explicit).is_empty():
		return explicit as StringName
	if kind == ResolverScript.KIND_STRUCTURE:
		if bool(source.get(&"home", false)):
			return &"home"
		if bool(source.get(&"machine", false)):
			return &"machine"
		return &"facility"
	if kind == ResolverScript.KIND_FRIENDLY_FAUNA:
		return &"wilderness"
	return kind


static func _target_id(
	cell: Vector2i,
	kind: StringName,
	subkind: StringName,
	source: Dictionary,
) -> StringName:
	var explicit: Variant = source.get(&"target_id", &"")
	if explicit is StringName and not str(explicit).is_empty():
		return explicit as StringName
	return StringName("interaction.target.%s.%s.%d.%d" % [kind, subkind, cell.x, cell.y])
