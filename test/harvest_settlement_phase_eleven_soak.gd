extends SceneTree

const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const StateHashScript: GDScript = preload("res://scripts/persistence_state_hash.gd")

const DEFAULT_SECONDS: int = 7_200
const HEARTBEAT_SECONDS: int = 60
const INPUT_SECONDS: int = 5

var _duration_seconds: int = DEFAULT_SECONDS
var _started_msec: int = 0
var _next_heartbeat: int = HEARTBEAT_SECONDS
var _next_input: int = INPUT_SECONDS
var _runtime: Node2D
var _failures: Array[String] = []
var _input_step: int = 0


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--p11-soak-seconds="):
			_duration_seconds = clampi(int(argument.get_slice("=", 1)), 10, 10_800)
	call_deferred("_start")


func _start() -> void:
	var packed: PackedScene = load("res://scenes/isometric_map.tscn") as PackedScene
	if packed == null:
		_fail("map_scene_missing")
		_finish()
		return
	_runtime = packed.instantiate() as Node2D
	_runtime.set("save_path", "user://p11-native-soak.json")
	get_root().add_child(_runtime)
	for _frame: int in 20:
		await process_frame
	if _runtime.get_node_or_null("HarvestPhaseTwo") == null:
		_fail("harvest_bridge_missing")
		_finish()
		return
	_started_msec = Time.get_ticks_msec()
	print("[P11_NATIVE_SOAK_START] seconds=%d" % _duration_seconds)


func _process(_delta: float) -> bool:
	if _started_msec == 0:
		return false
	var elapsed: int = int((Time.get_ticks_msec() - _started_msec) / 1000)
	if elapsed >= _next_input:
		_exercise_input()
		_next_input += INPUT_SECONDS
	if elapsed >= _next_heartbeat:
		_validate_heartbeat(elapsed)
		_next_heartbeat += HEARTBEAT_SECONDS
	if elapsed >= _duration_seconds:
		_validate_heartbeat(elapsed)
		_finish()
	return false


func _exercise_input() -> void:
	var keys: Array[Key] = [KEY_W, KEY_D, KEY_S, KEY_A]
	_press_key(keys[_input_step % keys.size()])
	if _input_step % 6 == 0:
		_press_key(KEY_E)
		_press_key(KEY_ESCAPE)
	_input_step += 1


func _press_key(keycode: Key) -> void:
	var pressed: InputEventKey = InputEventKey.new()
	pressed.physical_keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	var released: InputEventKey = pressed.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)


func _validate_heartbeat(elapsed: int) -> void:
	if not is_instance_valid(_runtime):
		_fail("runtime_freed_at_%d" % elapsed)
		return
	if not bool(_runtime.call("_save_world_state")):
		_fail("save_failed_at_%d" % elapsed)
		return
	var repository: RefCounted = _runtime.get("_state_store") as RefCounted
	var envelope: Dictionary = (
		repository.call("load_state") as Dictionary if repository != null else {}
	)
	if envelope.is_empty():
		_fail("envelope_missing_at_%d" % elapsed)
	elif FarmSchemaScript.validate(envelope.get(&"farm", {})).is_empty():
		_fail("farm_invalid_at_%d" % elapsed)
	elif not StateHashScript.result_hash_matches(envelope):
		_fail("state_hash_invalid_at_%d" % elapsed)
	print(
		"[P11_NATIVE_SOAK_HEARTBEAT] elapsed=%d objects=%d memory=%d failures=%d"
		% [
			elapsed,
			int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			int(Performance.get_monitor(Performance.MEMORY_STATIC)),
			_failures.size(),
		]
	)


func _fail(reason: String) -> void:
	if reason not in _failures:
		_failures.append(reason)
		push_error("P11 native soak failure: %s" % reason)


func _finish() -> void:
	if _failures.is_empty():
		print("[P11_NATIVE_SOAK_PASS] seconds=%d" % _duration_seconds)
		quit(0)
	else:
		print("[P11_NATIVE_SOAK_FAIL] failures=%s" % str(_failures))
		quit(1)
