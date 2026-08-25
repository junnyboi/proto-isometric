extends Node

const FarmRendererScript: GDScript = preload("res://scripts/farm_render_adapter.gd")
const InteractionControllerScript: GDScript = preload(
	"res://scripts/harvest_interaction_controller.gd"
)
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")

var _map: Node2D
var _controller: Node2D
var _farm_renderer: Node2D
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
	_controller = InteractionControllerScript.new() as Node2D
	_controller.name = "HarvestInteractionController"
	_map.add_child(_controller)
	if not bool(
		_controller.call(
			"configure",
			world,
			avatar,
			Callable(_map, "grid_to_screen"),
			Callable(_map, "get_robot_grid"),
			Callable(_map, "get_facing"),
			Callable(camera, "adjust_user_zoom"),
			Callable(self, "_target_snapshot"),
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
	_farm_renderer.call("consume_indexes", {})
	_sync_visible_chunks()
	_ready_for_commands = true


func _target_snapshot(cell: Vector2i) -> Dictionary:
	var world: RefCounted = _map.get("_world") as RefCounted
	if world == null or not bool(world.call("is_valid_cell", cell)):
		return {&"kinds": [], &"out_of_bounds": true}
	var kinds: Array[StringName] = []
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
		&"machine": false,
		&"tool_damage": false,
	}


func _sync_visible_chunks() -> void:
	if _farm_renderer == null or _map == null:
		return
	var chunks: Array[Vector2i] = []
	for cell: Vector2i in _map.get("_visible_cells") as Array[Vector2i]:
		var chunk: Vector2i = Vector2i(floori(float(cell.x) / 8.0), floori(float(cell.y) / 8.0))
		if chunk not in chunks:
			chunks.append(chunk)
	_farm_renderer.call("set_visible_chunks", chunks)
