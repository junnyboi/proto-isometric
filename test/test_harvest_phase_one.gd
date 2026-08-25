extends RefCounted

const BiomeIntelScript: GDScript = preload("res://scripts/biome_intel_catalog.gd")
const DesertAtmosphereScript: GDScript = preload("res://scripts/desert_atmosphere.gd")
const DesertHazardsScript: GDScript = preload("res://scripts/desert_hazards.gd")
const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const LavaContactScript: GDScript = preload("res://scripts/lava_contact.gd")
const MeleePressureScript: GDScript = preload("res://scripts/melee_pressure.gd")
const OutpostEnergyScript: GDScript = preload("res://scripts/outpost_energy.gd")
const OutpostVisualsScript: GDScript = preload("res://scripts/outpost_visuals.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const TerrainRendererScript: GDScript = preload("res://scripts/terrain_renderer.gd")
const VisualCatalogScript: GDScript = preload("res://scripts/visual_catalog.gd")
const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")
const WoodlandVisualsScript: GDScript = preload("res://scripts/woodland_visuals.gd")
const WorldObjectsScript: GDScript = preload("res://scripts/world_objects.gd")
const WorldSafetyScript: GDScript = preload("res://scripts/world_safety.gd")

const TILE_SIZE: Vector2 = Vector2(90.0, 45.0)
const EXTERNAL_GOLDENS: Array[Dictionary] = [
	{&"cell": Vector2i(-60, -60), &"biome": &"frozen", &"surface": &"snow"},
	{&"cell": Vector2i(-40, 12), &"biome": &"lava", &"surface": &"lava"},
	{&"cell": Vector2i(-24, 32), &"biome": &"lava", &"surface": &"lava"},
	{&"cell": Vector2i(24, -32), &"biome": &"frozen", &"surface": &"snow"},
	{&"cell": Vector2i(40, 0), &"biome": &"oasis", &"surface": &"wetland"},
	{&"cell": Vector2i(60, 60), &"biome": &"oasis", &"surface": &"wetland"},
	{&"cell": Vector2i(0, -40), &"biome": &"frozen", &"surface": &"snow"},
	{&"cell": Vector2i(0, 40), &"biome": &"desert", &"surface": &"sand"},
	{&"cell": Vector2i(30, 30), &"biome": &"oasis", &"surface": &"wetland"},
]


class SafeLavaWorld:
	extends RefCounted

	func _is_home_safe(_position: Vector2) -> bool:
		return true

	func _is_remote_sanctuary(_position: Vector2, _radius: float = 2.5) -> bool:
		return false

	func terrain_at(_cell: Vector2i) -> StringName:
		return &"lava"


class TestField:
	extends Node

	var cell: Vector2i = WoodlandClearingScript.CENTER

	func get_robot_grid() -> Vector2i:
		return cell


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_classifier_invariants(cases)
	var world: RefCounted = _make_world(RuntimeIdsScript.MODE_FRESH_FARM)
	_test_generation_precedence(cases, world)
	_test_external_goldens(cases, world)
	_test_tree_and_landmark_determinism(cases, world)
	_test_ruin_states(cases, world)
	_test_safety_authority(cases, world)
	_test_hostile_adapters(cases, world)
	_test_atmosphere_and_rendering(cases, world)
	_test_seven_day_soak(cases, world)
	_test_legacy_compatibility(cases)
	return cases


static func _test_classifier_invariants(cases: Array[Dictionary]) -> void:
	var valid: bool = true
	var saw_broadleaf: bool = false
	var saw_conifer: bool = false
	for seed: int in range(1000):
		for cell: Vector2i in WoodlandClearingScript.apron_cells():
			valid = valid and WoodlandClearingScript.is_farm_apron(cell)
			valid = valid and not WoodlandClearingScript.is_obstacle(cell, seed)
		for cell: Vector2i in WoodlandClearingScript.gate_cells():
			valid = valid and WoodlandClearingScript.is_gate(cell)
			valid = valid and WoodlandClearingScript.is_protected_path(cell)
			valid = valid and not WoodlandClearingScript.is_obstacle(cell, seed)
		for cell: Vector2i in WoodlandClearingScript.tree_cells(seed):
			var kind: StringName = WoodlandClearingScript.tree_kind_at(cell, seed)
			saw_broadleaf = saw_broadleaf or kind == WoodlandClearingScript.KIND_BROADLEAF
			saw_conifer = saw_conifer or kind == WoodlandClearingScript.KIND_CONIFER
			valid = valid and WoodlandClearingScript.is_tree_belt(cell)
			valid = valid and not WoodlandClearingScript.is_protected_path(cell)
		if not valid:
			break
	_add(cases, "PH-04 1,000 seeds preserve apron, gate, path, and tree-belt invariants", valid)
	_add(
		cases,
		"PH-04 the farm apron is one exact contiguous 6x6 claim",
		WoodlandClearingScript.apron_cells().size() == 36,
	)
	_add(
		cases,
		"PH-04 four gates are exactly two cells wide",
		WoodlandClearingScript.gate_cells().size() == 8,
	)
	_add(
		cases,
		"PH-04 both deterministic tree variants occur across bounded seeds",
		saw_broadleaf and saw_conifer,
	)
	_add(
		cases,
		"PH-04 home and pond are fixed protected landmarks",
		(
			WoodlandClearingScript.HOME_CELL == Vector2i(8, 4)
			and WoodlandClearingScript.POND_CELL == Vector2i(4, 9)
			and WoodlandClearingScript.is_protected_path(WoodlandClearingScript.HOME_CELL)
			and WoodlandClearingScript.is_protected_path(WoodlandClearingScript.POND_CELL)
		),
	)


static func _test_generation_precedence(cases: Array[Dictionary], world: RefCounted) -> void:
	_add(
		cases,
		"PH-05 generation exposes the approved precedence contract",
		(
			world.call("_get_generation_precedence")
			== [
				&"base_terrain",
				&"biome",
				&"clearing",
				&"protected_paths_apron",
				&"obstacles",
				&"mutations",
				&"structures",
			]
		),
	)
	var protected_clear: bool = true
	for cell: Vector2i in WoodlandClearingScript.protected_cells():
		protected_clear = protected_clear and world.call("terrain_at", cell) == &"woodland_grass"
		if cell != WoodlandClearingScript.POND_CELL:
			protected_clear = protected_clear and bool(world.call("is_walkable", cell))
		protected_clear = protected_clear and not bool(
			world.call("place_rock", cell, WoodlandClearingScript.CENTER)
		)
	_add(
		cases,
		"PH-05 protected paths and apron remain grass, walkable, and mutation-proof",
		protected_clear,
	)
	var tree_cell: Vector2i = (
		WoodlandClearingScript.tree_cells(WoodlandClearingScript.DEFAULT_SEED)[0]
	)
	_add(
		cases,
		"PH-05 generated tree obstacles block movement without becoming terrain rocks",
		(
			world.call("_tree_kind_at", tree_cell) != &""
			and world.call("terrain_at", tree_cell) == &"woodland_grass"
			and not bool(world.call("is_walkable", tree_cell))
			and not bool(world.call("place_rock", tree_cell, WoodlandClearingScript.CENTER))
		),
	)
	_add(
		cases,
		"PH-05 pond is a visible blocking landmark while home remains service-walkable",
		(
			bool(world.call("_is_pond", WoodlandClearingScript.POND_CELL))
			and not bool(world.call("is_walkable", WoodlandClearingScript.POND_CELL))
			and bool(world.call("is_walkable", WoodlandClearingScript.HOME_CELL))
		),
	)


static func _test_external_goldens(cases: Array[Dictionary], world: RefCounted) -> void:
	var preserved: bool = true
	for golden: Dictionary in EXTERNAL_GOLDENS:
		var cell: Vector2i = golden[&"cell"] as Vector2i
		preserved = preserved and world.call("_biome_at", cell) == golden[&"biome"]
		preserved = preserved and world.call("terrain_at", cell) == golden[&"surface"]
	_add(cases, "PH-04 all nine external golden biome/surface cells remain exact", preserved)


static func _test_tree_and_landmark_determinism(
	cases: Array[Dictionary], world: RefCounted
) -> void:
	var seed: int = 0x5EED123
	world.call("_set_generation_context", RuntimeIdsScript.MODE_FRESH_FARM, seed)
	var first: Array[Vector2i] = WoodlandClearingScript.tree_cells(seed)
	var variants: Dictionary = {}
	for cell: Vector2i in first:
		variants[cell] = world.call("_tree_kind_at", cell)
	world.call("stream_around", Vector2i(60, 60))
	world.call("stream_around", WoodlandClearingScript.CENTER)
	var stable: bool = first == WoodlandClearingScript.tree_cells(seed)
	for cell: Vector2i in first:
		stable = stable and variants[cell] == world.call("_tree_kind_at", cell)
	_add(cases, "PH-06 tree cells and variants survive stream order deterministically", stable)
	_add(
		cases,
		"PH-06 woodland assets retain approved runtime dimensions and anchors",
		(
			WoodlandVisualsScript.texture_for(WoodlandVisualsScript.KIND_BROADLEAF).get_size()
			== Vector2(256, 256)
			and WoodlandVisualsScript.texture_for(WoodlandVisualsScript.KIND_CONIFER).get_size()
			== Vector2(256, 256)
			and WoodlandVisualsScript.texture_for(WoodlandVisualsScript.KIND_POND).get_size()
			== Vector2(512, 512)
			and WoodlandVisualsScript.draw_offset_for(WoodlandVisualsScript.KIND_BROADLEAF).y < -100.0
		),
	)


static func _test_ruin_states(cases: Array[Dictionary], world: RefCounted) -> void:
	var registry: RefCounted = world.call("_get_ruin_registry") as RefCounted
	var home: Vector2i = WoodlandClearingScript.HOME_CELL
	_add(
		cases,
		"PH-08 fixed home starts discovered, repaired, powered, and service-active",
		(
			world.call("_outpost_kind_at", home) == OutpostVisualsScript.KIND_SAFEHOUSE
			and bool(world.call("_is_outpost_service_active", home))
			and bool(registry.call("is_sanctuary_active", home))
		),
	)
	var remote: Vector2i = _find_remote_outpost(world)
	_add(cases, "PH-08 bounded field contains a remote procedural ruin", remote != Vector2i.MAX)
	_add(
		cases,
		"PH-08 unrepaired remote ruin grants neither service nor immunity",
		(
			remote != Vector2i.MAX
			and not bool(world.call("_is_outpost_service_active", remote))
			and not bool(world.call("_is_in_sanctuary", Vector2(remote)))
			and WorldSafetyScript.allows_spawn(Vector2(remote), world)
		),
	)
	var staged: bool = bool(registry.call("repair", remote))
	staged = staged and not bool(world.call("_is_outpost_service_active", remote))
	staged = staged and not bool(world.call("_is_in_sanctuary", Vector2(remote)))
	staged = staged and bool(registry.call("set_powered", remote, true))
	staged = staged and bool(world.call("_is_outpost_service_active", remote))
	staged = staged and bool(world.call("_is_in_sanctuary", Vector2(remote)))
	_add(cases, "PH-08 remote sanctuary and services require both repair and power", staged)
	var outposts: Dictionary = {home: true, remote: true}
	var energy: Node2D = OutpostEnergyScript.new() as Node2D
	energy.call(
		"configure",
		outposts,
		func(cell: Vector2i) -> Vector2: return Vector2(cell),
		func(cell: Vector2i) -> bool: return cell == home,
		func(cell: Vector2i) -> StringName: return world.call("_outpost_kind_at", cell),
	)
	energy.call("set_visible_cells", [home, remote] as Array[Vector2i])
	_add(
		cases,
		"PH-08 inactive ruin presentation emits no service beacon",
		int(energy.call("get_visible_beacon_count")) == 1,
	)
	energy.free()


static func _test_safety_authority(cases: Array[Dictionary], world: RefCounted) -> void:
	var home: Vector2 = Vector2(WoodlandClearingScript.CENTER)
	var edge_inside: Vector2 = home + Vector2(WoodlandClearingScript.BUFFER_RADIUS - 0.01, 0.0)
	var edge_outside: Vector2 = home + Vector2(WoodlandClearingScript.BUFFER_RADIUS + 0.01, 0.0)
	_add(
		cases,
		"PH-07 safety buffer includes its inside edge and excludes the outside edge",
		(
			WorldSafetyScript.is_home_safe(edge_inside)
			and not WorldSafetyScript.is_home_safe(edge_outside)
			and not WorldSafetyScript.allows_spawn(edge_inside, world)
			and WorldSafetyScript.allows_spawn(edge_outside, world)
		),
	)
	_add(
		cases,
		"PH-07 central safety denies spawn, pursuit, projectile, hazard, weather, and lava",
		(
			not WorldSafetyScript.allows_spawn(home, world)
			and not WorldSafetyScript.allows_pursuit(home, world)
			and not WorldSafetyScript.allows_projectile_target(home, world)
			and not WorldSafetyScript.allows_deep_event(WoodlandClearingScript.CENTER, world)
			and not WorldSafetyScript.allows_hazard_damage(home, world)
			and not WorldSafetyScript.allows_weather_damage(home, world)
			and not WorldSafetyScript.allows_lava_damage(home, world)
		),
	)
	var safe_lava: RefCounted = SafeLavaWorld.new() as RefCounted
	var lava_contact: RefCounted = LavaContactScript.new() as RefCounted
	lava_contact.call("configure", safe_lava)
	_add(
		cases,
		"PH-07 lava contact adapter denies even a lava-reporting home cell",
		int(lava_contact.call("advance", home, 4.0)) == 0,
	)


static func _test_hostile_adapters(cases: Array[Dictionary], world: RefCounted) -> void:
	var home: Vector2 = Vector2(WoodlandClearingScript.CENTER)
	var worms: Node2D = SandwormsScript.new() as Node2D
	worms.call("configure", TILE_SIZE, Vector2.ZERO, null, world)
	worms.call("set_player_position", home)
	_add(
		cases,
		"PH-07 hostile spawn adapter rejects home worms",
		int(worms.call("spawn_worm", home, 0.0)) == -1,
	)
	var pressure: Node2D = MeleePressureScript.new() as Node2D
	pressure.call("configure", TILE_SIZE, Vector2.ZERO, world)
	pressure.call("set_player_position", Vector2(30, 10))
	var spawned: int = int(pressure.call("spawn_pack", Vector2(30, 10), 1))
	pressure.call("set_player_position", home)
	pressure.call("advance", 0.1)
	var pursuing_denied: bool = spawned == 1
	if int(pressure.call("get_count")) > 0:
		var snapshot: Dictionary = (pressure.call("get_combat_snapshots") as Array[Dictionary])[0]
		pursuing_denied = pursuing_denied and snapshot[&"state"] == MeleePressureScript.STATE_DISPERSING
	_add(
		cases,
		"PH-07 pursuit adapter disperses an active hostile at the home boundary",
		pursuing_denied,
	)
	var projectile_hits: Array[int] = []
	worms.connect(
		"damage_tick",
		func(_amount: int, _source: StringName) -> void: projectile_hits.append(1),
	)
	var salvo: Dictionary = {
		&"state_duration": 0.9,
		&"strike_pulses": 3,
		&"resolved_pulses": 0,
		&"strike_targets": [home, home, home],
	}
	worms.call("_resolve_salvo_pulses", salvo, 0.0, 0.9)
	_add(
		cases,
		"PH-07 projectile adapter resolves harmlessly without a home hit",
		projectile_hits.is_empty() and int(salvo[&"resolved_pulses"]) == 3,
	)
	var hazards: Node2D = DesertHazardsScript.new() as Node2D
	hazards.call("configure", TILE_SIZE, Vector2.ZERO, Vector2i(14, 11), world)
	var hazard_hits: Array[int] = []
	hazards.connect(
		"damage_tick",
		func(_amount: int, _source: StringName) -> void: hazard_hits.append(1),
	)
	hazards.call("set_player_position", home)
	var denied: bool = int(hazards.call("spawn_tornado", WoodlandClearingScript.CENTER, 0.0)) == -1
	denied = denied and int(
		hazards.call("spawn_sandstorm", WoodlandClearingScript.CENTER, Vector2i.RIGHT, 0.0)
	) == -1
	denied = denied and int(
		hazards.call("force_deep_event", &"desert", WoodlandClearingScript.CENTER)
	) == -1
	hazards.call("advance", 3.0)
	_add(
		cases,
		"PH-07 hazard and weather adapters reject home events and damage",
		denied and hazard_hits.is_empty(),
	)
	worms.free()
	pressure.free()
	hazards.free()


static func _test_atmosphere_and_rendering(cases: Array[Dictionary], world: RefCounted) -> void:
	var field: TestField = TestField.new()
	var atmosphere: Node2D = DesertAtmosphereScript.new() as Node2D
	atmosphere.set("_field", field)
	atmosphere.set("_world", world)
	atmosphere.call("_sync_weather_authority")
	var home_suppressed: bool = bool(atmosphere.call("is_suppressed"))
	field.cell = Vector2i(8, 26)
	atmosphere.call("_sync_weather_authority")
	_add(
		cases,
		"PH-06 woodland suppresses atmosphere while remote desert retains it",
		(
			home_suppressed
			and not bool(atmosphere.call("is_suppressed"))
			and int(atmosphere.call("get_visible_mark_count")) > 0
		),
	)
	var catalog: Resource = VisualCatalogScript.new() as Resource
	var required_paths: Array[String] = catalog.call("get_required_paths") as Array[String]
	var phase_one_assets_registered: bool = true
	for path: String in [
		"res://assets/textures/terrain/woodland_grass.png",
		"res://assets/textures/terrain/farm_soil.png",
		"res://assets/woodland/woodland_broadleaf_tree.png",
		"res://assets/woodland/woodland_conifer_tree.png",
		"res://assets/woodland/woodland_pond.png",
	]:
		phase_one_assets_registered = phase_one_assets_registered and path in required_paths
	_add(
		cases,
		"PH-06 visual catalog validates every woodland and registered soil asset",
		bool(catalog.call("validate_required")) and phase_one_assets_registered,
	)
	_add(
		cases,
		"PH-06 farm soil is registered for later phases without plot state",
		(
			TerrainRendererScript.TEXTURES.has(&"farm_soil")
			and (TerrainRendererScript.TEXTURES[&"farm_soil"] as Texture2D).get_size() == Vector2(512, 512)
		),
	)
	var home_intel: Dictionary = BiomeIntelScript.snapshot(&"woodland", &"woodland_grass")
	_add(
		cases,
		"PH-06 woodland intel reports a secure home instead of desert threats",
		(
			bool(home_intel.get(&"safe_home", false))
			and home_intel.get(&"region_key", &"") == &"field_intel.region.woodland"
			and home_intel.get(&"surface_key", &"") == &"field_intel.surface.woodland_grass"
		),
	)
	var objects: Node2D = WorldObjectsScript.new() as Node2D
	objects.call("configure", {}, {}, {}, func(cell: Vector2i) -> Vector2: return Vector2(cell))
	objects.call("bind_world", world, Callable())
	var before_children: int = objects.get_child_count()
	objects.call("set_visible_cells", WoodlandClearingScript.tree_cells(1))
	_add(
		cases,
		"PH-06 visible tree batching creates no per-tree Nodes",
		objects.get_child_count() == before_children,
	)
	objects.free()
	atmosphere.free()
	field.free()


static func _test_seven_day_soak(cases: Array[Dictionary], world: RefCounted) -> void:
	var home: Vector2 = Vector2(WoodlandClearingScript.CENTER)
	var worms: Node2D = SandwormsScript.new() as Node2D
	worms.call("configure", TILE_SIZE, Vector2.ZERO, null, world)
	worms.call("set_player_position", home)
	var hazards: Node2D = DesertHazardsScript.new() as Node2D
	hazards.call("configure", TILE_SIZE, Vector2.ZERO, Vector2i(14, 11), world)
	hazards.call("set_player_position", home)
	var violations: Array[int] = []
	worms.connect("damage_tick", func(_amount: int, _source: StringName) -> void: violations.append(1))
	hazards.connect(
		"damage_tick",
		func(_amount: int, _source: StringName) -> void: violations.append(1),
	)
	var safe: bool = true
	for _day: int in range(7):
		for _tick: int in range(240):
			worms.call("set_player_position", home)
			worms.call("advance", 0.1)
			hazards.call("set_player_position", home)
			hazards.call("advance", 0.1)
			for snapshot: Dictionary in worms.call("get_combat_snapshots") as Array[Dictionary]:
				safe = safe and not WorldSafetyScript.is_home_safe(snapshot[&"position"] as Vector2)
			if not safe or not violations.is_empty():
				break
		if not safe or not violations.is_empty():
			break
	_add(
		cases,
		"PH-07 seven-day-equivalent bounded soak records zero home violations",
		safe and violations.is_empty() and int(worms.call("get_worm_count")) == 0,
	)
	worms.free()
	hazards.free()


static func _test_legacy_compatibility(cases: Array[Dictionary]) -> void:
	var world: RefCounted = _make_world(RuntimeIdsScript.MODE_LEGACY_EXPEDITION)
	var starter: Vector2 = Vector2(WoodlandClearingScript.CENTER)
	_add(
		cases,
		"PH-07 legacy expedition keeps starter terrain and no clearing-wide immunity",
		(
			world.call("_biome_at", WoodlandClearingScript.CENTER) == &"desert"
			and world.call("terrain_at", WoodlandClearingScript.CENTER) == &"sand"
			and not bool(world.call("_is_home_safe", starter))
				and WorldSafetyScript.allows_spawn(starter, world)
			),
		)
	var all_starter_outposts_active: bool = true
	for cell: Vector2i in InfiniteWorldScript.STARTER_OUTPOSTS:
		all_starter_outposts_active = (
			all_starter_outposts_active
			and bool(world.call("_is_sanctuary_outpost", cell))
			and bool(world.call("_is_outpost_service_active", cell))
		)
	_add(
		cases,
		"PH-08 legacy starter outposts retain active sanctuary/service semantics",
		all_starter_outposts_active,
	)


static func _find_remote_outpost(world: RefCounted) -> Vector2i:
	var extent: int = InfiniteWorldScript.PLAYABLE_HALF_EXTENT
	for y: int in range(-extent, extent + 1):
		for x: int in range(-extent, extent + 1):
			var cell: Vector2i = Vector2i(x, y)
			if not WoodlandClearingScript.contains(cell) and bool(world.call("_is_outpost", cell)):
				return cell
	return Vector2i.MAX


static func _make_world(mode: StringName) -> RefCounted:
	var world: RefCounted = InfiniteWorldScript.new() as RefCounted
	world.call("configure", {}, {}, {}, {}, {}, {})
	world.call("_set_generation_context", mode)
	return world


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
