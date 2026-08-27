extends Node

const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")
const ConstructionModeScript: GDScript = preload("res://scripts/construction_mode_controller.gd")
const ConstructionPresentationScript: GDScript = preload(
	"res://scripts/construction_presentation_catalog.gd"
)
const ConstructionRuntimeScript: GDScript = preload(
	"res://scripts/construction_runtime_coordinator.gd"
)
const CrossDomainTransactionScript: GDScript = preload("res://scripts/cross_domain_transaction.gd")
const ExtractionRangeOverlayScript: GDScript = preload(
	"res://scripts/extraction_range_overlay.gd"
)
const FarmRendererScript: GDScript = preload("res://scripts/farm_render_adapter.gd")
const HomesteadPresentationScript: GDScript = preload(
	"res://scripts/homestead_presentation_catalog.gd"
)
const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")
const FarmRuntimeScript: GDScript = preload("res://scripts/harvest_farm_runtime.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const InteractionControllerScript: GDScript = preload(
	"res://scripts/harvest_interaction_controller.gd"
)
const InteractionPhaseBServiceScript: GDScript = preload(
	"res://scripts/harvest_interaction_phase_b_service.gd"
)
const InteractionPresenterScript: GDScript = preload(
	"res://scripts/harvest_interaction_presenter.gd"
)
const InteractionTargetBridgeScript: GDScript = preload(
	"res://scripts/harvest_interaction_target_bridge.gd"
)
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const MachineServiceScript: GDScript = preload("res://scripts/machine_service.gd")
const OrchardServiceScript: GDScript = preload("res://scripts/orchard_service.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const ResourceDepositPresentationScript: GDScript = preload(
	"res://scripts/resource_deposit_presentation.gd"
)
const SettlementModalScript: GDScript = preload("res://scripts/settlement_modal_controller.gd")
const SettlementRuntimeScript: GDScript = preload("res://scripts/settlement_runtime_coordinator.gd")
const SettlerPresentationScript: GDScript = preload(
	"res://scripts/settler_presentation_catalog.gd"
)
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")
const WildernessRuntimeScript: GDScript = preload("res://scripts/wilderness_runtime.gd")
const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")
const SHIPPING_CELL: Vector2i = Vector2i(7, 7)
const STORAGE_CELL: Vector2i = Vector2i(8, 7)
const WORKSHOP_CELL: Vector2i = Vector2i(9, 7)
const FURNACE_CELL: Vector2i = Vector2i(6, 7)
const IRRIGATION_CELL: Vector2i = Vector2i(10, 6)
const WELL_CELL: Vector2i = Vector2i(5, 9)
const SHIPPING_TEXTURE: Texture2D = preload("res://assets/props/farm_shipping_bin.png")
const STORAGE_TEXTURE: Texture2D = preload("res://assets/props/home_storage_crate.png")
const WORKSHOP_TEXTURE: Texture2D = preload("res://assets/props/tool_upgrade_bench.png")
const FURNACE_TEXTURE: Texture2D = preload("res://assets/props/machine_furnace.png")
const IRRIGATION_TEXTURE: Texture2D = preload("res://assets/props/machine_irrigation_pump.png")
const HOE_SFX: AudioStream = preload("res://assets/audio/harvest/hoe_soil.wav")
const WATER_SFX: AudioStream = preload("res://assets/audio/harvest/water_pour.wav")
const HARVEST_SFX: AudioStream = preload("res://assets/audio/harvest/harvest_pluck.wav")
const SHIPPING_SFX: AudioStream = preload("res://assets/audio/harvest/shipping_drop.wav")
var _map: Node2D
var _controller: Node2D
var _presenter: CanvasLayer
var _farm_renderer: Node2D
var _farm_runtime: RefCounted
var _transactions: RefCounted
var _interaction_phase_b_service: RefCounted
var _wilderness_runtime: RefCounted
var _construction_runtime: RefCounted
var _construction_mode: Node2D
var _extraction_range_overlay: Node2D
var _settlement_runtime: RefCounted
var _settlement_modal: Node2D
var _visible_chunks: Array[Vector2i] = []
var _ready_for_commands: bool = false
var _last_presentation_signature: int = 0
var _last_music_track: StringName = &""

