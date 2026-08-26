extends RefCounted

const BlueprintCatalogScript: GDScript = preload(
	"res://scripts/construction_blueprint_catalog.gd"
)
const ConstructionStateScript: GDScript = preload(
	"res://scripts/construction_state_service.gd"
)
const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const InventoryScript: GDScript = preload("res://scripts/inventory_service.gd")
const LocalStorageScript: GDScript = preload(
	"res://scripts/building_local_storage_service.gd"
)
const ReceiptLedgerScript: GDScript = preload("res://scripts/exact_once_receipt_ledger.gd")
const RecipeCatalogScript: GDScript = preload("res://scripts/recipe_catalog.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")
const WorkforceScript: GDScript = preload("res://scripts/workforce_service.gd")

const DAY_PREFIX: String = "production:day."
const MAX_RETAINED_DAY_RECEIPTS: int = 16


static func set_policy(
	farm: Dictionary,
	site_id: StringName,
	recipe_id: StringName,
	enabled: bool,
	priority: int,
	target_count: int,
) -> Dictionary:
	if priority < 0 or priority > 9 or target_count < 0:
		return _result(false, farm, &"invalid_recipe_policy")
	var building: Dictionary = ConstructionStateScript.building(farm, site_id)
	var recipe: Dictionary = RecipeCatalogScript.definition(recipe_id)
	if (
		building.is_empty()
		or str(building[&"state"]) != "complete"
		or StringName(str(building[&"blueprint_id"])) != BlueprintCatalogScript.FABRICATOR_ANNEX
		or recipe.is_empty()
	):
		return _result(false, farm, &"production_site_or_recipe_missing")
	var policies: Array[Dictionary] = []
	var found: bool = false
	for current: Dictionary in building[&"recipe_policies"] as Array[Dictionary]:
		if str(current[&"recipe_id"]) == str(recipe_id):
			found = true
			policies.append(_policy(recipe_id, enabled, priority, target_count))
		else:
			policies.append(current.duplicate(true))
	if not found:
		if policies.size() >= SectionsScript.MAX_RECIPES_PER_BUILDING:
			return _result(false, farm, &"recipe_policy_cap_reached")
		policies.append(_policy(recipe_id, enabled, priority, target_count))
	building[&"recipe_policies"] = policies
	return _write_building(farm, building)


static func advance(farm: Dictionary, absolute_day: int) -> Dictionary:
	var payload: Dictionary = {&"absolute_day": absolute_day}
	var token: String = "%s%09d" % [DAY_PREFIX, absolute_day]
	var replay: Dictionary = ReceiptLedgerScript.lookup(farm[&"receipts"], token, payload)
	if replay[&"status"] == &"duplicate":
		return {
			&"ok": true, &"candidate": farm.duplicate(true),
			&"summary": replay[&"result"], &"reason": &"",
		}
	if replay[&"status"] != &"missing":
		return _result(false, farm, replay[&"status"] as StringName)
	var candidate: Dictionary = farm.duplicate(true)
	var completed: int = 0
	var started: int = 0
	var idle: int = 0
	for building: Dictionary in _fabricators(candidate):
		var resolved: Dictionary = _complete_orders(candidate, building, absolute_day)
		candidate = resolved[&"candidate"] as Dictionary
		completed += int(resolved[&"completed"])
		if bool(resolved[&"blocked"]):
			idle += 1
			continue
		building = ConstructionStateScript.building(
			candidate, StringName(str(building[&"instance_id"]))
		)
		var start: Dictionary = _start_order(candidate, building, absolute_day)
		candidate = start[&"candidate"] as Dictionary
		if bool(start[&"started"]):
			started += 1
		else:
			idle += 1
	candidate = _prepare_receipts(candidate)
	if candidate.is_empty():
		return _result(false, farm, &"receipt_capacity_reached")
	var summary: Dictionary = {&"started": started, &"completed": completed, &"idle": idle}
	var recorded: Dictionary = ReceiptLedgerScript.record(
		candidate[&"receipts"], token, payload, summary
	)
	if not bool(recorded[&"ok"]):
		return _result(false, farm, recorded[&"status"] as StringName)
	candidate[&"receipts"] = recorded[&"candidate"]
	var normalized: Dictionary = FarmSchemaScript.validate(candidate)
	return {
		&"ok": not normalized.is_empty(),
		&"candidate": normalized if not normalized.is_empty() else farm,
		&"summary": summary,
		&"reason": &"" if not normalized.is_empty() else &"invalid_production_candidate",
	}


