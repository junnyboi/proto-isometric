extends RefCounted

const BiomeIntelScript: GDScript = preload("res://scripts/biome_intel_catalog.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const OutpostInterfaceScript: GDScript = preload("res://scripts/outpost_interface.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const FIELD_CASES: Array[Dictionary] = [
	{
		&"biome": &"desert",
		&"surface": &"sand",
		&"region": "DEEP DESERT",
		&"primary": "SANDWORM",
		&"swarm": "GLASSBACK SCARAB",
		&"fauna": "DUNE GRAZER",
	},
	{
		&"biome": &"oasis",
		&"surface": &"mud",
		&"region": "OASIS WETLANDS",
		&"primary": "MUD SKIMMER",
		&"swarm": "MIRE TICK",
		&"fauna": "REEDBACK",
	},
	{
		&"biome": &"frozen",
		&"surface": &"blue_ice",
		&"region": "FROZEN TUNDRA",
		&"primary": "RIME STALKER",
		&"swarm": "RIME SHARDLING",
		&"fauna": "RIMEHORN",
	},
	{
		&"biome": &"lava",
		&"surface": &"volcanic_ash",
		&"region": "LAVA FIELDS",
		&"primary": "CINDER CRAWLER",
		&"swarm": "EMBER SKITTER",
		&"fauna": "EMBER RAM",
	},
]


static func evaluate(runtime: Node = null) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var original_locale: StringName = LocalizationScript.get_locale()
	LocalizationScript.set_locale(&"en", false)
	_test_catalog(cases)
	_test_outpost_names(cases)
	_test_panel_modes(cases)
	if runtime != null:
		_test_live_map_panel(cases, runtime)
	LocalizationScript.set_locale(original_locale, false)
	return cases


static func _test_catalog(cases: Array[Dictionary]) -> void:
	var surfaces: Array[StringName] = [
		&"sand",
		&"salt",
		&"ruin",
		&"rock",
		&"wetland",
		&"mud",
		&"snow",
		&"blue_ice",
		&"lava",
		&"volcanic_ash",
		&"lava_basalt",
		&"void",
	]
	var all_surfaces_supported: bool = true
	for surface: StringName in surfaces:
		if not BiomeIntelScript.supports(&"desert", surface):
			all_surfaces_supported = false
	_add(cases, "biome intel localizes every generated terrain surface", all_surfaces_supported)
	_add(
		cases,
		"biome intel rejects unknown regions and surfaces",
		BiomeIntelScript.snapshot(&"unknown", &"sand").is_empty()
		and BiomeIntelScript.snapshot(&"desert", &"unknown").is_empty(),
	)


static func _test_outpost_names(cases: Array[Dictionary]) -> void:
	var panel: Control = OutpostInterfaceScript.new() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	var unique_names: Dictionary = {}
	var all_rendered: bool = true
	for biome: StringName in [&"desert", &"oasis", &"frozen", &"lava"]:
		for outpost_kind: StringName in BiomeIntelScript.OUTPOST_KINDS:
			var name_key: StringName = BiomeIntelScript.outpost_name_key(biome, outpost_kind)
			panel.call("set_location_context", biome, &"sand", outpost_kind)
			panel.call(
				"set_state",
				true,
				12,
				3,
				82,
				100,
				[RuntimeIdsScript.MODULE_WORN_PLATES],
				false,
				RuntimeIdsScript.MODIFIER_NEUTRAL,
			)
			var expected: String = LocalizationScript.t(name_key)
			unique_names[expected] = true
			if str(panel.call("get_title_text")) != expected or expected == "HARVESTED OUTPOST":
				all_rendered = false
	_add(cases, "all twenty biome and building outpost names render", all_rendered)
	_add(cases, "every biome and building combination has a unique title", unique_names.size() == 20)
	_add(
		cases,
		"outpost naming rejects unknown biomes and structures",
		BiomeIntelScript.outpost_name_key(&"unknown", &"ancient_ruin") == &""
		and BiomeIntelScript.outpost_name_key(&"desert", &"unknown") == &"",
	)
	LocalizationScript.set_locale(&"zh-CN", false)
	panel.call("set_location_context", &"lava", &"lava_basalt", &"ancient_palace")
	panel.call(
		"set_state",
		true,
		12,
		3,
		82,
		100,
		[RuntimeIdsScript.MODULE_WORN_PLATES],
		false,
		RuntimeIdsScript.MODIFIER_NEUTRAL,
	)
	_add(
		cases,
		"biome and building outpost names render in Simplified Chinese",
		str(panel.call("get_title_text")) == "烬冠宫",
	)
	LocalizationScript.set_locale(&"en", false)
	panel.free()


