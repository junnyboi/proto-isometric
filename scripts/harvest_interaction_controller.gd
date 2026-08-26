extends Node2D

signal menu_intent_requested(action: StringName)
signal menu_snapshot_opened(snapshot: Dictionary)
signal menu_snapshot_refreshed(snapshot: Dictionary)
signal menu_snapshot_closed
signal menu_selection_changed(index: int, action_id: StringName)
signal menu_execution_result(result: Dictionary)
signal quick_action_result(result: Dictionary)
signal tool_preview_contact(result: Dictionary)
signal target_acquired(result: Dictionary)
signal menu_navigation_committed(
	snapshot_id: StringName, from_index: int, to_index: int, action_id: StringName
)
signal safe_menu_action_committed(
	snapshot_id: StringName, option: Dictionary, result: Dictionary
)

const CatalogScript: GDScript = preload("res://scripts/interaction_option_catalog.gd")
const CommandsScript: GDScript = preload("res://scripts/harvest_command_intents.gd")
const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const ReticleScript: GDScript = preload("res://scripts/target_reticle.gd")
const QuickCoordinatorScript: GDScript = preload("res://scripts/quick_action_coordinator.gd")
const TargetBridgeScript: GDScript = preload(
	"res://scripts/harvest_interaction_target_bridge.gd"
)
const ToolPresenterScript: GDScript = preload("res://scripts/tool_action_presenter.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")

const TOOLS: Array[StringName] = [&"tool.hoe", &"tool.watering", &"tool.axe", &"tool.pick"]

var _world: RefCounted
var _avatar: Node2D
var _grid_to_screen: Callable
var _player_cell: Callable
var _facing: Callable
var _zoom: Callable
var _target_query: Callable
var _menu_target_query: Callable
var _productive_action: Callable
var _quick_action: Callable
var _reticle: Node2D
var _tool_presenter: Node2D
var _selected_tool: int = 0
var _last_target: Dictionary = {}
var _avatar_was_visible: bool = true
var _held_tool_msec: int = 0
var _repeat_count: int = 0
var _menu_snapshot: Dictionary = {}
var _selected_index: int = -1
var _selected_action_id: StringName = &""
var _executing: bool = false
var _quick_coordinator: RefCounted
var _external_modal: bool = false


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


func _process(delta: float) -> void:
	if _world == null:
		return
	_sync_target()
	if is_menu_open() or _external_modal:
		return
	_update_hold_repeat(delta)
	for action: StringName in CommandsScript.action_ids():
		if (
			action in CommandsScript.MOVE_ACTIONS
			or action in [CommandsScript.RUN, CommandsScript.COMBAT_ATTACK]
		):
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
	productive_action: Callable = Callable(),
	menu_target_query: Callable = Callable(),
	quick_action: Callable = Callable(),
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
	_productive_action = productive_action
	_menu_target_query = menu_target_query
	_quick_action = quick_action
	_configure_quick_action()
	_reticle.call("configure", grid_to_screen)
	_sync_target()
	return true


func handle_touch_command(action: StringName) -> bool:
	if action not in CommandsScript.action_ids() or action in CommandsScript.MOVE_ACTIONS:
		return false
	if _external_modal:
		return true
	if action in [CommandsScript.RUN, CommandsScript.COMBAT_ATTACK]:
		return false
	if is_menu_open():
		return _handle_menu_touch(action)
	_dispatch(action)
	return true


func _handle_menu_touch(action: StringName) -> bool:
	if action == CommandsScript.CONTEXT:
		return confirm_menu()
	if action == CommandsScript.CANCEL:
		return close_menu()
	return true


func _set_external_modal(active: bool) -> void:
	_external_modal = active
	if active:
		close_menu()


func get_selected_tool() -> StringName:
	return TOOLS[_selected_tool]


func get_last_target() -> Dictionary:
	return _last_target.duplicate(true)


func get_reticle() -> Node2D:
	return _reticle


func get_tool_presenter() -> Node2D:
	return _tool_presenter


func get_quick_action_coordinator() -> RefCounted:
	return _quick_coordinator


func is_menu_open() -> bool:
	return MenuScript.validate(_menu_snapshot)


func get_menu_snapshot() -> Dictionary:
	return _menu_snapshot.duplicate(true)


func get_selected_menu_index() -> int:
	return _selected_index


func get_selected_action_id() -> StringName:
	return _selected_action_id


