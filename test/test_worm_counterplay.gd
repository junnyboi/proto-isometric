extends RefCounted

const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const DEFAULT_PROFILE: Resource = preload("res://data/combat/sandworm_default.tres")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_profile(cases)
	_test_legal_cycle(cases)
	_test_damage_window(cases)
	_test_committed_lead(cases)
	_test_zero_and_large_delta(cases)
	_test_stagger_resume(cases)
	_test_all_state_dispersal(cases)
	_test_reference_fight(cases)
	return cases


static func _test_profile(cases: Array[Dictionary]) -> void:
	_add_case(cases, "worm combat profile validates", bool(DEFAULT_PROFILE.call("validate")))
	_add_case(
		cases,
		"worm combat profile preserves four health",
		int(DEFAULT_PROFILE.get("max_health")) == 4
	)
	_add_case(
		cases,
		"worm combat profile preserves ten damage",
		int(DEFAULT_PROFILE.get("attack_damage")) == 10
	)
	var timings: Dictionary = DEFAULT_PROFILE.call("timing_snapshot") as Dictionary
	_add_case(cases, "worm combat profile defines every timed state", timings.size() == 7)


static func _test_legal_cycle(cases: Array[Dictionary]) -> void:
	var worms: Node2D = _make_worms()
	worms.call("set_player_position", Vector2.ZERO)
	var worm_id: int = int(worms.call("spawn_worm", Vector2(2.0, 0.0), 0.0))
	_add_case(cases, "worm spawns in Burrow", worms.call("get_state", worm_id) == &"burrow")
	worms.call("advance", 0.001)
	_add_case(cases, "Burrow commits Intercept", worms.call("get_state", worm_id) == &"intercept")
	var committed: Dictionary = worms.call("get_combat_snapshot", worm_id) as Dictionary
	_add_case(cases, "Intercept commits one target", committed[&"committed_target"] == Vector2.ZERO)
	_advance_current_state(worms, worm_id)
	_add_case(cases, "Intercept enters Expose", worms.call("get_state", worm_id) == &"expose")
	_add_case(
		cases,
		"committed Intercept resolves one attack",
		int(worms.call("get_last_attack_count")) == 1
	)
	_advance_current_state(worms, worm_id)
	_add_case(cases, "Expose enters Dive", worms.call("get_state", worm_id) == &"dive")
	_advance_current_state(worms, worm_id)
	_add_case(cases, "Dive returns to Burrow", worms.call("get_state", worm_id) == &"burrow")
	worms.free()


static func _test_damage_window(cases: Array[Dictionary]) -> void:
	var worms: Node2D = _make_worms()
	worms.call("set_player_position", Vector2.ZERO)
	var worm_id: int = int(worms.call("spawn_worm", Vector2.ZERO, 0.0))
	_add_case(cases, "Burrow rejects Smash damage", not bool(worms.call("hit_worm", worm_id, 1)))
	worms.call("advance", 0.001)
	_add_case(cases, "Intercept rejects Smash damage", not bool(worms.call("hit_worm", worm_id, 1)))
	_advance_current_state(worms, worm_id)
	_add_case(cases, "Expose accepts Smash damage", bool(worms.call("hit_worm", worm_id, 1)))
	_add_case(
		cases,
		"Expose damage subtracts exactly one health",
		int(worms.call("get_health", worm_id)) == 3
	)
	_add_case(cases, "high charge enters Stagger", bool(worms.call("stagger_worm", worm_id, 5.0)))
	var stagger: Dictionary = worms.call("get_combat_snapshot", worm_id) as Dictionary
	_add_case(
		cases,
		"high-charge Stagger is capped by combat data",
		is_equal_approx(
			float(stagger[&"state_remaining"]),
			float(DEFAULT_PROFILE.get("maximum_stagger_seconds"))
		),
	)
	_add_case(
		cases, "Stagger rejects follow-up damage", not bool(worms.call("hit_worm", worm_id, 1))
	)
	worms.free()