static func _test_live_map_panel(cases: Array[Dictionary], runtime: Node) -> void:
	var field_hud: CanvasLayer = runtime.get_node("FieldHUD") as CanvasLayer
	var snapshot: Dictionary = field_hud.call("get_field_state_snapshot") as Dictionary
	var world: RefCounted = runtime.get("_world") as RefCounted
	var player_cell: Vector2i = runtime.get("_robot_grid") as Vector2i
	var panel: Control = field_hud.call("get_outpost_interface") as Control
	_add(
		cases,
		"live map passes authoritative biome and tile surface into the HUD",
		snapshot[&"current_biome"] == world.call("_biome_at", player_cell)
		and snapshot[&"terrain_surface"] == world.call("terrain_at", player_cell)
		and snapshot[&"current_outpost_kind"] == &"",
	)
	_add(
		cases,
		"live field HUD shows intelligence while outpost services remain hidden",
		not bool(panel.call("is_outpost_mode"))
		and bool(panel.call("is_intel_visible"))
		and not bool(panel.call("are_service_controls_visible"))
		and str(panel.call("get_intel_text")).contains("CURRENT TILE")
		and str(panel.call("get_intel_text")).contains("DETECTED"),
	)
	var outpost_cell: Vector2i = Vector2i(1, 10)
	var world_objects: Node2D = runtime.get("_world_objects") as Node2D
	var rendered_kind: StringName = world_objects.call("get_outpost_kind", outpost_cell) as StringName
	var linked_biome: StringName = world.call("_biome_at", outpost_cell) as StringName
	var expected_title: String = LocalizationScript.t(
		BiomeIntelScript.outpost_name_key(linked_biome, rendered_kind)
	)
	_add(
		cases,
		"live outpost renderer resolves a biome-specific building title",
		rendered_kind in BiomeIntelScript.OUTPOST_KINDS
		and expected_title != "HARVESTED OUTPOST",
	)


static func _test_panel_modes(cases: Array[Dictionary]) -> void:
	var panel: Control = OutpostInterfaceScript.new() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	for field_case: Dictionary in FIELD_CASES:
		panel.call(
			"set_location_context",
			field_case[&"biome"],
			field_case[&"surface"],
		)
		panel.call(
			"set_state",
			false,
			12,
			3,
			82,
			100,
			[RuntimeIdsScript.MODULE_WORN_PLATES],
			false,
			RuntimeIdsScript.MODIFIER_NEUTRAL,
		)
		var intel_text: String = str(panel.call("get_intel_text"))
		_add(
			cases,
			"%s field mode shows region and current tile" % field_case[&"biome"],
			not bool(panel.call("is_outpost_mode"))
			and bool(panel.call("is_intel_visible"))
			and not bool(panel.call("are_service_controls_visible"))
			and str(panel.call("get_title_text")) == field_case[&"region"]
			and LocalizationScript.t(
				StringName("field_intel.surface.%s" % field_case[&"surface"])
			) in intel_text,
		)
		_add(
			cases,
			"%s field mode lists both hostile signatures in warning red" % field_case[&"biome"],
			str(field_case[&"primary"]) in intel_text
			and str(field_case[&"swarm"]) in intel_text
			and (panel.call("get_threat_color") as Color).is_equal_approx(Color("ff5d5d")),
		)
		_add(
			cases,
			"%s field mode lists available Scrap and Core sources" % field_case[&"biome"],
			"RESOURCES AVAILABLE" in intel_text
			and "SCRAP" in intel_text
			and "CORES" in intel_text
			and str(field_case[&"fauna"]) in intel_text,
		)
	panel.call("set_location_context", &"desert", &"sand", &"ancient_ruin")
	panel.call(
		"set_state",
		true,
		12,
		3,
		82,
		100,
		[RuntimeIdsScript.MODULE_WORN_PLATES],
		false,
		RuntimeIdsScript.MODIFIER_NEUTRAL,
	)
	_add(
		cases,
		"entering an outpost restores repair and Refit services",
		bool(panel.call("is_outpost_mode"))
		and not bool(panel.call("is_intel_visible"))
		and bool(panel.call("are_service_controls_visible"))
		and bool(panel.call("is_repair_enabled"))
		and str(panel.call("get_title_text")) == "WINDCARVED RUIN",
	)
	LocalizationScript.set_locale(&"zh-CN", false)
	panel.call("set_location_context", &"frozen", &"snow")
	panel.call(
		"set_state",
		false,
		12,
		3,
		82,
		100,
		[RuntimeIdsScript.MODULE_WORN_PLATES],
		false,
		RuntimeIdsScript.MODIFIER_NEUTRAL,
	)
	_add(
		cases,
		"field intelligence re-renders in Simplified Chinese",
		str(panel.call("get_title_text")) == "冰封苔原"
		and "当前地块" in str(panel.call("get_intel_text"))
		and "检测到" in str(panel.call("get_intel_text")),
	)
	LocalizationScript.set_locale(&"en", false)
	panel.free()


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
