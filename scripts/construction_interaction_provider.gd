extends RefCounted

const CatalogScript: GDScript = preload("res://scripts/construction_blueprint_catalog.gd")
const StateScript: GDScript = preload("res://scripts/construction_state_service.gd")
const InventoryScript: GDScript = preload("res://scripts/inventory_service.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const TargetBridgeScript: GDScript = preload("res://scripts/harvest_interaction_target_bridge.gd")


static func building(
	farm: Dictionary, cell: Vector2i, record: Dictionary
) -> Dictionary:
	if record.is_empty():
		return {}
	var instance_id: StringName = StringName(str(record[&"instance_id"]))
	var blueprint_id: StringName = StringName(str(record[&"blueprint_id"]))
	var definition: Dictionary = CatalogScript.definition(blueprint_id)
	if definition.is_empty():
		return {}
	var complete: bool = record[&"state"] == "complete"
	var mobile_empty: bool = (
		(record[&"local_stacks"] as Array).is_empty()
		and (record[&"recipe_policies"] as Array).is_empty()
	)
	var dependencies: bool = StateScript.has_dependencies(farm, instance_id)
	var can_move: bool = (
		complete
		and mobile_empty
		and not dependencies
		and CatalogScript.is_movable(blueprint_id)
	)
	var next_level: int = int(record[&"level"]) + 1
	var upgrade_bill: Dictionary = CatalogScript.bill(blueprint_id, next_level)
	var can_upgrade: bool = (
		complete
		and next_level <= CatalogScript.MAX_LEVEL
		and _can_afford(farm, upgrade_bill)
	)
	var can_demolish: bool = mobile_empty and not dependencies
	var no_cost: Array[Dictionary] = []
	var options: Array[Dictionary] = [
		TargetBridgeScript.option_input(
			&"interaction.action.inspect_construction",
			&"inspect_construction",
			{&"instance_id": instance_id},
			true,
			&"",
			100,
			no_cost,
			OptionScript.CLOSE_NEVER,
		),
		TargetBridgeScript.option_input(
			&"interaction.action.move_construction",
			&"open_construction_move",
			{&"instance_id": instance_id},
			can_move,
			&"" if can_move else &"interaction.reason.construction_not_movable",
			220,
		),
		TargetBridgeScript.option_input(
			&"interaction.action.upgrade_construction",
			&"confirm_construction_upgrade",
			{&"instance_id": instance_id},
				can_upgrade,
				&"" if can_upgrade else &"interaction.reason.construction_upgrade_unavailable",
				240,
				_costs(upgrade_bill),
		),
		TargetBridgeScript.option_input(
			&"interaction.action.demolish_construction",
			&"confirm_construction_demolish",
			{&"instance_id": instance_id},
				can_demolish,
				&"" if can_demolish else &"interaction.reason.construction_protected",
			800,
		),
	]
	if complete and blueprint_id in [
		CatalogScript.SALVAGE_CAMP,
		CatalogScript.SURVEY_DRILL,
		CatalogScript.COPPICE_STATION,
	]:
		options.append(
			TargetBridgeScript.option_input(
				&"interaction.action.preview_extraction_range",
				&"preview_extraction_range",
				{&"instance_id": instance_id}, true, &"", 160, no_cost,
				OptionScript.CLOSE_NEVER,
			)
		)
	return TargetBridgeScript.project(
		cell,
		{
			&"kinds": [ResolverScript.KIND_STRUCTURE],
			&"blocked": true,
			&"target_id": instance_id,
			&"target_subkind": &"construction",
			&"target_state": {
				&"blueprint_id": str(blueprint_id),
				&"state": str(record[&"state"]),
				&"level": int(record[&"level"]),
				&"orientation": int(record[&"orientation"]),
			},
			&"option_inputs": options,
		},
	)


static func catalog_option() -> Dictionary:
	return TargetBridgeScript.option_input(
		&"interaction.action.open_construction",
		&"open_construction",
		{},
		true,
		&"",
		180,
	)


static func _can_afford(farm: Dictionary, bill: Dictionary) -> bool:
	for item_id: Variant in bill:
		if InventoryScript.count_all(farm, item_id as StringName) < int(bill[item_id]):
			return false
	return true


static func _costs(bill: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id: Variant in bill:
		result.append({&"cost_id": item_id as StringName, &"amount": int(bill[item_id])})
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"cost_id"]) < str(b[&"cost_id"])
	)
	return result
