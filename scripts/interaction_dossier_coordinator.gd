extends RefCounted

const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const DossierStateScript: GDScript = preload("res://scripts/interaction_dossier_state.gd")
const ExecutionResultScript: GDScript = preload("res://scripts/interaction_execution_result.gd")
const HistoryScript: GDScript = preload("res://scripts/interaction_session_history.gd")
const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const OperationCatalogScript: GDScript = preload("res://scripts/interaction_operation_catalog.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const PreviewScript: GDScript = preload("res://scripts/interaction_outcome_preview_catalog.gd")
const ProjectionScript: GDScript = preload("res://scripts/interaction_dossier_projection.gd")
const ToastScript: GDScript = preload("res://scripts/interaction_result_toast_projection.gd")

const COUNTER_KEYS: Array[StringName] = [
	&"composition_rebuilds",
	&"history_appends",
	&"preview_rebuilds",
	&"projection_rebuilds",
	&"toast_rebuilds",
]

var _history: RefCounted = HistoryScript.new()
var _snapshot: Dictionary = {}
var _result: Dictionary = {}
var _toast: Dictionary = {}
var _nearby: Array[Dictionary] = []
var _selected_action_id: StringName = &""
var _source_fingerprint: String = ""
var _state: Dictionary = {}
var _counters: Dictionary = {
	&"composition_rebuilds": 0,
	&"history_appends": 0,
	&"preview_rebuilds": 0,
	&"projection_rebuilds": 0,
	&"toast_rebuilds": 0,
}


func set_snapshot(value: Variant, selected_action_id: StringName = &"") -> bool:
	if not MenuScript.validate(value):
		return false
	var snapshot: Dictionary = value as Dictionary
	var selected: StringName = _selected_for(snapshot, selected_action_id)
	if (
		_snapshot.get(&"snapshot_id", &"") == snapshot[&"snapshot_id"]
		and _selected_action_id == selected
	):
		return false
	_snapshot = snapshot.duplicate(true)
	_selected_action_id = selected
	if (
		not _result.is_empty()
		and _result[&"source_snapshot_id"] != _snapshot[&"snapshot_id"]
	):
		_result = {}
	_mark_dirty()
	return true


func set_selection(action_id: StringName) -> bool:
	if _snapshot.is_empty() or _find_option(_snapshot, action_id).is_empty():
		return false
	if action_id == _selected_action_id:
		return false
	_selected_action_id = action_id
	_mark_dirty()
	return true


func observe_result(value: Variant) -> bool:
	var descriptor: Dictionary = _descriptor_for_result(value)
	if descriptor.is_empty() or not ExecutionResultScript.validate(value, descriptor):
		return false
	var result: Dictionary = value as Dictionary
	if not (_history as RefCounted).call("append_result", result, descriptor):
		return false
	_counters[&"history_appends"] = int(_counters[&"history_appends"]) + 1
	_result = result.duplicate(true)
	var incoming_toast: Dictionary = ToastScript.build(result, descriptor)
	if ToastScript.should_replace(_toast, incoming_toast):
		_toast = incoming_toast
		_counters[&"toast_rebuilds"] = int(_counters[&"toast_rebuilds"]) + 1
	_mark_dirty()
	return true


func set_nearby(value: Variant) -> bool:
	if not DossierStateScript.validate_nearby(value):
		return false
	var nearby: Array[Dictionary] = []
	for row: Dictionary in value as Array[Dictionary]:
		nearby.append(row.duplicate(true))
	if nearby == _nearby:
		return false
	_nearby = nearby
	_mark_dirty()
	return true


func compose() -> Dictionary:
	if _snapshot.is_empty():
		return {}
	var fingerprint: String = _input_fingerprint()
	if fingerprint == _source_fingerprint and DossierStateScript.validate(_state):
		return _state.duplicate(true)
	var projection: Dictionary = ProjectionScript.project(_snapshot, _result)
	_counters[&"projection_rebuilds"] = int(_counters[&"projection_rebuilds"]) + 1
	if projection.is_empty():
		return {}
	var option: Dictionary = _find_option(_snapshot, _selected_action_id)
	var preview: Dictionary = _preview_for(option)
	var unsigned: Dictionary = {
		&"state_id": &"pending",
		&"source_snapshot_id": projection[&"source_snapshot_id"],
		&"target_id": projection[&"target_id"],
		&"target_cell": projection[&"target_cell"],
		&"profile": projection[&"profile"],
		&"portrait_id": projection[&"portrait_id"],
		&"title_key": projection[&"title_key"],
		&"subtitle_key": projection[&"subtitle_key"],
		&"summary_sections": projection[&"summary_sections"],
		&"chips": projection[&"chips"],
		&"action_ids": projection[&"action_ids"],
		&"selected_action_id": _selected_action_id,
		&"preview": preview,
		&"nearby": _nearby.duplicate(true),
		&"history": (_history as RefCounted).call(
			"project_for_target",
			_snapshot[&"target_id"],
		) as Array[Dictionary],
		&"toast": _toast.duplicate(true),
	}
	_state = DossierStateScript.build(unsigned)
	if _state.is_empty():
		return {}
	_source_fingerprint = fingerprint
	_counters[&"composition_rebuilds"] = int(_counters[&"composition_rebuilds"]) + 1
	return _state.duplicate(true)


func state() -> Dictionary:
	return _state.duplicate(true) if DossierStateScript.validate(_state) else {}


func counters() -> Dictionary:
	return _counters.duplicate(true)


func clear_session() -> void:
	(_history as RefCounted).call("clear")
	_result = {}
	_toast = {}
	_mark_dirty()


func reset() -> void:
	_snapshot = {}
	_result = {}
	_toast = {}
	_nearby.clear()
	_selected_action_id = &""
	_source_fingerprint = ""
	_state = {}
	(_history as RefCounted).call("clear")
	for key: StringName in COUNTER_KEYS:
		_counters[key] = 0


func _preview_for(option: Dictionary) -> Dictionary:
	if option.is_empty():
		return {}
	var descriptor: Dictionary = OperationCatalogScript.descriptor_for(
		option[&"operation"] as StringName,
		option[&"provider_id"] as StringName,
	)
	var preview: Dictionary = PreviewScript.build(_snapshot, option, descriptor)
	if not preview.is_empty():
		_counters[&"preview_rebuilds"] = int(_counters[&"preview_rebuilds"]) + 1
	return preview


func _descriptor_for_result(value: Variant) -> Dictionary:
	if not value is Dictionary or _snapshot.is_empty():
		return {}
	var result: Dictionary = value as Dictionary
	if (
		result.get(&"source_snapshot_id") != _snapshot[&"snapshot_id"]
		or result.get(&"target_id") != _snapshot[&"target_id"]
		or result.get(&"target_cell") != _snapshot[&"target_cell"]
	):
		return {}
	var option: Dictionary = _find_option(_snapshot, result.get(&"action_id", &""))
	if option.is_empty():
		return {}
	return OperationCatalogScript.descriptor_for(
		option[&"operation"] as StringName,
		option[&"provider_id"] as StringName,
	)


static func _selected_for(snapshot: Dictionary, requested: StringName) -> StringName:
	if not requested.is_empty() and not _find_option(snapshot, requested).is_empty():
		return requested
	return ((snapshot[&"options"] as Array)[0] as Dictionary)[&"action_id"] as StringName


static func _find_option(snapshot: Dictionary, action_id: Variant) -> Dictionary:
	var options: Array = snapshot.get(&"options", []) as Array
	if options.is_empty() or not OptionScript.validate(options.front()):
		return {}
	for option: Dictionary in snapshot[&"options"] as Array[Dictionary]:
		if option[&"action_id"] == action_id:
			return option.duplicate(true)
	return {}


func _input_fingerprint() -> String:
	return CodecScript.digest({
		&"snapshot_id": _snapshot[&"snapshot_id"],
		&"selected_action_id": _selected_action_id,
		&"result_id": _result.get(&"result_id", &""),
		&"toast_id": _toast.get(&"toast_id", &""),
		&"nearby": _nearby,
		&"history": (_history as RefCounted).call("records"),
	})


func _mark_dirty() -> void:
	_source_fingerprint = ""
