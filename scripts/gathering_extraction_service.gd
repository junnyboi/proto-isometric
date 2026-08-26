extends RefCounted

const BlueprintCatalogScript: GDScript = preload(
	"res://scripts/construction_blueprint_catalog.gd"
)
const ConstructionStateScript: GDScript = preload(
	"res://scripts/construction_state_service.gd"
)
const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const GatheringStateScript: GDScript = preload("res://scripts/gathering_state_service.gd")
const LocalStorageScript: GDScript = preload(
	"res://scripts/building_local_storage_service.gd"
)
const ReceiptLedgerScript: GDScript = preload("res://scripts/exact_once_receipt_ledger.gd")
const ResourceCatalogScript: GDScript = preload("res://scripts/resource_deposit_catalog.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")
const WorkforceScript: GDScript = preload("res://scripts/workforce_service.gd")
const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")

const MAX_RETAINED_DAY_SHIFT_RECEIPTS: int = 64
const DAY_SHIFT_PREFIX: String = "shift:day."
const EXTRACTION_BLUEPRINTS: Array[StringName] = [
	BlueprintCatalogScript.SALVAGE_CAMP,
	BlueprintCatalogScript.SURVEY_DRILL,
	BlueprintCatalogScript.COPPICE_STATION,
]
const EXTRACTION_SLOT_TYPES: Array[StringName] = [&"salvage", &"mining", &"forestry"]


static func advance(
	farm: Dictionary,
	world_seed: int,
	absolute_day: int,
	source_resolver: Callable = Callable(),
	safety_resolver: Callable = Callable(),
) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var assignments: Array[Dictionary] = _extraction_assignments(source)
	var prepared: Dictionary = _prepare_receipts(source, assignments.size())
	if prepared.is_empty():
		return _result(false, source, [], &"shift_receipt_capacity_full")
	var candidate: Dictionary = prepared
	var results: Array[Dictionary] = []
	var staffed_sites: Dictionary = {}
	for assignment: Dictionary in assignments:
		staffed_sites[str(assignment[&"site_id"])] = true
		var resolved: Dictionary = _resolve_shift(
			candidate,
			assignment,
			world_seed,
			absolute_day,
			source_resolver,
			safety_resolver,
		)
		if not bool(resolved[&"ok"]):
			return _result(false, source, results, resolved[&"reason"] as StringName)
		candidate = resolved[&"candidate"] as Dictionary
		results.append((resolved[&"shift_result"] as Dictionary).duplicate(true))
	for building: Dictionary in _extraction_buildings(candidate):
		var site_id: String = str(building[&"instance_id"])
		if not staffed_sites.has(site_id):
			results.append(_idle_result(site_id, "", -1, -1, &"no_worker"))
	results.sort_custom(_result_precedes)
	candidate = _write_shift_reports(candidate, results, absolute_day)
	if candidate.is_empty():
		return _result(false, source, results, &"invalid_shift_reports")
	var normalized: Dictionary = FarmSchemaScript.validate(candidate)
	return _result(
		not normalized.is_empty(), normalized if not normalized.is_empty() else source,
		results, &"" if not normalized.is_empty() else &"invalid_shift_candidate"
	)


static func _resolve_shift(
	farm: Dictionary,
	assignment: Dictionary,
	world_seed: int,
	absolute_day: int,
	source_resolver: Callable,
	safety_resolver: Callable,
) -> Dictionary:
	var payload: Dictionary = {
		&"absolute_day": absolute_day,
		&"settler_id": str(assignment[&"settler_id"]),
		&"site_id": str(assignment[&"site_id"]),
		&"slot": int(assignment[&"slot"]),
		&"shift": int(assignment[&"shift"]),
	}
	var token: String = "%s%09d:%s" % [
		DAY_SHIFT_PREFIX, absolute_day, ReceiptLedgerScript.fingerprint(payload).left(24)
	]
	var ledger: Dictionary = farm[&"receipts"] as Dictionary
	var previous: Dictionary = ReceiptLedgerScript.lookup(ledger, token, payload)
	if previous[&"status"] == &"duplicate":
		return {
			&"ok": true, &"candidate": farm.duplicate(true),
			&"shift_result": (previous[&"result"] as Dictionary).duplicate(true), &"reason": &"",
		}
	if previous[&"status"] != &"missing":
		return {&"ok": false, &"candidate": farm.duplicate(true), &"reason": previous[&"status"]}
	var mutation: Dictionary = _mutate_shift(
		farm, assignment, world_seed, absolute_day, source_resolver, safety_resolver
	)
	if not bool(mutation[&"ok"]):
		return mutation
	var candidate: Dictionary = mutation[&"candidate"] as Dictionary
	var shift_result: Dictionary = mutation[&"shift_result"] as Dictionary
	var recorded: Dictionary = ReceiptLedgerScript.record(
		candidate[&"receipts"], token, payload, shift_result
	)
	if not bool(recorded[&"ok"]):
		return {
			&"ok": false, &"candidate": farm.duplicate(true),
			&"reason": recorded[&"status"] as StringName,
		}
	candidate[&"receipts"] = recorded[&"candidate"]
	return {
		&"ok": true, &"candidate": candidate,
		&"shift_result": shift_result, &"reason": &"",
	}


