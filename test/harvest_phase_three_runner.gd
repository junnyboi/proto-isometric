extends SceneTree

const HarvestPhaseThreeTestsScript: GDScript = preload("res://test/test_harvest_phase_three.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const SAVE_PATH: String = "/tmp/protos-harvest-phase-three.json"

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_save_files()
	var packed: PackedScene = load("res://scenes/isometric_map.tscn") as PackedScene
	var runtime: Node2D = packed.instantiate() as Node2D
	runtime.set("save_path", SAVE_PATH)
	get_root().add_child(runtime)
	await process_frame
	await process_frame
	await process_frame
	for test_case: Dictionary in HarvestPhaseThreeTestsScript.evaluate(runtime):
		_check(test_case)
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var persisted: Dictionary = (
		farm_runtime.call("transact", &"till", {&"cell": Vector2i(10, 7)}) as Dictionary
	)
	runtime.free()
	await process_frame
	var reloaded: Node2D = packed.instantiate() as Node2D
	reloaded.set("save_path", SAVE_PATH)
	get_root().add_child(reloaded)
	await process_frame
	await process_frame
	await process_frame
	var reloaded_bridge: Node = reloaded.get_node("HarvestPhaseTwo")
	var reloaded_farm: RefCounted = reloaded_bridge.call("get_farm_runtime") as RefCounted
	var reloaded_snapshot: Dictionary = reloaded_farm.call("get_snapshot") as Dictionary
	_check(
		{
			&"label": "PH-15 live sparse plot survives repository save and map reload",
			&"passed": (
				bool(persisted[&"ok"])
				and not FarmStateScript.plot_at(reloaded_snapshot, Vector2i(10, 7)).is_empty()
			),
		}
	)
	reloaded.free()
	await process_frame
	_remove_save_files()
	if _failures == 0:
		print("[PHASE_THREE_PASS] checks=%d" % _checks)
		quit(0)
	else:
		print("[PHASE_THREE_FAIL] checks=%d failures=%d" % [_checks, _failures])
		quit(1)


func _check(test_case: Dictionary) -> void:
	_checks += 1
	var passed: bool = bool(test_case[&"passed"])
	print("[%s] %s" % ["PASS" if passed else "FAIL", str(test_case[&"label"])])
	if not passed:
		_failures += 1


func _remove_save_files() -> void:
	var directory: DirAccess = DirAccess.open("/tmp")
	if directory == null:
		return
	var prefix: String = SAVE_PATH.get_file()
	for path: String in directory.get_files():
		if path == prefix or path.begins_with(prefix + "."):
			directory.remove(path)
