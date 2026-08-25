extends RefCounted

const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")

const SHIPPING_BIN_ID: StringName = &"structure.shipping_bin"
const SEED_SHOP_ID: StringName = &"shop.seed_cache"
const WORKSHOP_ID: StringName = &"structure.workshop_bench"
const UPGRADE_PRICE: int = 120
const UPGRADE_WOOD_COST: int = 5


static func ensure_default(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var economy: Dictionary = candidate.get(&"economy", {}) as Dictionary
	if economy.has(&"last_settlement_total"):
		return candidate
	economy[&"money"] = 50
	economy[&"shipping"] = []
	economy[&"last_settlement_total"] = 0
	economy[&"settlement_tokens"] = []
	candidate[&"economy"] = economy
	return candidate


static func shipping_preview(farm: Dictionary) -> Dictionary:
	var total: int = 0
	var item_count: int = 0
	for entry: Dictionary in (farm[&"economy"] as Dictionary)[&"shipping"] as Array[Dictionary]:
		var count: int = int(entry[&"count"])
		total += ItemCatalogScript.sell_price(StringName(entry[&"item_id"])) * count
		item_count += count
	return {&"money": total, &"item_count": item_count}


static func ship(farm: Dictionary, item_id: StringName, count: int) -> Dictionary:
	if ItemCatalogScript.sell_price(item_id) <= 0 or count <= 0:
		return _result(false, farm, &"not_shippable")
	var removed: Dictionary = InventoryServiceScript.remove_across(farm, item_id, count)
	if not bool(removed[&"ok"]):
		return _result(false, farm, &"insufficient_items")
	var candidate: Dictionary = removed[&"candidate"] as Dictionary
	var economy: Dictionary = candidate[&"economy"] as Dictionary
	var shipping: Array = (economy[&"shipping"] as Array).duplicate(true)
	var merged: bool = false
	for index: int in shipping.size():
		var entry: Dictionary = shipping[index] as Dictionary
		if StringName(entry[&"item_id"]) == item_id:
			entry[&"count"] = int(entry[&"count"]) + count
			shipping[index] = entry
			merged = true
			break
	if not merged:
		shipping.append({&"item_id": String(item_id), &"count": count})
	shipping.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return str(a[&"item_id"]) < str(b[&"item_id"])
	)
	economy[&"shipping"] = shipping
	candidate[&"economy"] = economy
	return _result(true, candidate, &"")


static func settle(farm: Dictionary, day_token: String) -> Dictionary:
	var economy: Dictionary = farm[&"economy"] as Dictionary
	if day_token in (economy[&"settlement_tokens"] as Array):
		return _result(false, farm, &"settlement_already_applied")
	var preview: Dictionary = shipping_preview(farm)
	var candidate: Dictionary = farm.duplicate(true)
	economy = candidate[&"economy"] as Dictionary
	economy[&"money"] = int(economy[&"money"]) + int(preview[&"money"])
	economy[&"shipping"] = []
	economy[&"last_settlement_total"] = int(preview[&"money"])
	var tokens: Array = (economy[&"settlement_tokens"] as Array).duplicate()
	tokens.append(day_token)
	if tokens.size() > 64:
		tokens.pop_front()
	economy[&"settlement_tokens"] = tokens
	candidate[&"economy"] = economy
	var result: Dictionary = _result(true, candidate, &"")
	result[&"money_earned"] = int(preview[&"money"])
	return result


static func buy_seed(farm: Dictionary, seed_item_id: StringName, count: int) -> Dictionary:
	var price: int = ItemCatalogScript.buy_price(seed_item_id) * count
	if count <= 0 or ItemCatalogScript.category(seed_item_id) != ItemCatalogScript.CATEGORY_SEED:
		return _result(false, farm, &"invalid_seed")
	var economy: Dictionary = farm[&"economy"] as Dictionary
	if int(economy[&"money"]) < price:
		return _result(false, farm, &"insufficient_money")
	var candidate: Dictionary = farm.duplicate(true)
	(candidate[&"economy"] as Dictionary)[&"money"] = int(economy[&"money"]) - price
	var credited: Dictionary = InventoryServiceScript.credit_with_overflow(
		candidate, seed_item_id, count
	)
	return (
		_result(true, credited[&"candidate"] as Dictionary, &"")
		if bool(credited[&"ok"])
		else _result(false, farm, &"inventory_full")
	)


static func purchase_workshop_upgrade(farm: Dictionary) -> Dictionary:
	var tools: Dictionary = farm[&"tools"] as Dictionary
	if String(ToolServiceScript.UPGRADE_WATER_EFFICIENCY) in (tools[&"upgrade_ids"] as Array):
		return _result(false, farm, &"upgrade_already_owned")
	var economy: Dictionary = farm[&"economy"] as Dictionary
	if int(economy[&"money"]) < UPGRADE_PRICE:
		return _result(false, farm, &"insufficient_money")
	var removed: Dictionary = InventoryServiceScript.remove_across(
		farm, &"item.material.wood", UPGRADE_WOOD_COST
	)
	if not bool(removed[&"ok"]):
		return _result(false, farm, &"missing_materials")
	var candidate: Dictionary = removed[&"candidate"] as Dictionary
	(candidate[&"economy"] as Dictionary)[&"money"] = int(economy[&"money"]) - UPGRADE_PRICE
	tools = candidate[&"tools"] as Dictionary
	var upgrades: Array = (tools[&"upgrade_ids"] as Array).duplicate()
	upgrades.append(String(ToolServiceScript.UPGRADE_WATER_EFFICIENCY))
	tools[&"upgrade_ids"] = upgrades
	candidate[&"tools"] = tools
	return _result(true, candidate, &"")


static func _result(ok: bool, farm: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": farm.duplicate(true), &"reason": reason}
