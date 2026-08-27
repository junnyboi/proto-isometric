extends RefCounted

const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const ExecutionResultScript: GDScript = preload("res://scripts/interaction_execution_result.gd")
const HistoryScript: GDScript = preload("res://scripts/interaction_session_history.gd")
const PreviewScript: GDScript = preload("res://scripts/interaction_outcome_preview_catalog.gd")
const ToastScript: GDScript = preload("res://scripts/interaction_result_toast_projection.gd")

const MAX_ACTIONS: int = 32
const MAX_CHIPS: int = 4
const MAX_HISTORY: int = 8
const MAX_NEARBY: int = 4
const MAX_SECTIONS: int = 4
const MAX_SUMMARY_ROWS: int = 12
const STATE_PREFIX: String = "interaction.dossier.state."
const PROFILES: Array[StringName] = [&"generic", &"object", &"terrain"]
const TONES: Array[StringName] = [
	&"caution",
	&"danger",
	&"information",
	&"neutral",
	&"positive",
]
const KEYS: Array[StringName] = [
	&"state_id",
	&"source_snapshot_id",
	&"target_id",
	&"target_cell",
	&"profile",
	&"portrait_id",
	&"title_key",
	&"subtitle_key",
	&"summary_sections",
	&"chips",
	&"action_ids",
	&"selected_action_id",
	&"preview",
	&"nearby",
	&"history",
	&"toast",
]
const SECTION_KEYS: Array[StringName] = [
	&"section_id",
	&"title_key",
	&"icon_id",
	&"rows",
]
const ROW_KEYS: Array[StringName] = [
	&"row_id",
	&"label_key",
	&"value_kind",
	&"value",
	&"tone",
]
const CHIP_KEYS: Array[StringName] = [
	&"chip_id",
	&"label_key",
	&"value_kind",
	&"value",
	&"tone",
]
const NEARBY_KEYS: Array[StringName] = [
	&"interest_id",
	&"kind",
	&"title_key",
	&"cell",
	&"source_revision",
	&"available",
	&"tile_distance",
	&"direction_id",
]


