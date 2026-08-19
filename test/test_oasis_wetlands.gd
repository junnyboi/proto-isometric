extends RefCounted

const DesertHazardsScript: GDScript = preload("res://scripts/desert_hazards.gd")
const EncounterDirectorScript: GDScript = preload("res://scripts/encounter_director.gd")
const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const OasisWetlandsScript: GDScript = preload("res://scripts/oasis_wetlands.gd")
const RunCoordinatorScript: GDScript = preload("res://scripts/run_coordinator.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const TerrainRendererScript: GDScript = preload("res://scripts/terrain_renderer.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_add(
		cases,
		"starter field remains desert",
		OasisWetlandsScript.biome_at(Vector2i(8, 10)) == &"desert"
	)
	_add(
		cases,
		"Oasis begins ten cells east of Walker",
		OasisWetlandsScript.biome_at(Vector2i(18, 10)) == &"oasis"
	)
	_add(
		cases,
		"showcase mud patch is deterministic",
		OasisWetlandsScript.is_mud_cell(Vector2i(23, 10))
	)
	_add(
		cases,
		"sanctuary carves mud into firm wetland",
		OasisWetlandsScript.surface_for(Vector2i(23, 10), &"sand", true) == &"wetland",
	)
	_add(
		cases,
		"rocks remain rocks inside Oasis",
		OasisWetlandsScript.surface_for(Vector2i(23, 10), &"rock") == &"rock",
	)
	_add(
		cases,
		"mud speed cap is exactly 62 percent",
		OasisWetlandsScript.MUD_SPEED_MULTIPLIER == 0.62
	)

	var world: RefCounted = InfiniteWorldScript.new() as RefCounted
	world.call("configure", {}, {}, {}, {}, {}, {})
	_add(
		cases,
		"prototype world is 145 by 145 cells",
		world.call("_get_playable_size") == Vector2i(145, 145)
	)
	_add(
		cases,
		"outer boundary cell remains playable",
		bool(world.call("is_valid_cell", Vector2i(72, -72)))
	)
	_add(
		cases,
		"cells beyond the compact field are void",
		world.call("terrain_at", Vector2i(73, 0)) == &"void"
	)
	_add(
		cases,
		"Oasis terrain reaches runtime world truth",
		world.call("terrain_at", Vector2i(23, 10)) == &"mud"
	)
	world.call("stream_around", Vector2i(72, 72))
	_add(
		cases,
		"edge streaming omits chunks beyond the world",
		int(world.call("get_loaded_chunk_count")) < 25
	)
	_add(
		cases,
		"legacy save coordinates remain decodable but unplayable",
		(
			world.call("decode_cell", [1000, -200]) == Vector2i(1000, -200)
			and not bool(world.call("is_valid_cell", Vector2i(1000, -200)))
		),
	)

	for value: Variant in TerrainRendererScript.TEXTURES.values():
		var texture: Texture2D = value as Texture2D
		_add(
			cases,
			"terrain material loads at 512 pixels",
			texture != null and texture.get_size() == Vector2(512.0, 512.0),
		)

	_test_oasis_hunter(cases, world)
	return cases


static func _test_oasis_hunter(cases: Array[Dictionary], world: RefCounted) -> void:
	var coordinator: RefCounted = RunCoordinatorScript.new() as RefCounted
	coordinator.call("configure_default")
	coordinator.call("set_run_value", &"player_cell", Vector2i(23, 10))
	coordinator.call("set_run_value", &"first_worm_defeated", true)
	var worms: Node2D = SandwormsScript.new() as Node2D
	worms.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, null, world)
	worms.call("set_player_position", Vector2(8, 10))
	worms.call("spawn_worm", Vector2(12, 10))
	var hazards: Node2D = DesertHazardsScript.new() as Node2D
	hazards.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, Vector2i(14, 14))
	hazards.call("spawn_tornado", Vector2i(10, 10))
	var director: Node = EncounterDirectorScript.new() as Node
	director.call("configure", coordinator, world, worms, hazards)
	director.call("_process", 4.1)
	var enemy_id: int = int((worms.call("get_combat_snapshots") as Array)[0][&"id"])
	_add(cases, "Oasis removes all desert weather", int(hazards.call("get_hazard_count")) == 0)
	_add(
		cases,
		"Oasis pressure spawns one biome-native hunter",
		int(worms.call("get_worm_count")) == 1
	)
	_add(
		cases,
		"Oasis hunter is a Mud Skimmer, never a sandworm",
		worms.call("_get_enemy_kind", enemy_id) == &"mud_skimmer"
	)
	worms.call("set_player_position", Vector2(8, 10))
	_add(
		cases,
		"leaving Oasis removes Mud Skimmers at the boundary",
		int(worms.call("get_worm_count")) == 0
	)
	worms.free()
	hazards.free()
	director.free()


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
