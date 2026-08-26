extends RefCounted

const BlueprintCatalogScript: GDScript = preload(
	"res://scripts/construction_blueprint_catalog.gd"
)
const ConstructionStateScript: GDScript = preload(
	"res://scripts/construction_state_service.gd"
)
const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const LocalStorageScript: GDScript = preload(
	"res://scripts/building_local_storage_service.gd"
)
const ReceiptLedgerScript: GDScript = preload("res://scripts/exact_once_receipt_ledger.gd")
const RecipeCatalogScript: GDScript = preload("res://scripts/recipe_catalog.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")
const WorkforceScript: GDScript = preload("res://scripts/workforce_service.gd")

const DAY_PREFIX: String = "transfer:day."
const FORCE_PREFIX: String = "transfer:force."
const MAX_RETAINED_DAY_RECEIPTS: int = 16
const MAX_RETAINED_FORCE_RECEIPTS: int = 4
const SELF_HAUL_CAPACITY: int = 2


static func reserve_floor(farm: Dictionary, item_id: StringName) -> int:
	for rule: Dictionary in farm[&"logistics"][&"reserve_rules"] as Array[Dictionary]:
		if StringName(str(rule[&"item_id"])) == item_id:
			return int(rule[&"floor"])
	return 0


static func set_reserve_floor(
	farm: Dictionary, item_id: StringName, floor: int
) -> Dictionary:
	if floor < 0:
		return _result(false, farm, &"invalid_reserve_floor")
	var logistics: Dictionary = farm[&"logistics"].duplicate(true)
	var rules: Array[Dictionary] = []
	var found: bool = false
	for current: Dictionary in logistics[&"reserve_rules"] as Array[Dictionary]:
		if StringName(str(current[&"item_id"])) == item_id:
			found = true
			if floor > 0:
				rules.append({&"item_id": str(item_id), &"floor": floor})
		else:
			rules.append(current.duplicate(true))
	if not found and floor > 0:
		rules.append({&"item_id": str(item_id), &"floor": floor})
	logistics[&"reserve_rules"] = rules
	return _write_logistics(farm, logistics)


static func generate_jobs(farm: Dictionary) -> Dictionary:
	var warehouses: Array[Dictionary] = _buildings_of(farm, BlueprintCatalogScript.FIELD_WAREHOUSE)
	var generated: Dictionary = {}
	if not warehouses.is_empty():
		_generate_output_jobs(farm, warehouses, generated)
		_generate_supply_jobs(farm, warehouses, generated)
	var existing_ages: Dictionary = {}
	for job: Dictionary in farm[&"logistics"][&"jobs"] as Array[Dictionary]:
		existing_ages[_job_key(job)] = mini(int(job[&"age"]) + 1, SectionsScript.MAX_NUMBER)
	var jobs: Array[Dictionary] = []
	for key: String in generated:
		var job: Dictionary = generated[key] as Dictionary
		job[&"age"] = int(existing_ages.get(key, 0))
		job[&"job_id"] = _job_id(job)
		jobs.append(job)
	jobs.sort_custom(_job_precedes)
	if jobs.size() > SectionsScript.MAX_LOGISTICS_JOBS:
		jobs.resize(SectionsScript.MAX_LOGISTICS_JOBS)
	var logistics: Dictionary = farm[&"logistics"].duplicate(true)
	logistics[&"jobs"] = jobs
	return _write_logistics(farm, logistics)


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
	var generated: Dictionary = generate_jobs(farm)
	if not bool(generated[&"ok"]):
		return generated
	var candidate: Dictionary = generated[&"candidate"] as Dictionary
	var haul: Dictionary = _process_jobs(candidate)
	if not bool(haul[&"ok"]):
		return haul
	candidate = haul[&"candidate"] as Dictionary
	candidate = _prepare_receipts(candidate)
	if candidate.is_empty():
		return _result(false, farm, &"receipt_capacity_reached")
	var recorded: Dictionary = ReceiptLedgerScript.record(
		candidate[&"receipts"], token, payload, haul[&"summary"]
	)
	if not bool(recorded[&"ok"]):
		return _result(false, farm, recorded[&"status"] as StringName)
	candidate[&"receipts"] = recorded[&"candidate"]
	var normalized: Dictionary = FarmSchemaScript.validate(candidate)
	if normalized.is_empty():
		return _result(false, farm, &"invalid_logistics_candidate")
	return {
		&"ok": true, &"candidate": normalized,
		&"summary": haul[&"summary"], &"reason": &"",
	}


