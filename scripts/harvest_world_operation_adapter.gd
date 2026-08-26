extends RefCounted

const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")
const WildFloraCatalogScript: GDScript = preload("res://scripts/wild_flora_catalog.gd")
const WorldMutationLedgerScript: GDScript = preload("res://scripts/world_mutation_ledger.gd")

const TREE_REWARDS: Dictionary = {
	&"woodland_broadleaf_tree": {&"item_id": &"item.material.wood", &"count": 3},
	&"woodland_conifer_tree": {&"item_id": &"item.material.wood", &"count": 2},
}
const RESOURCE_REWARDS: Dictionary = {
	&"desert_ironstone": {&"item_id": &"item.ore.iron", &"count": 2},
	&"rock": {&"item_id": &"item.material.stone", &"count": 2},
}


static func reward_for(family: StringName, source_kind: StringName) -> Dictionary:
	if family == &"flora":
		var flora_reward: Dictionary = WildFloraCatalogScript.smash_reward(source_kind)
		return (
			{}
			if flora_reward.is_empty()
			else {
				&"item_id": flora_reward[&"produce_item_id"],
				&"count": int(flora_reward[&"produce_count"]),
				&"seed_item_id": flora_reward[&"seed_item_id"],
				&"seed_count": int(flora_reward[&"seed_count"]),
			}
		)
	var catalog: Dictionary = TREE_REWARDS if family == &"tree" else RESOURCE_REWARDS
	var fallback: Dictionary = (
		{&"item_id": &"item.material.wood", &"count": 2}
		if family == &"tree"
		else {&"item_id": &"item.material.stone", &"count": 2}
	)
	return (catalog.get(source_kind, fallback) as Dictionary).duplicate(true)


static func build(source: Dictionary, arguments: Dictionary) -> Dictionary:
	if not _arguments_valid(arguments):
		return _result(false, source, &"invalid_world_operation")
	var cell: Vector2i = arguments[&"cell"] as Vector2i
	var world_kind: StringName = arguments[&"world_kind"] as StringName
	var required_tool: StringName = arguments[&"required_tool"] as StringName
	var source_kind: StringName = arguments[&"source_kind"] as StringName
	var family: StringName = &"resource"
	if world_kind == &"object.tree":
		family = &"tree"
	elif world_kind == &"object.flora":
		family = &"flora"
	var canonical_reward: Dictionary = reward_for(family, source_kind)
	if canonical_reward.is_empty() or not _arguments_match_authority(
		arguments, family, canonical_reward
	):
		return _result(false, source, &"invalid_world_operation")
	var reward_item: StringName = canonical_reward[&"item_id"] as StringName
	var reward_count: int = int(canonical_reward[&"count"])
	var world: Dictionary = source.get(&"world", {}) as Dictionary
	var ledger: Dictionary = (
		WorldMutationLedgerScript.validate(world[&"mutation_ledger"])
		if world.has(&"mutation_ledger")
		else WorldMutationLedgerScript.from_legacy(world)
	)
	if ledger.is_empty():
		return _result(false, source, &"invalid_ledger")
	var cleared: Dictionary = WorldMutationLedgerScript.clear(
		ledger, WorldMutationLedgerScript.make_cleared(world_kind, cell, reward_count)
	)
	if not bool(cleared[&"ok"]):
		return _result(false, source, cleared[&"reason"] as StringName)
	var farm: Dictionary = source[&"farm"] as Dictionary
	var spent: Dictionary = ToolServiceScript.spend(farm, required_tool)
	if not bool(spent[&"ok"]):
		return _result(false, source, spent[&"reason"] as StringName)
	var credited: Dictionary = InventoryServiceScript.credit_with_overflow(
		spent[&"candidate"] as Dictionary, reward_item, reward_count
	)
	if not bool(credited[&"ok"]):
		return _result(false, source, &"inventory_full")
	if family == &"flora":
		credited = InventoryServiceScript.credit_with_overflow(
			credited[&"candidate"] as Dictionary,
			canonical_reward[&"seed_item_id"] as StringName,
			int(canonical_reward[&"seed_count"]),
		)
		if not bool(credited[&"ok"]):
			return _result(false, source, &"inventory_full")
	var adapted: Dictionary = WorldMutationLedgerScript.legacy_arrays_exact(
		world, cleared[&"candidate"] as Dictionary
	)
	if adapted.is_empty():
		return _result(false, source, &"invalid_world_clear")
	adapted[&"mutation_ledger"] = cleared[&"candidate"]
	var candidate: Dictionary = source.duplicate(true)
	candidate[&"world"] = adapted
	candidate[&"farm"] = credited[&"candidate"]
	return _result(true, candidate, &"")


static func _arguments_valid(arguments: Dictionary) -> bool:
	return (
		arguments.has(&"cell")
		and arguments[&"cell"] is Vector2i
		and (
			arguments.get(&"world_kind", &"")
			in [&"object.tree", &"object.rock", &"object.resource", &"object.flora"]
		)
		and (
			arguments.get(&"required_tool", &"")
			in [
				ToolServiceScript.TOOL_AXE,
				ToolServiceScript.TOOL_PICK,
				ToolServiceScript.TOOL_CONTEXT,
			]
		)
		and arguments.get(&"source_kind", &"") is StringName
		and arguments.get(&"reward_item_id", &"") is StringName
		and int(arguments.get(&"reward_count", 0)) in range(1, 1000)
	)


static func _arguments_match_authority(
	arguments: Dictionary, family: StringName, reward: Dictionary
) -> bool:
	var expected_tool: StringName = ToolServiceScript.TOOL_PICK
	if family == &"tree":
		expected_tool = ToolServiceScript.TOOL_AXE
	elif family == &"flora":
		expected_tool = ToolServiceScript.TOOL_CONTEXT
	var matches: bool = (
		arguments[&"required_tool"] == expected_tool
		and arguments[&"reward_item_id"] == reward[&"item_id"]
		and int(arguments[&"reward_count"]) == int(reward[&"count"])
	)
	if family != &"flora":
		return matches
	return (
		matches
		and arguments.get(&"seed_item_id", &"") == reward[&"seed_item_id"]
		and int(arguments.get(&"seed_count", 0)) == int(reward[&"seed_count"])
	)


static func _result(ok: bool, candidate: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": candidate.duplicate(true), &"reason": reason}
