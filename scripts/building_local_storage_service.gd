extends RefCounted

const ConstructionStateScript: GDScript = preload(
	"res://scripts/construction_state_service.gd"
)
const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")

const OUTPUT_KEY: StringName = &"local_stacks"
const INPUT_KEY: StringName = &"local_input_stacks"


static func count(farm: Dictionary, site_id: StringName, item_id: StringName) -> int:
	return _count(farm, site_id, item_id, OUTPUT_KEY)


static func input_count(farm: Dictionary, site_id: StringName, item_id: StringName) -> int:
	return _count(farm, site_id, item_id, INPUT_KEY)


static func can_credit(
	farm: Dictionary, site_id: StringName, item_id: StringName, amount: int
) -> Dictionary:
	var checked: Dictionary = _mutate(farm, site_id, item_id, amount, OUTPUT_KEY)
	var reason: StringName = checked[&"reason"] as StringName
	if reason == &"local_storage_full":
		reason = &"local_output_full"
	elif reason == &"invalid_local_storage":
		reason = &"invalid_local_output"
	return {&"ok": checked[&"ok"], &"reason": reason}


static func can_credit_input(
	farm: Dictionary, site_id: StringName, item_id: StringName, amount: int
) -> Dictionary:
	var checked: Dictionary = _mutate(farm, site_id, item_id, amount, INPUT_KEY)
	return {&"ok": checked[&"ok"], &"reason": checked[&"reason"]}


static func credit(
	farm: Dictionary, site_id: StringName, item_id: StringName, amount: int
) -> Dictionary:
	return _mutate(farm, site_id, item_id, amount, OUTPUT_KEY)


static func credit_input(
	farm: Dictionary, site_id: StringName, item_id: StringName, amount: int
) -> Dictionary:
	return _mutate(farm, site_id, item_id, amount, INPUT_KEY)


static func remove(
	farm: Dictionary, site_id: StringName, item_id: StringName, amount: int
) -> Dictionary:
	return _mutate(farm, site_id, item_id, -amount, OUTPUT_KEY)


static func remove_input(
	farm: Dictionary, site_id: StringName, item_id: StringName, amount: int
) -> Dictionary:
	return _mutate(farm, site_id, item_id, -amount, INPUT_KEY)


static func transfer(
	farm: Dictionary,
	source_id: StringName,
	destination_id: StringName,
	item_id: StringName,
	amount: int,
	destination_input: bool,
) -> Dictionary:
	if source_id == destination_id or amount <= 0:
		return _result(false, farm, &"invalid_local_transfer")
	var removed: Dictionary = remove(farm, source_id, item_id, amount)
	if not bool(removed[&"ok"]):
		return removed
	var credited: Dictionary = (
		credit_input(removed[&"candidate"], destination_id, item_id, amount)
		if destination_input
		else credit(removed[&"candidate"], destination_id, item_id, amount)
	)
	return credited if bool(credited[&"ok"]) else _result(false, farm, credited[&"reason"])


static func _count(
	farm: Dictionary, site_id: StringName, item_id: StringName, key: StringName
) -> int:
	var building: Dictionary = ConstructionStateScript.building(farm, site_id)
	for stack: Dictionary in building.get(key, []) as Array[Dictionary]:
		if StringName(str(stack[&"item_id"])) == item_id:
			return int(stack[&"count"])
	return 0


static func _mutate(
	farm: Dictionary,
	site_id: StringName,
	item_id: StringName,
	delta: int,
	key: StringName,
) -> Dictionary:
	if delta == 0 or item_id not in ItemCatalogScript.ids():
		return _result(false, farm, &"invalid_local_storage")
	var building: Dictionary = ConstructionStateScript.building(farm, site_id)
	if building.is_empty():
		return _result(false, farm, &"work_site_missing")
	if str(building[&"state"]) != "complete":
		return _result(false, farm, &"work_site_incomplete")
	var stacks: Array[Dictionary] = []
	var found: bool = false
	for current: Dictionary in building.get(key, []) as Array[Dictionary]:
		var stack: Dictionary = current.duplicate(true)
		if StringName(str(stack[&"item_id"])) == item_id:
			var next_count: int = int(stack[&"count"]) + delta
			if next_count < 0:
				return _result(false, farm, &"local_items_missing")
			if next_count > ItemCatalogScript.stack_limit(item_id):
				return _result(false, farm, &"local_storage_full")
			if next_count > 0:
				stack[&"count"] = next_count
				stacks.append(stack)
			found = true
		else:
			stacks.append(stack)
	if not found:
		if delta < 0:
			return _result(false, farm, &"local_items_missing")
		if (
			stacks.size() >= SectionsScript.MAX_LOCAL_STACKS
			or delta > ItemCatalogScript.stack_limit(item_id)
		):
			return _result(false, farm, &"local_storage_full")
		stacks.append({&"item_id": str(item_id), &"count": delta})
	stacks.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"item_id"]) < str(b[&"item_id"])
	)
	building[key] = stacks
	return _write_building(farm, building)


static func _write_building(farm: Dictionary, building: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate.get(&"homestead", {}) as Dictionary
	var construction: Dictionary = homestead.get(&"construction", {}) as Dictionary
	var buildings: Array[Dictionary] = []
	var found: bool = false
	for current: Dictionary in construction.get(&"buildings", []) as Array[Dictionary]:
		if str(current[&"instance_id"]) == str(building[&"instance_id"]):
			buildings.append(building.duplicate(true))
			found = true
		else:
			buildings.append(current.duplicate(true))
	if not found:
		return _result(false, farm, &"work_site_missing")
	construction[&"buildings"] = buildings
	construction = SectionsScript.validate_construction(construction)
	if construction.is_empty():
		return _result(false, farm, &"invalid_local_storage")
	homestead[&"construction"] = construction
	candidate[&"homestead"] = homestead
	var normalized: Dictionary = FarmSchemaScript.validate(candidate)
	return _result(
		not normalized.is_empty(), normalized if not normalized.is_empty() else farm,
		&"" if not normalized.is_empty() else &"invalid_local_storage"
	)


static func _result(ok: bool, candidate: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": candidate.duplicate(true), &"reason": reason}
