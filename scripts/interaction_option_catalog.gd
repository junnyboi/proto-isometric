extends RefCounted

const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const TargetScript: GDScript = preload("res://scripts/interaction_target_snapshot.gd")

const MAX_PROVIDERS: int = 16
const PROVIDER_TERRAIN: StringName = &"interaction.provider.terrain_plot_crop"
const PROVIDER_RESOURCE: StringName = &"interaction.provider.tree_resource"
const PROVIDER_PICKUP: StringName = &"interaction.provider.pickup"
const PROVIDER_FACILITY: StringName = &"interaction.provider.home_facility_ruin"
const PROVIDER_MACHINE: StringName = &"interaction.provider.storage_shipping_machine"
const PROVIDER_RESIDENT: StringName = &"interaction.provider.resident"
const PROVIDER_LIVESTOCK: StringName = &"interaction.provider.livestock"
const PROVIDER_CONSTRUCTION: StringName = &"interaction.provider.construction"
const PROVIDER_DEPOSIT: StringName = &"interaction.provider.deposit"
const PROVIDER_WILDERNESS: StringName = &"interaction.provider.wilderness"
const PROVIDER_LEGACY: StringName = &"interaction.provider.legacy_expedition"
const PROVIDERS: Array[StringName] = [
	PROVIDER_FACILITY,
	PROVIDER_CONSTRUCTION,
	PROVIDER_DEPOSIT,
	PROVIDER_LEGACY,
	PROVIDER_LIVESTOCK,
	PROVIDER_MACHINE,
	PROVIDER_PICKUP,
	PROVIDER_RESIDENT,
	PROVIDER_RESOURCE,
	PROVIDER_TERRAIN,
	PROVIDER_WILDERNESS,
]
const PROVIDER_SUBKINDS: Dictionary = {
	PROVIDER_TERRAIN: [&"terrain", &"plot", &"crop"],
	PROVIDER_RESOURCE: [&"tree", &"resource", &"flora"],
	PROVIDER_PICKUP: [&"pickup"],
	PROVIDER_FACILITY: [&"home", &"facility", &"functional_prop", &"ruin", &"water"],
	PROVIDER_MACHINE: [&"storage", &"shipping", &"machine"],
	PROVIDER_RESIDENT: [&"resident", &"settler"],
	PROVIDER_LIVESTOCK: [&"livestock"],
	PROVIDER_CONSTRUCTION: [&"construction"],
	PROVIDER_DEPOSIT: [&"deposit_salvage", &"deposit_mineral", &"deposit_biomass"],
	PROVIDER_WILDERNESS: [&"wilderness", &"hostile", &"hazard", &"herd"],
	PROVIDER_LEGACY: [&"legacy_expedition", &"expedition_gate", &"safe_exit"],
}


static func provider_ids() -> Array[StringName]:
	return PROVIDERS.duplicate()


static func build_menu(target: Variant, registrations: Array[StringName] = PROVIDERS) -> Dictionary:
	if not TargetScript.validate(target):
		return {}
	var providers: Array[StringName] = _validated_registrations(registrations)
	if providers.is_empty():
		return {}
	var projection: Dictionary = target as Dictionary
	var provider_id: StringName = _provider_for(projection[&"target_subkind"] as StringName, providers)
	if provider_id == &"":
		return {}
	var options: Array[Dictionary] = []
	for option_input: Dictionary in projection[&"option_inputs"] as Array[Dictionary]:
		var cells: Array[Vector2i] = [projection[&"target_cell"] as Vector2i]
		var option: Dictionary = OptionScript.build(
			option_input[&"action_id"] as StringName,
			provider_id,
			projection[&"target_id"] as StringName,
			projection[&"target_kind"] as StringName,
			projection[&"target_subkind"] as StringName,
			option_input[&"operation"] as StringName,
			option_input[&"arguments"] as Dictionary,
			bool(option_input[&"enabled"]),
			option_input[&"label_key"] as StringName,
			option_input[&"reason_key"] as StringName,
			int(option_input[&"priority"]),
			cells,
			option_input[&"cost_preview"] as Array[Dictionary],
			option_input[&"close_behavior"] as StringName,
		)
		if option.is_empty():
			return {}
		options.append(option)
	if options.is_empty():
		options.append(_inspect_option(projection, provider_id))
	return MenuScript.build(
		projection[&"target_cell"] as Vector2i,
		projection[&"target_id"] as StringName,
		projection[&"target_kind"] as StringName,
		projection[&"target_subkind"] as StringName,
		projection[&"target_title_key"] as StringName,
		projection[&"state"] as Dictionary,
		options,
	)


static func _inspect_option(target: Dictionary, provider_id: StringName) -> Dictionary:
	var cell: Vector2i = target[&"target_cell"] as Vector2i
	var cells: Array[Vector2i] = [cell]
	return OptionScript.build(
		&"interaction.action.inspect",
		provider_id,
		target[&"target_id"] as StringName,
		target[&"target_kind"] as StringName,
		target[&"target_subkind"] as StringName,
		&"inspect",
		{&"cell": cell},
		true,
		&"interaction.action.inspect.label",
		&"",
		900,
		cells,
		[],
		OptionScript.CLOSE_NEVER,
	)


static func _validated_registrations(registrations: Array[StringName]) -> Array[StringName]:
	if registrations.is_empty() or registrations.size() > MAX_PROVIDERS:
		return []
	var result: Array[StringName] = registrations.duplicate()
	result.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return str(first) < str(second)
	)
	for index: int in result.size():
		if result[index] not in PROVIDERS or (index > 0 and result[index] == result[index - 1]):
			return []
	return result


static func _provider_for(subkind: StringName, registrations: Array[StringName]) -> StringName:
	for provider_id: StringName in registrations:
		var supported: Variant = PROVIDER_SUBKINDS[provider_id]
		if supported is Array and subkind in supported:
			return provider_id
	return &""
