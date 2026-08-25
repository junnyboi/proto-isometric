extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const CrossDomainTransactionScript: GDScript = preload("res://scripts/cross_domain_transaction.gd")
const DayAdvanceServiceScript: GDScript = preload("res://scripts/day_advance_service.gd")
const DurableUpgradeCatalogScript: GDScript = preload("res://scripts/durable_upgrade_catalog.gd")
const DurableUpgradeServiceScript: GDScript = preload("res://scripts/durable_upgrade_service.gd")
const EconomyServiceScript: GDScript = preload("res://scripts/economy_service.gd")
const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const MachineServiceScript: GDScript = preload("res://scripts/machine_service.gd")
const RecipeCatalogScript: GDScript = preload("res://scripts/recipe_catalog.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const RuntimeOwnershipScript: GDScript = preload("res://scripts/runtime_ownership.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")
const VisualCatalogScript: GDScript = preload("res://scripts/visual_catalog.gd")
const WorldMutationLedgerScript: GDScript = preload("res://scripts/world_mutation_ledger.gd")


class RepositoryProbe:
	extends RefCounted

	var accept: bool = true
	var saves: int = 0
	var last_saved: Dictionary = {}

	func validate_envelope(envelope: Dictionary) -> Dictionary:
		return envelope.duplicate(true)

	func save_state(
		world: Dictionary, active_run: Variant, profile: Dictionary, farm: Dictionary
	) -> bool:
		if not accept:
			return false
		saves += 1
		last_saved = {
			&"save_format_version": 4,
			&"metadata": {},
			&"world": world.duplicate(true),
			&"active_run": active_run.duplicate(true) if active_run is Dictionary else active_run,
			&"profile": profile.duplicate(true),
			&"farm": farm.duplicate(true),
		}
		return true


class PublisherProbe:
	extends RefCounted

	var fail_once: bool = false
	var calls: int = 0
	var current: Dictionary = {}

	func publish(envelope: Dictionary) -> bool:
		calls += 1
		if fail_once:
			fail_once = false
			return false
		current = envelope.duplicate(true)
		return true


static func evaluate(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_authority_registry(cases)
	_test_mutation_ledger(cases)
	_test_transaction_rollback(cases)
	_test_recipes_and_machines(cases)
	_test_upgrades(cases)
	_test_bounds_and_soak(cases)
	_test_assets(cases)
	_test_live_boundary(cases, runtime)
	return cases


static func _fresh_farm() -> Dictionary:
	var farm: Dictionary = FarmSaveSchemaScript.make_neutral(RuntimeIdsScript.MODE_FRESH_FARM)
	farm = InventoryServiceScript.ensure_default(farm)
	farm = CalendarStateScript.ensure_default(farm, 77)
	farm = ToolServiceScript.ensure_default(farm)
	farm = EconomyServiceScript.ensure_default(farm)
	farm = MachineServiceScript.ensure_default(farm)
	return FarmSaveSchemaScript.validate(farm)


static func _source_envelope(farm: Dictionary) -> Dictionary:
	return {
		&"save_format_version": 4,
		&"metadata": {},
		&"world": {
			&"destroyed_rocks": [],
			&"placed_rocks": [],
			&"dropped_scrap": [],
			&"collected_scrap": [],
		},
		&"active_run": null,
		&"profile": {},
		&"farm": farm.duplicate(true),
	}


static func _test_authority_registry(cases: Array[Dictionary]) -> void:
	_add(
		cases,
		"PH-20/22/23 runtime registry owns all new authoritative domains",
		(
			RuntimeIdsScript.REGISTRY_VERSION == 10
			and RuntimeOwnershipScript.validate()
			and (
				RuntimeOwnershipScript.owner_for(RuntimeIdsScript.DOMAIN_WORLD_MUTATIONS)
				== RuntimeIdsScript.OWNER_WORLD_MUTATION_LEDGER
			)
			and (
				RuntimeOwnershipScript.owner_for(RuntimeIdsScript.DOMAIN_CRAFTING_MACHINES)
				== RuntimeIdsScript.OWNER_CRAFTING_MACHINES
			)
			and (
				RuntimeOwnershipScript.owner_for(RuntimeIdsScript.DOMAIN_DURABLE_UPGRADES)
				== RuntimeIdsScript.OWNER_DURABLE_UPGRADES
			)
		),
	)


static func _test_mutation_ledger(cases: Array[Dictionary]) -> void:
	var empty: Dictionary = {&"cleared": [], &"placed": []}
	var one_cell: Array[Vector2i] = [Vector2i.ZERO]
	var two_cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0)]
	var tree: Dictionary = WorldMutationLedgerScript.make_placed(
		&"object.tree", Vector2i(9, 9), two_cells, -1
	)
	var placed: Dictionary = WorldMutationLedgerScript.place(empty, tree)
	var overlap: Dictionary = WorldMutationLedgerScript.place(
		placed[&"candidate"],
		WorldMutationLedgerScript.make_placed(
			&"structure.storage", Vector2i(10, 9), one_cell
		),
	)
	var duplicate: Dictionary = WorldMutationLedgerScript.place(placed[&"candidate"], tree)
	_add(
		cases,
		"PH-20 stable IDs reject duplicate and overlapping footprints",
		bool(placed[&"ok"]) and not bool(overlap[&"ok"]) and not bool(duplicate[&"ok"]),
	)
	var out_of_bounds: Dictionary = WorldMutationLedgerScript.make_cleared(
		&"object.resource", Vector2i(WorldMutationLedgerScript.MAX_COORDINATE + 1, 0)
	)
	_add(
		cases,
		"PH-20 mutation coordinates and values are strictly bounded",
		(
			WorldMutationLedgerScript.validate(
				{&"cleared": [out_of_bounds], &"placed": []}
			).is_empty()
			and WorldMutationLedgerScript.validate(
				{
					&"cleared": [
						WorldMutationLedgerScript.make_cleared(
							&"object.resource", Vector2i.ZERO, WorldMutationLedgerScript.MAX_DELTA_VALUE + 1
						)
					],
					&"placed": [],
				}
			).is_empty()
		),
	)
	var legacy_world: Dictionary = {
		&"destroyed_rocks": [[-2, 3]],
		&"placed_rocks": [[4, -5]],
		&"dropped_scrap": [{&"cell": [7, 8], &"amount": 2}],
		&"collected_scrap": [[9, 10]],
	}
	var legacy_ledger: Dictionary = WorldMutationLedgerScript.from_legacy(legacy_world)
	var adapted: Dictionary = WorldMutationLedgerScript.legacy_arrays_exact(
		legacy_world, legacy_ledger
	)
	_add(
		cases,
		"PH-20 legacy rock and scrap arrays remain semantically exact",
		(
			adapted[&"destroyed_rocks"] == legacy_world[&"destroyed_rocks"]
			and adapted[&"placed_rocks"] == legacy_world[&"placed_rocks"]
			and adapted[&"dropped_scrap"] == legacy_world[&"dropped_scrap"]
			and adapted[&"collected_scrap"] == legacy_world[&"collected_scrap"]
		),
	)
	var ordered_a: Dictionary = {
		&"cleared": [
			WorldMutationLedgerScript.make_cleared(&"object.tree", Vector2i(17, 1)),
			WorldMutationLedgerScript.make_cleared(&"object.tree", Vector2i(-1, -1)),
		],
		&"placed": [],
	}
	var ordered_b: Dictionary = {
		&"cleared": (ordered_a[&"cleared"] as Array).duplicate(true),
		&"placed": [],
	}
	(ordered_b[&"cleared"] as Array).reverse()
	var normalized_a: Dictionary = WorldMutationLedgerScript.validate(ordered_a)
	var normalized_b: Dictionary = WorldMutationLedgerScript.validate(ordered_b)
	_add(
		cases,
		"PH-20 ledger ordering and chunk indexes are deterministic",
		(
			normalized_a == normalized_b
			and WorldMutationLedgerScript.build_chunk_indexes(normalized_a).size() == 2
		),
	)