func _ready() -> void:
	call_deferred("_bootstrap")

func _process(_delta: float) -> void:
	if not _ready_for_commands:
		return
	_sync_visible_chunks()
	_sync_presentation_state()
	_sync_clearing_music()
	_sync_wilderness()

func get_interaction_controller() -> Node2D:
	return _controller

func get_interaction_presenter() -> CanvasLayer:
	return _presenter
func get_farm_renderer() -> Node2D:
	return _farm_renderer
func get_farm_runtime() -> RefCounted:
	return _farm_runtime
func get_transaction_boundary() -> RefCounted:
	return _transactions
func get_interaction_phase_b_service() -> RefCounted:
	return _interaction_phase_b_service
func get_wilderness_runtime() -> RefCounted:
	return _wilderness_runtime


func is_orchard_cell_occupied(cell: Vector2i) -> bool:
	if _farm_runtime == null:
		return false
	return not OrchardServiceScript.tree_at(
		_farm_runtime.call("get_snapshot") as Dictionary, cell
	).is_empty()


func get_construction_mode_controller() -> Node2D:
	return _construction_mode


func get_construction_runtime() -> RefCounted:
	return _construction_runtime


func get_settlement_runtime() -> RefCounted:
	return _settlement_runtime


func get_settlement_modal_controller() -> Node2D:
	return _settlement_modal


func is_ready_for_commands() -> bool:
	return _ready_for_commands


func is_interaction_menu_open() -> bool:
	if _controller != null and bool(_controller.call("is_menu_open")):
		return true
	if _construction_mode != null and bool(_construction_mode.call("is_active")):
		return true
	if _settlement_modal != null and bool(_settlement_modal.call("is_open")):
		return true
	return false


func get_live_presentation_records() -> Array[Dictionary]:
	if _farm_runtime == null:
		return []
	var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
	var records: Array[Dictionary] = HomesteadPresentationScript.build_records(farm)
	records.append_array(ConstructionPresentationScript.build_records(farm))
	records.append_array(SettlerPresentationScript.build_records(farm))
	records.append_array(OrchardServiceScript.build_records(farm))
	return records


func get_selected_clearing_track() -> StringName:
	return _last_music_track


func _bootstrap() -> void:
	_map = get_parent() as Node2D
	if _map == null:
		return
	var world: RefCounted = _map.get("_world") as RefCounted
	var avatar: Node2D = _map.get("_avatar") as Node2D
	var camera: Camera2D = _map.get("_camera") as Camera2D
	if world == null or avatar == null or camera == null:
		push_error("PH-09 interaction bridge could not bind the field authorities.")
		return
	_initialize_farm_runtime()
	_initialize_interaction_phase_b_service()
	_controller = InteractionControllerScript.new() as Node2D
	_controller.name = "HarvestInteractionController"
	_map.add_child(_controller)
	if not bool(
		(
			_controller
			. call(
				"configure",
				world,
				avatar,
				Callable(_map, "grid_to_screen"),
				Callable(_map, "get_robot_grid"),
				Callable(_map, "get_facing"),
				Callable(camera, "adjust_user_zoom"),
				Callable(self, "_target_snapshot"),
				Callable(self, "_execute_productive_action"),
				Callable(self, "_menu_target_snapshot"),
				Callable(_interaction_phase_b_service, "execute_quick"),
			)
		)
	):
		push_error("PH-10 target controller failed configuration.")
		return
	var mobile: CanvasLayer = _map.get("_mobile_controls") as CanvasLayer
	if mobile != null and mobile.has_signal("command_pressed"):
		mobile.connect("command_pressed", Callable(_controller, "handle_touch_command"))
	_controller.connect("menu_snapshot_opened", _on_menu_opened)
	_controller.connect("menu_snapshot_closed", _on_menu_closed)
	_presenter = InteractionPresenterScript.new() as CanvasLayer
	_map.add_child(_presenter)
	if not bool(_presenter.call("bind", _controller, mobile)):
		push_error("Phase C interaction presenter rejected live authorities.")
		return
	if not _initialize_post_interaction(mobile):
		return
	_farm_renderer = FarmRendererScript.new() as Node2D
	_farm_renderer.name = "FarmRenderAdapter"
	_farm_renderer.z_index = 12
	_map.add_child(_farm_renderer)
	if not bool(_farm_renderer.call("configure", Callable(_map, "grid_to_screen"))):
		push_error("PH-12 farm renderer failed configuration.")
		return
	_refresh_render_indexes()
	_sync_visible_chunks()
	_sync_ruin_registry()
	_sync_clearing_music()
	_initialize_wilderness()
	_ready_for_commands = true


