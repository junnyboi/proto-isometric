extends RefCounted

const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")

const ROBOT_ID: StringName = &"inventory.robot"
const HOME_ID: StringName = &"inventory.home"
const ROBOT_SLOTS: int = 12
const HOME_SLOTS: int = 48


static func ensure_default(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	if not (candidate.get(&"inventories", []) as Array).is_empty():
		return candidate
	candidate[&"inventories"] = [
		{
			&"container_id": String(ROBOT_ID),
			&"capacity_slots": ROBOT_SLOTS,
			&"stacks":
			[
				{&"item_id": "item.seed.glowroot", &"count": 3},
				{&"item_id": "item.material.stone", &"count": 2},
			],
		},
		{
			&"container_id": String(HOME_ID),
			&"capacity_slots": HOME_SLOTS,
			&"stacks": [{&"item_id": "item.material.wood", &"count": 12}],
		},
	]
	return candidate


static func count_item(farm: Dictionary, container_id: StringName, item_id: StringName) -> int:
	var inventory: Dictionary = _inventory(farm, container_id)
	var total: int = 0
	for stack: Dictionary in inventory.get(&"stacks", []) as Array[Dictionary]:
		if StringName(stack[&"item_id"]) == item_id:
			total += int(stack[&"count"])
	return total


static func count_all(farm: Dictionary, item_id: StringName) -> int:
	var total: int = 0
	for inventory: Dictionary in farm.get(&"inventories", []) as Array[Dictionary]:
		total += count_item(farm, StringName(inventory[&"container_id"]), item_id)
	return total


static func summary(farm: Dictionary, container_id: StringName) -> Dictionary:
	var inventory: Dictionary = _inventory(farm, container_id)
	if inventory.is_empty():
		return {}
	var stacks: Array[Dictionary] = inventory.get(&"stacks", []) as Array[Dictionary]
	var item_count: int = 0
	for stack: Dictionary in stacks:
		item_count += maxi(int(stack.get(&"count", 0)), 0)
	return {
		&"item_count": item_count,
		&"occupied_slots": stacks.size(),
		&"capacity_slots": int(inventory.get(&"capacity_slots", 0)),
	}


static func transfer(
	farm: Dictionary,
	source_id: StringName,
	destination_id: StringName,
	item_id: StringName,
	requested: int,
) -> Dictionary:
	if requested <= 0 or source_id == destination_id or item_id not in ItemCatalogScript.ids():
		return _result(false, farm, 0, maxi(requested, 0), &"invalid_transfer")
	var available: int = count_item(farm, source_id, item_id)
	var accepted: int = mini(
		mini(requested, available), _available_capacity(farm, destination_id, item_id)
	)
	if accepted <= 0:
		return _result(false, farm, 0, requested, &"destination_full")
	var candidate: Dictionary = farm.duplicate(true)
	if not _set_count(candidate, source_id, item_id, available - accepted):
		return _result(false, farm, 0, requested, &"missing_source")
	var destination_count: int = count_item(candidate, destination_id, item_id)
	if not _set_count(candidate, destination_id, item_id, destination_count + accepted):
		return _result(false, farm, 0, requested, &"missing_destination")
	return _result(true, candidate, accepted, requested - accepted, &"")


static func credit_with_overflow(farm: Dictionary, item_id: StringName, count: int) -> Dictionary:
	if count <= 0 or item_id not in ItemCatalogScript.ids():
		return _result(false, farm, 0, maxi(count, 0), &"invalid_item")
	var candidate: Dictionary = farm.duplicate(true)
	var remaining: int = count
	for container_id: StringName in [ROBOT_ID, HOME_ID]:
		var accepted: int = mini(remaining, _available_capacity(candidate, container_id, item_id))
		if accepted <= 0:
			continue
		var current: int = count_item(candidate, container_id, item_id)
		_set_count(candidate, container_id, item_id, current + accepted)
		remaining -= accepted
	if remaining > 0:
		return _result(false, farm, 0, count, &"all_containers_full")
	return _result(true, candidate, count, 0, &"")


static func remove(
	farm: Dictionary, container_id: StringName, item_id: StringName, count: int
) -> Dictionary:
	var available: int = count_item(farm, container_id, item_id)
	if count <= 0 or available < count:
		return _result(false, farm, 0, maxi(count, 0), &"insufficient_items")
	var candidate: Dictionary = farm.duplicate(true)
	_set_count(candidate, container_id, item_id, available - count)
	return _result(true, candidate, count, 0, &"")


static func remove_across(farm: Dictionary, item_id: StringName, count: int) -> Dictionary:
	if count <= 0 or count_all(farm, item_id) < count:
		return _result(false, farm, 0, maxi(count, 0), &"insufficient_items")
	var candidate: Dictionary = farm.duplicate(true)
	var remaining: int = count
	for container_id: StringName in [ROBOT_ID, HOME_ID]:
		var available: int = count_item(candidate, container_id, item_id)
		var removed: int = mini(available, remaining)
		if removed > 0:
			_set_count(candidate, container_id, item_id, available - removed)
			remaining -= removed
	return _result(true, candidate, count, 0, &"")


static func _available_capacity(
	farm: Dictionary, container_id: StringName, item_id: StringName
) -> int:
	var inventory: Dictionary = _inventory(farm, container_id)
	if inventory.is_empty():
		return 0
	var current: int = count_item(farm, container_id, item_id)
	var limit: int = ItemCatalogScript.stack_limit(item_id)
	if current > 0:
		return maxi(limit - current, 0)
	var stacks: Array = inventory[&"stacks"] as Array
	return limit if stacks.size() < int(inventory[&"capacity_slots"]) else 0


static func _inventory(farm: Dictionary, container_id: StringName) -> Dictionary:
	for inventory: Dictionary in farm.get(&"inventories", []) as Array[Dictionary]:
		if StringName(inventory[&"container_id"]) == container_id:
			return inventory
	return {}


static func _set_count(
	farm: Dictionary, container_id: StringName, item_id: StringName, count: int
) -> bool:
	var inventories: Array = farm.get(&"inventories", []) as Array
	for inventory_index: int in inventories.size():
		var inventory: Dictionary = inventories[inventory_index] as Dictionary
		if StringName(inventory[&"container_id"]) != container_id:
			continue
		var stacks: Array = (inventory[&"stacks"] as Array).duplicate(true)
		var found: int = -1
		for stack_index: int in stacks.size():
			if StringName((stacks[stack_index] as Dictionary)[&"item_id"]) == item_id:
				found = stack_index
				break
		if count <= 0 and found >= 0:
			stacks.remove_at(found)
		elif found >= 0:
			(stacks[found] as Dictionary)[&"count"] = count
		elif count > 0:
			stacks.append({&"item_id": String(item_id), &"count": count})
		stacks.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return str(a[&"item_id"]) < str(b[&"item_id"])
		)
		inventory[&"stacks"] = stacks
		inventories[inventory_index] = inventory
		farm[&"inventories"] = inventories
		return true
	return false


static func _result(
	ok: bool, farm: Dictionary, moved: int, overflow: int, reason: StringName
) -> Dictionary:
	return {
		&"ok": ok,
		&"candidate": farm.duplicate(true),
		&"moved": moved,
		&"overflow": overflow,
		&"reason": reason,
	}