func open_menu() -> bool:
	var result: Dictionary = _resolve(ResolverScript.ACTION_CONTEXT)
	_reticle.call("present", result, true)
	_last_target = result
	if not bool(result[&"valid"]):
		close_menu()
		return false
	cancel_pending_tool()
	var snapshot: Dictionary = _build_menu(result[&"target_cell"] as Vector2i)
	if not MenuScript.validate(snapshot):
		close_menu()
		return false
	_menu_snapshot = snapshot.duplicate(true)
	_select_first_enabled()
	menu_snapshot_opened.emit(_menu_snapshot.duplicate(true))
	return true


func close_menu() -> bool:
	var was_open: bool = is_menu_open()
	_menu_snapshot.clear()
	_selected_index = -1
	_selected_action_id = &""
	_executing = false
	if was_open:
		menu_snapshot_closed.emit()
	return was_open


func attempt_quick_action() -> Dictionary:
	if is_menu_open():
		return {&"result_id": &"quick.busy", &"reason": &"menu_open", &"mutated": false}
	if _quick_coordinator == null:
		open_menu()
		return {
			&"result_id": &"quick.unavailable",
			&"reason": &"coordinator_unavailable",
			&"mutated": false,
		}
	cancel_pending_tool()
	var result: Dictionary = _quick_coordinator.call("attempt") as Dictionary
	quick_action_result.emit(result.duplicate(true))
	return result


func navigate_menu(direction: int) -> bool:
	if not is_menu_open() or direction == 0:
		return false
	var options: Array = _menu_snapshot[&"options"] as Array
	var previous_index: int = _selected_index
	var next_index: int = clampi(previous_index + signi(direction), 0, options.size() - 1)
	if next_index == _selected_index:
		return false
	_selected_index = next_index
	_selected_action_id = (options[_selected_index] as Dictionary)[&"action_id"] as StringName
	menu_selection_changed.emit(_selected_index, _selected_action_id)
	if bool((options[_selected_index] as Dictionary)[&"enabled"]):
		menu_navigation_committed.emit(
			_menu_snapshot[&"snapshot_id"] as StringName,
			previous_index,
			_selected_index,
			_selected_action_id,
		)
	return true


func select_menu_index(index: int) -> bool:
	if not is_menu_open():
		return false
	var options: Array = _menu_snapshot[&"options"] as Array
	if index < 0 or index >= options.size() or index == _selected_index:
		return false
	var previous_index: int = _selected_index
	_selected_index = index
	_selected_action_id = (options[index] as Dictionary)[&"action_id"] as StringName
	menu_selection_changed.emit(_selected_index, _selected_action_id)
	if bool((options[_selected_index] as Dictionary)[&"enabled"]):
		menu_navigation_committed.emit(
			_menu_snapshot[&"snapshot_id"] as StringName,
			previous_index,
			_selected_index,
			_selected_action_id,
		)
	return true


func refresh_menu_if_stale() -> bool:
	if not is_menu_open():
		return false
	var selected: StringName = _selected_action_id
	var cell: Vector2i = _menu_snapshot[&"target_cell"] as Vector2i
	var current: Dictionary = _build_menu(cell)
	if not MenuScript.validate(current):
		close_menu()
		return false
	if current[&"snapshot_id"] == _menu_snapshot[&"snapshot_id"]:
		return false
	_menu_snapshot = current.duplicate(true)
	_restore_selection(selected)
	menu_snapshot_refreshed.emit(_menu_snapshot.duplicate(true))
	return true


func confirm_menu() -> bool:
	if not is_menu_open() or _executing or _selected_index < 0:
		return false
	if refresh_menu_if_stale():
		return false
	if not is_menu_open() or _selected_index < 0:
		return false
	var snapshot_id: StringName = _menu_snapshot[&"snapshot_id"] as StringName
	var option: Dictionary = (_menu_snapshot[&"options"] as Array)[_selected_index] as Dictionary
	if not bool(option[&"enabled"]):
		return false
	var resolved: Dictionary = _resolve(ResolverScript.ACTION_CONTEXT)
	if not bool(resolved[&"valid"]):
		close_menu()
		return false
	_executing = true
	var result: Dictionary = {&"ok": true, &"reason": &"preview_only"}
	if option[&"operation"] != &"inspect" and _productive_action.is_valid():
		result = _productive_action.call(
			ResolverScript.ACTION_CONTEXT,
			ToolServiceScript.TOOL_CONTEXT,
			resolved,
			option.duplicate(true),
		) as Dictionary
	_executing = false
	menu_execution_result.emit(result.duplicate(true))
	if bool(result.get(&"ok", false)):
		safe_menu_action_committed.emit(
			snapshot_id, option.duplicate(true), result.duplicate(true)
		)
	if bool(result.get(&"ok", false)):
		if option[&"close_behavior"] in [&"always", &"on_success"]:
			close_menu()
		else:
			refresh_menu_if_stale()
	elif option[&"close_behavior"] == &"always":
		close_menu()
	else:
		refresh_menu_if_stale()
	return bool(result.get(&"ok", false))