func _initialize_post_interaction(mobile: CanvasLayer) -> bool:
	if not _initialize_construction(mobile):
		push_error("P4 construction mode rejected live authorities.")
		return false
	if not _initialize_settlement(mobile):
		push_error("P6 settlement terminal rejected live authorities.")
		return false
	return true


func _on_menu_opened(_snapshot: Dictionary) -> void:
	_map.set("_velocity", Vector2.ZERO)
	_map.set("_is_moving", false)
	_map.set("_is_running", false)
	var buffer: RefCounted = _map.get("_drive_input_buffer") as RefCounted
	if buffer != null:
		buffer.call("clear")
	_set_modal_radar_yielded(true)


func _on_menu_closed() -> void:
	_set_modal_radar_yielded(false)


func _set_modal_radar_yielded(yielded: bool) -> void:
	if _map != null:
		var hud: CanvasLayer = _map.get("_hud") as CanvasLayer
		if hud != null:
			hud.call("_set_modal_radar_yielded", yielded)


func _initialize_farm_runtime() -> void:
	var repository: RefCounted = _map.get("_state_store") as RefCounted
	if (
		repository == null
		or repository.call("get_gameplay_mode") != RuntimeIdsScript.MODE_FRESH_FARM
	):
		return
	_farm_runtime = FarmRuntimeScript.new() as RefCounted
	if not bool(
		(
			_farm_runtime
			. call(
				"configure",
				repository.call("get_default_farm") as Dictionary,
				Callable(self, "_commit_farm_candidate"),
					WoodlandClearingScript.DEFAULT_SEED,
					Callable(_map.get("_world") as RefCounted, "_resource_source_at"),
					Callable(_map.get("_world") as RefCounted, "_is_home_safe"),
				)
		)
	):
		push_error("PH-14 farm runtime rejected its schema-5 source.")
		_farm_runtime = null
		return
	var source_envelope: Dictionary = {
		&"save_format_version": repository.FORMAT_VERSION,
		&"metadata":
		{
			&"build_id":
			str(ProjectSettings.get_setting("application/config/version", "development")),
			&"world_generation_version": repository.WORLD_GENERATION_VERSION,
			&"write_sequence": int(repository.call("get_write_sequence")),
			&"saved_at_unix": 0,
			&"migration_source": 0,
		},
		&"world": (_map.get("_world") as RefCounted).call("make_snapshot"),
		&"active_run": (_map.get("_run_coordinator") as RefCounted).call("get_run_snapshot"),
		&"profile": (_map.get("_run_coordinator") as RefCounted).call("get_profile_snapshot"),
		&"farm": _farm_runtime.call("get_snapshot"),
	}
	_transactions = CrossDomainTransactionScript.new() as RefCounted
	if not bool(
		(
			_transactions
			. call(
			"configure",
			source_envelope,
			repository,
			_map.get("_world") as RefCounted,
				Callable(self, "_publish_envelope"),
				WoodlandClearingScript.DEFAULT_SEED,
				true,
			)
		)
	):
		push_error("PH-21 cross-domain transaction boundary rejected the live envelope.")
		_transactions = null


func _initialize_interaction_phase_b_service() -> void:
	if _farm_runtime == null or _transactions == null:
		return
	var service: RefCounted = InteractionPhaseBServiceScript.new() as RefCounted
	if not bool(
		service.call(
			"configure",
			_map,
			_farm_runtime,
			_transactions,
			Callable(self, "_on_phase_b_committed"),
		)
	):
		push_error("Phase B interaction service rejected live authorities.")
		return
	_interaction_phase_b_service = service