static func _mutate_shift(
	farm: Dictionary,
	assignment: Dictionary,
	world_seed: int,
	absolute_day: int,
	source_resolver: Callable,
	safety_resolver: Callable,
) -> Dictionary:
	var settler_id: StringName = StringName(str(assignment[&"settler_id"]))
	var site_id: StringName = StringName(str(assignment[&"site_id"]))
	var slot: int = int(assignment[&"slot"])
	var shift: int = int(assignment[&"shift"])
	var available: Dictionary = WorkforceScript.availability(farm, settler_id)
	if not bool(available[&"available"]):
		return _idle_mutation(farm, assignment, available[&"reason"] as StringName)
	var building: Dictionary = ConstructionStateScript.building(farm, site_id)
	if building.is_empty() or str(building[&"state"]) != "complete":
		return _idle_mutation(farm, assignment, &"work_site_incomplete")
	if not _site_is_safe(building, safety_resolver):
		return _idle_mutation(farm, assignment, &"site_unsafe")
	var blueprint_id: StringName = StringName(str(building[&"blueprint_id"]))
	var slot_types: Array[StringName] = BlueprintCatalogScript.work_slot_types(blueprint_id)
	if slot < 0 or slot >= slot_types.size() or slot_types[slot] not in EXTRACTION_SLOT_TYPES:
		return _idle_mutation(farm, assignment, &"slot_not_extraction")
	var selection: Dictionary = _select_source(
		farm, building, world_seed, absolute_day, source_resolver
	)
	var selected: Dictionary = selection[&"source"] as Dictionary
	if selected.is_empty():
		return _idle_mutation(farm, assignment, selection[&"reason"] as StringName)
	var item_id: StringName = selected[&"reward_item_id"] as StringName
	var amount: int = int(selected[&"reward_count"])
	var capacity: Dictionary = LocalStorageScript.can_credit(farm, site_id, item_id, amount)
	if not bool(capacity[&"ok"]):
		return _idle_mutation(farm, assignment, capacity[&"reason"] as StringName)
	var reserved: Dictionary = GatheringStateScript.set_reservation(
		farm, selected, absolute_day, str(site_id)
	)
	if not bool(reserved[&"ok"]):
		return _idle_mutation(farm, assignment, reserved[&"reason"] as StringName)
	var gathered: Dictionary = GatheringStateScript.gather(
		reserved[&"candidate"], selected, absolute_day, &"building", str(site_id)
	)
	if not bool(gathered[&"ok"]):
		return _idle_mutation(farm, assignment, gathered[&"reason"] as StringName)
	var credited: Dictionary = LocalStorageScript.credit(
		gathered[&"candidate"], site_id, item_id, amount
	)
	if not bool(credited[&"ok"]):
		return {&"ok": false, &"candidate": farm.duplicate(true), &"reason": credited[&"reason"]}
	var result: Dictionary = {
		&"site_id": str(site_id), &"settler_id": str(settler_id),
		&"slot": slot, &"shift": shift, &"status": "productive", &"reason": "",
		&"source_id": str(selected[&"source_id"]), &"item_id": str(item_id), &"count": amount,
	}
	return {&"ok": true, &"candidate": credited[&"candidate"], &"shift_result": result, &"reason": &""}


