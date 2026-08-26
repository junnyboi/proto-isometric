extends RefCounted

const CalendarScript: GDScript = preload("res://scripts/calendar_state.gd")
const HousingScript: GDScript = preload("res://scripts/housing_protection_service.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")
const SettlerCatalogScript: GDScript = preload("res://scripts/settler_catalog.gd")

const OFFER_INTERVAL_DAYS: int = 7
const OFFER_DURATION_DAYS: int = 3
const MAX_DEFERRALS: int = 2
const INITIAL_MORALE: int = 80


static func current_offer(farm: Dictionary) -> Dictionary:
	var lifecycle: Dictionary = lifecycle_state(farm)
	var settler_id: StringName = StringName(str(lifecycle.get(&"current_applicant_id", "")))
	if settler_id == &"":
		return {}
	var definition: Dictionary = SettlerCatalogScript.definition(settler_id)
	if definition.is_empty():
		return {}
	definition[&"offered_day"] = int(lifecycle[&"offered_day"])
	definition[&"expires_day"] = int(lifecycle[&"expires_day"])
	definition[&"deferred_until_day"] = int(lifecycle[&"deferred_until_day"])
	definition[&"deferrals"] = int(lifecycle[&"deferrals"])
	definition[&"sequence"] = int(lifecycle[&"sequence"])
	return definition


static func lifecycle_state(farm: Dictionary) -> Dictionary:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var workforce: Dictionary = homestead.get(&"workforce", {}) as Dictionary
	return (workforce.get(&"applicant_lifecycle", {}) as Dictionary).duplicate(true)


static func advance_dawn(farm: Dictionary, world_seed: int, absolute_day: int) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var lifecycle: Dictionary = lifecycle_state(source)
	if lifecycle.is_empty() or absolute_day < 1:
		return _result(false, source, &"invalid_applicant_lifecycle")
	var event: StringName = &"none"
	if not str(lifecycle[&"current_applicant_id"]).is_empty():
		if absolute_day >= int(lifecycle[&"expires_day"]):
			_clear_offer(lifecycle)
			event = &"expired"
		else:
			return _result_with_event(true, source, &"", event)
	if absolute_day < int(lifecycle[&"next_offer_day"]):
		return _write_lifecycle(source, lifecycle, event)
	while int(lifecycle[&"next_offer_day"]) <= absolute_day:
		lifecycle[&"next_offer_day"] = int(lifecycle[&"next_offer_day"]) + OFFER_INTERVAL_DAYS
	if not HousingScript.safehouse_ready(source) or HousingScript.available_beds(source).is_empty():
		return _write_lifecycle(source, lifecycle, event)
	var excluded: Array[StringName] = []
	for settler: Dictionary in _workforce(source)[&"settlers"] as Array[Dictionary]:
		excluded.append(StringName(str(settler[&"settler_id"])))
	var sequence: int = int(lifecycle[&"sequence"]) + 1
	var applicant_id: StringName = SettlerCatalogScript.deterministic_offer_id(
		world_seed, absolute_day, sequence, excluded
	)
	if applicant_id == &"":
		return _write_lifecycle(source, lifecycle, event)
	lifecycle[&"current_applicant_id"] = str(applicant_id)
	lifecycle[&"offered_day"] = absolute_day
	lifecycle[&"expires_day"] = absolute_day + OFFER_DURATION_DAYS
	lifecycle[&"deferred_until_day"] = 0
	lifecycle[&"sequence"] = sequence
	lifecycle[&"deferrals"] = 0
	return _write_lifecycle(source, lifecycle, &"generated")


static func decide(
	farm: Dictionary,
	action: StringName,
	expected_applicant_id: StringName = &"",
	expected_sequence: int = -1,
) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var lifecycle: Dictionary = lifecycle_state(source)
	var applicant_id: StringName = StringName(str(lifecycle.get(&"current_applicant_id", "")))
	if applicant_id == &"" or SettlerCatalogScript.definition(applicant_id).is_empty():
		return _result(false, source, &"applicant_offer_missing")
	if expected_applicant_id != &"" and applicant_id != expected_applicant_id:
		return _result(false, source, &"applicant_offer_stale")
	if expected_sequence >= 0 and int(lifecycle[&"sequence"]) != expected_sequence:
		return _result(false, source, &"applicant_offer_stale")
	var day: int = CalendarScript.absolute_day(source[&"calendar_weather"])
	if day >= int(lifecycle[&"expires_day"]):
		return _result(false, source, &"applicant_offer_expired")
	if day < int(lifecycle[&"deferred_until_day"]):
		return _result(false, source, &"applicant_offer_deferred")
	match action:
		&"invite":
			return _invite(source, lifecycle, applicant_id, day)
		&"decline":
			_clear_offer(lifecycle)
			lifecycle[&"next_offer_day"] = maxi(
				int(lifecycle[&"next_offer_day"]), day + OFFER_INTERVAL_DAYS
			)
			return _write_lifecycle(source, lifecycle, &"declined")
		&"defer":
			if int(lifecycle[&"deferrals"]) >= MAX_DEFERRALS:
				return _result(false, source, &"applicant_defer_limit")
			if day + 1 >= int(lifecycle[&"expires_day"]):
				return _result(false, source, &"applicant_defer_too_late")
			lifecycle[&"deferred_until_day"] = day + 1
			lifecycle[&"deferrals"] = int(lifecycle[&"deferrals"]) + 1
			return _write_lifecycle(source, lifecycle, &"deferred")
	return _result(false, source, &"unknown_applicant_decision")