static func _complete_orders(
	farm: Dictionary, building: Dictionary, absolute_day: int
) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var retained: Array[Dictionary] = []
	var completed: int = 0
	var blocked: bool = false
	var site_id: StringName = StringName(str(building[&"instance_id"]))
	for order: Dictionary in building[&"production_orders"] as Array[Dictionary]:
		if int(order[&"complete_day"]) > absolute_day:
			retained.append(order.duplicate(true))
			continue
		var recipe: Dictionary = RecipeCatalogScript.definition(
			StringName(str(order[&"recipe_id"]))
		)
		var output_candidate: Dictionary = candidate.duplicate(true)
		var output_ok: bool = true
		for output: Dictionary in _all_outputs(recipe):
			var credited: Dictionary = LocalStorageScript.credit(
				output_candidate, site_id, StringName(str(output[&"item_id"])), int(output[&"count"])
			)
			if not bool(credited[&"ok"]):
				output_ok = false
				break
			output_candidate = credited[&"candidate"] as Dictionary
		if output_ok:
			candidate = output_candidate
			completed += 1
		else:
			retained.append(order.duplicate(true))
			blocked = true
	building = ConstructionStateScript.building(candidate, site_id)
	building[&"production_orders"] = retained
	var written: Dictionary = _write_building(candidate, building)
	return {
		&"candidate": written[&"candidate"] if written[&"ok"] else farm,
		&"completed": completed,
		&"blocked": blocked or not bool(written[&"ok"]),
	}


static func _start_order(
	farm: Dictionary, building: Dictionary, absolute_day: int
) -> Dictionary:
	if not _has_production_worker(farm, StringName(str(building[&"instance_id"]))):
		return {&"candidate": farm.duplicate(true), &"started": false}
	if not (building[&"production_orders"] as Array).is_empty():
		return {&"candidate": farm.duplicate(true), &"started": false}
	var policies: Array[Dictionary] = (
		building[&"recipe_policies"] as Array[Dictionary]
	).duplicate(true)
	policies.sort_custom(_policy_precedes)
	for policy: Dictionary in policies:
		if not bool(policy[&"enabled"]):
			continue
		var recipe_id: StringName = StringName(str(policy[&"recipe_id"]))
		var recipe: Dictionary = RecipeCatalogScript.definition(recipe_id)
		if _target_reached(farm, recipe, int(policy[&"target_count"])):
			continue
		var choices: Array[Dictionary] = _ingredient_choices(farm, building, recipe)
		if choices.is_empty():
			continue
		var candidate: Dictionary = farm.duplicate(true)
		var site_id: StringName = StringName(str(building[&"instance_id"]))
		for choice: Dictionary in choices:
			var removed: Dictionary = LocalStorageScript.remove_input(
				candidate, site_id, StringName(str(choice[&"item_id"])), int(choice[&"count"])
			)
			if not bool(removed[&"ok"]):
				return {&"candidate": farm.duplicate(true), &"started": false}
			candidate = removed[&"candidate"] as Dictionary
		building = ConstructionStateScript.building(candidate, site_id)
		var order_id: String = "order.%s.%09d" % [str(recipe_id).sha256_text().left(16), absolute_day]
		var token: String = "production:%s:%09d" % [str(site_id).sha256_text().left(16), absolute_day]
		building[&"production_orders"] = [
			{
				&"order_id": order_id, &"recipe_id": str(recipe_id),
				&"start_day": absolute_day,
				&"complete_day": absolute_day + int(recipe[&"duration_days"]),
				&"operation_token": token,
			}
		]
		var written: Dictionary = _write_building(candidate, building)
		return {
			&"candidate": written[&"candidate"] if written[&"ok"] else farm,
			&"started": bool(written[&"ok"]),
		}
	return {&"candidate": farm.duplicate(true), &"started": false}


static func _ingredient_choices(
	farm: Dictionary, building: Dictionary, recipe: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var site_id: StringName = StringName(str(building[&"instance_id"]))
	for group: Dictionary in recipe[&"ingredient_groups"] as Array[Dictionary]:
		var options: Array[Dictionary] = (
			group[&"options"] as Array[Dictionary]
		).duplicate(true)
		options.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return str(a[&"item_id"]) < str(b[&"item_id"])
		)
		var selected: Dictionary = {}
		for option: Dictionary in options:
			if LocalStorageScript.input_count(
				farm, site_id, StringName(str(option[&"item_id"]))
			) >= int(option[&"count"]):
				selected = option.duplicate(true)
				break
		if selected.is_empty():
			return []
		result.append(selected)
	return result


static func _target_reached(
	farm: Dictionary, recipe: Dictionary, target_count: int
) -> bool:
	if target_count <= 0:
		return false
	var primary: Dictionary = (recipe[&"outputs"] as Array[Dictionary])[0]
	var item_id: StringName = StringName(str(primary[&"item_id"]))
	var total: int = InventoryScript.count_all(farm, item_id)
	for building: Dictionary in _all_complete_buildings(farm):
		total += LocalStorageScript.count(
			farm, StringName(str(building[&"instance_id"])), item_id
		)
		for order: Dictionary in building[&"production_orders"] as Array[Dictionary]:
			var pending_recipe: Dictionary = RecipeCatalogScript.definition(
				StringName(str(order[&"recipe_id"]))
			)
			var pending_output: Dictionary = (
				pending_recipe[&"outputs"] as Array[Dictionary]
			)[0]
			if StringName(str(pending_output[&"item_id"])) == item_id:
				total += int(pending_output[&"count"])
	return total >= target_count


