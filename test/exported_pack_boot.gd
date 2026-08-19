extends SceneTree

const MAP_SCENE_PATH: String = "res://scenes/isometric_map.tscn"
const TITLE_SCENE_PATH: String = "res://scenes/title_screen.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var title_scene: PackedScene = load(TITLE_SCENE_PATH) as PackedScene
	if title_scene == null:
		_fail("title scene did not load from the exported PCK")
		return
	var map_scene: PackedScene = load(MAP_SCENE_PATH) as PackedScene
	if map_scene == null:
		_fail("field scene did not load from the exported PCK")
		return
	var map: Node = map_scene.instantiate()
	if map == null:
		_fail("field scene did not instantiate from the exported PCK")
		return
	map.set("save_path", "user://pck-boot-world.json")
	root.add_child(map)
	await process_frame
	await process_frame
	if not map.is_inside_tree() or map.get_node_or_null("FollowCamera") == null:
		_fail("exported field did not reach runtime readiness")
		return
	print("[PCK_BOOT_PASS]")
	map.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error("[PCK_BOOT_FAIL] %s" % message)
	quit(1)