static func _select_source(
	farm: Dictionary,
	building: Dictionary,
	world_seed: int,
	absolute_day: int,
	source_resolver: Callable,
) -> Dictionary:
	var encoded: Array = building[&"anchor"] as Array
	var anchor: Vector2i = Vector2i(int(encoded[0]), int(encoded[1]))
	var level: int = int(building[&"level"])
	var blueprint_id: StringName = StringName(str(building[&"blueprint_id"]))
	var radius: int = ResourceCatalogScript.effective_range(level)
	var candidates: Array[Dictionary] = []
	var saw_reserved: bool = false
	var saw_exhausted: bool = false
	for y: int in range(anchor.y - radius, anchor.y + radius + 1):
		for x: int in range(anchor.x - radius, anchor.x + radius + 1):
			var cell: Vector2i = Vector2i(x, y)
			if maxi(absi(cell.x - anchor.x), absi(cell.y - anchor.y)) > radius:
				continue
			var source: Dictionary = (
				source_resolver.call(cell) as Dictionary
				if source_resolver.is_valid()
				else ResourceCatalogScript.project_at(cell, world_seed)
			)
			if source.is_empty() or not ResourceCatalogScript.compatible(
				source, blueprint_id, level
			):
				continue
			var state: Dictionary = GatheringStateScript.effective(farm, source, absolute_day)
			if int(state[&"remaining_charges"]) <= 0:
				saw_exhausted = true
				continue
			var owner: String = str(state[&"reserved_by"])
			if not owner.is_empty() and owner != str(building[&"instance_id"]):
				saw_reserved = true
				continue
			var candidate: Dictionary = source.duplicate(true)
			candidate[&"distance"] = maxi(absi(cell.x - anchor.x), absi(cell.y - anchor.y))
			candidates.append(candidate)
	candidates.sort_custom(_source_precedes)
	if candidates.is_empty():
		var reason: StringName = &"source_reserved" if saw_reserved else &"source_exhausted"
		if not saw_reserved and not saw_exhausted:
			reason = &"no_compatible_source"
		return {&"source": {}, &"reason": reason}
	var selected: Dictionary = candidates[0].duplicate(true)
	selected.erase(&"distance")
	return {&"source": selected, &"reason": &""}


static func _prepare_receipts(farm: Dictionary, pending: int) -> Dictionary:
	var ledger: Dictionary = ReceiptLedgerScript.validate(farm.get(&"receipts"))
	if ledger.is_empty() or pending < 0 or pending > ReceiptLedgerScript.MAX_RECEIPTS:
		return {}
	var day_shift_count: int = 0
	for entry: Dictionary in ledger[&"entries"] as Array[Dictionary]:
		if str(entry[&"token"]).begins_with(DAY_SHIFT_PREFIX):
			day_shift_count += 1
	var non_day_count: int = (ledger[&"entries"] as Array).size() - day_shift_count
	var room_limit: int = ReceiptLedgerScript.MAX_RECEIPTS - non_day_count - pending
	var retention: int = mini(MAX_RETAINED_DAY_SHIFT_RECEIPTS - pending, room_limit)
	if retention < 0:
		return {}
	var compacted: Dictionary = ReceiptLedgerScript.retain_prefix(
		ledger, DAY_SHIFT_PREFIX, retention
	)
	if compacted.is_empty():
		return {}
	var candidate: Dictionary = farm.duplicate(true)
	candidate[&"receipts"] = compacted
	return candidate


static func _write_shift_reports(
	farm: Dictionary, results: Array[Dictionary], absolute_day: int
) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate.get(&"homestead", {}) as Dictionary
	var workforce: Dictionary = homestead.get(&"workforce", {}) as Dictionary
	var extraction_sites: Dictionary = {}
	for building: Dictionary in _extraction_buildings(candidate):
		extraction_sites[str(building[&"instance_id"])] = true
	var reports: Array[Dictionary] = []
	for existing: Dictionary in workforce.get(&"shift_reports", []) as Array[Dictionary]:
		if not extraction_sites.has(str(existing[&"site_id"])):
			reports.append(existing.duplicate(true))
	for result: Dictionary in results:
		var site_id: String = str(result[&"site_id"])
		var slot: int = int(result[&"slot"])
		var shift: int = int(result[&"shift"])
		var suffix: String = "idle" if slot < 0 else "%02d.%d" % [slot, shift]
		reports.append(
			{
				&"report_id": "report.shift.%s.%s" % [site_id, suffix],
				&"site_id": site_id, &"settler_id": str(result[&"settler_id"]),
				&"slot": slot, &"shift": shift, &"absolute_day": absolute_day,
				&"status": str(result[&"status"]), &"reason": str(result[&"reason"]),
				&"source_id": str(result[&"source_id"]), &"item_id": str(result[&"item_id"]),
				&"count": int(result[&"count"]),
			}
		)
	workforce[&"shift_reports"] = reports
	workforce = SectionsScript.validate_workforce(workforce)
	if workforce.is_empty():
		return {}
	homestead[&"workforce"] = workforce
	candidate[&"homestead"] = homestead
	return candidate


