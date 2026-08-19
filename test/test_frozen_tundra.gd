extends RefCounted

const DesertHazardsScript: GDScript = preload("res://scripts/desert_hazards.gd")
const EncounterDirectorScript: GDScript = preload("res://scripts/encounter_director.gd")
const FrozenTundraScript: GDScript = preload("res://scripts/frozen_tundra.gd")
const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const RunCoordinatorScript: GDScript = preload("res://scripts/run_coordinator.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const SurfaceDriveScript: GDScript = preload("res://scripts/surface_drive.gd")
const TerrainRendererScript: GDScript = preload("res://scripts/terrain_renderer.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_add(
		cases,
		"starter field remains outside Frozen",
		not FrozenTundraScript.contains(Vector2i(8, 10))
	)
	_add(
		cases,
		"Frozen begins eighteen cells north of Walker",
		FrozenTundraScript.contains(Vector2i(8, -8))
	)
	_add(
		cases,
		"Frozen edge provides a snow braking apron",
		FrozenTundraScript.surface_for(Vector2i(8, -8), &"sand") == &"snow"
	)
	_add(
		cases,
		"showcase blue-ice lake is deterministic",
		FrozenTundraScript.is_ice_cell(Vector2i(8, -15))
	)
	_add(
		cases,
		"sanctuary carves ice into snow",
		FrozenTundraScript.surface_for(Vector2i(8, -15), &"sand", true) == &"snow"
	)
	_add(
		cases,
		"Frozen rocks remain rocks",
		FrozenTundraScript.surface_for(Vector2i(8, -15), &"rock") == &"rock"
	)

	var world: RefCounted = InfiniteWorldScript.new() as RefCounted
	world.call("configure", {}, {}, {}, {}, {}, {})
	_add(
		cases,
		"Frozen biome reaches runtime world truth",
		world.call("_biome_at", Vector2i(8, -15)) == &"frozen"
	)
	_add(
		cases,
		"blue ice reaches runtime terrain truth",
		world.call("terrain_at", Vector2i(8, -15)) == &"blue_ice"
	)
	_add(
		cases,
		"snow reaches runtime terrain truth",
		world.call("terrain_at", Vector2i(8, -8)) == &"snow"
	)
	_test_surface_drive(cases)
	_test_frozen_hunter(cases, world)
	for terrain_id: StringName in [&"snow", &"blue_ice"]:
		var texture: Texture2D = TerrainRendererScript.TEXTURES[terrain_id] as Texture2D
		_add(
			cases,
			"%s material loads at 512 pixels" % terrain_id,
			texture != null and texture.get_size() == Vector2(512.0, 512.0)
		)
	return cases


static func _test_surface_drive(cases: Array[Dictionary]) -> void:
	var normal: Vector2 = SurfaceDriveScript.advance(
		Vector2.ZERO, Vector2(150.0, 0.0), 150.0, &"snow", 0.05
	)
	_add(
		cases,
		"snow preserves normal acceleration exactly",
		normal.is_equal_approx(Vector2(15.5, 0.0))
	)
	var mud: Vector2 = Vector2.ZERO
	for frame: int in range(120):
		mud = SurfaceDriveScript.advance(mud, Vector2(150.0, 0.0), 150.0, &"mud", 1.0 / 60.0)
	_add(
		cases,
		"shared adapter preserves the 62 percent mud cap",
		is_equal_approx(mud.length(), 93.0)
	)
	var ice: Vector2 = Vector2(150.0, 0.0)
	for frame: int in range(20):
		ice = SurfaceDriveScript.advance(ice, Vector2.ZERO, 150.0, &"blue_ice", 0.05)
	_add(cases, "ice release preserves substantial momentum", is_equal_approx(ice.length(), 126.0))
	var snow_stop: Vector2 = Vector2(150.0, 0.0)
	for frame: int in range(20):
		snow_stop = SurfaceDriveScript.advance(snow_stop, Vector2.ZERO, 150.0, &"snow", 0.05)
	_add(cases, "snow resumes normal braking", snow_stop == Vector2.ZERO)
	var ice_turn: Vector2 = SurfaceDriveScript.advance(
		Vector2(150.0, 0.0), Vector2(0.0, 150.0), 150.0, &"blue_ice", 0.05
	)
	var snow_turn: Vector2 = SurfaceDriveScript.advance(
		Vector2(150.0, 0.0), Vector2(0.0, 150.0), 150.0, &"snow", 0.05
	)
	_add(
		cases,
		"blue ice turns materially less than snow",
		absf(ice_turn.y) < absf(snow_turn.y) * 0.5
	)
	var ice_20hz: Vector2 = Vector2(150.0, 0.0)
	var ice_60hz: Vector2 = Vector2(150.0, 0.0)
	for frame: int in range(20):
		ice_20hz = SurfaceDriveScript.advance(ice_20hz, Vector2.ZERO, 150.0, &"blue_ice", 0.05)
	for frame: int in range(60):
		ice_60hz = SurfaceDriveScript.advance(
			ice_60hz, Vector2.ZERO, 150.0, &"blue_ice", 1.0 / 60.0
		)
	_add(cases, "ice drag is frame-rate stable", ice_20hz.is_equal_approx(ice_60hz))


static func _test_frozen_hunter(cases: Array[Dictionary], world: RefCounted) -> void:
	var coordinator: RefCounted = RunCoordinatorScript.new() as RefCounted
	coordinator.call("configure_default")
	coordinator.call("set_run_value", &"player_cell", Vector2i(8, -15))
	coordinator.call("set_run_value", &"first_worm_defeated", true)
	var hunters: Node2D = SandwormsScript.new() as Node2D
	hunters.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, null, world)
	hunters.call("set_player_position", Vector2(8, -15))
	var hazards: Node2D = DesertHazardsScript.new() as Node2D
	hazards.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, Vector2i(145, 145))
	hazards.call("spawn_tornado", Vector2i(8, -15))
	var director: Node = EncounterDirectorScript.new() as Node
	director.call("configure", coordinator, world, hunters, hazards)
	director.call("_process", 4.1)
	var snapshots: Array = hunters.call("get_combat_snapshots") as Array
	_add(cases, "Frozen removes all desert weather", int(hazards.call("get_hazard_count")) == 0)
	_add(cases, "Frozen pressure spawns one native hunter", snapshots.size() == 1)
	if not snapshots.is_empty():
		var enemy_id: int = int((snapshots[0] as Dictionary)[&"id"])
		_add(
			cases,
			"Frozen hunter is a Rime Stalker, never a sandworm",
			hunters.call("_get_enemy_kind", enemy_id) == &"rime_stalker"
		)
		hunters.call("set_player_position", Vector2(8, 10))
		_add(
			cases, "leaving Frozen removes Rime Stalkers", int(hunters.call("get_worm_count")) == 0
		)
	hunters.free()
	hazards.free()
	director.free()


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
