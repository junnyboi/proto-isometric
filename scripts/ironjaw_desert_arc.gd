extends RefCounted

const EcologyDirectorScript: GDScript = preload("res://scripts/ecology_director.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")

const LAIR_ID: StringName = &"lair.ironjaw.sunken_crown"
const QUEST_ID: StringName = &"quest.ironjaw.burrow_core"
const REQUIRED_REQUEST_ID: StringName = &"request.rook.scrap"
const LAIR_CENTER: Vector2i = Vector2i(0, 52)
const SAFE_EXIT: Vector2i = Vector2i(0, 47)
const WELL_CELL: Vector2i = Vector2i(5, 9)
const BURROW_CORE_ITEM: StringName = &"item.boss.burrow_core"
const DEEP_TILL_CELLS: Array[Vector2i] = [
	Vector2i(16, 7),
	Vector2i(16, 8),
	Vector2i(16, 9),
	Vector2i(16, 10),
	Vector2i(16, 11),
	Vector2i(16, 12),
]


static func definition() -> Dictionary:
	return {
		&"lair_id": LAIR_ID,
		&"quest_id": QUEST_ID,
		&"center": LAIR_CENTER,
		&"safe_exit": SAFE_EXIT,
		&"footprint": lair_cells(),
		&"reward_item_id": BURROW_CORE_ITEM,
		&"first_clear_id": EcologyDirectorScript.IRONJAW_CLEAR_ID,
	}


static func lair_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(LAIR_CENTER.y - 3, LAIR_CENTER.y + 4):
		for x: int in range(LAIR_CENTER.x - 4, LAIR_CENTER.x + 5):
			if Vector2(x, y).distance_to(Vector2(LAIR_CENTER)) <= 4.2:
				result.append(Vector2i(x, y))
	return result


static func quest_unlocked(farm: Dictionary) -> bool:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	for request: Dictionary in homestead.get(&"requests", []) as Array[Dictionary]:
		if StringName(str(request[&"request_id"])) == REQUIRED_REQUEST_ID:
			return request[&"status"] == "completed"
	return false


static func is_first_clear(farm: Dictionary) -> bool:
	return (
		String(EcologyDirectorScript.IRONJAW_CLEAR_ID)
		in ((farm.get(&"ecology", {}) as Dictionary).get(&"boss_first_clear_ids", []) as Array)
	)


static func complete_first_clear(farm: Dictionary) -> Dictionary:
	if not quest_unlocked(farm):
		return _result(false, farm, &"ironjaw_quest_locked")
	if is_first_clear(farm):
		return _result(false, farm, &"ironjaw_already_cleared")
	var credited: Dictionary = InventoryServiceScript.credit_with_overflow(
		farm, BURROW_CORE_ITEM, 1
	)
	if not bool(credited[&"ok"]):
		return _result(false, farm, &"inventory_full")
	var candidate: Dictionary = credited[&"candidate"] as Dictionary
	var ecology: Dictionary = candidate[&"ecology"] as Dictionary
	var clears: Array = (ecology[&"boss_first_clear_ids"] as Array).duplicate()
	clears.append(String(EcologyDirectorScript.IRONJAW_CLEAR_ID))
	clears.sort()
	ecology[&"boss_first_clear_ids"] = clears
	candidate[&"ecology"] = ecology
	var result: Dictionary = _result(true, candidate, &"")
	result[&"safe_exit"] = SAFE_EXIT
	result[&"capabilities"] = [&"capability.farm.deep_tilling", &"capability.farm.well"]
	return result


static func deep_tillable(farm: Dictionary, cell: Vector2i) -> bool:
	return is_first_clear(farm) and cell in DEEP_TILL_CELLS


static func _result(ok: bool, farm: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": farm.duplicate(true), &"reason": reason}