static func force_delivery(
	farm: Dictionary, job_id: StringName, operation_id: String, expected_revision: int = -1
) -> Dictionary:
	var payload: Dictionary = {&"job_id": str(job_id)}
	var token: String = "%s%s" % [FORCE_PREFIX, operation_id]
	var replay: Dictionary = ReceiptLedgerScript.lookup(farm[&"receipts"], token, payload)
	if replay[&"status"] == &"duplicate":
		return {
			&"ok": true, &"candidate": farm.duplicate(true),
			&"summary": replay[&"result"], &"reason": &"", &"replayed": true,
		}
	if replay[&"status"] != &"missing":
		return _result(false, farm, replay[&"status"] as StringName)
	var revision: int = int((farm[&"revisions"] as Dictionary)[&"result_revision"])
	if expected_revision >= 0 and expected_revision != revision:
		return _result(false, farm, &"stale_logistics_revision")
	var generated: Dictionary = generate_jobs(farm)
	if not bool(generated[&"ok"]):
		return generated
	var candidate: Dictionary = generated[&"candidate"] as Dictionary
	var job: Dictionary = _job_by_id(candidate, job_id)
	if job.is_empty():
		return _result(false, farm, &"transfer_job_missing")
	var moved: Dictionary = _move_job(candidate, job, int(job[&"count"]), true)
	if not bool(moved[&"ok"]):
		return moved
	candidate = generate_jobs(moved[&"candidate"])[&"candidate"]
	var summary: Dictionary = {&"job_id": str(job_id), &"moved": int(moved[&"moved"])}
	var compacted: Dictionary = ReceiptLedgerScript.retain_prefix(
		candidate[&"receipts"], FORCE_PREFIX, MAX_RETAINED_FORCE_RECEIPTS - 1
	)
	if compacted.is_empty():
		return _result(false, farm, &"receipt_capacity_reached")
	candidate[&"receipts"] = compacted
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
		&"replayed": false,
		&"reason": &"" if not normalized.is_empty() else &"invalid_logistics_candidate",
	}


