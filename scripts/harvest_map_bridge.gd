extends Node

const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")
const FarmRendererScript: GDScript = preload("res://scripts/farm_render_adapter.gd")
const FarmRuntimeScript: GDScript = preload("res://scripts/harvest_farm_runtime.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const InteractionControllerScript: GDScript = preload(
	"res://scripts/harvest_interaction_controller.gd"
)
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")
const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")

const SHIPPING_CELL: Vector2i = Vector2i(7, 7)
const STORAGE_CELL: Vector2i = Vector2i(8, 7)
const WORKSHOP_CELL: Vector2i = Vector2i(9, 7)
const SHIPPING_TEXTURE: Texture2D = preload("res://assets/props/farm_shipping_bin.png")
const STORAGE_TEXTURE: Texture2D = preload("res://assets/props/home_storage_crate.png")
const WORKSHOP_TEXTURE: Texture2D = preload("res://assets/props/tool_upgrade_bench.png")
const HOE_SFX: AudioStream = preload("res://assets/audio/harvest/hoe_soil.wav")
const WATER_SFX: AudioStream = preload("res://assets/audio/harvest/water_pour.wav")
const HARVEST_SFX: AudioStream = preload("res://assets/audio/harvest/harvest_pluck.wav")
const SHIPPING_SFX: AudioStream = preload("res://assets/audio/harvest/shipping_drop.wav")

var _map: Node2D
var _controller: Node2D
var _farm_renderer: Node2D
var _farm_runtime: RefCounted
var _ready_for_commands: bool = false


func _ready() -> void:
	call_deferred("_bootstrap")


func _process(_delta: float) -> void:
	if _ready_for_commands:
		_sync_visible_chunks()


func get_interaction_controller() -> Node2D:
	return _controller


func get_farm_renderer() -> Node2D:
	return _farm_renderer


func get_farm_runtime() -> RefCounted:
	return _farm_runtime


func is_ready_for_commands() -> bool:
	return _ready_for_commands


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
			)
		)
	):
		push_error("PH-10 target controller failed configuration.")
		return
	var mobile: CanvasLayer = _map.get("_mobile_controls") as CanvasLayer
	if mobile != null and mobile.has_signal("command_pressed"):
		mobile.connect("command_pressed", Callable(_controller, "handle_touch_command"))
	_farm_renderer = FarmRendererScript.new() as Node2D
	_farm_renderer.name = "FarmRenderAdapter"
	_farm_renderer.z_index = 12
	_map.add_child(_farm_renderer)
	if not bool(_farm_renderer.call("configure", Callable(_map, "grid_to_screen"))):
		push_error("PH-12 farm renderer failed configuration.")
		return
	_refresh_render_indexes()
	_sync_visible_chunks()
	_ready_for_commands = true


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
			)
		)
	):
		push_error("PH-14 farm runtime rejected its schema-4 source.")
		_farm_runtime = null


func _commit_farm_candidate(candidate: Dictionary) -> bool:
	var repository: RefCounted = _map.get("_state_store") as RefCounted
	var world: RefCounted = _map.get("_world") as RefCounted
	var coordinator: RefCounted = _map.get("_run_coordinator") as RefCounted
	if repository == null or world == null or coordinator == null:
		return false
	return bool(
		(
			repository
			. call(
				"save_state",
				world.call("make_snapshot"),
				coordinator.call("get_run_snapshot"),
				coordinator.call("get_profile_snapshot"),
				candidate,
			)
		)
	)


func _target_snapshot(cell: Vector2i) -> Dictionary:
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
	if bool(world.call("_is_outpost", cell)):
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


func _execute_productive_action(
	intent: StringName, tool_id: StringName, resolved: Dictionary
) -> Dictionary:
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
		operation = _context_operation(cell)
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
		_refresh_render_indexes()
		_play_action_sfx(operation, cell)
	return result


func _context_operation(cell: Vector2i) -> StringName:
	var operation: StringName = &""
	if cell == SHIPPING_CELL:
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
		&"ship":
			stream = SHIPPING_SFX
		_:
			return
	var service: Node = get_node_or_null("/root/AudioService")
	if service != null:
		service.call(
			"play_spatial",
			stream,
			_map.call("grid_to_screen", cell) as Vector2,
			AudioServiceScript.BUS_WORLD,
			1.0,
			-2.0,
			1,
		)


func _refresh_render_indexes() -> void:
	if _farm_renderer == null:
		return
	var indexes: Dictionary = (
		_farm_runtime.call("get_render_indexes") as Dictionary if _farm_runtime != null else {}
	)
	if _farm_runtime != null:
		_append_structure(indexes, SHIPPING_CELL, &"shipping_bin", SHIPPING_TEXTURE)
		_append_structure(indexes, STORAGE_CELL, &"storage_crate", STORAGE_TEXTURE)
		_append_structure(indexes, WORKSHOP_CELL, &"workshop_bench", WORKSHOP_TEXTURE)
	_farm_renderer.call("consume_indexes", indexes)


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


func _sync_visible_chunks() -> void:
	if _farm_renderer == null or _map == null:
		return
	var chunks: Array[Vector2i] = []
	for cell: Vector2i in _map.get("_visible_cells") as Array[Vector2i]:
		var chunk: Vector2i = Vector2i(floori(float(cell.x) / 8.0), floori(float(cell.y) / 8.0))
		if chunk not in chunks:
			chunks.append(chunk)
	_farm_renderer.call("set_visible_chunks", chunks)
