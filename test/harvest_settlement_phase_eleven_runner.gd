extends SceneTree

const BudgetScript: GDScript = preload("res://scripts/persistence_budget_catalog.gd")
const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const ScheduleScript: GDScript = preload(
	"res://test/harvest_settlement_phase_eleven_service.gd"
)
const StateHashScript: GDScript = preload("res://scripts/persistence_state_hash.gd")

const DEFAULT_DAYS: int = 1_000

var _days: int = DEFAULT_DAYS
var _fixture_dir: String = ""
var _run_id: String = "unspecified"
var _emit_maximum: bool = false
var _failures: Array[String] = []


func _initialize() -> void:
	_parse_arguments()
	call_deferred("_run")


func _run() -> void:
	var save_path: String = "user://p11-schedule-%s.json" % _safe_id(_run_id)
	_clear_save(save_path)
	var packed: PackedScene = load("res://scenes/isometric_map.tscn") as PackedScene
	if packed == null:
		_fail("map_scene_missing")
		_finish()
		return
	var runtime: Node2D = packed.instantiate() as Node2D
	runtime.set("save_path", save_path)
	get_root().add_child(runtime)
	for _frame: int in 20:
		await process_frame
	var bridge: Node = runtime.get_node_or_null("HarvestPhaseTwo")
	var transactions: RefCounted = (
		bridge.get("_transactions") as RefCounted if bridge != null else null
	)
	if transactions == null:
		_fail("transaction_boundary_missing")
		runtime.free()
		_finish()
		return
	var base: Dictionary = transactions.call("get_snapshot") as Dictionary
	if base.is_empty():
		_fail("base_envelope_missing")
	else:
		_run_schedule(base)
		if _emit_maximum:
			_emit_maximum_fixture(base, runtime.get("_state_store") as RefCounted)
	runtime.free()
	await process_frame
	_clear_save(save_path)
	_finish()


func _run_schedule(base: Dictionary) -> void:
	var result: Dictionary = ScheduleScript.run(base, _days, _run_id)
	if not bool(result.get(&"ok", false)):
		_fail(str(result.get(&"reason", "schedule_failed")))
		return
	print(
		"[P11_SCHEDULE_HASH] run=%s days=%d hash=%s bytes=%d"
		% [_run_id, _days, str(result[&"hash"]), int(result[&"bytes"])]
	)
	if _days == 100 and not _fixture_dir.is_empty():
		_write_fixture(
			"representative-100-day.json",
			BudgetScript.canonical_json(result[&"envelope"]),
		)


func _emit_maximum_fixture(base: Dictionary, repository: RefCounted) -> void:
	var maximum: Dictionary = BudgetScript.simultaneous_maximum(base)
	var preflight: Dictionary = BudgetScript.preflight(maximum)
	var validated: Dictionary = (
		repository.call("validate_envelope", maximum) as Dictionary
		if repository != null
		else {}
	)
	if maximum.is_empty() or validated.is_empty() or not bool(preflight.get(&"ok", false)):
		_fail(
			"maximum_invalid:%s:%d"
			% [str(preflight.get(&"reason", "validation")), int(preflight.get(&"bytes", 0))]
		)
		return
	print(
		"[P11_MAXIMUM] bytes=%d plots=%d trees=%d hash=%s"
		% [
			int(preflight[&"bytes"]),
			((maximum[&"farm"] as Dictionary)[&"plots"] as Array).size(),
			((maximum[&"farm"] as Dictionary)[&"orchard"][&"trees"] as Array).size(),
			StateHashScript.state_hash(maximum),
		]
	)
	if not _fixture_dir.is_empty():
		_write_fixture("simultaneous-maximum.json", BudgetScript.canonical_json(maximum))


func _write_fixture(file_name: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(_fixture_dir)
	var path: String = _fixture_dir.path_join(file_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("fixture_write_failed:%s" % path)
		return
	file.store_string(content + "\n")
	file.close()
	print("[P11_FIXTURE] path=%s bytes=%d" % [path, content.to_utf8_buffer().size() + 1])


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--p11-days="):
			_days = clampi(int(argument.get_slice("=", 1)), 1, 10_000)
		elif argument.begins_with("--p11-run-id="):
			_run_id = argument.get_slice("=", 1).left(64)
		elif argument.begins_with("--p11-fixture-dir="):
			_fixture_dir = argument.get_slice("=", 1)
		elif argument == "--p11-emit-maximum":
			_emit_maximum = true


func _safe_id(value: String) -> String:
	var safe: String = ""
	for character: String in value:
		safe += character if character.is_valid_identifier() or character == "-" else "_"
	return safe.left(64)


func _clear_save(path: String) -> void:
	for candidate: String in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


func _fail(reason: String) -> void:
	_failures.append(reason)
	push_error("P11 certification failure: %s" % reason)


func _finish() -> void:
	if _failures.is_empty():
		print("[P11_CERTIFICATION_PASS] run=%s days=%d" % [_run_id, _days])
		quit(0)
	else:
		print("[P11_CERTIFICATION_FAIL] run=%s failures=%s" % [_run_id, str(_failures)])
		quit(1)
