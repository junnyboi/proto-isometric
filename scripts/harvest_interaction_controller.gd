extends Node2D

signal menu_intent_requested(action: StringName)
signal tool_preview_contact(result: Dictionary)

const CommandsScript: GDScript = preload("res://scripts/harvest_command_intents.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const ReticleScript: GDScript = preload("res://scripts/target_reticle.gd")
const ToolPresenterScript: GDScript = preload("res://scripts/tool_action_presenter.gd")

const TOOLS: Array[StringName] = [&"tool.hoe", &"tool.watering"]

var _world: RefCounted
var _avatar: Node2D
var _grid_to_screen: Callable
var _player_cell: Callable
var _facing: Callable
var _zoom: Callable
var _target_query: Callable
var _reticle: Node2D
var _tool_presenter: Node2D
var _selected_tool: int = 0
var _last_target: Dictionary = {}
var _avatar_was_visible: bool = true


func _ready() -> void:
	CommandsScript.install_defaults()
	_reticle = ReticleScript.new() as Node2D
	_reticle.name = "AdjacentTargetReticle"
	_reticle.z_index = 18
	add_child(_reticle)
	_tool_presenter = ToolPresenterScript.new() as Node2D
	_tool_presenter.name = "ToolActionPresenter"
	_tool_presenter.z_index = 22
	_tool_presenter.connect("tool_contact_frame", Callable(self, "_on_tool_contact"))
	_tool_presenter.connect("tool_action_finished", Callable(self, "_on_tool_finished"))
	add_child(_tool_presenter)


func _process(_delta: float) -> void:
	if _world == null:
		return
	_sync_target()
	for action: StringName in CommandsScript.action_ids():
		if action in CommandsScript.MOVE_ACTIONS or action in [
			CommandsScript.RUN, CommandsScript.COMBAT_ATTACK
		]:
			continue
		if CommandsScript.is_just_pressed(action):
			_dispatch(action)


func configure(
	world: RefCounted,
	avatar: Node2D,
	grid_to_screen: Callable,
	player_cell: Callable,
	facing: Callable,
	zoom: Callable,
	target_query: Callable,
) -> bool:
	if (
		world == null
		or avatar == null
		or not grid_to_screen.is_valid()
		or not player_cell.is_valid()
		or not facing.is_valid()
		or not target_query.is_valid()
	):
		return false
	_world = world
	_avatar = avatar
	_grid_to_screen = grid_to_screen
	_player_cell = player_cell
	_facing = facing
	_zoom = zoom
	_target_query = target_query
	_reticle.call("configure", grid_to_screen)
	_sync_target()
	return true


func handle_touch_command(action: StringName) -> bool:
	if action not in CommandsScript.action_ids() or action in CommandsScript.MOVE_ACTIONS:
		return false
	if action in [CommandsScript.RUN, CommandsScript.COMBAT_ATTACK]:
		return false
	_dispatch(action)
	return true


func get_selected_tool() -> StringName:
	return TOOLS[_selected_tool]


func get_last_target() -> Dictionary:
	return _last_target.duplicate(true)


func get_reticle() -> Node2D:
	return _reticle


func get_tool_presenter() -> Node2D:
	return _tool_presenter


func _dispatch(action: StringName) -> void:
	match action:
		CommandsScript.CONTEXT:
			_present_context()
		CommandsScript.TOOL_ACTION:
			_attempt_tool()
		CommandsScript.PREVIOUS_TOOL:
			_selected_tool = posmod(_selected_tool - 1, TOOLS.size())
		CommandsScript.NEXT_TOOL:
			_selected_tool = posmod(_selected_tool + 1, TOOLS.size())
		CommandsScript.INVENTORY, CommandsScript.JOURNAL_MAP, CommandsScript.CANCEL:
			menu_intent_requested.emit(action)
		CommandsScript.ZOOM_IN:
			if _zoom.is_valid():
				_zoom.call(1)
		CommandsScript.ZOOM_OUT:
			if _zoom.is_valid():
				_zoom.call(-1)


func _present_context() -> void:
	var result: Dictionary = _resolve(ResolverScript.ACTION_CONTEXT)
	_reticle.call("present", result, true)
	_last_target = result


func _attempt_tool() -> void:
	var result: Dictionary = _resolve(ResolverScript.ACTION_TOOL)
	_reticle.call("present", result, false)
	_last_target = result
	if not bool(result[&"valid"]) or bool(_tool_presenter.call("is_playing")):
		return
	_tool_presenter.position = _avatar.position
	_avatar_was_visible = _avatar.visible
	_avatar.visible = false
	if not bool(_tool_presenter.call("play_tool", TOOLS[_selected_tool], result)):
		_avatar.visible = _avatar_was_visible


func _sync_target() -> void:
	var result: Dictionary = _resolve(ResolverScript.ACTION_CONTEXT)
	if result == _last_target:
		return
	var kind: StringName = result[&"target_kind"] as StringName
	var context_mode: bool = kind in [ResolverScript.KIND_STRUCTURE, ResolverScript.KIND_PICKUP]
	_reticle.call("present", result, context_mode)
	_last_target = result


func _resolve(intent: StringName) -> Dictionary:
	var origin: Vector2i = _player_cell.call() as Vector2i
	var facing: StringName = _facing.call() as StringName
	var cell: Vector2i = ResolverScript.adjacent_cell(origin, facing)
	var targets: Dictionary = _target_query.call(cell) as Dictionary
	return ResolverScript.resolve(origin, facing, ResolverScript.MASK_ALL, targets, intent)


func _on_tool_contact(result: Dictionary) -> void:
	tool_preview_contact.emit(result.duplicate(true))


func _on_tool_finished() -> void:
	if _avatar != null:
		_avatar.visible = _avatar_was_visible
