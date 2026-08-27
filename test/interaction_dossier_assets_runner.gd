extends SceneTree

const TestsScript: GDScript = preload("res://test/test_interaction_dossier_assets.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cases: Array[Dictionary] = TestsScript.evaluate()
	var failures: int = 0
	for item: Dictionary in cases:
		var passed: bool = bool(item[&"passed"])
		print("[%s] %s" % ["PASS" if passed else "FAIL", item[&"label"]])
		if not passed:
			failures += 1
	if failures == 0:
		print("[INTERACTION_DOSSIER_ASSETS_PASS] checks=%d" % cases.size())
	else:
		print("[INTERACTION_DOSSIER_ASSETS_FAIL] checks=%d failures=%d" % [cases.size(), failures])
	quit(failures)
