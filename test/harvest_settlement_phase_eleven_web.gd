extends Node

const ScheduleScript: GDScript = preload(
	"res://test/harvest_settlement_phase_eleven_service.gd"
)

const DAYS: int = 1_000
const SAVE_PATH: String = "user://p11-web-schedule.json"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_clear_save()
	var packed: PackedScene = load("res://scenes/isometric_map.tscn") as PackedScene
	if packed == null:
		_finish(false, "map_scene_missing")
		return
	var runtime: Node2D = packed.instantiate() as Node2D
	runtime.set("save_path", SAVE_PATH)
	add_child(runtime)
	for _frame: int in 20:
		await get_tree().process_frame
	var bridge: Node = runtime.get_node_or_null("HarvestPhaseTwo")
	var transactions: RefCounted = (
		bridge.get("_transactions") as RefCounted if bridge != null else null
	)
	if transactions == null:
		_finish(false, "transaction_boundary_missing")
		return
	var base: Dictionary = transactions.call("get_snapshot") as Dictionary
	var result: Dictionary = ScheduleScript.run(base, DAYS, "web-1000")
	if not bool(result.get(&"ok", false)):
		_finish(false, str(result.get(&"reason", "schedule_failed")))
		return
	print(
		"[P11_WEB_SCHEDULE_HASH] days=%d hash=%s bytes=%d"
		% [DAYS, str(result[&"hash"]), int(result[&"bytes"])]
	)
	_publish_browser_result(
		{&"passed": true, &"hash": str(result[&"hash"]), &"bytes": int(result[&"bytes"])}
	)
	_finish(true, "")


func _clear_save() -> void:
	for candidate: String in [SAVE_PATH, SAVE_PATH + ".tmp", SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


func _finish(passed: bool, reason: String) -> void:
	if passed:
		print("[P11_WEB_CERTIFICATION_PASS]")
	else:
		_publish_browser_result({&"passed": false, &"reason": reason})
		push_error("P11 Web certification failure: %s" % reason)
		print("[P11_WEB_CERTIFICATION_FAIL] reason=%s" % reason)
	get_tree().quit(0 if passed else 1)


func _publish_browser_result(result: Dictionary) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__p11Result = %s" % JSON.stringify(result))
