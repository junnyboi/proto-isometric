extends RefCounted

const RunPickupsScript: GDScript = preload("res://scripts/run_pickups.gd")
const RunCoordinatorScript: GDScript = preload("res://scripts/run_coordinator.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const DEFAULT_PROFILE: Resource = preload("res://data/combat/sandworm_default.tres")


class FakeWorld:
	extends RefCounted
	var blocked: Dictionary = {}

	func is_walkable(cell: Vector2i) -> bool:
		return not bool(blocked.get(cell, false))

	func is_cell_loaded(_cell: Vector2i) -> bool:
		return true


class ScreenProjection:
	extends RefCounted

	func grid_to_screen(cell: Vector2i) -> Vector2:
		return Vector2(cell) * 10.0


class SaveProbe:
	extends RefCounted
	var calls: int = 0

	func commit() -> bool:
		calls += 1
		return true


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var world: FakeWorld = FakeWorld.new()
	var projection: ScreenProjection = ScreenProjection.new()
	var worms: Node2D = SandwormsScript.new() as Node2D
	worms.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, DEFAULT_PROFILE)
	worms.call("set_auto_spawn", false)
	worms.call("set_player_position", Vector2(3.0, 3.0))
	var pickups: Node2D = RunPickupsScript.new() as Node2D
	_add_case(
		cases,
		"run pickups configure against walkability and projection contracts",
		bool(pickups.call("configure", world, Callable(projection, "grid_to_screen"))),
	)
	_add_case(
		cases, "run pickups bind one worm defeat source", bool(pickups.call("bind_worms", worms))
	)
	var worm_id: int = int(worms.call("spawn_worm", Vector2(4.0, 3.0), 0.0))
	_advance_to_expose(worms, worm_id)
	_add_case(cases, "lethal Expose contact is accepted", bool(worms.call("hit_worm", worm_id, 4)))
	_add_case(
		cases, "one lethal contact creates one run drop", int(pickups.call("get_drop_count")) == 1
	)
	_add_case(
		cases, "one worm drop contains exactly one Core", int(pickups.call("get_total_cores")) == 1
	)
	_add_case(
		cases, "one worm drop contains configured scrap", int(pickups.call("get_total_scrap")) == 2
	)
	worms.emit_signal("defeated", worm_id, Vector2(4.0, 3.0))
	_add_case(
		cases,
		"duplicate defeat signal cannot duplicate rewards",
		int(pickups.call("get_drop_count")) == 1
	)
	var snapshot: Array[Dictionary] = pickups.call("get_snapshot") as Array[Dictionary]
	snapshot[0][&"cores"] = 99
	_add_case(
		cases, "run pickup projections are detached", int(pickups.call("get_total_cores")) == 1
	)
	world.blocked[Vector2i(0, -1)] = true
	worms.call("set_player_position", Vector2.ZERO)
	var blocked_worm: int = int(worms.call("spawn_worm", Vector2.ZERO, 0.0))
	_advance_to_expose(worms, blocked_worm)
	worms.call("hit_worm", blocked_worm, 4)
	var placed: Array[Dictionary] = pickups.call("get_snapshot") as Array[Dictionary]
	_add_case(
		cases,
		"blocked defeat cell resolves to the first deterministic valid neighbor",
		placed[1][&"cell"] == [0, -2],
	)
	var before_dispersal: int = int(pickups.call("get_drop_count"))
	var dispersed_worm: int = int(worms.call("spawn_worm", Vector2(8.0, 8.0), 0.0))
	worms.call("disperse_all")
	worms.call("advance", float(DEFAULT_PROFILE.get("disperse_seconds")))
	_add_case(
		cases,
		"worm dispersal never creates a reward",
		(
			int(pickups.call("get_drop_count")) == before_dispersal
			and worms.call("get_state", dispersed_worm) == &"missing"
		),
	)
	for index: int in range(100):
		worms.emit_signal("defeated", 1000 + index, Vector2(100 + index * 3, 100))
	_add_case(
		cases,
		"active run drop dictionary stays hard bounded",
		int(pickups.call("get_drop_count")) == RunPickupsScript.MAX_ACTIVE_DROPS,
	)
	_test_typed_collection(cases, world, projection)
	pickups.free()
	worms.free()
	return cases


static func _test_typed_collection(
	cases: Array[Dictionary], world: FakeWorld, projection: ScreenProjection
) -> void:
	var coordinator: RefCounted = RunCoordinatorScript.new() as RefCounted
	coordinator.call("configure_default", Vector2i(8, 10), &"SE")
	var save_probe: SaveProbe = SaveProbe.new()
	var pickups: Node2D = RunPickupsScript.new() as Node2D
	(
		pickups
		. call(
			"configure",
			world,
			Callable(projection, "grid_to_screen"),
			coordinator,
			Callable(save_probe, "commit"),
		)
	)
	pickups.call("_on_worm_defeated", 501, Vector2(9.0, 10.0))
	var run_snapshot: Dictionary = coordinator.call("get_run_snapshot") as Dictionary
	_add_case(
		cases,
		"typed worm reward persists immediately",
		(
			(run_snapshot[&"run_drops"] as Array).size() == 1
			and bool(run_snapshot[&"first_worm_defeated"])
			and save_probe.calls == 1
		),
	)
	var restored_pickups: Node2D = RunPickupsScript.new() as Node2D
	restored_pickups.call("configure", world, Callable(projection, "grid_to_screen"), coordinator)
	_add_case(
		cases,
		"run pickup controller restores uncollected rewards",
		int(restored_pickups.call("get_drop_count")) == 1,
	)
	var drop: Dictionary = (run_snapshot[&"run_drops"] as Array)[0] as Dictionary
	var drop_cell: Array = drop[&"cell"] as Array
	var drop_position: Vector2i = Vector2i(int(drop_cell[0]), int(drop_cell[1]))
	var nearby_position: Vector2i = drop_position + Vector2i.LEFT
	coordinator.call("set_run_value", &"player_cell", nearby_position)
	pickups.call("_process", 0.0)
	_add_case(
		cases,
		"resource magnet credits a nearby Core and scrap exactly once",
		(
			Vector2(drop_position - nearby_position).length()
			<= RunPickupsScript.RESOURCE_MAGNET_RADIUS_CELLS
			and nearby_position != drop_position
			and int(coordinator.call("get_run_value", &"worm_cores")) == 1
			and int(coordinator.call("get_run_value", &"scrap")) == 2
			and (coordinator.call("_get_run_drops") as Array[Dictionary]).is_empty()
			and save_probe.calls == 2
		),
	)
	pickups.call("_process", 0.0)
	_add_case(cases, "collected run reward cannot save or credit twice", save_probe.calls == 2)
	restored_pickups.free()
	pickups.free()


static func _advance_to_expose(worms: Node2D, worm_id: int) -> void:
	worms.call("advance", 0.001)
	var snapshot: Dictionary = worms.call("get_combat_snapshot", worm_id) as Dictionary
	worms.call("advance", float(snapshot[&"state_remaining"]))


static func _add_case(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
