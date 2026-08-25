extends RefCounted

const CatalogScript: GDScript = preload("res://scripts/durable_upgrade_catalog.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const MachineServiceScript: GDScript = preload("res://scripts/machine_service.gd")

const FURNACE_UPGRADE: StringName = &"upgrade.machine.furnace"
const ROBOT_CHASSIS_UPGRADE: StringName = &"upgrade.robot.chassis_capacity"
const STORAGE_UPGRADE: StringName = &"upgrade.storage.home_expansion"


static func capabilities(farm: Dictionary) -> Array[StringName]:
	return CatalogScript.capabilities_for(
		(farm.get(&"tools", {}) as Dictionary).get(&"upgrade_ids", []) as Array
	)


static func purchase(farm: Dictionary, upgrade_id: StringName) -> Dictionary:
	var definition: Dictionary = CatalogScript.definition(upgrade_id)
	if definition.is_empty():
		return _result(false, farm, &"unknown_upgrade")
	var tools: Dictionary = farm.get(&"tools", {}) as Dictionary
	var owned: Array = tools.get(&"upgrade_ids", []) as Array
	if String(upgrade_id) in owned:
		return _result(false, farm, &"upgrade_already_owned")
	for raw_prerequisite: Variant in definition[&"prerequisites"] as Array:
		if str(raw_prerequisite) not in owned:
			return _result(false, farm, &"missing_prerequisite")
	var economy: Dictionary = farm.get(&"economy", {}) as Dictionary
	if int(economy.get(&"money", 0)) < int(definition[&"money_cost"]):
		return _result(false, farm, &"insufficient_money")
	var candidate: Dictionary = farm.duplicate(true)
	for raw_cost: Variant in definition[&"item_costs"] as Array:
		var cost: Dictionary = raw_cost as Dictionary
		var removed: Dictionary = InventoryServiceScript.remove_across(
			candidate, StringName(str(cost[&"item_id"])), int(cost[&"count"])
		)
		if not bool(removed[&"ok"]):
			return _result(false, farm, &"missing_materials")
		candidate = removed[&"candidate"] as Dictionary
	(candidate[&"economy"] as Dictionary)[&"money"] = (
		int(economy[&"money"]) - int(definition[&"money_cost"])
	)
	tools = candidate[&"tools"] as Dictionary
	var upgrades: Array = (tools[&"upgrade_ids"] as Array).duplicate()
	upgrades.append(String(upgrade_id))
	upgrades.sort()
	tools[&"upgrade_ids"] = upgrades
	candidate[&"tools"] = tools
	match upgrade_id:
		ROBOT_CHASSIS_UPGRADE:
			(candidate[&"tools"] as Dictionary)[&"max_stamina"] = int(tools[&"max_stamina"]) + 20
			(candidate[&"tools"] as Dictionary)[&"stamina"] = int(tools[&"stamina"]) + 20
		STORAGE_UPGRADE:
			candidate = _expand_home_storage(candidate)
		FURNACE_UPGRADE:
			var installed: Dictionary = MachineServiceScript.install_furnace(candidate)
			if not bool(installed[&"ok"]):
				return _result(false, farm, installed[&"reason"] as StringName)
			candidate = installed[&"candidate"] as Dictionary
	return _result(true, candidate, &"")


static func _expand_home_storage(farm: Dictionary) -> Dictionary:
	var result: Dictionary = farm.duplicate(true)
	var inventories: Array = (result[&"inventories"] as Array).duplicate(true)
	for index: int in inventories.size():
		var inventory: Dictionary = (inventories[index] as Dictionary).duplicate(true)
		if inventory[&"container_id"] == "inventory.home":
			inventory[&"capacity_slots"] = int(inventory[&"capacity_slots"]) + 12
			inventories[index] = inventory
	result[&"inventories"] = inventories
	return result


static func _result(ok: bool, farm: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": farm.duplicate(true), &"reason": reason}
