extends RefCounted

const CalendarScript: GDScript = preload("res://scripts/calendar_state.gd")
const FishingCatalogScript: GDScript = preload("res://scripts/fishing_catalog.gd")
const FishingServiceScript: GDScript = preload("res://scripts/fishing_service.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const OrchardCatalogScript: GDScript = preload("res://scripts/orchard_catalog.gd")
const OrchardServiceScript: GDScript = preload("res://scripts/orchard_service.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const TargetBridgeScript: GDScript = preload(
	"res://scripts/harvest_interaction_target_bridge.gd"
)
const TargetScript: GDScript = preload("res://scripts/interaction_target_snapshot.gd")
const ToolScript: GDScript = preload("res://scripts/tool_service.gd")


static func tree(farm: Dictionary, cell: Vector2i, record: Dictionary) -> Dictionary:
	var tree_id: StringName = StringName(str(record[&"tree_id"]))
	var species_id: StringName = StringName(str(record[&"species_id"]))
	var expected_revision: int = int((farm[&"revisions"] as Dictionary)[&"result_revision"])
	var harvest: Dictionary = OrchardServiceScript.harvest(farm, tree_id)
	var remove: Dictionary = OrchardServiceScript.remove_immature(farm, tree_id)
	var context_cost: Array[Dictionary] = [{
		&"cost_id": &"tool.stamina",
		&"amount": ToolScript.stamina_cost(farm, ToolScript.TOOL_CONTEXT),
	}]
	var options: Array[Dictionary] = [
		_read(cell),
		_offer(
			&"interaction.action.tree_harvest",
			&"tree_harvest",
			{&"tree_id": tree_id, &"expected_revision": expected_revision},
			bool(harvest[&"ok"]),
				_reason(harvest[&"reason"] as StringName),
				100,
				context_cost,
		),
		_offer(
			&"interaction.action.tree_remove",
			&"tree_remove",
			{&"tree_id": tree_id, &"expected_revision": expected_revision},
			bool(remove[&"ok"]),
			_reason(remove[&"reason"] as StringName),
			200,
				context_cost,
		),
	]
	return TargetScript.build(
		cell,
		tree_id,
		ResolverScript.KIND_RESOURCE,
		&"tree",
		&"interaction.target.orchard_tree.title",
		{
			&"species_id": species_id,
			&"stage": OrchardCatalogScript.stage_for(
				species_id, int(record[&"growth_points"])
			),
			&"harvest_sequence": int(record[&"harvest_sequence"]),
		},
		options,
	)


static func water(
	farm: Dictionary, cell: Vector2i, state: Dictionary, world_seed: int
) -> Dictionary:
	var water_class: StringName = state.get(&"water_class", &"") as StringName
	var spot_id: StringName = FishingCatalogScript.spot_for_water_class(water_class)
	if spot_id == &"":
		return {}
	var day: int = CalendarScript.absolute_day(farm[&"calendar_weather"])
	var expected_revision: int = int((farm[&"revisions"] as Dictionary)[&"result_revision"])
	var plain: Dictionary = FishingServiceScript.cast(farm, spot_id, day, world_seed, false)
	var baited: Dictionary = FishingServiceScript.cast(farm, spot_id, day, world_seed, true)
	var spot: Dictionary = FishingServiceScript.spot_snapshot(farm, spot_id, day)
	var options: Array[Dictionary] = [
		_read(cell),
		_offer(
			&"interaction.action.fish_cast",
			&"fish_cast",
			{
				&"spot_id": spot_id,
				&"use_bait": false,
				&"expected_revision": expected_revision,
			},
			bool(plain[&"ok"]),
			_reason(plain[&"reason"] as StringName),
			100,
		),
		_offer(
			&"interaction.action.fish_cast_bait",
			&"fish_cast",
			{
				&"spot_id": spot_id,
				&"use_bait": true,
				&"expected_revision": expected_revision,
			},
			bool(baited[&"ok"]),
			_reason(baited[&"reason"] as StringName),
			200,
			[{&"cost_id": FishingServiceScript.BAIT_ITEM, &"amount": 1}],
		),
	]
	var target_state: Dictionary = state.duplicate(true)
	target_state[&"spot_id"] = spot_id
	target_state[&"remaining_catches"] = int(spot.get(&"remaining_catches", 0))
	target_state[&"renewal_day"] = int(spot.get(&"renewal_day", day + 1))
	return TargetScript.build(
		cell,
		StringName("feature.water:%d,%d" % [cell.x, cell.y]),
		ResolverScript.KIND_STRUCTURE,
		&"water",
		&"interaction.target.water.title",
		target_state,
		options,
	)


static func _read(cell: Vector2i) -> Dictionary:
	var no_cost: Array[Dictionary] = []
	return TargetBridgeScript.option_input(
		&"interaction.action.inspect",
		&"inspect",
		{&"cell": cell},
		true,
		&"",
		0,
		no_cost,
		OptionScript.CLOSE_NEVER,
	)


static func _offer(
	action_id: StringName,
	operation: StringName,
	arguments: Dictionary,
	enabled: bool,
	reason: StringName,
	priority: int,
	costs: Array[Dictionary] = [],
) -> Dictionary:
	return TargetBridgeScript.option_input(
		action_id,
		operation,
		arguments,
		enabled,
		reason if not enabled else &"",
		priority,
		costs,
		OptionScript.CLOSE_ON_SUCCESS,
	)


static func _reason(reason: StringName) -> StringName:
	return (
		&"interaction.reason.unavailable"
		if reason == &""
		else StringName("interaction.reason.%s" % str(reason))
	)
