extends RefCounted

signal settlement_committed(operation: StringName, result: Dictionary)

const ApplicantLifecycleScript: GDScript = preload(
	"res://scripts/applicant_lifecycle_service.gd"
)
const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const SettlerDayScript: GDScript = preload("res://scripts/settler_day_service.gd")
const WorkforceScript: GDScript = preload("res://scripts/workforce_service.gd")

var _farm_runtime: RefCounted
var _transactions: RefCounted


func configure(farm_runtime: RefCounted, transactions: RefCounted) -> bool:
	if farm_runtime == null or transactions == null:
		return false
	_farm_runtime = farm_runtime
	_transactions = transactions
	return true


func snapshot() -> Dictionary:
	if _farm_runtime == null:
		return {}
	var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
	var roster: Array[Dictionary] = WorkforceScript.roster(farm)
	for entry: Dictionary in roster:
		var settler_id: StringName = StringName(str(entry[&"settler_id"]))
		entry[&"work_status"] = SettlerDayScript.presentation_status(farm, settler_id)
		entry[&"shift_report"] = SettlerDayScript.last_shift_report(farm, settler_id)
	var sites: Array[Dictionary] = WorkforceScript.site_snapshots(farm)
	var workforce: Dictionary = ((farm[&"homestead"] as Dictionary)[&"workforce"] as Dictionary)
	for site: Dictionary in sites:
		var reports: Array[Dictionary] = []
		for report: Dictionary in workforce[&"shift_reports"] as Array[Dictionary]:
			if str(report[&"site_id"]) == str(site[&"site_id"]):
				reports.append(report.duplicate(true))
		site[&"shift_reports"] = reports
	return {
		&"offer": ApplicantLifecycleScript.current_offer(farm),
		&"lifecycle": ApplicantLifecycleScript.lifecycle_state(farm),
		&"roster": roster,
		&"sites": sites,
		&"source_revision": int((farm[&"revisions"] as Dictionary)[&"result_revision"]),
	}


func decide_applicant(
	action: StringName,
	expected_applicant_id: StringName = &"",
	expected_sequence: int = -1,
) -> Dictionary:
	if action not in [&"invite", &"decline", &"defer"]:
		return _result(false, &"unknown_applicant_decision")
	var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
	var lifecycle: Dictionary = ApplicantLifecycleScript.lifecycle_state(farm)
	var applicant_id: String = (
		str(expected_applicant_id)
		if expected_applicant_id != &""
		else str(lifecycle.get(&"current_applicant_id", ""))
	)
	var sequence: int = (
		expected_sequence if expected_sequence >= 0 else int(lifecycle.get(&"sequence", 0))
	)
	var arguments: Dictionary = {
		&"decision": action,
		&"expected_applicant_id": StringName(applicant_id),
		&"expected_sequence": sequence,
	}
	var payload: Dictionary = {
		&"decision": str(action),
		&"applicant_id": applicant_id,
		&"offer_sequence": sequence,
	}
	var token: String = "applicant:%d:%s" % [sequence, str(action)]
	var deterministic: Dictionary = ApplicantLifecycleScript.deterministic_result(farm, action)
	return _transact_exact_once(&"applicant_decision", arguments, token, payload, deterministic)


func assign(
	settler_id: StringName,
	site_id: StringName,
	slot: int,
	shift: int,
	expected_revision: int = -1,
) -> Dictionary:
	var source_revision: int = expected_revision if expected_revision >= 0 else _source_revision()
	var arguments: Dictionary = {
		&"settler_id": settler_id,
		&"site_id": site_id,
		&"slot": slot,
		&"shift": shift,
		&"expected_revision": source_revision,
	}
	var payload: Dictionary = {
		&"settler_id": str(settler_id),
		&"site_id": str(site_id),
		&"slot": slot,
		&"shift": shift,
		&"source_revision": source_revision,
	}
	var token: String = "assignment:%d:%s" % [
		source_revision, CodecScript.digest(payload).left(24)
	]
	var deterministic: Dictionary = {
		&"settler_id": str(settler_id),
		&"site_id": str(site_id),
		&"slot": slot,
		&"shift": shift,
	}
	return _transact_exact_once(&"workforce_assign", arguments, token, payload, deterministic)


func unassign(settler_id: StringName, expected_revision: int = -1) -> Dictionary:
	var source_revision: int = expected_revision if expected_revision >= 0 else _source_revision()
	var arguments: Dictionary = {
		&"settler_id": settler_id, &"expected_revision": source_revision
	}
	var payload: Dictionary = {
		&"settler_id": str(settler_id),
		&"source_revision": source_revision,
		&"action": "unassign",
	}
	var token: String = "assignment:%d:%s" % [
		source_revision, CodecScript.digest(payload).left(24)
	]
	var deterministic: Dictionary = {
		&"settler_id": str(settler_id), &"action": "unassigned"
	}
	return _transact_exact_once(&"workforce_unassign", arguments, token, payload, deterministic)


func set_shift(
	settler_id: StringName, shift: int, expected_revision: int = -1
) -> Dictionary:
	var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
	var assignment: Dictionary = WorkforceScript.assignment_for(farm, settler_id)
	if assignment.is_empty():
		return _result(false, &"work_assignment_missing")
	var source_revision: int = expected_revision if expected_revision >= 0 else _source_revision()
	var arguments: Dictionary = {
		&"settler_id": settler_id,
		&"site_id": StringName(str(assignment[&"site_id"])),
		&"slot": int(assignment[&"slot"]),
		&"shift": shift,
		&"expected_revision": source_revision,
	}
	var payload: Dictionary = {
		&"settler_id": str(settler_id),
		&"site_id": str(assignment[&"site_id"]),
		&"slot": int(assignment[&"slot"]),
		&"shift": shift,
		&"source_revision": source_revision,
	}
	var token: String = "shift:%d:%s" % [source_revision, CodecScript.digest(payload).left(24)]
	var deterministic: Dictionary = {
		&"settler_id": str(settler_id), &"shift": shift, &"action": "shift_changed"
	}
	return _transact_exact_once(&"workforce_assign", arguments, token, payload, deterministic)


func _transact_exact_once(
	operation: StringName,
	arguments: Dictionary,
	token: String,
	payload: Dictionary,
	deterministic: Dictionary,
) -> Dictionary:
	var result: Dictionary = _transactions.call(
		"transact_exact_once", operation, arguments, token, payload, deterministic
	) as Dictionary
	var envelope: Dictionary = result.get(&"candidate", {}) as Dictionary
	if envelope.is_empty() or not envelope.get(&"farm", {}) is Dictionary:
		return _result(false, &"settlement_candidate_missing")
	if not bool(_farm_runtime.call("sync_committed", envelope[&"farm"])):
		return _result(false, &"live_farm_sync_failed")
	if bool(result.get(&"ok", false)) and not bool(result.get(&"replayed", false)):
		settlement_committed.emit(operation, result.duplicate(true))
	return result


func _source_revision() -> int:
	var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
	return int((farm[&"revisions"] as Dictionary)[&"result_revision"])


func _result(ok: bool, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"reason": reason, &"candidate": {}}