static func build(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var source: Dictionary = value as Dictionary
	if source.keys() != KEYS:
		return {}
	var result: Dictionary = source.duplicate(true)
	result[&"state_id"] = StringName("%s%s" % [STATE_PREFIX, _payload_digest(result)])
	return result if validate(result) else {}


static func validate(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var state: Dictionary = value as Dictionary
	if state.keys() != KEYS or not _scalar_fields_are_valid(state):
		return false
	if not _sections_are_valid(state[&"summary_sections"]):
		return false
	if not _chips_are_valid(state[&"chips"]):
		return false
	if not _actions_are_valid(state):
		return false
	if not _preview_is_valid(state):
		return false
	if not _nearby_are_valid(state[&"nearby"], state[&"target_id"]):
		return false
	if not _history_is_valid(state[&"history"], state[&"target_id"]):
		return false
	if not _toast_is_valid(state[&"toast"]):
		return false
	return str(state[&"state_id"]) == "%s%s" % [STATE_PREFIX, _payload_digest(state)]


static func canonical_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if validate(value) else {}


static func digest(value: Variant) -> StringName:
	if not value is Dictionary or (value as Dictionary).keys() != KEYS:
		return &""
	return StringName("%s%s" % [STATE_PREFIX, _payload_digest(value as Dictionary)])


static func canonical_text(value: Variant) -> String:
	return CodecScript.text(value) if validate(value) else ""


static func validate_nearby(value: Variant) -> bool:
	return _nearby_are_valid(value, &"")


static func _scalar_fields_are_valid(state: Dictionary) -> bool:
	return (
		_stable_id(state[&"state_id"], STATE_PREFIX)
		and _stable_id(state[&"source_snapshot_id"], "interaction.snapshot.")
		and _stable_id(state[&"target_id"])
		and state[&"target_cell"] is Vector2i
		and state[&"profile"] is StringName
		and state[&"profile"] in PROFILES
		and _optional_id(state[&"portrait_id"])
		and _stable_id(state[&"title_key"])
		and _optional_id(state[&"subtitle_key"])
		and state[&"summary_sections"] is Array
		and state[&"chips"] is Array
		and state[&"action_ids"] is Array
		and state[&"selected_action_id"] is StringName
		and state[&"preview"] is Dictionary
		and state[&"nearby"] is Array
		and state[&"history"] is Array
		and state[&"toast"] is Dictionary
	)


static func _sections_are_valid(value: Variant) -> bool:
	if not value is Array:
		return false
	var sections: Array = value as Array
	if sections.size() > MAX_SECTIONS:
		return false
	var seen: Dictionary = {}
	var total_rows: int = 0
	for raw_section: Variant in sections:
		if not raw_section is Dictionary:
			return false
		var section: Dictionary = raw_section as Dictionary
		if not _section_is_valid(section) or seen.has(section[&"section_id"]):
			return false
		seen[section[&"section_id"]] = true
		total_rows += (section[&"rows"] as Array).size()
	return total_rows <= MAX_SUMMARY_ROWS


static func _section_is_valid(section: Dictionary) -> bool:
	if section.keys() != SECTION_KEYS:
		return false
	if (
		not _stable_id(section[&"section_id"])
		or not _stable_id(section[&"title_key"])
		or not _stable_id(section[&"icon_id"])
		or not section[&"rows"] is Array
	):
		return false
	var seen: Dictionary = {}
	for raw_row: Variant in section[&"rows"] as Array:
		if not raw_row is Dictionary:
			return false
		var row: Dictionary = raw_row as Dictionary
		if not _row_is_valid(row) or seen.has(row[&"row_id"]):
			return false
		seen[row[&"row_id"]] = true
	return not (section[&"rows"] as Array).is_empty()


static func _row_is_valid(row: Dictionary) -> bool:
	return (
		row.keys() == ROW_KEYS
		and _stable_id(row[&"row_id"])
		and _stable_id(row[&"label_key"])
		and _value_is_valid(row[&"value_kind"], row[&"value"])
		and row[&"tone"] is StringName
		and row[&"tone"] in TONES
	)


static func _chips_are_valid(value: Variant) -> bool:
	if not value is Array or (value as Array).size() > MAX_CHIPS:
		return false
	var seen: Dictionary = {}
	for raw_chip: Variant in value as Array:
		if not raw_chip is Dictionary:
			return false
		var chip: Dictionary = raw_chip as Dictionary
		if (
			chip.keys() != CHIP_KEYS
			or not _stable_id(chip[&"chip_id"])
			or seen.has(chip[&"chip_id"])
			or not _stable_id(chip[&"label_key"])
			or not _value_is_valid(chip[&"value_kind"], chip[&"value"])
			or not chip[&"tone"] is StringName
			or chip[&"tone"] not in TONES
		):
			return false
		seen[chip[&"chip_id"]] = true
	return true


static func _actions_are_valid(state: Dictionary) -> bool:
	var actions: Array = state[&"action_ids"] as Array
	if actions.is_empty() or actions.size() > MAX_ACTIONS:
		return false
	var seen: Dictionary = {}
	for action_id: Variant in actions:
		if not _stable_id(action_id, "interaction.action.") or seen.has(action_id):
			return false
		seen[action_id] = true
	var selected: StringName = state[&"selected_action_id"] as StringName
	return selected == &"" or selected in actions


static func _preview_is_valid(state: Dictionary) -> bool:
	var preview: Dictionary = state[&"preview"] as Dictionary
	if preview.is_empty():
		return true
	return (
		PreviewScript.validate(preview)
		and preview[&"source_snapshot_id"] == state[&"source_snapshot_id"]
		and preview[&"action_id"] == state[&"selected_action_id"]
	)


static func _nearby_are_valid(value: Variant, target_id: StringName) -> bool:
	if not value is Array or (value as Array).size() > MAX_NEARBY:
		return false
	var previous_distance: int = -1
	var previous_id: String = ""
	var seen: Dictionary = {}
	for raw_row: Variant in value as Array:
		if not raw_row is Dictionary:
			return false
		var row: Dictionary = raw_row as Dictionary
		if not _nearby_row_is_valid(row) or seen.has(row[&"interest_id"]):
			return false
		if target_id != &"" and row[&"interest_id"] == target_id:
			return false
		var distance: int = int(row[&"tile_distance"])
		var current_id: String = str(row[&"interest_id"])
		if distance < previous_distance or (distance == previous_distance and current_id <= previous_id):
			return false
		previous_distance = distance
		previous_id = current_id
		seen[row[&"interest_id"]] = true
	return true


static func _nearby_row_is_valid(row: Dictionary) -> bool:
	return (
		row.keys() == NEARBY_KEYS
		and _stable_id(row[&"interest_id"])
		and _stable_id(row[&"kind"])
		and _stable_id(row[&"title_key"])
		and row[&"cell"] is Vector2i
		and row[&"source_revision"] is int
		and int(row[&"source_revision"]) >= 0
		and row[&"available"] is bool
		and bool(row[&"available"])
		and row[&"tile_distance"] is int
		and int(row[&"tile_distance"]) >= 0
		and _stable_id(row[&"direction_id"])
	)


static func _history_is_valid(value: Variant, target_id: StringName) -> bool:
	if not value is Array or (value as Array).size() > MAX_HISTORY:
		return false
	var previous_sequence: int = 2_147_483_647
	for raw_record: Variant in value as Array:
		if not HistoryScript.validate_record(raw_record):
			return false
		var record: Dictionary = raw_record as Dictionary
		if record[&"target_id"] != target_id or int(record[&"sequence"]) >= previous_sequence:
			return false
		previous_sequence = int(record[&"sequence"])
	return true


static func _toast_is_valid(value: Variant) -> bool:
	return value is Dictionary and ((value as Dictionary).is_empty() or ToastScript.validate(value))


static func _value_is_valid(kind_value: Variant, value: Variant) -> bool:
	if not kind_value is StringName or kind_value not in ExecutionResultScript.VALUE_KINDS:
		return false
	var kind: StringName = kind_value as StringName
	match kind:
		ExecutionResultScript.VALUE_TEXT_KEY:
			return _stable_id(value)
		ExecutionResultScript.VALUE_INTEGER:
			return value is int
		ExecutionResultScript.VALUE_DECIMAL:
			return value is float and is_finite(value as float)
		ExecutionResultScript.VALUE_BOOLEAN:
			return value is bool
		ExecutionResultScript.VALUE_IDENTIFIER:
			return _stable_id(value)
	return false


static func _payload_digest(state: Dictionary) -> String:
	var unsigned: Dictionary = state.duplicate(true)
	unsigned[&"state_id"] = &""
	return CodecScript.digest(unsigned).left(32)


static func _optional_id(value: Variant) -> bool:
	return value is StringName and (value == &"" or _stable_id(value))


static func _stable_id(value: Variant, prefix: String = "") -> bool:
	if not value is StringName:
		return false
	var identifier: String = str(value)
	return (
		not identifier.is_empty()
		and identifier.length() <= CodecScript.MAX_TEXT_LENGTH
		and (prefix.is_empty() or identifier.begins_with(prefix))
	)