static func _has_production_worker(farm: Dictionary, site_id: StringName) -> bool:
	var workforce: Dictionary = (farm[&"homestead"] as Dictionary)[&"workforce"]
	for assignment: Dictionary in workforce[&"work_assignments"] as Array[Dictionary]:
		if str(assignment[&"site_id"]) != str(site_id):
			continue
		var slot: int = int(assignment[&"slot"])
		var slots: Array[StringName] = BlueprintCatalogScript.work_slot_types(
			BlueprintCatalogScript.FABRICATOR_ANNEX
		)
		if slot < 0 or slot >= slots.size() or slots[slot] != &"fabrication":
			continue
		var settler_id: StringName = StringName(str(assignment[&"settler_id"]))
		if bool(WorkforceScript.availability(farm, settler_id)[&"available"]):
			return true
	return false


static func _all_outputs(recipe: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for output: Dictionary in recipe[&"outputs"] as Array[Dictionary]:
		result.append(output.duplicate(true))
	for byproduct: Dictionary in recipe[&"byproducts"] as Array[Dictionary]:
		result.append(byproduct.duplicate(true))
	return result


static func _policy_snapshot(farm: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building: Dictionary in _fabricators(farm):
		result.append(
			{
				&"site_id": building[&"instance_id"],
				&"policies": (building[&"recipe_policies"] as Array).duplicate(true),
				&"orders": (building[&"production_orders"] as Array).duplicate(true),
			}
		)
	return result


static func _prepare_receipts(farm: Dictionary) -> Dictionary:
	var ledger: Dictionary = ReceiptLedgerScript.retain_prefix(
		farm[&"receipts"], DAY_PREFIX, MAX_RETAINED_DAY_RECEIPTS - 1
	)
	if ledger.is_empty() or (ledger[&"entries"] as Array).size() >= ReceiptLedgerScript.MAX_RECEIPTS:
		return {}
	var candidate: Dictionary = farm.duplicate(true)
	candidate[&"receipts"] = ledger
	return candidate


static func _write_building(farm: Dictionary, building: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	var construction: Dictionary = homestead[&"construction"] as Dictionary
	var buildings: Array[Dictionary] = []
	var found: bool = false
	for current: Dictionary in construction[&"buildings"] as Array[Dictionary]:
		if str(current[&"instance_id"]) == str(building[&"instance_id"]):
			buildings.append(building.duplicate(true))
			found = true
		else:
			buildings.append(current.duplicate(true))
	if not found:
		return _result(false, farm, &"production_site_missing")
	construction[&"buildings"] = buildings
	homestead[&"construction"] = SectionsScript.validate_construction(construction)
	if (homestead[&"construction"] as Dictionary).is_empty():
		return _result(false, farm, &"invalid_production_candidate")
	candidate[&"homestead"] = homestead
	var normalized: Dictionary = FarmSchemaScript.validate(candidate)
	return _result(
		not normalized.is_empty(), normalized if not normalized.is_empty() else farm,
		&"" if not normalized.is_empty() else &"invalid_production_candidate"
	)


static func _policy(
	recipe_id: StringName, enabled: bool, priority: int, target_count: int
) -> Dictionary:
	return {
		&"recipe_id": str(recipe_id), &"enabled": enabled,
		&"priority": priority, &"target_count": target_count,
	}


static func _policy_precedes(first: Dictionary, second: Dictionary) -> bool:
	return (
		int(first[&"priority"]) > int(second[&"priority"])
		or (
			int(first[&"priority"]) == int(second[&"priority"])
			and str(first[&"recipe_id"]) < str(second[&"recipe_id"])
		)
	)


static func _fabricators(farm: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building: Dictionary in _all_complete_buildings(farm):
		if StringName(str(building[&"blueprint_id"])) == BlueprintCatalogScript.FABRICATOR_ANNEX:
			result.append(building)
	return result


static func _all_complete_buildings(farm: Dictionary) -> Array[Dictionary]:
	var construction: Dictionary = (farm[&"homestead"] as Dictionary)[&"construction"]
	var result: Array[Dictionary] = []
	for building: Dictionary in construction[&"buildings"] as Array[Dictionary]:
		if str(building[&"state"]) == "complete":
			result.append(building.duplicate(true))
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"instance_id"]) < str(b[&"instance_id"])
	)
	return result


static func _result(ok: bool, candidate: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": candidate.duplicate(true), &"reason": reason}
