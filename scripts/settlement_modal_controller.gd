extends Node2D

signal modal_changed(active: bool)
signal assignment_committed(result: Dictionary)

const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")
const PresenterScript: GDScript = preload("res://scripts/settlement_presenter.gd")

var _runtime: RefCounted
var _presenter: CanvasLayer
var _mobile: CanvasLayer


func configure(runtime: RefCounted, mobile: CanvasLayer = null) -> bool:
	if runtime == null:
		return false
	_runtime = runtime
	_mobile = mobile
	_presenter = PresenterScript.new() as CanvasLayer
	add_child(_presenter)
	_presenter.connect("action_requested", _on_action_requested)
	var preferences: RefCounted = PlayerPreferencesScript.new() as RefCounted
	_presenter.call("apply_preferences", preferences.call("load_preferences") as Dictionary)
	return true


func open(tab: StringName = &"offer") -> bool:
	if _runtime == null or _presenter == null:
		return false
	var snapshot: Dictionary = _runtime.call("snapshot") as Dictionary
	if tab == &"offer" and (snapshot.get(&"offer", {}) as Dictionary).is_empty():
		tab = &"roster"
	_presenter.call("present", snapshot, tab)
	modal_changed.emit(true)
	return true


func close() -> void:
	if _presenter != null:
		_presenter.call("dismiss")
	modal_changed.emit(false)


func is_open() -> bool:
	return _presenter != null and bool(_presenter.call("is_open"))


func panel_bounds() -> Rect2:
	return _presenter.call("panel_bounds") as Rect2 if _presenter != null else Rect2()


func get_presenter() -> CanvasLayer:
	return _presenter


func _on_action_requested(action: StringName, data: Dictionary) -> void:
	if action == &"close":
		close()
		return
	var result: Dictionary = {&"ok": false, &"reason": &"unknown_settlement_action"}
	match action:
		&"invite", &"decline", &"defer":
			result = _runtime.call(
				"decide_applicant",
				action,
				StringName(str(data.get(&"applicant_id", ""))),
				int(data.get(&"offer_sequence", -1)),
			) as Dictionary
		&"assign":
			result = _runtime.call(
				"assign",
				StringName(str(data.get(&"settler_id", ""))),
				StringName(str(data.get(&"site_id", ""))),
				int(data.get(&"slot", -1)),
				int(data.get(&"shift", -1)),
				int(data.get(&"source_revision", -1)),
			) as Dictionary
		&"unassign":
			result = _runtime.call(
				"unassign",
				StringName(str(data.get(&"settler_id", ""))),
				int(data.get(&"source_revision", -1)),
			) as Dictionary
		&"set_reserve":
			result = _runtime.call(
				"set_reserve",
				StringName(str(data.get(&"item_id", ""))),
				int(data.get(&"floor", -1)),
				int(data.get(&"source_revision", -1)),
			) as Dictionary
		&"save_policy":
			result = _runtime.call(
				"set_recipe_policy",
				StringName(str(data.get(&"site_id", ""))),
				StringName(str(data.get(&"recipe_id", ""))),
				bool(data.get(&"enabled", false)),
				int(data.get(&"priority", -1)),
				int(data.get(&"target_count", -1)),
				int(data.get(&"source_revision", -1)),
			) as Dictionary
		&"force_delivery":
			result = _runtime.call(
				"force_delivery",
				StringName(str(data.get(&"job_id", ""))),
				int(data.get(&"source_revision", -1)),
			) as Dictionary
	if bool(result.get(&"ok", false)) and action == &"assign":
		assignment_committed.emit(result.duplicate(true))
	if _presenter != null and _presenter.call("is_open"):
		_presenter.call("update_snapshot", _runtime.call("snapshot") as Dictionary)
		_presenter.call("present_result", result)
