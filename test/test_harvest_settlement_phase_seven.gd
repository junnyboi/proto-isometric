extends RefCounted

const BlueprintCatalogScript: GDScript = preload(
	"res://scripts/construction_blueprint_catalog.gd"
)
const BuildingStorageScript: GDScript = preload(
	"res://scripts/building_local_storage_service.gd"
)
const CalendarScript: GDScript = preload("res://scripts/calendar_state.gd")
const ConstructionStateScript: GDScript = preload(
	"res://scripts/construction_state_service.gd"
)
const ExtractionScript: GDScript = preload("res://scripts/gathering_extraction_service.gd")
const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const GatheringScript: GDScript = preload("res://scripts/gathering_state_service.gd")
const InventoryScript: GDScript = preload("res://scripts/inventory_service.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const ReceiptScript: GDScript = preload("res://scripts/exact_once_receipt_ledger.gd")
const ResourceCatalogScript: GDScript = preload("res://scripts/resource_deposit_catalog.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")
const SettlerCatalogScript: GDScript = preload("res://scripts/settler_catalog.gd")
const SettlerDayScript: GDScript = preload("res://scripts/settler_day_service.gd")
const SettlerPresentationScript: GDScript = preload(
	"res://scripts/settler_presentation_catalog.gd"
)
const StateHashScript: GDScript = preload("res://scripts/persistence_state_hash.gd")
const WorkforceScript: GDScript = preload("res://scripts/workforce_service.gd")

const SEED: int = 0x48415256


static func evaluate_contracts() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var contributors: Array[StringName] = [
		SettlerCatalogScript.AMARA_VOSS,
		SettlerCatalogScript.ELENA_MOROZ,
		SettlerCatalogScript.ISHAN_PATEL,
		SettlerCatalogScript.KEIKO_TAN,
	]
	var work: Dictionary = SettlerDayScript.construction_work_for(contributors, 4)
	_add(
		cases,
		"P7 construction uses bounded integer settler units and preserves Protos baseline",
		int(work[&"required_units"]) == 4
		and int(work[&"settler_units"]) == 3
		and int(work[&"protos_units"]) == 1
		and (work[&"contributors"] as Array).size() == 3,
	)
	var ledger: Dictionary = ReceiptScript.make_neutral()
	for day: int in 70:
		var payload: Dictionary = {&"day": day}
		var token: String = "shift:day.%09d:test" % day
		ledger = ReceiptScript.record(ledger, token, payload, {&"day": day})[&"candidate"]
	var compacted: Dictionary = ReceiptScript.retain_prefix(ledger, "shift:day.", 16)
	_add(
		cases,
		"P7 day-shift receipt retention is deterministic and bounded",
		not compacted.is_empty()
		and (compacted[&"entries"] as Array).size() == 16
		and str((compacted[&"entries"] as Array)[0][&"token"]).begins_with(
			"shift:day.000000054"
		),
	)
	_add(
		cases,
		"P7 extraction blueprints retain exactly one productive slot each",
		BlueprintCatalogScript.work_slot_types(BlueprintCatalogScript.SALVAGE_CAMP)[0]
		== &"salvage"
		and BlueprintCatalogScript.work_slot_types(BlueprintCatalogScript.SURVEY_DRILL)[0]
		== &"mining"
		and BlueprintCatalogScript.work_slot_types(BlueprintCatalogScript.COPPICE_STATION)[0]
		== &"forestry",
	)
	var pre_p7: Dictionary = SectionsScript.neutral_workforce()
	pre_p7.erase(&"shift_reports")
	var migrated: Dictionary = SectionsScript.validate_workforce(pre_p7)
	_add(
		cases,
		"P7 pre-shift-report workforce migrates canonically to an empty report list",
		not migrated.is_empty() and (migrated[&"shift_reports"] as Array).is_empty(),
	)
	var valid_building: Dictionary = {
		&"instance_id": "building.stack.test",
		&"blueprint_id": str(BlueprintCatalogScript.SALVAGE_CAMP),
		&"anchor": [0, 0], &"orientation": 0, &"level": 1, &"state": "complete",
		&"footprint": [[0, 0]],
		&"local_stacks": [{&"item_id": "item.material.scrap", &"count": 1}],
		&"recipe_policies": [],
	}
	var unknown_stack: Dictionary = valid_building.duplicate(true)
	unknown_stack[&"local_stacks"] = [{&"item_id": "item.unknown", &"count": 1}]
	var overflow_stack: Dictionary = valid_building.duplicate(true)
	overflow_stack[&"local_stacks"] = [
		{
			&"item_id": "item.material.scrap",
			&"count": ItemCatalogScript.stack_limit(&"item.material.scrap") + 1,
		}
	]
	_add(
		cases,
		"P7 cold-load schema rejects unknown and over-limit local output stacks",
		not SectionsScript.validate_construction(
			{&"state_version": 1, &"buildings": [valid_building]}
		).is_empty()
		and SectionsScript.validate_construction(
			{&"state_version": 1, &"buildings": [unknown_stack]}
		).is_empty()
		and SectionsScript.validate_construction(
			{&"state_version": 1, &"buildings": [overflow_stack]}
		).is_empty(),
	)
	return cases


static func evaluate(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = evaluate_contracts()
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var transactions: RefCounted = bridge.call("get_transaction_boundary") as RefCounted
	var construction: RefCounted = bridge.call("get_construction_runtime") as RefCounted
	var settlement: RefCounted = bridge.call("get_settlement_runtime") as RefCounted
	_pre_p7_hash_case(cases, transactions)
	var seeded: Dictionary = _seed_farm(transactions, farm_runtime)
	var camp_site: Dictionary = construction.call(
		"find_initial", BlueprintCatalogScript.SALVAGE_CAMP
	) as Dictionary
	var camp_cells: Array[Vector2i] = camp_site.get(&"cells", []) as Array[Vector2i]
	var camp_placed: Dictionary = construction.call(
		"place", BlueprintCatalogScript.SALVAGE_CAMP, camp_cells[0], 0
	) as Dictionary
	var camp_sleep: Dictionary = farm_runtime.call("transact", &"sleep", {}) as Dictionary
	_add(
		cases,
		"P7 live salvage camp completes through the preserved P4 baseline",
		seeded[&"ok"] and camp_site[&"ok"] and camp_placed[&"ok"] and camp_sleep[&"ok"],
	)
	var populated: Dictionary = _with_two_settlers(
		farm_runtime.call("get_snapshot") as Dictionary
	)
	var population_commit: Dictionary = _commit_farm(transactions, farm_runtime, populated)
	var warehouse_site: Dictionary = construction.call(
		"find_initial", BlueprintCatalogScript.FIELD_WAREHOUSE
	) as Dictionary
	var warehouse_cells: Array[Vector2i] = (
		warehouse_site.get(&"cells", []) as Array[Vector2i]
	)
	var warehouse_placed: Dictionary = construction.call(
		"place", BlueprintCatalogScript.FIELD_WAREHOUSE, warehouse_cells[0], 0
	) as Dictionary
	var construction_sleep: Dictionary = farm_runtime.call("transact", &"sleep", {}) as Dictionary
	var work_results: Array = construction_sleep.get(&"construction_work", []) as Array
	var construction_summary: Dictionary = (
		work_results[0] as Dictionary if not work_results.is_empty() else {}
	)
	_add(
		cases,
		"P7 unassigned settlers contribute once while Protos always completes construction",
		population_commit[&"ok"]
		and warehouse_site[&"ok"]
		and warehouse_placed[&"ok"]
		and construction_sleep[&"ok"]
		and int(construction_summary.get(&"settler_units", 0)) == 2
		and int(construction_summary.get(&"protos_units", 0)) >= 1
		and (construction_summary.get(&"contributors", []) as Array).size() == 2,
	)
	var no_worker_result: Dictionary = _find_reason(
		construction_sleep.get(&"shift_results", []) as Array, &"no_worker"
	)
	var no_worker_report: Dictionary = _find_report_reason(
		farm_runtime.call("get_snapshot") as Dictionary, &"no_worker"
	)
	var terminal_no_worker: bool = false
	for site: Dictionary in settlement.call("snapshot")[&"sites"] as Array[Dictionary]:
		for report: Dictionary in site.get(&"shift_reports", []) as Array[Dictionary]:
			terminal_no_worker = terminal_no_worker or str(report[&"reason"]) == "no_worker"
	_add(
		cases,
		"P7 unstaffed extraction persists a stable no-worker idle report",
		not no_worker_result.is_empty()
		and not no_worker_report.is_empty()
		and terminal_no_worker,
	)
	var camp_id: StringName = _site_id(
		farm_runtime.call("get_snapshot") as Dictionary,
		BlueprintCatalogScript.SALVAGE_CAMP,
	)
	var before_assign: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var revision: int = int((before_assign[&"revisions"] as Dictionary)[&"result_revision"])
	var assigned_result: Dictionary = settlement.call(
		"assign",
		SettlerCatalogScript.AMARA_VOSS,
		camp_id,
		0,
		WorkforceScript.SHIFT_DAY,
		revision,
	) as Dictionary
	var assigned: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var working_records: Array[Dictionary] = SettlerPresentationScript.build_records(assigned)
	var amara_working: Dictionary = _record(working_records, SettlerCatalogScript.AMARA_VOSS)
	_add(
		cases,
		"P7 assigned settler presents as a node-free working record at the work site",
		assigned_result[&"ok"]
		and amara_working[&"status"] == SettlerDayScript.WORKING
		and amara_working[&"cell"]
		== SettlerDayScript.work_cell(assigned, SettlerCatalogScript.AMARA_VOSS),
	)
	var absolute_day: int = CalendarScript.absolute_day(assigned[&"calendar_weather"])
	var pure_first: Dictionary = ExtractionScript.advance(assigned, SEED, absolute_day)
	var pure_second: Dictionary = ExtractionScript.advance(
		pure_first[&"candidate"], SEED, absolute_day
	)
	var pure_productive: Dictionary = _find_status(
		pure_first[&"shift_results"] as Array, "productive"
	)
	var pure_source: Dictionary = _source_from_result(pure_productive)
	var pure_before_state: Dictionary = GatheringScript.effective(
		assigned, pure_source, absolute_day
	)
	var pure_after_state: Dictionary = GatheringScript.effective(
		pure_first[&"candidate"], pure_source, absolute_day
	)
	var pure_report: Dictionary = SettlerDayScript.last_shift_report(
		pure_first[&"candidate"], SettlerCatalogScript.AMARA_VOSS
	)
	_add(
		cases,
		"P7 one shift reserves one charge credits one local output and replays exactly once",
		pure_first[&"ok"]
		and pure_second[&"ok"]
		and pure_second[&"candidate"] == pure_first[&"candidate"]
		and pure_second[&"shift_results"] == pure_first[&"shift_results"]
		and int(pure_after_state[&"remaining_charges"])
		== int(pure_before_state[&"remaining_charges"]) - 1
		and BuildingStorageScript.count(
			pure_first[&"candidate"], camp_id, pure_productive[&"item_id"] as StringName
		)
		== int(pure_productive[&"count"])
		and str(pure_report[&"source_id"]) == str(pure_productive[&"source_id"])
		and str(pure_report[&"item_id"]) == str(pure_productive[&"item_id"])
		and int(pure_report[&"count"]) == int(pure_productive[&"count"]),
	)
	_idle_reason_cases(cases, assigned, camp_id, pure_source, absolute_day)
	var shift_receipts_before: int = _day_shift_receipt_count(assigned)
	var slept: Dictionary = farm_runtime.call("transact", &"sleep", {}) as Dictionary
	var after: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var productive: Dictionary = _find_status(slept[&"shift_results"] as Array, "productive")
	var source: Dictionary = _source_from_result(productive)
	var after_state: Dictionary = GatheringScript.effective(
		after, source, CalendarScript.absolute_day(after[&"calendar_weather"])
	)
	var manual: Dictionary = GatheringScript.gather(
		after,
		source,
		CalendarScript.absolute_day(after[&"calendar_weather"]),
		&"manual",
		"",
	)
	var carrying: Dictionary = _record(
		SettlerPresentationScript.build_records(after), SettlerCatalogScript.AMARA_VOSS
	)
	var warehouse_id: StringName = _site_id(after, BlueprintCatalogScript.FIELD_WAREHOUSE)
	_add(
		cases,
		"P7 authoritative sleep persists one productive shift before P8 self-haul",
		slept[&"ok"]
		and not productive.is_empty()
		and _day_shift_receipt_count(after) == shift_receipts_before + 1
		and str(after_state[&"reserved_by"]).is_empty()
		and BuildingStorageScript.count(
			after, warehouse_id, productive[&"item_id"] as StringName
		)
		== int(productive[&"count"])
		and manual[&"ok"]
		and carrying[&"status"] == SettlerDayScript.WORKING,
	)
	var unassigned_output: Dictionary = WorkforceScript.unassign(
		pure_first[&"candidate"], SettlerCatalogScript.AMARA_VOSS
	)[&"candidate"]
	var cleared: Dictionary = GatheringScript.clear_reservation(
		unassigned_output,
		source,
		CalendarScript.absolute_day(unassigned_output[&"calendar_weather"]),
		str(camp_id),
	)
	var protected_demolition: Dictionary = ConstructionStateScript.demolish(
		cleared[&"candidate"], camp_id
	)
	var unassigned: Dictionary = WorkforceScript.unassign(
		after, SettlerCatalogScript.AMARA_VOSS
	)[&"candidate"]
	var resting: Dictionary = _record(
		SettlerPresentationScript.build_records(unassigned), SettlerCatalogScript.AMARA_VOSS
	)
	_add(
		cases,
		"P7 unhauled output remains a hard dependency and unassigned settlers rest at beds",
		not protected_demolition[&"ok"]
		and protected_demolition[&"reason"] == &"building_has_assignments"
		and resting[&"status"] == SettlerDayScript.RESTING,
	)
	_soak_case(cases, assigned)
	var renderer: Node2D = bridge.call("get_farm_renderer") as Node2D
	_add(
		cases,
		"P7 final staffed state stays schema-valid with zero per-settler scene nodes",
		not FarmSchemaScript.validate(after).is_empty()
		and not bool(renderer.call("has_per_entity_nodes")),
	)
	return cases


static func evaluate_reloaded(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var camp_id: StringName = _site_id(farm, BlueprintCatalogScript.SALVAGE_CAMP)
	var assignment: Dictionary = WorkforceScript.assignment_for(
		farm, SettlerCatalogScript.AMARA_VOSS
	)
	var shift_receipts: int = _day_shift_receipt_count(farm)
	var camp: Dictionary = ConstructionStateScript.building(farm, camp_id)
	var warehouse_id: StringName = _site_id(farm, BlueprintCatalogScript.FIELD_WAREHOUSE)
	var warehouse: Dictionary = ConstructionStateScript.building(farm, warehouse_id)
	var report: Dictionary = SettlerDayScript.last_shift_report(
		farm, SettlerCatalogScript.AMARA_VOSS
	)
	var source: Dictionary = _source_from_report(report)
	var source_state: Dictionary = GatheringScript.effective(
		farm, source, int(report.get(&"absolute_day", 1))
	)
	var receipt: Dictionary = _day_shift_receipt(farm)
	var receipt_result: Dictionary = receipt.get(&"result", {}) as Dictionary
	var replay: Dictionary = ExtractionScript.advance(
		farm, SEED, int(report.get(&"absolute_day", 1))
	)
	_add(
		cases,
		"P7 cold reload preserves assignment delivered output report receipt and replay",
		not assignment.is_empty()
		and (camp[&"local_stacks"] as Array).is_empty()
		and not (warehouse[&"local_stacks"] as Array).is_empty()
		and shift_receipts >= 1
		and str(source_state[&"reserved_by"]).is_empty()
		and int(source_state[&"remaining_charges"]) == int(source[&"capacity"]) - 1
		and str(receipt_result.get(&"source_id", "")) == str(report[&"source_id"])
		and int(receipt_result.get(&"count", 0)) == int(report[&"count"])
		and replay[&"candidate"] == farm
		and not FarmSchemaScript.validate(farm).is_empty(),
	)
	return cases


static func _idle_reason_cases(
	cases: Array[Dictionary],
	assigned: Dictionary,
	camp_id: StringName,
	source: Dictionary,
	absolute_day: int,
) -> void:
	var unsafe: Dictionary = ExtractionScript.advance(
		assigned, SEED, absolute_day, Callable(), Callable(_always_unsafe)
	)
	_add(
		cases,
		"P7 unsafe work idles explicitly without consuming a source charge",
		_find_reason(unsafe[&"shift_results"], &"site_unsafe") != {}
		and SettlerDayScript.last_shift_report(
			unsafe[&"candidate"], SettlerCatalogScript.AMARA_VOSS
		)[&"reason"] == "site_unsafe"
		and SettlerDayScript.presentation_status(
			unsafe[&"candidate"], SettlerCatalogScript.AMARA_VOSS
		) == SettlerDayScript.IDLE
		and GatheringScript.effective(unsafe[&"candidate"], source, absolute_day)
		== GatheringScript.effective(assigned, source, absolute_day),
	)
	var unavailable: Dictionary = assigned.duplicate(true)
	var workforce: Dictionary = (unavailable[&"homestead"] as Dictionary)[&"workforce"]
	(workforce[&"settlers"] as Array)[0][&"status"] = "recovering"
	var recovery: Dictionary = ExtractionScript.advance(unavailable, SEED, absolute_day)
	_add(
		cases,
		"P7 recovering workers idle explicitly without output mutation",
		not _find_reason(recovery[&"shift_results"], &"settler_recovering").is_empty()
		and SettlerDayScript.presentation_status(
			recovery[&"candidate"], SettlerCatalogScript.AMARA_VOSS
		) == SettlerDayScript.RECOVERING
		and ConstructionStateScript.building(recovery[&"candidate"], camp_id)[&"local_stacks"]
		== ConstructionStateScript.building(unavailable, camp_id)[&"local_stacks"],
	)
	var warehouse_id: StringName = _site_id(assigned, BlueprintCatalogScript.FIELD_WAREHOUSE)
	var reserved_farm: Dictionary = _with_source_state(
		assigned, source, int(source[&"capacity"]), str(warehouse_id)
	)
	var single_source: Callable = Callable(_single_source_at).bind(source)
	var contested: Dictionary = ExtractionScript.advance(
		reserved_farm, SEED, absolute_day, single_source
	)
	var exhausted_farm: Dictionary = _with_source_state(assigned, source, 0, "")
	var exhausted: Dictionary = ExtractionScript.advance(
		exhausted_farm, SEED, absolute_day, single_source
	)
	_add(
		cases,
		"P7 reserved and exhausted compatible sources retain distinct idle reasons",
		not reserved_farm.is_empty()
		and not _find_reason(contested[&"shift_results"], &"source_reserved").is_empty()
		and not _find_reason(exhausted[&"shift_results"], &"source_exhausted").is_empty(),
	)
	var missing_source: Dictionary = ExtractionScript.advance(
		assigned, SEED, absolute_day, Callable(_no_source)
	)
	_add(
		cases,
		"P7 missing compatible sources produce a stable idle reason",
		not _find_reason(
			missing_source[&"shift_results"], &"no_compatible_source"
		).is_empty(),
	)
	var item_id: StringName = source[&"reward_item_id"] as StringName
	var full: Dictionary = BuildingStorageScript.credit(
		assigned, camp_id, item_id, ItemCatalogScript.stack_limit(item_id)
	)
	var blocked: Dictionary = ExtractionScript.advance(
		full[&"candidate"], SEED, absolute_day
	)
	_add(
		cases,
		"P7 full local output idles before reservation depletion or credit",
		full[&"ok"]
		and not _find_reason(blocked[&"shift_results"], &"local_output_full").is_empty()
		and GatheringScript.effective(blocked[&"candidate"], source, absolute_day)
		== GatheringScript.effective(full[&"candidate"], source, absolute_day),
	)
	var removed: Dictionary = WorkforceScript.unassign(
		assigned, SettlerCatalogScript.AMARA_VOSS
	)
	var hauling: Dictionary = WorkforceScript.assign(
		removed[&"candidate"],
		SettlerCatalogScript.AMARA_VOSS,
		camp_id,
		1,
		WorkforceScript.SHIFT_DAY,
	)
	var non_extraction: Dictionary = ExtractionScript.advance(
		hauling[&"candidate"], SEED, absolute_day
	)
	_add(
		cases,
		"P7 non-extraction work slots never consume source charges",
		hauling[&"ok"]
		and not _find_reason(
			non_extraction[&"shift_results"], &"slot_not_extraction"
		).is_empty()
		and GatheringScript.effective(non_extraction[&"candidate"], source, absolute_day)
		== GatheringScript.effective(assigned, source, absolute_day),
	)


static func _soak_case(cases: Array[Dictionary], assigned: Dictionary) -> void:
	var candidate: Dictionary = assigned.duplicate(true)
	var valid: bool = true
	for day: int in range(1, 181):
		var result: Dictionary = ExtractionScript.advance(candidate, SEED, 1_000 + day)
		if not bool(result[&"ok"]):
			valid = false
			break
		candidate = result[&"candidate"] as Dictionary
	var count: int = _day_shift_receipt_count(candidate)
	_add(
		cases,
		"P7 180-day staffed soak remains schema-valid at the shared shift receipt quota",
		valid
		and count == int(ReceiptScript.NAMESPACE_LIMITS["shift"])
		and not FarmSchemaScript.validate(candidate).is_empty(),
	)


static func _pre_p7_hash_case(cases: Array[Dictionary], transactions: RefCounted) -> void:
	var legacy: Dictionary = (transactions.call("get_snapshot") as Dictionary).duplicate(true)
	var farm: Dictionary = legacy[&"farm"] as Dictionary
	var workforce: Dictionary = (farm[&"homestead"] as Dictionary)[&"workforce"]
	workforce.erase(&"shift_reports")
	var revisions: Dictionary = farm[&"revisions"] as Dictionary
	if int(revisions[&"result_revision"]) == 0:
		legacy = StateHashScript.apply_initial(legacy)
	else:
		revisions[&"result_hash"] = StateHashScript.state_hash(legacy)
		farm[&"revisions"] = revisions
		legacy[&"farm"] = farm
	var repository: RefCounted = transactions.get("_repository") as RefCounted
	var migrated: Dictionary = repository.call("validate_envelope", legacy) as Dictionary
	var migrated_workforce: Dictionary = (
		((migrated.get(&"farm", {}) as Dictionary).get(&"homestead", {}) as Dictionary)
		.get(&"workforce", {}) as Dictionary
	)
	var tampered: Dictionary = legacy.duplicate(true)
	(tampered[&"farm"] as Dictionary)[&"tutorial"][&"suppressed"] = true
	_add(
		cases,
		"P7 genuine pre-P7 hashed save migrates reports once while tampering still fails",
		not migrated.is_empty()
		and (migrated_workforce[&"shift_reports"] as Array).is_empty()
		and StateHashScript.result_hash_matches(migrated)
		and (repository.call("validate_envelope", tampered) as Dictionary).is_empty(),
	)


static func _with_two_settlers(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	var workforce: Dictionary = homestead[&"workforce"] as Dictionary
	workforce[&"settlers"] = [
		{
			&"settler_id": str(SettlerCatalogScript.AMARA_VOSS),
			&"status": "active", &"morale": 80, &"injured_until_day": 0,
		},
		{
			&"settler_id": str(SettlerCatalogScript.TOMAS_REED),
			&"status": "active", &"morale": 80, &"injured_until_day": 0,
		},
	]
	workforce[&"housing_assignments"] = [
		{&"settler_id": str(SettlerCatalogScript.AMARA_VOSS), &"bed_id": "bed.home.0"},
		{&"settler_id": str(SettlerCatalogScript.TOMAS_REED), &"bed_id": "bed.home.1"},
	]
	homestead[&"workforce"] = SectionsScript.validate_workforce(workforce)
	candidate[&"homestead"] = homestead
	return FarmSchemaScript.validate(candidate)


static func _seed_farm(transactions: RefCounted, farm_runtime: RefCounted) -> Dictionary:
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	for entry: Dictionary in [
		{&"item_id": &"item.material.wood", &"count": 60},
		{&"item_id": &"item.material.stone", &"count": 60},
		{&"item_id": &"item.material.scrap", &"count": 60},
	]:
		var credit: Dictionary = InventoryScript.credit_with_overflow(
			farm, entry[&"item_id"] as StringName, int(entry[&"count"])
		)
		if not bool(credit[&"ok"]):
			return credit
		farm = credit[&"candidate"] as Dictionary
	return _commit_farm(transactions, farm_runtime, farm)


static func _commit_farm(
	transactions: RefCounted, farm_runtime: RefCounted, farm: Dictionary
) -> Dictionary:
	var committed: Dictionary = transactions.call(
		"transact", &"farm_candidate", {&"farm": farm}
	) as Dictionary
	if bool(committed[&"ok"]):
		farm_runtime.call("sync_committed", (committed[&"candidate"] as Dictionary)[&"farm"])
	return committed


static func _site_id(farm: Dictionary, blueprint_id: StringName) -> StringName:
	var construction: Dictionary = (farm[&"homestead"] as Dictionary)[&"construction"]
	for building: Dictionary in construction[&"buildings"] as Array[Dictionary]:
		if StringName(str(building[&"blueprint_id"])) == blueprint_id:
			return StringName(str(building[&"instance_id"]))
	return &""


static func _source_from_result(result: Dictionary) -> Dictionary:
	if result.is_empty():
		return {}
	var cell: Vector2i = ResourceCatalogScript.cell_from_id(str(result[&"source_id"]))
	return ResourceCatalogScript.project_at(cell, SEED)


static func _source_from_report(report: Dictionary) -> Dictionary:
	if report.is_empty() or str(report.get(&"source_id", "")).is_empty():
		return {}
	var cell: Vector2i = ResourceCatalogScript.cell_from_id(str(report[&"source_id"]))
	return ResourceCatalogScript.project_at(cell, SEED)


static func _with_source_state(
	farm: Dictionary, source: Dictionary, remaining: int, owner: String
) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var gathering: Dictionary = candidate[&"gathering"] as Dictionary
	var deltas: Array[Dictionary] = []
	for delta: Dictionary in gathering[&"resource_deltas"] as Array[Dictionary]:
		if str(delta[&"source_id"]) != str(source[&"source_id"]):
			deltas.append(delta.duplicate(true))
	deltas.append(
		{
			&"source_id": str(source[&"source_id"]), &"remaining_charges": remaining,
			&"renewal_day": 0, &"reserved_by": owner,
		}
	)
	gathering[&"resource_deltas"] = deltas
	candidate[&"gathering"] = SectionsScript.validate_gathering(gathering)
	return FarmSchemaScript.validate(candidate)


static func _find_reason(results: Array, reason: StringName) -> Dictionary:
	for result: Dictionary in results:
		if StringName(str(result[&"reason"])) == reason:
			return result.duplicate(true)
	return {}


static func _find_report_reason(farm: Dictionary, reason: StringName) -> Dictionary:
	var workforce: Dictionary = (farm[&"homestead"] as Dictionary)[&"workforce"]
	for report: Dictionary in workforce[&"shift_reports"] as Array[Dictionary]:
		if StringName(str(report[&"reason"])) == reason:
			return report.duplicate(true)
	return {}


static func _find_status(results: Array, status: String) -> Dictionary:
	for result: Dictionary in results:
		if str(result[&"status"]) == status:
			return result.duplicate(true)
	return {}


static func _record(
	records: Array[Dictionary], settler_id: StringName
) -> Dictionary:
	for record: Dictionary in records:
		if record[&"stable_id"] == settler_id:
			return record.duplicate(true)
	return {}


static func _receipt_count(farm: Dictionary) -> int:
	return ((farm[&"receipts"] as Dictionary)[&"entries"] as Array).size()


static func _day_shift_receipt_count(farm: Dictionary) -> int:
	var result: int = 0
	for entry: Dictionary in (farm[&"receipts"] as Dictionary)[&"entries"]:
		if str(entry[&"token"]).begins_with(ExtractionScript.DAY_SHIFT_PREFIX):
			result += 1
	return result


static func _day_shift_receipt(farm: Dictionary) -> Dictionary:
	for entry: Dictionary in (farm[&"receipts"] as Dictionary)[&"entries"]:
		if str(entry[&"token"]).begins_with(ExtractionScript.DAY_SHIFT_PREFIX):
			return entry.duplicate(true)
	return {}


static func _always_unsafe(_position: Vector2) -> bool:
	return false


static func _no_source(_cell: Vector2i) -> Dictionary:
	return {}


static func _single_source_at(cell: Vector2i, source: Dictionary) -> Dictionary:
	return (
		source.duplicate(true)
		if cell == (source[&"cell"] as Vector2i)
		else {}
	)


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
