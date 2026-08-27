extends RefCounted

const CalendarScript: GDScript = preload("res://scripts/calendar_state.gd")
const CropCatalogScript: GDScript = preload("res://scripts/crop_catalog.gd")
const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const FarmOccupancyScript: GDScript = preload("res://scripts/farm_occupancy_service.gd")
const FishingCatalogScript: GDScript = preload("res://scripts/fishing_catalog.gd")
const FishingServiceScript: GDScript = preload("res://scripts/fishing_service.gd")
const InventoryScript: GDScript = preload("res://scripts/inventory_service.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const OperationCatalogScript: GDScript = preload("res://scripts/interaction_operation_catalog.gd")
const PhaseBScript: GDScript = preload("res://scripts/harvest_interaction_phase_b_service.gd")
const OrchardCatalogScript: GDScript = preload("res://scripts/orchard_catalog.gd")
const OrchardServiceScript: GDScript = preload("res://scripts/orchard_service.gd")
const PlacementScript: GDScript = preload("res://scripts/placement_validator.gd")
const QuickPolicyScript: GDScript = preload("res://scripts/quick_action_policy.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")
const SeasonalProviderScript: GDScript = preload(
	"res://scripts/seasonal_interaction_provider.gd"
)
const ToolScript: GDScript = preload("res://scripts/tool_service.gd")
const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")

const SEED: int = 902_011
const TREE_CELL: Vector2i = Vector2i(10, 7)


static func evaluate_contracts() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_add(
		cases,
		"P10 authored crop orchard fishing and item catalogs are finite and valid",
		CropCatalogScript.validate()
		and OrchardCatalogScript.validate()
		and FishingCatalogScript.validate()
		and ItemCatalogScript.validate()
		and CropCatalogScript.CROP_IDS.size() >= 6
		and OrchardCatalogScript.SPECIES_IDS.size() == 2
		and SectionsScript.MAX_TREES == 512
		and FarmOccupancyScript.orchard_cells().size() == 512
		and FishingCatalogScript.SPOT_IDS.size() == 3
		and FishingCatalogScript.FISH_IDS.size() == 4,
	)
	_add(
		cases,
		"P10 all three finite fishing pools are reachable through authoritative live features",
		_water_class(WoodlandClearingScript.POND_CELL, true, &"woodland") == &"freshwater_pond"
		and _water_class(FishingCatalogScript.MIRE_POOL_CELL, false, &"oasis") == &"mire_pool"
		and _water_class(FishingCatalogScript.RIME_MELT_CELL, false, &"frozen") == &"rime_melt",
	)
	var unique_affinities: Dictionary = {}
	for crop_id: StringName in CropCatalogScript.CROP_IDS:
		unique_affinities[str(CropCatalogScript.definition(crop_id)[&"favored_seasons"])] = true
	_add(
		cases,
		"P10 crop affinities are frozen varied and preserve winter-hardy identity",
		unique_affinities.size() >= 5
		and CropCatalogScript.is_favored(&"crop.ironturnip", &"season.winter")
		and not CropCatalogScript.is_favored(&"crop.sunpod", &"season.winter"),
	)
	var p10_items: Array[StringName] = [
		&"item.sapling.cinderapple", &"item.sapling.ironbark",
		&"item.tool.fishing_rod", &"item.bait.luminous",
	]
	var item_assets_valid: bool = true
	for item_id: StringName in p10_items:
		var path: String = str(ItemCatalogScript.definition(item_id)[&"icon_path"])
		item_assets_valid = item_assets_valid and load(path) is Texture2D
	_add(cases, "P10 authored item icons import as Texture2D resources", item_assets_valid)
	var orchard: Dictionary = SectionsScript.neutral_orchard()
	orchard[&"trees"] = [{
		&"tree_id": "tree.bad", &"species_id": "tree.unknown", &"cell": [1, 1],
		&"planted_day": 1, &"growth_points": 0, &"harvest_sequence": 0,
	}]
	var fishing: Dictionary = SectionsScript.neutral_fishing()
	fishing[&"spots"] = [{
		&"spot_id": str(FishingCatalogScript.WOODLAND_POND),
		&"cast_sequence": 0, &"remaining_catches": 99, &"renewal_day": 2,
	}]
	_add(
		cases,
		"P10 persistence rejects unknown or impossible trees and fishing capacity",
		SectionsScript.validate_orchard(orchard).is_empty()
		and SectionsScript.validate_fishing(fishing).is_empty()
		and _impossible_orchards_rejected(),
	)
	var expected_operations: Array[StringName] = [
		&"fish_cast", &"tree_harvest", &"tree_plant", &"tree_remove",
	]
	var operations_valid: bool = true
	for operation: StringName in expected_operations:
		var descriptor: Dictionary = _operation_descriptor(operation)
		operations_valid = operations_valid and not descriptor.is_empty()
		operations_valid = operations_valid and descriptor[&"receipt_policy"] == (
			OperationCatalogScript.RECEIPT_REQUIRED
		)
	_add(
		cases,
		"P10 tree and fishing mutations require exact-once receipts and never enter Safe Quick",
		operations_valid and not _quick_accepts(expected_operations),
	)
	var locale_keys: Array[String] = _locale_keys("res://data/locales/en.json")
	var required_reasons: Array[String] = [
		"interaction.reason.missing_tree",
		"interaction.reason.stale_seasonal_revision",
		"interaction.reason.tree_protected_path",
		"interaction.reason.unknown_fishing_spot",
	]
	_add(
		cases,
		"P10 localization has parity and every emitted seasonal failure reason",
		locale_keys == _locale_keys("res://data/locales/zh-CN.json")
		and _contains_all(locale_keys, required_reasons),
	)
	return cases


static func evaluate(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = evaluate_contracts()
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var transactions: RefCounted = bridge.call("get_transaction_boundary") as RefCounted
	var base: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var phase_b: RefCounted = bridge.call("get_interaction_phase_b_service") as RefCounted
	var live_world: RefCounted = runtime.get("_world") as RefCounted
	var live_mire: Dictionary = phase_b.call(
		"_stable_feature_at", FishingCatalogScript.MIRE_POOL_CELL, live_world
	)
	var live_rime: Dictionary = phase_b.call(
		"_stable_feature_at", FishingCatalogScript.RIME_MELT_CELL, live_world
	)
	_add(
		cases,
		"P10 mire and rime pools project through the live world and block movement",
		str((live_mire[&"state"] as Dictionary)[&"water_class"]) == "mire_pool"
		and str((live_rime[&"state"] as Dictionary)[&"water_class"]) == "rime_melt"
		and not runtime.is_walkable(FishingCatalogScript.MIRE_POOL_CELL)
		and not runtime.is_walkable(FishingCatalogScript.RIME_MELT_CELL),
	)
	_crop_season_cases(cases, base)
	var supplied: Dictionary = _with_items(base, {
		&"item.sapling.cinderapple": 2,
		&"item.sapling.ironbark": 2,
		&"item.tool.fishing_rod": 1,
		&"item.bait.luminous": 8,
	})
	var planted: Dictionary = OrchardServiceScript.plant(
		supplied, TREE_CELL, &"item.sapling.cinderapple", 1, func(_cell: Vector2i) -> bool: return true
	)
	var overlap: Dictionary = OrchardServiceScript.plant(
		planted[&"candidate"], TREE_CELL, &"item.sapling.ironbark", 1,
		func(_cell: Vector2i) -> bool: return true,
	)
	var remote: Dictionary = OrchardServiceScript.plant(
		supplied, Vector2i(0, 0), &"item.sapling.ironbark", 1,
		func(_cell: Vector2i) -> bool: return true,
	)
	var machine_farm: Dictionary = supplied.duplicate(true)
	(machine_farm[&"machines"] as Array).append({&"cell": [11, 8]})
	var machine_overlap: Dictionary = OrchardServiceScript.plant(
		machine_farm, Vector2i(11, 8), &"item.sapling.ironbark", 1,
		func(_cell: Vector2i) -> bool: return true,
	)
	var path_overlap: Dictionary = OrchardServiceScript.plant(
		supplied, Vector2i(12, 8), &"item.sapling.ironbark", 1,
		func(_cell: Vector2i) -> bool: return true,
	)
	_add(
		cases,
		"P10 orchard planting supports world-valid cells and rejects occupied service cells",
		planted[&"ok"]
		and InventoryScript.count_all(
			planted[&"candidate"], &"item.sapling.cinderapple"
			) == 1
			and not overlap[&"ok"] and overlap[&"reason"] == &"tree_cell_occupied"
			and remote[&"ok"]
			and not machine_overlap[&"ok"] and machine_overlap[&"reason"] == &"tree_cell_occupied"
			and not path_overlap[&"ok"] and path_overlap[&"reason"] == &"tree_protected_path",
	)
	var world: RefCounted = runtime.get("_world") as RefCounted
	var construction_overlap: Dictionary = PlacementScript.evaluate(
		planted[&"candidate"], world, &"blueprint.shelter_pod", TREE_CELL, 0
	)
	_add(
		cases,
		"P10 orchard cells are occupied and construction cannot claim the farm apron",
		FarmOccupancyScript.occupied(planted[&"candidate"], TREE_CELL)
		and not construction_overlap[&"ok"]
		and construction_overlap[&"reason"] == &"protected_path",
	)
	var plot_over_tree: Dictionary = FarmStateScript.till(planted[&"candidate"], TREE_CELL)
	var plot_over_machine: Dictionary = FarmStateScript.till(machine_farm, Vector2i(11, 8))
	var plot_on_x_lane: Dictionary = FarmStateScript.till(supplied, Vector2i(12, 8))
	var plot_on_y_lane: Dictionary = FarmStateScript.till(supplied, Vector2i(10, 9))
	_add(
		cases,
		"P10 plots cannot overwrite trees, farm occupants, or protected service lanes",
		not plot_over_tree[&"ok"] and plot_over_tree[&"reason"] == &"not_tillable"
		and plot_over_tree[&"candidate"] == planted[&"candidate"]
		and not plot_over_machine[&"ok"] and plot_over_machine[&"reason"] == &"not_tillable"
		and plot_over_machine[&"candidate"] == machine_farm
		and not plot_on_x_lane[&"ok"] and plot_on_x_lane[&"reason"] == &"not_tillable"
		and plot_on_x_lane[&"candidate"] == supplied
		and not plot_on_y_lane[&"ok"] and plot_on_y_lane[&"reason"] == &"not_tillable"
		and plot_on_y_lane[&"candidate"] == supplied,
	)
	var grown: Dictionary = planted[&"candidate"] as Dictionary
	for _day: int in 20:
		grown = OrchardServiceScript.advance_day(grown)
	var mature: Dictionary = OrchardServiceScript.tree_at(grown, TREE_CELL)
	var harvested: Dictionary = OrchardServiceScript.harvest(
		grown, StringName(str(mature[&"tree_id"]))
	)
	var harvest_replay_preview: Dictionary = OrchardServiceScript.harvest(
		harvested[&"candidate"], StringName(str(mature[&"tree_id"]))
	)
	_add(
		cases,
		"P10 trees mature deterministically harvest once and regrow without being destroyed",
		OrchardCatalogScript.is_mature(
			OrchardCatalogScript.CINDERAPPLE, int(mature[&"growth_points"])
		)
		and harvested[&"ok"] and int(harvested[&"yield_count"]) >= 3
		and not harvest_replay_preview[&"ok"]
		and not OrchardServiceScript.tree_at(
			harvested[&"candidate"], TREE_CELL
		).is_empty(),
	)
	var young: Dictionary = OrchardServiceScript.plant(
		supplied, Vector2i(11, 7), &"item.sapling.ironbark", 1,
		func(_cell: Vector2i) -> bool: return true,
	)
	var young_tree: Dictionary = OrchardServiceScript.tree_at(young[&"candidate"], Vector2i(11, 7))
	var lifted: Dictionary = OrchardServiceScript.remove_immature(
		young[&"candidate"], StringName(str(young_tree[&"tree_id"]))
	)
	var protected: Dictionary = OrchardServiceScript.remove_immature(
		grown, StringName(str(mature[&"tree_id"]))
	)
	_add(
		cases,
		"P10 only young saplings can be safely lifted and mature trees remain protected",
		lifted[&"ok"] and OrchardServiceScript.tree_at(
			lifted[&"candidate"], Vector2i(11, 7)
		).is_empty()
		and not protected[&"ok"] and protected[&"reason"] == &"mature_tree_protected",
	)
	var tree_commit: Dictionary = _commit_farm(transactions, farm_runtime, grown)
	_add(
		cases,
		"P10 committed orchard trees block player movement at their occupied cell",
		tree_commit[&"ok"] and not runtime.is_walkable(TREE_CELL),
	)
	var live_records: Array[Dictionary] = bridge.call("get_live_presentation_records")
	var tree_records: Array[Dictionary] = _records_with_id(live_records, str(mature[&"tree_id"]))
	var renderer: Node = bridge.call("get_farm_renderer") as Node
	_add(
		cases,
		"P10 committed orchard presentation is public batched state with no per-tree nodes",
		tree_records.size() == 1 and tree_records[0].has(&"atlas_region")
		and renderer.get_child_count() == 0,
	)
	var tree_target: Dictionary = SeasonalProviderScript.tree(grown, TREE_CELL, mature)
	var fish_target: Dictionary = SeasonalProviderScript.water(
		supplied,
		WoodlandClearingScript.POND_CELL,
		{&"water_class": &"freshwater_pond"},
		SEED,
	)
	_add(
		cases,
		"P10 sealed tree and pond targets expose inspect harvest remove cast and bait choices",
		_action_ids(tree_target).has(&"interaction.action.tree_harvest")
		and _action_ids(tree_target).has(&"interaction.action.tree_remove")
		and _action_ids(fish_target).has(&"interaction.action.fish_cast")
		and _action_ids(fish_target).has(&"interaction.action.fish_cast_bait"),
	)
	_add(
		cases,
		"P10 tree action previews match committed context-tool stamina costs exactly",
		_tree_costs_match(tree_target, grown),
	)
	_tree_exact_once_cases(cases, transactions, farm_runtime)
	_fishing_cases(cases, supplied)
	_exact_once_case(cases, transactions, farm_runtime, supplied)
	var records: Dictionary = OrchardServiceScript.build_chunk_indexes(grown)
	var record_count: int = 0
	for chunk: Variant in records:
		record_count += (records[chunk] as Array).size()
	_add(
		cases,
		"P10 orchard presentation is node-free batched atlas rendering",
		record_count == 1 and runtime.find_children("*", "Node", true, false).size() > 0
		and not (records.values()[0] as Array).is_empty()
		and (records.values()[0] as Array)[0].has(&"atlas_region"),
	)
	_ten_year_soak(cases, supplied)
	return cases


static func evaluate_reloaded(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	_add(
		cases,
		"P10 committed seasonal state cold-reloads with canonical schema and hash",
		not FarmSchemaScript.validate(farm).is_empty()
		and not (farm[&"fishing"][&"spots"] as Array).is_empty(),
	)
	return cases


static func _crop_season_cases(cases: Array[Dictionary], base: Dictionary) -> void:
	var winter: Dictionary = base.duplicate(true)
	(winter[&"calendar_weather"] as Dictionary)[&"season_id"] = "season.winter"
	var tilled: Dictionary = FarmStateScript.till(winter, Vector2i(10, 8))
	var planted: Dictionary = FarmStateScript.plant(
		tilled[&"candidate"], Vector2i(10, 8), &"item.seed.glowroot", 1
	)
	var watered: Dictionary = FarmStateScript.water(planted[&"candidate"], Vector2i(10, 8), 1)
	var dormant: Dictionary = FarmStateScript.grow(watered[&"candidate"], 1)
	var dormant_plot: Dictionary = FarmStateScript.plot_at(dormant, Vector2i(10, 8))
	(dormant[&"calendar_weather"] as Dictionary)[&"season_id"] = "season.spring"
	var spring_water: Dictionary = FarmStateScript.water(dormant, Vector2i(10, 8), 2)
	var favored: Dictionary = FarmStateScript.grow(spring_water[&"candidate"], 2)
	var favored_plot: Dictionary = FarmStateScript.plot_at(favored, Vector2i(10, 8))
	_add(
		cases,
		"P10 out-of-season crops survive dormant and resume accelerated favored growth",
		bool(dormant_plot[&"dormant"]) and int(dormant_plot[&"growth_points"]) == 0
		and not bool(favored_plot[&"dormant"])
		and int(favored_plot[&"growth_points"]) == 2,
	)


static func _fishing_cases(cases: Array[Dictionary], source: Dictionary) -> void:
	source = _with_inventory_headroom(source)
	var first: Dictionary = FishingServiceScript.cast(
		source, FishingCatalogScript.WOODLAND_POND, 1, SEED, false
	)
	var repeated: Dictionary = FishingServiceScript.cast(
		source, FishingCatalogScript.WOODLAND_POND, 1, SEED, false
	)
	var current: Dictionary = source
	for _cast: int in 4:
		var cast_result: Dictionary = FishingServiceScript.cast(
			current, FishingCatalogScript.WOODLAND_POND, 1, SEED, false
		)
		current = cast_result[&"candidate"] as Dictionary
	var depleted: Dictionary = FishingServiceScript.cast(
		current, FishingCatalogScript.WOODLAND_POND, 1, SEED, false
	)
	var renewed: Dictionary = FishingServiceScript.advance_day(current, 2)
	var after_renewal: Dictionary = FishingServiceScript.cast(
		renewed, FishingCatalogScript.WOODLAND_POND, 2, SEED, true
	)
	var partial_renewal: Dictionary = FishingServiceScript.advance_day(
		first[&"candidate"], 2
	)
	var partial_state: Dictionary = FishingServiceScript.spot_snapshot(
		partial_renewal, FishingCatalogScript.WOODLAND_POND, 2
	)
	var no_bait: Dictionary = InventoryScript.remove_across(
		source, FishingServiceScript.BAIT_ITEM,
		InventoryScript.count_all(source, FishingServiceScript.BAIT_ITEM),
	)[&"candidate"]
	var missing_bait: Dictionary = FishingServiceScript.cast(
		no_bait, FishingCatalogScript.WOODLAND_POND, 1, SEED, true
	)
	var full_inventory: Dictionary = _with_full_inventories(source)
	var blocked: Dictionary = FishingServiceScript.cast(
		full_inventory, FishingCatalogScript.WOODLAND_POND, 1, SEED, false
	)
	var bait_changed: bool = _bait_changes_pool(source)
	_add(
		cases,
		"P10 deterministic fishing repeats identity, depletes safely, renews, and consumes bait",
		first[&"ok"] and repeated[&"ok"] and first[&"fish_id"] == repeated[&"fish_id"]
		and not depleted[&"ok"] and depleted[&"reason"] == &"fishing_spot_depleted"
		and after_renewal[&"ok"] and after_renewal[&"bait_used"]
			and InventoryScript.count_all(
				after_renewal[&"candidate"], FishingServiceScript.BAIT_ITEM
			) == InventoryScript.count_all(renewed, FishingServiceScript.BAIT_ITEM) - 1
			and int(partial_state[&"remaining_catches"]) == 4
			and int(partial_state[&"cast_sequence"]) == 1,
	)
	_add(
		cases,
		"P10 bait changes deterministic weights and failures roll back all fishing state",
			bait_changed
		and not missing_bait[&"ok"] and missing_bait[&"reason"] == &"missing_fishing_bait"
		and missing_bait[&"candidate"] == no_bait
		and not blocked[&"ok"] and blocked[&"reason"] == &"inventory_full"
		and blocked[&"candidate"] == full_inventory,
	)


static func _exact_once_case(
	cases: Array[Dictionary],
	transactions: RefCounted,
	farm_runtime: RefCounted,
	supplied: Dictionary,
) -> void:
	var committed: Dictionary = _commit_farm(transactions, farm_runtime, supplied)
	var farm: Dictionary = committed[&"candidate"][&"farm"]
	var revision: int = int((farm[&"revisions"] as Dictionary)[&"result_revision"])
	var arguments: Dictionary = {
		&"spot_id": FishingCatalogScript.WOODLAND_POND,
		&"use_bait": false,
		&"expected_revision": revision,
	}
	var payload: Dictionary = {&"operation": "fish_cast", &"test": "p10"}
	var deterministic: Dictionary = {&"result_id": "fish.result.p10"}
	var first: Dictionary = transactions.call(
		"transact_exact_once", &"fish_cast", arguments,
		"fish:p10:cast.1", payload, deterministic,
	)
	var replay: Dictionary = transactions.call(
		"transact_exact_once", &"fish_cast", arguments,
		"fish:p10:cast.1", payload, deterministic,
	)
	var conflict_payload: Dictionary = payload.duplicate(true)
	conflict_payload[&"test"] = "conflict"
	var conflict: Dictionary = transactions.call(
		"transact_exact_once", &"fish_cast", arguments,
		"fish:p10:cast.1", conflict_payload, deterministic,
	)
	var stale: Dictionary = transactions.call(
		"transact_exact_once", &"fish_cast", arguments,
		"fish:p10:cast.2", {&"operation": "fish_cast", &"test": "stale"},
		{&"result_id": "fish.result.p10.stale"},
	)
	if bool(first[&"ok"]):
		farm_runtime.call("sync_committed", first[&"candidate"][&"farm"])
	_add(
		cases,
		"P10 fishing receipt replays exactly once and rejects conflicting token reuse",
		first[&"ok"] and replay[&"ok"] and replay[&"replayed"]
		and replay[&"candidate"] == first[&"candidate"]
		and not conflict[&"ok"] and conflict[&"reason"] == &"conflict"
		and not stale[&"ok"] and stale[&"reason"] == &"stale_seasonal_revision",
	)


static func _tree_exact_once_cases(
	cases: Array[Dictionary], transactions: RefCounted, farm_runtime: RefCounted
) -> void:
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var tree: Dictionary = OrchardServiceScript.tree_at(farm, TREE_CELL)
	var harvest: Dictionary = _exercise_receipt(
		transactions,
		&"tree_harvest",
		{
			&"tree_id": StringName(str(tree[&"tree_id"])),
			&"expected_revision": _revision(farm),
		},
		"tree:p10:harvest.1",
	)
	_add(cases, "P10 tree harvest is exact-once replay-safe", _receipt_case_passes(harvest))
	if not bool((harvest[&"first"] as Dictionary)[&"ok"]):
		return
	farm = (harvest[&"first"] as Dictionary)[&"candidate"][&"farm"]
	farm_runtime.call("sync_committed", farm)
	var plant: Dictionary = _exercise_receipt(
		transactions,
		&"tree_plant",
		{
			&"cell": Vector2i(11, 7),
			&"sapling_item_id": &"item.sapling.ironbark",
			&"expected_revision": _revision(farm),
		},
		"tree:p10:plant.1",
	)
	_add(cases, "P10 tree planting is exact-once replay-safe", _receipt_case_passes(plant))
	if not bool((plant[&"first"] as Dictionary)[&"ok"]):
		return
	farm = (plant[&"first"] as Dictionary)[&"candidate"][&"farm"]
	farm_runtime.call("sync_committed", farm)
	var young: Dictionary = OrchardServiceScript.tree_at(farm, Vector2i(11, 7))
	var remove: Dictionary = _exercise_receipt(
		transactions,
		&"tree_remove",
		{
			&"tree_id": StringName(str(young[&"tree_id"])),
			&"expected_revision": _revision(farm),
		},
		"tree:p10:remove.1",
	)
	_add(cases, "P10 young-tree lifting is exact-once replay-safe", _receipt_case_passes(remove))
	if bool((remove[&"first"] as Dictionary)[&"ok"]):
		farm_runtime.call("sync_committed", (remove[&"first"] as Dictionary)[&"candidate"][&"farm"])


static func _exercise_receipt(
	transactions: RefCounted,
	operation: StringName,
	arguments: Dictionary,
	token: String,
) -> Dictionary:
	var payload: Dictionary = {&"operation": str(operation), &"test": token}
	var deterministic: Dictionary = {&"result_id": "%s.result" % token}
	var first: Dictionary = transactions.call(
		"transact_exact_once", operation, arguments, token, payload, deterministic
	)
	var replay: Dictionary = transactions.call(
		"transact_exact_once", operation, arguments, token, payload, deterministic
	)
	var conflict_payload: Dictionary = payload.duplicate(true)
	conflict_payload[&"test"] = "%s.conflict" % token
	var conflict: Dictionary = transactions.call(
		"transact_exact_once", operation, arguments, token, conflict_payload, deterministic
	)
	var stale: Dictionary = transactions.call(
		"transact_exact_once", operation, arguments, "%s.stale" % token,
		{&"operation": str(operation), &"test": "%s.stale" % token},
		{&"result_id": "%s.stale" % deterministic[&"result_id"]},
	)
	return {&"first": first, &"replay": replay, &"conflict": conflict, &"stale": stale}


static func _receipt_case_passes(results: Dictionary) -> bool:
	var first: Dictionary = results[&"first"] as Dictionary
	var replay: Dictionary = results[&"replay"] as Dictionary
	var conflict: Dictionary = results[&"conflict"] as Dictionary
	var stale: Dictionary = results[&"stale"] as Dictionary
	return (
		bool(first[&"ok"])
		and bool(replay[&"ok"])
		and bool(replay[&"replayed"])
		and replay[&"candidate"] == first[&"candidate"]
		and not bool(conflict[&"ok"])
		and conflict[&"reason"] == &"conflict"
		and not bool(stale[&"ok"])
		and stale[&"reason"] == &"stale_seasonal_revision"
	)


static func _revision(farm: Dictionary) -> int:
	return int((farm[&"revisions"] as Dictionary)[&"result_revision"])


static func _ten_year_soak(cases: Array[Dictionary], source: Dictionary) -> void:
	var farm: Dictionary = OrchardServiceScript.plant(
		source, TREE_CELL, &"item.sapling.ironbark", 1,
		func(_cell: Vector2i) -> bool: return true,
	)[&"candidate"]
	for _day: int in 559:
		farm = OrchardServiceScript.advance_day(farm)
		farm = CalendarScript.advance_calendar(farm, SEED)
		farm = FishingServiceScript.advance_day(
			farm, CalendarScript.absolute_day(farm[&"calendar_weather"])
		)
	var tree: Dictionary = OrchardServiceScript.tree_at(farm, TREE_CELL)
	var normalized: Dictionary = FarmSchemaScript.validate(farm)
	_add(
		cases,
		"P10 ten-year seasonal soak stays bounded deterministic and schema-valid",
		int(tree[&"growth_points"]) == 18
		and not normalized.is_empty()
		and (farm[&"fishing"][&"spots"] as Array).size() <= 3,
	)


static func _with_items(farm: Dictionary, items: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	for item_id: StringName in items:
		var credited: Dictionary = InventoryScript.credit_with_overflow(
			candidate, item_id, int(items[item_id])
		)
		if bool(credited[&"ok"]):
			candidate = credited[&"candidate"] as Dictionary
	return candidate


static func _commit_farm(
	transactions: RefCounted, farm_runtime: RefCounted, farm: Dictionary
) -> Dictionary:
	var committed: Dictionary = transactions.call(
		"transact", &"farm_candidate", {&"farm": farm}
	) as Dictionary
	if bool(committed[&"ok"]):
		farm_runtime.call("sync_committed", committed[&"candidate"][&"farm"])
	return committed


static func _quick_accepts(operations: Array[StringName]) -> bool:
	for operation: StringName in operations:
		var option: Dictionary = {
			&"action_id": StringName("interaction.action.%s" % str(operation)),
			&"operation": operation,
			&"cost_preview": [],
			&"affected_cells": [Vector2i.ZERO],
			&"close_behavior": &"close_on_success",
		}
		if QuickPolicyScript.is_low_risk(option):
			return true
	return false


static func _action_ids(target: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for option: Dictionary in target.get(&"option_inputs", []) as Array[Dictionary]:
		result.append(option[&"action_id"] as StringName)
	return result


static func _operation_descriptor(operation: StringName) -> Dictionary:
	for descriptor: Dictionary in OperationCatalogScript.descriptors():
		if descriptor[&"operation"] == operation:
			return descriptor.duplicate(true)
	return {}


static func _water_class(
	cell: Vector2i, is_pond: bool, biome_id: StringName
) -> StringName:
	var description: Dictionary = PhaseBScript.stable_feature_description(
		cell, FarmSchemaScript.make_neutral(), is_pond, biome_id
	)
	return StringName(str((description.get(&"state", {}) as Dictionary).get(&"water_class", "")))


static func _impossible_orchards_rejected() -> bool:
	var definition: Dictionary = OrchardCatalogScript.definition(OrchardCatalogScript.IRONBARK)
	var mature: int = int((definition[&"growth_thresholds"] as Array)[3])
	var impossible_growth: Dictionary = SectionsScript.neutral_orchard()
	impossible_growth[&"trees"] = [{
		&"tree_id": "tree.bad.growth", &"species_id": str(OrchardCatalogScript.IRONBARK),
		&"cell": [10, 7], &"planted_day": 1,
		&"growth_points": mature + 1, &"harvest_sequence": 0,
	}]
	var too_many: Dictionary = SectionsScript.neutral_orchard()
	var records: Array[Dictionary] = []
	for index: int in SectionsScript.MAX_TREES + 1:
		records.append({
			&"tree_id": "tree.bad.count.%02d" % index,
			&"species_id": str(OrchardCatalogScript.IRONBARK),
			&"cell": [index, 0], &"planted_day": 1,
			&"growth_points": 0, &"harvest_sequence": 0,
		})
	too_many[&"trees"] = records
	var occupied: Dictionary = FarmSchemaScript.make_neutral()
	(occupied[&"orchard"] as Dictionary)[&"trees"] = [{
		&"tree_id": "tree.bad.cell", &"species_id": str(OrchardCatalogScript.IRONBARK),
		&"cell": [6, 7], &"planted_day": 1,
		&"growth_points": 0, &"harvest_sequence": 0,
	}]
	return (
		SectionsScript.validate_orchard(impossible_growth).is_empty()
		and SectionsScript.validate_orchard(too_many).is_empty()
		and FarmSchemaScript.validate(occupied).is_empty()
	)


static func _tree_costs_match(target: Dictionary, farm: Dictionary) -> bool:
	var expected: int = ToolScript.stamina_cost(farm, ToolScript.TOOL_CONTEXT)
	var matched: int = 0
	for option: Dictionary in target.get(&"option_inputs", []) as Array[Dictionary]:
		if option.get(&"operation") not in [&"tree_harvest", &"tree_remove"]:
			continue
		for cost: Dictionary in option.get(&"cost_preview", []) as Array[Dictionary]:
			if cost[&"cost_id"] == &"tool.stamina" and int(cost[&"amount"]) == expected:
				matched += 1
	return matched == 2


static func _bait_changes_pool(source: Dictionary) -> bool:
	for seed: int in range(1, 128):
		var plain: Dictionary = FishingServiceScript.cast(
			source, FishingCatalogScript.WOODLAND_POND, 1, seed, false
		)
		var baited: Dictionary = FishingServiceScript.cast(
			source, FishingCatalogScript.WOODLAND_POND, 1, seed, true
		)
		if plain[&"ok"] and baited[&"ok"] and plain[&"fish_id"] != baited[&"fish_id"]:
			return true
	return false


static func _with_full_inventories(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var ids: Array[StringName] = ItemCatalogScript.ids()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	var fill_ids: Array[StringName] = []
	for item_id: StringName in ids:
		if item_id != FishingServiceScript.ROD_ITEM:
			fill_ids.append(item_id)
	for inventory: Dictionary in candidate[&"inventories"] as Array[Dictionary]:
		var stacks: Array[Dictionary] = []
		var capacity: int = int(inventory[&"capacity_slots"])
		var is_robot: bool = inventory[&"container_id"] == InventoryScript.ROBOT_ID
		if is_robot:
			stacks.append({
				&"item_id": str(FishingServiceScript.ROD_ITEM), &"count": 1,
			})
		var fill_count: int = capacity - stacks.size()
		var offset: int = 0 if capacity > InventoryScript.ROBOT_SLOTS else fill_ids.size() - fill_count
		for slot: int in fill_count:
			var item_id: StringName = fill_ids[offset + slot]
			stacks.append({
				&"item_id": str(item_id), &"count": ItemCatalogScript.stack_limit(item_id),
			})
		inventory[&"stacks"] = stacks
	return candidate


static func _with_inventory_headroom(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	for inventory: Dictionary in candidate[&"inventories"] as Array[Dictionary]:
		if inventory[&"container_id"] == InventoryScript.ROBOT_ID:
			inventory[&"capacity_slots"] = mini(
			FarmSchemaScript.MAX_STACKS_PER_INVENTORY,
			maxi(int(inventory[&"capacity_slots"]), (inventory[&"stacks"] as Array).size() + 4),
			)
	return candidate


static func _records_with_id(records: Array[Dictionary], stable_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in records:
		if str(record.get(&"stable_id", "")) == stable_id:
			result.append(record)
	return result


static func _contains_all(haystack: Array[String], needles: Array[String]) -> bool:
	for needle: String in needles:
		if needle not in haystack:
			return false
	return true


static func _locale_keys(path: String) -> Array[String]:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var keys: Array[String] = []
	if parsed is Dictionary:
		for raw_key: Variant in parsed:
			keys.append(str(raw_key))
	keys.sort()
	return keys


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
