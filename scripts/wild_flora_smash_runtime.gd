extends RefCounted

const IsometricControlsScript: GDScript = preload("res://scripts/isometric_controls.gd")

const INVALID_CELL: Vector2i = Vector2i(-9999, -9999)

var _pending_cell: Vector2i = INVALID_CELL


func begin_if_targeted(map: Node2D) -> bool:
	if _pending_cell != INVALID_CELL:
		return false
	var world: RefCounted = map.get("_world") as RefCounted
	var avatar: Node2D = map.get("_avatar") as Node2D
	var bridge: Node = map.get_node_or_null("HarvestPhaseTwo")
	if world == null or avatar == null or bridge == null:
		return false
	if not bool(bridge.call("is_ready_for_commands")):
		return false
	var facing: StringName = map.call("get_facing") as StringName
	var screen: Vector2i = IsometricControlsScript.facing_to_screen_direction(facing)
	var cell: Vector2i = (
		map.call("get_robot_grid") as Vector2i
		+ IsometricControlsScript.screen_to_grid_delta(screen)
	)
	if world.call("_flora_kind_at", cell) as StringName == &"":
		return false
	_pending_cell = cell
	map.set("_velocity", Vector2.ZERO)
	(map.get("_drive_input_buffer") as RefCounted).call("clear")
	map.set("_pending_impact_cell", cell)
	map.set("_pending_impact_cells", [cell])
	map.set("_pending_impact_band", 0)
	map.set("_status_hold_time", 0.7)
	map.call("_update_status", &"status.flora_smash_windup")
	avatar.call("play_attack")
	return true


func resolve_pending(map: Node2D) -> bool:
	if _pending_cell == INVALID_CELL:
		return false
	var cell: Vector2i = _pending_cell
	_pending_cell = INVALID_CELL
	map.set("_pending_impact_cell", INVALID_CELL)
	map.set("_pending_impact_band", 0)
	(map.get("_pending_impact_cells") as Array).clear()
	(map.get("_pending_impact_rock_cells") as Array).clear()
	(map.get("_pending_impact_worm_ids") as Array).clear()
	var charge: Node2D = map.get("_impact_charge") as Node2D
	if charge != null:
		charge.call("consume_attack")
	var bridge: Node = map.get_node_or_null("HarvestPhaseTwo")
	var service: RefCounted = (
		bridge.call("get_interaction_phase_b_service") as RefCounted
		if bridge != null
		else null
	)
	var gathered: Dictionary = (
		service.call("smash_flora", cell) as Dictionary
		if service != null
		else {&"ok": false, &"reason": &"farm_unavailable"}
	)
	var no_props: Array[Dictionary] = []
	var feedback: Node = map.get("_feedback_router") as Node
	feedback.call(
		"present_smash",
		{},
		no_props,
		0,
		Vector2(map.call("get_robot_grid") as Vector2i),
		cell,
	)
	if not bool(gathered.get(&"ok", false)):
		map.call("_update_status", &"status.flora_harvest_failed")
		return true
	var reward: Dictionary = gathered.get(&"reward", {}) as Dictionary
	map.call(
		"_update_status",
		&"status.flora_harvested",
		{
			"produce": int(reward.get(&"produce_count", 0)),
			"seeds": int(reward.get(&"seed_count", 0)),
		},
	)
	print(
		"[WILD_FLORA_HARVEST] species=%s cell=%s produce=%d seeds=%d"
		% [
			gathered.get(&"species_id", &""),
			cell,
			int(reward.get(&"produce_count", 0)),
			int(reward.get(&"seed_count", 0)),
		]
	)
	return true
