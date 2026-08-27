extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const CatalogScript: GDScript = preload("res://scripts/interaction_option_catalog.gd")
const CropCatalogScript: GDScript = preload("res://scripts/crop_catalog.gd")
const CrossDomainTransactionScript: GDScript = preload("res://scripts/cross_domain_transaction.gd")
const DurableUpgradeCatalogScript: GDScript = preload("res://scripts/durable_upgrade_catalog.gd")
const EconomyServiceScript: GDScript = preload("res://scripts/economy_service.gd")
const EcologyDirectorScript: GDScript = preload("res://scripts/ecology_director.gd")
const ExecutionResultScript: GDScript = preload("res://scripts/interaction_execution_result.gd")
const FarmProviderScript: GDScript = preload("res://scripts/harvest_interaction_farm_provider.gd")
const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const HazardCatalogScript: GDScript = preload("res://scripts/hazard_opportunity_catalog.gd")
const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")
const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const InteractionServiceScript: GDScript = preload(
	"res://scripts/harvest_interaction_phase_b_service.gd"
)
const IronjawArcScript: GDScript = preload("res://scripts/ironjaw_desert_arc.gd")
const LivestockServiceScript: GDScript = preload("res://scripts/livestock_service.gd")
const MachineServiceScript: GDScript = preload("res://scripts/machine_service.gd")
const ResidentServiceScript: GDScript = preload("res://scripts/resident_service.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")
const StableFeatureProviderScript: GDScript = preload(
	"res://scripts/stable_feature_interaction_provider.gd"
)
const WildernessProviderScript: GDScript = preload(
	"res://scripts/harvest_interaction_world_provider.gd"
)
const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")
const WorldMutationLedgerScript: GDScript = preload("res://scripts/world_mutation_ledger.gd")
const WorldOperationScript: GDScript = preload("res://scripts/harvest_world_operation_adapter.gd")
const WildFloraCatalogScript: GDScript = preload("res://scripts/wild_flora_catalog.gd")
const WildFloraGeneratorScript: GDScript = preload("res://scripts/wild_flora_generator.gd")


class RepositoryProbe:
	extends RefCounted

	var accept: bool = true
	var saves: int = 0

	func validate_envelope(envelope: Dictionary) -> Dictionary:
		return envelope.duplicate(true)

	func save_state(
		_world: Dictionary, _active_run: Variant, _profile: Dictionary, _farm: Dictionary
	) -> bool:
		if not accept:
			return false
		saves += 1
		return true


class PublisherProbe:
	extends RefCounted

	var current: Dictionary = {}
	var calls: int = 0
	var failures_remaining: int = 0

	func publish(envelope: Dictionary) -> bool:
		calls += 1
		if failures_remaining > 0:
			failures_remaining -= 1
			return false
		current = envelope.duplicate(true)
		return true