func _initialize_construction(mobile: CanvasLayer) -> bool:
	if _farm_runtime == null or _transactions == null:
		return true
	_construction_runtime = ConstructionRuntimeScript.new() as RefCounted
	if not bool(_construction_runtime.call("configure", _map, _farm_runtime, _transactions)):
		return false
	_construction_runtime.connect("construction_committed", _on_construction_committed)
	_construction_mode = ConstructionModeScript.new() as Node2D
	_construction_mode.name = "ConstructionModeController"
	_map.add_child(_construction_mode)
	if not bool(
		_construction_mode.call(
			"configure", _construction_runtime, Callable(_map, "grid_to_screen"), mobile
		)
	):
		return false
	_construction_mode.connect("mode_changed", _on_construction_mode_changed)
	_extraction_range_overlay = ExtractionRangeOverlayScript.new() as Node2D
	_extraction_range_overlay.name = "ExtractionRangeOverlay"
	_map.add_child(_extraction_range_overlay)
	var world: RefCounted = _map.get("_world") as RefCounted
	if not bool(
		_extraction_range_overlay.call(
			"configure",
			Callable(_map, "grid_to_screen"),
			Callable(_farm_runtime, "get_snapshot"),
			world,
		)
	):
		return false
	return true


func _initialize_settlement(mobile: CanvasLayer) -> bool:
	if _farm_runtime == null or _transactions == null:
		return true
	_settlement_runtime = SettlementRuntimeScript.new() as RefCounted
	if not bool(_settlement_runtime.call("configure", _farm_runtime, _transactions)):
		_settlement_runtime = null
		return false
	_settlement_runtime.connect("settlement_committed", _on_settlement_committed)
	_settlement_modal = SettlementModalScript.new() as Node2D
	_settlement_modal.name = "SettlementModalController"
	_map.add_child(_settlement_modal)
	if not bool(_settlement_modal.call("configure", _settlement_runtime, mobile)):
		_settlement_modal.queue_free()
		_settlement_modal = null
		return false
	_settlement_modal.connect("modal_changed", _on_settlement_modal_changed)
	return true


func _commit_farm_candidate(candidate: Dictionary) -> Variant:
	if _transactions == null:
		return false
	var result: Dictionary = (
		_transactions.call("transact", &"farm_candidate", {&"farm": candidate}) as Dictionary
	)
	return {
		&"ok": bool(result.get(&"ok", false)),
		&"reason": result.get(&"reason", &"") as StringName,
		&"farm": ((result[&"candidate"] as Dictionary)[&"farm"] as Dictionary).duplicate(true),
	}


func _publish_envelope(envelope: Dictionary) -> bool:
	var world: RefCounted = _map.get("_world") as RefCounted
	var coordinator: RefCounted = _map.get("_run_coordinator") as RefCounted
	if world == null or coordinator == null:
		return false
	var world_snapshot: Dictionary = (envelope[&"world"] as Dictionary).duplicate(true)
	world_snapshot[&"schema"] = 2
	world.call("apply_snapshot", world_snapshot)
	return bool(
		coordinator.call("restore_persisted_state", envelope[&"active_run"], envelope[&"profile"])
	)


