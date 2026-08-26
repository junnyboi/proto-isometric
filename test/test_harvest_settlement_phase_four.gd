extends RefCounted

const CalendarScript: GDScript = preload("res://scripts/calendar_state.gd")
const CatalogScript: GDScript = preload("res://scripts/construction_blueprint_catalog.gd")
const ConstructionProviderScript: GDScript = preload(
	"res://scripts/construction_interaction_provider.gd"
)
const LinksScript: GDScript = preload("res://scripts/construction_envelope_links.gd")
const HomesteadScript: GDScript = preload("res://scripts/homestead_service.gd")
const InventoryScript: GDScript = preload("res://scripts/inventory_service.gd")
const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const OptionCatalogScript: GDScript = preload("res://scripts/interaction_option_catalog.gd")
const PresenterScript: GDScript = preload("res://scripts/construction_mode_presenter.gd")
const StateScript: GDScript = preload("res://scripts/construction_state_service.gd")
const WoodlandScript: GDScript = preload("res://scripts/woodland_clearing.gd")

const VIEWPORTS: Array[Vector2] = [
	Vector2(1280, 720),
	Vector2(1024, 576),
	Vector2(844, 390),
	Vector2(720, 1280),
	Vector2(390, 844),
]
const ASSET_PATHS: Array[String] = [
	"res://assets/settlement/construction/building_shelter_pod.png",
	"res://assets/settlement/construction/building_field_warehouse.png",
	"res://assets/settlement/construction/building_salvage_camp.png",
	"res://assets/settlement/construction/building_survey_drill.png",
	"res://assets/settlement/construction/building_coppice_station.png",
	"res://assets/settlement/construction/building_fabricator_annex.png",
	"res://assets/settlement/construction/building_fishing_platform.png",
	"res://assets/settlement/construction/construction_scaffold_small.png",
	"res://assets/settlement/construction/construction_scaffold_large.png",
	"res://assets/settlement/construction/icon_build_blueprint.png",
	"res://assets/settlement/construction/icon_rotate_building.png",
]


class FailedConfirmationCoordinator:
	extends RefCounted

	func building(_instance_id: StringName) -> Dictionary:
		return {&"instance_id": "building.failed.confirmation"}

	func demolish(_instance_id: StringName) -> Dictionary:
		return {&"ok": false, &"reason": &"building_has_assignments", &"candidate": {}}


static func evaluate_contracts() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_catalog_cases(cases)
	_layout_cases(cases)
	_asset_cases(cases)
	return cases


