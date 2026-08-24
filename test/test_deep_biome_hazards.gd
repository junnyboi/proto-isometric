extends RefCounted

const HazardsScript: GDScript = preload("res://scripts/desert_hazards.gd")

const BIOMES: Array[StringName] = [&"desert", &"oasis", &"frozen", &"lava"]
const EXPECTED: Dictionary = {
	&"desert": {&"kind": &"quicksand_collapse", &"damage": 5},
	&"oasis": {&"kind": &"bog_gas_bloom", &"damage": 4},
	&"frozen": {&"kind": &"ice_shear", &"damage": 6},
	&"lava": {&"kind": &"magma_vent", &"damage": 8},
}


class FakeWorld:
	extends RefCounted
	var biome: StringName = &"desert"
	var sanctuary: bool = false

	func _biome_at(_cell: Vector2i) -> StringName:
		return biome

	func _is_in_sanctuary(_position: Vector2) -> bool:
		return sanctuary


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_profiles_and_depth(cases)
	_test_candidate_density(cases)
	_test_telegraphs_and_damage(cases)
	_test_random_entry_contract(cases)
	return cases


static func _test_profiles_and_depth(cases: Array[Dictionary]) -> void:
	for biome: StringName in BIOMES:
		var profile: Dictionary = HazardsScript.profile_for_biome(biome)
		var expected: Dictionary = EXPECTED[biome] as Dictionary
		_add(
			cases,
			"%s deep hazard has a distinct bounded profile" % biome,
			profile[&"kind"] == expected[&"kind"]
			and int(profile[&"damage"]) == int(expected[&"damage"])
			and float(profile[&"telegraph"]) >= 1.0
			and float(profile[&"lifetime"]) > float(profile[&"telegraph"]),
		)
	_add(
		cases,
		"deep-biome thresholds exclude entry corridors and include interiors",
		not HazardsScript.is_deep_biome_cell(&"desert", Vector2i(8, 10))
		and HazardsScript.is_deep_biome_cell(&"desert", Vector2i(0, 26))
		and not HazardsScript.is_deep_biome_cell(&"oasis", Vector2i(18, 10))
		and HazardsScript.is_deep_biome_cell(&"oasis", Vector2i(32, 10))
		and not HazardsScript.is_deep_biome_cell(&"frozen", Vector2i(8, -8))
		and HazardsScript.is_deep_biome_cell(&"frozen", Vector2i(8, -22))
		and not HazardsScript.is_deep_biome_cell(&"lava", Vector2i(-8, 8))
		and HazardsScript.is_deep_biome_cell(&"lava", Vector2i(-22, 8)),
	)


static func _test_candidate_density(cases: Array[Dictionary]) -> void:
	var candidates: int = 0
	var samples: int = 0
	for y: int in range(-72, 73):
		for x: int in range(-72, 73):
			samples += 1
			if HazardsScript.is_deep_event_candidate(Vector2i(x, y)):
				candidates += 1
	var density: float = float(candidates) / float(samples)
	_add(
		cases,
		"deep hazard candidate density remains near forty-five percent",
		density >= 0.43 and density <= 0.47,
	)


static func _test_telegraphs_and_damage(cases: Array[Dictionary]) -> void:
	var world: FakeWorld = FakeWorld.new()
	var hazards: Node2D = _make_hazards(world)
	var hits: Array[Dictionary] = []
	hazards.connect(
		"damage_tick",
		func(amount: int, source: StringName) -> void:
			hits.append({&"amount": amount, &"source": source})
	)
	for biome: StringName in BIOMES:
		hazards.call("clear_hazards")
		world.biome = biome
		var cell: Vector2i = _candidate_cell(biome)
		hazards.call("set_deep_events_enabled", false)
		hazards.call("set_player_cell", cell)
		var event_id: int = int(hazards.call("force_deep_event", biome, cell))
		var profile: Dictionary = HazardsScript.profile_for_biome(biome)
		var hit_count: int = hits.size()
		hazards.call("advance", float(profile[&"telegraph"]) - 0.01)
		var safe_during_telegraph: bool = hits.size() == hit_count
		hazards.call("advance", 0.02)
		var expected: Dictionary = EXPECTED[biome] as Dictionary
		var impact_exact: bool = (
			hits.size() == hit_count + 1
			and int(hits[-1][&"amount"]) == int(expected[&"damage"])
			and hits[-1][&"source"] == expected[&"kind"]
		)
		hazards.call("advance", float(profile[&"lifetime"]))
		_add(
			cases,
			"%s event telegraphs, hits once, and expires" % biome,
			event_id > 0
			and safe_during_telegraph
			and impact_exact
			and int(hazards.call("get_deep_event_count")) == 0,
		)
	hazards.free()