static func _test_committed_lead(cases: Array[Dictionary]) -> void:
	var directions: Array[Vector2] = [
		Vector2.UP,
		Vector2(1.0, -1.0).normalized(),
		Vector2.RIGHT,
		Vector2(1.0, 1.0).normalized(),
		Vector2.DOWN,
		Vector2(-1.0, 1.0).normalized(),
		Vector2.LEFT,
		Vector2(-1.0, -1.0).normalized(),
	]
	for index: int in range(directions.size()):
		var worms: Node2D = _make_worms()
		var direction: Vector2 = directions[index]
		worms.call("set_player_position", Vector2.ZERO, direction * 20.0)
		var worm_id: int = int(worms.call("spawn_worm", Vector2(-3.0, 0.0), 0.0))
		worms.call("advance", float(DEFAULT_PROFILE.get("burrow_seconds")))
		var snapshot: Dictionary = worms.call("get_combat_snapshot", worm_id) as Dictionary
		var lead: Vector2 = snapshot[&"committed_target"] as Vector2
		_add_case(
			cases,
			"Intercept lead direction %d is committed and clamped" % index,
			(
				is_equal_approx(lead.length(), float(DEFAULT_PROFILE.get("maximum_lead_distance")))
				and lead.normalized().dot(direction) > 0.999
			),
		)
		worms.call("set_player_position", Vector2(20.0, 20.0), Vector2.ZERO)
		_add_case(
			cases,
			"Intercept target %d ignores later player movement" % index,
			(worms.call("get_combat_snapshot", worm_id) as Dictionary)[&"committed_target"] == lead,
		)
		worms.free()


static func _test_zero_and_large_delta(cases: Array[Dictionary]) -> void:
	var worms: Node2D = _make_worms()
	worms.call("set_player_position", Vector2.ZERO)
	var worm_id: int = int(worms.call("spawn_worm", Vector2.ZERO, 0.0))
	var before: Dictionary = worms.call("get_combat_snapshot", worm_id) as Dictionary
	worms.call("advance", 0.0)
	_add_case(
		cases,
		"zero delta leaves worm state unchanged",
		worms.call("get_combat_snapshot", worm_id) == before
	)
	worms.call("advance", 20.0)
	var after: Dictionary = worms.call("get_combat_snapshot", worm_id) as Dictionary
	_add_case(
		cases,
		"large delta preserves a legal worm state",
		after[&"state"] in [&"burrow", &"intercept", &"expose", &"dive"]
	)
	_add_case(
		cases,
		"large delta never resolves more attacks than committed windows",
		int(after[&"resolved_attack_serial"]) <= int(after[&"attack_serial"]),
	)
	var attack_count: int = int(worms.call("get_last_attack_count"))
	worms.call("advance", 0.0)
	_add_case(
		cases,
		"zero delta cannot duplicate a committed attack",
		int(worms.call("get_last_attack_count")) == attack_count
	)
	worms.free()


static func _test_stagger_resume(cases: Array[Dictionary]) -> void:
	var worms: Node2D = _make_worms()
	worms.call("set_player_position", Vector2.ZERO)
	var worm_id: int = int(worms.call("spawn_worm", Vector2.ZERO, 0.0))
	worms.call("advance", 0.001)
	_advance_current_state(worms, worm_id)
	_add_case(cases, "stagger setup reaches Expose", worms.call("get_state", worm_id) == &"expose")
	_add_case(cases, "stagger accepts a living worm", bool(worms.call("stagger_worm", worm_id)))
	_add_case(
		cases, "stagger enters bounded side state", worms.call("get_state", worm_id) == &"staggered"
	)
	worms.call("advance", float(DEFAULT_PROFILE.get("stagger_seconds")))
	_add_case(
		cases,
		"stagger resumes the interrupted legal state",
		worms.call("get_state", worm_id) == &"expose"
	)
	worms.free()