static func _test_transaction_rollback(cases: Array[Dictionary]) -> void:
	var source: Dictionary = _source_envelope(_fresh_farm())
	var candidate_farm: Dictionary = (source[&"farm"] as Dictionary).duplicate(true)
	(candidate_farm[&"economy"] as Dictionary)[&"money"] += 1
	candidate_farm = FarmSaveSchemaScript.validate(candidate_farm)
	var rejected_repository: RepositoryProbe = RepositoryProbe.new()
	rejected_repository.accept = false
	var rejected_publisher: PublisherProbe = PublisherProbe.new()
	var persistence_tx: RefCounted = CrossDomainTransactionScript.new() as RefCounted
	persistence_tx.call(
		"configure",
		source,
		rejected_repository,
		rejected_repository,
		Callable(rejected_publisher, "publish"),
		77,
	)
	var persistence_failure: Dictionary = persistence_tx.call(
		"transact", &"farm_candidate", {&"farm": candidate_farm}
	) as Dictionary
	_add(
		cases,
		"PH-21 persistence failure publishes nothing and restores every domain",
		(
			not bool(persistence_failure[&"ok"])
			and persistence_tx.call("get_snapshot") == source
			and rejected_publisher.calls == 0
		),
	)
	var rollback_repository: RepositoryProbe = RepositoryProbe.new()
	var rollback_publisher: PublisherProbe = PublisherProbe.new()
	rollback_publisher.fail_once = true
	var publish_tx: RefCounted = CrossDomainTransactionScript.new() as RefCounted
	publish_tx.call(
		"configure",
		source,
		rollback_repository,
		rollback_repository,
		Callable(rollback_publisher, "publish"),
		77,
	)
	var publish_failure: Dictionary = publish_tx.call(
		"transact", &"farm_candidate", {&"farm": candidate_farm}
	) as Dictionary
	_add(
		cases,
		"PH-21 publish failure compensates live and persisted state exactly",
		(
			not bool(publish_failure[&"ok"])
			and publish_tx.call("get_snapshot") == source
			and rollback_repository.saves == 2
			and rollback_repository.last_saved[&"farm"] == source[&"farm"]
			and rollback_publisher.current == source
		),
	)
	var success_repository: RepositoryProbe = RepositoryProbe.new()
	var success_publisher: PublisherProbe = PublisherProbe.new()
	var success_tx: RefCounted = CrossDomainTransactionScript.new() as RefCounted
	success_tx.call(
		"configure",
		source,
		success_repository,
		success_repository,
		Callable(success_publisher, "publish"),
		77,
	)
	var success: Dictionary = success_tx.call(
		"transact", &"farm_candidate", {&"farm": candidate_farm}
	) as Dictionary
	_add(
		cases,
		"PH-21 successful transaction commits one validated detached envelope",
		(
			bool(success[&"ok"])
			and success_repository.saves == 1
			and int((success_tx.call("get_snapshot")[&"farm"][&"economy"])[&"money"])
			== int((source[&"farm"][&"economy"])[&"money"]) + 1
		),
	)


