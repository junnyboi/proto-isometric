extends Node2D

signal mode_changed(active: bool)
signal construction_result(result: Dictionary)

const CatalogScript: GDScript = preload("res://scripts/construction_blueprint_catalog.gd")
const CommandsScript: GDScript = preload("res://scripts/harvest_command_intents.gd")
const GhostScript: GDScript = preload("res://scripts/construction_ghost_overlay.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const PresenterScript: GDScript = preload("res://scripts/construction_mode_presenter.gd")

var _coordinator: RefCounted
var _grid_to_screen: Callable
var _mobile: CanvasLayer
var _ghost: Node2D
var _presenter: CanvasLayer
var _confirmation: ConfirmationDialog
var _active: bool = false
var _mode: StringName = &"place"
var _blueprint_index: int = 0
var _anchor: Vector2i = Vector2i.ZERO
var _orientation: int = 0
var _instance_id: StringName = &""
var _preview: Dictionary = {}
var _pending_confirm: StringName = &""


func _ready() -> void:
	CommandsScript.install_defaults()
	_ghost = GhostScript.new() as Node2D
	_ghost.name = "ConstructionGhostOverlay"
	_ghost.z_index = 28
	add_child(_ghost)
	_presenter = PresenterScript.new() as CanvasLayer
	_presenter.name = "ConstructionModePresenter"
	add_child(_presenter)
	_presenter.connect("action_requested", _on_presenter_action)
	_confirmation = ConfirmationDialog.new()
	_confirmation.name = "ConstructionConfirmation"
	_confirmation.confirmed.connect(_on_confirmation_accepted)
	_confirmation.canceled.connect(_on_confirmation_canceled)
	add_child(_confirmation)
	set_process_input(true)


func configure(
	coordinator: RefCounted, grid_to_screen: Callable, mobile: CanvasLayer
) -> bool:
	if coordinator == null or not grid_to_screen.is_valid():
		return false
	_coordinator = coordinator
	_grid_to_screen = grid_to_screen
	_mobile = mobile
	return bool(_ghost.call("configure", grid_to_screen))


func is_active() -> bool:
	return _active or _confirmation.visible


func open_build(blueprint_id: StringName = &"") -> bool:
	if _coordinator == null or is_active():
		return false
	var ids: Array[StringName] = CatalogScript.ids()
	_blueprint_index = maxi(ids.find(blueprint_id), 0)
	_mode = &"place"
	_instance_id = &""
	_orientation = 0
	var initial: Dictionary = _coordinator.call("find_initial", ids[_blueprint_index]) as Dictionary
	var cells: Array[Vector2i] = initial.get(&"cells", []) as Array[Vector2i]
	_anchor = cells[0] if not cells.is_empty() else Vector2i.ZERO
	_set_active(true)
	_refresh_preview()
	return true


func open_move(instance_id: StringName) -> bool:
	if _coordinator == null or is_active():
		return false
	var building: Dictionary = _coordinator.call("building", instance_id) as Dictionary
	if building.is_empty():
		return false
	var ids: Array[StringName] = CatalogScript.ids()
	_blueprint_index = ids.find(StringName(str(building[&"blueprint_id"])))
	var raw_anchor: Array = building[&"anchor"] as Array
	_anchor = Vector2i(int(raw_anchor[0]), int(raw_anchor[1]))
	_orientation = int(building[&"orientation"])
	_instance_id = instance_id
	_mode = &"move"
	_set_active(true)
	_refresh_preview()
	return true


func request_upgrade(instance_id: StringName) -> bool:
	return _open_confirmation(instance_id, &"upgrade")


func request_demolish(instance_id: StringName) -> bool:
	return _open_confirmation(instance_id, &"demolish")


func close_mode() -> bool:
	if not is_active():
		return false
	_confirmation.hide()
	_pending_confirm = &""
	_instance_id = &""
	_preview.clear()
	_ghost.call("clear")
	_presenter.call("dismiss")
	_set_active(false)
	return true


func get_preview() -> Dictionary:
	return _preview.duplicate(true)


func _input(event: InputEvent) -> void:
	if not _active or event == null or not event.is_pressed() or event.is_echo():
		return
	var handled: bool = true
	if event.is_action_pressed(CommandsScript.MOVE_UP, false, true):
		_move(Vector2i.UP)
	elif event.is_action_pressed(CommandsScript.MOVE_DOWN, false, true):
		_move(Vector2i.DOWN)
	elif event.is_action_pressed(CommandsScript.MOVE_LEFT, false, true):
		_move(Vector2i.LEFT)
	elif event.is_action_pressed(CommandsScript.MOVE_RIGHT, false, true):
		_move(Vector2i.RIGHT)
	elif event.is_action_pressed(CommandsScript.TOOL_ACTION, false, true):
		_rotate()
	elif event.is_action_pressed(CommandsScript.PREVIOUS_TOOL, false, true):
		_cycle(-1)
	elif event.is_action_pressed(CommandsScript.NEXT_TOOL, false, true):
		_cycle(1)
	elif event.is_action_pressed(CommandsScript.CONTEXT, false, true):
		_confirm()
	elif event.is_action_pressed(CommandsScript.CANCEL, false, true):
		close_mode()
	else:
		handled = event is InputEventKey or event is InputEventJoypadButton
	if handled:
		get_viewport().set_input_as_handled()


func _on_presenter_action(action: StringName) -> void:
	match action:
		&"move_up":
			_move(Vector2i.UP)
		&"move_down":
			_move(Vector2i.DOWN)
		&"move_left":
			_move(Vector2i.LEFT)
		&"move_right":
			_move(Vector2i.RIGHT)
		&"rotate":
			_rotate()
		&"previous":
			_cycle(-1)
		&"next":
			_cycle(1)
		&"confirm":
			_confirm()
		&"cancel":
			close_mode()


func _move(direction: Vector2i) -> void:
	_anchor += direction
	_refresh_preview()


func _rotate() -> void:
	_orientation = posmod(_orientation + 1, 4)
	_refresh_preview()


func _cycle(direction: int) -> void:
	if _mode != &"place":
		return
	var ids: Array[StringName] = CatalogScript.ids()
	_blueprint_index = posmod(_blueprint_index + direction, ids.size())
	_orientation = 0
	_refresh_preview()


func _confirm() -> void:
	if not bool(_preview.get(&"ok", false)):
		return
	var blueprint_id: StringName = CatalogScript.ids()[_blueprint_index]
	var result: Dictionary = (
		_coordinator.call("place", blueprint_id, _anchor, _orientation) as Dictionary
		if _mode == &"place"
		else _coordinator.call("move", _instance_id, _anchor, _orientation) as Dictionary
	)
	construction_result.emit(result.duplicate(true))
	if bool(result.get(&"ok", false)):
		close_mode()
	else:
		_refresh_preview()


func _refresh_preview() -> void:
	var blueprint_id: StringName = CatalogScript.ids()[_blueprint_index]
	_preview = _coordinator.call(
		"preview", blueprint_id, _anchor, _orientation, _instance_id
	) as Dictionary
	_ghost.call("present", blueprint_id, _anchor, _orientation, _preview)
	_presenter.call(
		"present",
		{
			&"blueprint_id": blueprint_id,
			&"valid": bool(_preview.get(&"ok", false)),
			&"reason": _preview.get(&"reason", &"invalid_blueprint"),
			&"mode": _mode,
		},
	)
	_sync_mobile_exclusion()


func _open_confirmation(instance_id: StringName, operation: StringName) -> bool:
	if _coordinator == null or is_active():
		return false
	var building: Dictionary = _coordinator.call("building", instance_id) as Dictionary
	if building.is_empty():
		return false
	_instance_id = instance_id
	_pending_confirm = operation
	_confirmation.title = LocalizationScript.t(
		StringName("construction.confirm.%s.title" % str(operation))
	)
	_confirmation.dialog_text = LocalizationScript.t(
		StringName("construction.confirm.%s.body" % str(operation))
	)
	_confirmation.popup_centered(Vector2i(440, 220))
	_set_active(true)
	return true


func _on_confirmation_accepted() -> void:
	var result: Dictionary = (
		_coordinator.call("upgrade", _instance_id) as Dictionary
		if _pending_confirm == &"upgrade"
		else _coordinator.call("demolish", _instance_id) as Dictionary
	)
	construction_result.emit(result.duplicate(true))
	if bool(result.get(&"ok", false)):
		close_mode()
	else:
		_confirmation.dialog_text = LocalizationScript.t(
			&"construction.confirm.rejected",
			{&"reason": str(result.get(&"reason", &"rejected"))},
		)
		_confirmation.call_deferred("popup_centered", Vector2i(440, 220))


func _on_confirmation_canceled() -> void:
	close_mode()


func _set_active(active: bool) -> void:
	_active = active
	if _mobile != null:
		_mobile.call("_set_modal_input_suppressed", active)
		_sync_mobile_exclusion()
	mode_changed.emit(active)


func _sync_mobile_exclusion() -> void:
	if _mobile == null:
		return
	var bounds: Rect2 = _presenter.call("panel_bounds") as Rect2 if _active else Rect2()
	_mobile.call("_set_modal_touch_exclusion", bounds, _active)
