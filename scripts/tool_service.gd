extends RefCounted

const TOOL_HOE: StringName = &"tool.hoe"
const TOOL_WATERING: StringName = &"tool.watering"
const TOOL_AXE: StringName = &"tool.axe"
const TOOL_PICK: StringName = &"tool.pick"
const TOOL_CONTEXT: StringName = &"tool.context"
const UPGRADE_WATER_EFFICIENCY: StringName = &"upgrade.tool.watering_efficiency"
const MAX_STAMINA: int = 100
const DAILY_RECOVERY: int = 100
const HOLD_INITIAL_DELAY_MS: int = 320
const HOLD_INTERVAL_MS: int = 260
const MAX_REPEAT_ACTIONS: int = 8
const DEFINITIONS: Array[Dictionary] = [
	{&"tool_id": TOOL_HOE, &"stamina_cost": 8, &"target": &"soil"},
	{&"tool_id": TOOL_WATERING, &"stamina_cost": 5, &"target": &"plot"},
	{&"tool_id": TOOL_AXE, &"stamina_cost": 10, &"target": &"tree"},
	{&"tool_id": TOOL_PICK, &"stamina_cost": 12, &"target": &"rock"},
	{&"tool_id": TOOL_CONTEXT, &"stamina_cost": 2, &"target": &"crop"},
]


static func ensure_default(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var tools: Dictionary = candidate.get(&"tools", {}) as Dictionary
	if tools.has(&"stamina"):
		return candidate
	tools[&"equipped_tool_id"] = String(TOOL_HOE)
	tools[&"upgrade_ids"] = []
	tools[&"stamina"] = MAX_STAMINA
	tools[&"max_stamina"] = MAX_STAMINA
	candidate[&"tools"] = tools
	return candidate


static func definition(tool_id: StringName) -> Dictionary:
	for candidate: Dictionary in DEFINITIONS:
		if candidate[&"tool_id"] == tool_id:
			return candidate.duplicate(true)
	return {}


static func stamina_cost(farm: Dictionary, tool_id: StringName) -> int:
	var cost: int = int(definition(tool_id).get(&"stamina_cost", 0))
	var upgrades: Array = (farm.get(&"tools", {}) as Dictionary).get(&"upgrade_ids", []) as Array
	if tool_id == TOOL_WATERING and String(UPGRADE_WATER_EFFICIENCY) in upgrades:
		cost = maxi(cost - 2, 1)
	return cost


static func can_spend(farm: Dictionary, tool_id: StringName) -> bool:
	var tools: Dictionary = farm.get(&"tools", {}) as Dictionary
	var cost: int = stamina_cost(farm, tool_id)
	return not definition(tool_id).is_empty() and cost > 0 and int(tools.get(&"stamina", 0)) >= cost


static func spend(farm: Dictionary, tool_id: StringName) -> Dictionary:
	if not can_spend(farm, tool_id):
		return {&"ok": false, &"candidate": farm.duplicate(true), &"reason": &"exhausted"}
	var candidate: Dictionary = farm.duplicate(true)
	var tools: Dictionary = candidate[&"tools"] as Dictionary
	tools[&"stamina"] = int(tools[&"stamina"]) - stamina_cost(candidate, tool_id)
	tools[&"equipped_tool_id"] = String(
		tool_id if tool_id != TOOL_CONTEXT else StringName(tools[&"equipped_tool_id"])
	)
	candidate[&"tools"] = tools
	return {&"ok": true, &"candidate": candidate, &"reason": &""}


static func recover(farm: Dictionary, amount: int = DAILY_RECOVERY) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var tools: Dictionary = candidate[&"tools"] as Dictionary
	tools[&"stamina"] = mini(int(tools[&"max_stamina"]), int(tools[&"stamina"]) + maxi(amount, 0))
	candidate[&"tools"] = tools
	return candidate


static func repeat_fire_count(held_msec: int) -> int:
	if held_msec < HOLD_INITIAL_DELAY_MS:
		return 0
	return mini(1 + (held_msec - HOLD_INITIAL_DELAY_MS) / HOLD_INTERVAL_MS, MAX_REPEAT_ACTIONS)


static func movement_allowed(_farm: Dictionary) -> bool:
	return true


static func menus_allowed(_farm: Dictionary) -> bool:
	return true


static func validate() -> bool:
	var seen: Dictionary = {}
	for tool: Dictionary in DEFINITIONS:
		if seen.has(tool[&"tool_id"]) or int(tool[&"stamina_cost"]) <= 0:
			return false
		seen[tool[&"tool_id"]] = true
	return seen.size() == 5 and repeat_fire_count(60_000) == MAX_REPEAT_ACTIONS
