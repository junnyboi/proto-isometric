extends RefCounted

const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const OperationCatalogScript: GDScript = preload("res://scripts/interaction_operation_catalog.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const PresentationScript: GDScript = preload(
	"res://scripts/interaction_action_presentation_catalog.gd"
)

const MAX_EFFECT_ROWS: int = 4
const PREVIEW_PREFIX: String = "interaction.preview."
const KEYS: Array[StringName] = [
	&"preview_id",
	&"source_snapshot_id",
	&"option_fingerprint",
	&"action_id",
	&"operation",
	&"mutability",
	&"title_key",
	&"description_key",
	&"enabled",
	&"reason_key",
	&"costs",
	&"affected_cells",
	&"effect_rows",
]
const EFFECT_KEYS: Array[StringName] = [
	&"effect_id",
	&"label_key",
	&"value_kind",
	&"value",
]


static func build(
	fresh_menu: Variant,
	current_option: Variant,
	operation_descriptor: Variant,
) -> Dictionary:
	if (
		not MenuScript.validate(fresh_menu)
		or not OptionScript.validate(current_option)
		or not OperationCatalogScript.validate(operation_descriptor)
	):
		return {}
	var menu: Dictionary = fresh_menu as Dictionary
	var option: Dictionary = current_option as Dictionary
	var descriptor: Dictionary = operation_descriptor as Dictionary
	if not _option_is_current(menu, option) or not OperationCatalogScript.accepts(
		descriptor,
		option[&"provider_id"] as StringName,
		option[&"operation"] as StringName,
		option[&"close_behavior"] as StringName,
	):
		return {}
	var presentation: Dictionary = PresentationScript.for_option(option, descriptor)
	if presentation.is_empty():
		return {}
	var preview: Dictionary = {
		&"preview_id": &"pending",
		&"source_snapshot_id": menu[&"snapshot_id"],
		&"option_fingerprint": fingerprint(option),
		&"action_id": option[&"action_id"],
		&"operation": option[&"operation"],
		&"mutability": descriptor[&"mutability"],
		&"title_key": option[&"label_key"],
		&"description_key": presentation[&"description_key"],
		&"enabled": option[&"enabled"],
		&"reason_key": option[&"reason_key"],
		&"costs": (option[&"cost_preview"] as Array).duplicate(true),
		&"affected_cells": (option[&"affected_cells"] as Array).duplicate(),
		&"effect_rows": _descriptor_effect_rows(descriptor),
	}
	preview[&"preview_id"] = StringName("%s%s" % [PREVIEW_PREFIX, _payload_digest(preview)])
	return preview if validate(preview) else {}


