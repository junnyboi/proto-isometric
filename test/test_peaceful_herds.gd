extends RefCounted

const HerdsScript: GDScript = preload("res://scripts/peaceful_herds.gd")
const RunCoordinatorScript: GDScript = preload("res://scripts/run_coordinator.gd")
const RunPickupsScript: GDScript = preload("res://scripts/run_pickups.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const DEFAULT_PROFILE: Resource = preload("res://data/combat/sandworm_default.tres")


class FakeWorld:
	extends RefCounted
	var biome: StringName = &"desert"
	var blocked: Dictionary = {}

	func is_walkable(cell: Vector2i) -> bool:
		return not bool(blocked.get(cell, false))

	func is_cell_loaded(_cell: Vector2i) -> bool:
		return true

	func _biome_at(_cell: Vector2i) -> StringName:
		return biome

	func _is_in_sanctuary(_position: Vector2) -> bool:
		return false


class ScreenProjection:
	extends RefCounted

	func grid_to_screen(cell: Vector2i) -> Vector2:
		return Vector2(cell) * 10.0


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_catalog(cases)
	_test_loot_balance(cases)
	_test_biome_population(cases)
	_test_herd_motion(cases)
	_test_avoidance_and_presentation(cases)
	_test_one_hit_reward(cases)
	_test_fauna_and_pickup_integration(cases)
	return cases


static func _test_catalog(cases: Array[Dictionary]) -> void:
	var expected: Dictionary = {
		&"desert": &"dune_grazer",
		&"oasis": &"reedback",
		&"frozen": &"rimehorn",
		&"lava": &"ember_ram",
	}
	for biome: StringName in expected:
		var kind: StringName = expected[biome] as StringName
		_add(
			cases,
			"%s owns peaceful species %s" % [biome, kind],
			HerdsScript.species_for_biome(biome) == kind,
		)
		var texture: Texture2D = HerdsScript.texture_for(kind)
		_add(
			cases,
			"%s uses one generated transparent runtime sprite" % kind,
			texture != null and texture.get_width() == 512 and texture.get_height() == 512,
		)
		_add(cases, "%s exposes a bounded loot profile" % kind, HerdsScript.resource_amount(kind) > 0)


static func _test_loot_balance(cases: Array[Dictionary]) -> void:
	var expected: Dictionary = {
		&"dune_grazer": Vector2(0.70, 0.03),
		&"reedback": Vector2(0.78, 0.04),
		&"rimehorn": Vector2(0.84, 0.06),
		&"ember_ram": Vector2(0.90, 0.08),
	}
	var herds: Node2D = _make_herds(FakeWorld.new())
	for kind: StringName in expected:
		var profile: Dictionary = HerdsScript.loot_profile(kind)
		var target: Vector2 = expected[kind] as Vector2
		_add(
			cases,
			"%s loot chances match the economy curve" % kind,
			is_equal_approx(float(profile[&"scrap_chance"]), target.x)
			and is_equal_approx(float(profile[&"core_chance"]), target.y),
		)
		herds.call("set_loot_random_seed", 0x4000 + expected.keys().find(kind))
		var scrap_drops: int = 0
		var core_drops: int = 0
		var samples: int = 10_000
		for _sample: int in range(samples):
			var loot: Dictionary = herds.call("_roll_resources", kind) as Dictionary
			scrap_drops += int(loot[&"scrap"])
			core_drops += int(loot[&"cores"])
		_add(
			cases,
			"%s seeded loot frequency stays within two points" % kind,
			absf(float(scrap_drops) / samples - target.x) <= 0.02
			and absf(float(core_drops) / samples - target.y) <= 0.02,
		)
	herds.free()


static func _test_biome_population(cases: Array[Dictionary]) -> void:
	var expected: Dictionary = {
		&"desert": &"dune_grazer",
		&"oasis": &"reedback",
		&"frozen": &"rimehorn",
		&"lava": &"ember_ram",
	}
	var world: FakeWorld = FakeWorld.new()
	var herds: Node2D = _make_herds(world)
	for biome: StringName in expected:
		world.biome = biome
		herds.call("set_active_biome", biome)
		herds.call("set_player_position", Vector2.ZERO)
		var snapshots: Array[Dictionary] = (
			herds.call("get_snapshots") as Array[Dictionary]
		)
		var kind: StringName = expected[biome] as StringName
		var all_native: bool = snapshots.all(
			func(entry: Dictionary) -> bool: return entry[&"kind"] == kind
		)
		_add(
			cases,
			"%s auto-populates two four-member native herds" % biome,
			snapshots.size() == HerdsScript.MAX_CREATURES and all_native,
		)
	herds.free()


static func _test_herd_motion(cases: Array[Dictionary]) -> void:
	var world: FakeWorld = FakeWorld.new()
	var herds: Node2D = _make_herds(world)
	herds.call("set_auto_spawn", false)
	var herd_id: int = int(
		herds.call("spawn_herd", Vector2(18.0, 18.0), 4, &"desert")
	)
	var before: Array[Dictionary] = herds.call("get_snapshots") as Array[Dictionary]
	for _step: int in range(10):
		herds.call("advance", 0.1)
	var after: Array[Dictionary] = herds.call("get_snapshots") as Array[Dictionary]
	var moved: float = (after[0][&"position"] as Vector2).distance_to(
		before[0][&"position"] as Vector2
	)
	var same_herd: bool = after.all(
		func(entry: Dictionary) -> bool: return int(entry[&"herd_id"]) == herd_id
	)
	_add(
		cases,
		"biome herd spawns four peaceful members",
		herd_id > 0 and after.size() == 4 and same_herd,
	)
	_add(
		cases,
		"peaceful herd moves slowly as a group",
		moved > 0.05 and moved <= HerdsScript.FLEE_SPEED + 0.1,
	)
	var center: Vector2 = Vector2.ZERO
	for entry: Dictionary in after:
		center += entry[&"position"] as Vector2
	center /= float(after.size())
	var clustered: bool = after.all(
		func(entry: Dictionary) -> bool:
			return (entry[&"position"] as Vector2).distance_to(center) < 3.5
	)
	_add(cases, "peaceful members retain a readable herd cluster", clustered)
	herds.free()


static func _test_avoidance_and_presentation(cases: Array[Dictionary]) -> void:
	var world: FakeWorld = FakeWorld.new()
	var herds: Node2D = _make_herds(world)
	herds.call("set_auto_spawn", false)
	herds.call("spawn_herd", Vector2(2.0, 0.0), 1, &"desert")
	var creature_id: int = int(
		(herds.call("get_snapshots") as Array[Dictionary])[0][&"id"]
	)
	var before: Vector2 = herds.call("get_creature_position", creature_id) as Vector2
	herds.call("set_player_position", Vector2.ZERO)
	for _step: int in range(8):
		herds.call("advance", 0.1)
	var after: Vector2 = herds.call("get_creature_position", creature_id) as Vector2
	_add(
		cases,
		"peaceful fauna increases distance from a nearby Walker",
		after.length() > before.length(),
	)
	_add(
		cases,
		"movement facing flips across projected direction",
		HerdsScript.facing_left(Vector2.LEFT)
		and not HerdsScript.facing_left(Vector2.RIGHT),
	)
	var low: float = HerdsScript.bounce_offset(0.0, 0.0)
	var high: float = HerdsScript.bounce_offset(0.3, 0.0)
	_add(
		cases,
		"static sprites use bounded code-driven bounce",
		low == 0.0 and high > 0.0 and high <= HerdsScript.BOUNCE_HEIGHT,
	)
	herds.free()


static func _test_one_hit_reward(cases: Array[Dictionary]) -> void:
	for biome: StringName in [&"desert", &"oasis", &"frozen", &"lava"]:
		var world: FakeWorld = FakeWorld.new()
		world.biome = biome
		var herds: Node2D = _make_herds(world)
		herds.call("set_auto_spawn", false)
		herds.call("set_active_biome", biome)
		herds.call("spawn_herd", Vector2(6.0, 6.0), 1, biome)
		var snapshot: Dictionary = (herds.call("get_snapshots") as Array[Dictionary])[0]
		var creature_id: int = int(snapshot[&"id"])
		var rewards: Array[Dictionary] = []
		herds.connect(
			"defeated",
			func(id: int, position: Vector2, cores: int, scrap: int) -> void:
				rewards.append(
					{&"id": id, &"position": position, &"cores": cores, &"scrap": scrap}
				)
		)
		_add(
			cases,
			"%s herd members expose one hit point" % biome,
			int(snapshot[&"health"]) == 1 and int(snapshot[&"max_health"]) == 1,
		)
		var accepted: bool = bool(herds.call("hit_creature", creature_id, 1))
		_add(
			cases,
			"one Impact defeats a %s herd member" % biome,
			accepted and int(herds.call("get_creature_count")) == 0,
		)
		_add(
			cases,
			"%s herd defeat emits its resource drop exactly once" % biome,
				(
					rewards.size() == 1
					and int(rewards[0][&"cores"]) in [0, 1]
					and int(rewards[0][&"scrap"]) in [0, 1]
					and not bool(herds.call("hit_creature", creature_id, 1))
					and rewards.size() == 1
				),
		)
		herds.free()


static func _test_fauna_and_pickup_integration(cases: Array[Dictionary]) -> void:
	var world: FakeWorld = FakeWorld.new()
	var enemies: Node2D = SandwormsScript.new() as Node2D
	enemies.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, DEFAULT_PROFILE, world)
	enemies.call("set_auto_spawn", false)
	var herds: Node2D = enemies.call("_get_peaceful_herds") as Node2D
	herds.call("set_auto_spawn", false)
	var reward_seeded: bool = _seed_scrap_only_reward(herds, &"dune_grazer")
	herds.call("spawn_herd", Vector2(4.0, 4.0), 1, &"desert")
	var creature_id: int = int(
		(herds.call("get_snapshots") as Array[Dictionary])[0][&"id"]
	)
	var creature_cell: Vector2i = Vector2i(
		(herds.call("get_creature_position", creature_id) as Vector2).round()
	)
	var coordinator: RefCounted = RunCoordinatorScript.new() as RefCounted
	coordinator.call("configure_default", Vector2i(8, 10), &"SE")
	var projection: ScreenProjection = ScreenProjection.new()
	var pickups: Node2D = RunPickupsScript.new() as Node2D
	pickups.call("configure", world, Callable(projection, "grid_to_screen"), coordinator)
	_add(
		cases,
		"run pickups bind peaceful and hostile fauna signals",
		bool(pickups.call("bind_worms", enemies)),
	)
	_add(
		cases,
		"Impact target routes through fauna authority",
		int(enemies.call("find_target", creature_cell)) == creature_id,
	)
	_add(
		cases,
		"fauna authority accepts one-hit peaceful Impact",
		bool(enemies.call("hit_worm", creature_id, 1)),
	)
	var drops: Array[Dictionary] = coordinator.call("_get_run_drops") as Array[Dictionary]
	_add(
		cases,
		"peaceful defeat creates one balanced persistent resource pickup",
		reward_seeded
		and drops.size() == 1
		and int(drops[0][&"cores"]) == 0
		and int(drops[0][&"scrap"]) == 1,
	)
	pickups.free()
	enemies.free()


static func _seed_scrap_only_reward(herds: Node2D, kind: StringName) -> bool:
	for seed_value: int in range(1, 512):
		herds.call("set_loot_random_seed", seed_value)
		var loot: Dictionary = herds.call("_roll_resources", kind) as Dictionary
		if int(loot[&"cores"]) == 0 and int(loot[&"scrap"]) == 1:
			herds.call("set_loot_random_seed", seed_value)
			return true
	return false


static func _make_herds(world: FakeWorld) -> Node2D:
	var herds: Node2D = HerdsScript.new() as Node2D
	herds.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, world)
	return herds


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