static func _test_recipes_and_machines(cases: Array[Dictionary]) -> void:
	_add(
		cases,
		"PH-22 recipe and station catalogs are complete and data-driven",
		RecipeCatalogScript.validate() and RecipeCatalogScript.ids().size() == 2,
	)
	var farm: Dictionary = _fresh_farm()
	var credited: Dictionary = InventoryServiceScript.credit_with_overflow(
		farm, &"item.material.scrap", 2
	)
	farm = credited[&"candidate"] as Dictionary
	var wood_before: int = InventoryServiceScript.count_all(farm, &"item.material.wood")
	var scrap_before: int = InventoryServiceScript.count_all(farm, &"item.material.scrap")
	var started: Dictionary = MachineServiceScript.start(
		farm, MachineServiceScript.WORKBENCH_ID, RecipeCatalogScript.RECIPE_IRRIGATION_COIL
	)
	var running: Dictionary = started[&"candidate"] as Dictionary
	var reloaded: Dictionary = FarmSaveSchemaScript.validate(
		JSON.parse_string(FarmSaveSchemaScript.canonical_json(running))
	)
	var complete_day: int = CalendarStateScript.absolute_day(reloaded[&"calendar_weather"]) + 1
	var complete: Dictionary = MachineServiceScript.advance(reloaded, complete_day)
	var claimed: Dictionary = MachineServiceScript.claim(
		complete, MachineServiceScript.WORKBENCH_ID
	)
	var claimed_farm: Dictionary = claimed[&"candidate"] as Dictionary
	var duplicate: Dictionary = MachineServiceScript.claim(
		claimed_farm, MachineServiceScript.WORKBENCH_ID
	)
	var restart_same_day: Dictionary = MachineServiceScript.start(
		claimed_farm,
		MachineServiceScript.WORKBENCH_ID,
		RecipeCatalogScript.RECIPE_IRRIGATION_COIL,
	)
	_add(
		cases,
		"PH-22 machine inputs and outputs commit exactly once across reload and retry",
		(
			bool(started[&"ok"])
			and bool(claimed[&"ok"])
			and not bool(duplicate[&"ok"])
			and not bool(restart_same_day[&"ok"])
			and (
				InventoryServiceScript.count_all(claimed_farm, &"item.material.wood")
				== wood_before - 2
			)
			and (
				InventoryServiceScript.count_all(claimed_farm, &"item.material.scrap")
				== scrap_before - 1
			)
			and InventoryServiceScript.count_all(
				claimed_farm, &"item.part.irrigation_coil"
			) == 1
		),
	)
	var wrong_station: Dictionary = MachineServiceScript.start(
		farm, MachineServiceScript.WORKBENCH_ID, RecipeCatalogScript.RECIPE_IRON_INGOT
	)
	_add(
		cases,
		"PH-22 station tags reject incompatible recipes without consuming inputs",
		not bool(wrong_station[&"ok"]) and wrong_station[&"candidate"] == farm,
	)
	var orphaned: Dictionary = farm.duplicate(true)
	(orphaned[&"machines"] as Array).append(
		{
			&"machine_id": "machine.unknown",
			&"station_tag": "station.workbench",
			&"cell": [1, 1],
			&"state": "machine.idle",
			&"recipe_id": "",
			&"start_day": 0,
			&"complete_day": 0,
			&"operation_token": "",
			&"claimed_tokens": [],
		}
	)
	_add(
		cases,
		"PH-22 orphaned machine records are rejected",
		FarmSaveSchemaScript.validate(orphaned).is_empty(),
	)


