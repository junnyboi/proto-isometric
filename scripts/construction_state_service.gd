extends RefCounted

const CatalogScript: GDScript = preload("res://scripts/construction_blueprint_catalog.gd")
const InventoryScript: GDScript = preload("res://scripts/inventory_service.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")


static func building(farm: Dictionary, instance_id: StringName) -> Dictionary:
	for record: Dictionary in _buildings(farm):
		if str(record[&"instance_id"]) == str(instance_id):
			return record.duplicate(true)
	return {}


static func building_at(farm: Dictionary, cell: Vector2i) -> Dictionary:
	for record: Dictionary in _buildings(farm):
		for encoded: Array in record[&"footprint"] as Array[Array]:
			if Vector2i(int(encoded[0]), int(encoded[1])) == cell:
				return record.duplicate(true)
	return {}


static func next_instance_id(farm: Dictionary, blueprint_id: StringName) -> StringName:
	var suffix: String = String(blueprint_id).trim_prefix("blueprint.")
	var highest: int = 0
	var prefix: String = "building.%s." % suffix
	for record: Dictionary in _buildings(farm):
		var current: String = str(record[&"instance_id"])
		if current.begins_with(prefix):
			highest = maxi(highest, int(current.trim_prefix(prefix)))
	return StringName("%s%d" % [prefix, highest + 1])


static func can_afford(farm: Dictionary, materials: Dictionary) -> bool:
	if materials.is_empty():
		return false
	for raw_id: Variant in materials:
		var item_id: StringName = StringName(str(raw_id))
		if InventoryScript.count_all(farm, item_id) < int(materials[raw_id]):
			return false
	return true


static func place(
	farm: Dictionary,
	blueprint_id: StringName,
	instance_id: StringName,
	anchor: Vector2i,
	orientation: int,
) -> Dictionary:
	var blueprint: Dictionary = CatalogScript.definition(blueprint_id)
	if blueprint.is_empty() or building(farm, instance_id) != {}:
		return _result(false, farm, &"invalid_blueprint_or_instance")
	if _buildings(farm).size() >= SectionsScript.MAX_BUILDINGS:
		return _result(false, farm, &"building_cap_reached")
	var bill: Dictionary = CatalogScript.bill(blueprint_id)
	var consumed: Dictionary = _consume(farm, bill)
	if consumed.is_empty():
		return _result(false, farm, &"construction_materials_missing")
	var candidate: Dictionary = consumed.duplicate(true)
	var record: Dictionary = {
		&"instance_id": String(instance_id),
		&"blueprint_id": String(blueprint_id),
		&"anchor": [anchor.x, anchor.y],
		&"orientation": orientation,
		&"level": 1,
		&"state": "constructing",
		&"footprint": CatalogScript.encoded_footprint(blueprint_id, anchor, orientation),
		&"local_stacks": [],
		&"recipe_policies": [],
	}
	if not _replace_building(candidate, record):
		return _result(false, farm, &"construction_record_invalid")
	return _result(true, candidate, &"")


static func complete(farm: Dictionary, instance_id: StringName) -> Dictionary:
	var record: Dictionary = building(farm, instance_id)
	if record.is_empty() or record[&"state"] != "constructing":
		return _result(false, farm, &"building_not_constructing")
	record[&"state"] = "complete"
	var candidate: Dictionary = farm.duplicate(true)
	if not _replace_building(candidate, record):
		return _result(false, farm, &"construction_record_invalid")
	return _result(true, candidate, &"")


static func relocate(
	farm: Dictionary, instance_id: StringName, anchor: Vector2i, orientation: int
) -> Dictionary:
	var record: Dictionary = building(farm, instance_id)
	if record.is_empty() or orientation < 0 or orientation > 3:
		return _result(false, farm, &"building_missing")
	var blueprint_id: StringName = StringName(str(record[&"blueprint_id"]))
	if (
		record[&"state"] != "complete"
		or not CatalogScript.is_movable(blueprint_id)
		or has_dependencies(farm, instance_id)
	):
		return _result(false, farm, &"building_not_movable")
	record[&"anchor"] = [anchor.x, anchor.y]
	record[&"orientation"] = orientation
	record[&"footprint"] = CatalogScript.encoded_footprint(blueprint_id, anchor, orientation)
	var candidate: Dictionary = farm.duplicate(true)
	if not _replace_building(candidate, record):
		return _result(false, farm, &"construction_overlap")
	return _result(true, candidate, &"")


static func upgrade(farm: Dictionary, instance_id: StringName) -> Dictionary:
	var record: Dictionary = building(farm, instance_id)
	if record.is_empty() or record[&"state"] != "complete":
		return _result(false, farm, &"building_not_complete")
	var level: int = int(record[&"level"])
	if level >= CatalogScript.MAX_LEVEL:
		return _result(false, farm, &"building_max_level")
	var blueprint_id: StringName = StringName(str(record[&"blueprint_id"]))
	var consumed: Dictionary = _consume(farm, CatalogScript.bill(blueprint_id, level + 1))
	if consumed.is_empty():
		return _result(false, farm, &"upgrade_materials_missing")
	record[&"level"] = level + 1
	if not _replace_building(consumed, record):
		return _result(false, farm, &"construction_record_invalid")
	return _result(true, consumed, &"")


