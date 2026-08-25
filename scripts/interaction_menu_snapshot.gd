extends RefCounted

const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")

const MAX_OPTIONS: int = OptionScript.MAX_OPTIONS
const KEYS: Array[StringName] = [
	&"snapshot_id",
	&"target_cell",
	&"target_id",
	&"target_kind",
	&"target_subkind",
	&"target_title_key",
	&"target_state",
	&"options",
]


static func build(
	target_cell: Vector2i,
	target_id: StringName,
	target_kind: StringName,
	target_subkind: StringName,
	target_title_key: StringName,
	target_state: Dictionary,
	options: Array[Dictionary],
) -> Dictionary:
	var normalized_state: Dictionary = CodecScript.canonical_dictionary(target_state)
	if not target_state.is_empty() and normalized_state.is_empty():
		return {}
	var normalized_options: Array[Dictionary] = []
	for option: Dictionary in options:
		var normalized: Dictionary = OptionScript.canonical_copy(option)
		if normalized.is_empty():
			return {}
		normalized_options.append(normalized)
	normalized_options.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return OptionScript.sort_key(first) < OptionScript.sort_key(second)
	)
	if _has_duplicate_ids(normalized_options):
		return {}
	var unsigned: Dictionary = {
		&"snapshot_id": &"pending",
		&"target_cell": target_cell,
		&"target_id": target_id,
		&"target_kind": target_kind,
		&"target_subkind": target_subkind,
		&"target_title_key": target_title_key,
		&"target_state": normalized_state,
		&"options": normalized_options,
	}
	unsigned[&"snapshot_id"] = StringName("interaction.snapshot.%s" % _payload_digest(unsigned))
	return unsigned if validate(unsigned) else {}


static func validate(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var snapshot: Dictionary = value as Dictionary
	if snapshot.keys() != KEYS:
		return false
	if (
		not snapshot[&"snapshot_id"] is StringName
		or not snapshot[&"target_cell"] is Vector2i
		or not snapshot[&"target_id"] is StringName
		or not snapshot[&"target_kind"] is StringName
		or not snapshot[&"target_subkind"] is StringName
		or not snapshot[&"target_title_key"] is StringName
		or not snapshot[&"target_state"] is Dictionary
		or not snapshot[&"options"] is Array
	):
		return false
	if (
		not str(snapshot[&"snapshot_id"]).begins_with("interaction.snapshot.")
		or str(snapshot[&"target_id"]).is_empty()
		or str(snapshot[&"target_kind"]).is_empty()
		or str(snapshot[&"target_title_key"]).is_empty()
	):
		return false
	var state: Dictionary = snapshot[&"target_state"] as Dictionary
	if CodecScript.canonical_dictionary(state) != state:
		return false
	var options: Array = snapshot[&"options"] as Array
	if options.is_empty() or options.size() > MAX_OPTIONS:
		return false
	var normalized: Array[Dictionary] = []
	for option_value: Variant in options:
		if not OptionScript.validate(option_value):
			return false
		var option: Dictionary = option_value as Dictionary
		if (
			option[&"target_id"] != snapshot[&"target_id"]
			or option[&"target_kind"] != snapshot[&"target_kind"]
		):
			return false
		normalized.append(option)
	if _has_duplicate_ids(normalized):
		return false
	for index: int in range(1, normalized.size()):
		if OptionScript.sort_key(normalized[index - 1]) >= OptionScript.sort_key(normalized[index]):
			return false
	return str(snapshot[&"snapshot_id"]) == "interaction.snapshot.%s" % _payload_digest(snapshot)


static func canonical_text(value: Variant) -> String:
	return CodecScript.text(value) if validate(value) else ""


static func _payload_digest(snapshot: Dictionary) -> String:
	var unsigned: Dictionary = snapshot.duplicate(true)
	unsigned[&"snapshot_id"] = &""
	return CodecScript.digest(unsigned).left(32)


static func _has_duplicate_ids(options: Array[Dictionary]) -> bool:
	var seen: Dictionary = {}
	for option: Dictionary in options:
		var action_id: StringName = option[&"action_id"] as StringName
		if seen.has(action_id):
			return true
		seen[action_id] = true
	return false
