extends RefCounted

const EcologyDirectorScript: GDScript = preload("res://scripts/ecology_director.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")

const WATER_RETENTION: StringName = &"capability.farm.water_retention"
const COMPOST_YIELD: StringName = &"capability.farm.compost_yield"
const FROST_WARD: StringName = &"capability.farm.frost_ward"
const FURNACE_FLUX: StringName = &"capability.farm.furnace_flux"
const DEEP_TILLING: StringName = &"capability.farm.deep_tilling"
const WELL: StringName = &"capability.farm.well"
const UNLOCKS: Dictionary = {
	WATER_RETENTION:
	[
		{&"item_id": &"item.wild.glass_chitin", &"count": 3},
		{&"item_id": &"item.wild.dune_fiber", &"count": 2},
		{&"item_id": &"item.wild.dune_sinew", &"count": 1},
		{&"item_id": &"item.hazard.silica_loam", &"count": 1}
	],
	COMPOST_YIELD:
	[
		{&"item_id": &"item.wild.mire_spore", &"count": 3},
		{&"item_id": &"item.wild.reed_resin", &"count": 2},
		{&"item_id": &"item.wild.mire_membrane", &"count": 1},
		{&"item_id": &"item.hazard.bloom_compost", &"count": 1}
	],
	FROST_WARD:
	[
		{&"item_id": &"item.wild.rime_shard", &"count": 3},
		{&"item_id": &"item.wild.rime_wool", &"count": 2},
		{&"item_id": &"item.wild.rime_lens", &"count": 1},
		{&"item_id": &"item.hazard.ice_crystal", &"count": 1}
	],
	FURNACE_FLUX:
	[
		{&"item_id": &"item.wild.ember_shell", &"count": 3},
		{&"item_id": &"item.wild.ember_fleece", &"count": 2},
		{&"item_id": &"item.wild.cinder_gland", &"count": 1},
		{&"item_id": &"item.hazard.vent_glass", &"count": 1}
	],
}


static func capabilities(farm: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for capability: StringName in UNLOCKS:
		if has(farm, capability):
			result.append(capability)
	var clears: Array = (
		(farm.get(&"ecology", {}) as Dictionary).get(&"boss_first_clear_ids", []) as Array
	)
	if String(EcologyDirectorScript.IRONJAW_CLEAR_ID) in clears:
		result.append(DEEP_TILLING)
		result.append(WELL)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result


static func has(farm: Dictionary, capability: StringName) -> bool:
	if capability in [DEEP_TILLING, WELL]:
		return String(EcologyDirectorScript.IRONJAW_CLEAR_ID) in (
			(farm.get(&"ecology", {}) as Dictionary).get(&"boss_first_clear_ids", []) as Array
		)
	return EcologyDirectorScript.has_token(farm, "capability:%s" % capability)


static func unlock(farm: Dictionary, capability: StringName) -> Dictionary:
	if not UNLOCKS.has(capability):
		return _result(false, farm, &"unknown_capability")
	if has(farm, capability):
		return _result(false, farm, &"capability_already_unlocked")
	var candidate: Dictionary = farm.duplicate(true)
	for cost: Dictionary in UNLOCKS[capability] as Array[Dictionary]:
		var removed: Dictionary = InventoryServiceScript.remove_across(
			candidate, cost[&"item_id"] as StringName, int(cost[&"count"])
		)
		if not bool(removed[&"ok"]):
			return _result(false, farm, &"missing_wilderness_materials")
		candidate = removed[&"candidate"] as Dictionary
	return EcologyDirectorScript.add_token(candidate, "capability:%s" % capability)


static func claim_hazard_reward(
	farm: Dictionary, token: String, item_id: StringName, count: int
) -> Dictionary:
	if not token.begins_with("hazard:") or count < 1 or count > 4:
		return _result(false, farm, &"invalid_hazard_reward")
	if EcologyDirectorScript.has_token(farm, token):
		return _result(false, farm, &"hazard_reward_already_claimed")
	var credited: Dictionary = InventoryServiceScript.credit_with_overflow(farm, item_id, count)
	if not bool(credited[&"ok"]):
		return _result(false, farm, &"inventory_full")
	return EcologyDirectorScript.add_token(credited[&"candidate"] as Dictionary, token)


static func _result(ok: bool, farm: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": farm.duplicate(true), &"reason": reason}
