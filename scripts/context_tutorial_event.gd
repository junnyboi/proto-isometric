extends RefCounted

const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")

const EVENT_TYPES: Array[StringName] = [
	&"player_moved",
	&"target_changed",
	&"terminal_opened",
	&"menu_navigated",
	&"menu_navigation_not_needed",
	&"safe_action_confirmed",
	&"quick_action_completed",
	&"build_mode_entered",
	&"first_worker_assigned",
]
const SAFE_CONFIRM_OPERATIONS: Array[StringName] = [
	&"inspect", &"admire", &"collect", &"harvest", &"claim_product"
]


static func movement_committed(from_cell: Vector2i, to_cell: Vector2i) -> Dictionary:
	return _event(&"player_moved", from_cell != to_cell)


static func target_acquired(target: Dictionary) -> Dictionary:
	return _event(
		&"target_changed",
		bool(target.get(&"valid", false))
		and target.get(&"target_cell") is Vector2i
		and target.get(&"target_kind", &"") != &"",
	)


static func terminal_opened(menu: Dictionary) -> Dictionary:
	return _event(&"terminal_opened", MenuScript.validate(menu))


static func terminal_navigated(
	snapshot_id: String, from_index: int, to_index: int, action_id: StringName
) -> Dictionary:
	return _event(
		&"menu_navigated",
		snapshot_id.begins_with("interaction.snapshot.") and from_index >= 0 and to_index >= 0
		and from_index != to_index and action_id != &"",
	)


static func navigation_not_needed(menu: Dictionary) -> Dictionary:
	if not MenuScript.validate(menu):
		return _event(&"menu_navigation_not_needed", false)
	var enabled: int = 0
	for option: Dictionary in menu[&"options"] as Array[Dictionary]:
		enabled += 1 if bool(option[&"enabled"]) else 0
	return _event(&"menu_navigation_not_needed", enabled == 1)


static func safe_action_committed(
	snapshot_id: String, option: Dictionary, result: Dictionary
) -> Dictionary:
	var valid: Dictionary = option if OptionScript.validate(option) else {}
	var safe: bool = (
		snapshot_id.begins_with("interaction.snapshot.")
		and not valid.is_empty()
		and bool(valid[&"enabled"])
		and (valid[&"cost_preview"] as Array).is_empty()
		and valid[&"operation"] in SAFE_CONFIRM_OPERATIONS
		and bool(result.get(&"ok", false))
	)
	return _event(&"safe_action_confirmed", safe)


static func quick_committed(result: Dictionary) -> Dictionary:
	return _event(
		&"quick_action_completed",
		result.get(&"result_id", &"") == &"quick.executed"
		and bool(result.get(&"mutated", false)),
	)


static func build_mode_entered(receipt: Dictionary) -> Dictionary:
	return _event(
		&"build_mode_entered",
		bool(receipt.get(&"ok", false)) and bool(receipt.get(&"committed", false)),
	)


static func worker_assignment_committed(receipt: Dictionary) -> Dictionary:
	return _event(
		&"first_worker_assigned",
		bool(receipt.get(&"ok", false))
		and bool(receipt.get(&"committed", false))
		and not str(receipt.get(&"settler_id", "")).is_empty()
		and not str(receipt.get(&"site_id", "")).is_empty(),
	)


static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var event: Dictionary = value as Dictionary
	if event.size() != 2 or not event.has(&"event_type") or not event.has(&"success"):
		return {}
	if not event[&"event_type"] is StringName or event[&"event_type"] not in EVENT_TYPES:
		return {}
	if not event[&"success"] is bool:
		return {}
	return {&"event_type": event[&"event_type"], &"success": event[&"success"]}


static func _event(event_type: StringName, success: bool) -> Dictionary:
	return {&"event_type": event_type, &"success": success}