static func demolish(farm: Dictionary, instance_id: StringName) -> Dictionary:
	var record: Dictionary = building(farm, instance_id)
	if record.is_empty():
		return _result(false, farm, &"building_missing")
	if has_dependencies(farm, instance_id):
		return _result(false, farm, &"building_has_assignments")
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	var construction: Dictionary = homestead[&"construction"] as Dictionary
	var retained: Array[Dictionary] = []
	for current: Dictionary in construction[&"buildings"] as Array[Dictionary]:
		if str(current[&"instance_id"]) != str(instance_id):
			retained.append(current.duplicate(true))
	construction[&"buildings"] = retained
	homestead[&"construction"] = construction
	var workforce: Dictionary = homestead.get(&"workforce", {}) as Dictionary
	var reports: Array[Dictionary] = []
	for report: Dictionary in workforce.get(&"shift_reports", []) as Array[Dictionary]:
		if str(report[&"site_id"]) != str(instance_id):
			reports.append(report.duplicate(true))
	workforce[&"shift_reports"] = reports
	homestead[&"workforce"] = SectionsScript.validate_workforce(workforce)
	candidate[&"homestead"] = homestead
	var blueprint_id: StringName = StringName(str(record[&"blueprint_id"]))
	var refund: Dictionary = _refund_bill(CatalogScript.bill(blueprint_id))
	for raw_id: Variant in refund:
		var credited: Dictionary = InventoryScript.credit_with_overflow(
			candidate, StringName(str(raw_id)), int(refund[raw_id])
		)
		if not bool(credited[&"ok"]):
			return _result(false, farm, &"refund_storage_full")
		candidate = credited[&"candidate"] as Dictionary
	return _result(true, candidate, &"")


static func _replace_building(farm: Dictionary, record: Dictionary) -> bool:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var construction: Dictionary = homestead.get(&"construction", {}) as Dictionary
	var records: Array[Dictionary] = []
	var replaced: bool = false
	for current: Dictionary in construction.get(&"buildings", []) as Array[Dictionary]:
		if str(current[&"instance_id"]) == str(record[&"instance_id"]):
			records.append(record.duplicate(true))
			replaced = true
		else:
			records.append(current.duplicate(true))
	if not replaced:
		records.append(record.duplicate(true))
	construction[&"buildings"] = records
	construction = SectionsScript.validate_construction(construction)
	if construction.is_empty():
		return false
	homestead[&"construction"] = construction
	farm[&"homestead"] = homestead
	return true


static func _consume(farm: Dictionary, materials: Dictionary) -> Dictionary:
	if not can_afford(farm, materials):
		return {}
	var candidate: Dictionary = farm.duplicate(true)
	var item_ids: Array[StringName] = []
	for raw_id: Variant in materials:
		item_ids.append(StringName(str(raw_id)))
	item_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	for item_id: StringName in item_ids:
		var removed: Dictionary = InventoryScript.remove_across(
			candidate, item_id, int(materials[item_id])
		)
		if not bool(removed[&"ok"]):
			return {}
		candidate = removed[&"candidate"] as Dictionary
	return candidate


static func has_dependencies(farm: Dictionary, instance_id: StringName) -> bool:
	var site: Dictionary = building(farm, instance_id)
	if not site.is_empty() and not (site[&"local_stacks"] as Array).is_empty():
		return true
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var workforce: Dictionary = homestead.get(&"workforce", {}) as Dictionary
	var bed_prefix: String = "bed.%s." % str(instance_id)
	for housing: Dictionary in workforce.get(&"housing_assignments", []) as Array[Dictionary]:
		if str(housing[&"bed_id"]).begins_with(bed_prefix):
			return true
	for assignment: Dictionary in workforce.get(&"work_assignments", []) as Array[Dictionary]:
		if str(assignment[&"site_id"]) == str(instance_id):
			return true
	for delta: Dictionary in farm.get(&"gathering", {}).get(
		&"resource_deltas", []
	) as Array[Dictionary]:
		if str(delta[&"reserved_by"]) == str(instance_id):
			return true
	for job: Dictionary in farm.get(&"logistics", {}).get(&"jobs", []) as Array[Dictionary]:
		if str(job[&"source_id"]) == str(instance_id):
			return true
		if str(job[&"destination_id"]) == str(instance_id):
			return true
	return false


static func _refund_bill(materials: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_id: Variant in materials:
		var amount: int = int(materials[raw_id])
		result[StringName(str(raw_id))] = maxi(amount / 2, 1)
	return result


static func _buildings(farm: Dictionary) -> Array[Dictionary]:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var construction: Dictionary = homestead.get(&"construction", {}) as Dictionary
	return construction.get(&"buildings", []) as Array[Dictionary]


static func _result(ok: bool, candidate: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": candidate.duplicate(true), &"reason": reason}