static func _test_upgrades(cases: Array[Dictionary]) -> void:
	_add(
		cases,
		"PH-23 all six durable upgrade families have strict definitions",
		DurableUpgradeCatalogScript.validate() and DurableUpgradeCatalogScript.ids().size() == 6,
	)
	var farm: Dictionary = _fresh_farm()
	(farm[&"economy"] as Dictionary)[&"money"] = 1_000
	var paid: Dictionary = DurableUpgradeServiceScript.purchase(
		farm, ToolServiceScript.UPGRADE_WATER_EFFICIENCY
	)
	var paid_farm: Dictionary = paid[&"candidate"] as Dictionary
	var duplicate: Dictionary = DurableUpgradeServiceScript.purchase(
		paid_farm, ToolServiceScript.UPGRADE_WATER_EFFICIENCY
	)
	_add(
		cases,
		"PH-23 legacy watering upgrade retains exact cost and duplicate rejection",
		(
			bool(paid[&"ok"])
			and not bool(duplicate[&"ok"])
			and int((paid_farm[&"economy"] as Dictionary)[&"money"]) == 880
			and InventoryServiceScript.count_all(paid_farm, &"item.material.wood") == 7
			and ToolServiceScript.UPGRADE_WATER_EFFICIENCY
			in ((paid_farm[&"tools"] as Dictionary)[&"upgrade_ids"] as Array)
		),
	)
	var rich: Dictionary = _fresh_farm()
	(rich[&"economy"] as Dictionary)[&"money"] = 5_000
	for reward: Dictionary in [
		{&"item": &"item.material.scrap", &"count": 6},
		{&"item": &"item.material.wood", &"count": 20},
		{&"item": &"item.material.stone", &"count": 12},
		{&"item": &"item.part.irrigation_coil", &"count": 4},
	]:
		var result: Dictionary = InventoryServiceScript.credit_with_overflow(
			rich, reward[&"item"] as StringName, int(reward[&"count"])
		)
		rich = result[&"candidate"] as Dictionary
	var initial_max_stamina: int = int((rich[&"tools"] as Dictionary)[&"max_stamina"])
	var robot: Dictionary = DurableUpgradeServiceScript.purchase(
		rich, &"upgrade.robot.chassis_capacity"
	)
	var robot_farm: Dictionary = robot[&"candidate"] as Dictionary
	var storage: Dictionary = DurableUpgradeServiceScript.purchase(
		robot_farm, &"upgrade.storage.home_expansion"
	)
	var storage_farm: Dictionary = storage[&"candidate"] as Dictionary
	var safehouse: Dictionary = DurableUpgradeServiceScript.purchase(
		storage_farm, &"upgrade.safehouse.power_capacity"
	)
	var furnace: Dictionary = DurableUpgradeServiceScript.purchase(
		safehouse[&"candidate"] as Dictionary, &"upgrade.machine.furnace"
	)
	var furnace_farm: Dictionary = furnace[&"candidate"] as Dictionary
	_add(
		cases,
		"PH-23 robot storage safehouse and furnace capabilities mutate atomically",
		(
			bool(robot[&"ok"])
			and bool(storage[&"ok"])
			and bool(safehouse[&"ok"])
			and bool(furnace[&"ok"])
			and (
				int((robot_farm[&"tools"] as Dictionary)[&"max_stamina"])
				== initial_max_stamina + 20
			)
			and _home_capacity(storage_farm) == 60
			and _has_machine(furnace_farm, MachineServiceScript.FURNACE_ID)
			and &"capability.machine.furnace"
			in DurableUpgradeServiceScript.capabilities(furnace_farm)
		),
	)
	var blocked: Dictionary = DurableUpgradeServiceScript.purchase(
		rich, &"upgrade.machine.furnace"
	)
	_add(
		cases,
		"PH-23 prerequisite failure returns the exact source farm",
		not bool(blocked[&"ok"]) and blocked[&"candidate"] == rich,
	)


