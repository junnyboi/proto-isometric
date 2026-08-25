extends SceneTree

const HarvestPhaseTwoTestsScript: GDScript = preload("res://test/test_harvest_phase_two.gd")
const SAVE_PATH: String = "/tmp/protos-harvest-phase-two.json"

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
	for test_case: Dictionary in HarvestPhaseTwoTestsScript.evaluate(runtime):
		_check(test_case)
	runtime.free()
	await process_frame
	_remove_save_files()
	if _failures == 0:
		print("[PHASE_TWO_PASS] checks=%d" % _checks)
		quit(0)
	else:
		print("[PHASE_TWO_FAIL] checks=%d failures=%d" % [_checks, _failures])
		quit(1)


func _check(test_case: Dictionary) -> void:
	_checks += 1
	var passed: bool = bool(test_case[&"passed"])
	print("[%s] %s" % ["PASS" if passed else "FAIL", str(test_case[&"label"])])
	if not passed:
		_failures += 1


func _remove_save_files() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	for path: String in DirAccess.get_files_at("/tmp"):
		if path.begins_with("protos-harvest-phase-two.json.quarantine"):
			DirAccess.remove_absolute("/tmp/%s" % path)
