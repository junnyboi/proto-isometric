extends RefCounted

const CalendarScript: GDScript = preload("res://scripts/calendar_state.gd")
const CatalogScript: GDScript = preload("res://scripts/resource_deposit_catalog.gd")
const ConstructionCatalogScript: GDScript = preload(
	"res://scripts/construction_blueprint_catalog.gd"
)
const ConstructionProviderScript: GDScript = preload(
	"res://scripts/construction_interaction_provider.gd"
)
const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const GatheringScript: GDScript = preload("res://scripts/gathering_state_service.gd")
const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const InventoryScript: GDScript = preload("res://scripts/inventory_service.gd")
const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const OptionCatalogScript: GDScript = preload("res://scripts/interaction_option_catalog.gd")
const BudgetScript: GDScript = preload("res://scripts/persistence_budget_catalog.gd")
const PresentationCatalogScript: GDScript = preload(
	"res://scripts/resource_deposit_presentation_catalog.gd"
)
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const DeltaValidatorScript: GDScript = preload(
	"res://scripts/resource_deposit_delta_validator.gd"
)
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")
const ToolScript: GDScript = preload("res://scripts/tool_service.gd")

const SEED: int = 0x48415256
const GOLDEN_DIGEST: String = "e86faa9463629e2b9bd990b9b30fc0c542d267b70a38aeeeec286a1ab4a6f221"
const SALVAGE_CELL: Vector2i = Vector2i(2, 6)
const MINERAL_CELL: Vector2i = Vector2i(15, 6)
const BIOMASS_CELL: Vector2i = Vector2i(2, 15)
const ASSET_PATHS: Array[String] = [
	"res://assets/settlement/deposits/deposit_salvage_cluster_states.png",
	"res://assets/settlement/deposits/deposit_mineral_seam_states.png",
	"res://assets/settlement/deposits/deposit_biomass_patch_states.png",
]
const ASSET_HASHES: Dictionary = {
	ASSET_PATHS[0]: "d2bb436ce20ea8ae78f06925a8923cf94c25700310958a72cd3e331c90fa3d52",
	ASSET_PATHS[1]: "918b14961a5d1e45af6fbacc7e69657a069243cab75c7a40840768625dc91f21",
	ASSET_PATHS[2]: "a3540c66665aaab69861dccd318a8547b46e71a89ff91b6d7ebde38da2ca2627",
}


static func evaluate_contracts() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_catalog_cases(cases)
	_asset_cases(cases)
	return cases