static func _test_all_state_dispersal(cases: Array[Dictionary]) -> void:
	var states: Array[StringName] = [
		&"burrow",
		&"intercept",
		&"expose",
		&"dive",
		&"staggered",
		&"defeated",
	]
	for state: StringName in states:
		var worms: Node2D = _make_worms()
		worms.call("set_player_position", Vector2.ZERO)
		var worm_id: int = int(worms.call("spawn_worm", Vector2.ZERO, 0.0))
		_prepare_state(worms, worm_id, state)
		_add_case(
			cases,
			"%s setup reaches requested state" % state,
			worms.call("get_state", worm_id) == state
		)
		worms.call("disperse_all")
		_add_case(
			cases,
			"%s cancels into dispersing" % state,
			worms.call("get_state", worm_id) == &"dispersing"
		)
		worms.call("advance", float(DEFAULT_PROFILE.get("disperse_seconds")))
		_add_case(
			cases, "%s dispersal expires cleanly" % state, int(worms.call("get_worm_count")) == 0
		)
		worms.free()


static func _test_reference_fight(cases: Array[Dictionary]) -> void:
	var worms: Node2D = _make_worms()
	var damage_ticks: Array[int] = [0]
	worms.connect(
		"damage_tick", func(_amount: int, _source: StringName) -> void: damage_ticks[0] += 1
	)
	worms.call("set_player_position", Vector2.ZERO)
	var worm_id: int = int(worms.call("spawn_worm", Vector2(2.0, 0.0), 0.0))
	var elapsed: float = 0.0
	for hit: int in range(4):
		worms.call("set_player_position", Vector2.ZERO)
		var burrow: Dictionary = worms.call("get_combat_snapshot", worm_id) as Dictionary
		var burrow_wait: float = maxf(float(burrow[&"state_remaining"]), 0.001)
		worms.call("advance", burrow_wait)
		elapsed += burrow_wait
		var intercept: Dictionary = worms.call("get_combat_snapshot", worm_id) as Dictionary
		worms.call("set_player_position", Vector2(8.0, 8.0))
		worms.call("advance", float(intercept[&"state_remaining"]))
		elapsed += float(intercept[&"state_remaining"])
		if not bool(worms.call("hit_worm", worm_id, 1)):
			break
		if hit < 3:
			for _phase: int in range(2):
				var phase: Dictionary = worms.call("get_combat_snapshot", worm_id) as Dictionary
				worms.call("advance", float(phase[&"state_remaining"]))
				elapsed += float(phase[&"state_remaining"])
	_add_case(
		cases,
		"reference worm fight lands four readable Expose hits",
		worms.call("get_state", worm_id) == &"defeated",
	)
	_add_case(cases, "reference worm fight completes under twenty-five seconds", elapsed < 25.0)
	_add_case(cases, "respected intercepts deal zero reference damage", damage_ticks[0] == 0)
	worms.free()


static func _prepare_state(worms: Node2D, worm_id: int, state: StringName) -> void:
	if state == &"burrow":
		return
	worms.call("advance", 0.001)
	if state == &"intercept":
		return
	_advance_current_state(worms, worm_id)
	if state == &"expose":
		return
	if state == &"staggered":
		worms.call("stagger_worm", worm_id)
		return
	if state == &"defeated":
		worms.call("hit_worm", worm_id, int(DEFAULT_PROFILE.get("max_health")))
		return
	_advance_current_state(worms, worm_id)


static func _advance_current_state(worms: Node2D, worm_id: int) -> void:
	var snapshot: Dictionary = worms.call("get_combat_snapshot", worm_id) as Dictionary
	worms.call("advance", float(snapshot[&"state_remaining"]))


static func _make_worms() -> Node2D:
	var worms: Node2D = SandwormsScript.new() as Node2D
	worms.call("configure", Vector2(90.0, 45.0), Vector2(760.0, 70.0), DEFAULT_PROFILE)
	worms.call("set_auto_spawn", false)
	return worms


static func _add_case(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
