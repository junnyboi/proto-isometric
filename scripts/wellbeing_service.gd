extends RefCounted

const CalendarScript: GDScript = preload("res://scripts/calendar_state.gd")
const HousingScript: GDScript = preload("res://scripts/housing_protection_service.gd")
const InventoryScript: GDScript = preload("res://scripts/inventory_service.gd")
const ReceiptLedgerScript: GDScript = preload("res://scripts/exact_once_receipt_ledger.gd")
const ResidentScript: GDScript = preload("res://scripts/resident_service.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")

const FOOD_ID: StringName = &"item.food.field_ration"
const NOTICE_THRESHOLD: int = 25
const REMEDY_THRESHOLD: int = 40
const NOTICE_REMEDY_DAYS: int = 2
const INJURY_DURATION_DAYS: int = 2
const CLINIC_INJURY_DURATION_DAYS: int = 1
const INJURY_MODULUS: int = 23
const RECEIPT_PREFIX: String = "wellbeing:day."

const SHELTER_PROTECTED: StringName = &"wellbeing.shelter.protected"
const SHELTER_UNPROTECTED: StringName = &"wellbeing.shelter.unprotected"
const FOOD_SHARED: StringName = &"wellbeing.food.shared"
const FOOD_SHORTAGE: StringName = &"wellbeing.food.shortage"
const RESTED: StringName = &"wellbeing.rest.sufficient"
const SAFETY_CONFIRMED: StringName = &"wellbeing.safety.confirmed"
const SAFETY_STOP: StringName = &"wellbeing.safety.stop_honored"
const INJURY_TREATED: StringName = &"wellbeing.care.treated"
const INJURY_UNTREATED: StringName = &"wellbeing.care.untreated"
const VOICE_HEARD: StringName = &"wellbeing.voice.heard"
const BELONGING: StringName = &"wellbeing.belonging.supported"
const ISOLATED: StringName = &"wellbeing.belonging.isolated"
const INJURY_NONFATAL: StringName = &"wellbeing.injury.nonfatal"
const NOTICE_OPENED: StringName = &"wellbeing.notice.opened"
const NOTICE_REMEDIED: StringName = &"wellbeing.notice.remedied"
const DEPARTED: StringName = &"wellbeing.departure.voluntary"

const NEGATIVE_PRIORITY: Array[StringName] = [
	INJURY_UNTREATED, SHELTER_UNPROTECTED, FOOD_SHORTAGE, ISOLATED,
]
const REASON_DEFINITIONS: Dictionary = {
	SHELTER_PROTECTED: {&"delta": 3, &"remedies": []},
	SHELTER_UNPROTECTED: {&"delta": -15, &"remedies": [&"restore_protected_bed"]},
	FOOD_SHARED: {&"delta": 4, &"remedies": []},
	FOOD_SHORTAGE: {&"delta": -12, &"remedies": [&"stock_field_rations"]},
	RESTED: {&"delta": 2, &"remedies": []},
	SAFETY_CONFIRMED: {&"delta": 2, &"remedies": []},
	SAFETY_STOP: {&"delta": 0, &"remedies": [&"make_work_site_safe"]},
	INJURY_TREATED: {&"delta": 2, &"remedies": []},
	INJURY_UNTREATED: {&"delta": -10, &"remedies": [&"restore_clinic_power"]},
	VOICE_HEARD: {&"delta": 0, &"remedies": []},
	BELONGING: {&"delta": 2, &"remedies": []},
	ISOLATED: {&"delta": -3, &"remedies": [&"welcome_another_settler"]},
	INJURY_NONFATAL: {&"delta": -8, &"remedies": [&"allow_recovery"]},
	NOTICE_OPENED: {&"delta": 0, &"remedies": [&"resolve_open_concern"]},
	NOTICE_REMEDIED: {&"delta": 0, &"remedies": []},
	DEPARTED: {&"delta": 0, &"remedies": []},
}


