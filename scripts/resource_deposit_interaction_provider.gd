extends RefCounted

const CatalogScript: GDScript = preload("res://scripts/resource_deposit_catalog.gd")
const GatheringScript: GDScript = preload("res://scripts/gathering_state_service.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const TargetBridgeScript: GDScript = preload("res://scripts/harvest_interaction_target_bridge.gd")
const ToolScript: GDScript = preload("res://scripts/tool_service.gd")


static func deposit(
	farm: Dictionary,
	source: Dictionary,
	absolute_day: int,
	selected_tool: StringName,
) -> Dictionary:
	if not CatalogScript.validate_source(source):
		return {}
	var current: Dictionary = GatheringScript.effective(farm, source, absolute_day)
	if current.is_empty():
		return {}
	var required_tool: StringName = source[&"required_tool"] as StringName
	var enabled: bool = (
		int(current[&"remaining_charges"]) > 0
		and str(current[&"reserved_by"]).is_empty()
		and selected_tool == required_tool
		and ToolScript.can_spend(farm, required_tool)
	)
	var no_cost: Array[Dictionary] = []
	var costs: Array[Dictionary] = [
		{&"cost_id": &"tool.stamina", &"amount": ToolScript.stamina_cost(farm, required_tool)}
	]
	var options: Array[Dictionary] = [
		TargetBridgeScript.option_input(
			&"interaction.action.inspect_deposit", &"inspect_deposit",
			{&"source_id": str(source[&"source_id"])}, true, &"", 100, no_cost,
			OptionScript.CLOSE_NEVER,
		),
		TargetBridgeScript.option_input(
			&"interaction.action.gather_deposit", &"deposit_gather",
			{
				&"source_id": str(source[&"source_id"]), &"cell": source[&"cell"],
				&"expected_remaining": int(current[&"remaining_charges"]),
				&"absolute_day": absolute_day, &"actor_kind": "manual", &"actor_id": "protos",
			}, enabled, _reason(farm, source, current, selected_tool), 200, costs,
		),
	]
	var kind: StringName = source[&"source_kind"] as StringName
	return TargetBridgeScript.project(
		source[&"cell"],
		{
			&"kinds": [ResolverScript.KIND_RESOURCE], &"blocked": true,
			&"target_id": source[&"source_id"] as StringName,
			&"target_subkind": StringName("deposit_%s" % str(kind)),
			&"target_state": {
				&"source_kind": str(kind), &"remaining_charges": int(current[&"remaining_charges"]),
				&"capacity": int(current[&"capacity"]), &"tier": int(source[&"tier"]),
				&"phase": str(current[&"phase"]), &"renewal_day": int(current[&"renewal_day"]),
				&"reserved_by": str(current[&"reserved_by"]),
				&"reward_item_id": str(source[&"reward_item_id"]),
				&"reward_count": int(source[&"reward_count"]),
			},
			&"option_inputs": options,
		},
	)


static func _reason(
	farm: Dictionary,
	source: Dictionary,
	current: Dictionary,
	selected_tool: StringName,
) -> StringName:
	if int(current[&"remaining_charges"]) <= 0:
		return (
			&"interaction.reason.deposit_renewing"
			if bool(source[&"renewable"])
			else &"interaction.reason.deposit_exhausted"
		)
	if not str(current[&"reserved_by"]).is_empty():
		return &"interaction.reason.deposit_reserved"
	var required: StringName = source[&"required_tool"] as StringName
	if selected_tool != required:
		return (
			&"interaction.reason.requires_axe"
			if required == ToolScript.TOOL_AXE
			else &"interaction.reason.requires_pick"
		)
	if not ToolScript.can_spend(farm, required):
		return &"interaction.reason.exhausted"
	return &""
