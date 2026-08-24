extends RefCounted


static func evaluate_live(map: Node, world_objects: Node2D, heat_haze: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var occupied: Array[Vector2i] = map.call("get_robot_occupied_cells") as Array[Vector2i]
	_add(cases, "Walker exposes at least one occupied foot tile", not occupied.is_empty())
	_add(
		cases,
		"occupied footprint remains gameplay-only without a debug renderer",
		(
			not world_objects.has_method("set_occupied_cells")
			and not world_objects.has_method("_draw_occupied_tile_borders")
		),
	)
	var avatar: Node2D = map.get("_avatar") as Node2D
	var foot_offset: Vector2 = avatar.call("get_visual_foot_offset") as Vector2
	_add(
		cases,
		"Walker visible feet resolve to the authoritative world origin",
		foot_offset.length() <= 0.5,
	)

	_add(cases, "place Walker beside rock", bool(map.call("place_robot", Vector2i(3, 4))))
	_add(
		cases,
		"destructible rock exists",
		bool(map.call("has_destructible_rock", Vector2i(4, 4))),
	)
	_add(
		cases,
		"intact rock masks haze",
		not bool(heat_haze.call("has_haze_at", Vector2i(4, 4))),
	)
	var start: Vector2 = map.call("get_robot_position") as Vector2
	var reached_contact: bool = false
	for _step: int in range(80):
		if not bool(map.call("update_drive", Vector2(1.0, 1.0).normalized(), 0.05, false)):
			reached_contact = true
			break
	var contact: Vector2 = map.call("get_robot_position") as Vector2
	_add(cases, "rock stops Walker at the crossed tile boundary", reached_contact)
	_add(cases, "Walker advances to obstacle contact before stopping", contact != start)
	_add(cases, "blocked tile is never occupied", map.call("get_robot_grid") == Vector2i(3, 4))
	_add(
		cases,
		"Walker stops within one drive step of the obstacle tile boundary",
		(
			map.call("screen_to_grid", contact + Vector2(1.0, 1.0).normalized() * 8.0)
			== Vector2i(4, 4)
		),
	)
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
