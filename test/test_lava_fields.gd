extends RefCounted

const DesertHazardsScript: GDScript = preload("res://scripts/desert_hazards.gd")
const EncounterDirectorScript: GDScript = preload("res://scripts/encounter_director.gd")
const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const LavaContactScript: GDScript = preload("res://scripts/lava_contact.gd")
const LavaFieldsScript: GDScript = preload("res://scripts/lava_fields.gd")
const RunCoordinatorScript: GDScript = preload("res://scripts/run_coordinator.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const TerrainRendererScript: GDScript = preload("res://scripts/terrain_renderer.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_add(
		cases,
		"starter field remains outside Lava Fields",
		not LavaFieldsScript.contains(Vector2i(8, 10))
	)
	_add(
		cases,
		"Lava Fields begin sixteen cells west of Walker",
		LavaFieldsScript.contains(Vector2i(-8, 10))
	)
	_add(
		cases,
		"showcase lava cell is deterministic",
		LavaFieldsScript.surface_for(Vector2i(-15, 8), &"sand") == &"lava"
	)
	_add(
		cases,
		"showcase basalt cell is deterministic",
		LavaFieldsScript.surface_for(Vector2i(-15, 6), &"sand") == &"lava_basalt"
	)
	_add(
		cases,
		"showcase ash cell is deterministic",
		LavaFieldsScript.surface_for(Vector2i(-15, 12), &"sand") == &"volcanic_ash"
	)
	_add(
		cases,
		"sanctuary replaces lava with basalt",
		LavaFieldsScript.surface_for(Vector2i(-15, 8), &"sand", true) == &"lava_basalt"
	)
	_add(
		cases,
		"volcanic rocks remain rocks",
		LavaFieldsScript.surface_for(Vector2i(-15, 8), &"rock") == &"rock"
	)

	var world: RefCounted = InfiniteWorldScript.new() as RefCounted
	world.call("configure", {}, {}, {}, {}, {}, {})
	_add(
		cases,
		"Lava biome reaches runtime world truth",
		world.call("_biome_at", Vector2i(-15, 8)) == &"lava"
	)
	_add(
		cases,
		"lava reaches runtime terrain truth",
		world.call("terrain_at", Vector2i(-15, 8)) == &"lava"
	)
	_add(cases, "lava remains walkable", bool(world.call("is_walkable", Vector2i(-15, 8))))
	_test_contact_damage(cases, world)
	_test_lava_hunter(cases, world)
	for terrain_id: StringName in [&"lava_basalt", &"volcanic_ash", &"lava"]:
		var texture: Texture2D = TerrainRendererScript.TEXTURES[terrain_id] as Texture2D
		_add(
			cases,
			"%s material loads at 512 pixels" % terrain_id,
			texture != null and texture.get_size() == Vector2(512.0, 512.0)
		)
	return cases


static func _test_contact_damage(cases: Array[Dictionary], world: RefCounted) -> void:
	var contact: RefCounted = LavaContactScript.new() as RefCounted
	_add(cases, "lava contact binds world truth", bool(contact.call("configure", world)))
	_add(
		cases,
		"lava contact deals immediate entry damage",
		int(contact.call("advance", Vector2(-15, 8), 0.0)) == 8
	)
	_add(
		cases, "lava does not tick early", int(contact.call("advance", Vector2(-15, 8), 0.99)) == 0
	)
	_add(
		cases,
		"lava ticks every full second",
		int(contact.call("advance", Vector2(-15, 8), 0.01)) == 8
	)
	_add(
		cases, "safe basalt resets contact", int(contact.call("advance", Vector2(-15, 6), 0.5)) == 0
	)
	_add(
		cases,
		"re-entering lava deals immediate damage again",
		int(contact.call("advance", Vector2(-15, 8), 0.0)) == 8
	)
	_add(
		cases,
		"lava hitch catch-up is bounded",
		int(contact.call("advance", Vector2(-15, 8), 7.0)) == 32,
	)
	_add(
		cases,
		"bounded lava hitch discards excess backlog",
		int(contact.call("advance", Vector2(-15, 8), 0.0)) == 0
	)
	_add(
		cases,
		"shutdown suppresses and resets lava",
		int(contact.call("advance", Vector2(-15, 8), 0.5, true)) == 0
	)


static func _test_lava_hunter(cases: Array[Dictionary], world: RefCounted) -> void:
	var coordinator: RefCounted = RunCoordinatorScript.new() as RefCounted
	coordinator.call("configure_default")
	coordinator.call("set_run_value", &"player_cell", Vector2i(-15, 8))
	coordinator.call("set_run_value", &"first_worm_defeated", true)
	var hunters: Node2D = SandwormsScript.new() as Node2D
	hunters.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, null, world)
	hunters.call("set_player_position", Vector2(-15, 8))
	var hazards: Node2D = DesertHazardsScript.new() as Node2D
	hazards.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, Vector2i(145, 145))
	hazards.call("spawn_sandstorm", Vector2i(-15, 8), Vector2i.RIGHT)
	var director: Node = EncounterDirectorScript.new() as Node
	director.call("configure", coordinator, world, hunters, hazards)
	director.call("_process", 4.1)
	var snapshots: Array = hunters.call("get_combat_snapshots") as Array
	_add(cases, "Lava Fields remove all desert weather", int(hazards.call("get_hazard_count")) == 0)
	_add(cases, "Lava pressure spawns one native hunter", snapshots.size() == 1)
	if not snapshots.is_empty():
		var enemy_id: int = int((snapshots[0] as Dictionary)[&"id"])
		_add(
			cases,
			"Lava hunter is a Cinder Crawler, never a sandworm",
			hunters.call("_get_enemy_kind", enemy_id) == &"cinder_crawler"
		)
		hunters.call("set_player_position", Vector2(8, 10))
		var leaving: Dictionary = hunters.call("get_combat_snapshot", enemy_id) as Dictionary
		_add(
			cases,
			"leaving Lava makes Cinder Crawlers disengage",
			leaving[&"state"] == &"dispersing" and int(hunters.call("get_worm_count")) == 1,
		)
		hunters.call("advance", float(leaving[&"state_duration"]))
		_add(cases, "Lava retirees cull after fading", int(hunters.call("get_worm_count")) == 0)
	hunters.free()
	hazards.free()
	director.free()


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
