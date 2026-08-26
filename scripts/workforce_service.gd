extends RefCounted

const BlueprintCatalogScript: GDScript = preload(
	"res://scripts/construction_blueprint_catalog.gd"
)
const CalendarScript: GDScript = preload("res://scripts/calendar_state.gd")
const ConstructionStateScript: GDScript = preload("res://scripts/construction_state_service.gd")
const HousingScript: GDScript = preload("res://scripts/housing_protection_service.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")
const SettlerCatalogScript: GDScript = preload("res://scripts/settler_catalog.gd")

const SHIFT_DAY: int = 0
const SHIFT_EVENING: int = 1
const SHIFTS: Array[int] = [SHIFT_DAY, SHIFT_EVENING]


static func assignment_for(farm: Dictionary, settler_id: StringName) -> Dictionary:
	for assignment: Dictionary in _workforce(farm)[&"work_assignments"] as Array[Dictionary]:
		if str(assignment[&"settler_id"]) == str(settler_id):
			return assignment.duplicate(true)
	return {}


static func availability(farm: Dictionary, settler_id: StringName) -> Dictionary:
	var settler: Dictionary = _settler(farm, settler_id)
	if settler.is_empty():
		return {&"available": false, &"reason": &"settler_missing"}
	var day: int = CalendarScript.absolute_day(farm[&"calendar_weather"])
	if settler[&"status"] == "recovering":
		return {&"available": false, &"reason": &"settler_recovering"}
	if settler[&"status"] != "active":
		return {&"available": false, &"reason": &"settler_unavailable"}
	if int(settler[&"injured_until_day"]) > day:
		return {&"available": false, &"reason": &"settler_recovering"}
	if not HousingScript.assignment_is_protected(farm, settler_id):
		return {&"available": false, &"reason": &"protected_bed_missing"}
	return {&"available": true, &"reason": &""}


static func assign(
	farm: Dictionary,
	settler_id: StringName,
	site_id: StringName,
	slot: int,
	shift: int,
) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var state: Dictionary = availability(source, settler_id)
	if not bool(state[&"available"]):
		return _result(false, source, state[&"reason"] as StringName)
	if shift not in SHIFTS:
		return _result(false, source, &"invalid_shift")
	var building: Dictionary = ConstructionStateScript.building(source, site_id)
	if building.is_empty():
		return _result(false, source, &"work_site_missing")
	if str(building[&"state"]) != "complete":
		return _result(false, source, &"work_site_incomplete")
	var blueprint_id: StringName = StringName(str(building[&"blueprint_id"]))
	var slot_types: Array[StringName] = BlueprintCatalogScript.work_slot_types(blueprint_id)
	if slot < 0 or slot >= slot_types.size():
		return _result(false, source, &"work_slot_missing")
	var workforce: Dictionary = _workforce(source)
	var assignments: Array[Dictionary] = []
	for current: Dictionary in workforce[&"work_assignments"] as Array[Dictionary]:
		if str(current[&"settler_id"]) == str(settler_id):
			continue
		if (
			str(current[&"site_id"]) == str(site_id)
			and int(current[&"slot"]) == slot
			and int(current[&"shift"]) == shift
		):
			return _result(false, source, &"work_slot_occupied")
		assignments.append(current.duplicate(true))
	assignments.append(
		{
			&"settler_id": str(settler_id),
			&"site_id": str(site_id),
			&"slot": slot,
			&"shift": shift,
		}
	)
	workforce[&"work_assignments"] = assignments
	workforce[&"shift_reports"] = _reports_without(
		workforce, str(settler_id), str(site_id)
	)
	return _write_workforce(source, workforce)


static func unassign(farm: Dictionary, settler_id: StringName) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var workforce: Dictionary = _workforce(source)
	var assignments: Array[Dictionary] = []
	var found: bool = false
	for current: Dictionary in workforce[&"work_assignments"] as Array[Dictionary]:
		if str(current[&"settler_id"]) == str(settler_id):
			found = true
			continue
		assignments.append(current.duplicate(true))
	if not found:
		return _result(false, source, &"work_assignment_missing")
	workforce[&"work_assignments"] = assignments
	workforce[&"shift_reports"] = _reports_without(workforce, str(settler_id), "")
	return _write_workforce(source, workforce)


