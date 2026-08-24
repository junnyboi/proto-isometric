extends RefCounted

const BiomeDestructiblesScript: GDScript = preload("res://scripts/biome_destructibles.gd")
const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const TerrainRendererScript: GDScript = preload("res://scripts/terrain_renderer.gd")
const WorldObjectsScript: GDScript = preload("res://scripts/world_objects.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_variant_contract(cases)
	_test_debris_palettes(cases)
	_test_obstacle_block_palettes(cases)
	_test_runtime_assets(cases)
	_test_world_binding(cases)
	_test_break_and_save_compatibility(cases)
	return cases


static func _test_variant_contract(cases: Array[Dictionary]) -> void:
	_add(
		cases,
		"desert cells retain the procedural rock fallback",
		(
			BiomeDestructiblesScript.kind_for(&"desert", Vector2i(8, 10))
			== BiomeDestructiblesScript.KIND_DESERT_ROCK
		),
	)
	var expected: Dictionary = {
		&"oasis":
		[
			BiomeDestructiblesScript.KIND_WETLAND_MANGROVE,
			BiomeDestructiblesScript.KIND_WETLAND_STUMP,
		],
		&"frozen":
		[
			BiomeDestructiblesScript.KIND_FROZEN_SNOW_ROCK,
			BiomeDestructiblesScript.KIND_FROZEN_PINE,
		],
		&"lava":
		[
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


static func _test_debris_palettes(cases: Array[Dictionary]) -> void:
	var desert: Array[Color] = BiomeDestructiblesScript.debris_palette_for(&"desert_rock")
	var wetland: Array[Color] = BiomeDestructiblesScript.debris_palette_for(&"wetland_stump")
	var frozen_rock: Array[Color] = BiomeDestructiblesScript.debris_palette_for(&"frozen_snow_rock")
	var frozen_pine: Array[Color] = BiomeDestructiblesScript.debris_palette_for(&"frozen_pine")
	var lava: Array[Color] = BiomeDestructiblesScript.debris_palette_for(&"lava_obsidian_cluster")
	_add(
		cases,
		"every biome debris palette has at least three colors",
		(
			desert.size() >= 3
			and wetland.size() >= 3
			and frozen_rock.size() >= 3
			and frozen_pine.size() >= 3
			and lava.size() >= 3
		)
	)
	_add(
		cases,
		"wetland debris differs from desert rock debris",
		wetland != desert,
	)
	_add(
		cases,
		"frozen tree debris differs from frozen stone debris",
		frozen_pine != frozen_rock,
	)
	_add(
		cases,
		"lava debris differs from every cold palette",
		lava != frozen_rock and lava != frozen_pine,
	)


static func _test_obstacle_block_palettes(cases: Array[Dictionary]) -> void:
	var kinds: Array[StringName] = [
		BiomeDestructiblesScript.KIND_DESERT_ROCK,
		BiomeDestructiblesScript.KIND_WETLAND_STUMP,
		BiomeDestructiblesScript.KIND_FROZEN_SNOW_ROCK,
		BiomeDestructiblesScript.KIND_FROZEN_PINE,
		BiomeDestructiblesScript.KIND_LAVA_BASALT_CHIMNEY,
		BiomeDestructiblesScript.KIND_LAVA_OBSIDIAN_CLUSTER,
	]
	var top_colors: Dictionary = {}
	var faces_valid: bool = true
	var native_targets: Dictionary = {
		BiomeDestructiblesScript.KIND_DESERT_ROCK: Color("874627"),
		BiomeDestructiblesScript.KIND_WETLAND_STUMP: Color("8e873c"),
		BiomeDestructiblesScript.KIND_FROZEN_SNOW_ROCK: Color("bec9d5"),
		BiomeDestructiblesScript.KIND_FROZEN_PINE: Color("526f7a"),
		BiomeDestructiblesScript.KIND_LAVA_BASALT_CHIMNEY: Color("28292b"),
		BiomeDestructiblesScript.KIND_LAVA_OBSIDIAN_CLUSTER: Color("1f1f29"),
	}
	var native_harmony: bool = true
	for kind: StringName in kinds:
		var palette: Dictionary = BiomeDestructiblesScript.block_palette_for(kind)
		var top: Color = palette.get(&"top", Color.TRANSPARENT) as Color
		var right: Color = palette.get(&"right", Color.TRANSPARENT) as Color
		var left: Color = palette.get(&"left", Color.TRANSPARENT) as Color
		top_colors[top.to_html()] = true
		native_harmony = native_harmony and _color_distance(top, native_targets[kind]) < 0.25
		faces_valid = (
			faces_valid
			and top.a > 0.99
			and right.get_luminance() < top.get_luminance()
			and left.get_luminance() < right.get_luminance()
		)
	_add(cases, "every obstacle palette has readable top and shaded side faces", faces_valid)
	_add(
		cases,
		"desert, wetland, frozen stone, frozen wood, basalt, and obsidian blocks differ",
		top_colors.size() == kinds.size(),
	)
	_add(
		cases,
		"obstacle tops remain close to measured native terrain and material colors",
		native_harmony,
	)
	var renderer: RefCounted = TerrainRendererScript.new() as RefCounted
	renderer.call("configure", {}, {}, {}, Vector2(90.0, 45.0), Vector2.ZERO)
	renderer.call("set_biome_lookup", func(_cell: Vector2i) -> StringName: return &"frozen")
	var sample: Vector2i = Vector2i(4, 5)
	var expected_kind: StringName = BiomeDestructiblesScript.kind_for(&"frozen", sample)
	_add(
		cases,
		"terrain renderer resolves elevated obstacle colors through biome metadata",
		(
			renderer.call("obstacle_palette_at", sample)
			== BiomeDestructiblesScript.block_palette_for(expected_kind)
		),
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
		(
			objects.call("get_destructible_kind", cell)
			== BiomeDestructiblesScript.kind_for(&"frozen", cell)
		),
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


static func _color_distance(first: Color, second: Color) -> float:
	return Vector3(first.r - second.r, first.g - second.g, first.b - second.b).length()


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
