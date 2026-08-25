extends SceneTree

const PhaseSixTestsScript: GDScript = preload("res://test/test_harvest_phase_six.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cases: Array[Dictionary] = PhaseSixTestsScript.evaluate()
	var failures: int = 0
	for case: Dictionary in cases:
		if bool(case[&"passed"]):
			print("[PASS] %s" % case[&"name"])
		else:
			failures += 1
			push_error("[FAIL] %s" % case[&"name"])
	if failures == 0:
		print("[PHASE_SIX_PASS] checks=%d" % cases.size())
		quit(0)
	else:
		print("[PHASE_SIX_FAIL] checks=%d failures=%d" % [cases.size(), failures])
		quit(1)
