extends RefCounted

const FaunaCombatScript: GDScript = preload("res://scripts/fauna_combat_catalog.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const WormTelegraphScript: GDScript = preload("res://scripts/worm_telegraph.gd")
const DEFAULT_PROFILE: Resource = preload("res://data/combat/sandworm_default.tres")
const TILE_SIZE: Vector2 = Vector2(90.0, 45.0)
const MAP_ORIGIN: Vector2 = Vector2(760.0, 70.0)


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_catalog(cases)
	_test_balance_budget(cases)
	_test_native_cycle(cases, &"oasis", &"mud_skimmer", &"skim", &"wake_warning", &"wake_sweep", 6)
	_test_native_cycle(
		cases, &"frozen", &"rime_stalker", &"stalk", &"pounce_warning", &"pounce", 10
	)
	_test_native_cycle(
		cases, &"lava", &"cinder_crawler", &"brace", &"salvo_warning", &"ember_salvo", 5
	)
	_test_unique_telegraphs(cases)
	_test_large_delta_salvo_bound(cases)
	return cases


static func _test_catalog(cases: Array[Dictionary]) -> void:
	_add(cases, "Sandworm exclusively owns burrowing", FaunaCombatScript.is_burrower(&"sandworm"))
	for kind: StringName in [&"mud_skimmer", &"rime_stalker", &"cinder_crawler"]:
		_add(cases, "%s never owns burrowing" % kind, not FaunaCombatScript.is_burrower(kind))
		_add(
			cases,
			"%s primary cycle excludes Burrow and Dive" % kind,
			(
				not FaunaCombatScript.legal_primary_state(kind, &"burrow")
				and not FaunaCombatScript.legal_primary_state(kind, &"dive")
			),
		)
		_add(
			cases,
			"%s owns one explicit warning state" % kind,
			FaunaCombatScript.legal_primary_state(kind, FaunaCombatScript.warning_state(kind)),
		)


static func _test_balance_budget(cases: Array[Dictionary]) -> void:
	var expected_damage: Dictionary = {
		&"mud_skimmer": 6,
		&"rime_stalker": 10,
		&"cinder_crawler": 5,
	}
	for kind: StringName in expected_damage:
		var warning_seconds: float = FaunaCombatScript.value(kind, &"warning_seconds")
		var attack_seconds: float = FaunaCombatScript.value(kind, &"attack_seconds")
		var recovery_seconds: float = FaunaCombatScript.value(kind, &"recover_seconds")
		var tracking_seconds: float = FaunaCombatScript.value(kind, &"tracking_seconds")
		var pulses: int = 3 if kind == &"cinder_crawler" else 1
		var worst_cycle_damage: float = float(expected_damage[kind]) * float(pulses)
		var cycle_seconds: float = (
			tracking_seconds + warning_seconds + attack_seconds + recovery_seconds
		)
		_add(cases, "%s warning is at least 600 ms" % kind, warning_seconds >= 0.6)
		_add(
			cases,
			"%s recovery is no shorter than its attack" % kind,
			recovery_seconds >= attack_seconds,
		)
		_add(
			cases,
			"%s tuned damage matches its combat role" % kind,
			FaunaCombatScript.damage(kind, DEFAULT_PROFILE) == int(expected_damage[kind]),
		)
		_add(
			cases,
			"%s worst-case pressure stays below three chassis per second" % kind,
			worst_cycle_damage / cycle_seconds < 3.0,
		)


static func _test_native_cycle(
	cases: Array[Dictionary],
	biome: StringName,
	kind: StringName,
	tracking_state: StringName,
	warning_state: StringName,
	attack_state: StringName,
	damage: int,
) -> void:
	var enemies: Node2D = _make_enemies(biome)
	var hits: Array[Dictionary] = []
	enemies.connect(
		"damage_tick",
		func(amount: int, source: StringName) -> void:
			hits.append({&"amount": amount, &"source": source})
	)
	enemies.call("set_player_position", Vector2.ZERO)
	var enemy_id: int = int(enemies.call("spawn_worm", Vector2(2.0, 0.0), 0.0))
	_add(cases, "%s spawns as itself" % kind, enemies.call("_get_enemy_kind", enemy_id) == kind)
	_add(
		cases,
		"%s starts visibly in %s" % [kind, tracking_state],
		enemies.call("get_state", enemy_id) == tracking_state,
	)
	_add(
		cases,
		"%s tracking rejects premature Smash" % kind,
		not bool(enemies.call("hit_worm", enemy_id, 1)),
	)
	enemies.call("advance", 0.001)
	_add(
		cases,
		"%s commits a visible %s before attacking" % [kind, warning_state],
		enemies.call("get_state", enemy_id) == warning_state,
	)
	var committed: Dictionary = enemies.call("get_combat_snapshot", enemy_id) as Dictionary
	_add(
		cases,
		"%s publishes its unique attack pattern" % kind,
		committed[&"attack_pattern"] == FaunaCombatScript.attack_pattern(kind),
	)
	_add(cases, "%s warning deals no damage" % kind, hits.is_empty())
	_add(cases, "%s warning rejects Smash" % kind, not bool(enemies.call("hit_worm", enemy_id, 1)))
	enemies.call("advance", float(committed[&"state_remaining"]))
	_add(
		cases,
		"%s warning resolves into %s" % [kind, attack_state],
		enemies.call("get_state", enemy_id) == attack_state,
	)
	_add(cases, "%s attack has not damaged on frame zero" % kind, hits.is_empty())
	var attack: Dictionary = enemies.call("get_combat_snapshot", enemy_id) as Dictionary
	_add(cases, "%s attack rejects Smash" % kind, not bool(enemies.call("hit_worm", enemy_id, 1)))
	enemies.call("advance", float(attack[&"state_remaining"]))
	_add(
		cases,
		"%s enters a recovery counter-window" % kind,
		enemies.call("get_state", enemy_id) == &"recover",
	)
	_add(cases, "%s resolves one bounded damage tick" % kind, hits.size() == 1)
	if not hits.is_empty():
		_add(cases, "%s deals its own damage value" % kind, int(hits[0][&"amount"]) == damage)
		_add(cases, "%s reports its own damage source" % kind, hits[0][&"source"] == kind)
	_add(cases, "%s recovery accepts Smash" % kind, bool(enemies.call("hit_worm", enemy_id, 1)))
	_add(
		cases,
		"%s recovery accepts Aftershock stagger" % kind,
		bool(enemies.call("stagger_worm", enemy_id)),
	)
	_add(
		cases,
		"%s enters bounded Stagger" % kind,
		enemies.call("get_state", enemy_id) == &"staggered",
	)
	var staggered: Dictionary = enemies.call("get_combat_snapshot", enemy_id) as Dictionary
	enemies.call("advance", float(staggered[&"state_remaining"]))
	_add(
		cases,
		"%s resumes its interrupted recovery" % kind,
		enemies.call("get_state", enemy_id) == &"recover",
	)
	var recovery: Dictionary = enemies.call("get_combat_snapshot", enemy_id) as Dictionary
	enemies.call("advance", float(recovery[&"state_remaining"]))
	_add(
		cases,
		"%s recovery returns to %s" % [kind, tracking_state],
		enemies.call("get_state", enemy_id) == tracking_state,
	)
	enemies.call("disperse_all")
	_add(
		cases,
		"%s sanctuary cancellation starts dispersal" % kind,
		enemies.call("get_state", enemy_id) == &"dispersing",
	)
	enemies.call("advance", float(DEFAULT_PROFILE.get("disperse_seconds")))
	_add(
		cases,
		"%s sanctuary dispersal expires cleanly" % kind,
		int(enemies.call("get_worm_count")) == 0,
	)
	enemies.free()


static func _test_unique_telegraphs(cases: Array[Dictionary]) -> void:
	var expected: Dictionary = {
		&"oasis": {&"pattern": &"wake_line", &"pulses": 1},
		&"frozen": {&"pattern": &"frost_pounce", &"pulses": 1},
		&"lava": {&"pattern": &"ember_salvo", &"pulses": 3},
	}
	for biome: StringName in expected:
		var enemies: Node2D = _make_enemies(biome)
		var telegraph: Node2D = WormTelegraphScript.new() as Node2D
		telegraph.call("configure", TILE_SIZE, MAP_ORIGIN)
		enemies.call("set_player_position", Vector2.ZERO)
		var enemy_id: int = int(enemies.call("spawn_worm", Vector2(2.0, 0.0), 0.0))
		enemies.call("advance", 0.001)
		telegraph.call("sync_combat_snapshots", enemies.call("get_combat_snapshots"))
		var snapshot: Dictionary = telegraph.call("get_telegraph_snapshot", enemy_id) as Dictionary
		var facts: Dictionary = expected[biome] as Dictionary
		_add(
			cases,
			"%s fauna exposes the correct telegraph" % biome,
			snapshot[&"attack_pattern"] == facts[&"pattern"],
		)
		_add(
			cases,
			"%s fauna never emits a burrow trail" % biome,
			int(snapshot[&"trail_points"]) == 0,
		)
		_add(
			cases,
			"%s fauna exposes its attack pulse count" % biome,
			int(snapshot[&"strike_pulses"]) == int(facts[&"pulses"]),
		)
		_add(
			cases,
			"%s fauna exposes an active pre-attack countdown" % biome,
			bool(snapshot[&"warning_active"]) and float(snapshot[&"warning_countdown"]) > 0.99,
		)
		_add(
			cases,
			"%s fauna commits stable attack geometry" % biome,
			(snapshot[&"attack_origin"] as Vector2) != (snapshot[&"target_grid"] as Vector2),
		)
		if biome == &"lava":
			_add(
				cases,
				"Ember Salvo commits three ordered blast cells",
				(snapshot[&"strike_targets"] as Array).size() == 3,
			)
		enemies.free()
		telegraph.free()


static func _test_large_delta_salvo_bound(cases: Array[Dictionary]) -> void:
	var enemies: Node2D = _make_enemies(&"lava")
	var hit_count: Array[int] = [0]
	enemies.connect(
		"damage_tick", func(_amount: int, _source: StringName) -> void: hit_count[0] += 1
	)
	enemies.call("set_player_position", Vector2.ZERO)
	var enemy_id: int = int(enemies.call("spawn_worm", Vector2(2.0, 0.0), 0.0))
	enemies.call("advance", 0.001)
	var warning: Dictionary = enemies.call("get_combat_snapshot", enemy_id) as Dictionary
	enemies.call("advance", float(warning[&"state_remaining"]))
	var salvo: Dictionary = enemies.call("get_combat_snapshot", enemy_id) as Dictionary
	enemies.call("advance", float(salvo[&"state_remaining"]))
	var recovered: Dictionary = enemies.call("get_combat_snapshot", enemy_id) as Dictionary
	_add(cases, "large-frame Ember Salvo stacks at most one hit", hit_count[0] <= 1)
	_add(
		cases,
		"large-frame Ember Salvo resolves all three pulse slots",
		int(recovered[&"resolved_pulses"]) == 3,
	)
	enemies.call("advance", 0.0)
	_add(cases, "zero delta cannot replay Ember Salvo damage", hit_count[0] <= 1)
	enemies.free()


static func _make_enemies(biome: StringName) -> Node2D:
	var enemies: Node2D = SandwormsScript.new() as Node2D
	enemies.call("configure", TILE_SIZE, MAP_ORIGIN, DEFAULT_PROFILE)
	enemies.call("set_auto_spawn", false)
	enemies.call("_set_active_biome", biome)
	return enemies


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
