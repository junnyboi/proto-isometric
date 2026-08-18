extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const RuntimeOwnershipScript: GDScript = preload("res://scripts/runtime_ownership.gd")
const RunStateScript: GDScript = preload("res://scripts/run_state.gd")
const ProfileStateScript: GDScript = preload("res://scripts/profile_state.gd")
const SessionTelemetryScript: GDScript = preload("res://scripts/session_telemetry.gd")
const DEFAULT_BALANCE: Resource = preload("res://data/balance/default_balance.tres")

var _balance: Resource
var _telemetry: RefCounted
var _run_state: RefCounted
var _profile_state: RefCounted
var _configured: bool = false


func configure_default(start_cell: Vector2i = Vector2i(8, 10), facing: StringName = &"SE") -> bool:
	var balance: Resource = DEFAULT_BALANCE.duplicate(true) as Resource
	var run_state: RefCounted = RunStateScript.new() as RefCounted
	if not bool(
		(
			run_state
			. call(
				"configure",
				&"run.legacy.v1",
				0,
				int(balance.get("max_chassis")),
				start_cell,
				facing,
			)
		)
	):
		return false
	if not bool(run_state.call("transition_to", RuntimeIdsScript.RUN_PHASE_HUNT)):
		return false
	return configure(
		balance,
		SessionTelemetryScript.new() as RefCounted,
		run_state,
		ProfileStateScript.new() as RefCounted,
	)


func configure(
	balance: Resource,
	telemetry: RefCounted,
	run_state: RefCounted,
	profile_state: RefCounted,
) -> bool:
	if (
		balance == null
		or telemetry == null
		or run_state == null
		or profile_state == null
		or not balance.has_method("validate")
		or not bool(balance.call("validate"))
		or not run_state.has_method("to_dictionary")
		or not profile_state.has_method("to_dictionary")
		or not RuntimeOwnershipScript.validate()
	):
		return false
	_balance = balance
	_telemetry = telemetry
	_run_state = run_state
	_profile_state = profile_state
	_configured = true
	return true


func is_configured() -> bool:
	return _configured


func is_behavior_neutral() -> bool:
	return _configured


func get_registry_version() -> int:
	return RuntimeIdsScript.REGISTRY_VERSION


func owner_for(domain_id: StringName) -> StringName:
	return RuntimeOwnershipScript.owner_for(domain_id)


func get_contract_snapshot() -> Array[Dictionary]:
	return RuntimeOwnershipScript.contracts().duplicate(true)


func get_balance_snapshot() -> Dictionary:
	return _balance.call("baseline_snapshot") as Dictionary if _balance != null else {}


func get_run_value(key: StringName) -> Variant:
	return _run_state.call("get_value", key) if _run_state != null else null


func set_run_value(key: StringName, value: Variant) -> bool:
	return bool(_run_state.call("set_value", key, value)) if _run_state != null else false


func transition_run(next_phase: StringName) -> bool:
	return bool(_run_state.call("transition_to", next_phase)) if _run_state != null else false


func apply_run_event(event_id: StringName) -> bool:
	return bool(_run_state.call("apply_event", event_id)) if _run_state != null else false


func _add_run_module(module_id: StringName) -> bool:
	return bool(_run_state.call("add_module", module_id)) if _run_state != null else false


func _has_run_module(module_id: StringName) -> bool:
	return bool(_run_state.call("has_module", module_id)) if _run_state != null else false


func get_run_snapshot() -> Dictionary:
	return _run_state.call("to_dictionary") as Dictionary if _run_state != null else {}


func get_profile_snapshot() -> Dictionary:
	return _profile_state.call("to_dictionary") as Dictionary if _profile_state != null else {}


func restore_state_snapshots(run_snapshot: Dictionary, profile_snapshot: Dictionary) -> bool:
	var run_candidate: RefCounted = RunStateScript.new() as RefCounted
	var profile_candidate: RefCounted = ProfileStateScript.new() as RefCounted
	if (
		not bool(run_candidate.call("restore_dictionary", run_snapshot.duplicate(true)))
		or not bool(profile_candidate.call("restore_dictionary", profile_snapshot.duplicate(true)))
	):
		return false
	_run_state = run_candidate
	_profile_state = profile_candidate
	return true


func restore_persisted_state(active_run: Variant, profile_snapshot: Dictionary) -> bool:
	var run_snapshot: Dictionary = get_run_snapshot()
	if active_run is Dictionary:
		run_snapshot = (active_run as Dictionary).duplicate(true)
	elif active_run != null:
		return false
	return restore_state_snapshots(run_snapshot, profile_snapshot)


func get_telemetry_events() -> Array[Dictionary]:
	return _telemetry.call("get_events") as Array[Dictionary] if _telemetry != null else []


func get_telemetry_summary() -> Dictionary:
	return _telemetry.call("get_summary") as Dictionary if _telemetry != null else {}


func record_event(event_id: StringName, payload: Dictionary = {}) -> bool:
	return bool(_telemetry.call("record", event_id, payload)) if _telemetry != null else false