static func evaluate(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_catalog_cases(cases)
	_layout_cases(cases)
	_asset_cases(cases)
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var construction: RefCounted = bridge.call("get_construction_runtime") as RefCounted
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var transactions: RefCounted = bridge.call("get_transaction_boundary") as RefCounted
	_add(cases, "P4 live field owns one construction coordinator", construction != null)
	var seeded: Dictionary = _seed_farm(transactions, farm_runtime)
	_add(cases, "P4 starter construction materials commit through the save boundary", seeded[&"ok"])
	var phase_b: RefCounted = bridge.call("get_interaction_phase_b_service") as RefCounted
	var workshop: Dictionary = phase_b.call("project", Vector2i(9, 7), &"tool.hoe")
	var workshop_menu: Dictionary = OptionCatalogScript.build_menu(workshop)
	_add(
		cases,
		"P4 workshop E-terminal exposes the construction planner",
		_has_action(workshop_menu, &"interaction.action.open_construction"),
	)
	runtime.set("_robot_grid", Vector2i(7, 11))
	var actor_preview: Dictionary = construction.call(
		"preview", CatalogScript.SHELTER_POD, Vector2i(7, 11), 0
	) as Dictionary
	runtime.set("_robot_grid", WoodlandScript.CENTER)
	_add(
		cases,
		"P4 placement rejects the live actor footprint",
		not actor_preview[&"ok"] and actor_preview[&"reason"] == &"actor_occupied",
	)
	var protected_preview: Dictionary = construction.call(
		"preview", CatalogScript.SHELTER_POD, WoodlandScript.HOME_CELL, 0
	) as Dictionary
	_add(
		cases,
		"P4 placement rejects protected settlement paths",
		not protected_preview[&"ok"] and protected_preview[&"reason"] == &"protected_path",
	)
	var initial: Dictionary = construction.call("find_initial", CatalogScript.SHELTER_POD)
	var initial_cells: Array[Vector2i] = initial.get(&"cells", []) as Array[Vector2i]
	_add(
		cases,
		"P4 safe-site search is valid and bounded",
		initial[&"ok"]
		and not initial_cells.is_empty()
		and int((initial[&"path"] as Dictionary)[&"visits"]) <= 1024,
	)
	var current: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var revision: int = int((current[&"revisions"] as Dictionary)[&"result_revision"])
	var actor_bypass: Dictionary = transactions.call(
		"transact",
		&"construction_place",
		{
			&"blueprint_id": CatalogScript.SHELTER_POD,
			&"instance_id": &"building.shelter_pod.bypass",
			&"anchor": initial_cells[0],
			&"orientation": 0,
			&"source_revision": revision,
		},
	) as Dictionary
	_add(
		cases,
		"P4 lower transaction layer rejects missing actor occupancy evidence",
		not actor_bypass[&"ok"] and actor_bypass[&"reason"] == &"invalid_construction_anchor",
	)
	var before: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var wood_before: int = InventoryScript.count_all(before, &"item.material.wood")
	var stone_before: int = InventoryScript.count_all(before, &"item.material.stone")
	var receipts_before: int = ((before[&"receipts"] as Dictionary)[&"entries"] as Array).size()
	var placed: Dictionary = construction.call(
		"place", CatalogScript.SHELTER_POD, initial_cells[0], 0
	) as Dictionary
	var after_place: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var after_homestead: Dictionary = after_place[&"homestead"] as Dictionary
	var buildings: Array = (after_homestead[&"construction"] as Dictionary)[&"buildings"]
	_add(
		cases,
		"P4 place debits one bill and records one exact-once receipt",
		placed[&"ok"]
		and buildings.size() == 1
		and InventoryScript.count_all(after_place, &"item.material.wood") == wood_before - 4
		and InventoryScript.count_all(after_place, &"item.material.stone") == stone_before - 2
		and ((after_place[&"receipts"] as Dictionary)[&"entries"] as Array).size()
		== receipts_before + 1,
	)
	_add(
		cases,
		"P4 placed structure occupies every footprint cell immediately",
		_all_unwalkable(runtime, initial_cells),
	)
	var overlap: Dictionary = construction.call(
		"preview", CatalogScript.SHELTER_POD, initial_cells[0], 0
	) as Dictionary
	_add(
		cases,
		"P4 placement rejects construction overlap",
		not overlap[&"ok"] and overlap[&"reason"] == &"building_overlap",
	)
	var slept: Dictionary = farm_runtime.call("transact", &"sleep", {}) as Dictionary
	var complete: Dictionary = construction.call("building", placed[&"instance_id"])
	_add(
		cases,
		"P4 baseline construction completes after one authoritative sleep",
		slept[&"ok"] and complete[&"state"] == "complete",
	)
	_persistence_cases(cases, runtime, bridge, initial_cells)
	_mode_cases(cases, runtime, bridge)
	return cases


static func evaluate_reloaded(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var construction: RefCounted = bridge.call("get_construction_runtime") as RefCounted
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	var buildings: Array = (homestead[&"construction"] as Dictionary)[&"buildings"]
	var building: Dictionary = buildings[0] as Dictionary if buildings.size() == 1 else {}
	var cells: Array[Vector2i] = _decoded_cells(building.get(&"footprint", []))
	_add(
		cases,
		"P4 cold reload restores the completed building and occupancy",
		building.get(&"state", "") == "complete" and _all_unwalkable(runtime, cells),
	)
	var records: Array[Dictionary] = bridge.call("get_live_presentation_records")
	_add(
		cases,
		"P4 renderer emits one batched record per building rather than per cell",
		_count_stable(records, StringName(str(building.get(&"instance_id", "")))) == 1,
	)
	var phase_b: RefCounted = bridge.call("get_interaction_phase_b_service") as RefCounted
	var target_valid: bool = not cells.is_empty()
	for cell: Vector2i in cells:
		var target: Dictionary = phase_b.call("project", cell, &"tool.hoe") as Dictionary
		target_valid = (
			target_valid
			and not target.is_empty()
			and target[&"target_id"] == StringName(str(building[&"instance_id"]))
		)
	_add(cases, "P4 every footprint cell resolves the same E-terminal building", target_valid)
	var projection: Dictionary = phase_b.call("project", cells[0], &"tool.hoe") as Dictionary
	var menu: Dictionary = OptionCatalogScript.build_menu(projection)
	_add(
		cases,
		"P4 sealed building terminal exposes inspect move upgrade and demolish",
		MenuScript.validate(menu) and _has_construction_actions(menu),
	)
	var second_site: Dictionary = construction.call("find_initial", CatalogScript.SHELTER_POD)
	var second_cells: Array[Vector2i] = second_site.get(&"cells", []) as Array[Vector2i]
	var moved: Dictionary = construction.call(
		"move", StringName(str(building[&"instance_id"])), second_cells[0], 0
	) as Dictionary
	_add(
		cases,
		"P4 move atomically frees old occupancy and claims the new footprint",
		moved[&"ok"]
		and _all_walkable(runtime, cells)
		and _all_unwalkable(runtime, second_cells),
	)
	var upgraded: Dictionary = construction.call(
		"upgrade", StringName(str(building[&"instance_id"]))
	) as Dictionary
	var upgraded_building: Dictionary = construction.call(
		"building", StringName(str(building[&"instance_id"]))
	) as Dictionary
	_add(
		cases,
		"P4 explicit upgrade commits its bill and level exactly once",
		upgraded[&"ok"] and int(upgraded_building.get(&"level", 0)) == 2,
	)
	var level_two_farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var upgrade_projection: Dictionary = ConstructionProviderScript.building(
		level_two_farm, second_cells[0], upgraded_building
	)
	var upgrade_menu: Dictionary = OptionCatalogScript.build_menu(upgrade_projection)
	var upgraded_three: Dictionary = construction.call(
		"upgrade", StringName(str(building[&"instance_id"]))
	) as Dictionary
	var level_three: Dictionary = construction.call(
		"building", StringName(str(building[&"instance_id"]))
	) as Dictionary
	_add(
		cases,
		"P4 level-two terminal enables and commits the supported level-three upgrade",
		_option_enabled(upgrade_menu, &"interaction.action.upgrade_construction")
		and upgraded_three[&"ok"]
		and int(level_three.get(&"level", 0)) == CatalogScript.MAX_LEVEL,
	)
	var dependent_farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	(dependent_farm[&"logistics"] as Dictionary)[&"jobs"] = [
		{
			&"job_id": "job.p4.dependency",
			&"source_id": str(building[&"instance_id"]),
			&"destination_id": "building.other",
			&"item_id": "item.material.wood",
			&"count": 1,
			&"priority": 1,
			&"age": 0,
		}
	]
	var dependency_projection: Dictionary = ConstructionProviderScript.building(
		dependent_farm, second_cells[0], level_three
	)
	var dependency_menu: Dictionary = OptionCatalogScript.build_menu(dependency_projection)
	_add(
		cases,
		"P4 demolition menu and state share dependency rejection",
		not _option_enabled(dependency_menu, &"interaction.action.demolish_construction")
		and not StateScript.demolish(
			dependent_farm, StringName(str(building[&"instance_id"]))
		)[&"ok"],
	)
	var before_demo: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var wood_before: int = InventoryScript.count_all(before_demo, &"item.material.wood")
	var stone_before: int = InventoryScript.count_all(before_demo, &"item.material.stone")
	var demolished: Dictionary = construction.call(
		"demolish", StringName(str(building[&"instance_id"]))
	) as Dictionary
	var after_demo: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	_add(
		cases,
		"P4 confirmed demolition applies deterministic partial salvage",
		demolished[&"ok"]
		and InventoryScript.count_all(after_demo, &"item.material.wood") == wood_before + 2
		and InventoryScript.count_all(after_demo, &"item.material.stone") == stone_before + 1
		and _all_walkable(runtime, second_cells),
	)
	_add(
		cases,
		"P4 place move two upgrades and demolish leave five bounded receipts",
		((after_demo[&"receipts"] as Dictionary)[&"entries"] as Array).size() >= 5,
	)
	return cases


static func _catalog_cases(cases: Array[Dictionary]) -> void:
	var ids: Array[StringName] = CatalogScript.ids()
	var valid: bool = ids.size() == 7
	for blueprint_id: StringName in ids:
		var definition: Dictionary = CatalogScript.definition(blueprint_id)
		valid = (
			valid
			and not definition.is_empty()
			and not CatalogScript.bill(blueprint_id).is_empty()
			and not CatalogScript.footprint(blueprint_id, Vector2i.ZERO, 0).is_empty()
		)
	_add(cases, "P4 seven original blueprints validate with bills and footprints", valid)
	_add(
		cases,
		"P4 completed shelters move while fishing platforms remain anchored",
		CatalogScript.is_movable(CatalogScript.SHELTER_POD)
		and not CatalogScript.is_movable(CatalogScript.FISHING_PLATFORM),
	)
	var rotated: Array[Vector2i] = CatalogScript.footprint(
		CatalogScript.FIELD_WAREHOUSE, Vector2i(10, 10), 1
	)
	_add(
		cases,
		"P4 rotation produces canonical orientation-specific footprints",
		rotated
		== [
			Vector2i(9, 10), Vector2i(10, 10), Vector2i(9, 11),
			Vector2i(10, 11), Vector2i(9, 12), Vector2i(10, 12),
		],
	)
	var source: Dictionary = {&"state_version": 1, &"buildings": []}
	var bad: Dictionary = StateScript.place(
		source, CatalogScript.SHELTER_POD, &"building.bad.1", Vector2i.ZERO, 4
	)
	_add(
		cases,
		"P4 invalid orientation fails closed without mutation",
		not bad[&"ok"] and bad[&"candidate"] == source,
	)


static func _layout_cases(cases: Array[Dictionary]) -> void:
	var valid: bool = true
	for viewport: Vector2 in VIEWPORTS:
		for scale: float in [0.85, 1.0, 1.25]:
			var bounds: Rect2 = PresenterScript._layout_for(viewport, scale)
			valid = (
				valid
				and bounds.position.x >= 0.0
				and bounds.position.y >= 0.0
				and bounds.end.x <= viewport.x
				and bounds.end.y <= viewport.y
				and bounds.size.x >= 300.0
				and bounds.size.y >= 280.0
			)
	_add(cases, "P4 construction panel stays safe across five responsive viewports", valid)


static func _asset_cases(cases: Array[Dictionary]) -> void:
	var valid: bool = true
	for path: String in ASSET_PATHS:
		var texture: Texture2D = load(path) as Texture2D
		var image: Image = texture.get_image() if texture != null else Image.new()
		valid = (
			valid
			and not image.is_empty()
			and image.get_width() >= 128
			and image.get_height() >= 128
			and image.detect_alpha() != Image.ALPHA_NONE
		)
	_add(cases, "P4 selected GPT Image 2 structures and scaffolds retain alpha", valid)


static func _persistence_cases(
	cases: Array[Dictionary], runtime: Node2D, bridge: Node, cells: Array[Vector2i]
) -> void:
	var repository: RefCounted = runtime.get("_state_store") as RefCounted
	var transactions: RefCounted = bridge.call("get_transaction_boundary") as RefCounted
	var envelope: Dictionary = transactions.call("get_snapshot") as Dictionary
	_add(
		cases,
		"P4 committed envelope preserves construction-world bijection",
		LinksScript.validate(envelope),
	)
	var missing_world: Dictionary = envelope.duplicate(true)
	((missing_world[&"world"] as Dictionary)[&"mutation_ledger"] as Dictionary)[&"placed"] = []
	_add(
		cases,
		"P4 save validation rejects a building orphaned from world occupancy",
		(repository.call("validate_candidate_envelope", missing_world) as Dictionary).is_empty(),
	)
	var missing_building: Dictionary = envelope.duplicate(true)
	var missing_farm: Dictionary = missing_building[&"farm"] as Dictionary
	var missing_home: Dictionary = missing_farm[&"homestead"] as Dictionary
	var construction: Dictionary = missing_home[&"construction"] as Dictionary
	construction[&"buildings"] = []
	_add(
		cases,
		"P4 save validation rejects world occupancy orphaned from construction",
		(repository.call("validate_candidate_envelope", missing_building) as Dictionary).is_empty(),
	)
	var unknown_blueprint: Dictionary = envelope.duplicate(true)
	var unknown_farm: Dictionary = unknown_blueprint[&"farm"] as Dictionary
	var unknown_home: Dictionary = unknown_farm[&"homestead"] as Dictionary
	var unknown_buildings: Array = (unknown_home[&"construction"] as Dictionary)[&"buildings"]
	(unknown_buildings[0] as Dictionary)[&"blueprint_id"] = "blueprint.unknown"
	_add(
		cases,
		"P4 save validation rejects unknown invisible-blocker blueprints",
		(repository.call("validate_candidate_envelope", unknown_blueprint) as Dictionary).is_empty(),
	)
	var impossible_level: Dictionary = envelope.duplicate(true)
	var impossible_farm: Dictionary = impossible_level[&"farm"] as Dictionary
	var impossible_home: Dictionary = impossible_farm[&"homestead"] as Dictionary
	var impossible_buildings: Array = (
		(impossible_home[&"construction"] as Dictionary)[&"buildings"] as Array
	)
	(impossible_buildings[0] as Dictionary)[&"level"] = CatalogScript.MAX_LEVEL + 1
	_add(
		cases,
		"P4 save validation rejects construction levels beyond runtime support",
		(repository.call("validate_candidate_envelope", impossible_level) as Dictionary).is_empty(),
	)
	var world: RefCounted = runtime.get("_world") as RefCounted
	var snapshot: Dictionary = world.call("make_snapshot") as Dictionary
	_add(
		cases,
		"P4 world snapshot persists one footprint placement and no fake rocks",
		((snapshot[&"mutation_ledger"] as Dictionary)[&"placed"] as Array).size() == 1
		and (snapshot[&"placed_rocks"] as Array).is_empty()
		and not cells.is_empty(),
	)


static func _mode_cases(cases: Array[Dictionary], runtime: Node2D, bridge: Node) -> void:
	var mode: Node2D = bridge.call("get_construction_mode_controller") as Node2D
	var mobile: CanvasLayer = runtime.get("_mobile_controls") as CanvasLayer
	mobile.call("force_mobile", true)
	var opened: bool = bool(mode.call("open_build", CatalogScript.FIELD_WAREHOUSE))
	var interaction: Node2D = runtime.get_node("HarvestInteractionController") as Node2D
	_add(
		cases,
		"P4 build mode is modal and suppresses legacy touch commands",
		opened
		and mode.call("is_active")
		and mobile.call("is_modal_input_suppressed")
		and interaction.call("handle_touch_command", &"harvest_context"),
	)
	var presenter: CanvasLayer = mode.get_node("ConstructionModePresenter") as CanvasLayer
	var panel: Control = presenter.get_node("ConstructionModeRoot/ConstructionModePanel") as Control
	_add(
		cases,
		"P4 touch parity exposes directional rotate cycle confirm and cancel buttons",
		panel != null and _button_count(panel) >= 9,
	)
	mode.call("close_mode")
	_add(
		cases,
		"P4 cancel exits build mode and restores mobile controls",
		not mode.call("is_active") and not mobile.call("is_modal_input_suppressed"),
	)
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	var buildings: Array = (homestead[&"construction"] as Dictionary)[&"buildings"]
	var instance_id: StringName = StringName(str((buildings[0] as Dictionary)[&"instance_id"]))
	var confirmation_opened: bool = bool(mode.call("request_demolish", instance_id))
	var confirmation: ConfirmationDialog = mode.get_node("ConstructionConfirmation")
	_add(
		cases,
		"P4 demolition requires an explicit confirmation dialog",
		confirmation_opened and confirmation.visible and mode.call("is_active"),
	)
	confirmation.get_cancel_button().pressed.emit()
	_add(
		cases,
		"P4 native confirmation Cancel clears modal ownership and restores touch controls",
		not mode.call("is_active") and not mobile.call("is_modal_input_suppressed"),
	)
	mode.set("_coordinator", FailedConfirmationCoordinator.new())
	mode.call("request_demolish", &"building.failed.confirmation")
	confirmation.get_ok_button().pressed.emit()
	_add(
		cases,
		"P4 rejected confirmation retains modal context for review and retry",
		mode.call("is_active") and mobile.call("is_modal_input_suppressed"),
	)
	mode.call("close_mode")


static func _seed_farm(transactions: RefCounted, farm_runtime: RefCounted) -> Dictionary:
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	for entry: Dictionary in [
		{&"item_id": &"item.material.wood", &"count": 40},
		{&"item_id": &"item.material.stone", &"count": 40},
		{&"item_id": &"item.material.scrap", &"count": 40},
	]:
		var credit: Dictionary = InventoryScript.credit_with_overflow(
			farm, entry[&"item_id"] as StringName, int(entry[&"count"])
		)
		if not bool(credit[&"ok"]):
			return credit
		farm = credit[&"candidate"] as Dictionary
	var committed: Dictionary = transactions.call(
		"transact", &"farm_candidate", {&"farm": farm}
	) as Dictionary
	if bool(committed[&"ok"]):
		farm_runtime.call("sync_committed", (committed[&"candidate"] as Dictionary)[&"farm"])
	return committed


static func _has_construction_actions(menu: Dictionary) -> bool:
	var ids: Array[StringName] = []
	for option: Dictionary in menu[&"options"] as Array[Dictionary]:
		ids.append(option[&"action_id"] as StringName)
	return (
		&"interaction.action.inspect_construction" in ids
		and &"interaction.action.move_construction" in ids
		and &"interaction.action.upgrade_construction" in ids
		and &"interaction.action.demolish_construction" in ids
	)


static func _has_action(menu: Dictionary, action_id: StringName) -> bool:
	if not MenuScript.validate(menu):
		return false
	for option: Dictionary in menu[&"options"] as Array[Dictionary]:
		if option[&"action_id"] == action_id:
			return true
	return false


static func _option_enabled(menu: Dictionary, action_id: StringName) -> bool:
	if not MenuScript.validate(menu):
		return false
	for option: Dictionary in menu[&"options"] as Array[Dictionary]:
		if option[&"action_id"] == action_id:
			return bool(option[&"enabled"])
	return false


static func _all_unwalkable(runtime: Node2D, cells: Array[Vector2i]) -> bool:
	var world: RefCounted = runtime.get("_world") as RefCounted
	for cell: Vector2i in cells:
		if bool(world.call("is_walkable", cell)):
			return false
	return not cells.is_empty()


static func _all_walkable(runtime: Node2D, cells: Array[Vector2i]) -> bool:
	var world: RefCounted = runtime.get("_world") as RefCounted
	for cell: Vector2i in cells:
		if not bool(world.call("is_walkable", cell)):
			return false
	return not cells.is_empty()


static func _decoded_cells(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for raw: Array in value as Array[Array]:
		result.append(Vector2i(int(raw[0]), int(raw[1])))
	return result


static func _count_stable(records: Array[Dictionary], stable_id: StringName) -> int:
	var count: int = 0
	for record: Dictionary in records:
		count += int(record[&"stable_id"] == stable_id)
	return count


static func _button_count(root: Node) -> int:
	var count: int = int(root is Button)
	for child: Node in root.get_children():
		count += _button_count(child)
	return count


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