static func evaluate(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_catalog_cases(cases)
	_asset_cases(cases)
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var phase_b: RefCounted = bridge.call("get_interaction_phase_b_service") as RefCounted
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var transactions: RefCounted = bridge.call("get_transaction_boundary") as RefCounted
	var world: RefCounted = runtime.get("_world") as RefCounted
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var salvage: Dictionary = world.call("_resource_source_at", SALVAGE_CELL) as Dictionary
	var mineral: Dictionary = world.call("_resource_source_at", MINERAL_CELL) as Dictionary
	var biomass: Dictionary = world.call("_resource_source_at", BIOMASS_CELL) as Dictionary
	_add(
		cases,
		"P5 starter clearing exposes one source of each original deposit family",
		not salvage.is_empty() and not mineral.is_empty() and not biomass.is_empty(),
	)
	_add(
		cases,
		"P5 projected sources block walking and construction occupancy",
		not bool(world.call("is_walkable", SALVAGE_CELL))
		and not bool(world.call("is_walkable", MINERAL_CELL))
		and not bool(world.call("is_walkable", BIOMASS_CELL)),
	)
	var wrong_projection: Dictionary = phase_b.call("project", SALVAGE_CELL, ToolScript.TOOL_HOE)
	var wrong_menu: Dictionary = OptionCatalogScript.build_menu(wrong_projection)
	_add(
		cases,
		"P5 wrong tools keep Gather visible but disabled with a truthful reason",
		_has_action(wrong_menu, &"interaction.action.gather_deposit")
		and not _option_enabled(wrong_menu, &"interaction.action.gather_deposit")
		and _option_reason(wrong_menu, &"interaction.action.gather_deposit")
		== &"interaction.reason.requires_pick",
	)
	var first_projection: Dictionary = phase_b.call(
		"project", SALVAGE_CELL, ToolScript.TOOL_PICK
	) as Dictionary
	var first_menu: Dictionary = OptionCatalogScript.build_menu(first_projection)
	var first_option: Dictionary = _option(first_menu, &"interaction.action.gather_deposit")
	_add(
		cases,
		"P5 E-terminal exposes Inspect and enabled Gather for a compatible tool",
		_has_action(first_menu, &"interaction.action.inspect_deposit")
		and _option_enabled(first_menu, &"interaction.action.gather_deposit"),
	)
	var item_before: int = InventoryScript.count_all(farm, &"item.material.scrap")
	var stamina_before: int = int((farm[&"tools"] as Dictionary)[&"stamina"])
	var receipts_before: int = ((farm[&"receipts"] as Dictionary)[&"entries"] as Array).size()
	var gathered: Array[Dictionary] = []
	for _index: int in 4:
		var menu: Dictionary = OptionCatalogScript.build_menu(
			phase_b.call("project", SALVAGE_CELL, ToolScript.TOOL_PICK) as Dictionary
		)
		gathered.append(
			phase_b.call(
				"execute", ResolverScript.ACTION_CONTEXT, ToolScript.TOOL_PICK,
				_resolved(SALVAGE_CELL, _option(menu, &"interaction.action.gather_deposit")),
				_option(menu, &"interaction.action.gather_deposit"),
			) as Dictionary
		)
	var after_four: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var four_state: Dictionary = GatheringScript.effective(
		after_four, salvage, CalendarScript.absolute_day(after_four[&"calendar_weather"])
	)
	_add(
		cases,
		"P5 exactly four Gather commands yield four receipts rewards costs and charges",
		_all_ok(gathered)
		and InventoryScript.count_all(after_four, &"item.material.scrap") == item_before + 8
		and int((after_four[&"tools"] as Dictionary)[&"stamina"])
		== stamina_before - 4 * ToolScript.stamina_cost(farm, ToolScript.TOOL_PICK)
		and ((after_four[&"receipts"] as Dictionary)[&"entries"] as Array).size()
		== receipts_before + 4
		and int(four_state[&"remaining_charges"]) == 2
		and ((after_four[&"gathering"] as Dictionary)[&"resource_deltas"] as Array).size() == 1,
	)
	var stale: Dictionary = phase_b.call(
		"execute", ResolverScript.ACTION_CONTEXT, ToolScript.TOOL_PICK,
		_resolved(SALVAGE_CELL, first_option), first_option,
	) as Dictionary
	_add(
		cases,
		"P5 stale sealed Gather options fail before mutation",
		not bool(stale[&"ok"]) and stale[&"reason"] == &"stale_target_identity",
	)
	_replay_case(cases, bridge, phase_b)
	for _index: int in 2:
		var menu: Dictionary = OptionCatalogScript.build_menu(
			phase_b.call("project", SALVAGE_CELL, ToolScript.TOOL_PICK) as Dictionary
		)
		phase_b.call(
			"execute", ResolverScript.ACTION_CONTEXT, ToolScript.TOOL_PICK,
			_resolved(SALVAGE_CELL, _option(menu, &"interaction.action.gather_deposit")),
			_option(menu, &"interaction.action.gather_deposit"),
		)
	var exhausted_farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var exhausted: Dictionary = GatheringScript.effective(
		exhausted_farm,
		salvage,
		CalendarScript.absolute_day(exhausted_farm[&"calendar_weather"]),
	)
	var exhausted_menu: Dictionary = OptionCatalogScript.build_menu(
		phase_b.call("project", SALVAGE_CELL, ToolScript.TOOL_PICK) as Dictionary
	)
	_add(
		cases,
		"P5 finite salvage reaches persistent exhaustion and disables further Gather",
		int(exhausted[&"remaining_charges"]) == 0
		and exhausted[&"phase"] == &"exhausted"
		and not _option_enabled(exhausted_menu, &"interaction.action.gather_deposit")
		and _option_reason(exhausted_menu, &"interaction.action.gather_deposit")
		== &"interaction.reason.deposit_exhausted",
	)
	_reservation_cases(cases, exhausted_farm, mineral)
	_renewal_cases(cases, exhausted_farm, biomass)
	var slept: Dictionary = farm_runtime.call("transact", &"sleep", {}) as Dictionary
	var after_sleep: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var finite_after_sleep: Dictionary = GatheringScript.effective(
		after_sleep, salvage, CalendarScript.absolute_day(after_sleep[&"calendar_weather"])
	)
	_add(
		cases,
		"P5 ordinary sleep never regenerates finite deposits",
		slept[&"ok"] and int(finite_after_sleep[&"remaining_charges"]) == 0,
	)
	_soak_case(cases, after_sleep, biomass)
	var orphan_farm: Dictionary = after_sleep.duplicate(true)
	var orphan_section: Dictionary = orphan_farm[&"gathering"] as Dictionary
	var orphan_deltas: Array = (orphan_section[&"resource_deltas"] as Array).duplicate(true)
	var orphan_cell: Vector2i = _empty_projected_cell()
	orphan_deltas.append(
		{
			&"source_id": str(CatalogScript.canonical_source_id(CatalogScript.SALVAGE, orphan_cell)),
			&"remaining_charges": 5, &"renewal_day": 0, &"reserved_by": "",
		}
	)
	orphan_deltas.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"source_id"]) < str(b[&"source_id"])
	)
	orphan_section[&"resource_deltas"] = orphan_deltas
	orphan_farm[&"gathering"] = orphan_section
	var orphan_result: Dictionary = GatheringScript.advance_day(
		orphan_farm, SEED, CalendarScript.absolute_day(after_sleep[&"calendar_weather"]) + 1
	)
	_add(
		cases,
		"P5 dawn compaction rejects orphan sparse deltas",
		not orphan_result[&"ok"] and orphan_result[&"reason"] == &"orphan_resource_delta",
	)
	var suppressed: Dictionary = _suppressed_projected_source(world)
	var collision_farm: Dictionary = after_sleep.duplicate(true)
	var collision_section: Dictionary = collision_farm[&"gathering"] as Dictionary
	var collision_deltas: Array = (
		(collision_section[&"resource_deltas"] as Array).duplicate(true)
	)
	collision_deltas.append(
		{
			&"source_id": str(suppressed[&"source_id"]),
			&"remaining_charges": int(suppressed[&"capacity"]) - 1,
			&"renewal_day": 0, &"reserved_by": "",
		}
	)
	collision_deltas.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"source_id"]) < str(b[&"source_id"])
	)
	collision_section[&"resource_deltas"] = collision_deltas
	collision_farm[&"gathering"] = collision_section
	var collision_result: Dictionary = GatheringScript.advance_day(
		collision_farm,
		SEED,
		CalendarScript.absolute_day(after_sleep[&"calendar_weather"]) + 1,
		Callable(world, "_resource_source_at"),
	)
	_add(
		cases,
		"P5 dawn rejects deltas for catalog sources suppressed by live-world blockers",
		bool(suppressed.get(&"test_suppressed", false))
		and not collision_result[&"ok"]
		and collision_result[&"reason"] == &"orphan_resource_delta",
	)
	var dirty_cells: Array[Vector2i] = [SALVAGE_CELL, MINERAL_CELL, BIOMASS_CELL]
	bridge.call("_refresh_render_indexes", dirty_cells)
	var renderer: Node2D = bridge.call("get_farm_renderer") as Node2D
	_add(
		cases,
		"P5 visible deposits use node-free batched records with stable IDs",
		_deposit_record_count(renderer.call("get_visible_records") as Array[Dictionary]) >= 3,
	)
	var camp_record: Dictionary = _complete_camp_record()
	var camp_projection: Dictionary = ConstructionProviderScript.building(
		after_sleep, SALVAGE_CELL, camp_record
	)
	var camp_menu: Dictionary = OptionCatalogScript.build_menu(camp_projection)
	_add(
		cases,
		"P5 completed extraction camps expose a nonmutating source-range preview",
		_has_action(camp_menu, &"interaction.action.preview_extraction_range"),
	)
	_add(
		cases,
		"P5 all live commits retain validator-valid schema-5 farm state",
		not FarmSchemaScript.validate(after_sleep).is_empty()
		and not (transactions.call("get_snapshot") as Dictionary).is_empty(),
	)
	return cases


