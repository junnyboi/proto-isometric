extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const CrossDomainTransactionScript: GDScript = preload("res://scripts/cross_domain_transaction.gd")
const EcologyDirectorScript: GDScript = preload("res://scripts/ecology_director.gd")
const EconomyServiceScript: GDScript = preload("res://scripts/economy_service.gd")
const FarmCapabilityServiceScript: GDScript = preload("res://scripts/farm_capability_service.gd")
const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const HazardCatalogScript: GDScript = preload("res://scripts/hazard_opportunity_catalog.gd")
const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const IronjawArcScript: GDScript = preload("res://scripts/ironjaw_desert_arc.gd")
const LivestockServiceScript: GDScript = preload("res://scripts/livestock_service.gd")
const MachineServiceScript: GDScript = preload("res://scripts/machine_service.gd")
const PeacefulHerdsScript: GDScript = preload("res://scripts/peaceful_herds.gd")
const ProfileStateScript: GDScript = preload("res://scripts/profile_state.gd")
const RelationshipServiceScript: GDScript = preload("res://scripts/relationship_service.gd")
const ResidentServiceScript: GDScript = preload("res://scripts/resident_service.gd")
const RunStateScript: GDScript = preload("res://scripts/run_state.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const RuntimeOwnershipScript: GDScript = preload("res://scripts/runtime_ownership.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")
const LootCatalogScript: GDScript = preload("res://scripts/wilderness_loot_catalog.gd")


class FakeWorld:
	extends RefCounted

	func is_walkable(_cell: Vector2i) -> bool:
		return true

	func _biome_at(_cell: Vector2i) -> StringName:
		return &"desert"


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_registry(cases)
	_test_ecology(cases)
	_test_herds(cases)
	_test_loot_and_capabilities(cases)
	_test_hazards(cases)
	_test_ironjaw(cases)
	_test_expedition_return(cases)
	_test_schema(cases)
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


static func _test_registry(cases: Array[Dictionary]) -> void:
	var contract: Dictionary = RuntimeOwnershipScript.contract_for(RuntimeIdsScript.DOMAIN_ECOLOGY)
	_add(
		cases,
		"PH-30 ecology is an additive stable authority",
		(
			RuntimeIdsScript.REGISTRY_VERSION == 10
			and RuntimeOwnershipScript.validate()
			and contract[&"migration_state"] == RuntimeOwnershipScript.MIGRATION_STABLE
			and RuntimeOwnershipScript.can_mutate(
				RuntimeIdsScript.DOMAIN_ECOLOGY, RuntimeIdsScript.OWNER_ECOLOGY
			)
		),
	)


static func _test_ecology(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	var first: Array[Dictionary] = EcologyDirectorScript.population_snapshot(farm, 91, 12, 600)
	var second: Array[Dictionary] = EcologyDirectorScript.population_snapshot(farm, 91, 12, 600)
	_add(
		cases,
		"PH-30 catalog defines twelve bounded deterministic habitats",
		EcologyDirectorScript.validate_catalog() and first.size() == 12 and first == second,
	)
	var trigger_safe: bool = true
	for habitat: Dictionary in first:
		trigger_safe = trigger_safe and habitat[&"trigger"] == &"habitat_entry"
		trigger_safe = trigger_safe and int(habitat[&"population"]) <= 4
	_add(cases, "PH-30 populations are habitat-entry driven and bounded", trigger_safe)
	var habitat_id: StringName = &"habitat.desert.glass_nest"
	var depleted: Dictionary = EcologyDirectorScript.deplete(farm, habitat_id, 4, 12)
	var empty: Array[Dictionary] = EcologyDirectorScript.population_snapshot(
		depleted[&"candidate"], 91, 13, 600
	)
	var respawned: Array[Dictionary] = EcologyDirectorScript.population_snapshot(
		depleted[&"candidate"], 91, 14, 600
	)
	_add(
		cases,
		"PH-30 depletion and day-based respawn reproduce across reload",
		bool(depleted[&"ok"])
		and _population(empty, habitat_id) == 0
		and _population(respawned, habitat_id) == 4,
	)


static func _test_herds(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	var habitat_id: StringName = &"habitat.desert.dune_herd"
	var first: Dictionary = EcologyDirectorScript.interact_herd(farm, habitat_id, 3)
	var retry: Dictionary = EcologyDirectorScript.interact_herd(first[&"candidate"], habitat_id, 3)
	_add(
		cases,
		"PH-31 friendly herd trust persists and renewable yield is once per day",
		bool(first[&"ok"])
		and bool(first[&"yielded"])
		and bool(retry[&"ok"])
		and not bool(retry[&"yielded"])
		and int(retry[&"trust"]) == 50,
	)
	var herds: Node2D = PeacefulHerdsScript.new() as Node2D
	herds.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, FakeWorld.new())
	herds.call("set_auto_spawn", false)
	herds.call("spawn_herd", Vector2(4.0, 4.0), 1, &"desert")
	var creature_id: int = int((herds.call("get_snapshots") as Array[Dictionary])[0][&"id"])
	_add(
		cases,
		"PH-31 ordinary tools cannot kill friendly fauna",
		not bool(herds.call("hit_creature", creature_id, 99))
		and int(herds.call("get_creature_count")) == 1,
	)
	herds.free()


static func _test_loot_and_capabilities(cases: Array[Dictionary]) -> void:
	var all_useful: bool = LootCatalogScript.validate()
	for entry: Dictionary in LootCatalogScript.DEFINITIONS:
		all_useful = all_useful and not str(entry[&"capability"]).is_empty()
		all_useful = all_useful and LootCatalogScript.routine_value_is_bounded(
			entry[&"item_id"] as StringName
		)
	_add(
		cases,
		"PH-32 every named wilderness material has a bounded farm use",
		all_useful and LootCatalogScript.DEFINITIONS.size() == 17,
	)
	var farm: Dictionary = _fresh_farm()
	for cost: Dictionary in FarmCapabilityServiceScript.UNLOCKS[
		FarmCapabilityServiceScript.WATER_RETENTION
	] as Array[Dictionary]:
		var credited: Dictionary = InventoryServiceScript.credit_with_overflow(
			farm, cost[&"item_id"] as StringName, int(cost[&"count"])
		)
		farm = credited[&"candidate"] as Dictionary
	var unlocked: Dictionary = FarmCapabilityServiceScript.unlock(
		farm, FarmCapabilityServiceScript.WATER_RETENTION
	)
	var duplicate: Dictionary = FarmCapabilityServiceScript.unlock(
		unlocked[&"candidate"], FarmCapabilityServiceScript.WATER_RETENTION
	)
	_add(
		cases,
		"PH-32 wilderness materials unlock one exact farm capability",
		bool(unlocked[&"ok"])
		and FarmCapabilityServiceScript.has(
			unlocked[&"candidate"], FarmCapabilityServiceScript.WATER_RETENTION
		)
		and not bool(duplicate[&"ok"]),
	)


static func _test_hazards(cases: Array[Dictionary]) -> void:
	var deterministic: bool = true
	for biome: StringName in [&"desert", &"oasis", &"frozen", &"lava"]:
		var first: Dictionary = HazardCatalogScript.forecast(biome, Vector2i(8, 9), 14, 91)
		var second: Dictionary = HazardCatalogScript.forecast(biome, Vector2i(8, 9), 14, 91)
		deterministic = deterministic and first == second and not first.is_empty()
		var kind: StringName = first[&"kind"] as StringName
		deterministic = deterministic and HazardCatalogScript.mitigated_damage(kind, 9, true) < 9
		deterministic = deterministic and HazardCatalogScript.can_stabilize(
			kind, float(first[&"stabilize_from"]), true
		)
	_add(
		cases,
		"PH-33 all four deep-biome opportunities forecast, telegraph, mitigate, and stabilize",
		HazardCatalogScript.validate() and deterministic,
	)
	var farm: Dictionary = _fresh_farm()
	var claimed: Dictionary = FarmCapabilityServiceScript.claim_hazard_reward(
		farm, "hazard:quicksand_collapse:8,9", &"item.hazard.silica_loam", 1
	)
	var duplicate: Dictionary = FarmCapabilityServiceScript.claim_hazard_reward(
		claimed[&"candidate"], "hazard:quicksand_collapse:8,9", &"item.hazard.silica_loam", 1
	)
	_add(
		cases,
		"PH-33 stabilized hazard rewards are exact once",
		bool(claimed[&"ok"])
		and InventoryServiceScript.count_all(
			claimed[&"candidate"], &"item.hazard.silica_loam"
		)
		== 1
		and not bool(duplicate[&"ok"]),
	)


static func _test_ironjaw(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	var locked: Dictionary = IronjawArcScript.complete_first_clear(farm)
	for request: Dictionary in (farm[&"homestead"] as Dictionary)[&"requests"] as Array[Dictionary]:
		if StringName(str(request[&"request_id"])) == RuntimeIdsScript.REQUEST_ROOK_ID:
			request[&"status"] = "completed"
			request[&"completed_day"] = 1
	var clear: Dictionary = IronjawArcScript.complete_first_clear(farm)
	var duplicate: Dictionary = IronjawArcScript.complete_first_clear(clear[&"candidate"])
	_add(
		cases,
		"PH-34 Ironjaw lair is quest-gated and exposes a safe exit",
		not bool(locked[&"ok"])
		and IronjawArcScript.definition()[&"safe_exit"] == IronjawArcScript.SAFE_EXIT
		and IronjawArcScript.lair_cells().size() > 32,
	)
	_add(
		cases,
		"PH-34 first clear grants one Burrow Core and farm-changing capabilities",
		bool(clear[&"ok"])
		and InventoryServiceScript.count_all(clear[&"candidate"], IronjawArcScript.BURROW_CORE_ITEM)
		== 1
		and FarmCapabilityServiceScript.has(
			clear[&"candidate"], FarmCapabilityServiceScript.DEEP_TILLING
		)
		and FarmCapabilityServiceScript.has(clear[&"candidate"], FarmCapabilityServiceScript.WELL)
		and IronjawArcScript.deep_tillable(
			clear[&"candidate"], IronjawArcScript.DEEP_TILL_CELLS[0]
		)
		and not bool(duplicate[&"ok"]),
	)


static func _test_expedition_return(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	var wood_before: int = InventoryServiceScript.count_all(farm, &"item.material.wood")
	var run: RefCounted = RunStateScript.new() as RefCounted
	run.call("configure", &"run.phase6.return", 91, 20, Vector2i(0, 42), &"S")
	run.call("transition_to", RuntimeIdsScript.RUN_PHASE_HUNT)
	run.call("transition_to", RuntimeIdsScript.RUN_PHASE_EXTRACTION_READY)
	run.call("set_value", &"scrap", 7)
	run.call("set_value", &"worm_cores", 2)
	var profile: RefCounted = ProfileStateScript.new() as RefCounted
	var source: Dictionary = {
		&"save_format_version": 4,
		&"metadata": {},
		&"world": {
			&"destroyed_rocks": [],
			&"placed_rocks": [],
			&"dropped_scrap": [],
			&"collected_scrap": [],
		},
		&"active_run": run.call("to_dictionary"),
		&"profile": profile.call("to_dictionary"),
		&"farm": farm,
	}
	var transaction: RefCounted = CrossDomainTransactionScript.new() as RefCounted
	var returned: Dictionary = transaction.call(
		"_build",
		source,
		&"expedition_return",
		{
			&"cargo": [{&"item_id": &"item.wild.glass_chitin", &"count": 1}],
			&"activate_ruin_id": &"ruin.remote.desert.sunken_crown",
		},
	) as Dictionary
	var candidate: Dictionary = returned.get(&"candidate", {}) as Dictionary
	var retry: Dictionary = transaction.call(
		"_build", candidate, &"expedition_return", {&"cargo": []}
	) as Dictionary
	var returned_farm: Dictionary = candidate.get(&"farm", {}) as Dictionary
	_add(
		cases,
		"PH-35 expedition return atomically deposits cargo without touching home inventory",
		bool(returned[&"ok"])
		and InventoryServiceScript.count_all(returned_farm, &"item.material.scrap") >= 7
		and InventoryServiceScript.count_all(returned_farm, &"item.monster.worm_core") >= 2
		and InventoryServiceScript.count_all(returned_farm, &"item.wild.glass_chitin") == 1
		and InventoryServiceScript.count_all(returned_farm, &"item.material.wood") == wood_before
		and EcologyDirectorScript.has_token(
			returned_farm, "ruin:ruin.remote.desert.sunken_crown:activated"
		),
	)
	_add(
		cases,
		"PH-35 expedition return and remote ruin activation cannot duplicate",
		not bool(retry[&"ok"]),
	)


static func _test_schema(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	var token: Dictionary = EcologyDirectorScript.add_token(farm, "ruin:remote.desert:activated")
	var validated: Dictionary = FarmSaveSchemaScript.validate(token[&"candidate"])
	var malformed: Dictionary = (token[&"candidate"] as Dictionary).duplicate(true)
	((malformed[&"ecology"] as Dictionary)[&"deltas"] as Array).append(
		((malformed[&"ecology"] as Dictionary)[&"deltas"] as Array)[0].duplicate(true)
	)
	_add(
		cases,
		"PH-30/35 ecology tokens persist canonically and duplicates are rejected",
		bool(token[&"ok"])
		and not validated.is_empty()
		and FarmSaveSchemaScript.validate(malformed).is_empty(),
	)


static func _population(records: Array[Dictionary], habitat_id: StringName) -> int:
	for record: Dictionary in records:
		if record[&"habitat_id"] == habitat_id:
			return int(record[&"population"])
	return -1


static func _add(cases: Array[Dictionary], name: String, passed: bool) -> void:
	cases.append({&"name": name, &"passed": passed})