static func validate(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var preview: Dictionary = value as Dictionary
	if preview.keys() != KEYS:
		return false
	if (
		not _stable_id(preview[&"preview_id"], PREVIEW_PREFIX)
		or not _stable_id(preview[&"source_snapshot_id"], "interaction.snapshot.")
		or not _stable_id(preview[&"option_fingerprint"], "interaction.option.")
		or not _stable_id(preview[&"action_id"], "interaction.action.")
		or not _stable_id(preview[&"operation"])
		or preview[&"mutability"] not in OperationCatalogScript.MUTABILITIES
		or not _stable_id(preview[&"title_key"])
		or not _stable_id(preview[&"description_key"])
		or not preview[&"enabled"] is bool
		or not preview[&"reason_key"] is StringName
		or not preview[&"costs"] is Array
		or not preview[&"affected_cells"] is Array
		or not preview[&"effect_rows"] is Array
	):
		return false
	if not _reason_matches_enabled(preview[&"enabled"], preview[&"reason_key"]):
		return false
	if not _costs_are_valid(preview[&"costs"] as Array):
		return false
	if not _cells_are_valid(preview[&"affected_cells"] as Array):
		return false
	if not _effect_rows_are_valid(preview[&"effect_rows"] as Array):
		return false
	return str(preview[&"preview_id"]) == "%s%s" % [
		PREVIEW_PREFIX,
		_payload_digest(preview),
	]


static func is_current(
	value: Variant,
	fresh_menu: Variant,
	current_option: Variant,
) -> bool:
	if not validate(value) or not MenuScript.validate(fresh_menu):
		return false
	if not OptionScript.validate(current_option):
		return false
	var preview: Dictionary = value as Dictionary
	var menu: Dictionary = fresh_menu as Dictionary
	var option: Dictionary = current_option as Dictionary
	return (
		preview[&"source_snapshot_id"] == menu[&"snapshot_id"]
		and preview[&"option_fingerprint"] == fingerprint(option)
		and preview[&"action_id"] == option[&"action_id"]
		and _option_is_current(menu, option)
	)


static func canonical_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if validate(value) else {}


static func fingerprint(value: Variant) -> StringName:
	if not OptionScript.validate(value):
		return &""
	return StringName("interaction.option.%s" % CodecScript.digest(value).left(32))


static func _descriptor_effect_rows(descriptor: Dictionary) -> Array[Dictionary]:
	var row: Dictionary
	match descriptor[&"mutability"] as StringName:
		OperationCatalogScript.MUTABILITY_READ_ONLY:
			row = _effect(&"read_only", &"interaction.inspect.fact.state", &"read_only")
		OperationCatalogScript.MUTABILITY_UI_ONLY:
			row = _effect(&"ui_only", &"interaction.inspect.fact.state", &"ui_only")
		_:
			return []
	return [row]


static func _effect(
	effect_id: StringName,
	label_key: StringName,
	value: StringName,
) -> Dictionary:
	return {
		&"effect_id": StringName("interaction.effect.%s" % str(effect_id)),
		&"label_key": label_key,
		&"value_kind": &"identifier",
		&"value": StringName("interaction.effect.value.%s" % str(value)),
	}


static func _effect_rows_are_valid(rows: Array) -> bool:
	if rows.size() > MAX_EFFECT_ROWS:
		return false
	var previous: String = ""
	for raw_row: Variant in rows:
		if not raw_row is Dictionary:
			return false
		var row: Dictionary = raw_row as Dictionary
		if (
			row.keys() != EFFECT_KEYS
			or not _stable_id(row[&"effect_id"], "interaction.effect.")
			or not _stable_id(row[&"label_key"])
			or row[&"value_kind"] != &"identifier"
			or not _stable_id(row[&"value"], "interaction.effect.value.")
		):
			return false
		var current: String = str(row[&"effect_id"])
		if not previous.is_empty() and current <= previous:
			return false
		previous = current
	return true


static func _costs_are_valid(costs: Array) -> bool:
	if costs.size() > OptionScript.MAX_COST_ENTRIES:
		return false
	var previous: String = ""
	for raw_cost: Variant in costs:
		if not raw_cost is Dictionary:
			return false
		var cost: Dictionary = raw_cost as Dictionary
		if (
			cost.keys() != [&"cost_id", &"amount"]
			or not _stable_id(cost[&"cost_id"])
			or not cost[&"amount"] is int
			or int(cost[&"amount"]) <= 0
		):
			return false
		var current: String = str(cost[&"cost_id"])
		if not previous.is_empty() and current <= previous:
			return false
		previous = current
	return true


static func _cells_are_valid(cells: Array) -> bool:
	if cells.is_empty() or cells.size() > OptionScript.MAX_AFFECTED_CELLS:
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


static func _reason_matches_enabled(enabled: Variant, reason_key: Variant) -> bool:
	if enabled:
		return reason_key == &""
	return _stable_id(reason_key, "interaction.reason.")


static func _option_is_current(menu: Dictionary, option: Dictionary) -> bool:
	for candidate: Dictionary in menu[&"options"] as Array[Dictionary]:
		if candidate[&"action_id"] == option[&"action_id"]:
			return candidate == option
	return false


static func _payload_digest(preview: Dictionary) -> String:
	var unsigned: Dictionary = preview.duplicate(true)
	unsigned[&"preview_id"] = &""
	return CodecScript.digest(unsigned).left(32)


static func _stable_id(value: Variant, prefix: String = "") -> bool:
	if not value is StringName:
		return false
	var identifier: String = str(value)
	return (
		not identifier.is_empty()
		and identifier.length() <= CodecScript.MAX_TEXT_LENGTH
		and (prefix.is_empty() or identifier.begins_with(prefix))
	)


static func _cell_less(first: Vector2i, second: Vector2i) -> bool:
	return first.y < second.y or (first.y == second.y and first.x < second.x)