func _target_snapshot(cell: Vector2i) -> Dictionary:
	if _interaction_phase_b_service != null:
		return _interaction_phase_b_service.call("resolver_snapshot", cell) as Dictionary
	var world: RefCounted = _map.get("_world") as RefCounted
	if world == null or not bool(world.call("is_valid_cell", cell)):
		return {&"kinds": [], &"out_of_bounds": true}
	var kinds: Array[StringName] = []
	if _farm_runtime != null:
		var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
		var plot: Dictionary = FarmStateScript.plot_at(farm, cell)
		if not plot.is_empty():
			kinds.append(
				(
					ResolverScript.KIND_CROP
					if not str(plot[&"crop_id"]).is_empty()
					else ResolverScript.KIND_PLOT
				)
			)
		if cell in [SHIPPING_CELL, STORAGE_CELL, WORKSHOP_CELL, WoodlandClearingScript.HOME_CELL]:
			kinds.append(ResolverScript.KIND_STRUCTURE)
		elif WoodlandClearingScript.is_farm_apron(cell) and kinds.is_empty():
			kinds.append(ResolverScript.KIND_TERRAIN)
	if world.call("_tree_kind_at", cell) as StringName != &"":
		kinds.append(ResolverScript.KIND_TREE)
	if bool(world.call("_is_outpost", cell)) or HomesteadServiceScript.facility_id_at(cell) != &"":
		kinds.append(ResolverScript.KIND_STRUCTURE)
	if bool(_map.call("has_scrap", cell)):
		kinds.append(ResolverScript.KIND_PICKUP)
	var blocked: bool = not bool(world.call("is_walkable", cell))
	if kinds.is_empty() and not blocked:
		kinds.append(ResolverScript.KIND_TERRAIN)
	return {
		&"kinds": kinds,
		&"blocked": blocked,
		&"home": cell == WoodlandClearingScript.HOME_CELL,
		&"machine": cell in [SHIPPING_CELL, STORAGE_CELL, WORKSHOP_CELL],
		&"tool_damage": false,
	}


func _menu_target_snapshot(cell: Vector2i) -> Dictionary:
	if _interaction_phase_b_service != null:
		var selected_tool: StringName = _controller.call("get_selected_tool") as StringName
		return _interaction_phase_b_service.call("project", cell, selected_tool) as Dictionary
	return InteractionTargetBridgeScript.project(cell, _target_snapshot(cell))


func _execute_productive_action(
	intent: StringName,
	tool_id: StringName,
	resolved: Dictionary,
	option: Dictionary = {},
) -> Dictionary:
	if _interaction_phase_b_service != null:
		return _interaction_phase_b_service.call(
			"execute", intent, tool_id, resolved, option
		) as Dictionary
	if _farm_runtime == null or not bool(resolved.get(&"valid", false)):
		return {&"ok": false, &"reason": &"farm_unavailable"}
	var cell: Vector2i = resolved[&"target_cell"] as Vector2i
	var operation: StringName = &""
	var arguments: Dictionary = {&"cell": cell}
	if intent == ResolverScript.ACTION_TOOL:
		operation = &"till" if tool_id == ToolServiceScript.TOOL_HOE else &"water"
		if tool_id not in [ToolServiceScript.TOOL_HOE, ToolServiceScript.TOOL_WATERING]:
			return {&"ok": false, &"reason": &"tool_has_no_phase_three_target"}
	else:
		operation = option.get(&"operation", _context_operation(cell)) as StringName
		arguments = (option.get(&"arguments", arguments) as Dictionary).duplicate(true)
		arguments[&"cell"] = cell
		if operation in [&"facility_repair", &"facility_power"]:
			arguments[&"facility_id"] = HomesteadServiceScript.facility_id_at(cell)
		if operation == &"plant":
			arguments[&"seed_item_id"] = &"item.seed.glowroot"
		elif operation == &"ship":
			var shipment: Dictionary = _first_shippable_stack()
			if shipment.is_empty():
				return {&"ok": false, &"reason": &"nothing_to_ship"}
			arguments = shipment
		elif operation == &"buy_seed":
			arguments = {&"item_id": &"item.seed.glowroot", &"count": 1}
	var result: Dictionary = _farm_runtime.call("transact", operation, arguments) as Dictionary
	if bool(result.get(&"ok", false)):
		var dirty: Array[Vector2i] = []
		for value: Variant in result.get(&"dirty_cells", []):
			if value is Vector2i:
				dirty.append(value as Vector2i)
		_refresh_render_indexes(dirty)
		_sync_ruin_registry()
		_sync_clearing_music()
		_play_action_sfx(operation, cell)
	return result