static func _test_bounds_and_soak(cases: Array[Dictionary]) -> void:
	var records: Array[Dictionary] = []
	var one_cell: Array[Vector2i] = [Vector2i.ZERO]
	for index: int in WorldMutationLedgerScript.MAX_RECORDS:
		records.append(
			WorldMutationLedgerScript.make_placed(
				&"structure.storage", Vector2i(index, 0), one_cell
			)
		)
	var max_ledger: Dictionary = WorldMutationLedgerScript.validate(
		{&"cleared": [], &"placed": records}
	)
	var oversized_records: Array[Dictionary] = records.duplicate(true)
	oversized_records.append(
		WorldMutationLedgerScript.make_placed(
			&"structure.storage",
			Vector2i(WorldMutationLedgerScript.MAX_RECORDS, 0),
			one_cell,
		)
	)
	var encoded_size: int = JSON.stringify({&"mutation_ledger": max_ledger}).to_utf8_buffer().size()
	_add(
		cases,
		"PH-24 maximum ledger fits the two-megabyte budget and rejects one extra record",
		(
			not max_ledger.is_empty()
			and encoded_size < 2_097_152
			and WorldMutationLedgerScript.validate(
				{&"cleared": [], &"placed": oversized_records}
			).is_empty()
		),
	)
	var first: Dictionary = _simulate_days(_fresh_farm(), 3_360, 77)
	var second: Dictionary = _simulate_days(_fresh_farm(), 3_360, 77)
	var serialized_first: String = FarmSaveSchemaScript.canonical_json(first)
	_add(
		cases,
		"PH-24 deterministic 3,360-day soak stays valid, bounded, and under budget",
		(
			not first.is_empty()
			and first == second
			and serialized_first == FarmSaveSchemaScript.canonical_json(second)
			and serialized_first.to_utf8_buffer().size() < 2_097_152
			and (first[&"day_tokens"] as Array).size() <= FarmSaveSchemaScript.MAX_DAY_TOKENS
			and (
				((first[&"economy"] as Dictionary)[&"settlement_tokens"] as Array).size()
				<= FarmSaveSchemaScript.MAX_DAY_TOKENS
			)
		),
	)
	_add(
		cases,
		"PH-24 farm and mutation caps are explicit production bounds",
		(
			FarmSaveSchemaScript.MAX_PLOTS == 4_096
			and FarmSaveSchemaScript.MAX_INVENTORIES == 2
			and FarmSaveSchemaScript.MAX_MACHINES == 128
			and WorldMutationLedgerScript.MAX_RECORDS == 4_096
		),
	)


static func _test_assets(cases: Array[Dictionary]) -> void:
	var catalog: Resource = VisualCatalogScript.new() as Resource
	var paths: Array[String] = catalog.call("get_required_paths") as Array[String]
	_add(
		cases,
		"PH-22/23 GPT Image 2 furnace and irrigation assets are registered",
		(
			bool(catalog.call("validate_required"))
			and "res://assets/props/machine_furnace.png" in paths
			and "res://assets/props/machine_irrigation_pump.png" in paths
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
		farm_runtime.call("transact", &"till", {&"cell": Vector2i(12, 7)}) as Dictionary
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
		"PH-21 live productive actions update the cross-domain envelope",
		(
			bool(result.get(&"ok", false))
			and not boundary_farm.is_empty()
			and (boundary_farm[&"plots"] as Array).size() == 1
		),
	)


static func _simulate_days(farm: Dictionary, count: int, seed: int) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	for _day: int in count:
		var advanced: Dictionary = DayAdvanceServiceScript.build_candidate(candidate, seed)
		if not bool(advanced[&"ok"]):
			return {}
		candidate = FarmSaveSchemaScript.validate(advanced[&"candidate"])
		if candidate.is_empty():
			return {}
	return candidate


static func _home_capacity(farm: Dictionary) -> int:
	for inventory: Dictionary in farm[&"inventories"] as Array[Dictionary]:
		if inventory[&"container_id"] == "inventory.home":
			return int(inventory[&"capacity_slots"])
	return 0


static func _has_machine(farm: Dictionary, machine_id: StringName) -> bool:
	for machine: Dictionary in farm[&"machines"] as Array[Dictionary]:
		if StringName(machine[&"machine_id"]) == machine_id:
			return true
	return false


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