static func advance(farm: Dictionary, world_seed: int, absolute_day: int) -> Dictionary:
	var source: Dictionary = reconcile_recovery(farm, absolute_day)
	if absolute_day < 1:
		return _result(false, source, &"invalid_wellbeing_day", [], false)
	var workforce: Dictionary = _workforce(source)
	var payload: Dictionary = {
		&"absolute_day": absolute_day,
		&"world_seed": world_seed,
	}
	var token: String = "%s%09d" % [RECEIPT_PREFIX, absolute_day]
	var replay: Dictionary = ReceiptLedgerScript.lookup(source[&"receipts"], token, payload)
	if replay[&"status"] == &"duplicate":
		return _result(true, source, &"", [], true)
	if replay[&"status"] != &"missing":
		return _result(false, source, &"wellbeing_receipt_conflict", [], false)
	var prepared: Dictionary = ReceiptLedgerScript.prepare_for_record(source[&"receipts"], token)
	if prepared.is_empty():
		return _result(false, source, &"wellbeing_receipt_capacity", [], false)
	source[&"receipts"] = prepared
	var settlers: Array[Dictionary] = (workforce[&"settlers"] as Array).duplicate(true)
	var fed: bool = _consume_equitable_food(source, settlers.size())
	var candidate: Dictionary = source
	if settlers.size() > 0 and fed:
		var removed: Dictionary = InventoryScript.remove_across(candidate, FOOD_ID, settlers.size())
		if not bool(removed[&"ok"]):
			return _result(false, farm, &"wellbeing_food_debit_failed", [], false)
		candidate = removed[&"candidate"] as Dictionary
	var clinic: bool = _clinic_available(candidate)
	var population: int = settlers.size()
	var summaries: Array[Dictionary] = []
	var departed_ids: Array[String] = []
	var kept: Array[Dictionary] = []
	for settler: Dictionary in settlers:
		var settled: Dictionary = _resolve_settler(
			candidate, settler, world_seed, absolute_day, fed, clinic, population
		)
		summaries.append(settled[&"summary"])
		if bool(settled[&"departed"]):
			departed_ids.append(str(settler[&"settler_id"]))
		else:
			kept.append(settled[&"settler"])
	workforce = _workforce(candidate)
	workforce[&"settlers"] = kept
	workforce = _apply_concerns(workforce, summaries, departed_ids, absolute_day)
	workforce = _remove_departed_links(workforce, departed_ids)
	var normalized: Dictionary = SectionsScript.validate_workforce(workforce)
	if normalized.is_empty():
		return _result(false, farm, &"invalid_wellbeing_candidate", [], false)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	homestead[&"workforce"] = normalized
	candidate[&"homestead"] = homestead
	var receipt_result: Dictionary = {
		&"absolute_day": absolute_day,
		&"settlers_evaluated": settlers.size(),
		&"departed_ids": departed_ids,
	}
	var recorded: Dictionary = ReceiptLedgerScript.record(
		candidate[&"receipts"], token, payload, receipt_result
	)
	if not bool(recorded[&"ok"]):
		return _result(false, farm, &"wellbeing_receipt_failed", [], false)
	candidate[&"receipts"] = recorded[&"candidate"]
	return _result(true, candidate, &"", summaries, false)


static func reason_definition(reason_id: StringName) -> Dictionary:
	return (REASON_DEFINITIONS.get(reason_id, {}) as Dictionary).duplicate(true)


static func reconcile_recovery(farm: Dictionary, absolute_day: int) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var workforce: Dictionary = _workforce(candidate)
	var changed: bool = false
	for settler: Dictionary in workforce[&"settlers"] as Array[Dictionary]:
		if (
			str(settler[&"status"]) == "recovering"
			and absolute_day >= int(settler[&"injured_until_day"])
		):
			settler[&"status"] = "notice" if int(settler[&"notice_day"]) > 0 else "active"
			changed = true
	if not changed:
		return candidate
	var normalized: Dictionary = SectionsScript.validate_workforce(workforce)
	if normalized.is_empty():
		return farm.duplicate(true)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	homestead[&"workforce"] = normalized
	candidate[&"homestead"] = homestead
	return candidate


