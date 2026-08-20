extends RefCounted

const BiomeDestructiblesScript: GDScript = preload("res://scripts/biome_destructibles.gd")
const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const WorldObjectsScript: GDScript = preload("res://scripts/world_objects.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_variant_contract(cases)
	_test_runtime_assets(cases)
	_test_world_binding(cases)
	_test_break_and_save_compatibility(cases)
	return cases


static func _test_variant_contract(cases: Array[Dictionary]) -> void:
	_add(
		cases,
		"desert cells retain the procedural rock fallback",
		BiomeDestructiblesScript.kind_for(&"desert", Vector2i(8, 10))
		== BiomeDestructiblesScript.KIND_DESERT_ROCK,
	)
	var expected: Dictionary = {
		&"oasis": [
			BiomeDestructiblesScript.KIND_WETLAND_MANGROVE,
			BiomeDestructiblesScript.KIND_WETLAND_STUMP,
		],
		&"frozen": [
			BiomeDestructiblesScript.KIND_FROZEN_SNOW_ROCK,
			BiomeDestructiblesScript.KIND_FROZEN_PINE,
		],
		&"lava": [
			BiomeDestructiblesScript.KIND_LAVA_BASALT_CHIMNEY,
			BiomeDestructiblesScript.KIND_LAVA_OBSIDIAN_CLUSTER,
		],
	}
	for biome: StringName in expected:
		var found: Dictionary = {}
		for y: int in range(-4, 5):
			for x: int in range(-4, 5):
				var cell: Vector2i = Vector2i(x, y)
				var kind: StringName = BiomeDestructiblesScript.kind_for(biome, cell)
				found[kind] = true
				_add(
					cases,
					"%s destructible selection is deterministic at %s" % [biome, cell],
					kind == BiomeDestructiblesScript.kind_for(biome, cell),
				)
		var expected_kinds: Array = expected[biome] as Array
		_add(
			cases,
			"%s exposes both biome-native destructible variants" % biome,
			found.size() == 2 and found.has(expected_kinds[0]) and found.has(expected_kinds[1]),
		)


static func _test_runtime_assets(cases: Array[Dictionary]) -> void:
	var paths: Array[String] = BiomeDestructiblesScript.get_required_paths()
	_add(cases, "six generated destructible sprites are registered", paths.size() == 6)
	for kind: StringName in BiomeDestructiblesScript.GENERATED_KINDS:
		var texture: Texture2D = BiomeDestructiblesScript.texture_for(kind)
		var size: Vector2 = BiomeDestructiblesScript.display_size_for(kind)
		_add(
			cases,
			"%s runtime sprite is a 256 pixel RGBA texture" % kind,
			texture != null and texture.get_size() == Vector2(256.0, 256.0),
		)
		_add(
			cases,
			"%s display bounds remain inside one readable object envelope" % kind,
			size.x >= 70.0 and size.x <= 96.0 and size.y >= 56.0 and size.y <= 140.0,
		)


static func _test_world_binding(cases: Array[Dictionary]) -> void:
	var terrain: Dictionary = {}
	var elevation: Dictionary = {}
	var blocked: Dictionary = {}
	var rocks: Dictionary = {}
	var scrap: Dictionary = {}
	var outposts: Dictionary = {}
	var world: RefCounted = InfiniteWorldScript.new() as RefCounted
	world.call("configure", terrain, elevation, blocked, rocks, scrap, outposts)
	var cell: Vector2i = _find_natural_rock(world, &"frozen")
	world.call("terrain_at", cell)
	var objects: Node2D = WorldObjectsScript.new() as Node2D
	objects.call(
		"configure",
		rocks,
		scrap,
		outposts,
		func(value: Vector2i) -> Vector2: return Vector2(value),
	)
	objects.call("bind_world", world, func(_amount: int, _source: StringName) -> void: pass)
	_add(
		cases,
		"WorldObjects resolves frozen rock truth through the biome adapter",
		objects.call("get_destructible_kind", cell)
		== BiomeDestructiblesScript.kind_for(&"frozen", cell),
	)
	objects.free()


static func _test_break_and_save_compatibility(cases: Array[Dictionary]) -> void:
	for biome: StringName in [&"oasis", &"frozen", &"lava"]:
		var terrain: Dictionary = {}
		var elevation: Dictionary = {}
		var blocked: Dictionary = {}
		var rocks: Dictionary = {}
		var scrap: Dictionary = {}
		var outposts: Dictionary = {}
		var world: RefCounted = InfiniteWorldScript.new() as RefCounted
		world.call("configure", terrain, elevation, blocked, rocks, scrap, outposts)
		var cell: Vector2i = _find_natural_rock(world, biome)
		_add(cases, "%s has a natural rock fixture" % biome, cell.x <= 72)
		world.call("terrain_at", cell)
		_add(
			cases,
			"%s fixture starts as a blocking rock" % biome,
			bool(rocks.get(cell, false)),
		)
		_add(
			cases,
			"%s native destructible breaks through rock truth" % biome,
			world.call("break_rock", cell),
		)
		_add(
			cases,
			"%s native destructible still drops exactly two scrap" % biome,
			world.call("collect_scrap", cell) == 2,
		)
		var snapshot: Dictionary = world.call("make_snapshot") as Dictionary
		var stored_cell: Array[int] = [cell.x, cell.y]
		_add(
			cases,
			"%s destruction remains in the existing destroyed_rocks field" % biome,
			stored_cell in (snapshot["destroyed_rocks"] as Array),
		)
		_add(
			cases,
			"%s save stores no presentation-only biome variant" % biome,
			not snapshot.has("destructible_kinds"),
		)


static func _find_natural_rock(world: RefCounted, biome: StringName) -> Vector2i:
	for y: int in range(-72, 73):
		for x: int in range(-72, 73):
			var cell: Vector2i = Vector2i(x, y)
			if (
				world.call("_biome_at", cell) == biome
				and world.call("_base_terrain", cell) == &"rock"
				and not bool(world.call("_is_outpost", cell))
			):
				return cell
	return Vector2i(1_000_001, 1_000_001)


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
