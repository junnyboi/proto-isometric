extends RefCounted

const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const OperationCatalogScript: GDScript = preload("res://scripts/interaction_operation_catalog.gd")

const MAX_FACTS: int = 12
const RESULT_PREFIX: String = "interaction.result."
const VALUE_TEXT_KEY: StringName = &"text_key"
const VALUE_INTEGER: StringName = &"integer"
const VALUE_DECIMAL: StringName = &"decimal"
const VALUE_BOOLEAN: StringName = &"boolean"
const VALUE_IDENTIFIER: StringName = &"identifier"
const VALUE_KINDS: Array[StringName] = [
	VALUE_BOOLEAN,
	VALUE_DECIMAL,
	VALUE_IDENTIFIER,
	VALUE_INTEGER,
	VALUE_TEXT_KEY,
]
const KEYS: Array[StringName] = [
	&"result_id",
	&"ok",
	&"reason_key",
	&"mutated",
	&"source_snapshot_id",
	&"action_id",
	&"target_id",
	&"target_cell",
	&"observed_state",
	&"view",
]
const VIEW_KEYS: Array[StringName] = [
	&"title_key",
	&"body_key",
	&"parameters",
	&"facts",
]
const FACT_KEYS: Array[StringName] = [
	&"label_key",
	&"value_kind",
	&"value",
]


static func build(
	ok: bool,
	reason_key: StringName,
	mutated: bool,
	source_snapshot_id: StringName,
	action_id: StringName,
	target_id: StringName,
	target_cell: Vector2i,
	observed_state: Dictionary,
	view: Dictionary,
	operation_descriptor: Dictionary = {},
) -> Dictionary:
	var normalized_observed_state: Dictionary = CodecScript.canonical_dictionary(observed_state)
	if not observed_state.is_empty() and normalized_observed_state.is_empty():
		return {}
	var normalized_view: Dictionary = canonical_view(view)
	if normalized_view.is_empty():
		return {}
	var result: Dictionary = {
		&"result_id": &"pending",
		&"ok": ok,
		&"reason_key": reason_key,
		&"mutated": mutated,
		&"source_snapshot_id": source_snapshot_id,
		&"action_id": action_id,
		&"target_id": target_id,
		&"target_cell": target_cell,
		&"observed_state": normalized_observed_state,
		&"view": normalized_view,
	}
	result[&"result_id"] = StringName("%s%s" % [RESULT_PREFIX, _payload_digest(result)])
	return result if validate(result, operation_descriptor) else {}


static func validate(
	value: Variant,
	operation_descriptor: Dictionary = {},
) -> bool:
	if not value is Dictionary:
		return false
	var result: Dictionary = value as Dictionary
	if result.keys() != KEYS:
		return false
	if (
		not result[&"result_id"] is StringName
		or not result[&"ok"] is bool
		or not result[&"reason_key"] is StringName
		or not result[&"mutated"] is bool
		or not result[&"source_snapshot_id"] is StringName
		or not result[&"action_id"] is StringName
		or not result[&"target_id"] is StringName
		or not result[&"target_cell"] is Vector2i
		or not result[&"observed_state"] is Dictionary
		or not result[&"view"] is Dictionary
	):
		return false
	if (
		not _stable_id(result[&"result_id"], RESULT_PREFIX)
		or not _stable_id(result[&"source_snapshot_id"], "interaction.snapshot.")
		or not _stable_id(result[&"action_id"], "interaction.action.")
		or not _stable_id(result[&"target_id"])
	):
		return false
	var ok: bool = bool(result[&"ok"])
	var reason_key: StringName = result[&"reason_key"] as StringName
	var mutated: bool = bool(result[&"mutated"])
	if ok and reason_key != &"":
		return false
	if not ok and not _stable_id(reason_key, "interaction.reason."):
		return false
	if mutated and not ok:
		return false
	if mutated and operation_descriptor.is_empty():
		return false
	var observed_state: Dictionary = result[&"observed_state"] as Dictionary
	if CodecScript.canonical_dictionary(observed_state) != observed_state:
		return false
	if not validate_view(result[&"view"]):
		return false
	if not operation_descriptor.is_empty():
		if not OperationCatalogScript.validate(operation_descriptor):
			return false
		var mutability: StringName = operation_descriptor[&"mutability"] as StringName
		if mutated and mutability != OperationCatalogScript.MUTABILITY_MUTATING:
			return false
		if (
			mutability in [
				OperationCatalogScript.MUTABILITY_READ_ONLY,
				OperationCatalogScript.MUTABILITY_UI_ONLY,
			]
			and mutated
		):
			return false
	return str(result[&"result_id"]) == "%s%s" % [RESULT_PREFIX, _payload_digest(result)]


