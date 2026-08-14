extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(
		str(ProjectSettings.get_setting("application/run/main_scene", ""))
		== "res://scenes/title_screen.tscn",
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
	var map: Node = packed_map.instantiate()
	get_root().add_child(map)
	await process_frame
	await process_frame

	_check(map.call("get_grid_size") == Vector2i(9, 9), "grid size")
	var sample: Vector2i = Vector2i(5, 3)
	var projected: Vector2 = map.call("grid_to_screen", sample) as Vector2
	_check(map.call("screen_to_grid", projected) == sample, "2:1 projection round trip")
	_check(not bool(map.call("is_walkable", Vector2i(1, 2))), "rock tile blocks movement")
	_check(bool(map.call("is_walkable", Vector2i(5, 7))), "sand tile is walkable")

	var start: Vector2i = map.call("get_robot_grid") as Vector2i
	_check(bool(map.call("request_route", Vector2i(5, 7))), "route request succeeds")
	var route: Array[Vector2i] = map.call("get_route") as Array[Vector2i]
	_check(not route.is_empty(), "route contains steps")
	map.call("_process", 1.0)
	_check(map.call("get_robot_grid") != start, "robot advances on route")

	map.free()
	await process_frame


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