static func _extraction_assignments(farm: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var workforce: Dictionary = homestead.get(&"workforce", {}) as Dictionary
	for assignment: Dictionary in workforce.get(&"work_assignments", []) as Array[Dictionary]:
		var building: Dictionary = ConstructionStateScript.building(
			farm, StringName(str(assignment[&"site_id"]))
		)
		if building.is_empty():
			continue
		if StringName(str(building[&"blueprint_id"])) in EXTRACTION_BLUEPRINTS:
			result.append(assignment.duplicate(true))
	result.sort_custom(_assignment_precedes)
	return result


static func _extraction_buildings(farm: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var construction: Dictionary = homestead.get(&"construction", {}) as Dictionary
	for building: Dictionary in construction.get(&"buildings", []) as Array[Dictionary]:
		if (
			str(building[&"state"]) == "complete"
			and StringName(str(building[&"blueprint_id"])) in EXTRACTION_BLUEPRINTS
		):
			result.append(building.duplicate(true))
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"instance_id"]) < str(b[&"instance_id"])
	)
	return result


static func _site_is_safe(building: Dictionary, safety_resolver: Callable) -> bool:
	var encoded: Array = building[&"anchor"] as Array
	var anchor: Vector2i = Vector2i(int(encoded[0]), int(encoded[1]))
	return (
		bool(safety_resolver.call(Vector2(anchor)))
		if safety_resolver.is_valid()
		else WoodlandClearingScript.is_buffer_safe(anchor)
	)


static func _idle_mutation(
	farm: Dictionary, assignment: Dictionary, reason: StringName
) -> Dictionary:
	return {
		&"ok": true, &"candidate": farm.duplicate(true),
		&"shift_result": _idle_result(
			str(assignment[&"site_id"]), str(assignment[&"settler_id"]),
			int(assignment[&"slot"]), int(assignment[&"shift"]), reason
		),
		&"reason": &"",
	}


static func _idle_result(
	site_id: String, settler_id: String, slot: int, shift: int, reason: StringName
) -> Dictionary:
	return {
		&"site_id": site_id, &"settler_id": settler_id, &"slot": slot, &"shift": shift,
		&"status": "idle", &"reason": str(reason), &"source_id": "", &"item_id": "",
		&"count": 0,
	}


static func _source_precedes(first: Dictionary, second: Dictionary) -> bool:
	return (
		int(first[&"distance"]) < int(second[&"distance"])
		or (
			int(first[&"distance"]) == int(second[&"distance"])
			and str(first[&"source_id"]) < str(second[&"source_id"])
		)
	)


static func _assignment_precedes(first: Dictionary, second: Dictionary) -> bool:
	var a: String = "%d|%s|%02d|%s" % [
		int(first[&"shift"]), str(first[&"site_id"]), int(first[&"slot"]), str(first[&"settler_id"])
	]
	var b: String = "%d|%s|%02d|%s" % [
		int(second[&"shift"]), str(second[&"site_id"]), int(second[&"slot"]), str(second[&"settler_id"])
	]
	return a < b


static func _result_precedes(first: Dictionary, second: Dictionary) -> bool:
	return _assignment_precedes(first, second)


static func _result(
	ok: bool,
	candidate: Dictionary,
	shift_results: Array[Dictionary],
	reason: StringName,
) -> Dictionary:
	return {
		&"ok": ok, &"candidate": candidate.duplicate(true),
		&"shift_results": shift_results.duplicate(true), &"reason": reason,
	}
