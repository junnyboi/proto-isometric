extends SceneTree

const ContractTestsScript: GDScript = preload("res://test/test_contracts.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const SmokeHelpersScript: GDScript = preload("res://test/smoke_helpers.gd")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	LocalizationScript.set_locale(&"en", false)
	_check(
		(
			ProjectSettings.get_setting("application/run/main_scene")
			== "res://scenes/title_screen.tscn"
		),
		"main scene",
	)
	await _test_title()
	await _test_isometric_map()
	_finish()


func _test_title() -> void:
	var packed_scene: PackedScene = load("res://scenes/title_screen.tscn") as PackedScene
	_check(packed_scene != null, "title scene loads")
	if packed_scene == null:
		return
	var scene: Node = packed_scene.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	var panel: Node = scene.get_node("UILayer/UIRoot/ConceptCanvas/TitlePanel")
	var title_label: Label = panel.get_node("TitleLabel") as Label
	var begin_button: Button = panel.get_node("BeginButton") as Button
	_check(title_label.text == LocalizationScript.t(&"title.name"), "title text")
	_check(title_label.visible, "title visible")
	_check(begin_button.text == LocalizationScript.t(&"title.begin_new"), "Deploy Cardinal label")
	_check(begin_button.focus_mode == Control.FOCUS_ALL, "Begin focusable")
	var background: TextureRect = scene.get_node("UILayer/UIRoot/GeneratedTitleArt") as TextureRect
	_check(background.texture != null, "Signal-First title art loaded")
	_check(bool(scene.call("is_audio_ready")), "audio loaded")
	scene.call("prepare_for_shutdown")
	scene.free()
	await process_frame


func _test_isometric_map() -> void:
	var packed_map: PackedScene = load("res://scenes/isometric_map.tscn") as PackedScene
	_check(packed_map != null, "map scene loads")
	if packed_map == null:
		return
	var save_path: String = "/tmp/proto-isometric-smoke-world.json"
	var malformed_path: String = "/tmp/proto-isometric-smoke-malformed.json"
	var incompatible_path: String = "/tmp/proto-isometric-smoke-incompatible.json"
	SmokeHelpersScript.clear_test_save(save_path)
	SmokeHelpersScript.clear_test_save(malformed_path)
	SmokeHelpersScript.clear_test_save(incompatible_path)
	var map: Node = packed_map.instantiate()
	map.set("save_path", save_path)
	get_root().add_child(map)
	await process_frame
	await process_frame
	var run_coordinator: RefCounted = map.get("_run_coordinator") as RefCounted
	_check(
		run_coordinator.call("get_run_value", &"player_cell") == map.call("get_robot_grid"),
		"live RunState owns Cardinal position",
	)

	_check(map.call("get_grid_size") == Vector2i(145, 145), "world reports compact grid")
	var world: RefCounted = map.get("_world") as RefCounted
	_check(world != null, "lazy world stream exists")
	for test_case: Dictionary in ContractTestsScript.evaluate(run_coordinator, world, map):
		_check(bool(test_case[&"passed"]), str(test_case[&"label"]))
	_check(
		int(world.call("get_loaded_chunk_count")) == 25, "stream keeps five by five chunks active"
	)
	_check(int(world.call("get_active_cell_count")) <= 25 * 64, "active terrain memory is bounded")
	var sample: Vector2i = Vector2i(5, 3)
	var projected: Vector2 = map.call("grid_to_screen", sample) as Vector2
	_check(map.call("screen_to_grid", projected) == sample, "2:1 projection round trip")
	_check(not bool(map.call("is_walkable", Vector2i(4, 4))), "rock tile blocks movement")
	_check(bool(map.call("is_walkable", Vector2i(5, 7))), "sand tile is walkable")
	_check(
		int(map.get("texture_repeat")) == CanvasItem.TEXTURE_REPEAT_ENABLED,
		"terrain textures repeat explicitly",
	)
	var renderer: RefCounted = map.get("_terrain_renderer") as RefCounted
	var uv_origin: PackedVector2Array = renderer.call("terrain_uvs", Vector2i.ZERO)
	var uv_east: PackedVector2Array = renderer.call("terrain_uvs", Vector2i(1, 0))
	_check(uv_origin[1].is_equal_approx(uv_east[0]), "east tile top UV is continuous")
	_check(uv_origin[2].is_equal_approx(uv_east[3]), "east tile bottom UV is continuous")
	var tint_origin: PackedColorArray = renderer.call("terrain_tints", Vector2i.ZERO)
	var tint_east: PackedColorArray = renderer.call("terrain_tints", Vector2i(1, 0))
	var tint_far: PackedColorArray = renderer.call("terrain_tints", Vector2i(12, 12))
	_check(tint_origin[1].is_equal_approx(tint_east[0]), "east tile tint is continuous")
	_check(not tint_origin[0].is_equal_approx(tint_far[0]), "terrain tint varies at low frequency")
	var atmosphere: Node2D = map.get_node("DesertAtmosphere") as Node2D
	_check(atmosphere != null, "wind-blown sand atmosphere exists")
	_check(int(atmosphere.call("get_particle_count")) >= 90, "ambient sand has dense particles")
	var wind_before: float = float(atmosphere.call("get_wind_intensity"))
	atmosphere.call("advance", 1.0)
	_check(float(atmosphere.call("get_wind_intensity")) != wind_before, "desert wind breathes")
	var heat_haze: Node2D = map.get_node("TerrainHaze") as Node2D
	_check(heat_haze != null, "heat haze overlay exists")
	_check(heat_haze.material is ShaderMaterial, "heat haze shader is active")
	var world_object_layer: CanvasLayer = map.get_node("WorldObjectLayer") as CanvasLayer
	var world_effects_layer: CanvasLayer = map.get_node("WorldEffectsLayer") as CanvasLayer
	var world_objects: Node2D = world_object_layer.get_node("WorldObjects") as Node2D
	var mobile_controls: CanvasLayer = map.get_node("MobileControls") as CanvasLayer
	_check(mobile_controls != null, "mobile controls runtime exists")
	_check(not bool(mobile_controls.call("is_mobile_device")), "desktop hides mobile controls")
	mobile_controls.call("force_mobile", true)
	var smash_button: Button = mobile_controls.call("get_smash_button") as Button
	_check(smash_button.visible, "mobile detection shows smash button")
	var native_size: Vector2 = map.get_viewport().get_visible_rect().size
	_check(
		(
			smash_button.position.x > native_size.x * 0.65
			and smash_button.position.y > native_size.y * 0.65
		),
		"smash button occupies bottom right",
	)
	_check(
		not bool(
			mobile_controls.call("begin_touch", 9, smash_button.get_global_rect().get_center())
		),
		"smash touch cannot capture joystick",
	)
	var joystick_origin: Vector2 = Vector2(123.0, maxf(native_size.y, 320.0) - 118.0)
	_check(
		bool(mobile_controls.call("begin_touch", 1, joystick_origin)),
		"tap and hold summons floating joystick"
	)
	_check(bool(mobile_controls.call("is_joystick_visible")), "floating joystick becomes visible")
	var touch_drive: Vector2 = (
		mobile_controls.call("drag_touch", 1, joystick_origin + Vector2(70.0, -70.0)) as Vector2
	)
	_check(touch_drive.x > 0.5 and touch_drive.y < -0.5, "joystick supplies fluid analog diagonal")
	_check(touch_drive.length() <= 1.0, "joystick output is bounded")
	_check(bool(mobile_controls.call("is_run_intended")), "joystick outer ring enters run intent")
	_check(bool(map.call("place_robot", Vector2i(8, 8))), "place Cardinal for touch drive")
	var touch_start: Vector2 = map.call("get_robot_position") as Vector2
	_check(
		bool(map.call("_update_drive_vector", touch_drive, 0.05, false)),
		"touch drive moves Cardinal"
	)
	_check(
		(map.call("get_robot_position") as Vector2).distance_to(touch_start) > 0.0,
		"touch drive reaches movement runtime",
	)
	var touch_speed: float = (map.call("get_velocity") as Vector2).length()
	_check(bool(mobile_controls.call("end_touch", 1)), "touch release ends joystick capture")
	_check(not bool(mobile_controls.call("is_run_intended")), "touch release clears run intent")
	_check(not bool(mobile_controls.call("is_joystick_visible")), "joystick hides on release")
	map.call("_update_drive_vector", Vector2.ZERO, 0.05, false)
	_check(
		(map.call("get_velocity") as Vector2).length() < touch_speed, "touch release decelerates"
	)
	map.set("_facing", &"SE")
	mobile_controls.call("trigger_smash")
	_check(
		map.get("_pending_impact_cell") != Vector2i(-9999, -9999),
		"mobile smash enters contact-frame attack",
	)
	var touch_avatar: Node2D = map.call("get_avatar") as Node2D
	touch_avatar.call("_process", float(touch_avatar.call("get_attack_contact_time")) + 0.01)
	mobile_controls.call("force_mobile", false)
	_check(not smash_button.visible, "desktop mode removes touch affordances")
	_check(heat_haze.z_index == 1, "sand ripple occupies terrain-only depth")
	_check(bool(heat_haze.call("has_haze_at", Vector2i(1, 0))), "sand tile receives haze")
	_check(not bool(heat_haze.call("has_haze_at", Vector2i(0, 0))), "salt tile rejects haze")
	_check(not bool(heat_haze.call("has_haze_at", Vector2i(2, 3))), "rock tile rejects haze")
	_check(not bool(heat_haze.call("has_haze_at", Vector2i(8, 4))), "ruin tile rejects haze")
	_check(
		int(heat_haze.call("get_haze_tile_count")) < int(world.call("get_render_cell_limit")),
		"haze mask excludes non-sand",
	)
	var haze_shader: Shader = (heat_haze.material as ShaderMaterial).shader
	_check("MODEL_MATRIX" in haze_shader.code, "sand ripple phase uses world coordinates")
	var shimmer_speed: float = float(
		(heat_haze.material as ShaderMaterial).get_shader_parameter(&"shimmer_speed")
	)
	_check(is_equal_approx(shimmer_speed, 0.575), "sand ripple runs at half speed")
	_check(world_object_layer.layer == 2, "rocks and interactables render above ripple")
	_check(world_effects_layer.layer == 3, "environmental enemies render above objects")
	_check(world_object_layer.follow_viewport_enabled, "object layer follows the world camera")
	_check(world_objects.has_method("_draw_rock"), "rocks use the high-layer renderer")
	_check(
		(
			int(world_objects.call("get_visible_cell_count"))
			== int(world.call("get_render_cell_limit"))
		),
		"terrain and object graphics are viewport culled",
	)
	var field_hud: CanvasLayer = map.get_node("FieldHUD") as CanvasLayer
	_check(field_hud.has_node("ExpeditionRadar"), "expedition radar exists")
	_check(field_hud.has_node("OnboardingOverlay"), "signal-first onboarding exists")
	_check(field_hud.layer > world_effects_layer.layer, "HUD renders above world effects")
	var field_snapshot: Dictionary = field_hud.call("get_field_state_snapshot") as Dictionary
	_check(not field_snapshot.is_empty(), "HUD reads one sealed semantic field snapshot")
	_check(int(field_snapshot[&"worm_cores"]) == 0, "live HUD exposes future-safe zero Cores")
	_check(int(field_snapshot[&"alert_level"]) == 0, "live HUD exposes future-safe zero Alert")
	_check(
		not bool(field_snapshot[&"debug_visible"]), "live HUD hides coordinate telemetry by default"
	)
	_check(
		"@" not in str(field_hud.call("get_status_text")), "default field status omits coordinates"
	)
	var field_layout: Dictionary = field_hud.call("get_layout_snapshot") as Dictionary
	var drive_rect: Rect2 = field_layout[&"drive_panel"] as Rect2
	var outpost_rect: Rect2 = field_layout[&"outpost_panel"] as Rect2
	_check(not drive_rect.intersects(outpost_rect), "desktop HUD panels respect exclusions")
	mobile_controls.call("force_mobile", true)
	map.call("_refresh_outpost_interface")
	var touch_exclusions: Array[Rect2] = (
		mobile_controls.call("get_touch_exclusions") as Array[Rect2]
	)
	_check(touch_exclusions.size() == 4, "mobile controls expose HUD and control exclusions")
	_check(
		not bool(mobile_controls.call("begin_touch", 44, drive_rect.get_center())),
		"mobile joystick cannot claim HUD touches",
	)
	mobile_controls.call("force_mobile", false)
	map.call("_refresh_outpost_interface")
	var impact_charge: Node2D = map.get_node("WorldObjectLayer/ImpactCharge") as Node2D
	_check(impact_charge != null, "Impact Charge controller exists")
	_check(
		is_equal_approx(float(impact_charge.call("get_gain_multiplier")), 1.15),
		"live Worn Plates multiplier is fifteen percent",
	)
	_check(int(impact_charge.call("get_band")) == 0, "Impact Charge starts in contact band")
	var medium_footprint: Array = (
		impact_charge.call("footprint", Vector2i(6, 6), Vector2i.RIGHT, 1) as Array
	)
	var high_footprint: Array = (
		impact_charge.call("footprint", Vector2i(6, 6), Vector2i.RIGHT, 2) as Array
	)
	_check(medium_footprint.size() == 2, "mid charge creates a two-cell shock line")
	_check(high_footprint.size() == 3, "high charge creates a three-tile fan")
	_check("IMPACT 000%" in str(field_hud.call("get_impact_text")), "charge meter starts empty")
	_check("WORN +15%" in str(field_hud.call("get_impact_text")), "HUD names Worn Plates bonus")
	_check("RELAY 0/3" in str(field_hud.call("get_relay_text")), "relay expedition starts visible")
	var outpost_interface: Control = field_hud.call("get_outpost_interface") as Control
	_check(outpost_interface != null, "outpost interface exists")
	_check(
		bool(outpost_interface.call("are_locked_actions_disabled")),
		"Refit cards start safely unavailable"
	)
	_check(
		(
			outpost_interface.call("get_module_button", &"module.ram_plating") != null
			and outpost_interface.call("get_module_button", &"module.aftershock") != null
			and outpost_interface.call("get_module_button", &"module.storm_seal") != null
		),
		"outpost exposes three Refit cards",
	)
	_check(not bool(outpost_interface.call("is_repair_enabled")), "repair starts unavailable")
	var chassis_feedback: CanvasLayer = map.get_node("ChassisFeedback") as CanvasLayer
	_check(chassis_feedback != null, "chassis feedback controller exists")
	_check(bool(chassis_feedback.call("is_audio_ready")), "chassis damage audio is loaded")
	_check(not bool(chassis_feedback.call("is_shutdown_visible")), "shutdown overlay starts hidden")

	var hazards: Node2D = map.get_node("WorldEffectsLayer/DesertHazards") as Node2D
	_check(hazards != null, "environmental hazard controller exists")
	_check(hazards.get_parent() == world_effects_layer, "hazard particles use the effects layer")
	hazards.call("set_auto_spawn", false)
	hazards.call("clear_hazards")
	_check(bool(map.call("place_robot", Vector2i(5, 5))), "place Cardinal for moving tornado")
	var moving_damage_before: int = int(map.call("_get_chassis"))
	var moving_tornado: int = int(hazards.call("spawn_tornado", Vector2i(5, 5), 0.0, 20.0, 3.2))
	var tornado_start: Vector2 = hazards.call("get_tornado_position", moving_tornado) as Vector2
	hazards.call("advance", 0.01)
	_check(
		(hazards.call("get_tornado_position", moving_tornado) as Vector2) != tornado_start,
		"active tornado moves rapidly",
	)
	_check(
		int(map.call("_get_chassis")) == moving_damage_before - 6,
		"moving tornado damages immediately on contact",
	)
	hazards.call("clear_hazards")
	hazards.call("spawn_tornado", Vector2i(2, 2))
	hazards.call("spawn_tornado", Vector2i(12, 12))
	_check(int(hazards.call("get_hazard_count", &"tornado")) == 2, "multiple tornadoes coexist")
	hazards.call("clear_hazards")
	_check(bool(map.call("place_robot", Vector2i(5, 7))), "place Cardinal for hazard damage")
	var telegraph_chassis: int = int(map.call("_get_chassis"))
	var tornado_id: int = int(hazards.call("spawn_tornado", Vector2i(5, 7), 3.0, 20.0, 0.0))
	hazards.call("advance", 2.9)
	_check(
		hazards.call("get_tornado_state", tornado_id) == &"forming",
		"tornado telegraphs for three seconds"
	)
	_check(int(map.call("_get_chassis")) == telegraph_chassis, "forming tornado causes no damage")
	hazards.call("advance", 0.1)
	_check(
		hazards.call("get_tornado_state", tornado_id) == &"active",
		"tornado activates after telegraph"
	)
	_check(
		int(map.call("_get_chassis")) == telegraph_chassis - 6,
		"active tornado damages immediately",
	)
	hazards.call("advance", 0.99)
	_check(
		int(map.call("_get_chassis")) == telegraph_chassis - 6,
		"tornado does not over-tick before one second",
	)
	hazards.call("advance", 0.02)
	_check(
		int(map.call("_get_chassis")) == telegraph_chassis - 12,
		"tornado continuously deals six damage per second",
	)
	_check(bool(map.call("is_walkable", Vector2i(5, 7))), "tornado does not block traversal")
	hazards.call("set_player_cell", Vector2i(-9999, -9999))
	hazards.call("advance", 0.1)
	hazards.call("set_player_cell", Vector2i(5, 7))
	hazards.call("advance", 0.01)
	_check(
		int(map.call("_get_chassis")) == telegraph_chassis - 18,
		"tornado contact damages immediately after re-entry",
	)
	hazards.call("set_player_cell", Vector2i(-9999, -9999))
	hazards.call("advance", 18.77)
	_check(
		hazards.call("get_tornado_state", tornado_id) == &"active",
		"tornado survives until 20 seconds",
	)
	hazards.call("advance", 0.2)
	_check(
		hazards.call("get_tornado_state", tornado_id) == &"missing",
		"tornado fades and disappears after 20 seconds",
	)
	hazards.call("set_player_cell", Vector2i(5, 7))
	var storm_chassis: int = int(map.call("_get_chassis"))
	var storm_id: int = int(hazards.call("spawn_sandstorm", Vector2i(5, 7), Vector2i.RIGHT, 0.0))
	var footprint: Array = hazards.call("get_sandstorm_footprint", storm_id) as Array
	_check(footprint.size() == 6, "sandstorm occupies six tiles")
	_check(
		(
			Vector2i(5, 7) in footprint
			and Vector2i(6, 7) in footprint
			and Vector2i(5, 9) in footprint
			and Vector2i(6, 9) in footprint
		),
		"sandstorm footprint is exactly two by three",
	)
	var east_front_tiles: int = 0
	for cell: Vector2i in footprint:
		if cell.x == 6:
			east_front_tiles += 1
	_check(east_front_tiles == 3, "eastbound sandstorm leads with three tiles")
	hazards.call("advance", 0.01)
	_check(
		int(map.call("_get_chassis")) == storm_chassis - 3,
		"sandstorm damages immediately on contact",
	)
	hazards.call("advance", 0.99)
	_check(
		int(map.call("_get_chassis")) == storm_chassis - 3,
		"sandstorm does not over-tick before one second",
	)
	hazards.call("advance", 0.02)
	_check(
		int(map.call("_get_chassis")) == storm_chassis - 6,
		"sandstorm continuously deals three damage per second",
	)
	var hazard_chassis_after: int = int(map.call("_get_chassis"))
	_check(bool(map.call("is_walkable", Vector2i(5, 7))), "sandstorm does not block traversal")
	var north_storm: int = int(hazards.call("spawn_sandstorm", Vector2i(10, 10), Vector2i.UP, 0.0))
	var north_footprint: Array = hazards.call("get_sandstorm_footprint", north_storm) as Array
	var north_front_tiles: int = 0
	for cell: Vector2i in north_footprint:
		if cell.y == 10:
			north_front_tiles += 1
	_check(north_front_tiles == 3, "northbound sandstorm leads with three tiles")
	_check(int(hazards.call("get_hazard_count", &"sandstorm")) == 2, "multiple sandstorms coexist")
	hazards.call("clear_hazards")
	hazards.call("set_player_cell", Vector2i(-9999, -9999))
	hazards.call("set_auto_spawn", true)
	hazards.call("advance", 12.1)
	_check(int(hazards.call("get_hazard_count", &"tornado")) >= 1, "tornadoes spawn periodically")
	_check(
		int(hazards.call("get_hazard_count", &"sandstorm")) >= 1, "sandstorms spawn from map edges"
	)
	hazards.call("set_auto_spawn", false)
	hazards.call("clear_hazards")

	var avatar: Node2D = map.call("get_avatar") as Node2D
	_check(avatar != null, "Cardinal avatar exists")
	_check(avatar.get_parent() == world_object_layer, "Cardinal renders above sand ripple")
	_check(avatar.has_method("set_motion"), "Cardinal animation adapter is connected")
	_check(not bool(avatar.call("is_using_proxy")), "Cardinal uses approved combined atlas")
	var sandworms: Node2D = map.get_node("WorldObjectLayer/Sandworms") as Node2D
	_check(sandworms != null, "sandworm controller exists")
	var run_pickups: Node2D = map.get_node("WorldObjectLayer/WorldObjects/RunPickups") as Node2D
	_check(run_pickups != null, "run-only pickup controller exists")
	var worm_telegraph: Node2D = map.get_node("WorldObjectLayer/WormTelegraph") as Node2D
	_check(worm_telegraph != null, "worm telegraph renderer exists")
	_check(sandworms.get_parent() == world_object_layer, "sandworms render above terrain haze")
	_check(worm_telegraph.z_index < sandworms.z_index, "worm telegraphs render beneath worm bodies")
	sandworms.call("set_auto_spawn", false)
	sandworms.call("clear_worms")
	_check(bool(map.call("place_robot", Vector2i(6, 6))), "place Cardinal for sandworm pursuit")
	var chase_worm: int = int(sandworms.call("spawn_worm", Vector2(9.0, 6.0), 0.0))
	var chase_start: Vector2 = sandworms.call("get_worm_position", chase_worm) as Vector2
	sandworms.call("advance", 0.5)
	_check(sandworms.call("get_state", chase_worm) == &"intercept", "sandworm commits an Intercept")
	_check(
		(
			(sandworms.call("get_worm_position", chase_worm) as Vector2).distance_to(
				Vector2(6.0, 6.0)
			)
			< chase_start.distance_to(Vector2(6.0, 6.0))
		),
		"sandworm Intercept closes on its committed target",
	)
	sandworms.call("clear_worms")
	var worm_damage_start: int = int(map.call("_get_chassis"))
	var attacking_worm: int = int(sandworms.call("spawn_worm", Vector2(6.0, 6.0), 0.0))
	sandworms.call("advance", 0.65)
	_check(
		int(map.call("_get_chassis")) == worm_damage_start - 10,
		"committed sandworm Intercept deals ten damage",
	)
	_check(int(sandworms.call("get_last_attack_count")) == 1, "sandworm attack triggers once")
	sandworms.call("advance", 0.9)
	_check(
		int(map.call("_get_chassis")) == worm_damage_start - 10,
		"one committed Intercept cannot attack twice",
	)
	sandworms.call("clear_worms")
	_check(bool(map.call("place_robot", Vector2i(6, 6))), "place Cardinal for worm melee")
	map.set("_facing", &"E")
	var melee_worm: int = int(sandworms.call("spawn_worm", Vector2(7.0, 5.0), 0.0))
	SmokeHelpersScript.advance_worm_to_expose(sandworms, melee_worm)
	for hit: int in range(1, 5):
		_check(bool(map.call("attack")), "melee strike %d targets sandworm" % hit)
		avatar.call("_process", float(avatar.call("get_attack_contact_time")) + 0.01)
		_check(
			int(sandworms.call("get_health", melee_worm)) == 4 - hit,
			"sandworm health drops on strike %d" % hit,
		)
		avatar.call("_process", float(avatar.call("get_attack_duration")))
	_check(
		sandworms.call("get_state", melee_worm) == &"defeated", "four melee hits defeat sandworm"
	)
	_check("SANDWORM DESTROYED" in str(map.call("get_status_text")), "worm defeat is readable")
	_check(int(run_pickups.call("get_drop_count")) == 1, "live worm defeat creates one run reward")
	sandworms.call("advance", 0.65)
	_check(int(sandworms.call("get_worm_count")) == 0, "defeated worm presentation expires")
	sandworms.call("clear_worms")
	_check(bool(map.call("place_robot", Vector2i(6, 6))), "place Cardinal for shock line")
	map.set("_facing", &"E")
	map.call("_set_impact_charge", 0.5)
	var line_worm: int = int(sandworms.call("spawn_worm", Vector2(8.0, 4.0), 0.0))
	SmokeHelpersScript.advance_worm_to_expose(sandworms, line_worm)
	_check(bool(map.call("attack")), "mid charge reaches a worm two cells ahead")
	avatar.call("_process", float(avatar.call("get_attack_contact_time")) + 0.01)
	_check(
		int(sandworms.call("get_health", line_worm)) == 3, "shock line damages its distant target"
	)
	avatar.call("_process", float(avatar.call("get_attack_duration")))
	sandworms.call("clear_worms")
	map.call("_set_impact_charge", 0.9)
	var fan_worm: int = int(sandworms.call("spawn_worm", Vector2(7.0, 6.0), 0.0))
	SmokeHelpersScript.advance_worm_to_expose(sandworms, fan_worm)
	var charge_effects: Node2D = map.get_node("WorldEffectsLayer/ImpactEffects") as Node2D
	var charged_emissions: int = int(charge_effects.call("get_aftershock_emission_count"))
	_check(bool(map.call("attack")), "high charge catches a worm on the fan flank")
	avatar.call("_process", float(avatar.call("get_attack_contact_time")) + 0.01)
	_check(int(sandworms.call("get_health", fan_worm)) == 3, "aftershock fan damages its target")
	_check(
		sandworms.call("get_state", fan_worm) == &"staggered",
		"aftershock staggers a surviving worm",
	)
	_check(is_zero_approx(float(map.call("_get_impact_charge"))), "smash consumes Impact Charge")
	_check(
		int(charge_effects.call("get_aftershock_emission_count")) == charged_emissions + 1,
		"charged smash emits distinct debris",
	)
	avatar.call("_process", float(avatar.call("get_attack_duration")))
	charge_effects.call("advance", 1.0)
	sandworms.call("clear_worms")
	var relay: Node2D = map.get_node("WorldObjectLayer/RelayContest") as Node2D
	var relay_cell: Vector2i = relay.call("get_relay_cell") as Vector2i
	_check(relay != null, "contested relay controller exists")
	_check(relay_cell == Vector2i(12, 6), "starter relay placement is deterministic")
	_check(world.call("terrain_at", relay_cell) == &"ruin", "relay occupies reserved ruin terrain")
	_check(bool(map.call("place_robot", relay_cell)), "Cardinal enters the relay zone")
	relay.call("advance", 0.5)
	_check(relay.call("get_state") == &"linking", "entering relay zone starts linking")
	_check(int(sandworms.call("get_worm_count")) == 0, "linking does not spawn before Alert credit")
	relay.call("advance", 1.75)
	_check(float(relay.call("get_progress")) >= 0.49, "relay link builds while Cardinal holds zone")
	_check(bool(map.call("place_robot", Vector2i(8, 10))), "Cardinal can leave the relay zone")
	relay.call("advance", 0.01)
	_check(
		is_zero_approx(float(relay.call("get_progress"))), "relay link resets when Cardinal leaves"
	)
	_check(bool(map.call("place_robot", relay_cell)), "Cardinal re-enters the relay zone")
	relay.call("advance", 0.01)
	_check(
		int(sandworms.call("get_worm_count")) == 0,
		"relay re-entry does not create ambient encounters"
	)
	relay.call("advance", 3.5)
	_check(bool(relay.call("is_completed")), "relay completes after the uninterrupted link timer")
	_check(int(map.call("_get_completed_relays")) == 1, "relay completion raises Alert I")
	_check(
		bool(run_coordinator.call("get_run_value", &"starter_relay_completed")),
		"live RunState owns starter relay completion",
	)
	var encounter_director: Node = map.get_node("WorldObjectLayer/WorldObjects/EncounterDirector")
	encounter_director.call("_process", 4.1)
	_check(int(sandworms.call("get_worm_count")) == 2, "Alert I adds one hunter over ambient")
	map.call("_refresh_outpost_interface")
	_check("ALERT 1" in str(field_hud.call("get_relay_text")), "HUD reports completed relay alert")
	sandworms.call("clear_worms")
	var safe_worm: int = int(sandworms.call("spawn_worm", Vector2(3.0, 10.0), 0.0))
	_check(bool(map.call("place_robot", Vector2i(1, 10))), "place Cardinal at linked outpost")
	_check(sandworms.call("get_state", safe_worm) == &"dispersing", "outpost link disperses worms")
	sandworms.call("advance", 1.3)
	_check(int(sandworms.call("get_worm_count")) == 0, "dispersed worm leaves Cardinal alone")
	hazard_chassis_after = int(map.call("_get_chassis"))

	var directions: Dictionary = {
		Vector2i(0, -1): &"N",
		Vector2i(1, -1): &"NE",
		Vector2i(1, 0): &"E",
		Vector2i(1, 1): &"SE",
		Vector2i(0, 1): &"S",
		Vector2i(-1, 1): &"SW",
		Vector2i(-1, 0): &"W",
		Vector2i(-1, -1): &"NW",
	}
	for direction: Variant in directions:
		var screen_direction: Vector2i = direction as Vector2i
		var label: StringName = directions[direction] as StringName
		_check(bool(map.call("place_robot", Vector2i(8, 8))), "place Cardinal for %s" % label)
		var start_position: Vector2 = map.call("get_robot_position") as Vector2
		_check(
			bool(map.call("update_drive", screen_direction, 0.05, false)),
			"%s weighted movement succeeds" % label,
		)
		var motion: Vector2 = (map.call("get_robot_position") as Vector2) - start_position
		_check(
			motion.normalized().dot(Vector2(screen_direction).normalized()) > 0.999,
			"%s movement follows screen vector" % label,
		)
		_check(map.call("get_facing") == label, "%s facing" % label)
		_check(avatar.call("get_facing") == label, "%s animation facing" % label)

	_check(bool(map.call("place_robot", Vector2i(8, 8))), "place Cardinal for inertia test")
	map.call("update_drive", Vector2i(1, 0), 0.05, false)
	var first_speed: float = (map.call("get_velocity") as Vector2).length()
	var before_second_step: Vector2 = map.call("get_robot_position") as Vector2
	map.call("update_drive", Vector2i(1, 0), 0.05, false)
	var second_speed: float = (map.call("get_velocity") as Vector2).length()
	_check(second_speed > first_speed, "Cardinal accelerates")
	_check(second_speed < 150.0, "acceleration is not instant")
	map.call("update_drive", Vector2i.ZERO, 0.05, false)
	var release_speed: float = (map.call("get_velocity") as Vector2).length()
	_check(release_speed < second_speed and release_speed > 0.0, "Cardinal decelerates over time")
	_check(
		(map.call("get_robot_position") as Vector2).distance_to(before_second_step) > 0.0,
		"Cardinal coasts during release",
	)

	_check(bool(map.call("place_robot", Vector2i(1, 1))), "place Cardinal for walk speed")
	for _step: int in range(20):
		map.call("update_drive", Vector2i(1, 1), 0.05, false)
	_check(is_equal_approx(float(map.call("get_speed_ratio")), 1.0), "walk reaches rated speed")
	map.call("place_robot", Vector2i(1, 1))
	for _step: int in range(20):
		map.call("update_drive", Vector2i(1, 1), 0.05, true)
	_check(is_equal_approx(float(map.call("get_speed_ratio")), 1.5), "Shift run reaches 1.5x speed")
	map.call("place_robot", Vector2i(23, 10))
	for _step: int in range(20):
		map.call("update_drive", Vector2i(1, 1), 0.05, false)
	_check(is_equal_approx(float(map.call("get_speed_ratio")), 0.62), "mud speed cap is 62 percent")
	var lava_before: int = int(map.call("_get_chassis"))
	_check(bool(map.call("place_robot", Vector2i(-15, 8))), "place Cardinal on lava")
	map.call("_process", 0.0)
	_check(int(map.call("_get_chassis")) == lava_before - 8, "live lava damages chassis")
	map.set("_chassis", lava_before)
	map.call("_set_impact_charge", 0.0)
	map.call("place_robot", Vector2i(1, 1))
	for _step: int in range(80):
		map.call("update_drive", Vector2i(1, 1), 0.05, true)
	var run_charge: float = float(map.call("_get_impact_charge"))
	_check(run_charge >= 0.8, "sustained running builds high Impact Charge")
	_check(int(impact_charge.call("get_band")) == 2, "high charge enters Aftershock band")
	for _step: int in range(60):
		map.call("update_drive", Vector2i.ZERO, 0.05, false)
	_check(float(map.call("_get_impact_charge")) < run_charge, "Impact Charge decays while idle")
	map.call("_refresh_outpost_interface")
	_check(
		"AFTERSHOCK" in str(field_hud.call("get_impact_text")), "HUD names the active charge band"
	)

	map.call("place_robot", Vector2i(8, 8))
	var follow_camera: Camera2D = map.get_node("FollowCamera") as Camera2D
	follow_camera.position = map.call("get_robot_position") as Vector2
	var camera_start: Vector2 = map.call("get_camera_position") as Vector2
	for _step: int in range(6):
		map.call("update_drive", Vector2i(1, 0), 0.05, false)
	var camera_target: Vector2 = map.call("get_camera_target") as Vector2
	map.call("_update_camera_follow", 0.1)
	var camera_after: Vector2 = map.call("get_camera_position") as Vector2
	_check(camera_after != camera_start, "camera follows Cardinal")
	_check(
		camera_after.distance_to(camera_target) < camera_start.distance_to(camera_target),
		"camera eases toward target",
	)
	_check(
		camera_target.x > (map.call("get_robot_position") as Vector2).x,
		"camera leads movement direction",
	)

	_check(bool(map.call("place_robot", Vector2i(3, 4))), "place Cardinal beside rock")
	_check(bool(map.call("has_destructible_rock", Vector2i(4, 4))), "destructible rock exists")
	_check(not bool(heat_haze.call("has_haze_at", Vector2i(4, 4))), "intact rock masks haze")
	var blocked_position: Vector2 = map.call("get_robot_position") as Vector2
	_check(
		not bool(map.call("update_drive", Vector2i(1, 1), 0.05, false)),
		"rock blocks direct drive",
	)
	_check(map.call("get_robot_position") == blocked_position, "blocked drive does not move")
	var effects: Node2D = map.get_node("WorldEffectsLayer/ImpactEffects") as Node2D
	_check(effects != null, "impact effects controller exists")
	var scrap_before_rock: int = int(map.call("get_scrap_count"))
	_check(bool(map.call("attack")), "impact attack targets facing rock")
	_check(bool(map.call("has_destructible_rock", Vector2i(4, 4))), "rock survives windup frames")
	_check(int(effects.call("get_emission_count")) == 0, "windup emits no premature debris")
	var windup_position: Vector2 = map.call("get_robot_position") as Vector2
	map.call("update_drive", Vector2i(1, 1), 0.05, false)
	_check(
		map.call("get_robot_position") == windup_position, "Cardinal braces through strike windup"
	)
	avatar.call("_process", float(avatar.call("get_attack_contact_time")) + 0.01)
	var magnet_scrap_total: int = int(map.call("get_scrap_count"))
	_check("ROCK SALVAGED" in str(map.call("get_status_text")), "impact feedback remains readable")
	_check(not bool(map.call("has_destructible_rock", Vector2i(4, 4))), "rock is destroyed")
	_check(bool(map.call("is_walkable", Vector2i(4, 4))), "destroyed rock becomes walkable")
	_check(bool(heat_haze.call("has_haze_at", Vector2i(4, 4))), "salvaged sand enables haze")
	_check(not bool(map.call("has_scrap", Vector2i(4, 4))), "magnet collects rock scrap nearby")
	_check(int(effects.call("get_emission_count")) == 1, "contact frame emits one debris burst")
	_check(int(effects.call("get_particle_count")) >= 20, "rock impact emits debris particles")
	_check(float(effects.call("get_shake_remaining")) > 0.0, "contact frame starts camera shake")
	_check(
		(effects.call("get_camera_offset") as Vector2).length() <= 11.01, "camera shake is bounded"
	)
	avatar.call("_process", float(avatar.call("get_attack_duration")))
	_check(int(effects.call("get_emission_count")) == 1, "attack contact cannot fire twice")
	effects.call("advance", 1.0)
	_check(int(effects.call("get_particle_count")) == 0, "debris particles expire")
	_check(effects.call("get_camera_offset") == Vector2.ZERO, "camera shake resets cleanly")
	var live_envelope: Dictionary = SmokeHelpersScript.read_test_json(save_path)
	_check(
		(
			int(live_envelope.get("save_format_version", -1)) == 3
			and live_envelope.has("metadata")
			and live_envelope.has("world")
			and live_envelope.has("active_run")
			and live_envelope.has("profile")
		),
		"live field writes a complete schema-3 envelope",
	)
	_check(
		"module.worn_plates" in (live_envelope["active_run"] as Dictionary)["active_module_ids"],
		"live schema-three save persists Worn Plates",
	)

	map.free()
	await process_frame
	map = packed_map.instantiate()
	map.set("save_path", save_path)
	get_root().add_child(map)
	await process_frame
	await process_frame
	run_coordinator = map.get("_run_coordinator") as RefCounted
	run_pickups = map.get_node("WorldObjectLayer/WorldObjects/RunPickups") as Node2D
	_check(
		int(run_pickups.call("get_drop_count")) == 1, "uncollected worm reward persists on reload"
	)
	_check(int(map.call("_get_completed_relays")) == 1, "relay completion persists on reload")
	_check(
		(
			run_coordinator.call("get_run_value", &"player_cell") == map.call("get_robot_grid")
			and (
				int(run_coordinator.call("get_run_value", &"chassis"))
				== int(map.call("_get_chassis"))
			)
			and (
				int(run_coordinator.call("get_run_value", &"scrap"))
				== int(map.call("get_scrap_count"))
			)
		),
		"schema-three reload round-trips through typed RunState",
	)
	_check(
		bool(run_coordinator.call("_has_run_module", &"module.worn_plates")),
		"schema-three reload preserves Worn Plates",
	)
	_check(
		not bool(map.call("has_destructible_rock", Vector2i(4, 4))),
		"broken rock persists on reload"
	)
	_check(map.call("get_robot_grid") == Vector2i(3, 4), "Cardinal position persists on reload")
	_check(magnet_scrap_total == scrap_before_rock + 2, "resource magnet collects adjacent scrap")
	map.free()
	await process_frame
	map = packed_map.instantiate()
	map.set("save_path", save_path)
	get_root().add_child(map)
	await process_frame
	await process_frame
	_check(
		not bool(map.call("has_destructible_rock", Vector2i(4, 4))),
		"terrain mutation stays persistent"
	)
	_check(int(map.call("get_scrap_count")) == magnet_scrap_total, "scrap inventory persists")
	_check(
		int(map.call("_get_chassis")) == hazard_chassis_after,
		"hazard chassis damage persists",
	)
	var outpost_cell: Vector2i = Vector2i(1, 10)
	_check(bool(map.call("_place_scrap", outpost_cell, 5)), "stage repair scrap at outpost")
	_check(bool(map.call("place_robot", outpost_cell)), "Cardinal enters harvested outpost")
	_check(bool(map.call("_is_at_outpost")), "outpost service link activates")
	field_hud = map.get_node("FieldHUD") as CanvasLayer
	outpost_interface = field_hud.call("get_outpost_interface") as Control
	_check(
		bool(outpost_interface.call("is_repair_enabled")), "repair unlocks with scrap and damage"
	)
	var scrap_before_repair: int = int(map.call("get_scrap_count"))
	var chassis_before_repair: int = int(map.call("_get_chassis"))
	var repaired_chassis: int = mini(chassis_before_repair + 35, 100)
	_check(bool(map.call("_repair_chassis")), "outpost repairs Cardinal")
	_check(int(map.call("_get_chassis")) == repaired_chassis, "repair restores thirty-five chassis")
	_check(
		int(map.call("get_scrap_count")) == scrap_before_repair - 5, "repair consumes five scrap"
	)
	run_coordinator = map.get("_run_coordinator") as RefCounted
	run_coordinator.call("set_run_value", &"worm_cores", 1)
	map.call("_refresh_outpost_interface")
	var aftershock_button: Button = (
		outpost_interface.call("get_module_button", &"module.aftershock") as Button
	)
	aftershock_button.pressed.emit()
	await process_frame
	var refit_scrap_total: int = int(map.call("get_scrap_count"))
	_check(
		(
			bool(run_coordinator.call("_has_run_module", &"module.aftershock"))
			and refit_scrap_total == scrap_before_repair - 7
			and int(run_coordinator.call("get_run_value", &"worm_cores")) == 0
		),
		"live Refit installs Aftershock and deducts exact wallets",
	)
	map.free()
	await process_frame
	map = packed_map.instantiate()
	map.set("save_path", save_path)
	get_root().add_child(map)
	await process_frame
	await process_frame
	_check(int(map.call("_get_chassis")) == repaired_chassis, "repaired chassis persists")
	run_coordinator = map.get("_run_coordinator") as RefCounted
	_check(int(map.call("get_scrap_count")) == refit_scrap_total, "post-Refit scrap persists")
	_check(
		bool(run_coordinator.call("_has_run_module", &"module.aftershock")),
		"installed Refit module persists",
	)
	_check(bool(map.call("_is_at_outpost")), "outpost position persists")

	world = map.get("_world") as RefCounted
	var far_cell: Vector2i = Vector2i(-32, -24)
	_check(bool(map.call("place_robot", far_cell)), "Cardinal crosses the compact field")
	_check(not bool(map.call("place_robot", Vector2i(73, 0))), "Cardinal cannot leave world bounds")
	var far_terrain: StringName = world.call("terrain_at", far_cell) as StringName
	_check(far_terrain != &"void", "far terrain generates lazily")
	_check(int(world.call("get_loaded_chunk_count")) == 25, "far travel evicts old chunks")
	_check(
		not bool(world.call("is_cell_loaded", Vector2i(8, 8))), "starter chunks unload offscreen"
	)
	_check(int(world.call("get_active_cell_count")) <= 25 * 64, "far travel keeps memory bounded")
	_check(
		bool(map.call("place_destructible_rock", far_cell + Vector2i.RIGHT)), "far mutation saves"
	)
	_check(
		bool(map.call("place_robot", Vector2i(0, 0))), "Cardinal returns across chunk boundaries"
	)
	_check(bool(map.call("place_robot", far_cell)), "Cardinal revisits generated terrain")
	_check(world.call("terrain_at", far_cell) == far_terrain, "procedural terrain is deterministic")
	var follow_zoom: Vector2 = (map.get_node("FollowCamera") as Camera2D).zoom
	_check(follow_zoom.x >= 0.649, "camera applies responsive framing")

	chassis_feedback = map.get_node("ChassisFeedback") as CanvasLayer
	effects = map.get_node("WorldEffectsLayer/ImpactEffects") as Node2D
	avatar = map.call("get_avatar") as Node2D
	var damage_audio_before: int = int(chassis_feedback.call("get_audio_trigger_count"))
	var damage_emissions_before: int = int(effects.call("get_damage_emission_count"))
	var damage_start_chassis: int = int(map.call("_get_chassis"))
	_check(int(map.call("_apply_chassis_damage", 4, &"test_impact")) == 4, "damage applies")
	_check(
		int(map.call("_get_chassis")) == damage_start_chassis - 4,
		"nonlethal damage reduces chassis",
	)
	_check(float(chassis_feedback.call("get_flash_alpha")) > 0.0, "damage flashes the screen")
	_check(avatar.modulate != Color.WHITE, "damage flashes Cardinal")
	_check(
		int(chassis_feedback.call("get_audio_trigger_count")) == damage_audio_before + 1,
		"damage triggers one audio cue",
	)
	_check(
		int(effects.call("get_damage_emission_count")) == damage_emissions_before + 1,
		"damage emits chassis sparks",
	)
	_check(float(effects.call("get_shake_remaining")) > 0.0, "damage starts camera kick")
	_check(
		(effects.call("get_camera_offset") as Vector2).length() <= 6.01,
		"damage camera kick is bounded",
	)
	_check(
		LocalizationScript.t(&"source.test_impact") in str(map.call("get_status_text")), "source"
	)
	chassis_feedback.call("advance", 0.5)
	_check(is_zero_approx(float(chassis_feedback.call("get_flash_alpha"))), "damage flash expires")
	_check(avatar.modulate.is_equal_approx(Color.WHITE), "Cardinal flash resets")

	var lethal_damage: int = int(map.call("_get_chassis"))
	_check(
		int(map.call("_apply_chassis_damage", lethal_damage, &"sandstorm")) == lethal_damage,
		"lethal damage applies",
	)
	_check(int(map.call("_get_chassis")) == 0, "lethal damage reaches zero")
	_check(bool(map.get("_shutdown")), "zero chassis enters shutdown")
	run_coordinator = map.get("_run_coordinator") as RefCounted
	_check(
		(
			int(run_coordinator.call("get_run_value", &"chassis")) == 0
			and bool(run_coordinator.call("get_run_value", &"shutdown"))
			and run_coordinator.call("get_run_value", &"phase") == &"run_phase.failed"
		),
		"live RunState owns shutdown lifecycle",
	)
	_check(bool(chassis_feedback.call("is_shutdown_visible")), "shutdown overlay is visible")
	_check(
		int(chassis_feedback.call("get_audio_trigger_count")) == damage_audio_before + 2,
		"shutdown triggers one low damage cue",
	)
	_check(not bool(map.call("update_drive", Vector2i.RIGHT, 0.05, false)), "shutdown blocks drive")
	_check(not bool(map.call("attack")), "shutdown blocks impact strike")
	_check(not bool(map.call("place_robot", Vector2i(2, 2))), "shutdown blocks placement")
	_check("CARDINAL SHUTDOWN" in str(map.call("get_status_text")), "shutdown status is readable")
	field_hud = map.get_node("FieldHUD") as CanvasLayer
	outpost_interface = field_hud.call("get_outpost_interface") as Control
	_check(not bool(outpost_interface.call("is_repair_enabled")), "shutdown disables field repair")
	_check(
		int(map.call("_apply_chassis_damage", 1, &"repeat")) == 0, "shutdown ignores extra damage"
	)
	_check(
		int(chassis_feedback.call("get_audio_trigger_count")) == damage_audio_before + 2,
		"shutdown cue cannot retrigger from extra damage",
	)

	map.free()
	await process_frame
	map = packed_map.instantiate()
	map.set("save_path", save_path)
	get_root().add_child(map)
	await process_frame
	await process_frame
	chassis_feedback = map.get_node("ChassisFeedback") as CanvasLayer
	_check(int(map.call("_get_chassis")) == 0, "zero chassis persists")
	_check(bool(map.get("_shutdown")), "shutdown state restores on reload")
	_check(bool(chassis_feedback.call("is_shutdown_visible")), "restored shutdown remains visible")
	_check(
		bool(map.call("has_destructible_rock", far_cell + Vector2i.RIGHT)),
		"far streamed terrain mutation persists",
	)
	_check(
		not bool(map.call("update_drive", Vector2i.RIGHT, 0.05, false)),
		"restored shutdown remains immobile",
	)

	map.free()
	await process_frame
	var malformed: FileAccess = FileAccess.open(malformed_path, FileAccess.WRITE)
	malformed.store_string("{not valid world state")
	malformed.close()
	map = packed_map.instantiate()
	map.set("save_path", malformed_path)
	get_root().add_child(map)
	await process_frame
	await process_frame
	_check(
		bool(map.call("has_destructible_rock", Vector2i(4, 4))), "malformed save falls back safely"
	)
	_check(int(map.call("get_scrap_count")) == 0, "malformed save cannot corrupt inventory")
	var malformed_repository: RefCounted = map.get("_state_store") as RefCounted
	var malformed_quarantine: Array = malformed_repository.call("get_quarantine_paths") as Array
	_check(
		(
			not FileAccess.file_exists(malformed_path)
			and malformed_quarantine.size() == 1
			and FileAccess.file_exists(malformed_quarantine[0])
		),
		"malformed save is quarantined diagnostically",
	)
	map.free()
	await process_frame
	var incompatible: FileAccess = FileAccess.open(incompatible_path, FileAccess.WRITE)
	(
		incompatible
		. store_string(
			(
				JSON
				. stringify(
					{
						"schema": 999,
						"scrap_total": 0,
						"chassis": 100,
						"robot_cell": [8, 10],
						"facing": "SE",
					}
				)
			)
		)
	)
	incompatible.close()
	map = packed_map.instantiate()
	map.set("save_path", incompatible_path)
	get_root().add_child(map)
	await process_frame
	await process_frame
	_check(int(map.call("get_scrap_count")) == 0, "incompatible save falls back safely")
	var incompatible_repository: RefCounted = map.get("_state_store") as RefCounted
	var incompatible_quarantine: Array = (
		incompatible_repository.call("get_quarantine_paths") as Array
	)
	_check(
		(
			incompatible_repository.call("get_status") == &"incompatible"
			and bool(incompatible_repository.call("is_write_blocked"))
			and not FileAccess.file_exists(incompatible_path)
			and incompatible_quarantine.size() == 1
			and FileAccess.file_exists(incompatible_quarantine[0])
		),
		"future save is quarantined and protected from overwrite",
	)
	map.free()
	await process_frame
	SmokeHelpersScript.clear_test_save(save_path)
	SmokeHelpersScript.clear_test_save(malformed_path)
	SmokeHelpersScript.clear_test_save(incompatible_path)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		push_error("[FAIL] %s" % label)


func _finish() -> void:
	if _failures == 0:
		print("[SMOKE_PASS] checks=%d" % _checks)
		quit(0)
	else:
		print("[SMOKE_FAIL] checks=%d failures=%d" % [_checks, _failures])
		quit(1)