func _on_phase_b_committed(
	operation: StringName, cell: Vector2i, result: Dictionary
) -> void:
	if operation == &"open_settlement":
		if _settlement_modal != null:
			_settlement_modal.call("open", &"offer")
		return
	if operation == &"open_settlement_logistics":
		if _settlement_modal != null:
			_settlement_modal.call("open", &"logistics")
		return
	if operation == &"preview_extraction_range":
		if _extraction_range_overlay != null:
			var arguments: Dictionary = result.get(&"arguments", {}) as Dictionary
			_extraction_range_overlay.call(
				"toggle_site", arguments.get(&"instance_id", &"") as StringName
			)
		return
	if operation in [
		&"open_construction",
		&"open_construction_move",
		&"confirm_construction_upgrade",
		&"confirm_construction_demolish",
	]:
		_open_construction_operation(operation, result)
		return
	var dirty: Array[Vector2i] = []
	for value: Variant in result.get(&"dirty_cells", []):
		if value is Vector2i:
			dirty.append(value as Vector2i)
	if operation == &"world_clear_reward":
		dirty.append(cell)
		var objects: Node2D = _map.get("_world_objects") as Node2D
		if objects != null:
			objects.call("invalidate_static_objects")
	if operation == &"deposit_gather":
		dirty.append(cell)
		if _extraction_range_overlay != null:
			_extraction_range_overlay.call("refresh")
	_refresh_render_indexes(dirty)
	_sync_ruin_registry()
	_sync_clearing_music()
	_play_action_sfx(operation, cell)


func _open_construction_operation(operation: StringName, result: Dictionary) -> void:
	if _construction_mode == null:
		return
	var arguments: Dictionary = result.get(&"arguments", {}) as Dictionary
	var instance_id: StringName = arguments.get(&"instance_id", &"") as StringName
	match operation:
		&"open_construction":
			_construction_mode.call("open_build")
		&"open_construction_move":
			_construction_mode.call("open_move", instance_id)
		&"confirm_construction_upgrade":
			_construction_mode.call("request_upgrade", instance_id)
		&"confirm_construction_demolish":
			_construction_mode.call("request_demolish", instance_id)


func _on_construction_mode_changed(active: bool) -> void:
	if _controller != null:
		_controller.call("_set_external_modal", active)
	_set_modal_radar_yielded(active)


func _on_construction_committed(_operation: StringName, result: Dictionary) -> void:
	var dirty: Array[Vector2i] = []
	for value: Variant in result.get(&"dirty_cells", []):
		if value is Vector2i:
			dirty.append(value as Vector2i)
	_refresh_render_indexes(dirty)
	var objects: Node2D = _map.get("_world_objects") as Node2D
	if objects != null:
		objects.call("invalidate_static_objects")


func _on_settlement_modal_changed(active: bool) -> void:
	if _controller != null:
		_controller.call("_set_external_modal", active)
	_set_modal_radar_yielded(active)


func _on_settlement_committed(_operation: StringName, _result: Dictionary) -> void:
	_refresh_render_indexes()


func _context_operation(cell: Vector2i) -> StringName:
	var operation: StringName = &""
	var facility_id: StringName = HomesteadServiceScript.facility_id_at(cell)
	if facility_id != &"":
		var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
		var state: Dictionary = HomesteadServiceScript.facility_state(farm, facility_id)
		if not bool(state.get(&"repaired", false)):
			operation = &"facility_repair"
		elif not bool(state.get(&"powered", false)):
			operation = &"facility_power"
	elif cell == SHIPPING_CELL:
		operation = &"ship"
	elif cell == STORAGE_CELL:
		operation = &"buy_seed"
	elif cell == WORKSHOP_CELL:
		operation = &"upgrade"
	elif cell == WoodlandClearingScript.HOME_CELL:
		operation = &"sleep"
	else:
		var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
		var plot: Dictionary = FarmStateScript.plot_at(farm, cell)
		if not plot.is_empty():
			operation = &"plant" if str(plot[&"crop_id"]).is_empty() else &"harvest"
	return operation


