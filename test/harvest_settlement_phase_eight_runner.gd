extends SceneTree

const PhaseEightTestsScript: GDScript = preload(
	"res://test/test_harvest_settlement_phase_eight.gd"
)
const SAVE_PATH: String = "/tmp/protos-harvest-settlement-phase-eight.json"

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_save_files()
	get_root().size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://scenes/isometric_map.tscn") as PackedScene
	var runtime: Node2D = packed.instantiate() as Node2D
	runtime.set("save_path", SAVE_PATH)
	get_root().add_child(runtime)
	for _frame: int in 16:
		await process_frame
	for test_case: Dictionary in PhaseEightTestsScript.evaluate(runtime):
		_check(test_case)
	runtime.free()
	await process_frame
	var reopened: Node2D = packed.instantiate() as Node2D
	reopened.set("save_path", SAVE_PATH)
	get_root().add_child(reopened)
	for _frame: int in 16:
		await process_frame
	for test_case: Dictionary in PhaseEightTestsScript.evaluate_reloaded(reopened):
		_check(test_case)
	reopened.free()
	await process_frame
	_remove_save_files()
	if _failures == 0:
		print("[HARVEST_SETTLEMENT_PHASE_EIGHT_PASS] checks=%d" % _checks)
		quit(0)
	else:
		print(
			"[HARVEST_SETTLEMENT_PHASE_EIGHT_FAIL] checks=%d failures=%d"
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
