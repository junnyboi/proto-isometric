extends SceneTree

const PhaseThreeTestsScript: GDScript = preload(
	"res://test/test_harvest_settlement_phase_three.gd"
)
const SAVE_PATH: String = "/tmp/protos-harvest-settlement-phase-three.json"

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
	for _frame: int in 8:
		await process_frame
	for test_case: Dictionary in PhaseThreeTestsScript.evaluate(runtime):
		_check(test_case)
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var director: RefCounted = bridge.call("get_context_tutorial_director") as RefCounted
	var expected: Dictionary = director.call("get_state") as Dictionary
	runtime.free()
	await process_frame
	var reopened: Node2D = packed.instantiate() as Node2D
	reopened.set("save_path", SAVE_PATH)
	get_root().add_child(reopened)
	for _frame: int in 8:
		await process_frame
	for test_case: Dictionary in PhaseThreeTestsScript.evaluate_reloaded(reopened, expected):
		_check(test_case)
	reopened.free()
	await process_frame
	_remove_save_files()
	if _failures == 0:
		print("[HARVEST_SETTLEMENT_PHASE_THREE_PASS] checks=%d" % _checks)
		quit(0)
	else:
		print(
			"[HARVEST_SETTLEMENT_PHASE_THREE_FAIL] checks=%d failures=%d"
			% [_checks, _failures]
		)
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