static func deterministic_result(farm: Dictionary, action: StringName) -> Dictionary:
	var lifecycle: Dictionary = lifecycle_state(farm)
	var applicant_id: String = str(lifecycle.get(&"current_applicant_id", ""))
	var result: Dictionary = {
		&"action": str(action),
		&"applicant_id": applicant_id,
		&"offer_sequence": int(lifecycle.get(&"sequence", 0)),
	}
	if action == &"invite":
		var bed: Dictionary = HousingScript.first_available_bed(farm)
		result[&"bed_id"] = str(bed.get(&"bed_id", ""))
	return result


static func _invite(
	source: Dictionary,
	lifecycle: Dictionary,
	applicant_id: StringName,
	day: int,
) -> Dictionary:
	var workforce: Dictionary = _workforce(source)
	if (workforce[&"settlers"] as Array).size() >= SectionsScript.MAX_SETTLERS:
		return _result(false, source, &"settler_cap_reached")
	for settler: Dictionary in workforce[&"settlers"] as Array[Dictionary]:
		if str(settler[&"settler_id"]) == str(applicant_id):
			return _result(false, source, &"settler_already_present")
	var bed: Dictionary = HousingScript.first_available_bed(source)
	if bed.is_empty():
		return _result(false, source, &"protected_bed_unavailable")
	var settlers: Array = (workforce[&"settlers"] as Array).duplicate(true)
	settlers.append(
		{
			&"settler_id": str(applicant_id),
			&"status": "active",
			&"morale": INITIAL_MORALE,
			&"injured_until_day": 0,
		}
	)
	var housing: Array = (workforce[&"housing_assignments"] as Array).duplicate(true)
	housing.append({&"settler_id": str(applicant_id), &"bed_id": str(bed[&"bed_id"])})
	workforce[&"settlers"] = settlers
	workforce[&"housing_assignments"] = housing
	_clear_offer(lifecycle)
	lifecycle[&"next_offer_day"] = maxi(
		int(lifecycle[&"next_offer_day"]), day + OFFER_INTERVAL_DAYS
	)
	workforce[&"applicant_lifecycle"] = lifecycle
	return _write_workforce(source, workforce, &"invited")


static func _write_lifecycle(
	farm: Dictionary, lifecycle: Dictionary, event: StringName
) -> Dictionary:
	var workforce: Dictionary = _workforce(farm)
	workforce[&"applicant_lifecycle"] = lifecycle
	return _write_workforce(farm, workforce, event)


static func _write_workforce(
	farm: Dictionary, workforce: Dictionary, event: StringName
) -> Dictionary:
	var normalized: Dictionary = SectionsScript.validate_workforce(workforce)
	if normalized.is_empty():
		return _result(false, farm, &"invalid_workforce_candidate")
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	homestead[&"workforce"] = normalized
	candidate[&"homestead"] = homestead
	return _result_with_event(true, candidate, &"", event)


static func _workforce(farm: Dictionary) -> Dictionary:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	return (homestead.get(&"workforce", {}) as Dictionary).duplicate(true)


static func _clear_offer(lifecycle: Dictionary) -> void:
	lifecycle[&"current_applicant_id"] = ""
	lifecycle[&"offered_day"] = 0
	lifecycle[&"expires_day"] = 0
	lifecycle[&"deferred_until_day"] = 0
	lifecycle[&"deferrals"] = 0


static func _result(
	ok: bool, candidate: Dictionary, reason: StringName
) -> Dictionary:
	return _result_with_event(ok, candidate, reason, &"none")


static func _result_with_event(
	ok: bool, candidate: Dictionary, reason: StringName, event: StringName
) -> Dictionary:
	return {
		&"ok": ok,
		&"candidate": candidate.duplicate(true),
		&"reason": reason,
		&"applicant_event": event,
	}