static func canonical_copy(
	value: Variant,
	operation_descriptor: Dictionary = {},
) -> Dictionary:
	return (value as Dictionary).duplicate(true) if validate(value, operation_descriptor) else {}


static func canonical_view(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var view: Dictionary = value as Dictionary
	if view.keys() != VIEW_KEYS:
		return {}
	if (
		not view[&"title_key"] is StringName
		or not view[&"body_key"] is StringName
		or not view[&"parameters"] is Dictionary
		or not view[&"facts"] is Array
	):
		return {}
	var parameters: Dictionary = CodecScript.canonical_dictionary(view[&"parameters"])
	if parameters != view[&"parameters"]:
		return {}
	var facts: Array = view[&"facts"] as Array
	if facts.size() > MAX_FACTS:
		return {}
	var normalized_facts: Array[Dictionary] = []
	for raw_fact: Variant in facts:
		if not raw_fact is Dictionary:
			return {}
		var normalized_fact: Dictionary = _canonical_fact(raw_fact as Dictionary)
		if normalized_fact.is_empty():
			return {}
		normalized_facts.append(normalized_fact)
	var result: Dictionary = {
		&"title_key": view[&"title_key"],
		&"body_key": view[&"body_key"],
		&"parameters": parameters,
		&"facts": normalized_facts,
	}
	return result if validate_view(result) else {}


static func validate_view(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var view: Dictionary = value as Dictionary
	if view.keys() != VIEW_KEYS:
		return false
	if (
		not _stable_id(view[&"title_key"])
		or not _stable_id(view[&"body_key"])
		or not view[&"parameters"] is Dictionary
		or not view[&"facts"] is Array
	):
		return false
	var parameters: Dictionary = view[&"parameters"] as Dictionary
	if CodecScript.canonical_dictionary(parameters) != parameters:
		return false
	var facts: Array = view[&"facts"] as Array
	if facts.size() > MAX_FACTS:
		return false
	for raw_fact: Variant in facts:
		if not raw_fact is Dictionary or not _fact_is_valid(raw_fact as Dictionary):
			return false
	return true


static func canonical_text(value: Variant) -> String:
	return CodecScript.text(value) if validate(value) else ""


static func digest(value: Variant) -> StringName:
	if not value is Dictionary:
		return &""
	var result: Dictionary = value as Dictionary
	return (
		StringName("%s%s" % [RESULT_PREFIX, _payload_digest(result)])
		if result.keys() == KEYS
		else &""
	)


static func _canonical_fact(fact: Dictionary) -> Dictionary:
	if fact.keys() != FACT_KEYS:
		return {}
	var result: Dictionary = {
		&"label_key": fact[&"label_key"],
		&"value_kind": fact[&"value_kind"],
		&"value": fact[&"value"],
	}
	return result if _fact_is_valid(result) else {}


static func _fact_is_valid(fact: Dictionary) -> bool:
	if fact.keys() != FACT_KEYS:
		return false
	if (
		not fact[&"label_key"] is StringName
		or not fact[&"value_kind"] is StringName
		or not _stable_id(fact[&"label_key"])
		or fact[&"value_kind"] not in VALUE_KINDS
	):
		return false
	var kind: StringName = fact[&"value_kind"] as StringName
	var fact_value: Variant = fact[&"value"]
	match kind:
		VALUE_TEXT_KEY:
			return fact_value is StringName and _stable_id(fact_value)
		VALUE_INTEGER:
			return fact_value is int
		VALUE_DECIMAL:
			return fact_value is float and is_finite(fact_value as float)
		VALUE_BOOLEAN:
			return fact_value is bool
		VALUE_IDENTIFIER:
			return fact_value is StringName and _stable_id(fact_value)
	return false


static func _payload_digest(result: Dictionary) -> String:
	var unsigned: Dictionary = result.duplicate(true)
	unsigned[&"result_id"] = &""
	return CodecScript.digest(CodecScript.canonical_dictionary(unsigned)).left(32)


static func _stable_id(value: Variant, prefix: String = "") -> bool:
	if not value is StringName:
		return false
	var identifier: String = str(value)
	return (
		not identifier.is_empty()
		and identifier.length() <= CodecScript.MAX_TEXT_LENGTH
		and (prefix.is_empty() or identifier.begins_with(prefix))
	)
