extends RefCounted

const EcologyDirectorScript: GDScript = preload("res://scripts/ecology_director.gd")
const FarmCapabilityServiceScript: GDScript = preload("res://scripts/farm_capability_service.gd")
const HazardCatalogScript: GDScript = preload("res://scripts/hazard_opportunity_catalog.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const IronjawArcScript: GDScript = preload("res://scripts/ironjaw_desert_arc.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const TargetBridgeScript: GDScript = preload("res://scripts/harvest_interaction_target_bridge.gd")
const TargetScript: GDScript = preload("res://scripts/interaction_target_snapshot.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")
const WildFloraCatalogScript: GDScript = preload("res://scripts/wild_flora_catalog.gd")
const WildernessLootScript: GDScript = preload("res://scripts/wilderness_loot_catalog.gd")
const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")
const WorldOperationScript: GDScript = preload("res://scripts/harvest_world_operation_adapter.gd")


static func tree(
	farm: Dictionary,
	cell: Vector2i,
	tree_kind: StringName,
	selected_tool: StringName,
) -> Dictionary:
	var reward: Dictionary = WorldOperationScript.reward_for(&"tree", tree_kind)
	var enabled: bool = (
		selected_tool == ToolServiceScript.TOOL_AXE
		and ToolServiceScript.can_spend(farm, ToolServiceScript.TOOL_AXE)
	)
	var reason: StringName = _tool_reason(
		farm, selected_tool, ToolServiceScript.TOOL_AXE, &"interaction.reason.requires_axe"
	)
	var options: Array[Dictionary] = [
		_inspect(cell),
		_read(&"admire", &"admire", {&"tree_kind": tree_kind}, 100),
		_offer(
			&"chop",
			&"world_clear_reward",
			{
				&"cell": cell,
				&"world_kind": &"object.tree",
				&"source_kind": tree_kind,
				&"required_tool": ToolServiceScript.TOOL_AXE,
				&"reward_item_id": reward[&"item_id"],
				&"reward_count": int(reward[&"count"]),
			},
			enabled,
			reason,
			200,
			[
				{
					&"cost_id": &"tool.stamina",
					&"amount": ToolServiceScript.stamina_cost(farm, ToolServiceScript.TOOL_AXE),
				}
			],
		),
	]
	return _target(
		cell,
		StringName("object.tree:%d,%d" % [cell.x, cell.y]),
		&"tree",
		{&"tree_kind": tree_kind, &"reward": reward},
		options,
		&"tree",
	)


static func resource(
	farm: Dictionary,
	cell: Vector2i,
	resource_kind: StringName,
	selected_tool: StringName,
) -> Dictionary:
	var reward: Dictionary = WorldOperationScript.reward_for(&"resource", resource_kind)
	var enabled: bool = (
		selected_tool == ToolServiceScript.TOOL_PICK
		and ToolServiceScript.can_spend(farm, ToolServiceScript.TOOL_PICK)
	)
	var reason: StringName = _tool_reason(
		farm, selected_tool, ToolServiceScript.TOOL_PICK, &"interaction.reason.requires_pick"
	)
	var action: StringName = &"mine" if str(resource_kind).contains("iron") else &"break"
	var options: Array[Dictionary] = [
		_inspect(cell),
		_offer(
			action,
			&"world_clear_reward",
			{
				&"cell": cell,
				&"world_kind": &"object.rock",
				&"source_kind": resource_kind,
				&"required_tool": ToolServiceScript.TOOL_PICK,
				&"reward_item_id": reward[&"item_id"],
				&"reward_count": int(reward[&"count"]),
			},
			enabled,
			reason,
			200,
			[
				{
					&"cost_id": &"tool.stamina",
					&"amount": ToolServiceScript.stamina_cost(farm, ToolServiceScript.TOOL_PICK),
				}
			],
		),
	]
	return _target(
		cell,
		StringName("object.rock:%d,%d" % [cell.x, cell.y]),
		&"resource",
		{&"resource_kind": resource_kind, &"reward": reward},
		options,
		&"structure",
	)


static func flora(farm: Dictionary, cell: Vector2i, species_id: StringName) -> Dictionary:
	var reward: Dictionary = WildFloraCatalogScript.smash_reward(species_id)
	if reward.is_empty():
		return {}
	var enabled: bool = ToolServiceScript.can_spend(farm, ToolServiceScript.TOOL_CONTEXT)
	var options: Array[Dictionary] = [
		_inspect(cell),
		_offer(
			&"smash_flora",
			&"world_clear_reward",
			{
				&"cell": cell,
				&"world_kind": &"object.flora",
				&"source_kind": species_id,
				&"required_tool": ToolServiceScript.TOOL_CONTEXT,
				&"reward_item_id": reward[&"produce_item_id"],
				&"reward_count": int(reward[&"produce_count"]),
				&"seed_item_id": reward[&"seed_item_id"],
				&"seed_count": int(reward[&"seed_count"]),
			},
			enabled,
			&"" if enabled else &"interaction.reason.exhausted",
			200,
			[
				{
					&"cost_id": &"tool.stamina",
					&"amount": ToolServiceScript.stamina_cost(
						farm, ToolServiceScript.TOOL_CONTEXT
					),
				}
			],
		),
	]
	return _target(
		cell,
		StringName("object.flora:%d,%d" % [cell.x, cell.y]),
		&"flora",
		{&"species_id": species_id, &"reward": reward},
		options,
		&"resource",
	)


static func pickup(
	cell: Vector2i,
	target_id: StringName,
	state: Dictionary,
	operation: StringName,
) -> Dictionary:
	var options: Array[Dictionary] = [
		_inspect(cell),
		_offer(
			&"collect",
			operation,
			{&"cell": cell, &"pickup_id": target_id},
			false,
			&"interaction.reason.pickup_authority_unavailable",
			100,
		),
	]
	return _target(cell, target_id, &"pickup", state, options, &"pickup")


static func habitat(
	farm: Dictionary,
	cell: Vector2i,
	habitat: Dictionary,
	absolute_day: int,
) -> Dictionary:
	var habitat_id: StringName = habitat[&"habitat_id"] as StringName
	var category: StringName = habitat[&"category"] as StringName
	var state: Dictionary = {
		&"habitat_id": habitat_id,
		&"category": category,
		&"kind": habitat[&"kind"] as StringName,
		&"population": int(habitat[&"population"]),
		&"trust": int(habitat[&"trust"]),
		&"active": bool(habitat[&"active"]),
		&"yield_item_id": habitat[&"yield_item_id"] as StringName,
	}
	if category == EcologyDirectorScript.HERD:
		var interaction: Dictionary = EcologyDirectorScript.interact_herd(
			farm, habitat_id, absolute_day
		)
		var options: Array[Dictionary] = [
			_inspect(cell),
			_read(&"herd_observe", &"observe_herd", {&"habitat_id": habitat_id}, 100),
			_offer(
				&"herd_bond",
				&"herd_interact",
				{&"habitat_id": habitat_id, &"absolute_day": absolute_day},
				bool(interaction[&"ok"]),
				_reason(interaction[&"reason"] as StringName),
				200,
			),
			_read(&"herd_yield", &"read_herd_yield", {&"habitat_id": habitat_id}, 300),
		]
		return _target(cell, habitat_id, &"herd", state, options, &"friendly_fauna")
	var source_kind: StringName = habitat[&"kind"] as StringName
	var drop: Dictionary = _drop_for_source(source_kind)
	var hostile_options: Array[Dictionary] = [
		_inspect(cell),
		_read(&"threat", &"review_threat", {&"habitat_id": habitat_id}, 100),
		_read(&"drops", &"review_drops", drop, 200),
		_read(&"habitat", &"review_habitat", {&"habitat_id": habitat_id}, 300),
	]
	return _target(cell, habitat_id, &"hostile", state, hostile_options, &"hostile")


static func hostile(cell: Vector2i, target_id: StringName, combat: Dictionary) -> Dictionary:
	var kind: StringName = combat.get(&"kind", &"hostile") as StringName
	var drop: Dictionary = _drop_for_source(kind)
	var state: Dictionary = {
		&"kind": kind,
		&"health": int(combat.get(&"health", 0)),
		&"max_health": int(combat.get(&"max_health", 0)),
		&"is_boss": bool(combat.get(&"is_boss", false)),
	}
	var options: Array[Dictionary] = [
		_inspect(cell),
		_read(&"threat", &"review_threat", {&"hostile_id": target_id}, 100),
		_read(&"drops", &"review_drops", drop, 200),
		_read(&"habitat", &"review_habitat", {&"source_kind": kind}, 300),
	]
	if bool(combat.get(&"is_boss", false)) or kind == &"ironjaw_apex":
		(
			options
			. append(
				_read(
					&"first_clear",
					&"review_first_clear",
					{
						&"first_clear": IronjawArcScript.definition()[&"first_clear_id"],
						&"reward_item_id": IronjawArcScript.BURROW_CORE_ITEM,
					},
					400,
				)
			)
		)
	return _target(cell, target_id, &"hostile", state, options, &"hostile")


static func hazard(farm: Dictionary, event: Dictionary) -> Dictionary:
	var cell: Vector2i = event[&"cell"] as Vector2i
	var kind: StringName = event[&"kind"] as StringName
	var definition: Dictionary = HazardCatalogScript.definition(kind)
	if definition.is_empty():
		return {}
	var prepared: bool = FarmCapabilityServiceScript.has(
		farm, definition[&"preparation"] as StringName
	)
	var token: String = "hazard:%s:%d,%d" % [kind, cell.x, cell.y]
	var options: Array[Dictionary] = [
		_inspect(cell),
		_read(&"hazard_forecast", &"review_forecast", {&"forecast": definition[&"forecast"]}, 100),
		_read(
			&"hazard_mitigation",
			&"review_mitigation",
			{&"preparation": definition[&"preparation"]},
			200
		),
		_offer(
			&"hazard_stabilize",
			&"stabilize_hazard",
			{
				&"event_id": int(event[&"id"]),
				&"kind": kind,
				&"token": token,
				&"item_id": definition[&"reward_item_id"],
				&"count": int(definition[&"reward_count"]),
			},
			false,
			&"interaction.reason.hazard_runtime_transaction_unavailable",
			300,
		),
	]
	return _target(
		cell,
		StringName("hazard.%s.%d" % [kind, int(event[&"id"])]),
		&"hazard",
		{&"kind": kind, &"age": float(event[&"age"]), &"prepared": prepared, &"token": token},
		options,
		&"hostile",
	)


static func ruin(cell: Vector2i, ruin_state: Dictionary, farm: Dictionary) -> Dictionary:
	var ruin_id: StringName = ruin_state[&"id"] as StringName
	var token: String = "ruin:%s:activated" % ruin_id
	var activated: bool = EcologyDirectorScript.has_token(farm, token)
	var options: Array[Dictionary] = [
		_inspect(cell),
		_read(
			&"sanctuary_review",
			&"review_sanctuary",
			{&"ruin_id": ruin_id, &"activated": activated},
			100
		),
		_offer(
			&"remote_ruin_activate",
			&"activate_remote_ruin",
			{&"ruin_id": ruin_id},
			false,
			&"interaction.reason.activation_requires_expedition_return",
			200,
		),
	]
	return _target(cell, ruin_id, &"ruin", ruin_state, options)


static func gate(cell: Vector2i, active_run: Dictionary) -> Dictionary:
	var gate_id: StringName = StringName("expedition.gate:%d,%d" % [cell.x, cell.y])
	var review: Dictionary = {
		&"phase": StringName(str(active_run.get(&"phase", "run_phase.bootstrap"))),
		&"unbanked_scrap": int(active_run.get(&"unbanked_scrap", 0)),
		&"worm_cores": int(active_run.get(&"worm_cores", 0)),
	}
	var options: Array[Dictionary] = [
		_inspect(cell),
		_read(&"gate_biome", &"review_gate_biome", {&"cell": cell}, 100),
		_read(&"gate_risk", &"review_gate_risk", review, 200),
		_offer(
			&"gate_enter",
			&"enter_expedition_gate",
			{&"cell": cell},
			false,
			&"interaction.reason.gate_entry_authority_unavailable",
			300,
		),
	]
	return _target(cell, gate_id, &"expedition_gate", review, options)


static func _drop_for_source(source: StringName) -> Dictionary:
	for entry: Dictionary in WildernessLootScript.DEFINITIONS:
		if entry[&"source"] == source:
			return {
				&"item_id": entry[&"item_id"] as StringName,
				&"capability": entry[&"capability"] as StringName,
				&"tier": int(entry[&"tier"]),
			}
	return {&"item_id": &"item.material.scrap", &"capability": &"", &"tier": 1}


static func _inspect(cell: Vector2i) -> Dictionary:
	return _read(&"inspect", &"inspect", {&"cell": cell}, 0)


static func _read(
	action: StringName, operation: StringName, arguments: Dictionary, priority: int
) -> Dictionary:
	return _offer(action, operation, arguments, true, &"", priority, [], OptionScript.CLOSE_NEVER)


static func _offer(
	action: StringName,
	operation: StringName,
	arguments: Dictionary,
	enabled: bool,
	reason: StringName,
	priority: int,
	costs: Array[Dictionary] = [],
	close: StringName = OptionScript.CLOSE_ON_SUCCESS,
) -> Dictionary:
	return (
		TargetBridgeScript
		. option_input(
			StringName("interaction.action.%s" % str(action)),
			operation,
			arguments,
			enabled,
			reason if not enabled else &"",
			priority,
			costs,
			close,
		)
	)


static func _target(
	cell: Vector2i,
	target_id: StringName,
	subkind: StringName,
	state: Dictionary,
	options: Array[Dictionary],
	kind: StringName = &"structure",
) -> Dictionary:
	return (
		TargetScript
		. build(
			cell,
			target_id,
			kind,
			subkind,
			StringName("interaction.target.%s.title" % str(subkind)),
			state,
			options,
		)
	)


static func _reason(reason: StringName) -> StringName:
	return (
		&"interaction.reason.unavailable"
		if reason == &""
		else StringName("interaction.reason.%s" % str(reason))
	)


static func _tool_reason(
	farm: Dictionary,
	selected: StringName,
	required: StringName,
	mismatch: StringName,
) -> StringName:
	if selected != required:
		return mismatch
	return &"" if ToolServiceScript.can_spend(farm, required) else &"interaction.reason.exhausted"
