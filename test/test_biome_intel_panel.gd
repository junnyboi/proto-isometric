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
		and snapshot[&"terrain_surface"] == world.call("terrain_at", player_cell),
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


static func _test_panel_modes(cases: Array[Dictionary]) -> void:
	var panel: Control = OutpostInterfaceScript.new() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	for field_case: Dictionary in FIELD_CASES:
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
			field_case[&"biome"],
			field_case[&"surface"],
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
		&"desert",
		&"sand",
	)
	_add(
		cases,
		"entering an outpost restores repair and Refit services",
		bool(panel.call("is_outpost_mode"))
		and not bool(panel.call("is_intel_visible"))
		and bool(panel.call("are_service_controls_visible"))
		and bool(panel.call("is_repair_enabled"))
		and str(panel.call("get_title_text")) == "HARVESTED OUTPOST",
	)
	LocalizationScript.set_locale(&"zh-CN", false)
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
		&"frozen",
		&"snow",
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