func _first_shippable_stack() -> Dictionary:
	var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
	for item_id: StringName in [
		&"item.produce.glowroot",
		&"item.produce.coilbean",
		&"item.produce.ironturnip",
		&"item.produce.rainleaf",
		&"item.produce.starbloom",
		&"item.produce.sunpod",
	]:
		var count: int = InventoryServiceScript.count_all(farm, item_id)
		if count > 0:
			return {&"item_id": item_id, &"count": count}
	return {}


func _play_action_sfx(operation: StringName, cell: Vector2i) -> void:
	var stream: AudioStream
	match operation:
		&"till":
			stream = HOE_SFX
		&"water":
			stream = WATER_SFX
		&"harvest":
			stream = HARVEST_SFX
		&"world_clear_reward":
			stream = HARVEST_SFX
		&"ship":
			stream = SHIPPING_SFX
		_:
			return
	var service: Node = get_node_or_null("/root/AudioService")
	if service != null:
		(
			service
			. call(
			"play_spatial",
			stream,
			_map.call("grid_to_screen", cell) as Vector2,
			AudioServiceScript.BUS_WORLD,
			1.0,
			-2.0,
			1,
		)
		)


func _refresh_render_indexes(dirty_cells: Array[Vector2i] = []) -> void:
	if _farm_renderer == null:
		return
	var indexes: Dictionary = (
		_farm_runtime.call("get_render_indexes") as Dictionary if _farm_runtime != null else {}
	)
	if _farm_runtime != null:
		_append_structure(indexes, SHIPPING_CELL, &"shipping_bin", SHIPPING_TEXTURE)
		_append_structure(indexes, STORAGE_CELL, &"storage_crate", STORAGE_TEXTURE)
		_append_structure(indexes, WORKSHOP_CELL, &"workshop_bench", WORKSHOP_TEXTURE)
		var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
		_merge_indexes(indexes, HomesteadPresentationScript.build_chunk_indexes(farm))
		_merge_indexes(indexes, ConstructionPresentationScript.build_chunk_indexes(farm))
		_merge_indexes(indexes, SettlerPresentationScript.build_chunk_indexes(farm))
		_merge_indexes(indexes, OrchardServiceScript.build_chunk_indexes(farm))
		var world: RefCounted = _map.get("_world") as RefCounted
		_merge_indexes(
			indexes,
			ResourceDepositPresentationScript.build_chunk_indexes(
				farm, world, _visible_chunks
			),
		)
		if _has_machine(farm, MachineServiceScript.FURNACE_ID):
			_append_structure(indexes, FURNACE_CELL, &"furnace", FURNACE_TEXTURE)
		if _has_upgrade(farm, &"upgrade.irrigation.grid_radius"):
			_append_structure(indexes, IRRIGATION_CELL, &"irrigation_pump", IRRIGATION_TEXTURE)
		if (
			String("boss.ironjaw.first_clear")
			in (farm[&"ecology"] as Dictionary)[&"boss_first_clear_ids"]
		):
			_append_structure(indexes, WELL_CELL, &"burrow_well", IRRIGATION_TEXTURE)
	_farm_renderer.call("consume_indexes", indexes)
	if not dirty_cells.is_empty():
		_farm_renderer.call("invalidate_cells", dirty_cells)
	_last_presentation_signature = _presentation_signature()


func _merge_indexes(target: Dictionary, source: Dictionary) -> void:
	for value: Variant in source:
		var chunk: Vector2i = value as Vector2i
		if not target.has(chunk):
			target[chunk] = []
		for record: Dictionary in source[chunk] as Array[Dictionary]:
			(target[chunk] as Array).append(record)


func _has_machine(farm: Dictionary, machine_id: StringName) -> bool:
	for machine: Dictionary in farm.get(&"machines", []) as Array[Dictionary]:
		if StringName(machine[&"machine_id"]) == machine_id:
			return true
	return false


func _has_upgrade(farm: Dictionary, upgrade_id: StringName) -> bool:
	return (
		String(upgrade_id)
		in ((farm.get(&"tools", {}) as Dictionary).get(&"upgrade_ids", []) as Array)
	)