static func _process_jobs(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var jobs: Array[Dictionary] = candidate[&"logistics"][&"jobs"] as Array[Dictionary]
	var workers: Array[Dictionary] = _haulers(candidate)
	var capacities: Array[int] = []
	for worker: Dictionary in workers:
		capacities.append(4 + int(worker[&"warehouse_level"]) * 2)
	capacities.append(SELF_HAUL_CAPACITY)
	var moved_total: int = 0
	var completed: int = 0
	var used_self_haul: bool = false
	for job: Dictionary in jobs:
		var remaining: int = int(job[&"count"])
		for index: int in capacities.size():
			if capacities[index] <= 0 or remaining <= 0:
				continue
			var pending: Dictionary = job.duplicate(true)
			pending[&"count"] = remaining
			var moved: Dictionary = _move_job(candidate, pending, capacities[index], false)
			if not bool(moved[&"ok"]):
				break
			var moved_count: int = int(moved[&"moved"])
			if moved_count <= 0:
				break
			candidate = moved[&"candidate"] as Dictionary
			capacities[index] -= moved_count
			remaining -= moved_count
			moved_total += moved_count
			if index == capacities.size() - 1:
				used_self_haul = true
		if remaining <= 0:
			completed += 1
	var refreshed: Dictionary = generate_jobs(candidate)
	if not bool(refreshed[&"ok"]):
		return refreshed
	return {
		&"ok": true,
		&"candidate": refreshed[&"candidate"],
		&"summary": {
			&"moved": moved_total,
			&"completed": completed,
			&"workers": workers.size(),
			&"self_haul": used_self_haul,
		},
		&"reason": &"",
	}


static func _move_job(
	farm: Dictionary, job: Dictionary, capacity: int, forced: bool
) -> Dictionary:
	var source_id: StringName = StringName(str(job[&"source_id"]))
	var destination_id: StringName = StringName(str(job[&"destination_id"]))
	var item_id: StringName = StringName(str(job[&"item_id"]))
	var amount: int = mini(int(job[&"count"]), capacity)
	var source: Dictionary = ConstructionStateScript.building(farm, source_id)
	var destination: Dictionary = ConstructionStateScript.building(farm, destination_id)
	if source.is_empty() or destination.is_empty() or amount <= 0:
		return _result(false, farm, &"transfer_job_invalid")
	if StringName(str(source[&"blueprint_id"])) == BlueprintCatalogScript.FIELD_WAREHOUSE:
		var available: int = LocalStorageScript.count(farm, source_id, item_id)
		amount = mini(amount, maxi(available - reserve_floor(farm, item_id), 0))
		if amount <= 0:
			return _result(false, farm, &"reserve_floor_blocked")
	var destination_input: bool = (
		StringName(str(destination[&"blueprint_id"])) == BlueprintCatalogScript.FABRICATOR_ANNEX
	)
	var moved: Dictionary = LocalStorageScript.transfer(
		farm, source_id, destination_id, item_id, amount, destination_input
	)
	if not bool(moved[&"ok"]):
		return moved
	var candidate: Dictionary = moved[&"candidate"] as Dictionary
	if (ConstructionStateScript.building(candidate, source_id)[&"local_stacks"] as Array).is_empty():
		candidate = _clear_site_reservations(candidate, str(source_id))
	return {
		&"ok": true, &"candidate": candidate, &"moved": amount,
		&"forced": forced, &"reason": &"",
	}


static func _generate_output_jobs(
	farm: Dictionary, warehouses: Array[Dictionary], generated: Dictionary
) -> void:
	for building: Dictionary in _all_complete_buildings(farm):
		var blueprint_id: StringName = StringName(str(building[&"blueprint_id"]))
		if blueprint_id in [BlueprintCatalogScript.FIELD_WAREHOUSE, BlueprintCatalogScript.SHELTER_POD]:
			continue
		var warehouse: Dictionary = _nearest(building, warehouses)
		for stack: Dictionary in building[&"local_stacks"] as Array[Dictionary]:
			_add_job(
				generated, str(building[&"instance_id"]), str(warehouse[&"instance_id"]),
				str(stack[&"item_id"]), int(stack[&"count"]), 5
			)


static func _generate_supply_jobs(
	farm: Dictionary, warehouses: Array[Dictionary], generated: Dictionary
) -> void:
	for building: Dictionary in _buildings_of(farm, BlueprintCatalogScript.FABRICATOR_ANNEX):
		for policy: Dictionary in building[&"recipe_policies"] as Array[Dictionary]:
			if not bool(policy[&"enabled"]):
				continue
			var recipe: Dictionary = RecipeCatalogScript.definition(
				StringName(str(policy[&"recipe_id"]))
			)
			for group: Dictionary in recipe[&"ingredient_groups"] as Array[Dictionary]:
				var choice: Dictionary = _available_option(farm, warehouses, group)
				if choice.is_empty():
					continue
				var item_id: StringName = StringName(str(choice[&"item_id"]))
				var missing: int = maxi(
					int(choice[&"count"])
					- LocalStorageScript.input_count(
						farm, StringName(str(building[&"instance_id"])), item_id
					),
					0,
				)
				if missing <= 0:
					continue
				var warehouse: Dictionary = _warehouse_with_item(farm, warehouses, item_id)
				if not warehouse.is_empty():
					_add_job(
						generated, str(warehouse[&"instance_id"]), str(building[&"instance_id"]),
						str(item_id), missing, int(policy[&"priority"])
					)


static func _add_job(
	generated: Dictionary,
	source_id: String,
	destination_id: String,
	item_id: String,
	count: int,
	priority: int,
) -> void:
	if count <= 0:
		return
	var key: String = "%s|%s|%s" % [source_id, destination_id, item_id]
	if generated.has(key):
		var existing: Dictionary = generated[key] as Dictionary
		existing[&"count"] = int(existing[&"count"]) + count
		existing[&"priority"] = maxi(int(existing[&"priority"]), priority)
		return
	generated[key] = {
		&"job_id": "", &"source_id": source_id, &"destination_id": destination_id,
		&"item_id": item_id, &"count": count, &"priority": clampi(priority, 0, 9), &"age": 0,
	}


static func _available_option(
	farm: Dictionary, warehouses: Array[Dictionary], group: Dictionary
) -> Dictionary:
	var options: Array[Dictionary] = (group[&"options"] as Array[Dictionary]).duplicate(true)
	options.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"item_id"]) < str(b[&"item_id"])
	)
	for option: Dictionary in options:
		var item_id: StringName = StringName(str(option[&"item_id"]))
		for warehouse: Dictionary in warehouses:
			var site_id: StringName = StringName(str(warehouse[&"instance_id"]))
			var available: int = (
				LocalStorageScript.count(farm, site_id, item_id)
				- reserve_floor(farm, item_id)
			)
			if available >= int(option[&"count"]):
				return option.duplicate(true)
	return {}


static func _warehouse_with_item(
	farm: Dictionary, warehouses: Array[Dictionary], item_id: StringName
) -> Dictionary:
	for warehouse: Dictionary in warehouses:
		var site_id: StringName = StringName(str(warehouse[&"instance_id"]))
		if LocalStorageScript.count(farm, site_id, item_id) > reserve_floor(farm, item_id):
			return warehouse.duplicate(true)
	return {}


