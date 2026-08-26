extends RefCounted

const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const TargetBridgeScript: GDScript = preload(
	"res://scripts/harvest_interaction_target_bridge.gd"
)


static func water(cell: Vector2i, state: Dictionary) -> Dictionary:
	return _target(
		cell,
		StringName("feature.water:%d,%d" % [cell.x, cell.y]),
		&"water",
		state,
		[_inspect(cell)],
	)


static func safe_exit(cell: Vector2i, state: Dictionary) -> Dictionary:
	var no_cost: Array[Dictionary] = []
	var options: Array[Dictionary] = [
		_inspect(cell),
		TargetBridgeScript.option_input(
			&"interaction.action.return_safe_exit",
			&"return_safe_exit",
			{&"cell": cell, &"destination": state.get(&"destination", &"home_clearing")},
			false,
			&"interaction.reason.safe_exit_transition_unavailable",
			100,
			no_cost,
			OptionScript.CLOSE_ON_SUCCESS,
		),
	]
	return _target(
		cell,
		StringName("feature.safe_exit:%d,%d" % [cell.x, cell.y]),
		&"safe_exit",
		state,
		options,
	)


static func functional_prop(
	cell: Vector2i,
	prop_id: StringName,
	state: Dictionary,
) -> Dictionary:
	return _target(cell, prop_id, &"functional_prop", state, [_inspect(cell)])


static func _inspect(cell: Vector2i) -> Dictionary:
	var no_cost: Array[Dictionary] = []
	return TargetBridgeScript.option_input(
		&"interaction.action.inspect",
		&"inspect",
		{&"cell": cell},
		true,
		&"",
		0,
		no_cost,
		OptionScript.CLOSE_NEVER,
	)


static func _target(
	cell: Vector2i,
	target_id: StringName,
	subkind: StringName,
	state: Dictionary,
	options: Array[Dictionary],
) -> Dictionary:
	return TargetBridgeScript.project(
		cell,
		{
			&"kinds": [ResolverScript.KIND_STRUCTURE],
			&"blocked": true,
			&"target_id": target_id,
			&"target_subkind": subkind,
			&"target_state": state,
			&"option_inputs": options,
		},
	)