static func evaluate(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var farm: Dictionary = _farm_with_all_seeds()
	_test_terrain_and_crops(cases, farm)
	_test_tools_and_world_objects(cases, farm)
	_test_homestead_and_machines(cases, farm)
	_test_residents_and_livestock(cases, farm)
	_test_wilderness_catalogs(cases, farm)
	_test_world_transaction(cases, farm)
	_test_wild_flora(cases, farm)
	_test_live_service(cases, runtime)
	_test_stable_features(cases, farm)
	return cases


static func _fresh_farm() -> Dictionary:
	var farm: Dictionary = FarmSaveSchemaScript.make_neutral(RuntimeIdsScript.MODE_FRESH_FARM)
	farm = InventoryServiceScript.ensure_default(farm)
	farm = CalendarStateScript.ensure_default(farm, WoodlandClearingScript.DEFAULT_SEED)
	farm = ToolServiceScript.ensure_default(farm)
	farm = EconomyServiceScript.ensure_default(farm)
	farm = MachineServiceScript.ensure_default(farm)
	farm = HomesteadServiceScript.ensure_default(farm)
	farm = ResidentServiceScript.ensure_default(farm)
	farm = preload("res://scripts/relationship_service.gd").ensure_default(farm)
	farm = LivestockServiceScript.ensure_default(farm)
	return FarmSaveSchemaScript.validate(farm)


static func _farm_with_all_seeds() -> Dictionary:
	var farm: Dictionary = _fresh_farm()
	for crop_id: StringName in CropCatalogScript.CROP_IDS:
		var seed_id: StringName = CropCatalogScript.definition(crop_id)[&"seed_item_id"]
		if InventoryServiceScript.count_all(farm, seed_id) > 0:
			continue
		var credited: Dictionary = InventoryServiceScript.credit_with_overflow(farm, seed_id, 1)
		if bool(credited[&"ok"]):
			farm = credited[&"candidate"] as Dictionary
	return farm


static func _test_terrain_and_crops(
	cases: Array[Dictionary], farm: Dictionary
) -> void:
	var cell: Vector2i = _apron_cell()
	var before: Dictionary = farm.duplicate(true)
	var menu: Dictionary = _menu(FarmProviderScript.terrain(farm, cell, ToolServiceScript.TOOL_HOE))
	var plant_rows: int = 0
	for option: Dictionary in menu.get(&"options", []) as Array[Dictionary]:
		if str(option[&"action_id"]).begins_with("interaction.action.plant."):
			plant_rows += 1
	_add(
		cases,
		"PHB-01 terrain exposes inspect, till, six owned seeds, water, and harvest without mutation",
		(
			farm == before
			and not menu.is_empty()
			and plant_rows == CropCatalogScript.CROP_IDS.size()
			and _has_action(menu, &"interaction.action.inspect")
			and _has_action(menu, &"interaction.action.till")
			and _has_action(menu, &"interaction.action.water")
			and _has_action(menu, &"interaction.action.harvest")
		),
	)
	var wrong_tool: Dictionary = _menu(
		FarmProviderScript.terrain(farm, cell, ToolServiceScript.TOOL_PICK)
	)
	var till: Dictionary = _action(wrong_tool, &"interaction.action.till")
	_add(
		cases,
		"PHB-02 state and selected tool produce an explicit deterministic disabled reason",
		(
			not till.is_empty()
			and not bool(till[&"enabled"])
			and till[&"reason_key"] == &"interaction.reason.requires_hoe"
		),
	)


static func _test_tools_and_world_objects(
	cases: Array[Dictionary], farm: Dictionary
) -> void:
	var cell: Vector2i = _tree_cell()
	var tree_wrong: Dictionary = _menu(
		WildernessProviderScript.tree(
			farm,
			cell,
			WoodlandClearingScript.tree_kind_at(cell, WoodlandClearingScript.DEFAULT_SEED),
			ToolServiceScript.TOOL_HOE,
		)
	)
	var tree_right: Dictionary = _menu(
		WildernessProviderScript.tree(
			farm,
			cell,
			WoodlandClearingScript.tree_kind_at(cell, WoodlandClearingScript.DEFAULT_SEED),
			ToolServiceScript.TOOL_AXE,
		)
	)
	_add(
		cases,
		"PHB-03 tree exposes inspect, admire, strict Axe chop, and no preview mutation",
		(
			_has_action(tree_right, &"interaction.action.inspect")
			and _has_action(tree_right, &"interaction.action.admire")
			and bool(_action(tree_right, &"interaction.action.chop")[&"enabled"])
			and not bool(_action(tree_wrong, &"interaction.action.chop")[&"enabled"])
			and (
				_action(tree_wrong, &"interaction.action.chop")[&"reason_key"]
				== &"interaction.reason.requires_axe"
			)
		),
	)
	var rock_wrong: Dictionary = _menu(
		WildernessProviderScript.resource(farm, cell, &"desert_ironstone", ToolServiceScript.TOOL_AXE)
	)
	var rock_right: Dictionary = _menu(
		WildernessProviderScript.resource(farm, cell, &"desert_ironstone", ToolServiceScript.TOOL_PICK)
	)
	_add(
		cases,
		"PHB-04 resource nodes expose strict Pick mining and deterministic rewards",
		(
			bool(_action(rock_right, &"interaction.action.mine")[&"enabled"])
			and not bool(_action(rock_wrong, &"interaction.action.mine")[&"enabled"])
			and (
				_action(rock_wrong, &"interaction.action.mine")[&"reason_key"]
				== &"interaction.reason.requires_pick"
			)
		),
	)
	var pickup: Dictionary = _menu(
		WildernessProviderScript.pickup(
			cell,
			&"pickup.test",
			{&"source": &"test", &"amount": 1},
			&"world_collect_reward",
		)
	)
	_add(
		cases,
		"PHB-05 pickup interaction fails explicitly while its runtime transaction is unavailable",
		(
			_has_action(pickup, &"interaction.action.inspect")
			and not bool(_action(pickup, &"interaction.action.collect")[&"enabled"])
			and (
				_action(pickup, &"interaction.action.collect")[&"reason_key"]
				== &"interaction.reason.pickup_authority_unavailable"
			)
		),
	)


static func _test_homestead_and_machines(
	cases: Array[Dictionary], farm: Dictionary
) -> void:
	var home: Dictionary = _menu(
		FarmProviderScript.home(farm, WoodlandClearingScript.HOME_CELL)
	)
	var shipping: Dictionary = _menu(FarmProviderScript.shipping(farm, Vector2i(7, 7)))
	var storage: Dictionary = _menu(FarmProviderScript.storage(farm, Vector2i(8, 7)))
	_add(
		cases,
		"PHB-06 home, shipping, and storage expose their complete non-destructive service surfaces",
		(
			_has_action(home, &"interaction.action.sleep")
			and _has_action(home, &"interaction.action.storage")
			and _has_action(shipping, &"interaction.action.shipping_review")
			and _has_action(storage, &"interaction.action.inventory")
		),
	)
	var facility_count: int = 0
	for facility_id: StringName in HomesteadServiceScript.FACILITY_IDS:
		var definition: Dictionary = HomesteadServiceScript.definition(facility_id)
		var facility: Dictionary = _menu(
			FarmProviderScript.facility(farm, definition[&"cell"], facility_id)
		)
		if (
			_has_action(facility, &"interaction.action.facility_repair")
			and _has_action(facility, &"interaction.action.facility_power")
		):
			facility_count += 1
	_add(cases, "PHB-07 all three facilities expose repair and power rows", facility_count == 3)
	var workbench: Dictionary = _machine(farm, MachineServiceScript.WORKBENCH_ID)
	var installed: Dictionary = MachineServiceScript.install_furnace(farm)
	var furnace_farm: Dictionary = installed[&"candidate"] as Dictionary
	var furnace: Dictionary = _machine(furnace_farm, MachineServiceScript.FURNACE_ID)
	var upgrade_rows: int = 0
	for upgrade_id: StringName in DurableUpgradeCatalogScript.ids():
		if _has_action(
			workbench,
			StringName("interaction.action.upgrade.%s" % str(upgrade_id)),
		):
			upgrade_rows += 1
	_add(
		cases,
		"PHB-08 workbench and furnace menus are valid, bounded, and include machine operations",
		(
			not workbench.is_empty()
			and not furnace.is_empty()
			and (workbench[&"options"] as Array).size() <= 32
			and _has_action(workbench, &"interaction.action.machine_progress")
			and _has_action(furnace, &"interaction.action.machine_progress")
			and upgrade_rows == DurableUpgradeCatalogScript.ids().size()
		),
	)


static func _test_residents_and_livestock(
	cases: Array[Dictionary], farm: Dictionary
) -> void:
	var resident_count: int = 0
	for resident_id: StringName in ResidentServiceScript.RESIDENT_IDS:
		var target: Dictionary = _menu(FarmProviderScript.resident(farm, Vector2i.ZERO, resident_id))
		if (
			_has_action(target, &"interaction.action.talk")
			and _has_action(target, &"interaction.action.relationship")
		):
			resident_count += 1
	_add(cases, "PHB-09 all three residents expose social interaction rows", resident_count == 3)
	var species: Array[StringName] = [
		LivestockServiceScript.MOSSBACK_ID,
		LivestockServiceScript.COILHEN_ID,
		LivestockServiceScript.RUSTSNOUT_ID,
	]
	var livestock_count: int = 0
	for index: int in species.size():
		var animal: Dictionary = _animal("animal.phase_b.%d" % index, species[index])
		var livestock: Dictionary = _menu(
			FarmProviderScript.livestock(farm, Vector2i(index, 0), animal)
		)
		if (
			_has_action(livestock, &"interaction.action.animal_feed")
			and _has_action(livestock, &"interaction.action.animal_pet")
			and _has_action(livestock, &"interaction.action.animal_product")
		):
			livestock_count += 1
	_add(
		cases,
		"PHB-10 all three livestock species expose care and product rows",
		livestock_count == 3,
	)


static func _test_wilderness_catalogs(
	cases: Array[Dictionary], farm: Dictionary
) -> void:
	var day: int = CalendarStateScript.absolute_day(farm[&"calendar_weather"])
	var habitats: Array[Dictionary] = EcologyDirectorScript.population_snapshot(
		farm, WoodlandClearingScript.DEFAULT_SEED, day, 600
	)
	var valid_habitats: int = 0
	for habitat: Dictionary in habitats:
		var target: Dictionary = _menu(
			WildernessProviderScript.habitat(farm, habitat[&"anchor"], habitat, day)
		)
		if not target.is_empty() and _has_action(target, &"interaction.action.inspect"):
			valid_habitats += 1
	_add(cases, "PHB-11 all twelve ecology habitats project deterministic menus", valid_habitats == 12)
	var hazard_count: int = 0
	var ordinal: int = 1
	for kind: StringName in HazardCatalogScript.DEFINITIONS:
		var hazard: Dictionary = _menu(
			WildernessProviderScript.hazard(
				farm,
				{&"id": ordinal, &"kind": kind, &"cell": Vector2i(ordinal, 40), &"age": 0.7},
			)
		)
		var stabilize: Dictionary = _action(hazard, &"interaction.action.hazard_stabilize")
		if (
			_has_action(hazard, &"interaction.action.hazard_forecast")
			and _has_action(hazard, &"interaction.action.hazard_mitigation")
			and not bool(stabilize[&"enabled"])
			and (
				stabilize[&"reason_key"]
				== &"interaction.reason.hazard_runtime_transaction_unavailable"
			)
		):
			hazard_count += 1
		ordinal += 1
	_add(
		cases,
		"PHB-12 all four hazards explain forecast, mitigation, and safe disabled stabilization",
		hazard_count == 4,
	)
	var ironjaw: Dictionary = _menu(
		WildernessProviderScript.hostile(
			Vector2i(0, 42),
			&"hostile.ironjaw",
			{&"kind": &"ironjaw_apex", &"health": 180, &"max_health": 180, &"is_boss": true},
		)
	)
	var ruin: Dictionary = _menu(
		WildernessProviderScript.ruin(
			Vector2i(4, 4),
			{&"id": &"ruin.remote.test", &"active": false},
			farm,
		)
	)
	var gate: Dictionary = _menu(WildernessProviderScript.gate(Vector2i(0, 20), {}))
	_add(
		cases,
		(
			"PHB-13 Ironjaw, remote ruins, and expedition gates expose useful reads "
			+ "and exact disabled reasons"
		),
		(
			_has_action(ironjaw, &"interaction.action.first_clear")
			and not bool(_action(ruin, &"interaction.action.remote_ruin_activate")[&"enabled"])
			and (
				_action(ruin, &"interaction.action.remote_ruin_activate")[&"reason_key"]
				== &"interaction.reason.activation_requires_expedition_return"
			)
			and not bool(_action(gate, &"interaction.action.gate_enter")[&"enabled"])
			and (
				_action(gate, &"interaction.action.gate_enter")[&"reason_key"]
				== &"interaction.reason.gate_entry_authority_unavailable"
			)
		),
	)


static func _test_world_transaction(
	cases: Array[Dictionary], farm: Dictionary
) -> void:
	var cell: Vector2i = _tree_cell()
	var kind: StringName = WoodlandClearingScript.tree_kind_at(
		cell, WoodlandClearingScript.DEFAULT_SEED
	)
	var reward: Dictionary = WorldOperationScript.reward_for(&"tree", kind)
	var source: Dictionary = _source_envelope(farm)
	var repository: RepositoryProbe = RepositoryProbe.new()
	var publisher: PublisherProbe = PublisherProbe.new()
	var boundary: RefCounted = CrossDomainTransactionScript.new() as RefCounted
	var world: RefCounted = InfiniteWorldScript.new() as RefCounted
	var configured: bool = bool(
		boundary.call(
			"configure",
			source,
			repository,
			world,
			Callable(publisher, "publish"),
			WoodlandClearingScript.DEFAULT_SEED,
		)
	)
	var arguments: Dictionary = {
		&"cell": cell,
		&"world_kind": &"object.tree",
		&"source_kind": kind,
		&"required_tool": ToolServiceScript.TOOL_AXE,
		&"reward_item_id": reward[&"item_id"],
		&"reward_count": int(reward[&"count"]),
	}
	var before_stamina: int = int((farm[&"tools"] as Dictionary)[&"stamina"])
	var before_wood: int = InventoryServiceScript.count_all(farm, reward[&"item_id"])
	var first: Dictionary = boundary.call("transact", &"world_clear_reward", arguments)
	var envelope: Dictionary = first.get(&"candidate", {}) as Dictionary
	var after_farm: Dictionary = envelope.get(&"farm", {}) as Dictionary
	var after_world: Dictionary = envelope.get(&"world", {}) as Dictionary
	world.call("configure", {}, {}, {}, {}, {}, {})
	world.call(
		"_set_generation_context",
		RuntimeIdsScript.MODE_FRESH_FARM,
		WoodlandClearingScript.DEFAULT_SEED,
	)
	var applied: Dictionary = after_world.duplicate(true)
	applied[&"schema"] = 2
	world.call("apply_snapshot", applied)
	var second: Dictionary = boundary.call("transact", &"world_clear_reward", arguments)
	_add(
		cases,
		"PHB-14 tree clear, stamina, reward, persistence, live suppression, and idempotence are atomic",
		(
			configured
			and bool(first[&"ok"])
			and repository.saves == 1
			and publisher.calls == 1
			and WorldMutationLedgerScript.is_cleared(
				after_world[&"mutation_ledger"], &"object.tree", cell
			)
			and int((after_farm[&"tools"] as Dictionary)[&"stamina"]) == before_stamina - 10
			and InventoryServiceScript.count_all(after_farm, reward[&"item_id"]) == (
				before_wood + int(reward[&"count"])
			)
			and world.call("_tree_kind_at", cell) == &""
			and not bool(second[&"ok"])
			and second[&"candidate"] == first[&"candidate"]
		),
	)
	var failed_repository: RepositoryProbe = RepositoryProbe.new()
	failed_repository.accept = false
	var failed_boundary: RefCounted = CrossDomainTransactionScript.new() as RefCounted
	failed_boundary.call(
		"configure",
		source,
		failed_repository,
		world,
		Callable(publisher, "publish"),
		WoodlandClearingScript.DEFAULT_SEED,
	)
	var failed: Dictionary = failed_boundary.call("transact", &"world_clear_reward", arguments)
	_add(
		cases,
		"PHB-15 persistence failure restores the exact source world and farm",
		(
			not bool(failed[&"ok"])
			and failed[&"reason"] == &"persistence_failed"
			and failed[&"candidate"] == source
		),
	)
	var invalid_arguments: Dictionary = arguments.duplicate(true)
	invalid_arguments[&"reward_count"] = int(reward[&"count"]) + 1
	var invalid: Dictionary = WorldOperationScript.build(source, invalid_arguments)
	var full_source: Dictionary = source.duplicate(true)
	var full_farm: Dictionary = (full_source[&"farm"] as Dictionary).duplicate(true)
	var inventories: Array = (full_farm[&"inventories"] as Array).duplicate(true)
	for inventory_index: int in inventories.size():
		var inventory: Dictionary = (inventories[inventory_index] as Dictionary).duplicate(true)
		inventory[&"stacks"] = [
			{
				&"item_id": String(reward[&"item_id"]),
				&"count": ItemCatalogScript.stack_limit(reward[&"item_id"] as StringName),
			}
		]
		inventories[inventory_index] = inventory
	full_farm[&"inventories"] = inventories
	full_source[&"farm"] = full_farm
	var capacity: Dictionary = WorldOperationScript.build(full_source, arguments)
	_add(
		cases,
		"PHB-16 world clear rejects forged rewards and full inventory without partial state",
		(
			not bool(invalid[&"ok"])
			and invalid[&"reason"] == &"invalid_world_operation"
			and invalid[&"candidate"] == source
			and not bool(capacity[&"ok"])
			and capacity[&"reason"] == &"inventory_full"
			and capacity[&"candidate"] == full_source
		),
	)
	var rollback_repository: RepositoryProbe = RepositoryProbe.new()
	var rollback_publisher: PublisherProbe = PublisherProbe.new()
	rollback_publisher.failures_remaining = 1
	var rollback_boundary: RefCounted = CrossDomainTransactionScript.new() as RefCounted
	var rollback_world: RefCounted = InfiniteWorldScript.new() as RefCounted
	rollback_boundary.call(
		"configure",
		source,
		rollback_repository,
		rollback_world,
		Callable(rollback_publisher, "publish"),
		WoodlandClearingScript.DEFAULT_SEED,
	)
	var publish_failed: Dictionary = rollback_boundary.call(
		"transact", &"world_clear_reward", arguments
	)
	_add(
		cases,
		"PHB-17 publication failure durably restores source before reporting failure",
		(
			not bool(publish_failed[&"ok"])
			and publish_failed[&"reason"] == &"publish_failed"
			and publish_failed[&"candidate"] == source
			and rollback_repository.saves == 2
			and rollback_publisher.calls == 2
			and rollback_publisher.current == source
		),
	)


static func _test_wild_flora(cases: Array[Dictionary], farm: Dictionary) -> void:
	var world: RefCounted = InfiniteWorldScript.new() as RefCounted
	world.call("configure", {}, {}, {}, {}, {}, {})
	world.call(
		"_set_generation_context",
		RuntimeIdsScript.MODE_FRESH_FARM,
		WoodlandClearingScript.DEFAULT_SEED,
	)
	var flora_cell: Vector2i = Vector2i(1_000_001, 1_000_001)
	var species_id: StringName = &""
	for y: int in range(-16, 17):
		for x: int in range(-16, 17):
			var cell: Vector2i = Vector2i(x, y)
			var candidate: StringName = world.call("_flora_kind_at", cell) as StringName
			if candidate != &"":
				flora_cell = cell
				species_id = candidate
				break
		if species_id != &"":
			break
	var density: float = WildFloraGeneratorScript.density_for_seed(
		WoodlandClearingScript.DEFAULT_SEED
	)
	_add(
		cases,
		"GF-01 five-species flora catalog and coordinate generation are stable and bounded",
		(
			WildFloraCatalogScript.validate(true)
			and WildFloraCatalogScript.SPECIES_IDS.size() == 5
			and species_id != &""
			and not WoodlandClearingScript.is_protected_path(flora_cell)
			and not WoodlandClearingScript.is_farm_apron(flora_cell)
			and density >= 0.08
			and density <= 0.14
			and world.call("_flora_kind_at", flora_cell) == species_id
		),
	)
	var reward: Dictionary = WildFloraCatalogScript.smash_reward(species_id)
	var menu: Dictionary = _menu(WildernessProviderScript.flora(farm, flora_cell, species_id))
	var smash: Dictionary = _action(menu, &"interaction.action.smash_flora")
	var source: Dictionary = _source_envelope(farm)
	var before_produce: int = InventoryServiceScript.count_all(
		farm, reward[&"produce_item_id"] as StringName
	)
	var before_seed: int = InventoryServiceScript.count_all(
		farm, reward[&"seed_item_id"] as StringName
	)
	var before_stamina: int = int((farm[&"tools"] as Dictionary)[&"stamina"])
	var gathered: Dictionary = WorldOperationScript.build(
		source, smash.get(&"arguments", {}) as Dictionary
	)
	var envelope: Dictionary = gathered.get(&"candidate", {}) as Dictionary
	var gathered_farm: Dictionary = envelope.get(&"farm", {}) as Dictionary
	var gathered_world: Dictionary = envelope.get(&"world", {}) as Dictionary
	var applied_world: Dictionary = gathered_world.duplicate(true)
	applied_world[&"schema"] = 2
	world.call("apply_snapshot", applied_world)
	_add(
		cases,
		"GF-02 Smash atomically clears one plant and credits half produce plus one seed",
		(
			not menu.is_empty()
			and bool(smash[&"enabled"])
			and bool(gathered[&"ok"])
			and int((gathered_farm[&"tools"] as Dictionary)[&"stamina"]) == before_stamina - 2
			and InventoryServiceScript.count_all(
				gathered_farm, reward[&"produce_item_id"] as StringName
			) == before_produce + int(reward[&"produce_count"])
			and InventoryServiceScript.count_all(
				gathered_farm, reward[&"seed_item_id"] as StringName
			) == before_seed + 1
			and WorldMutationLedgerScript.is_cleared(
				gathered_world[&"mutation_ledger"], &"object.flora", flora_cell
			)
			and world.call("_flora_kind_at", flora_cell) == &""
		),
	)
	var crop_id: StringName = WildFloraCatalogScript.definition(species_id)[&"crop_id"]
	var crop: Dictionary = CropCatalogScript.definition(crop_id)
	var plot_cell: Vector2i = _apron_cell()
	var tilled: Dictionary = FarmStateScript.till(gathered_farm, plot_cell)
	var planted: Dictionary = FarmStateScript.plant(
		tilled[&"candidate"], plot_cell, reward[&"seed_item_id"], 1
	)
	var growing: Dictionary = planted[&"candidate"] as Dictionary
	for day: int in range(1, int((crop[&"stage_growth"] as Array)[3]) + 1):
		var watered: Dictionary = FarmStateScript.water(growing, plot_cell, day)
		growing = FarmStateScript.grow(watered[&"candidate"], day)
	var mature: Dictionary = FarmStateScript.plot_at(growing, plot_cell)
	var harvested: Dictionary = FarmStateScript.harvest(growing, plot_cell)
	_add(
		cases,
		"GF-03 discovered seed tills, plants, waters, matures, and returns full farm yield",
		(
			bool(tilled[&"ok"])
			and bool(planted[&"ok"])
			and bool(mature[&"ready"])
			and int(mature[&"stage"]) == 3
			and bool(harvested[&"ok"])
			and int(harvested[&"yield_count"]) == int(crop[&"yield_min"])
			and int(harvested[&"yield_count"]) > int(reward[&"produce_count"])
		),
	)
	var all_species_valid: bool = true
	for flora_id: StringName in WildFloraCatalogScript.SPECIES_IDS:
		var flora: Dictionary = WildFloraCatalogScript.definition(flora_id)
		var loop_crop_id: StringName = flora[&"crop_id"] as StringName
		var loop_crop: Dictionary = CropCatalogScript.definition(loop_crop_id)
		var loop_farm: Dictionary = _farm_with_all_seeds()
		var favored_seasons: Array = loop_crop[&"favored_seasons"] as Array
		(loop_farm[&"calendar_weather"] as Dictionary)[&"season_id"] = favored_seasons[0]
		var loop_till: Dictionary = FarmStateScript.till(loop_farm, plot_cell)
		var loop_plant: Dictionary = FarmStateScript.plant(
			loop_till.get(&"candidate", {}) as Dictionary,
			plot_cell,
			flora[&"seed_item_id"] as StringName,
			1,
		)
		if not bool(loop_till.get(&"ok", false)) or not bool(loop_plant.get(&"ok", false)):
			all_species_valid = false
			continue
		var loop_growing: Dictionary = loop_plant[&"candidate"] as Dictionary
		for day: int in range(1, int((loop_crop[&"stage_growth"] as Array)[3]) + 1):
			var loop_water: Dictionary = FarmStateScript.water(loop_growing, plot_cell, day)
			if not bool(loop_water.get(&"ok", false)):
				all_species_valid = false
				break
			loop_growing = FarmStateScript.grow(loop_water[&"candidate"], day)
		var loop_harvest: Dictionary = FarmStateScript.harvest(loop_growing, plot_cell)
		var after_plot: Dictionary = FarmStateScript.plot_at(
			loop_harvest.get(&"candidate", {}) as Dictionary, plot_cell
		)
		var regrows: bool = int(loop_crop[&"regrow_days"]) > 0
		all_species_valid = (
			all_species_valid
			and bool(loop_harvest.get(&"ok", false))
			and int(loop_harvest.get(&"yield_count", 0)) == int(loop_crop[&"yield_min"])
			and ((after_plot[&"crop_id"] == loop_crop_id) if regrows else after_plot[&"crop_id"] == &"")
		)
	_add(
		cases,
		"GF-04 all five species complete four-stage growth with canonical clear or regrow outcomes",
		all_species_valid,
	)


static func _test_live_service(cases: Array[Dictionary], runtime: Node2D) -> void:
	var bridge: Node = runtime.get_node_or_null("HarvestPhaseTwo")
	var service: RefCounted = (
		bridge.call("get_interaction_phase_b_service") as RefCounted if bridge != null else null
	)
	var controller: Node2D = (
		bridge.call("get_interaction_controller") as Node2D if bridge != null else null
	)
	var farm_runtime: RefCounted = (
		bridge.call("get_farm_runtime") as RefCounted if bridge != null else null
	)
	var before: Dictionary = farm_runtime.call("get_snapshot") if farm_runtime != null else {}
	var opened: bool = bool(controller.call("open_menu")) if controller != null else false
	var after: Dictionary = farm_runtime.call("get_snapshot") if farm_runtime != null else {}
	var gameplay_after: Dictionary = after.duplicate(true)
	if not before.is_empty() and not gameplay_after.is_empty():
		gameplay_after[&"tutorial"] = before[&"tutorial"]
		gameplay_after[&"revisions"] = before[&"revisions"]
	var workbench: Dictionary = (
		_menu(service.call("project", Vector2i(9, 7), ToolServiceScript.TOOL_HOE))
		if service != null
		else {}
	)
	_add(
		cases,
		(
			"PHB-18 live bridge opens without gameplay mutation, "
			+ "and workbench projection is valid"
		),
		(
			bridge != null
			and bridge.call("is_ready_for_commands")
			and service != null
			and controller != null
			and opened
			and before == gameplay_after
			and not workbench.is_empty()
			and (workbench[&"options"] as Array).size() <= 32
		),
	)
	var inspect_cell: Vector2i = _apron_cell()
	var inspect_menu: Dictionary = (
		_menu(service.call("project", inspect_cell, ToolServiceScript.TOOL_HOE))
		if service != null
		else {}
	)
	var inspect_option: Dictionary = _action(
		inspect_menu, &"interaction.action.inspect"
	)
	var inspect_before: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var inspect_result: Dictionary = (
		service.call(
			"execute",
			ResolverScript.ACTION_CONTEXT,
			ToolServiceScript.TOOL_HOE,
			{
				&"valid": true,
				&"target_cell": inspect_cell,
				&"target_kind": inspect_menu.get(&"target_kind", &"") as StringName,
				&"action": ResolverScript.ACTION_CONTEXT,
				&"rejection_reason": &"",
			},
			inspect_option,
		) as Dictionary
		if service != null and not inspect_option.is_empty()
		else {}
	)
	var inspect_after: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	_add(
		cases,
		"PHB-19 live Terrain Inspect returns a useful Decision Card without mutation",
		(
			ExecutionResultScript.validate(inspect_result)
			and bool(inspect_result[&"ok"])
			and not bool(inspect_result[&"mutated"])
			and (((inspect_result[&"view"] as Dictionary)[&"facts"] as Array).size() >= 5)
			and inspect_before == inspect_after
		),
	)
	var pond_cell: Vector2i = WoodlandClearingScript.POND_CELL
	var pond_menu: Dictionary = (
		_menu(service.call("project", pond_cell, ToolServiceScript.TOOL_HOE))
		if service != null
		else {}
	)
	var pond_option: Dictionary = _action(pond_menu, &"interaction.action.inspect")
	var pond_before: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var pond_result: Dictionary = (
		service.call(
			"execute",
			ResolverScript.ACTION_CONTEXT,
			ToolServiceScript.TOOL_HOE,
			{
				&"valid": true,
				&"target_cell": pond_cell,
				&"target_kind": pond_menu.get(&"target_kind", &"") as StringName,
				&"action": ResolverScript.ACTION_CONTEXT,
				&"rejection_reason": &"",
			},
			pond_option,
		) as Dictionary
		if service != null and not pond_option.is_empty()
		else {}
	)
	var pond_after: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	_add(
		cases,
		"PHB-20 live freshwater pond Inspect returns useful state without mutation",
		(
			pond_menu[&"target_subkind"] == &"water"
			and ExecutionResultScript.validate(pond_result)
			and _result_fact_value(
				pond_result, &"interaction.inspect.fact.water_class"
			) == &"interaction.value.water.freshwater_pond"
			and pond_before == pond_after
		),
	)
	if controller != null:
		controller.call("close_menu")


static func _test_stable_features(cases: Array[Dictionary], farm: Dictionary) -> void:
	var pond_description: Dictionary = InteractionServiceScript.stable_feature_description(
		WoodlandClearingScript.POND_CELL, farm, true
	)
	var exit_description: Dictionary = InteractionServiceScript.stable_feature_description(
		IronjawArcScript.SAFE_EXIT, farm, false
	)
	var pond_menu: Dictionary = _menu(
		StableFeatureProviderScript.water(
			WoodlandClearingScript.POND_CELL,
			pond_description.get(&"state", {}) as Dictionary,
		)
	)
	var exit_menu: Dictionary = _menu(
		StableFeatureProviderScript.safe_exit(
			IronjawArcScript.SAFE_EXIT,
			exit_description.get(&"state", {}) as Dictionary,
		)
	)
	var return_option: Dictionary = _action(
		exit_menu, &"interaction.action.return_safe_exit"
	)
	var locked_pump: Dictionary = InteractionServiceScript.stable_feature_description(
		Vector2i(10, 6), farm, false
	)
	var locked_well: Dictionary = InteractionServiceScript.stable_feature_description(
		IronjawArcScript.WELL_CELL, farm, false
	)
	var unlocked: Dictionary = farm.duplicate(true)
	var tools: Dictionary = unlocked[&"tools"] as Dictionary
	var upgrades: Array = (tools[&"upgrade_ids"] as Array).duplicate()
	upgrades.append("upgrade.irrigation.grid_radius")
	tools[&"upgrade_ids"] = upgrades
	var ecology: Dictionary = unlocked[&"ecology"] as Dictionary
	var clears: Array = (ecology[&"boss_first_clear_ids"] as Array).duplicate()
	clears.append(String(EcologyDirectorScript.IRONJAW_CLEAR_ID))
	ecology[&"boss_first_clear_ids"] = clears
	var pump: Dictionary = InteractionServiceScript.stable_feature_description(
		Vector2i(10, 6), unlocked, false
	)
	var well: Dictionary = InteractionServiceScript.stable_feature_description(
		IronjawArcScript.WELL_CELL, unlocked, false
	)
	var ready_exit: Dictionary = InteractionServiceScript.stable_feature_description(
		IronjawArcScript.SAFE_EXIT, unlocked, false
	)
	_add(
		cases,
		"PHB-21 pond and safe exit resolve through existing structure kind with truthful actions",
		(
			pond_description[&"family"] == &"water"
			and pond_menu[&"target_kind"] == ResolverScript.KIND_STRUCTURE
			and pond_menu[&"target_subkind"] == &"water"
			and exit_description[&"family"] == &"safe_exit"
			and exit_menu[&"target_subkind"] == &"safe_exit"
			and not bool(return_option[&"enabled"])
			and return_option[&"reason_key"]
			== &"interaction.reason.safe_exit_transition_unavailable"
		),
	)
	_add(
		cases,
		"PHB-22 functional props appear only when their owning capability is active",
		(
			locked_pump.is_empty()
			and locked_well.is_empty()
			and pump[&"target_id"] == &"prop.irrigation_pump"
			and well[&"target_id"] == &"prop.burrow_well"
			and bool((ready_exit[&"state"] as Dictionary)[&"ready"])
		),
	)
	_add(
		cases,
		"PHB-23 decorative cells remain excluded from interaction taxonomy",
		InteractionServiceScript.stable_feature_description(
			Vector2i(3, 3), unlocked, false
		).is_empty(),
	)


static func _menu(target: Dictionary) -> Dictionary:
	return CatalogScript.build_menu(target)


static func _machine(farm: Dictionary, machine_id: StringName) -> Dictionary:
	for record: Dictionary in farm.get(&"machines", []) as Array[Dictionary]:
		if StringName(record[&"machine_id"]) == machine_id:
			var raw: Array = record[&"cell"] as Array
			return _menu(
				FarmProviderScript.machine(
					farm, Vector2i(int(raw[0]), int(raw[1])), record
				)
			)
	return {}


static func _action(menu: Dictionary, action_id: StringName) -> Dictionary:
	for option: Dictionary in menu.get(&"options", []) as Array[Dictionary]:
		if option[&"action_id"] == action_id:
			return option
	return {}


static func _result_fact_value(result: Dictionary, label_key: StringName) -> Variant:
	var view: Dictionary = result.get(&"view", {}) as Dictionary
	for fact: Dictionary in view.get(&"facts", []) as Array[Dictionary]:
		if fact[&"label_key"] == label_key:
			return fact[&"value"]
	return null


static func _has_action(menu: Dictionary, action_id: StringName) -> bool:
	return not _action(menu, action_id).is_empty()


static func _apron_cell() -> Vector2i:
	for y: int in range(-16, 17):
		for x: int in range(-16, 17):
			var cell: Vector2i = Vector2i(x, y)
			if WoodlandClearingScript.is_farm_apron(cell):
				return cell
	return Vector2i.ZERO


static func _tree_cell() -> Vector2i:
	for y: int in range(-24, 25):
		for x: int in range(-24, 25):
			var cell: Vector2i = Vector2i(x, y)
			if WoodlandClearingScript.tree_kind_at(
				cell, WoodlandClearingScript.DEFAULT_SEED
			) != &"":
				return cell
	return Vector2i(1_000_001, 1_000_001)


static func _animal(animal_id: String, species_id: StringName) -> Dictionary:
	return {
		&"animal_id": animal_id,
		&"species_id": String(species_id),
		&"housing_id": "housing.home.test",
		&"bond": 0,
		&"last_feed_day": 0,
		&"last_pet_day": 0,
		&"last_product_day": 0,
		&"care_tokens": [],
	}


static func _source_envelope(farm: Dictionary) -> Dictionary:
	return {
		&"save_format_version": 4,
		&"metadata": {},
		&"world": {
			&"destroyed_rocks": [],
			&"placed_rocks": [],
			&"dropped_scrap": [],
			&"collected_scrap": [],
			&"mutation_ledger": {&"cleared": [], &"placed": []},
		},
		&"active_run": null,
		&"profile": {},
		&"farm": farm.duplicate(true),
	}


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
