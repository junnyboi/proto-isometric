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

	var packed_scene: PackedScene = load("res://scenes/title_screen.tscn") as PackedScene
	_check(packed_scene != null, "title scene loads")
	if packed_scene == null:
		_finish()
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
	_check(not bool(scene.call("is_staging_visible")), "staging hidden initially")

	begin_button.pressed.emit()
	await process_frame
	_check(not bool(scene.call("is_title_visible")), "Begin hides title")
	_check(bool(scene.call("is_staging_visible")), "Begin opens staging")
	_check(int(scene.call("get_audio_trigger_count")) == 1, "Begin triggers audio once")

	begin_button.pressed.emit()
	await process_frame
	_check(int(scene.call("get_audio_trigger_count")) == 1, "Begin is idempotent")

	scene.call("prepare_for_shutdown")
	scene.free()
	await process_frame
	_finish()


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
