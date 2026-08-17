extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const RuntimeOwnershipScript: GDScript = preload("res://scripts/runtime_ownership.gd")
const SessionTelemetryScript: GDScript = preload("res://scripts/session_telemetry.gd")
const DEFAULT_BALANCE: Resource = preload("res://data/balance/default_balance.tres")

var _balance: Resource
var _telemetry: RefCounted
var _configured: bool = false


func configure_default() -> bool:
	return configure(DEFAULT_BALANCE.duplicate(true) as Resource, SessionTelemetryScript.new())


func configure(balance: Resource, telemetry: RefCounted) -> bool:
	if (
		balance == null
		or telemetry == null
		or not balance.has_method("validate")
		or not bool(balance.call("validate"))
		or not RuntimeOwnershipScript.validate()
	):
		return false
	_balance = balance
	_telemetry = telemetry
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


func get_telemetry_events() -> Array[Dictionary]:
	return _telemetry.call("get_events") as Array[Dictionary] if _telemetry != null else []


func get_telemetry_summary() -> Dictionary:
	return _telemetry.call("get_summary") as Dictionary if _telemetry != null else {}


func record_event(event_id: StringName, payload: Dictionary = {}) -> bool:
	return bool(_telemetry.call("record", event_id, payload)) if _telemetry != null else false
