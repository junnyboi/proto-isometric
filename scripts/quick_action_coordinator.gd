extends RefCounted

const PolicyScript: GDScript = preload("res://scripts/quick_action_policy.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")

const EXECUTED: StringName = &"quick.executed"
const TERMINAL_OPENED: StringName = &"quick.terminal_opened"
const UNAVAILABLE: StringName = &"quick.unavailable"
const BUSY: StringName = &"quick.busy"

var _resolve: Callable
var _menu_for: Callable
var _execute: Callable
var _open_terminal: Callable
var _in_flight: bool = false


func configure(
	resolve: Callable,
	menu_for: Callable,
	execute: Callable,
	open_terminal: Callable,
) -> bool:
	if (
		not resolve.is_valid()
		or not menu_for.is_valid()
		or not execute.is_valid()
		or not open_terminal.is_valid()
	):
		return false
	_resolve = resolve
	_menu_for = menu_for
	_execute = execute
	_open_terminal = open_terminal
	return true


func attempt() -> Dictionary:
	if _in_flight:
		return _result(BUSY, &"reentry_blocked")
	_in_flight = true
	var result: Dictionary = _attempt_once()
	_in_flight = false
	return result


func is_in_flight() -> bool:
	return _in_flight


func _attempt_once() -> Dictionary:
	var resolved: Dictionary = _resolve.call(ResolverScript.ACTION_CONTEXT) as Dictionary
	if not bool(resolved.get(&"valid", false)):
		return _fallback(&"invalid_resolved_target")
	var menu: Dictionary = _menu_for.call(resolved[&"target_cell"] as Vector2i) as Dictionary
	var decision: Dictionary = PolicyScript.decide(menu)
	if decision[&"decision"] != PolicyScript.EXECUTE:
		return _fallback(decision[&"reason"] as StringName, menu)
	var option: Dictionary = (decision[&"option"] as Dictionary).duplicate(true)
	var execution: Dictionary = (
		_execute.call(
			ResolverScript.ACTION_CONTEXT,
			ToolServiceScript.TOOL_CONTEXT,
			resolved,
			option,
		) as Dictionary
	)
	if not bool(execution.get(&"ok", false)):
		return _fallback(execution.get(&"reason", &"execution_failed") as StringName, menu)
	var receipt: Dictionary = execution.get(&"receipt_result", {}) as Dictionary
	var result_id: StringName = StringName(str(receipt.get(&"result_id", EXECUTED)))
	return _result(
		result_id,
		execution.get(&"reason", &"") as StringName,
		menu,
		option,
		true,
	)


func _fallback(
	reason: StringName,
	menu: Dictionary = {},
) -> Dictionary:
	var opened: bool = bool(_open_terminal.call())
	return _result(TERMINAL_OPENED if opened else UNAVAILABLE, reason, menu)


func _result(
	result_id: StringName,
	reason: StringName,
	menu: Dictionary = {},
	option: Dictionary = {},
	mutated: bool = false,
) -> Dictionary:
	return {
		&"result_id": result_id,
		&"reason": reason,
		&"snapshot_id": menu.get(&"snapshot_id", &"") as StringName,
		&"action_id": option.get(&"action_id", &"") as StringName,
		&"mutated": mutated,
	}
