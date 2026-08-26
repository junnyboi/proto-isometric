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
const LogisticsScript: GDScript = preload("res://scripts/logistics_service.gd")
const ProductionScript: GDScript = preload("res://scripts/production_policy_service.gd")
const RecipeCatalogScript: GDScript = preload("res://scripts/recipe_catalog.gd")
const ReceiptLedgerScript: GDScript = preload("res://scripts/exact_once_receipt_ledger.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")
const SettlerCatalogScript: GDScript = preload("res://scripts/settler_catalog.gd")
const StateHashScript: GDScript = preload("res://scripts/persistence_state_hash.gd")
const ToolScript: GDScript = preload("res://scripts/tool_service.gd")

const COIL_RECIPE: StringName = &"recipe.workbench.irrigation_coil"
const INGOT_RECIPE: StringName = &"recipe.furnace.iron_ingot"


static func evaluate_contracts() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var coil: Dictionary = RecipeCatalogScript.definition(COIL_RECIPE)
	var ingot: Dictionary = RecipeCatalogScript.definition(INGOT_RECIPE)
	_add(
		cases,
		"P8 recipes expose deterministic alternatives and bounded byproducts",
		(coil[&"ingredient_groups"] as Array).size() == 2
		and ((coil[&"ingredient_groups"] as Array)[0][&"options"] as Array).size() == 2
		and (ingot[&"byproducts"] as Array).size() == 1,
	)
	var legacy_building: Dictionary = {
		&"instance_id": "building.p8.legacy",
		&"blueprint_id": str(BlueprintCatalogScript.FABRICATOR_ANNEX),
		&"anchor": [0, 0], &"orientation": 0, &"level": 1, &"state": "complete",
		&"footprint": [[0, 0]], &"local_stacks": [], &"recipe_policies": [],
	}
	var migrated_construction: Dictionary = SectionsScript.validate_construction(
		{&"state_version": 1, &"buildings": [legacy_building]}
	)
	var migrated_building: Dictionary = (
		(migrated_construction[&"buildings"] as Array)[0]
		if not migrated_construction.is_empty()
		else {}
	)
	var migrated_logistics: Dictionary = SectionsScript.validate_logistics(
		{&"state_version": 1, &"jobs": []}
	)
	_add(
		cases,
		"P8 pre-logistics saves migrate dual buffers orders and reserve floors neutrally",
		not migrated_building.is_empty()
		and (migrated_building[&"local_input_stacks"] as Array).is_empty()
		and (migrated_building[&"production_orders"] as Array).is_empty()
		and (migrated_logistics[&"reserve_rules"] as Array).is_empty(),
	)
	var invalid_policy: Dictionary = legacy_building.duplicate(true)
	invalid_policy[&"local_input_stacks"] = []
	invalid_policy[&"production_orders"] = []
	invalid_policy[&"recipe_policies"] = [
		{&"recipe_id": "recipe.unknown", &"enabled": true, &"priority": 5, &"target_count": 1}
	]
	var invalid_station: Dictionary = migrated_building.duplicate(true)
	invalid_station[&"blueprint_id"] = str(BlueprintCatalogScript.SHELTER_POD)
	invalid_station[&"local_input_stacks"] = [
		{&"item_id": "item.material.wood", &"count": 1}
	]
	_add(
		cases,
		"P8 cold-load rejects unknown policies reserve items and non-fabricator inputs",
		SectionsScript.validate_construction(
			{&"state_version": 1, &"buildings": [invalid_policy]}
		).is_empty()
		and SectionsScript.validate_construction(
			{&"state_version": 1, &"buildings": [invalid_station]}
		).is_empty()
		and SectionsScript.validate_logistics(
			{
				&"state_version": 1, &"jobs": [],
				&"reserve_rules": [{&"item_id": "item.unknown", &"floor": 1}],
			}
		).is_empty(),
	)
	var impossible_workforce: Dictionary = SectionsScript.validate_workforce(
		{
			&"state_version": 1,
			&"settlers": [
				{
					&"settler_id": "settler.p8.invalid", &"status": "active",
					&"morale": 80, &"injured_until_day": 0,
				}
			],
			&"housing_assignments": [],
			&"work_assignments": [
				{
					&"settler_id": "settler.p8.invalid",
					&"site_id": "building.p8.legacy", &"slot": 31, &"shift": 0,
				}
			],
			&"concerns": [], &"shift_reports": [],
			&"applicant_lifecycle": SectionsScript.neutral_workforce()[&"applicant_lifecycle"],
		}
	)
	var incomplete_building: Dictionary = migrated_building.duplicate(true)
	incomplete_building[&"state"] = "constructing"
	var incomplete_construction: Dictionary = SectionsScript.validate_construction(
		{&"state_version": 1, &"buildings": [incomplete_building]}
	)
	var sentinel_workforce: Dictionary = SectionsScript.validate_workforce(
		{
			&"state_version": 1, &"settlers": [], &"housing_assignments": [],
			&"work_assignments": [], &"concerns": [],
			&"shift_reports": [
				{
					&"report_id": "report.p8.incomplete", &"site_id": "building.p8.legacy",
					&"settler_id": "", &"slot": -1, &"shift": -1, &"absolute_day": 1,
					&"status": "idle", &"reason": "no_worker", &"source_id": "",
					&"item_id": "", &"count": 0,
				}
			],
			&"applicant_lifecycle": SectionsScript.neutral_workforce()[&"applicant_lifecycle"],
		}
	)
	_add(
		cases,
		"P8 farm links reject invalid slots and incomplete sentinel report sites",
		not impossible_workforce.is_empty()
		and not SectionsScript.validate_links(
			migrated_construction,
			SectionsScript.neutral_gathering(),
			impossible_workforce,
			SectionsScript.neutral_logistics(),
		)
		and not incomplete_construction.is_empty()
		and not sentinel_workforce.is_empty()
		and not SectionsScript.validate_links(
			incomplete_construction,
			SectionsScript.neutral_gathering(),
			sentinel_workforce,
			SectionsScript.neutral_logistics(),
		),
	)
	return cases