func _append_structure(
	indexes: Dictionary, cell: Vector2i, stable_id: StringName, texture: Texture2D
) -> void:
	var chunk: Vector2i = Vector2i(floori(float(cell.x) / 8.0), floori(float(cell.y) / 8.0))
	if not indexes.has(chunk):
		indexes[chunk] = []
	(
		(indexes[chunk] as Array)
		. append(
			{
				&"cell": cell,
				&"type": &"structure",
				&"stable_id": stable_id,
				&"texture": texture,
				&"draw_size": Vector2(116.0, 116.0),
				&"draw_offset": Vector2(0.0, -42.0),
			}
		)
	)


func _sync_presentation_state() -> void:
	var signature: int = _presentation_signature()
	if signature == _last_presentation_signature:
		return
	var previous: Array[Vector2i] = []
	if _farm_runtime != null:
		var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
		previous = HomesteadPresentationScript.presentation_cells(farm)
		previous.append_array(ConstructionPresentationScript.presentation_cells(farm))
		previous.append_array(SettlerPresentationScript.presentation_cells(farm))
		previous.append_array(OrchardServiceScript.presentation_cells(farm))
	_refresh_render_indexes(previous)
	_sync_ruin_registry()


func _presentation_signature() -> int:
	if _farm_runtime == null:
		return 0
	return hash(_farm_runtime.call("get_snapshot"))


func _sync_ruin_registry() -> void:
	if _farm_runtime == null or _map == null:
		return
	var world: RefCounted = _map.get("_world") as RefCounted
	if world == null:
		return
	var registry: RefCounted = world.call("_get_ruin_registry") as RefCounted
	if registry == null:
		return
	registry.call("sync_homestead", _farm_runtime.call("get_snapshot") as Dictionary)
	var objects: Node2D = _map.get("_world_objects") as Node2D
	if objects != null:
		var hidden: Array[Vector2i] = [WoodlandClearingScript.HOME_CELL]
		for facility_id: StringName in HomesteadServiceScript.FACILITY_IDS:
			var definition_value: Dictionary = HomesteadServiceScript.definition(facility_id)
			hidden.append(definition_value[&"cell"] as Vector2i)
		objects.call("set_hidden_outpost_cells", hidden)
		objects.call("invalidate_static_objects")


func _sync_clearing_music() -> void:
	if _farm_runtime == null or _map == null:
		return
	var router: Node = _map.get("_feedback_router") as Node
	if router == null:
		return
	var music: Node = router.get("_music") as Node
	if music == null:
		return
	var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
	var calendar: Dictionary = farm.get(&"calendar_weather", {}) as Dictionary
	_last_music_track = (
		(
			music
			. call(
		"set_clearing_context",
		true,
		int(calendar.get(&"minute_of_day", 360)),
		StringName(str(calendar.get(&"current_weather_id", "weather.clear"))),
			)
		)
		as StringName
	)


func _initialize_wilderness() -> void:
	if _farm_runtime == null:
		return
	var sandworms: Node2D = _map.get("_sandworms") as Node2D
	_wilderness_runtime = WildernessRuntimeScript.new() as RefCounted
	if not bool(
		_wilderness_runtime.call(
			"configure", sandworms, _farm_runtime, WoodlandClearingScript.DEFAULT_SEED
		)
	):
		_wilderness_runtime = null


func _sync_wilderness() -> void:
	if _wilderness_runtime == null:
		return
	var cell: Vector2i = _map.call("get_robot_grid") as Vector2i
	var world: RefCounted = _map.get("_world") as RefCounted
	_wilderness_runtime.call("sync", cell, world.call("_biome_at", cell) as StringName)


func _sync_visible_chunks() -> void:
	if _farm_renderer == null or _map == null:
		return
	var chunks: Array[Vector2i] = []
	for cell: Vector2i in _map.get("_visible_cells") as Array[Vector2i]:
		var chunk: Vector2i = Vector2i(floori(float(cell.x) / 8.0), floori(float(cell.y) / 8.0))
		if chunk not in chunks:
			chunks.append(chunk)
	chunks.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	if chunks != _visible_chunks:
		_visible_chunks = chunks.duplicate()
		_refresh_render_indexes()
	_farm_renderer.call("set_visible_chunks", chunks)
