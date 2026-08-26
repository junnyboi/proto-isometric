extends SceneTree

const InspectionTestsScript: GDScript = preload("res://test/test_interaction_inspection.gd")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for test_case: Dictionary in InspectionTestsScript.evaluate():
		_check(test_case)
	if _failures == 0:
		print("[INTERACTION_INSPECTION_PASS] checks=%d" % _checks)
		quit(0)
	else:
		print(
			"[INTERACTION_INSPECTION_FAIL] checks=%d failures=%d"
			% [_checks, _failures]
		)
		quit(1)


func _check(test_case: Dictionary) -> void:
	_checks += 1
	var passed: bool = bool(test_case[&"passed"])
	print("[%s] %s" % ["PASS" if passed else "FAIL", str(test_case[&"label"])])
	if not passed:
		_failures += 1
