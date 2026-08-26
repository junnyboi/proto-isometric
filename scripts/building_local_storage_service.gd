extends RefCounted

const ConstructionStateScript: GDScript = preload(
	"res://scripts/construction_state_service.gd"
)
const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")


static func count(farm: Dictionary, site_id: StringName, item_id: StringName) -> int:
	var building: Dictionary = ConstructionStateScript.building(farm, site_id)
	for stack: Dictionary in building.get(&"local_stacks", []) as Array[Dictionary]:
		if StringName(str(stack[&"item_id"])) == item_id:
			return int(stack[&"count"])
	return 0


static func can_credit(
	farm: Dictionary, site_id: StringName, item_id: StringName, amount: int
) -> Dictionary:
	var checked: Dictionary = _credit_candidate(farm, site_id, item_id, amount)
	return {&"ok": checked[&"ok"], &"reason": checked[&"reason"]}


static func credit(
	farm: Dictionary, site_id: StringName, item_id: StringName, amount: int
) -> Dictionary:
	return _credit_candidate(farm, site_id, item_id, amount)


static func _credit_candidate(
	farm: Dictionary, site_id: StringName, item_id: StringName, amount: int
) -> Dictionary:
	if amount <= 0 or item_id not in ItemCatalogScript.ids():
		return _result(false, farm, &"invalid_local_output")
	var building: Dictionary = ConstructionStateScript.building(farm, site_id)
	if building.is_empty():
		return _result(false, farm, &"work_site_missing")
	if str(building[&"state"]) != "complete":
		return _result(false, farm, &"work_site_incomplete")
	var stacks: Array[Dictionary] = []
	var found: bool = false
	for current: Dictionary in building[&"local_stacks"] as Array[Dictionary]:
		var stack: Dictionary = current.duplicate(true)
		if StringName(str(stack[&"item_id"])) == item_id:
			var next_count: int = int(stack[&"count"]) + amount
			if next_count > ItemCatalogScript.stack_limit(item_id):
				return _result(false, farm, &"local_output_full")
			stack[&"count"] = next_count
			found = true
		stacks.append(stack)
	if not found:
		if stacks.size() >= SectionsScript.MAX_LOCAL_STACKS:
			return _result(false, farm, &"local_output_full")
		if amount > ItemCatalogScript.stack_limit(item_id):
			return _result(false, farm, &"local_output_full")
		stacks.append({&"item_id": str(item_id), &"count": amount})
	stacks.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"item_id"]) < str(b[&"item_id"])
	)
	building[&"local_stacks"] = stacks
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
		return _result(false, farm, &"invalid_local_output")
	homestead[&"construction"] = construction
	candidate[&"homestead"] = homestead
	var normalized: Dictionary = FarmSchemaScript.validate(candidate)
	return _result(
		not normalized.is_empty(), normalized if not normalized.is_empty() else farm,
		&"" if not normalized.is_empty() else &"invalid_local_output"
	)


static func _result(ok: bool, candidate: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": candidate.duplicate(true), &"reason": reason}