static func _test_random_entry_contract(cases: Array[Dictionary]) -> void:
	var world: FakeWorld = FakeWorld.new()
	var hazards: Node2D = _make_hazards(world)
	hazards.call("set_event_random_seed", _trigger_seed())
	var first: Vector2i = _candidate_cell(&"desert", 0)
	var second: Vector2i = _candidate_cell(&"desert", 1)
	var third: Vector2i = _candidate_cell(&"desert", 2)
	hazards.call("set_player_cell", first)
	_add(
		cases,
		"seeded deep-tile entry starts one random hazard",
		int(hazards.call("get_deep_event_count")) == 1,
	)
	hazards.call("clear_hazards")
	hazards.call("set_event_random_seed", _trigger_seed())
	hazards.call("set_player_cell", first)
	_add(
		cases,
		"remaining on one tile cannot retrigger its event",
		int(hazards.call("get_deep_event_count")) == 0,
	)
	hazards.call("set_player_cell", second)
	_add(
		cases,
		"shared cooldown blocks adjacent deep-tile event chains",
		int(hazards.call("get_deep_event_count")) == 0,
	)
	hazards.call("advance", HazardsScript.DEEP_EVENT_COOLDOWN_SECONDS)
	hazards.call("set_event_random_seed", _trigger_seed())
	hazards.call("set_player_cell", third)
	_add(
		cases,
		"deep events become eligible after the bounded cooldown",
		int(hazards.call("get_deep_event_count")) == 1,
	)
	hazards.call("clear_hazards")
	hazards.call("reset_deep_event_cooldown")
	world.sanctuary = true
	hazards.call("set_event_random_seed", _trigger_seed())
	hazards.call("set_player_cell", _candidate_cell(&"desert", 3))
	_add(
		cases,
		"outpost sanctuary suppresses deep-tile events",
		int(hazards.call("get_deep_event_count")) == 0,
	)
	world.sanctuary = false
	hazards.call("force_deep_event", &"desert", first)
	hazards.call("force_deep_event", &"oasis", _candidate_cell(&"oasis"))
	var rejected: int = int(
		hazards.call("force_deep_event", &"frozen", _candidate_cell(&"frozen"))
	)
	_add(
		cases,
		"deep hazard population is hard-capped at two",
		int(hazards.call("get_deep_event_count")) == HazardsScript.MAX_DEEP_EVENTS
		and rejected == -1,
	)
	hazards.free()


static func _candidate_cell(biome: StringName, skip: int = 0) -> Vector2i:
	var found: int = 0
	var start: int = 22
	if biome == &"desert":
		start = 26
	elif biome == &"oasis":
		start = 32
	for distance: int in range(start, 73):
		var cell: Vector2i
		match biome:
			&"desert":
				cell = Vector2i(0, distance)
			&"oasis":
				cell = Vector2i(distance, 10)
			&"frozen":
				cell = Vector2i(8, -distance)
			_:
				cell = Vector2i(-distance, 8)
		if HazardsScript.is_deep_event_candidate(cell):
			if found == skip:
				return cell
			found += 1
	return Vector2i(0, 26)


static func _trigger_seed() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for seed_value: int in range(1, 2048):
		rng.seed = seed_value
		if rng.randf() <= HazardsScript.DEEP_TRIGGER_CHANCE:
			return seed_value
	return 1


static func _make_hazards(world: FakeWorld) -> Node2D:
	var hazards: Node2D = HazardsScript.new() as Node2D
	hazards.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, Vector2i(14, 14), world)
	hazards.call("set_auto_spawn", false)
	return hazards


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
