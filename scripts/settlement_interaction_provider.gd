extends RefCounted

const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const TargetBridgeScript: GDScript = preload(
	"res://scripts/harvest_interaction_target_bridge.gd"
)


static func terminal_option() -> Dictionary:
	var no_cost: Array[Dictionary] = []
	return TargetBridgeScript.option_input(
		&"interaction.action.open_settlement",
		&"open_settlement",
		{},
		true,
		&"",
		190,
		no_cost,
		OptionScript.CLOSE_ALWAYS,
	)


static func logistics_option() -> Dictionary:
	var no_cost: Array[Dictionary] = []
	return TargetBridgeScript.option_input(
		&"interaction.action.open_logistics",
		&"open_settlement_logistics",
		{},
		true,
		&"",
		195,
		no_cost,
		OptionScript.CLOSE_ALWAYS,
	)


static func settler(cell: Vector2i, settler_id: StringName) -> Dictionary:
	var no_cost: Array[Dictionary] = []
	return TargetBridgeScript.project(
		cell,
		{
			&"kinds": [ResolverScript.KIND_RESIDENT],
			&"blocked": true,
			&"target_id": settler_id,
			&"target_subkind": &"settler",
			&"target_state": {&"settler_id": str(settler_id)},
			&"option_inputs": [
				TargetBridgeScript.option_input(
					&"interaction.action.inspect",
					&"inspect",
					{&"cell": cell},
					true,
					&"",
					0,
					no_cost,
					OptionScript.CLOSE_NEVER,
				),
				terminal_option(),
			],
		},
	)
