extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const CrossDomainTransactionScript: GDScript = preload("res://scripts/cross_domain_transaction.gd")
const EconomyServiceScript: GDScript = preload("res://scripts/economy_service.gd")
const FarmRuntimeScript: GDScript = preload("res://scripts/harvest_farm_runtime.gd")
const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const LivestockServiceScript: GDScript = preload("res://scripts/livestock_service.gd")
const MachineServiceScript: GDScript = preload("res://scripts/machine_service.gd")
const RelationshipServiceScript: GDScript = preload("res://scripts/relationship_service.gd")
const ResidentServiceScript: GDScript = preload("res://scripts/resident_service.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const RuntimeOwnershipScript: GDScript = preload("res://scripts/runtime_ownership.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")


class CommitProbe:
	extends RefCounted

	var accept: bool = true
	var commits: int = 0
	var last_candidate: Dictionary = {}

	func commit(candidate: Dictionary) -> bool:
		if not accept:
			return false
		commits += 1
		last_candidate = candidate.duplicate(true)
		return true


class RepositoryProbe:
	extends RefCounted

	var saves: int = 0
	var last_farm: Dictionary = {}

	func validate_envelope(envelope: Dictionary) -> Dictionary:
		var candidate: Dictionary = envelope.duplicate(true)
		var farm: Dictionary = FarmSaveSchemaScript.validate(candidate.get(&"farm", {}))
		if farm.is_empty():
			return {}
		candidate[&"farm"] = farm
		return candidate

	func save_state(
		_world: Dictionary, _active_run: Variant, _profile: Dictionary, farm: Dictionary
	) -> bool:
		saves += 1
		last_farm = farm.duplicate(true)
		return true


static func evaluate(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_registry_and_definitions(cases)
	_test_schema(cases)
	_test_facilities(cases)
	_test_residents(cases)
	_test_relationships(cases)
	_test_livestock(cases)
	_test_reload(cases)
	_test_transaction_dispatch(cases)
	_test_live_boundary(cases, runtime)
	return cases


static func _fresh_farm() -> Dictionary:
	var farm: Dictionary = FarmSaveSchemaScript.make_neutral(RuntimeIdsScript.MODE_FRESH_FARM)
	farm = InventoryServiceScript.ensure_default(farm)
	farm = CalendarStateScript.ensure_default(farm, 77)
	farm = ToolServiceScript.ensure_default(farm)
	farm = EconomyServiceScript.ensure_default(farm)
	farm = MachineServiceScript.ensure_default(farm)
	farm = HomesteadServiceScript.ensure_default(farm)
	farm = ResidentServiceScript.ensure_default(farm)
	farm = RelationshipServiceScript.ensure_default(farm)
	farm = LivestockServiceScript.ensure_default(farm)
	return FarmSaveSchemaScript.validate(farm)


static func _test_registry_and_definitions(cases: Array[Dictionary]) -> void:
	var contract: Dictionary = RuntimeOwnershipScript.contract_for(
		RuntimeIdsScript.DOMAIN_HOMESTEAD_SETTLEMENT
	)
	_add(
		cases,
		"Phase 5 homestead authority and additive registry IDs are stable",
		(
			RuntimeIdsScript.REGISTRY_VERSION == 9
			and contract[&"migration_state"] == RuntimeOwnershipScript.MIGRATION_STABLE
			and RuntimeOwnershipScript.can_mutate(
				RuntimeIdsScript.DOMAIN_HOMESTEAD_SETTLEMENT,
				RuntimeIdsScript.OWNER_HOMESTEAD_SETTLEMENT,
			)
			and RuntimeIdsScript.LIVESTOCK_MOSSBACK_ID == &"livestock.mossback_grazer"
			and RuntimeIdsScript.LIVESTOCK_COILHEN_ID == &"livestock.coilhen"
			and RuntimeIdsScript.LIVESTOCK_RUSTSNOUT_ID == &"livestock.rustsnout_rooter"
		),
	)
	_add(
		cases,
		"Phase 5 facility resident relationship livestock and item definitions are strict",
		(
			HomesteadServiceScript.validate_definitions()
			and ResidentServiceScript.validate_definitions()
			and RelationshipServiceScript.validate_definitions()
			and LivestockServiceScript.validate_definitions()
			and ItemCatalogScript.validate()
		),
	)


static func _test_schema(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	var serialized: String = FarmSaveSchemaScript.canonical_json(farm)
	var roundtrip: Dictionary = FarmSaveSchemaScript.validate(JSON.parse_string(serialized))
	_add(
		cases,
		"Phase 5 active homestead schema round-trips canonically and detached",
		(
			not farm.is_empty()
			and roundtrip == farm
			and serialized == FarmSaveSchemaScript.canonical_json(roundtrip)
		),
	)
	var unknown: Dictionary = farm.duplicate(true)
	((unknown[&"homestead"] as Dictionary)[&"home"] as Dictionary)[&"future"] = true
	var duplicate: Dictionary = farm.duplicate(true)
	var facilities: Array = (duplicate[&"homestead"] as Dictionary)[&"facilities"] as Array
	facilities.append((facilities[0] as Dictionary).duplicate(true))
	var bad_coordinate: Dictionary = farm.duplicate(true)
	var bad_facilities: Array = (bad_coordinate[&"homestead"] as Dictionary)[&"facilities"]
	(bad_facilities[0] as Dictionary)[&"cell"] = [1_000_001, 0]
	_add(
		cases,
		"Phase 5 schema rejects unknown keys duplicates and out-of-range coordinates",
		(
			FarmSaveSchemaScript.validate(unknown).is_empty()
			and FarmSaveSchemaScript.validate(duplicate).is_empty()
			and FarmSaveSchemaScript.validate(bad_coordinate).is_empty()
		),
	)
	var capped: Dictionary = farm.duplicate(true)
	var animals: Array = []
	var template: Dictionary = {
		&"animal_id": "animal.cap.00",
		&"species_id": String(LivestockServiceScript.MOSSBACK_ID),
		&"housing_id": "housing.home_paddock",
		&"bond": 0,
		&"last_feed_day": 0,
		&"last_pet_day": 0,
		&"last_product_day": 0,
		&"care_tokens": [],
	}
	for index: int in FarmSaveSchemaScript.MAX_ANIMALS:
		var record: Dictionary = template.duplicate(true)
		record[&"animal_id"] = "animal.cap.%02d" % index
		animals.append(record)
	(capped[&"homestead"] as Dictionary)[&"animals"] = animals
	var oversized: Dictionary = capped.duplicate(true)
	var extra: Dictionary = template.duplicate(true)
	extra[&"animal_id"] = "animal.cap.extra"
	((oversized[&"homestead"] as Dictionary)[&"animals"] as Array).append(extra)
	_add(
		cases,
		"Phase 5 animal records accept exactly the twelve-record cap and reject thirteen",
		(
			not FarmSaveSchemaScript.validate(capped).is_empty()
			and FarmSaveSchemaScript.validate(oversized).is_empty()
		),
	)


static func _test_facilities(cases: Array[Dictionary]) -> void:
	var all_exact: bool = true
	for facility_id: StringName in HomesteadServiceScript.FACILITY_IDS:
		var farm: Dictionary = _fresh_farm()
		var definition_value: Dictionary = HomesteadServiceScript.definition(facility_id)
		farm = _credit_materials(farm, definition_value[&"repair_materials"])
		var before: Dictionary = farm.duplicate(true)
		var repaired: Dictionary = HomesteadServiceScript.repair(farm, facility_id)
		var repaired_farm: Dictionary = repaired[&"candidate"] as Dictionary
		var duplicate: Dictionary = HomesteadServiceScript.repair(repaired_farm, facility_id)
		var premature: Dictionary = HomesteadServiceScript.power(repaired_farm, facility_id)
		_add_upgrade(repaired_farm, HomesteadServiceScript.SAFEHOUSE_POWER_UPGRADE)
		repaired_farm = _credit_materials(repaired_farm, definition_value[&"power_materials"])
		var powered: Dictionary = HomesteadServiceScript.power(repaired_farm, facility_id)
		var powered_farm: Dictionary = powered[&"candidate"] as Dictionary
		var state_value: Dictionary = HomesteadServiceScript.facility_state(powered_farm, facility_id)
		var ruin: Dictionary = _ruin_for(powered_farm, facility_id)
		all_exact = (
			all_exact
			and bool(repaired[&"ok"])
			and repaired[&"candidate"] != before
			and not bool(duplicate[&"ok"])
			and duplicate[&"reason"] == &"facility_already_repaired"
			and not bool(premature[&"ok"])
			and bool(powered[&"ok"])
			and state_value[&"repair_token"] == "repair:%s" % facility_id
			and state_value[&"power_token"] == "power:%s" % facility_id
			and bool(ruin[&"repaired"])
			and bool(ruin[&"powered"])
		)
	_add(cases, "All three facilities consume exact materials and synchronize ruins", all_exact)
	var services: Dictionary = HomesteadServiceScript.home_services(_fresh_farm())
	_add(
		cases,
		"Starting home exposes exact bed storage safehouse and animal capacity",
		(
			bool(services[&"bed"])
			and bool(services[&"storage"])
			and bool(services[&"safehouse"])
			and int(services[&"animal_capacity"]) == HomesteadServiceScript.HOME_CAPACITY
		),
	)


static func _test_residents(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	farm = _activate_all_facilities(farm)
	var calendar: Dictionary = farm[&"calendar_weather"] as Dictionary
	calendar[&"day"] = 3
	farm[&"calendar_weather"] = calendar
	var arrivals: Dictionary = ResidentServiceScript.reconcile_arrivals(farm)
	var arrived: Dictionary = arrivals[&"candidate"] as Dictionary
	var all_arrived: bool = true
	for resident_id: StringName in ResidentServiceScript.RESIDENT_IDS:
		all_arrived = all_arrived and bool(ResidentServiceScript.state(arrived, resident_id)[&"arrived"])
	_add(
		cases,
		"Exactly Lyra Rook and Mira arrive only after powered facilities and day thresholds",
		bool(arrivals[&"ok"]) and all_arrived and ResidentServiceScript.RESIDENT_IDS.size() == 3,
	)
	var blocked: Dictionary = _fresh_farm()
	(blocked[&"calendar_weather"] as Dictionary)[&"day"] = 14
	var no_arrivals: Dictionary = ResidentServiceScript.reconcile_arrivals(blocked)
	_add(
		cases,
		"Resident day thresholds never bypass repair and power gates",
		not bool(no_arrivals[&"ok"]) and no_arrivals[&"candidate"] == blocked,
	)
	var clear_a: Array[Dictionary] = ResidentServiceScript.schedule_snapshot(arrived, 720)
	var clear_b: Array[Dictionary] = ResidentServiceScript.schedule_snapshot(arrived, 720)
	(arrived[&"calendar_weather"] as Dictionary)[&"current_weather_id"] = "weather.rain"
	var rain: Array[Dictionary] = ResidentServiceScript.schedule_snapshot(arrived, 720)
	clear_a[0][&"cell"] = Vector2i(99, 99)
	var detached: Array[Dictionary] = ResidentServiceScript.schedule_snapshot(arrived, 720)
	_add(
		cases,
		"Clear and rain schedules are deterministic bounded and detached",
		(
			clear_b.size() == 3
			and rain.size() == 3
			and clear_b != rain
			and detached[0][&"cell"] != Vector2i(99, 99)
		),
	)
	var collision: Array[Dictionary] = ResidentServiceScript.schedule_snapshot(
		arrived, 720, func(cell: Vector2i) -> bool: return cell.x not in [10, 13, 6]
	)
	_add(
		cases,
		"Blocked schedule cells use collision-safe deterministic fallbacks",
		collision.size() == 3 and _unique_cells(collision),
	)


static func _test_relationships(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _arrived_farm(ResidentServiceScript.LYRA_ID)
	farm = _credit(farm, &"item.produce.rainleaf", 2)
	var talked: Dictionary = RelationshipServiceScript.talk(farm, ResidentServiceScript.LYRA_ID)
	var after_talk: Dictionary = talked[&"candidate"] as Dictionary
	var repeated_talk: Dictionary = RelationshipServiceScript.talk(
		after_talk, ResidentServiceScript.LYRA_ID
	)
	var gifted: Dictionary = RelationshipServiceScript.gift(
		after_talk, ResidentServiceScript.LYRA_ID, &"item.produce.rainleaf"
	)
	var after_gift: Dictionary = gifted[&"candidate"] as Dictionary
	var repeated_gift: Dictionary = RelationshipServiceScript.gift(
		after_gift, ResidentServiceScript.LYRA_ID, &"item.produce.rainleaf"
	)
	_add(
		cases,
		"Talk and gift are separately tokenized exactly once per resident per day",
		(
			bool(talked[&"ok"])
			and not bool(repeated_talk[&"ok"])
			and bool(gifted[&"ok"])
			and not bool(repeated_gift[&"ok"])
			and RelationshipServiceScript.relationship(
				after_gift, ResidentServiceScript.LYRA_ID
			)[&"interaction_tokens"].size() == 2
		),
	)
	var board: Array[Dictionary] = RelationshipServiceScript.board(after_gift)
	var money_before: int = int((after_gift[&"economy"] as Dictionary)[&"money"])
	var completed: Dictionary = RelationshipServiceScript.complete_request(
		after_gift, RuntimeIdsScript.REQUEST_LYRA_ID
	)
	var completed_farm: Dictionary = completed[&"candidate"] as Dictionary
	var repeated: Dictionary = RelationshipServiceScript.complete_request(
		completed_farm, RuntimeIdsScript.REQUEST_LYRA_ID
	)
	_add(
		cases,
		"Three deterministic requests lock at exact thresholds and reward exactly once",
		(
			RelationshipServiceScript.REQUEST_IDS.size() == 3
			and board.size() == 1
			and bool(completed[&"ok"])
			and not bool(repeated[&"ok"])
			and int((completed_farm[&"economy"] as Dictionary)[&"money"]) == money_before + 120
			and RuntimeIdsScript.REQUEST_LYRA_ID in RelationshipServiceScript.relationship(
				completed_farm, ResidentServiceScript.LYRA_ID
			)[&"completed_request_ids"]
		),
	)
	var invalid: Dictionary = RelationshipServiceScript.gift(
		farm, &"resident.unknown", &"item.unknown"
	)
	var invalid_request: Dictionary = RelationshipServiceScript.complete_request(
		farm, &"request.unknown"
	)
	_add(
		cases,
		"Unknown resident item and request IDs are rejected without mutation",
		not bool(invalid[&"ok"]) and invalid[&"candidate"] == farm and not bool(invalid_request[&"ok"]),
	)


static func _test_livestock(cases: Array[Dictionary]) -> void:
	var definitions_exact: bool = true
	var species_index: int = 0
	for species_id: StringName in LivestockServiceScript.SPECIES_IDS:
		var definition_value: Dictionary = LivestockServiceScript.definition(species_id)
		var hook: Dictionary = LivestockServiceScript.presentation_hook(species_id)
		definitions_exact = (
			definitions_exact
			and str(definition_value[&"display_name"])
			in ["Mossback Grazer", "Coilhen", "Rustsnout Rooter"]
			and hook[&"atlas_columns"] == 4
			and hook[&"atlas_rows"] == 2
			and hook[&"frame_size"] == Vector2i(256, 256)
			and bool(hook[&"available"])
		)
		var farm: Dictionary = _fresh_farm()
		if definition_value[&"housing_id"] == &"housing.greenhouse_coop":
			var gated: Dictionary = LivestockServiceScript.add_animal(
				farm, &"animal.gated", species_id, definition_value[&"housing_id"]
			)
			definitions_exact = definitions_exact and not bool(gated[&"ok"])
			farm = _activate_facility(farm, HomesteadServiceScript.GREENHOUSE_ID)
		farm = _credit(farm, definition_value[&"feed_item_id"], 1)
		var animal_id: StringName = StringName("animal.test.%d" % species_index)
		var added: Dictionary = LivestockServiceScript.add_animal(
			farm, animal_id, species_id, definition_value[&"housing_id"]
		)
		var added_farm: Dictionary = added[&"candidate"] as Dictionary
		var fed: Dictionary = LivestockServiceScript.feed(added_farm, animal_id)
		var fed_farm: Dictionary = fed[&"candidate"] as Dictionary
		var duplicate_feed: Dictionary = LivestockServiceScript.feed(fed_farm, animal_id)
		var petted: Dictionary = LivestockServiceScript.pet(fed_farm, animal_id)
		var petted_farm: Dictionary = petted[&"candidate"] as Dictionary
		var product: Dictionary = LivestockServiceScript.claim_product(petted_farm, animal_id)
		var product_farm: Dictionary = product[&"candidate"] as Dictionary
		var duplicate_product: Dictionary = LivestockServiceScript.claim_product(
			product_farm, animal_id
		)
		definitions_exact = (
			definitions_exact
			and bool(added[&"ok"])
			and bool(fed[&"ok"])
			and not bool(duplicate_feed[&"ok"])
			and bool(petted[&"ok"])
			and bool(product[&"ok"])
			and not bool(duplicate_product[&"ok"])
			and InventoryServiceScript.count_all(
				product_farm, definition_value[&"product_item_id"]
			) == int(product[&"yield"])
		)
		species_index += 1
	_add(
		cases,
		"All three final livestock definitions assets care tokens and yields are exact",
		definitions_exact,
	)
	var capacity_farm: Dictionary = _fresh_farm()
	var one: Dictionary = LivestockServiceScript.add_animal(
		capacity_farm,
		&"animal.moss",
		LivestockServiceScript.MOSSBACK_ID,
		&"housing.home_paddock",
	)
	var two: Dictionary = LivestockServiceScript.add_animal(
		one[&"candidate"],
		&"animal.rust",
		LivestockServiceScript.RUSTSNOUT_ID,
		&"housing.home_rooter_pen",
	)
	_add(
		cases,
		"Livestock service enforces home capacity duplicate and greenhouse housing gates",
		bool(one[&"ok"]) and not bool(two[&"ok"]),
	)


static func _test_reload(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _arrived_farm(ResidentServiceScript.LYRA_ID)
	farm = _credit(farm, &"item.produce.rainleaf", 2)
	farm = RelationshipServiceScript.talk(farm, ResidentServiceScript.LYRA_ID)[&"candidate"]
	farm = RelationshipServiceScript.gift(
		farm, ResidentServiceScript.LYRA_ID, &"item.produce.rainleaf"
	)[&"candidate"]
	farm = RelationshipServiceScript.complete_request(
		farm, RuntimeIdsScript.REQUEST_LYRA_ID
	)[&"candidate"]
	farm = _credit(farm, &"item.feed.mossgrass_fodder", 1)
	farm = LivestockServiceScript.add_animal(
		farm,
		&"animal.reload",
		LivestockServiceScript.MOSSBACK_ID,
		&"housing.home_paddock",
	)[&"candidate"]
	farm = LivestockServiceScript.feed(farm, &"animal.reload")[&"candidate"]
	farm = LivestockServiceScript.pet(farm, &"animal.reload")[&"candidate"]
	farm = LivestockServiceScript.claim_product(farm, &"animal.reload")[&"candidate"]
	var encoded: String = FarmSaveSchemaScript.canonical_json(farm)
	var reloaded: Dictionary = FarmSaveSchemaScript.validate(JSON.parse_string(encoded))
	_add(
		cases,
		"Canonical Phase 5 state is reload-safe with exact-once histories intact",
		(
			not reloaded.is_empty()
			and encoded == FarmSaveSchemaScript.canonical_json(reloaded)
			and not bool(RelationshipServiceScript.complete_request(
				reloaded, RuntimeIdsScript.REQUEST_LYRA_ID
			)[&"ok"])
			and not bool(LivestockServiceScript.claim_product(reloaded, &"animal.reload")[&"ok"])
		),
	)


static func _test_transaction_dispatch(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	var definition_value: Dictionary = HomesteadServiceScript.definition(
		HomesteadServiceScript.GREENHOUSE_ID
	)
	farm = _credit_materials(farm, definition_value[&"repair_materials"])
	var source: Dictionary = {
		&"save_format_version": 4,
		&"metadata": {},
		&"world": {},
		&"active_run": null,
		&"profile": {},
		&"farm": farm,
	}
	var repository: RepositoryProbe = RepositoryProbe.new()
	var transaction: RefCounted = CrossDomainTransactionScript.new() as RefCounted
	var configured: bool = bool(
		transaction.call("configure", source, repository, repository, Callable(), 77)
	)
	var repaired: Dictionary = transaction.call(
		"transact",
		&"facility_repair",
		{&"facility_id": HomesteadServiceScript.GREENHOUSE_ID},
	) as Dictionary
	_add(
		cases,
		"Phase 5 transaction dispatch persists homestead mutations through one boundary",
		(
			configured
			and bool(repaired[&"ok"])
			and repository.saves == 1
			and bool(HomesteadServiceScript.facility_state(
				repository.last_farm, HomesteadServiceScript.GREENHOUSE_ID
			)[&"repaired"])
		),
	)


static func _test_live_boundary(cases: Array[Dictionary], runtime: Node2D) -> void:
	var bridge: Node = runtime.get_node_or_null("HarvestPhaseTwo")
	var farm_runtime: RefCounted = (
		bridge.call("get_farm_runtime") as RefCounted if bridge != null else null
	)
	var boundary: RefCounted = (
		bridge.call("get_transaction_boundary") as RefCounted if bridge != null else null
	)
	var result: Dictionary = (
		farm_runtime.call(
			"transact",
			&"animal_add",
			{
				&"animal_id": &"animal.live",
				&"species_id": LivestockServiceScript.MOSSBACK_ID,
				&"housing_id": &"housing.home_paddock",
			},
		) as Dictionary
		if farm_runtime != null
		else {}
	)
	var boundary_farm: Dictionary = (
		(boundary.call("get_snapshot") as Dictionary).get(&"farm", {}) as Dictionary
		if boundary != null
		else {}
	)
	_add(
		cases,
		"Live Phase 5 operation reaches the configured cross-domain farm boundary",
		bool(result.get(&"ok", false)) and _has_animal(boundary_farm, &"animal.live"),
	)


static func _activate_all_facilities(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	for facility_id: StringName in HomesteadServiceScript.FACILITY_IDS:
		candidate = _activate_facility(candidate, facility_id)
	return candidate


static func _activate_facility(farm: Dictionary, facility_id: StringName) -> Dictionary:
	var definition_value: Dictionary = HomesteadServiceScript.definition(facility_id)
	var candidate: Dictionary = _credit_materials(farm, definition_value[&"repair_materials"])
	candidate = HomesteadServiceScript.repair(candidate, facility_id)[&"candidate"]
	_add_upgrade(candidate, HomesteadServiceScript.SAFEHOUSE_POWER_UPGRADE)
	candidate = _credit_materials(candidate, definition_value[&"power_materials"])
	return HomesteadServiceScript.power(candidate, facility_id)[&"candidate"]


static func _arrived_farm(resident_id: StringName) -> Dictionary:
	var farm: Dictionary = _fresh_farm()
	var definition_value: Dictionary = ResidentServiceScript.definition(resident_id)
	farm = _activate_facility(farm, definition_value[&"facility_id"])
	var calendar: Dictionary = farm[&"calendar_weather"] as Dictionary
	calendar[&"day"] = int(definition_value[&"arrival_day"])
	farm[&"calendar_weather"] = calendar
	return ResidentServiceScript.reconcile_arrivals(farm)[&"candidate"]


static func _credit_materials(farm: Dictionary, materials: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	for raw_item_id: Variant in materials:
		candidate = _credit(
			candidate, StringName(str(raw_item_id)), int(materials[raw_item_id])
		)
	return candidate


static func _credit(farm: Dictionary, item_id: StringName, count: int) -> Dictionary:
	var result: Dictionary = InventoryServiceScript.credit_with_overflow(farm, item_id, count)
	return result[&"candidate"] as Dictionary if bool(result[&"ok"]) else farm.duplicate(true)


static func _add_upgrade(farm: Dictionary, upgrade_id: StringName) -> void:
	var tools: Dictionary = farm[&"tools"] as Dictionary
	var upgrades: Array = (tools[&"upgrade_ids"] as Array).duplicate()
	if String(upgrade_id) not in upgrades:
		upgrades.append(String(upgrade_id))
		upgrades.sort()
	tools[&"upgrade_ids"] = upgrades
	farm[&"tools"] = tools


static func _ruin_for(farm: Dictionary, facility_id: StringName) -> Dictionary:
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	for ruin: Dictionary in homestead[&"ruins"] as Array[Dictionary]:
		if StringName(ruin[&"facility_id"]) == facility_id:
			return ruin.duplicate(true)
	return {}


static func _unique_cells(schedules: Array[Dictionary]) -> bool:
	var seen: Dictionary = {}
	for schedule: Dictionary in schedules:
		if seen.has(schedule[&"cell"]):
			return false
		seen[schedule[&"cell"]] = true
	return true


static func _has_animal(farm: Dictionary, animal_id: StringName) -> bool:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	for animal: Dictionary in homestead.get(&"animals", []) as Array[Dictionary]:
		if StringName(animal[&"animal_id"]) == animal_id:
			return true
	return false


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