static func concern_for(farm: Dictionary, settler_id: StringName) -> Dictionary:
	for concern: Dictionary in _workforce(farm)[&"concerns"] as Array[Dictionary]:
		if str(concern[&"settler_id"]) == str(settler_id):
			return concern.duplicate(true)
	return {}


static func remedies_for(reason_id: StringName) -> Array[StringName]:
	var definition: Dictionary = reason_definition(reason_id)
	var result: Array[StringName] = []
	for remedy: StringName in definition.get(&"remedies", []) as Array[StringName]:
		result.append(remedy)
	return result


static func injury_occurs(world_seed: int, absolute_day: int, settler_id: StringName) -> bool:
	var value: int = 2_166_136_261
	for byte: int in ("%d|%d|%s" % [world_seed, absolute_day, settler_id]).to_utf8_buffer():
		value = int((value ^ byte) * 16_777_619) & 0x7fffffff
	return value % INJURY_MODULUS == 0


static func _resolve_settler(
	farm: Dictionary,
	settler: Dictionary,
	world_seed: int,
	absolute_day: int,
	fed: bool,
	clinic: bool,
	population: int,
) -> Dictionary:
	var state: Dictionary = settler.duplicate(true)
	var settler_id: StringName = StringName(str(state[&"settler_id"]))
	var reasons: Array[StringName] = []
	reasons.append(
		SHELTER_PROTECTED if HousingScript.assignment_is_protected(farm, settler_id)
		else SHELTER_UNPROTECTED
	)
	reasons.append(FOOD_SHARED if fed else FOOD_SHORTAGE)
	reasons.append(RESTED)
	var report: Dictionary = _shift_report(farm, settler_id, absolute_day)
	var safety_stop: bool = str(report.get(&"reason", "")) == "site_unsafe"
	reasons.append(SAFETY_STOP if safety_stop else SAFETY_CONFIRMED)
	if safety_stop:
		reasons.append(VOICE_HEARD)
	var injured: bool = false
	if (
		str(state[&"status"]) == "active"
		and str(report.get(&"status", "")) == "productive"
		and injury_occurs(world_seed, absolute_day, settler_id)
	):
		injured = true
		state[&"injured_until_day"] = absolute_day + (
			CLINIC_INJURY_DURATION_DAYS if clinic else INJURY_DURATION_DAYS
		)
		state[&"status"] = "recovering"
		reasons.append(INJURY_NONFATAL)
	if int(state[&"injured_until_day"]) > absolute_day:
		reasons.append(INJURY_TREATED if clinic else INJURY_UNTREATED)
	reasons.append(BELONGING if population > 1 else ISOLATED)
	reasons = _canonical_reasons(reasons)
	var morale_delta: int = 0
	for reason_id: StringName in reasons:
		morale_delta += int(reason_definition(reason_id).get(&"delta", 0))
	state[&"morale"] = clampi(int(state[&"morale"]) + morale_delta, 0, 100)
	var notice_event: StringName = &""
	if int(state[&"notice_day"]) > 0 and int(state[&"morale"]) >= REMEDY_THRESHOLD:
		state[&"notice_day"] = 0
		if str(state[&"status"]) == "notice":
			state[&"status"] = "active"
		reasons.append(NOTICE_REMEDIED)
		notice_event = NOTICE_REMEDIED
	elif int(state[&"notice_day"]) == 0 and int(state[&"morale"]) <= NOTICE_THRESHOLD:
		state[&"notice_day"] = absolute_day
		if str(state[&"status"]) != "recovering":
			state[&"status"] = "notice"
		reasons.append(NOTICE_OPENED)
		notice_event = NOTICE_OPENED
	var departed: bool = (
		int(state[&"notice_day"]) > 0
		and absolute_day >= int(state[&"notice_day"]) + NOTICE_REMEDY_DAYS
		and int(state[&"morale"]) < REMEDY_THRESHOLD
		and int(state[&"injured_until_day"]) <= absolute_day
	)
	if departed:
		reasons.append(DEPARTED)
		notice_event = DEPARTED
	state[&"last_reason_ids"] = _string_reasons(reasons)
	return {
		&"settler": state,
		&"departed": departed,
		&"summary": {
			&"settler_id": str(settler_id), &"morale": int(state[&"morale"]),
			&"delta": morale_delta, &"reasons": state[&"last_reason_ids"],
			&"status": str(state[&"status"]), &"injured": injured,
			&"notice_event": str(notice_event), &"departed": departed,
		},
	}


