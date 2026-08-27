extends RefCounted

const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const OperationCatalogScript: GDScript = preload("res://scripts/interaction_operation_catalog.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")

const CONFIRM_STANDARD: StringName = &"standard"
const CONFIRM_HOLD: StringName = &"hold"
const CONFIRM_PRESENTATIONS: Array[StringName] = [CONFIRM_HOLD, CONFIRM_STANDARD]
const TONES: Array[StringName] = [&"danger", &"neutral", &"productive", &"read", &"ui"]
const KEYS: Array[StringName] = [
	&"presentation_id",
	&"icon_id",
	&"description_key",
	&"tone",
	&"confirm_presentation",
]
const FALLBACK: Dictionary = {
	&"presentation_id": &"interaction.presentation.neutral",
	&"icon_id": &"interaction.icon.procedural.neutral",
	&"description_key": &"interaction.action.unavailable.label",
	&"tone": &"neutral",
	&"confirm_presentation": CONFIRM_STANDARD,
}
const EXACT: Dictionary = {
	&"interaction.action.inspect": [&"inspect", &"read"],
	&"interaction.action.inspect_construction": [&"inspect", &"read"],
	&"interaction.action.inspect_deposit": [&"inspect", &"read"],
	&"interaction.action.facility_repair": [&"repair", &"productive"],
	&"interaction.action.facility_power": [&"power", &"productive"],
	&"interaction.action.fish_cast": [&"fish", &"productive"],
	&"interaction.action.fish_cast_bait": [&"fish", &"productive"],
	&"interaction.action.harvest": [&"harvest", &"productive"],
	&"interaction.action.till": [&"till", &"productive"],
	&"interaction.action.water": [&"water", &"productive"],
	&"interaction.action.open_construction": [&"open", &"ui"],
	&"interaction.action.move_construction": [&"move", &"ui"],
	&"interaction.action.upgrade_construction": [&"upgrade", &"ui"],
	&"interaction.action.demolish_construction": [&"demolish", &"danger"],
	&"interaction.action.preview_extraction_range": [&"range", &"read"],
	&"interaction.action.return_safe_exit": [&"return", &"productive"],
	&"interaction.action.sleep": [&"sleep", &"productive"],
}
const PREFIXES: Array[Dictionary] = [
	{&"prefix": &"interaction.action.buy_seed.", &"icon": &"buy", &"tone": &"productive"},
	{&"prefix": &"interaction.action.gift.", &"icon": &"gift", &"tone": &"productive"},
	{&"prefix": &"interaction.action.machine_start.", &"icon": &"craft", &"tone": &"productive"},
	{&"prefix": &"interaction.action.plant.", &"icon": &"plant", &"tone": &"productive"},
	{&"prefix": &"interaction.action.service.", &"icon": &"service", &"tone": &"read"},
	{&"prefix": &"interaction.action.ship.", &"icon": &"ship", &"tone": &"productive"},
	{&"prefix": &"interaction.action.tree_plant.", &"icon": &"plant", &"tone": &"productive"},
	{&"prefix": &"interaction.action.upgrade.", &"icon": &"upgrade", &"tone": &"productive"},
]


static func for_option(value: Variant, operation_descriptor: Variant) -> Dictionary:
	if not OptionScript.validate(value) or not OperationCatalogScript.validate(operation_descriptor):
		return {}
	var option: Dictionary = value as Dictionary
	var descriptor: Dictionary = operation_descriptor as Dictionary
	if not OperationCatalogScript.accepts(
		descriptor,
		option[&"provider_id"] as StringName,
		option[&"operation"] as StringName,
		option[&"close_behavior"] as StringName,
	):
		return {}
	var metadata: Dictionary = _metadata_for(option[&"action_id"] as StringName)
	if metadata[&"presentation_id"] != FALLBACK[&"presentation_id"]:
		metadata[&"tone"] = _descriptor_tone(descriptor, metadata[&"tone"] as StringName)
	metadata[&"confirm_presentation"] = _confirmation_for(option, descriptor)
	return metadata if validate(metadata) else {}


static func validate(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var presentation: Dictionary = value as Dictionary
	return (
		presentation.keys() == KEYS
		and _stable_id(presentation[&"presentation_id"], "interaction.presentation.")
		and _stable_id(presentation[&"icon_id"], "interaction.icon.")
		and _stable_id(presentation[&"description_key"])
		and presentation[&"tone"] is StringName
		and presentation[&"tone"] in TONES
		and presentation[&"confirm_presentation"] is StringName
		and presentation[&"confirm_presentation"] in CONFIRM_PRESENTATIONS
	)


static func canonical_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if validate(value) else {}


static func _metadata_for(action_id: StringName) -> Dictionary:
	if EXACT.has(action_id):
		return _metadata(action_id, EXACT[action_id] as Array)
	for row: Dictionary in PREFIXES:
		if str(action_id).begins_with(str(row[&"prefix"])):
			return _metadata(action_id, [row[&"icon"], row[&"tone"]])
	return FALLBACK.duplicate(true)


static func _metadata(action_id: StringName, values: Array) -> Dictionary:
	var suffix: String = str(action_id).trim_prefix("interaction.action.")
	return {
		&"presentation_id": StringName("interaction.presentation.%s" % suffix),
		&"icon_id": StringName("interaction.icon.procedural.%s" % str(values[0])),
		&"description_key": StringName("%s.label" % str(action_id)),
		&"tone": values[1] as StringName,
		&"confirm_presentation": CONFIRM_STANDARD,
	}


static func _descriptor_tone(descriptor: Dictionary, mapped_tone: StringName) -> StringName:
	match descriptor[&"mutability"] as StringName:
		OperationCatalogScript.MUTABILITY_READ_ONLY:
			return &"read"
		OperationCatalogScript.MUTABILITY_UI_ONLY:
			return &"ui"
	return mapped_tone if mapped_tone in [&"danger", &"productive"] else &"productive"


static func _confirmation_for(option: Dictionary, descriptor: Dictionary) -> StringName:
	if (
		option[&"action_id"] == &"interaction.action.demolish_construction"
		and option[&"operation"] == &"confirm_construction_demolish"
		and descriptor[&"mutability"] == OperationCatalogScript.MUTABILITY_UI_ONLY
	):
		return CONFIRM_HOLD
	return CONFIRM_STANDARD


static func _stable_id(value: Variant, prefix: String = "") -> bool:
	if not value is StringName:
		return false
	var identifier: String = str(value)
	return (
		not identifier.is_empty()
		and identifier.length() <= CodecScript.MAX_TEXT_LENGTH
		and (prefix.is_empty() or identifier.begins_with(prefix))
	)
