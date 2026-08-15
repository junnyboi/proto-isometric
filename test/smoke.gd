extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(
		(
			str(ProjectSettings.get_setting("application/run/main_scene", ""))
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
	var title_label: Label = scene.get_node("UILayer/UIRoot/TitlePanel/TitleLabel") as Label
	var begin_button: Button = scene.get_node("UILayer/UIRoot/TitlePanel/BeginButton") as Button
	_check(title_label.text == "PROTO\nISOMETRIC", "title text")
	_check(title_label.visible, "title visible")
	_check(begin_button.text == "BEGIN  >", "Begin label")
	_check(begin_button.focus_mode == Control.FOCUS_ALL, "Begin focusable")
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
	_clear_test_save(save_path)
	_clear_test_save(malformed_path)
	var map: Node = packed_map.instantiate()
	map.set("save_path", save_path)
	get_root().add_child(map)
	await process_frame
	await process_frame

	_check(map.call("get_grid_size") == Vector2i(18, 18), "expanded grid size")
	var sample: Vector2i = Vector2i(5, 3)
	var projected: Vector2 = map.call("grid_to_screen", sample) as Vector2
	_check(map.call("screen_to_grid", projected) == sample, "2:1 projection round trip")
	_check(not bool(map.call("is_walkable", Vector2i(4, 4))), "rock tile blocks movement")
	_check(bool(map.call("is_walkable", Vector2i(5, 7))), "sand tile is walkable")
	var texture_paths: Array[String] = [
		"res://assets/textures/terrain/desert_sand.png",
		"res://assets/textures/terrain/salt_crust.png",
		"res://assets/textures/terrain/iron_rock.png",
		"res://assets/textures/terrain/ancient_ruin.png",
	]
	for texture_path: String in texture_paths:
		var texture: Texture2D = load(texture_path) as Texture2D
		_check(texture != null, "%s texture loads" % texture_path.get_file())
		_check(
			texture.get_size() == Vector2(512.0, 512.0), "%s runtime size" % texture_path.get_file()
		)
	_check(
		int(map.get("texture_repeat")) == CanvasItem.TEXTURE_REPEAT_ENABLED,
		"terrain textures repeat explicitly",
	)
	var uv_origin: PackedVector2Array = (
		map.call("_terrain_uvs", Vector2i.ZERO) as PackedVector2Array
	)
	var uv_east: PackedVector2Array = map.call("_terrain_uvs", Vector2i(1, 0)) as PackedVector2Array
	_check(uv_origin[1].is_equal_approx(uv_east[0]), "east tile top UV is continuous")
	_check(uv_origin[2].is_equal_approx(uv_east[3]), "east tile bottom UV is continuous")

	var avatar: Node2D = map.call("get_avatar") as Node2D
	_check(avatar != null, "Cardinal avatar exists")
	_check(avatar.has_method("set_motion"), "Cardinal animation adapter is connected")
	_check(bool(avatar.call("is_using_proxy")), "unapproved sheets use animated proxy")

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

	map.call("place_robot", Vector2i(8, 8))
	map.call("_snap_camera_to_robot")
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
	var blocked_position: Vector2 = map.call("get_robot_position") as Vector2
	_check(
		not bool(map.call("update_drive", Vector2i(1, 1), 0.05, false)),
		"rock blocks direct drive",
	)
	_check(map.call("get_robot_position") == blocked_position, "blocked drive does not move")
	var effects: Node2D = map.get_node("ImpactEffects") as Node2D
	_check(effects != null, "impact effects controller exists")
	_check(bool(map.call("attack")), "impact attack targets facing rock")
	_check(bool(map.call("has_destructible_rock", Vector2i(4, 4))), "rock survives windup frames")
	_check(int(effects.call("get_emission_count")) == 0, "windup emits no premature debris")
	var windup_position: Vector2 = map.call("get_robot_position") as Vector2
	map.call("update_drive", Vector2i(1, 1), 0.05, false)
	_check(
		map.call("get_robot_position") == windup_position, "Cardinal braces through strike windup"
	)
	avatar.call("_process", 0.23)
	_check("ROCK SALVAGED" in str(map.call("get_status_text")), "impact feedback remains readable")
	_check(not bool(map.call("has_destructible_rock", Vector2i(4, 4))), "rock is destroyed")
	_check(bool(map.call("is_walkable", Vector2i(4, 4))), "destroyed rock becomes walkable")
	_check(bool(map.call("has_scrap", Vector2i(4, 4))), "destroyed rock drops scrap")
	_check(int(effects.call("get_emission_count")) == 1, "contact frame emits one debris burst")
	_check(int(effects.call("get_particle_count")) >= 20, "rock impact emits debris particles")
	_check(float(effects.call("get_shake_remaining")) > 0.0, "contact frame starts camera shake")
	_check(
		(effects.call("get_camera_offset") as Vector2).length() <= 11.01, "camera shake is bounded"
	)
	avatar.call("_process", 0.23)
	_check(int(effects.call("get_emission_count")) == 1, "attack contact cannot fire twice")
	effects.call("advance", 1.0)
	_check(int(effects.call("get_particle_count")) == 0, "debris particles expire")
	_check(effects.call("get_camera_offset") == Vector2.ZERO, "camera shake resets cleanly")

	map.free()
	await process_frame
	map = packed_map.instantiate()
	map.set("save_path", save_path)
	get_root().add_child(map)
	await process_frame
	await process_frame
	_check(
		not bool(map.call("has_destructible_rock", Vector2i(4, 4))),
		"broken rock persists on reload"
	)
	_check(bool(map.call("has_scrap", Vector2i(4, 4))), "dropped scrap persists on reload")
	_check(map.call("get_robot_grid") == Vector2i(3, 4), "Cardinal position persists on reload")
	_check(bool(map.call("place_robot", Vector2i(4, 4))), "Cardinal enters cleared tile")
	_check(int(map.call("get_scrap_count")) == 2, "Cardinal collects dropped scrap")
	_check(
		"SCRAP COLLECTED" in str(map.call("get_status_text")),
		"collection feedback remains readable"
	)
	_check(not bool(map.call("has_scrap", Vector2i(4, 4))), "collected scrap leaves world")
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
	_check(not bool(map.call("has_scrap", Vector2i(4, 4))), "collected scrap stays absent")
	_check(int(map.call("get_scrap_count")) == 2, "scrap inventory persists on reload")
	_check(map.call("get_robot_grid") == Vector2i(4, 4), "post-collection position persists")

	map.call("place_robot", Vector2i(0, 0))
	_check(
		not bool(map.call("update_drive", Vector2i(-1, -1), 0.05, false)),
		"map edge blocks drive",
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
	map.free()
	await process_frame
	_clear_test_save(save_path)
	_clear_test_save(malformed_path)


func _clear_test_save(path: String) -> void:
	for candidate: String in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


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
