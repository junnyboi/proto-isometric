extends SceneTree

const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const RunCoordinatorScript: GDScript = preload("res://scripts/run_coordinator.gd")
const PhaseOneTestsScript: GDScript = preload(
	"res://test/test_harvest_settlement_phase_one.gd"
)

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world: RefCounted = InfiniteWorldScript.new() as RefCounted
	var coordinator: RefCounted = RunCoordinatorScript.new() as RefCounted
	if not bool(coordinator.call("configure_default", Vector2i(8, 10), &"SE")):
		_failures += 1
	else:
		for test_case: Dictionary in PhaseOneTestsScript.evaluate(
			world,
			coordinator.call("get_run_snapshot") as Dictionary,
			coordinator.call("get_profile_snapshot") as Dictionary,
		):
			_check(test_case)
	if _failures == 0:
		print("[SETTLEMENT_PHASE_ONE_PASS] checks=%d" % _checks)
		quit(0)
	else:
		print(
			"[SETTLEMENT_PHASE_ONE_FAIL] checks=%d failures=%d" % [_checks, _failures]
		)
		quit(1)


func _check(test_case: Dictionary) -> void:
	_checks += 1
	var passed: bool = bool(test_case[&"passed"])
	print("[%s] %s" % ["PASS" if passed else "FAIL", str(test_case[&"label"])])
	if not passed:
		_failures += 1
