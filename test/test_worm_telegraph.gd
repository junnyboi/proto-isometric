extends RefCounted

const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const WormTelegraphScript: GDScript = preload("res://scripts/worm_telegraph.gd")
const DEFAULT_PROFILE: Resource = preload("res://data/combat/sandworm_default.tres")
const TILE_SIZE: Vector2 = Vector2(90.0, 45.0)
const MAP_ORIGIN: Vector2 = Vector2(760.0, 70.0)


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_committed_geometry(cases)
	_test_bounded_trail_and_cancel(cases)
	_test_expose_accent(cases)
	return cases


static func _test_committed_geometry(cases: Array[Dictionary]) -> void:
	var worms: Node2D = _make_worms()
	var telegraph: Node2D = _make_telegraph()
	worms.call("set_player_position", Vector2.ZERO, Vector2.RIGHT * 20.0)
	var worm_id: int = int(worms.call("spawn_worm", Vector2(-3.0, 0.0), 0.0))
	worms.call("advance", 0.001)
	telegraph.call("sync_combat_snapshots", worms.call("get_combat_snapshots"))
	var first: Dictionary = telegraph.call("get_telegraph_snapshot", worm_id) as Dictionary
	var target_grid: Vector2 = first[&"target_grid"] as Vector2
	_add_case(
		cases, "worm telegraph exposes one stable committed target", target_grid != Vector2.ZERO
	)
	_add_case(
		cases,
		"worm target marker is world anchored",
		(first[&"target_screen"] as Vector2).is_equal_approx(_grid_to_screen(target_grid)),
	)
	_add_case(
		cases,
		"worm target marker exposes a larger safe-space radius",
		float(first[&"safe_radius"]) > float(first[&"target_radius"]),
	)
	worms.call("set_player_position", Vector2(20.0, 20.0), Vector2.LEFT * 20.0)
	worms.call("advance", 0.1)
	telegraph.call("sync_combat_snapshots", worms.call("get_combat_snapshots"))
	var second: Dictionary = telegraph.call("get_telegraph_snapshot", worm_id) as Dictionary
	_add_case(
		cases,
		"worm target marker ignores later player movement",
		second[&"target_grid"] == target_grid
	)
	_add_case(
		cases,
		"worm countdown decreases through Intercept",
		float(second[&"countdown"]) < float(first[&"countdown"]),
	)
	worms.free()
	telegraph.free()


static func _test_bounded_trail_and_cancel(cases: Array[Dictionary]) -> void:
	var worms: Node2D = _make_worms()
	var telegraph: Node2D = _make_telegraph()
	worms.call("set_player_position", Vector2.ZERO)
	var worm_id: int = int(worms.call("spawn_worm", Vector2(-4.0, 0.0), 0.0))
	for _step: int in range(10):
		worms.call("advance", 0.05)
		telegraph.call("sync_combat_snapshots", worms.call("get_combat_snapshots"))
	var trail_points: int = int(telegraph.call("get_trail_point_count", worm_id))
	_add_case(cases, "worm ridge history accumulates movement", trail_points >= 2)
	_add_case(cases, "worm ridge history remains hard bounded", trail_points <= 7)
	worms.call("disperse_all")
	telegraph.call("sync_combat_snapshots", worms.call("get_combat_snapshots"))
	_add_case(
		cases,
		"worm sanctuary cancellation clears target and trail presentation",
		(
			(telegraph.call("get_telegraph_snapshot", worm_id) as Dictionary).is_empty()
			and int(telegraph.call("get_trail_point_count", worm_id)) == 0
		),
	)
	worms.free()
	telegraph.free()


static func _test_expose_accent(cases: Array[Dictionary]) -> void:
	var worms: Node2D = _make_worms()
	var telegraph: Node2D = _make_telegraph()
	worms.call("set_player_position", Vector2.ZERO)
	var worm_id: int = int(worms.call("spawn_worm", Vector2.ZERO, 0.0))
	worms.call("advance", 0.001)
	var intercept: Dictionary = worms.call("get_combat_snapshot", worm_id) as Dictionary
	worms.call("advance", float(intercept[&"state_remaining"]))
	telegraph.call("sync_combat_snapshots", worms.call("get_combat_snapshots"))
	var exposed: Dictionary = telegraph.call("get_telegraph_snapshot", worm_id) as Dictionary
	_add_case(
		cases, "worm Expose starts one breach accent", float(exposed[&"breach_remaining"]) > 0.0
	)
	telegraph.call("advance", 0.2)
	telegraph.call("sync_combat_snapshots", worms.call("get_combat_snapshots"))
	var retained: Dictionary = telegraph.call("get_telegraph_snapshot", worm_id) as Dictionary
	_add_case(
		cases,
		"repeated Expose snapshots do not restart the breach accent",
		float(retained[&"breach_remaining"]) < float(exposed[&"breach_remaining"]),
	)
	telegraph.call("advance", 10.0)
	var expired: Dictionary = telegraph.call("get_telegraph_snapshot", worm_id) as Dictionary
	_add_case(
		cases,
		"large delta expires breach accent safely",
		is_zero_approx(float(expired[&"breach_remaining"]))
	)
	var before_zero: Dictionary = telegraph.call("get_telegraph_snapshot", worm_id) as Dictionary
	telegraph.call("advance", 0.0)
	_add_case(
		cases,
		"zero delta leaves telegraph facts unchanged",
		telegraph.call("get_telegraph_snapshot", worm_id) == before_zero
	)
	worms.free()
	telegraph.free()


static func _make_worms() -> Node2D:
	var worms: Node2D = SandwormsScript.new() as Node2D
	worms.call("configure", TILE_SIZE, MAP_ORIGIN, DEFAULT_PROFILE)
	worms.call("set_auto_spawn", false)
	return worms


static func _make_telegraph() -> Node2D:
	var telegraph: Node2D = WormTelegraphScript.new() as Node2D
	telegraph.call("configure", TILE_SIZE, MAP_ORIGIN)
	return telegraph


static func _grid_to_screen(position: Vector2) -> Vector2:
	return (
		MAP_ORIGIN
		+ Vector2(
			(position.x - position.y) * TILE_SIZE.x * 0.5,
			(position.x + position.y) * TILE_SIZE.y * 0.5,
		)
	)


static func _add_case(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