static func site_snapshots(farm: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var construction: Dictionary = homestead.get(&"construction", {}) as Dictionary
	for building: Dictionary in construction.get(&"buildings", []) as Array[Dictionary]:
		if str(building.get(&"state", "")) != "complete":
			continue
		var blueprint_id: StringName = StringName(str(building[&"blueprint_id"]))
		var slot_types: Array[StringName] = BlueprintCatalogScript.work_slot_types(blueprint_id)
		if slot_types.is_empty():
			continue
		result.append(
			{
				&"site_id": str(building[&"instance_id"]),
				&"blueprint_id": str(blueprint_id),
					&"slot_types": slot_types,
					&"level": int(building[&"level"]),
					&"local_stacks": (building[&"local_stacks"] as Array).duplicate(true),
				}
		)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"site_id"]) < str(b[&"site_id"])
	)
	return result


static func roster(farm: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var workforce: Dictionary = _workforce(farm)
	for settler: Dictionary in workforce[&"settlers"] as Array[Dictionary]:
		var settler_id: StringName = StringName(str(settler[&"settler_id"]))
		var definition: Dictionary = SettlerCatalogScript.definition(settler_id)
		if definition.is_empty():
			continue
		var record: Dictionary = definition
		record[&"state"] = settler.duplicate(true)
		record[&"housing"] = _housing_for(workforce, settler_id)
		record[&"assignment"] = assignment_for(farm, settler_id)
		record[&"availability"] = availability(farm, settler_id)
		result.append(record)
	return result


static func preference_matches(
	settler_id: StringName, blueprint_id: StringName, slot: int
) -> bool:
	var definition: Dictionary = SettlerCatalogScript.definition(settler_id)
	var slots: Array[StringName] = BlueprintCatalogScript.work_slot_types(blueprint_id)
	if definition.is_empty() or slot < 0 or slot >= slots.size():
		return false
	return slots[slot] in (definition[&"preferred_job_types"] as Array)


static func _write_workforce(farm: Dictionary, workforce: Dictionary) -> Dictionary:
	var normalized: Dictionary = SectionsScript.validate_workforce(workforce)
	if normalized.is_empty():
		return _result(false, farm, &"invalid_workforce_candidate")
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	homestead[&"workforce"] = normalized
	candidate[&"homestead"] = homestead
	return _result(true, candidate, &"")


static func _settler(farm: Dictionary, settler_id: StringName) -> Dictionary:
	for candidate: Dictionary in _workforce(farm)[&"settlers"] as Array[Dictionary]:
		if str(candidate[&"settler_id"]) == str(settler_id):
			return candidate.duplicate(true)
	return {}


static func _housing_for(workforce: Dictionary, settler_id: StringName) -> Dictionary:
	for assignment: Dictionary in workforce[&"housing_assignments"] as Array[Dictionary]:
		if str(assignment[&"settler_id"]) == str(settler_id):
			return assignment.duplicate(true)
	return {}


static func _workforce(farm: Dictionary) -> Dictionary:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	return (homestead.get(&"workforce", {}) as Dictionary).duplicate(true)


static func _reports_without(
	workforce: Dictionary, settler_id: String, site_id: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for report: Dictionary in workforce.get(&"shift_reports", []) as Array[Dictionary]:
		if str(report[&"settler_id"]) == settler_id:
			continue
		if not site_id.is_empty() and str(report[&"site_id"]) == site_id:
			continue
		result.append(report.duplicate(true))
	return result


static func _result(
	ok: bool, candidate: Dictionary, reason: StringName
) -> Dictionary:
	return {&"ok": ok, &"candidate": candidate.duplicate(true), &"reason": reason}