static func evaluate_reloaded(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var world: RefCounted = runtime.get("_world") as RefCounted
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var source: Dictionary = world.call("_resource_source_at", SALVAGE_CELL) as Dictionary
	var state: Dictionary = GatheringScript.effective(
		farm, source, CalendarScript.absolute_day(farm[&"calendar_weather"])
	)
	_add(
		cases,
		"P5 cold reload restores finite exhaustion from its sparse delta",
		int(state[&"remaining_charges"]) == 0
		and state[&"phase"] == &"exhausted"
		and _has_delta(farm, str(source[&"source_id"]), 0),
	)
	return cases


static func _catalog_cases(cases: Array[Dictionary]) -> void:
	_add(cases, "P5 original three-source catalog validates", CatalogScript.validate())
	var first: String = CatalogScript.golden_digest(SEED)
	var second: String = CatalogScript.golden_digest(SEED)
	_add(
		cases,
		"P5 SHA-256 projection is deterministic and seed-sensitive",
		first == GOLDEN_DIGEST
		and first == second
		and first != CatalogScript.golden_digest(SEED + 1),
	)
	var sources: Array[Dictionary] = _projected_sources(SEED)
	_add(
		cases,
		"P5 projected source density remains below the 256-delta persistence cap",
		sources.size() <= CatalogScript.MAX_PROJECTED_SOURCES
		and sources.size() < SectionsScript.MAX_RESOURCE_DELTAS,
	)
	var seed_corpus_valid: bool = true
	for seed: int in [-2_147_483_648, -1, 0, 1, SEED, 2_147_483_647]:
		var count: int = _projected_sources(seed).size()
		seed_corpus_valid = seed_corpus_valid and count <= CatalogScript.MAX_PROJECTED_SOURCES
	_add(
		cases,
		"P5 projected density bound holds across representative extreme seeds",
		seed_corpus_valid,
	)
	var unique: Dictionary = {}
	for source: Dictionary in sources:
		unique[source[&"source_id"]] = true
	_add(
		cases,
		"P5 projected source IDs are unique canonical and cell-reversible",
		unique.size() == sources.size() and _all_ids_round_trip(sources),
	)
	_add(
		cases,
		"P5 finite and managed policies keep distinct capacities and renewability",
		int(CatalogScript.definition(CatalogScript.SALVAGE)[&"capacity"]) == 6
		and int(CatalogScript.definition(CatalogScript.MINERAL)[&"capacity"]) == 8
		and not bool(CatalogScript.definition(CatalogScript.SALVAGE)[&"renewable"])
		and bool(CatalogScript.definition(CatalogScript.BIOMASS)[&"renewable"]),
	)
	var malformed: Dictionary = SectionsScript.neutral_gathering()
	malformed[&"resource_deltas"] = [
		{
			&"source_id": str(CatalogScript.project_at(BIOMASS_CELL, SEED)[&"source_id"]),
			&"remaining_charges": 0, &"renewal_day": 0, &"reserved_by": "",
		}
	]
	_add(
		cases,
		"P5 renewable exhaustion requires a positive renewal schedule",
		not DeltaValidatorScript.validate(malformed),
	)


static func _asset_cases(cases: Array[Dictionary]) -> void:
	var valid: bool = PresentationCatalogScript.validate()
	for path: String in ASSET_PATHS:
		var texture: Texture2D = load(path) as Texture2D
		valid = (
			valid
			and texture != null
			and texture.get_size() == Vector2(768, 256)
			and FileAccess.get_sha256(path) == str(ASSET_HASHES[path])
		)
	_add(
		cases,
		"P5 GPT Image 2 deposit atlases match authorized hashes and dimensions",
		valid,
	)


static func _replay_case(
	cases: Array[Dictionary], bridge: Node, phase_b: RefCounted
) -> void:
	var transactions: RefCounted = bridge.call("get_transaction_boundary") as RefCounted
	var menu: Dictionary = OptionCatalogScript.build_menu(
		phase_b.call("project", MINERAL_CELL, ToolScript.TOOL_PICK) as Dictionary
	)
	var option: Dictionary = _option(menu, &"interaction.action.gather_deposit")
	var arguments: Dictionary = (option[&"arguments"] as Dictionary).duplicate(true)
	var before: Dictionary = transactions.call("get_snapshot") as Dictionary
	var before_farm: Dictionary = before[&"farm"] as Dictionary
	var revision: int = int((before_farm[&"revisions"] as Dictionary)[&"result_revision"])
	var digest: String = CodecScript.digest(option)
	var token: String = "deposit:%d:%s" % [revision, digest.left(32)]
	var payload: Dictionary = {
		&"source_id": str(arguments[&"source_id"]), &"option_digest": digest,
		&"source_revision": revision,
	}
	var deterministic: Dictionary = {
		&"result_id": "deposit.result.%s" % digest.left(24),
		&"source_id": str(arguments[&"source_id"]), &"source_revision": revision,
	}
	var first: Dictionary = transactions.call(
		"transact_exact_once", &"deposit_gather", arguments, token, payload, deterministic
	) as Dictionary
	var replay: Dictionary = transactions.call(
		"transact_exact_once", &"deposit_gather", arguments, token, payload, deterministic
	) as Dictionary
	var after_farm: Dictionary = (replay[&"candidate"] as Dictionary)[&"farm"] as Dictionary
	var mineral: Dictionary = CatalogScript.project_at(MINERAL_CELL, SEED)
	var state: Dictionary = GatheringScript.effective(
		after_farm, mineral, CalendarScript.absolute_day(after_farm[&"calendar_weather"])
	)
	_add(
		cases,
		"P5 duplicate replay spends one charge and credits exactly once",
		first[&"ok"]
		and replay[&"ok"]
		and replay[&"replayed"]
		and int(state[&"remaining_charges"]) == int(mineral[&"capacity"]) - 1
		and InventoryScript.count_all(after_farm, &"item.ore.iron")
		== InventoryScript.count_all(before_farm, &"item.ore.iron") + 2
		and int((after_farm[&"tools"] as Dictionary)[&"stamina"])
		== int((before_farm[&"tools"] as Dictionary)[&"stamina"]) - 12
		and ((after_farm[&"receipts"] as Dictionary)[&"entries"] as Array).size()
		== ((before_farm[&"receipts"] as Dictionary)[&"entries"] as Array).size() + 1,
	)


static func _reservation_cases(
	cases: Array[Dictionary], farm: Dictionary, source: Dictionary
) -> void:
	var anchor: Vector2i = MINERAL_CELL + Vector2i(5, 0)
	var anchored: Dictionary = _farm_with_building(
		farm, "building.test.survey", ConstructionCatalogScript.SURVEY_DRILL,
		anchor, 1, "complete"
	)
	var day: int = CalendarScript.absolute_day(farm[&"calendar_weather"])
	var reserved: Dictionary = GatheringScript.set_reservation(
		anchored, source, day, "building.test.survey"
	)
	var manual: Dictionary = GatheringScript.gather(
		reserved[&"candidate"], source, day, &"manual", "protos"
	)
	var worker: Dictionary = GatheringScript.gather(
		reserved[&"candidate"], source, day, &"building", "building.test.survey"
	)
	_add(
		cases,
		"P5 reservations block manual extraction but permit the owning building",
		reserved[&"ok"]
		and not manual[&"ok"]
		and manual[&"reason"] == &"source_reserved"
		and worker[&"ok"],
	)
	var wrong: Dictionary = _farm_with_building(
		farm, "building.test.wrong", ConstructionCatalogScript.SALVAGE_CAMP,
		anchor, 1, "complete"
	)
	var far: Dictionary = _farm_with_building(
		farm, "building.test.far", ConstructionCatalogScript.SURVEY_DRILL,
		Vector2i(30, 30), 1, "complete"
	)
	var incomplete: Dictionary = _farm_with_building(
		farm, "building.test.incomplete", ConstructionCatalogScript.SURVEY_DRILL,
		anchor, 1, "constructing"
	)
	var tier_two: Dictionary = source.duplicate(true)
	tier_two[&"tier"] = 2
	_add(
		cases,
		"P5 reservation authority rejects wrong incomplete far unknown and low-tier buildings",
		GatheringScript.set_reservation(
			wrong, source, day, "building.test.wrong"
		)[&"reason"] == &"source_incompatible"
		and GatheringScript.set_reservation(
			far, source, day, "building.test.far"
		)[&"reason"] == &"source_out_of_range"
		and GatheringScript.set_reservation(
			incomplete, source, day, "building.test.incomplete"
		)[&"reason"] == &"building_incomplete"
		and GatheringScript.set_reservation(
			anchored, source, day, "building.missing"
		)[&"reason"] == &"unknown_building"
		and GatheringScript.set_reservation(
			anchored, tier_two, day, "building.test.survey"
		)[&"reason"] == &"source_incompatible",
	)


static func _renewal_cases(
	cases: Array[Dictionary], farm: Dictionary, source: Dictionary
) -> void:
	var day: int = CalendarScript.absolute_day(farm[&"calendar_weather"])
	var baseline_deltas: int = (
		((farm[&"gathering"] as Dictionary)[&"resource_deltas"] as Array).size()
	)
	var candidate: Dictionary = farm.duplicate(true)
	for _index: int in int(source[&"capacity"]):
		var gathered: Dictionary = GatheringScript.gather(
			candidate, source, day, &"manual", "protos"
		)
		candidate = gathered[&"candidate"] as Dictionary
	var renewing: Dictionary = GatheringScript.effective(candidate, source, day)
	var early: Dictionary = GatheringScript.advance_day(
		candidate, SEED, int(renewing[&"renewal_day"]) - 1
	)
	var restored: Dictionary = GatheringScript.advance_day(
		candidate, SEED, int(renewing[&"renewal_day"])
	)
	var restored_farm: Dictionary = restored[&"candidate"] as Dictionary
	var restored_state: Dictionary = GatheringScript.effective(
		restored_farm, source, int(renewing[&"renewal_day"])
	)
	_add(
		cases,
		"P5 managed biomass renews only on schedule and compacts its default delta",
		renewing[&"phase"] == &"renewing"
		and early[&"ok"]
		and ((early[&"candidate"][&"gathering"] as Dictionary)[&"resource_deltas"] as Array).size()
		== baseline_deltas + 1
		and restored[&"ok"]
		and int(restored_state[&"remaining_charges"]) == int(source[&"capacity"])
		and ((restored_farm[&"gathering"] as Dictionary)[&"resource_deltas"] as Array).size()
		== baseline_deltas,
	)


static func _soak_case(
	cases: Array[Dictionary], farm: Dictionary, source: Dictionary
) -> void:
	var candidate: Dictionary = farm.duplicate(true)
	var day: int = CalendarScript.absolute_day(candidate[&"calendar_weather"])
	var maximum_deltas: int = 0
	var maximum_bytes: int = 0
	var valid: bool = true
	for _offset: int in 3650:
		var state: Dictionary = GatheringScript.effective(candidate, source, day)
		if int(state[&"remaining_charges"]) == int(source[&"capacity"]):
			for _charge: int in int(source[&"capacity"]):
				var gathered: Dictionary = GatheringScript.gather(
					candidate, source, day, &"manual", "protos"
				)
				valid = valid and bool(gathered[&"ok"])
				candidate = gathered[&"candidate"] as Dictionary
		var advanced: Dictionary = GatheringScript.advance_day(candidate, SEED, day + 1)
		valid = valid and bool(advanced[&"ok"])
		candidate = advanced[&"candidate"] as Dictionary
		day += 1
		var gathering: Dictionary = candidate[&"gathering"] as Dictionary
		maximum_deltas = maxi(
			maximum_deltas, (gathering[&"resource_deltas"] as Array).size()
		)
		maximum_bytes = maxi(maximum_bytes, BudgetScript.canonical_bytes(gathering))
	_add(
		cases,
		"P5 ten-year depletion and renewal soak stays within sparse caps and bytes",
		valid
		and maximum_deltas <= SectionsScript.MAX_RESOURCE_DELTAS
		and maximum_bytes <= int(BudgetScript.SECTION_BUDGETS["gathering"]),
	)


static func _projected_sources(seed: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for y: int in range(-9, 10):
		for x: int in range(-9, 10):
			result.append_array(CatalogScript.project_chunk(Vector2i(x, y), seed))
	return result


static func _suppressed_projected_source(world: RefCounted) -> Dictionary:
	for source: Dictionary in _projected_sources(SEED):
		if (world.call("_resource_source_at", source[&"cell"]) as Dictionary).is_empty():
			var result: Dictionary = source.duplicate(true)
			result[&"test_suppressed"] = true
			return result
	var fallback: Dictionary = CatalogScript.project_at(SALVAGE_CELL, SEED)
	fallback[&"test_suppressed"] = false
	return fallback


static func _empty_projected_cell() -> Vector2i:
	for y: int in range(-72, 73):
		for x: int in range(-72, 73):
			var cell: Vector2i = Vector2i(x, y)
			if CatalogScript.project_at(cell, SEED).is_empty():
				return cell
	return Vector2i(72, 72)


static func _all_ids_round_trip(sources: Array[Dictionary]) -> bool:
	for source: Dictionary in sources:
		var source_id: String = str(source[&"source_id"])
		var cell: Vector2i = CatalogScript.cell_from_id(source_id)
		if CatalogScript.canonical_source_id(source[&"source_kind"], cell) != source_id:
			return false
	return true


static func _has_delta(farm: Dictionary, source_id: String, remaining: int) -> bool:
	for delta: Dictionary in (
		(farm[&"gathering"] as Dictionary)[&"resource_deltas"] as Array[Dictionary]
	):
		if str(delta[&"source_id"]) == source_id:
			return int(delta[&"remaining_charges"]) == remaining
	return false


static func _farm_with_building(
	farm: Dictionary,
	instance_id: String,
	blueprint_id: StringName,
	anchor: Vector2i,
	level: int,
	state: String,
) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	var construction: Dictionary = homestead[&"construction"] as Dictionary
	construction[&"buildings"] = [
		{
			&"instance_id": instance_id, &"blueprint_id": str(blueprint_id),
			&"anchor": [anchor.x, anchor.y], &"orientation": 0, &"level": level,
			&"state": state, &"footprint": ConstructionCatalogScript.encoded_footprint(
				blueprint_id, anchor, 0
			),
			&"local_stacks": [], &"recipe_policies": [],
		}
	]
	homestead[&"construction"] = construction
	candidate[&"homestead"] = homestead
	return FarmSchemaScript.validate(candidate)


static func _complete_camp_record() -> Dictionary:
	var anchor: Vector2i = Vector2i(20, 20)
	return {
		&"instance_id": "building.test.salvage", &"blueprint_id": str(
			ConstructionCatalogScript.SALVAGE_CAMP
		),
		&"anchor": [anchor.x, anchor.y], &"orientation": 0, &"level": 1,
		&"state": "complete", &"footprint": ConstructionCatalogScript.encoded_footprint(
			ConstructionCatalogScript.SALVAGE_CAMP, anchor, 0
		),
		&"local_stacks": [], &"recipe_policies": [],
	}


static func _resolved(cell: Vector2i, option: Dictionary) -> Dictionary:
	return {
		&"valid": true, &"target_cell": cell, &"target_kind": option[&"target_kind"],
		&"target_id": option[&"target_id"],
	}


static func _option(menu: Dictionary, action_id: StringName) -> Dictionary:
	if not MenuScript.validate(menu):
		return {}
	for option: Dictionary in menu[&"options"] as Array[Dictionary]:
		if option[&"action_id"] == action_id:
			return option.duplicate(true)
	return {}


static func _has_action(menu: Dictionary, action_id: StringName) -> bool:
	return not _option(menu, action_id).is_empty()


static func _option_enabled(menu: Dictionary, action_id: StringName) -> bool:
	return bool(_option(menu, action_id).get(&"enabled", false))


static func _option_reason(menu: Dictionary, action_id: StringName) -> StringName:
	return _option(menu, action_id).get(&"reason_key", &"") as StringName


static func _all_ok(results: Array[Dictionary]) -> bool:
	for result: Dictionary in results:
		if not bool(result.get(&"ok", false)):
			return false
	return true


static func _deposit_record_count(records: Array[Dictionary]) -> int:
	var count: int = 0
	var ids: Dictionary = {}
	for record: Dictionary in records:
		if record.get(&"type", &"") == &"deposit":
			count += 1
			ids[record[&"stable_id"]] = true
	return count if count == ids.size() else -1


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
