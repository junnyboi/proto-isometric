extends SceneTree

const ScenarioScript: GDScript = preload("res://selftest/scenarios/title_launch.gd")
const VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)
const MAX_FRAMES: int = 180

var _checks: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _expects_done: bool = false
var _done: bool = false
var _frames_used: int = 0
var _shots_root: String = "res://artifacts/title_launch"
var _started_msec: int = 0


func _initialize() -> void:
	_started_msec = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	get_root().size = VIEWPORT_SIZE
	_parse_args()
	var load_error: Error = change_scene_to_file("res://scenes/title_screen.tscn")
	check("scene_load", load_error == OK, "error=%d" % int(load_error))
	await frames(4)
	var scenario: RefCounted = ScenarioScript.new()
	await scenario.call("run", self)
	scenario = null
	check("completion_expected", _expects_done, "expect_done=%s" % str(_expects_done))
	check("completion_sentinel", _done, "done=%s" % str(_done))
	check(
		"frame_budget", _frames_used <= MAX_FRAMES, "frames=%d max=%d" % [_frames_used, MAX_FRAMES]
	)
	_write_report()
	var failed_count: int = 0
	for result: Dictionary in _checks:
		if not bool(result["ok"]):
			failed_count += 1
	var scene_to_free: Node = current_scene
	current_scene = null
	if scene_to_free != null:
		if scene_to_free.has_method("prepare_for_shutdown"):
			scene_to_free.call("prepare_for_shutdown")
		scene_to_free.free()
	await process_frame
	if failed_count == 0:
		print("[SCENARIO_DONE] title_launch checks=%d frames=%d" % [_checks.size(), _frames_used])
		quit(0)
	else:
		push_error("[SCENARIO_FAILED] title_launch failed=%d" % failed_count)
		quit(1)


func _parse_args() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shots="):
			_shots_root = argument.trim_prefix("--shots=")


func frames(count: int) -> void:
	for _frame_index: int in range(count):
		_frames_used += 1
		await process_frame


func physics_frames(count: int) -> void:
	for _frame_index: int in range(count):
		_frames_used += 1
		await physics_frame


func check(check_name: String, ok: bool, detail: String) -> void:
	_checks.append({"name": check_name, "ok": ok, "detail": detail})
	var status: String = "PASS" if ok else "FAIL"
	print("[%s] %s %s" % [status, check_name, detail])


func expect_done() -> void:
	_expects_done = true


func done() -> void:
	_done = true


func click_view(control: Control) -> void:
	var center: Vector2 = control.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.device = 4242
	motion.position = center
	motion.global_position = center
	Input.parse_input_event(motion)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.device = 4242
	down.position = center
	down.global_position = center
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await physics_frames(1)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.device = 4242
	up.position = center
	up.global_position = center
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await frames(2)


func shot(shot_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		_shots.append({"name": shot_name, "status": "SKIP", "reason": "headless"})
		print("[SHOT-SKIPPED] %s headless" % shot_name)
		return
	await RenderingServer.frame_post_draw
	var output_dir: String = _shots_root
	var absolute_dir: String = ProjectSettings.globalize_path(output_dir)
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_dir)
	check("shot_dir_%s" % shot_name, mkdir_error == OK, "error=%d" % int(mkdir_error))
	var path: String = "%s/%s.png" % [output_dir, shot_name]
	var image: Image = get_root().get_texture().get_image()
	var save_error: Error = image.save_png(path)
	var valid_dimensions: bool = (
		image.get_width() == VIEWPORT_SIZE.x and image.get_height() == VIEWPORT_SIZE.y
	)
	check("shot_save_%s" % shot_name, save_error == OK, "error=%d" % int(save_error))
	check(
		"shot_dimensions_%s" % shot_name,
		valid_dimensions,
		"width=%d height=%d" % [image.get_width(), image.get_height()]
	)
	_shots.append(
		{
			"name": shot_name,
			"status": "PASS" if save_error == OK and valid_dimensions else "FAIL",
			"path": path
		}
	)
	print("[SHOT] %s %s" % [shot_name, path])


func _write_report() -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(_shots_root)
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_dir)
	if mkdir_error != OK:
		push_error("Cannot create report directory: %d" % int(mkdir_error))
		return
	var failed_count: int = 0
	for result: Dictionary in _checks:
		if not bool(result["ok"]):
			failed_count += 1
	var report: Dictionary = {
		"scenario": "title_launch",
		"seed": 42,
		"headless": DisplayServer.get_name() == "headless",
		"frames_used": _frames_used,
		"max_frames": MAX_FRAMES,
		"completion_sentinel": _done,
		"checks": _checks,
		"shots": _shots,
		"result": "PASS" if failed_count == 0 and _done else "FAIL",
		"elapsed_ms": Time.get_ticks_msec() - _started_msec,
	}
	var report_path: String = "%s/report.json" % _shots_root
	var report_file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		push_error("Cannot open report path: %s" % report_path)
		return
	report_file.store_string(JSON.stringify(report, "  "))
	report_file.close()
