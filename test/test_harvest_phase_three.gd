extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const CropCatalogScript: GDScript = preload("res://scripts/crop_catalog.gd")
const DayAdvanceServiceScript: GDScript = preload("res://scripts/day_advance_service.gd")
const EconomyServiceScript: GDScript = preload("res://scripts/economy_service.gd")
const FarmRendererScript: GDScript = preload("res://scripts/farm_render_adapter.gd")
const FarmRuntimeScript: GDScript = preload("res://scripts/harvest_farm_runtime.gd")
const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")
const VisualCatalogScript: GDScript = preload("res://scripts/visual_catalog.gd")


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


class Projector:
	extends RefCounted

	func project(cell: Vector2i) -> Vector2:
		return Vector2(cell * 10)


static func evaluate(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_definitions(cases)
	_test_inventory(cases)
	_test_crop_growth(cases)
	_test_stamina(cases)
	_test_calendar(cases)
	_test_day_transaction(cases)
	_test_economy_and_loop(cases)
	_test_runtime_rollback(cases)
	_test_render_and_assets(cases)
	_test_live_bridge(cases, runtime)
	_test_compatibility(cases)
	return cases


static func _fresh_farm() -> Dictionary:
	var farm: Dictionary = FarmSaveSchemaScript.make_neutral(RuntimeIdsScript.MODE_FRESH_FARM)
	farm = InventoryServiceScript.ensure_default(farm)
	farm = CalendarStateScript.ensure_default(farm, 77)
	farm = ToolServiceScript.ensure_default(farm)
	farm = EconomyServiceScript.ensure_default(farm)
	return FarmSaveSchemaScript.validate(farm)


static func _test_definitions(cases: Array[Dictionary]) -> void:
	_add(cases, "PH-14 item definitions cover ten stable categories", ItemCatalogScript.validate())
	_add(
		cases,
		"PH-15 all eleven four-stage crops validate against generated atlases",
		CropCatalogScript.validate() and CropCatalogScript.CROP_IDS.size() == 11,
	)
	var all_roles: Dictionary = {}
	var deterministic: bool = true
	for crop_id: StringName in CropCatalogScript.CROP_IDS:
		var crop: Dictionary = CropCatalogScript.definition(crop_id)
		all_roles[crop[&"role"]] = true
		var first_yield: int = CropCatalogScript.deterministic_yield(crop_id, Vector2i(11, 8), 1, 0)
		var second_yield: int = CropCatalogScript.deterministic_yield(
			crop_id, Vector2i(11, 8), 1, 0
		)
		deterministic = (
			deterministic
			and first_yield == second_yield
			and first_yield >= int(crop[&"yield_min"])
			and first_yield <= int(crop[&"yield_max"])
		)
	_add(
		cases,
		"PH-15 eleven distinct crop roles have deterministic bounded yields",
		all_roles.size() == 11 and deterministic
	)


static func _test_inventory(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	var before_total: int = InventoryServiceScript.count_all(farm, &"item.material.wood")
	var transfer: Dictionary = (
		InventoryServiceScript
		. transfer(
			farm,
			InventoryServiceScript.HOME_ID,
			InventoryServiceScript.ROBOT_ID,
			&"item.material.wood",
			7,
		)
	)
	var candidate: Dictionary = transfer[&"candidate"] as Dictionary
	_add(
		cases,
		"PH-14 robot/home transfer conserves totals",
		(
			bool(transfer[&"ok"])
			and InventoryServiceScript.count_all(candidate, &"item.material.wood") == before_total
		),
	)
	var capped: Dictionary = farm.duplicate(true)
	var inventories: Array = capped[&"inventories"] as Array
	for index: int in inventories.size():
		var inventory: Dictionary = inventories[index] as Dictionary
		if inventory[&"container_id"] == "inventory.robot":
			inventory[&"capacity_slots"] = 1
			inventory[&"stacks"] = [{&"item_id": "item.seed.glowroot", &"count": 99}]
			inventories[index] = inventory
		elif inventory[&"container_id"] == "inventory.home":
			inventory[&"capacity_slots"] = 1
			inventory[&"stacks"] = [{&"item_id": "item.material.wood", &"count": 99}]
			inventories[index] = inventory
	capped[&"inventories"] = inventories
	var overflow: Dictionary = InventoryServiceScript.credit_with_overflow(
		capped, &"item.produce.glowroot", 2
	)
	_add(
		cases,
		"PH-14 full robot and home inventories reject overflow without mutation",
		not bool(overflow[&"ok"]) and overflow[&"candidate"] == capped,
	)


static func _test_crop_growth(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	var cell: Vector2i = Vector2i(10, 7)
	var till: Dictionary = FarmStateScript.till(farm, cell)
	var planted: Dictionary = FarmStateScript.plant(
		till[&"candidate"] as Dictionary, cell, &"item.seed.glowroot", 1
	)
	var growing: Dictionary = planted[&"candidate"] as Dictionary
	for day: int in range(1, 4):
		growing = FarmStateScript.apply_rain(growing, day)
		growing = FarmStateScript.grow(growing, day)
	var ready_plot: Dictionary = FarmStateScript.plot_at(growing, cell)
	var serialized: String = JSON.stringify(growing, "", true, true)
	var reloaded: Dictionary = FarmSaveSchemaScript.validate(JSON.parse_string(serialized))
	_add(
		cases,
		"PH-15 till plant water and four stages survive serialization reload",
		(
			bool(till[&"ok"])
			and bool(planted[&"ok"])
			and int(ready_plot[&"stage"]) == 3
			and bool(ready_plot[&"ready"])
			and FarmStateScript.plot_at(reloaded, cell) == ready_plot
		),
	)
	var before_produce: int = InventoryServiceScript.count_all(growing, &"item.produce.glowroot")
	var harvested: Dictionary = FarmStateScript.harvest(growing, cell)
	var harvested_farm: Dictionary = harvested[&"candidate"] as Dictionary
	var duplicate: Dictionary = FarmStateScript.harvest(harvested_farm, cell)
	_add(
		cases,
		"PH-15 harvest credits deterministic yield exactly once",
		(
			bool(harvested[&"ok"])
			and not bool(duplicate[&"ok"])
			and (
				InventoryServiceScript.count_all(harvested_farm, &"item.produce.glowroot")
				== before_produce + int(harvested[&"yield_count"])
			)
		),
	)
	var indexes: Dictionary = FarmStateScript.build_chunk_indexes(harvested_farm)
	_add(
		cases,
		"PH-15 plots remain available through streaming-safe chunk indexes",
		not indexes.is_empty()
	)


static func _test_stamina(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	var tools: Dictionary = farm[&"tools"] as Dictionary
	tools[&"stamina"] = 0
	farm[&"tools"] = tools
	var exhausted: Dictionary = FarmStateScript.till(farm, Vector2i(10, 7))
	_add(
		cases,
		"PH-16 exhaustion denies productivity but movement and menus remain available",
		(
			not bool(exhausted[&"ok"])
			and exhausted[&"candidate"] == farm
			and ToolServiceScript.movement_allowed(farm)
			and ToolServiceScript.menus_allowed(farm)
		),
	)
	_add(
		cases,
		"PH-16 hoe watering axe pick and context definitions have bounded hold assist",
		ToolServiceScript.validate() and ToolServiceScript.repeat_fire_count(60_000) == 8,
	)


static func _test_calendar(cases: Array[Dictionary]) -> void:
	var sequence_a: Array[StringName] = []
	var sequence_b: Array[StringName] = []
	for day: int in range(1, 60):
		sequence_a.append(CalendarStateScript.weather_for(912_345, day))
		sequence_b.append(CalendarStateScript.weather_for(912_345, day))
	_add(
		cases,
		"PH-17 identical seed/day inputs reproduce current weather and forecast",
		sequence_a == sequence_b
	)
	var farm: Dictionary = _fresh_farm()
	var paused: Dictionary = CalendarStateScript.advance_time(farm, 60.0, true)
	var running: Dictionary = CalendarStateScript.advance_time(farm, 60.0, false)
	_add(
		cases,
		"PH-17 time pauses in modals and advances only during active play",
		paused == farm and running != farm and CalendarStateScript.time_pauses_for(&"inventory"),
	)


static func _test_day_transaction(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	var token: String = str((farm[&"calendar_weather"] as Dictionary)[&"day_token"])
	var first: Dictionary = DayAdvanceServiceScript.build_candidate(farm, 77)
	var candidate: Dictionary = first[&"candidate"] as Dictionary
	var retry: Dictionary = DayAdvanceServiceScript.build_candidate(candidate, 77, token)
	_add(
		cases,
		"PH-18 day candidate is detached and source remains unchanged before commit",
		(
			bool(first[&"ok"])
			and token not in (farm[&"day_tokens"] as Array)
			and token in (candidate[&"day_tokens"] as Array)
		),
	)
	_add(
		cases,
		"PH-18 retry with a committed day token cannot double advance",
		not bool(retry[&"ok"]) and retry[&"candidate"] == candidate,
	)


static func _test_economy_and_loop(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	var cell: Vector2i = Vector2i(10, 7)
	farm = (FarmStateScript.till(farm, cell)[&"candidate"] as Dictionary)
	farm = (FarmStateScript.plant(farm, cell, &"item.seed.glowroot", 1)[&"candidate"] as Dictionary)
	for day: int in range(1, 4):
		farm = FarmStateScript.apply_rain(farm, day)
		farm = FarmStateScript.grow(farm, day)
	var harvest: Dictionary = FarmStateScript.harvest(farm, cell)
	farm = harvest[&"candidate"] as Dictionary
	var produce_count: int = InventoryServiceScript.count_all(farm, &"item.produce.glowroot")
	farm = (
		EconomyServiceScript.ship(farm, &"item.produce.glowroot", produce_count)[&"candidate"]
		as Dictionary
	)
	var preview: Dictionary = EconomyServiceScript.shipping_preview(farm)
	var sleep: Dictionary = DayAdvanceServiceScript.build_candidate(farm, 77)
	farm = sleep[&"candidate"] as Dictionary
	var seed: Dictionary = EconomyServiceScript.buy_seed(farm, &"item.seed.glowroot", 1)
	farm = seed[&"candidate"] as Dictionary
	var upgrade: Dictionary = EconomyServiceScript.purchase_workshop_upgrade(farm)
	var upgraded: Dictionary = upgrade[&"candidate"] as Dictionary
	var repeat_upgrade: Dictionary = EconomyServiceScript.purchase_workshop_upgrade(upgraded)
	_add(
		cases,
		"PH-19 complete deterministic till plant water grow harvest ship sleep buy loop passes",
		(
			bool(harvest[&"ok"])
			and int(preview[&"money"]) > 0
			and bool(sleep[&"ok"])
			and bool(seed[&"ok"])
		),
	)
	_add(
		cases,
		"PH-19 workshop purchases exactly one watering-efficiency upgrade",
		(
			bool(upgrade[&"ok"])
			and not bool(repeat_upgrade[&"ok"])
			and (
				String(ToolServiceScript.UPGRADE_WATER_EFFICIENCY)
				in ((upgraded[&"tools"] as Dictionary)[&"upgrade_ids"] as Array)
			)
		),
	)


static func _test_runtime_rollback(cases: Array[Dictionary]) -> void:
	var probe: RefCounted = CommitProbe.new() as RefCounted
	var runtime: RefCounted = FarmRuntimeScript.new() as RefCounted
	var configured: bool = bool(
		runtime.call("configure", _fresh_farm(), Callable(probe, "commit"), 77)
	)
	var before: Dictionary = runtime.call("get_snapshot") as Dictionary
	probe.set("accept", false)
	var failed: Dictionary = (
		runtime.call("transact", &"till", {&"cell": Vector2i(10, 7)}) as Dictionary
	)
	var preview: Dictionary = (
		runtime.call("preview", &"till", {&"cell": Vector2i(10, 7)}) as Dictionary
	)
	_add(
		cases,
		"PH-14 failed candidate persistence rolls back and preview never mutates",
		(
			configured
			and not bool(failed[&"ok"])
			and runtime.call("get_snapshot") == before
			and bool(preview[&"source_unchanged"])
			and int(probe.get("commits")) == 0
		),
	)


static func _test_render_and_assets(cases: Array[Dictionary]) -> void:
	var catalog: Resource = VisualCatalogScript.new() as Resource
	var required: Array[String] = catalog.call("get_required_paths") as Array[String]
	var all_assets: bool = true
	for path: String in [
		"res://assets/crops/crop_glowroot_stages.png",
		"res://assets/crops/crop_coilbean_stages.png",
		"res://assets/crops/crop_ironturnip_stages.png",
		"res://assets/crops/crop_rainleaf_stages.png",
		"res://assets/crops/crop_starbloom_stages.png",
		"res://assets/crops/crop_sunpod_stages.png",
		"res://assets/props/farm_shipping_bin.png",
		"res://assets/props/home_storage_crate.png",
		"res://assets/props/tool_upgrade_bench.png",
	]:
		all_assets = all_assets and path in required and ResourceLoader.exists(path)
	_add(
		cases,
		"PH-15 and PH-19 generated crop and prop assets are cataloged",
		all_assets and bool(catalog.call("validate_required"))
	)
	var renderer: Node2D = FarmRendererScript.new() as Node2D
	(Engine.get_main_loop() as SceneTree).root.add_child(renderer)
	var projector: RefCounted = Projector.new() as RefCounted
	renderer.call("configure", Callable(projector, "project"))
	var farm: Dictionary = _fresh_farm()
	farm = (FarmStateScript.till(farm, Vector2i(10, 7))[&"candidate"] as Dictionary)
	renderer.call("consume_indexes", FarmStateScript.build_chunk_indexes(farm))
	var visible_chunks: Array[Vector2i] = [Vector2i(1, 0)]
	renderer.call("set_visible_chunks", visible_chunks)
	_add(
		cases,
		"PH-15 farm renderer has no per-crop Nodes",
		not bool(renderer.call("has_per_crop_nodes")) and renderer.get_child_count() == 0
	)
	renderer.free()


static func _test_live_bridge(cases: Array[Dictionary], runtime: Node2D) -> void:
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	_add(
		cases,
		"PH-14 live fresh-farm bridge owns a saveable farm runtime outside the capped map",
		(
			farm_runtime != null
			and (
				(farm_runtime.call("get_snapshot") as Dictionary)[&"mode"]
				== "gameplay_mode.fresh_farm"
			)
		),
	)
	var renderer: Node2D = bridge.call("get_farm_renderer") as Node2D
	_add(
		cases,
		"PH-19 live batched renderer includes three generated starter props",
		renderer != null and int(renderer.call("get_visible_record_count")) >= 3
	)


static func _test_compatibility(cases: Array[Dictionary]) -> void:
	var legacy: Dictionary = FarmSaveSchemaScript.make_neutral(
		RuntimeIdsScript.MODE_LEGACY_EXPEDITION, true
	)
	var validated: Dictionary = FarmSaveSchemaScript.validate(legacy)
	_add(
		cases,
		"PH-14 legacy schema-1/2/3 migration farm semantics remain exactly neutral",
		(
			not validated.is_empty()
			and (validated[&"plots"] as Array).is_empty()
			and (validated[&"inventories"] as Array).is_empty()
			and validated[&"migration_tokens"] == [String(RuntimeIdsScript.MIGRATION_FARM_V3_TO_V4)]
		),
	)
	var old_future_record: Dictionary = legacy.duplicate(true)
	old_future_record[&"plots"] = [{&"cell": [8, 10]}]
	_add(
		cases,
		"PH-14 malformed old partial farm records still fail closed",
		FarmSaveSchemaScript.validate(old_future_record).is_empty()
	)


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