static func _haulers(farm: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var workforce: Dictionary = (farm[&"homestead"] as Dictionary)[&"workforce"]
	for assignment: Dictionary in workforce[&"work_assignments"] as Array[Dictionary]:
		var building: Dictionary = ConstructionStateScript.building(
			farm, StringName(str(assignment[&"site_id"]))
		)
		if (
			building.is_empty()
			or StringName(str(building[&"blueprint_id"]))
			!= BlueprintCatalogScript.FIELD_WAREHOUSE
		):
			continue
		var slots: Array[StringName] = BlueprintCatalogScript.work_slot_types(
			BlueprintCatalogScript.FIELD_WAREHOUSE
		)
		var slot: int = int(assignment[&"slot"])
		if slot < 0 or slot >= slots.size() or slots[slot] not in [&"logistics", &"hauling"]:
			continue
		var settler_id: StringName = StringName(str(assignment[&"settler_id"]))
		if bool(WorkforceScript.availability(farm, settler_id)[&"available"]):
			result.append(
				{&"settler_id": str(settler_id), &"warehouse_level": int(building[&"level"])}
			)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"settler_id"]) < str(b[&"settler_id"])
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


static func _clear_site_reservations(farm: Dictionary, site_id: String) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var gathering: Dictionary = candidate[&"gathering"] as Dictionary
	var deltas: Array[Dictionary] = []
	for current: Dictionary in gathering[&"resource_deltas"] as Array[Dictionary]:
		var delta: Dictionary = current.duplicate(true)
		if str(delta[&"reserved_by"]) == site_id:
			delta[&"reserved_by"] = ""
		deltas.append(delta)
	gathering[&"resource_deltas"] = deltas
	candidate[&"gathering"] = SectionsScript.validate_gathering(gathering)
	return FarmSchemaScript.validate(candidate)


static func _write_logistics(farm: Dictionary, logistics: Dictionary) -> Dictionary:
	var normalized: Dictionary = SectionsScript.validate_logistics(logistics)
	if normalized.is_empty():
		return _result(false, farm, &"invalid_logistics_candidate")
	var candidate: Dictionary = farm.duplicate(true)
	candidate[&"logistics"] = normalized
	var farm_normalized: Dictionary = FarmSchemaScript.validate(candidate)
	return _result(
		not farm_normalized.is_empty(), farm_normalized if not farm_normalized.is_empty() else farm,
		&"" if not farm_normalized.is_empty() else &"invalid_logistics_candidate"
	)


static func _job_by_id(farm: Dictionary, job_id: StringName) -> Dictionary:
	for job: Dictionary in farm[&"logistics"][&"jobs"] as Array[Dictionary]:
		if str(job[&"job_id"]) == str(job_id):
			return job.duplicate(true)
	return {}


static func _job_id(job: Dictionary) -> String:
	return "job.%s" % ReceiptLedgerScript.fingerprint(
		{
			&"source_id": job[&"source_id"], &"destination_id": job[&"destination_id"],
			&"item_id": job[&"item_id"],
		}
	).left(24)


static func _job_key(job: Dictionary) -> String:
	return "%s|%s|%s" % [job[&"source_id"], job[&"destination_id"], job[&"item_id"]]


static func _job_precedes(first: Dictionary, second: Dictionary) -> bool:
	if int(first[&"priority"]) != int(second[&"priority"]):
		return int(first[&"priority"]) > int(second[&"priority"])
	if int(first[&"age"]) != int(second[&"age"]):
		return int(first[&"age"]) > int(second[&"age"])
	return _job_key(first) < _job_key(second)


static func _nearest(source: Dictionary, candidates: Array[Dictionary]) -> Dictionary:
	var origin: Array = source[&"anchor"] as Array
	var best: Dictionary = {}
	var best_distance: int = SectionsScript.MAX_NUMBER
	for candidate: Dictionary in candidates:
		var anchor: Array = candidate[&"anchor"] as Array
		var distance: int = (
			absi(int(anchor[0]) - int(origin[0]))
			+ absi(int(anchor[1]) - int(origin[1]))
		)
		var stable_first: bool = (
			str(candidate[&"instance_id"]) < str(best.get(&"instance_id", "~"))
		)
		if distance < best_distance or (distance == best_distance and stable_first):
			best = candidate.duplicate(true)
			best_distance = distance
	return best


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


static func _buildings_of(farm: Dictionary, blueprint_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building: Dictionary in _all_complete_buildings(farm):
		if StringName(str(building[&"blueprint_id"])) == blueprint_id:
			result.append(building)
	return result


static func _result(ok: bool, candidate: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": candidate.duplicate(true), &"reason": reason}
