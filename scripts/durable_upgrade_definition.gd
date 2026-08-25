extends Resource

@export var upgrade_id: StringName = &""
@export var family: StringName = &""
@export var prerequisites: Array[StringName] = []
@export_range(0, 1_000_000_000, 1) var money_cost: int = 0
@export var item_costs: Array[Dictionary] = []
@export var capabilities: Array[StringName] = []


func validate(
	families: Array[StringName], item_ids: Array[StringName], upgrade_ids: Array[StringName]
) -> bool:
	if (
		not String(upgrade_id).begins_with("upgrade.")
		or family not in families
		or money_cost < 0
		or capabilities.is_empty()
	):
		return false
	var seen_prerequisites: Dictionary = {}
	for prerequisite: StringName in prerequisites:
		if (
			prerequisite == upgrade_id
			or prerequisite not in upgrade_ids
			or seen_prerequisites.has(prerequisite)
		):
			return false
		seen_prerequisites[prerequisite] = true
	var seen_capabilities: Dictionary = {}
	for capability: StringName in capabilities:
		if not String(capability).begins_with("capability.") or seen_capabilities.has(capability):
			return false
		seen_capabilities[capability] = true
	var seen_costs: Dictionary = {}
	for cost: Dictionary in item_costs:
		if cost.size() != 2 or not cost.has(&"item_id") or not cost.has(&"count"):
			return false
		var item_id: StringName = StringName(str(cost[&"item_id"]))
		var count: Variant = cost[&"count"]
		if (
			item_id not in item_ids
			or seen_costs.has(item_id)
			or not count is int
			or int(count) <= 0
			or int(count) > 999
		):
			return false
		seen_costs[item_id] = true
	return money_cost > 0 or not item_costs.is_empty()


func to_dictionary() -> Dictionary:
	var prerequisite_values: Array[String] = []
	for prerequisite: StringName in prerequisites:
		prerequisite_values.append(String(prerequisite))
	var capability_values: Array[String] = []
	for capability: StringName in capabilities:
		capability_values.append(String(capability))
	return {
		&"upgrade_id": String(upgrade_id),
		&"family": String(family),
		&"prerequisites": prerequisite_values,
		&"money_cost": money_cost,
		&"item_costs": item_costs.duplicate(true),
		&"capabilities": capability_values,
	}