func cancel_pending_tool() -> bool:
	_held_tool_msec = 0
	_repeat_count = 0
	if _tool_presenter == null or not bool(_tool_presenter.call("is_playing")):
		return false
	_tool_presenter.call("cancel_tool")
	if _avatar != null:
		_avatar.visible = _avatar_was_visible
	return true


func _dispatch(action: StringName) -> void:
	match action:
		CommandsScript.CONTEXT:
			open_menu()
		CommandsScript.TOOL_ACTION:
			_attempt_tool()
		CommandsScript.QUICK_ACTION:
			attempt_quick_action()
		CommandsScript.PREVIOUS_TOOL:
			_selected_tool = posmod(_selected_tool - 1, TOOLS.size())
		CommandsScript.NEXT_TOOL:
			_selected_tool = posmod(_selected_tool + 1, TOOLS.size())
		CommandsScript.INVENTORY, CommandsScript.JOURNAL_MAP:
			menu_intent_requested.emit(action)
		CommandsScript.CANCEL:
			if not close_menu():
				menu_intent_requested.emit(action)
		CommandsScript.ZOOM_IN:
			if _zoom.is_valid():
				_zoom.call(1)
		CommandsScript.ZOOM_OUT:
			if _zoom.is_valid():
				_zoom.call(-1)


func _configure_quick_action() -> void:
	_quick_coordinator = null
	if not _productive_action.is_valid() or not _menu_target_query.is_valid():
		return
	var executor: Callable = _quick_action if _quick_action.is_valid() else _productive_action
	var coordinator: RefCounted = QuickCoordinatorScript.new() as RefCounted
	if bool(
		coordinator.call(
			"configure",
			Callable(self, "_resolve"),
			Callable(self, "_build_menu"),
			executor,
			Callable(self, "open_menu"),
		)
	):
		_quick_coordinator = coordinator


func _attempt_tool() -> void:
	if is_menu_open():
		return
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
	if bool(result[&"valid"]):
		target_acquired.emit(result.duplicate(true))


func _resolve(intent: StringName) -> Dictionary:
	var origin: Vector2i = _player_cell.call() as Vector2i
	var facing: StringName = _facing.call() as StringName
	var cell: Vector2i = ResolverScript.adjacent_cell(origin, facing)
	var targets: Dictionary = _target_query.call(cell) as Dictionary
	return ResolverScript.resolve(origin, facing, ResolverScript.MASK_ALL, targets, intent)


func _build_menu(cell: Vector2i) -> Dictionary:
	var target: Dictionary = {}
	if _menu_target_query.is_valid():
		target = _menu_target_query.call(cell) as Dictionary
	else:
		target = TargetBridgeScript.project(cell, _target_query.call(cell))
	return CatalogScript.build_menu(target)


func _select_first_enabled() -> void:
	_selected_index = 0
	var options: Array = _menu_snapshot[&"options"] as Array
	for index: int in options.size():
		if bool((options[index] as Dictionary)[&"enabled"]):
			_selected_index = index
			break
	_selected_action_id = (options[_selected_index] as Dictionary)[&"action_id"] as StringName
	menu_selection_changed.emit(_selected_index, _selected_action_id)


func _restore_selection(action_id: StringName) -> void:
	var options: Array = _menu_snapshot[&"options"] as Array
	for index: int in options.size():
		if (options[index] as Dictionary)[&"action_id"] == action_id:
			_selected_index = index
			_selected_action_id = action_id
			menu_selection_changed.emit(_selected_index, _selected_action_id)
			return
	_select_first_enabled()


func _on_tool_contact(result: Dictionary) -> void:
	tool_preview_contact.emit(result.duplicate(true))
	if _productive_action.is_valid():
		_productive_action.call(ResolverScript.ACTION_TOOL, TOOLS[_selected_tool], result)


func _on_tool_finished() -> void:
	if _avatar != null:
		_avatar.visible = _avatar_was_visible


func _update_hold_repeat(delta: float) -> void:
	if not CommandsScript.is_pressed(CommandsScript.TOOL_ACTION):
		_held_tool_msec = 0
		_repeat_count = 0
		return
	_held_tool_msec += maxi(roundi(maxf(delta, 0.0) * 1000.0), 0)
	var expected: int = ToolServiceScript.repeat_fire_count(_held_tool_msec)
	if expected > _repeat_count and not bool(_tool_presenter.call("is_playing")):
		_repeat_count += 1
		_attempt_tool()