static func _apply_concerns(
	workforce: Dictionary,
	summaries: Array[Dictionary],
	departed_ids: Array[String],
	absolute_day: int,
) -> Dictionary:
	var existing: Dictionary = {}
	for concern: Dictionary in workforce[&"concerns"] as Array[Dictionary]:
		existing[str(concern[&"settler_id"])] = concern
	var concerns: Array[Dictionary] = []
	for summary: Dictionary in summaries:
		var settler_id: String = str(summary[&"settler_id"])
		if settler_id in departed_ids:
			continue
		var reason_id: StringName = _primary_concern(summary[&"reasons"] as Array)
		if reason_id == &"":
			continue
		var previous: Dictionary = existing.get(settler_id, {}) as Dictionary
		var opened_day: int = absolute_day
		if str(previous.get(&"reason_id", "")) == str(reason_id):
			opened_day = int(previous[&"opened_day"])
		concerns.append(
			{
				&"concern_id": "concern.%s" % settler_id,
				&"settler_id": settler_id,
				&"reason_id": str(reason_id),
				&"opened_day": opened_day,
			}
		)
	workforce[&"concerns"] = concerns
	return workforce


static func _remove_departed_links(
	workforce: Dictionary, departed_ids: Array[String]
) -> Dictionary:
	if departed_ids.is_empty():
		return workforce
	for key: StringName in [&"housing_assignments", &"work_assignments", &"shift_reports"]:
		var retained: Array[Dictionary] = []
		for record: Dictionary in workforce[key] as Array[Dictionary]:
			if str(record.get(&"settler_id", "")) not in departed_ids:
				retained.append(record.duplicate(true))
		workforce[key] = retained
	var history: Array[String] = (workforce[&"departed_settler_ids"] as Array).duplicate()
	for settler_id: String in departed_ids:
		if settler_id not in history:
			history.append(settler_id)
	history.sort()
	workforce[&"departed_settler_ids"] = history
	return workforce


static func _primary_concern(reasons: Array) -> StringName:
	for reason_id: StringName in NEGATIVE_PRIORITY:
		if str(reason_id) in reasons:
			return reason_id
	return &""


static func _shift_report(
	farm: Dictionary, settler_id: StringName, absolute_day: int
) -> Dictionary:
	for report: Dictionary in _workforce(farm)[&"shift_reports"] as Array[Dictionary]:
		if (
			str(report[&"settler_id"]) == str(settler_id)
			and int(report[&"absolute_day"]) == absolute_day
		):
			return report.duplicate(true)
	return {}


static func _clinic_available(farm: Dictionary) -> bool:
	return &"service.clinic" in ResidentScript.active_services(farm, ResidentScript.MIRA_ID)


static func _consume_equitable_food(farm: Dictionary, population: int) -> bool:
	return population == 0 or InventoryScript.count_all(farm, FOOD_ID) >= population


static func _canonical_reasons(reasons: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for reason_id: StringName in reasons:
		if reason_id not in result:
			result.append(reason_id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return result


static func _string_reasons(reasons: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for reason_id: StringName in _canonical_reasons(reasons):
		result.append(str(reason_id))
	return result


static func _workforce(farm: Dictionary) -> Dictionary:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	return (homestead.get(&"workforce", {}) as Dictionary).duplicate(true)


static func _result(
	ok: bool,
	candidate: Dictionary,
	reason: StringName,
	summaries: Array,
	replayed: bool,
) -> Dictionary:
	return {
		&"ok": ok, &"candidate": candidate.duplicate(true), &"reason": reason,
		&"summaries": summaries.duplicate(true), &"replayed": replayed,
	}
