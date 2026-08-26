extends RefCounted

const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")

const EXECUTE: StringName = &"execute"
const OPEN_TERMINAL: StringName = &"open_terminal"
const ACTION_OPERATIONS: Dictionary = {
	&"interaction.action.harvest": [&"harvest"],
	&"interaction.action.machine_claim": [&"craft_claim"],
	&"interaction.action.animal_product": [&"animal_product"],
	&"interaction.action.collect": [&"collect_run_pickup", &"world_collect_reward"],
}


static func decide(menu: Dictionary) -> Dictionary:
	if not MenuScript.validate(menu):
		return _decision(OPEN_TERMINAL, &"invalid_snapshot")
	var eligible: Array[Dictionary] = []
	for option: Dictionary in menu[&"options"] as Array[Dictionary]:
		if is_low_risk(option) and bool(option[&"enabled"]):
			eligible.append(option.duplicate(true))
	if eligible.size() == 1:
		return _decision(EXECUTE, &"unique_enabled", eligible[0])
	if eligible.is_empty():
		return _decision(OPEN_TERMINAL, &"no_enabled_low_risk_option")
	return _decision(OPEN_TERMINAL, &"ambiguous_low_risk_options")


static func is_low_risk(option: Dictionary) -> bool:
	var action: Variant = option.get(&"action_id", null)
	var operation: Variant = option.get(&"operation", null)
	if not action is StringName or not operation is StringName:
		return false
	if action not in ACTION_OPERATIONS:
		return false
	return (
		operation in ACTION_OPERATIONS[action]
		and (option.get(&"cost_preview", []) as Array).is_empty()
		and (option.get(&"affected_cells", []) as Array).size() == 1
		and option.get(&"close_behavior", &"") in [
			OptionScript.CLOSE_ALWAYS, OptionScript.CLOSE_ON_SUCCESS
		]
	)


static func _decision(
	decision: StringName,
	reason: StringName,
	option: Dictionary = {},
) -> Dictionary:
	return {
		&"decision": decision,
		&"reason": reason,
		&"option": option.duplicate(true),
	}