static func evaluate(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = evaluate_contracts()
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var transactions: RefCounted = bridge.call("get_transaction_boundary") as RefCounted
	var construction: RefCounted = bridge.call("get_construction_runtime") as RefCounted
	var settlement: RefCounted = bridge.call("get_settlement_runtime") as RefCounted
	var phase_b: RefCounted = bridge.call("get_interaction_phase_b_service") as RefCounted
	_pre_p8_hash_case(cases, transactions)
	var seeded: Dictionary = _seed_farm(transactions, farm_runtime)
	var built: bool = bool(seeded[&"ok"])
	for blueprint_id: StringName in [
		BlueprintCatalogScript.SHELTER_POD,
		BlueprintCatalogScript.FIELD_WAREHOUSE,
		BlueprintCatalogScript.SALVAGE_CAMP,
		BlueprintCatalogScript.FABRICATOR_ANNEX,
	]:
		built = built and _construct(construction, farm_runtime, blueprint_id)
	_add(cases, "P8 live warehouse extraction and fabrication sites complete", built)
	var built_farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var camp_id: StringName = _site_id(built_farm, BlueprintCatalogScript.SALVAGE_CAMP)
	var warehouse_id: StringName = _site_id(
		built_farm, BlueprintCatalogScript.FIELD_WAREHOUSE
	)
	var fabricator_id: StringName = _site_id(
		built_farm, BlueprintCatalogScript.FABRICATOR_ANNEX
	)
	var warehouse: Dictionary = ConstructionStateScript.building(built_farm, warehouse_id)
	var warehouse_anchor: Array = warehouse[&"anchor"] as Array
	var warehouse_projection: Dictionary = phase_b.call(
		"project",
		Vector2i(int(warehouse_anchor[0]), int(warehouse_anchor[1])),
		ToolScript.TOOL_CONTEXT,
	) as Dictionary
	var logistics_option: Dictionary = _projection_option(
		warehouse_projection, &"open_settlement_logistics"
	)
	_add(
		cases,
		"P8 complete warehouse E-terminal exposes sealed logistics without Quick bypass",
		not logistics_option.is_empty()
		and str(logistics_option[&"action_id"]) == "interaction.action.open_logistics"
		and not bool(logistics_option.get(&"quick_eligible", false)),
	)
	var no_warehouse: Dictionary = built_farm.duplicate(true)
	var no_warehouse_construction: Dictionary = no_warehouse[&"homestead"][&"construction"]
	for building: Dictionary in no_warehouse_construction[&"buildings"] as Array[Dictionary]:
		if str(building[&"instance_id"]) == str(warehouse_id):
			building[&"state"] = "constructing"
	var retained: Dictionary = LocalStorageScript.credit(
		no_warehouse, camp_id, &"item.material.scrap", 2
	)
	var no_jobs: Dictionary = LogisticsScript.generate_jobs(retained[&"candidate"])
	_add(
		cases,
		"P8 extraction output stays local when no complete warehouse exists",
		no_jobs[&"ok"]
		and (no_jobs[&"candidate"][&"logistics"][&"jobs"] as Array).is_empty()
		and LocalStorageScript.count(
			no_jobs[&"candidate"], camp_id, &"item.material.scrap"
		) == 2,
	)
	var populated: Dictionary = _with_settlers(farm_runtime.call("get_snapshot") as Dictionary)
	var population_commit: Dictionary = _commit_farm(transactions, farm_runtime, populated)
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var assignment_ok: bool = bool(population_commit[&"ok"])
	for request: Dictionary in [
		{&"settler": SettlerCatalogScript.TOMAS_REED, &"site": camp_id, &"slot": 0},
		{&"settler": SettlerCatalogScript.MAEVE_QUINN, &"site": warehouse_id, &"slot": 0},
		{&"settler": SettlerCatalogScript.AMARA_VOSS, &"site": fabricator_id, &"slot": 0},
	]:
		var snapshot: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
		var revision: int = int(snapshot[&"revisions"][&"result_revision"])
		var assigned: Dictionary = settlement.call(
			"assign", request[&"settler"], request[&"site"], request[&"slot"], 0, revision
		) as Dictionary
		assignment_ok = assignment_ok and bool(assigned[&"ok"])
	_add(cases, "P8 hauling fabrication and extraction assignments commit atomically", assignment_ok)
	farm = farm_runtime.call("get_snapshot") as Dictionary
	for credit: Dictionary in [
		{&"site": camp_id, &"item": &"item.material.scrap", &"count": 6},
		{&"site": warehouse_id, &"item": &"item.material.wood", &"count": 10},
		{&"site": warehouse_id, &"item": &"item.material.stone", &"count": 10},
	]:
		var stored: Dictionary = LocalStorageScript.credit(
			farm, credit[&"site"], credit[&"item"], credit[&"count"]
		)
		farm = stored[&"candidate"] as Dictionary
	_commit_farm(transactions, farm_runtime, farm)
	var reserve_revision: int = _revision(farm_runtime)
	var reserve: Dictionary = settlement.call(
		"set_reserve", &"item.material.stone", 10, reserve_revision
	) as Dictionary
	var reserve_after: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var reserve_replay: Dictionary = settlement.call(
		"set_reserve", &"item.material.stone", 10, reserve_revision
	) as Dictionary
	var reserve_replayed: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	_add(
		cases,
		"P8 reserve floor commits once replays without revision and rejects production debit",
		reserve[&"ok"] and reserve_replay[&"ok"]
		and reserve_after == reserve_replayed
		and LogisticsScript.reserve_floor(reserve_replayed, &"item.material.stone") == 10,
	)
	var policy_revision: int = _revision(farm_runtime)
	var policy: Dictionary = settlement.call(
		"set_recipe_policy", fabricator_id, COIL_RECIPE, true, 8, 1, policy_revision
	) as Dictionary
	var policy_after: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var policy_replay: Dictionary = settlement.call(
		"set_recipe_policy", fabricator_id, COIL_RECIPE, true, 8, 1, policy_revision
	) as Dictionary
	_add(
		cases,
		"P8 production policy commits enabled priority target and replays byte-stably",
		policy[&"ok"] and policy_replay[&"ok"]
		and policy_after == (farm_runtime.call("get_snapshot") as Dictionary),
	)
	var generated: Dictionary = LogisticsScript.generate_jobs(
		farm_runtime.call("get_snapshot") as Dictionary
	)
	var jobs: Array = generated[&"candidate"][&"logistics"][&"jobs"] as Array
	var ordered: bool = _jobs_are_ordered(jobs)
	var jobs_commit: Dictionary = _commit_farm(
		transactions, farm_runtime, generated[&"candidate"]
	)
	_add(
		cases,
		"P8 jobs merge canonically and order by priority age source destination item ID",
		generated[&"ok"] and jobs_commit[&"ok"] and jobs.size() == 2 and ordered,
	)
	var force_job: Dictionary = _job_between(jobs, camp_id, warehouse_id)
	var force_revision: int = _revision(farm_runtime)
	var forced: Dictionary = settlement.call(
		"force_delivery", StringName(str(force_job[&"job_id"])), force_revision
	) as Dictionary
	var after_force: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var revision_after_force: int = _revision(farm_runtime)
	var forced_replay: Dictionary = settlement.call(
		"force_delivery", StringName(str(force_job[&"job_id"])), force_revision
	) as Dictionary
	var after_force_replay: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	_add(
		cases,
		"P8 forced delivery moves exactly once and replay does not advance revision",
		forced[&"ok"] and forced_replay[&"ok"]
		and after_force == after_force_replay
		and _revision(farm_runtime) == revision_after_force
		and LocalStorageScript.count(after_force, camp_id, &"item.material.scrap") == 0
		and LocalStorageScript.count(after_force, warehouse_id, &"item.material.scrap") == 6,
	)
	var day: int = 400
	var hauled: Dictionary = LogisticsScript.advance(after_force, day)
	var hauled_replay: Dictionary = LogisticsScript.advance(hauled[&"candidate"], day)
	var hauled_farm: Dictionary = hauled[&"candidate"] as Dictionary
	_add(
		cases,
		"P8 hauler plus self-haul supply alternatives without breaching reserve floors",
		hauled[&"ok"] and hauled_replay[&"ok"]
		and hauled_replay[&"candidate"] == hauled_farm
		and LocalStorageScript.input_count(
			hauled_farm, fabricator_id, &"item.material.wood"
		) == 2
		and LocalStorageScript.input_count(
			hauled_farm, fabricator_id, &"item.material.scrap"
		) == 1
		and LocalStorageScript.input_count(
			hauled_farm, fabricator_id, &"item.material.stone"
		) == 0
		and LocalStorageScript.count(
			hauled_farm, warehouse_id, &"item.material.stone"
		) == 10,
	)
	_add(
		cases,
		"P8 shared targets count in-flight orders across multiple fabricators",
		_two_fabricator_target_case(hauled_farm, fabricator_id, day),
	)
	var started: Dictionary = ProductionScript.advance(hauled_farm, day)
	var started_replay: Dictionary = ProductionScript.advance(started[&"candidate"], day)
	var completed: Dictionary = ProductionScript.advance(started[&"candidate"], day + 1)
	var completed_farm: Dictionary = completed[&"candidate"] as Dictionary
	_add(
		cases,
		"P8 automated production debits once completes once and honors target output",
		started[&"ok"] and started_replay[&"candidate"] == started[&"candidate"]
		and completed[&"ok"]
		and LocalStorageScript.count(
			completed_farm, fabricator_id, &"item.part.irrigation_coil"
		) == 1
		and (ConstructionStateScript.building(
			completed_farm, fabricator_id
		)[&"production_orders"] as Array).is_empty(),
	)
	var ingot_policy: Dictionary = ProductionScript.set_policy(
		completed_farm, fabricator_id, INGOT_RECIPE, true, 9, 1
	)
	var disabled_coil: Dictionary = ProductionScript.set_policy(
		ingot_policy[&"candidate"], fabricator_id, COIL_RECIPE, false, 8, 1
	)
	var ingot_inputs: Dictionary = LocalStorageScript.credit_input(
		disabled_coil[&"candidate"], fabricator_id, &"item.material.scrap", 4
	)
	var ingot_started: Dictionary = ProductionScript.advance(ingot_inputs[&"candidate"], day + 2)
	var ingot_done: Dictionary = ProductionScript.advance(ingot_started[&"candidate"], day + 4)
	var final_farm: Dictionary = ingot_done[&"candidate"] as Dictionary
	_add(
		cases,
		"P8 ingredient alternative and byproduct credit are deterministic and atomic",
		ingot_started[&"ok"] and ingot_done[&"ok"]
		and LocalStorageScript.count(
			final_farm, fabricator_id, &"item.part.iron_ingot"
		) == 1
		and LocalStorageScript.count(
			final_farm, fabricator_id, &"item.material.stone"
		) == 1,
	)
	var soak: Dictionary = final_farm.duplicate(true)
	var soak_ok: bool = true
	for offset: int in 180:
		var logistics_day: Dictionary = LogisticsScript.advance(soak, 600 + offset)
		if not bool(logistics_day[&"ok"]):
			soak_ok = false
			break
		var production_day: Dictionary = ProductionScript.advance(
			logistics_day[&"candidate"], 600 + offset
		)
		if not bool(production_day[&"ok"]):
			soak_ok = false
			break
		soak = production_day[&"candidate"] as Dictionary
	_add(
		cases,
		"P8 180-day logistics and production soak retains bounded exact receipts",
		soak_ok
		and _receipt_count(soak, "transfer:day.") <= 16
		and _receipt_count(soak, "production:day.") <= 16
		and (soak[&"receipts"][&"entries"] as Array).size() <= 128
		and not FarmSchemaScript.validate(soak).is_empty(),
	)
	var pressured: Dictionary = final_farm.duplicate(true)
	var pressure_ok: bool = true
	for category: String in ReceiptLedgerScript.TOKEN_NAMESPACES:
		for index: int in 24:
			var token: String = "%s:pressure:%03d" % [category, index]
			var recorded: Dictionary = ReceiptLedgerScript.record(
				pressured[&"receipts"], token, {&"index": index}, {&"ok": true}
			)
			if not bool(recorded[&"ok"]):
				pressure_ok = false
				break
			pressured[&"receipts"] = recorded[&"candidate"]
	var pressure_logistics: Dictionary = LogisticsScript.advance(pressured, 900)
	var pressure_production: Dictionary = ProductionScript.advance(
		pressure_logistics[&"candidate"], 900
	)
	_add(
		cases,
		"P8 namespace quotas keep saturated receipt history from blocking day progress",
		pressure_ok and pressure_logistics[&"ok"] and pressure_production[&"ok"]
		and (
			pressure_production[&"candidate"][&"receipts"][&"entries"] as Array
		).size() <= ReceiptLedgerScript.MAX_RECEIPTS,
	)
	var final_commit: Dictionary = _commit_farm(transactions, farm_runtime, final_farm)
	var modal: Node2D = bridge.call("get_settlement_modal_controller") as Node2D
	runtime.get_viewport().size = Vector2i(390, 844)
	var opened: bool = bool(modal.call("open", &"logistics"))
	var presenter: CanvasLayer = modal.call("get_presenter") as CanvasLayer
	var layout: Dictionary = presenter.call("layout_snapshot") as Dictionary
	var panel: Rect2 = layout[&"panel"] as Rect2
	_add(
		cases,
		"P8 native logistics modal reflows within portrait touch-safe geometry",
		final_commit[&"ok"] and opened
		and panel.size.x > 0.0 and panel.end.x <= 390.0
		and float(layout[&"minimum_touch_target"]) >= 44.0
		and int(layout[&"transfer_columns"]) == 1
		and int(layout[&"reserve_columns"]) == 1
		and int(layout[&"policy_columns"]) == 1,
	)
	modal.call("close")
	runtime.get_viewport().size = Vector2i(1280, 720)
	_add(
		cases,
		"P8 final logistics and production state remains schema-valid",
		not FarmSchemaScript.validate(farm_runtime.call("get_snapshot")).is_empty(),
	)
	return cases


static func evaluate_reloaded(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var settlement: RefCounted = bridge.call("get_settlement_runtime") as RefCounted
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var fabricator_id: StringName = _site_id(farm, BlueprintCatalogScript.FABRICATOR_ANNEX)
	var snapshot: Dictionary = settlement.call("snapshot") as Dictionary
	_add(
		cases,
		"P8 cold reload preserves reserve policy receipts outputs byproducts and UI snapshot",
		LogisticsScript.reserve_floor(farm, &"item.material.stone") == 10
		and LocalStorageScript.count(farm, fabricator_id, &"item.part.irrigation_coil") == 1
		and LocalStorageScript.count(farm, fabricator_id, &"item.part.iron_ingot") == 1
		and LocalStorageScript.count(farm, fabricator_id, &"item.material.stone") == 1
		and (snapshot[&"fabricators"] as Array).size() == 1
		and _receipt_count(farm, "transfer:") >= 2
		and _receipt_count(farm, "production:") >= 3
		and not FarmSchemaScript.validate(farm).is_empty(),
	)
	return cases


static func _pre_p8_hash_case(cases: Array[Dictionary], transactions: RefCounted) -> void:
	var legacy: Dictionary = (transactions.call("get_snapshot") as Dictionary).duplicate(true)
	var farm: Dictionary = legacy[&"farm"] as Dictionary
	(farm[&"logistics"] as Dictionary).erase(&"reserve_rules")
	var construction: Dictionary = (farm[&"homestead"] as Dictionary)[&"construction"]
	for building: Dictionary in construction[&"buildings"] as Array[Dictionary]:
		building.erase(&"local_input_stacks")
		building.erase(&"production_orders")
	legacy[&"farm"] = farm
	if int((farm[&"revisions"] as Dictionary)[&"result_revision"]) == 0:
		legacy = StateHashScript.apply_initial(legacy)
	else:
		(farm[&"revisions"] as Dictionary)[&"result_hash"] = StateHashScript.state_hash(legacy)
		legacy[&"farm"] = farm
	var repository: RefCounted = transactions.get("_repository") as RefCounted
	var migrated: Dictionary = repository.call("validate_envelope", legacy) as Dictionary
	var migrated_farm: Dictionary = migrated.get(&"farm", {}) as Dictionary
	var tampered: Dictionary = legacy.duplicate(true)
	(tampered[&"farm"] as Dictionary)[&"tutorial"][&"suppressed"] = true
	_add(
		cases,
		"P8 genuine pre-P8 hashed save migrates once while tampering still fails",
		not migrated_farm.is_empty()
		and (migrated_farm[&"logistics"][&"reserve_rules"] as Array).is_empty()
		and StateHashScript.result_hash_matches(migrated)
		and (repository.call("validate_envelope", tampered) as Dictionary).is_empty(),
	)


static func _construct(
	construction: RefCounted, farm_runtime: RefCounted, blueprint_id: StringName
) -> bool:
	var site: Dictionary = construction.call("find_initial", blueprint_id) as Dictionary
	if not bool(site.get(&"ok", false)):
		return false
	var cells: Array[Vector2i] = site[&"cells"] as Array[Vector2i]
	var placed: Dictionary = construction.call("place", blueprint_id, cells[0], 0) as Dictionary
	if not bool(placed.get(&"ok", false)):
		return false
	var slept: Dictionary = farm_runtime.call("transact", &"sleep", {}) as Dictionary
	if not bool(slept.get(&"ok", false)):
		return false
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	return str(ConstructionStateScript.building(
		farm, _site_id(farm, blueprint_id)
	).get(&"state", "")) == "complete"


static func _two_fabricator_target_case(
	farm: Dictionary, fabricator_id: StringName, absolute_day: int
) -> bool:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	var construction: Dictionary = homestead[&"construction"] as Dictionary
	var second: Dictionary = ConstructionStateScript.building(candidate, fabricator_id)
	second[&"instance_id"] = "building.p8.second_fabricator"
	var anchor: Array = second[&"anchor"] as Array
	second[&"anchor"] = [int(anchor[0]) + 100, int(anchor[1]) + 100]
	var shifted: Array[Array] = []
	for cell: Array in second[&"footprint"] as Array[Array]:
		shifted.append([int(cell[0]) + 100, int(cell[1]) + 100])
	second[&"footprint"] = shifted
	second[&"local_stacks"] = []
	second[&"production_orders"] = []
	(construction[&"buildings"] as Array).append(second)
	homestead[&"construction"] = SectionsScript.validate_construction(construction)
	var workforce: Dictionary = homestead[&"workforce"] as Dictionary
	(workforce[&"settlers"] as Array).append(
		{
			&"settler_id": str(SettlerCatalogScript.ELENA_MOROZ), &"status": "active",
			&"morale": 80, &"injured_until_day": 0,
		}
	)
	var shelter_id: StringName = _site_id(candidate, BlueprintCatalogScript.SHELTER_POD)
	(workforce[&"housing_assignments"] as Array).append(
		{
			&"settler_id": str(SettlerCatalogScript.ELENA_MOROZ),
			&"bed_id": "bed.%s.1" % str(shelter_id),
		}
	)
	(workforce[&"work_assignments"] as Array).append(
		{
			&"settler_id": str(SettlerCatalogScript.ELENA_MOROZ),
			&"site_id": str(second[&"instance_id"]), &"slot": 0, &"shift": 1,
		}
	)
	homestead[&"workforce"] = SectionsScript.validate_workforce(workforce)
	candidate[&"homestead"] = homestead
	candidate = FarmSchemaScript.validate(candidate)
	if candidate.is_empty():
		return false
	var advanced: Dictionary = ProductionScript.advance(candidate, absolute_day)
	if not bool(advanced[&"ok"]):
		return false
	var orders: int = 0
	for building: Dictionary in (
		advanced[&"candidate"][&"homestead"][&"construction"][&"buildings"] as Array[Dictionary]
	):
		orders += (building[&"production_orders"] as Array).size()
	return orders == 1


static func _with_settlers(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	var workforce: Dictionary = homestead[&"workforce"] as Dictionary
	var ids: Array[StringName] = [
		SettlerCatalogScript.TOMAS_REED,
		SettlerCatalogScript.MAEVE_QUINN,
		SettlerCatalogScript.AMARA_VOSS,
	]
	var settlers: Array[Dictionary] = []
	var housing: Array[Dictionary] = []
	for index: int in ids.size():
		settlers.append(
			{
				&"settler_id": str(ids[index]), &"status": "active",
				&"morale": 80, &"injured_until_day": 0,
			}
		)
		var bed_id: String = "bed.home.%d" % index
		if index == 2:
			bed_id = "bed.%s.0" % str(_site_id(candidate, BlueprintCatalogScript.SHELTER_POD))
		housing.append({&"settler_id": str(ids[index]), &"bed_id": bed_id})
	workforce[&"settlers"] = settlers
	workforce[&"housing_assignments"] = housing
	homestead[&"workforce"] = SectionsScript.validate_workforce(workforce)
	candidate[&"homestead"] = homestead
	return FarmSchemaScript.validate(candidate)


static func _seed_farm(transactions: RefCounted, farm_runtime: RefCounted) -> Dictionary:
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	for entry: Dictionary in [
		{&"item": &"item.material.wood", &"count": 60},
		{&"item": &"item.material.stone", &"count": 60},
		{&"item": &"item.material.scrap", &"count": 60},
	]:
		var credit: Dictionary = InventoryScript.credit_with_overflow(
			farm, entry[&"item"], entry[&"count"]
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
		farm_runtime.call("sync_committed", committed[&"candidate"][&"farm"])
	return committed


static func _site_id(farm: Dictionary, blueprint_id: StringName) -> StringName:
	var construction: Dictionary = (farm[&"homestead"] as Dictionary)[&"construction"]
	for building: Dictionary in construction[&"buildings"] as Array[Dictionary]:
		if StringName(str(building[&"blueprint_id"])) == blueprint_id:
			return StringName(str(building[&"instance_id"]))
	return &""


static func _job_between(
	jobs: Array, source_id: StringName, destination_id: StringName
) -> Dictionary:
	for job: Dictionary in jobs as Array[Dictionary]:
		if (
			str(job[&"source_id"]) == str(source_id)
			and str(job[&"destination_id"]) == str(destination_id)
		):
			return job.duplicate(true)
	return {}


static func _jobs_are_ordered(jobs: Array) -> bool:
	for index: int in range(1, jobs.size()):
		var previous: Dictionary = jobs[index - 1] as Dictionary
		var current: Dictionary = jobs[index] as Dictionary
		if int(previous[&"priority"]) < int(current[&"priority"]):
			return false
		if (
			int(previous[&"priority"]) == int(current[&"priority"])
			and int(previous[&"age"]) < int(current[&"age"])
		):
			return false
	return true


static func _revision(farm_runtime: RefCounted) -> int:
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	return int((farm[&"revisions"] as Dictionary)[&"result_revision"])


static func _receipt_count(farm: Dictionary, prefix: String) -> int:
	var count: int = 0
	for entry: Dictionary in farm[&"receipts"][&"entries"] as Array[Dictionary]:
		if str(entry[&"token"]).begins_with(prefix):
			count += 1
	return count


static func _projection_option(projection: Dictionary, operation: StringName) -> Dictionary:
	for option: Dictionary in projection.get(&"option_inputs", []) as Array[Dictionary]:
		if option.get(&"operation", &"") as StringName == operation:
			return option.duplicate(true)
	return {}


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
