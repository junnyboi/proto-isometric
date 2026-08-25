extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const LYRA_ID: StringName = RuntimeIdsScript.RESIDENT_LYRA_ID
const ROOK_ID: StringName = RuntimeIdsScript.RESIDENT_ROOK_ID
const MIRA_ID: StringName = RuntimeIdsScript.RESIDENT_MIRA_ID
const RESIDENT_IDS: Array[StringName] = [LYRA_ID, ROOK_ID, MIRA_ID]
const MAX_TOPICS_PER_RESIDENT: int = 4
const MAX_SERVICES_PER_RESIDENT: int = 4
const SCHEDULE_SLOTS: int = 4
const DEFINITIONS: Array[Dictionary] = [
	{
		&"resident_id": LYRA_ID,
		&"display_name": "Lyra",
		&"role_id": &"role.agronomist",
		&"facility_id": HomesteadServiceScript.GREENHOUSE_ID,
		&"arrival_day": 1,
		&"fallback_cells": [Vector2i(2, 11), Vector2i(3, 12)],
		&"clear_schedule": [
			Vector2i(2, 10), Vector2i(10, 9), Vector2i(6, 9), Vector2i(3, 11)
		],
		&"rain_schedule": [
			Vector2i(2, 10), Vector2i(2, 9), Vector2i(6, 8), Vector2i(3, 11)
		],
		&"topic_ids": [&"dialogue.lyra.arrival", &"dialogue.lyra.crops", &"dialogue.lyra.rain"],
		&"service_ids": [&"service.seed_shop", &"service.soil_advice"],
	},
	{
		&"resident_id": ROOK_ID,
		&"display_name": "Rook",
		&"role_id": &"role.mechanic",
		&"facility_id": HomesteadServiceScript.WORKSHOP_ID,
		&"arrival_day": 2,
		&"fallback_cells": [Vector2i(14, 9), Vector2i(13, 10)],
		&"clear_schedule": [
			Vector2i(14, 8), Vector2i(13, 8), Vector2i(7, 10), Vector2i(14, 9)
		],
		&"rain_schedule": [
			Vector2i(14, 8), Vector2i(13, 8), Vector2i(7, 9), Vector2i(14, 9)
		],
		&"topic_ids": [&"dialogue.rook.arrival", &"dialogue.rook.tools", &"dialogue.rook.power"],
		&"service_ids": [&"service.construction", &"service.tool_upgrade"],
	},
	{
		&"resident_id": MIRA_ID,
		&"display_name": "Mira",
		&"role_id": &"role.medic_cook",
		&"facility_id": HomesteadServiceScript.CLINIC_ID,
		&"arrival_day": 3,
		&"fallback_cells": [Vector2i(5, 14), Vector2i(6, 13)],
		&"clear_schedule": [
			Vector2i(5, 14), Vector2i(6, 12), Vector2i(4, 10), Vector2i(6, 14)
		],
		&"rain_schedule": [
			Vector2i(5, 14), Vector2i(6, 12), Vector2i(4, 11), Vector2i(6, 14)
		],
		&"topic_ids": [&"dialogue.mira.arrival", &"dialogue.mira.clinic", &"dialogue.mira.kitchen"],
		&"service_ids": [&"service.clinic", &"service.kitchen"],
	},
]


static func ensure_default(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate.get(&"homestead", {}) as Dictionary
	if not homestead.has(&"home") or not (homestead.get(&"residents", []) as Array).is_empty():
		return candidate
	var residents: Array[Dictionary] = []
	for definition_value: Dictionary in DEFINITIONS:
		residents.append(
			{
				&"resident_id": String(definition_value[&"resident_id"]),
				&"facility_id": String(definition_value[&"facility_id"]),
				&"arrived": false,
				&"arrival_day": 0,
			}
		)
	residents.sort_custom(_id_precedes.bind(&"resident_id"))
	homestead[&"residents"] = residents
	candidate[&"homestead"] = homestead
	return candidate


static func validate_definitions() -> bool:
	var residents: Dictionary = {}
	var facilities: Dictionary = {}
	for definition_value: Dictionary in DEFINITIONS:
		if not _definition_is_valid(definition_value):
			return false
		var resident_id: StringName = definition_value[&"resident_id"] as StringName
		var facility_id: StringName = definition_value[&"facility_id"] as StringName
		if residents.has(resident_id) or facilities.has(facility_id):
			return false
		residents[resident_id] = true
		facilities[facility_id] = true
	return residents.size() == 3 and facilities.size() == 3


static func definition(resident_id: StringName) -> Dictionary:
	for definition_value: Dictionary in DEFINITIONS:
		if definition_value[&"resident_id"] == resident_id:
			return definition_value.duplicate(true)
	return {}


static func state(farm: Dictionary, resident_id: StringName) -> Dictionary:
	var found: Dictionary = {}
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	for record: Dictionary in homestead.get(&"residents", []) as Array[Dictionary]:
		if StringName(record.get(&"resident_id", "")) != resident_id:
			continue
		if not found.is_empty():
			return {}
		found = record.duplicate(true)
	return found


static func reconcile_arrivals(farm: Dictionary) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = source.get(&"homestead", {}) as Dictionary
	if not homestead.has(&"home"):
		return _result(false, source, &"homestead_inactive")
	var residents: Array = (homestead.get(&"residents", []) as Array).duplicate(true)
	if not _records_are_complete(residents):
		return _result(false, source, &"invalid_resident_records")
	var day: int = CalendarStateScript.absolute_day(source[&"calendar_weather"])
	var changed: bool = false
	for index: int in residents.size():
		var record: Dictionary = residents[index] as Dictionary
		if bool(record[&"arrived"]):
			continue
		var definition_value: Dictionary = definition(StringName(record[&"resident_id"]))
		var facility: Dictionary = HomesteadServiceScript.facility_state(
			source, definition_value[&"facility_id"] as StringName
		)
		if (
			day >= int(definition_value[&"arrival_day"])
			and bool(facility.get(&"repaired", false))
			and bool(facility.get(&"powered", false))
		):
			record[&"arrived"] = true
			record[&"arrival_day"] = day
			residents[index] = record
			changed = true
	homestead[&"residents"] = residents
	var candidate: Dictionary = source.duplicate(true)
	candidate[&"homestead"] = homestead
	return _result(changed, candidate, &"" if changed else &"no_arrivals")


static func schedule_snapshot(
	farm: Dictionary, minute_of_day: int, walkable: Callable = Callable()
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var occupied: Dictionary = {}
	for resident_id: StringName in RESIDENT_IDS:
		var record: Dictionary = state(farm, resident_id)
		if record.is_empty() or not bool(record[&"arrived"]):
			continue
		var definition_value: Dictionary = definition(resident_id)
		var cell: Vector2i = _schedule_cell(farm, definition_value, minute_of_day)
		if not _cell_available(cell, occupied, walkable):
			cell = _fallback_cell(definition_value, occupied, walkable)
		if cell == Vector2i.MAX:
			continue
		occupied[cell] = true
		result.append({&"resident_id": resident_id, &"cell": cell})
	return result.duplicate(true)


static func topic_ids(resident_id: StringName) -> Array[StringName]:
	var definition_value: Dictionary = definition(resident_id)
	var result: Array[StringName] = []
	for topic_id: StringName in definition_value.get(&"topic_ids", []) as Array[StringName]:
		if result.size() >= MAX_TOPICS_PER_RESIDENT:
			break
		result.append(topic_id)
	return result.duplicate()


static func active_services(farm: Dictionary, resident_id: StringName) -> Array[StringName]:
	var record: Dictionary = state(farm, resident_id)
	if record.is_empty() or not bool(record[&"arrived"]):
		return []
	var definition_value: Dictionary = definition(resident_id)
	var facility: Dictionary = HomesteadServiceScript.facility_state(
		farm, definition_value[&"facility_id"] as StringName
	)
	if not bool(facility.get(&"repaired", false)) or not bool(facility.get(&"powered", false)):
		return []
	var result: Array[StringName] = []
	for service_id: StringName in definition_value[&"service_ids"] as Array[StringName]:
		if result.size() >= MAX_SERVICES_PER_RESIDENT:
			break
		result.append(service_id)
	result.sort_custom(_name_precedes)
	return result.duplicate()


static func _definition_is_valid(definition_value: Dictionary) -> bool:
	if not _exact_keys(
		definition_value,
		[
			&"resident_id",
			&"display_name",
			&"role_id",
			&"facility_id",
			&"arrival_day",
			&"fallback_cells",
			&"clear_schedule",
			&"rain_schedule",
			&"topic_ids",
			&"service_ids",
		],
	):
		return false
	if (
		definition_value[&"resident_id"] not in RESIDENT_IDS
		or definition_value[&"facility_id"] not in HomesteadServiceScript.FACILITY_IDS
		or not definition_value[&"display_name"] is String
		or not _stable_id(definition_value[&"role_id"], "role.")
		or not definition_value[&"arrival_day"] is int
		or int(definition_value[&"arrival_day"]) < 1
		or int(definition_value[&"arrival_day"]) > 14
		or not _cells_are_valid(definition_value[&"fallback_cells"], 1, 4)
		or not _cells_are_valid(definition_value[&"clear_schedule"], SCHEDULE_SLOTS, SCHEDULE_SLOTS)
		or not _cells_are_valid(definition_value[&"rain_schedule"], SCHEDULE_SLOTS, SCHEDULE_SLOTS)
		or not _ids_are_valid(definition_value[&"topic_ids"], "dialogue.", MAX_TOPICS_PER_RESIDENT)
		or not _ids_are_valid(
			definition_value[&"service_ids"], "service.", MAX_SERVICES_PER_RESIDENT
		)
	):
		return false
	return true


static func _records_are_complete(records: Array) -> bool:
	if records.size() != RESIDENT_IDS.size():
		return false
	var seen: Dictionary = {}
	for record: Variant in records:
		if not record is Dictionary:
			return false
		var resident_id: StringName = StringName(str((record as Dictionary).get(&"resident_id", "")))
		if resident_id not in RESIDENT_IDS or seen.has(resident_id):
			return false
		seen[resident_id] = true
	return true


static func _schedule_cell(
	farm: Dictionary, definition_value: Dictionary, minute_of_day: int
) -> Vector2i:
	var minute: int = clampi(minute_of_day, 0, 1_439)
	var index: int = 0
	if minute >= 600:
		index = 1
	if minute >= 1_020:
		index = 2
	if minute >= 1_260:
		index = 3
	var calendar: Dictionary = farm.get(&"calendar_weather", {}) as Dictionary
	var weather: StringName = StringName(str(calendar.get(&"current_weather_id", "")))
	var key: StringName = &"rain_schedule" if weather == &"weather.rain" else &"clear_schedule"
	return (definition_value[key] as Array[Vector2i])[index]


static func _fallback_cell(
	definition_value: Dictionary, occupied: Dictionary, walkable: Callable
) -> Vector2i:
	for cell: Vector2i in definition_value[&"fallback_cells"] as Array[Vector2i]:
		if _cell_available(cell, occupied, walkable):
			return cell
	return Vector2i.MAX


static func _cell_available(cell: Vector2i, occupied: Dictionary, walkable: Callable) -> bool:
	return not occupied.has(cell) and (not walkable.is_valid() or bool(walkable.call(cell)))


static func _cells_are_valid(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is Array or (value as Array).size() < minimum or (value as Array).size() > maximum:
		return false
	var seen: Dictionary = {}
	for cell: Variant in value:
		if not cell is Vector2i or seen.has(cell):
			return false
		seen[cell] = true
	return true


static func _ids_are_valid(value: Variant, prefix: String, maximum: int) -> bool:
	if not value is Array or (value as Array).is_empty() or (value as Array).size() > maximum:
		return false
	var seen: Dictionary = {}
	for identifier: Variant in value:
		if not _stable_id(identifier, prefix) or seen.has(identifier):
			return false
		seen[identifier] = true
	return true


static func _stable_id(value: Variant, prefix: String) -> bool:
	return (
		(value is String or value is StringName)
		and str(value).begins_with(prefix)
		and str(value).length() <= 64
	)


static func _name_precedes(first: StringName, second: StringName) -> bool:
	return String(first) < String(second)


static func _id_precedes(first: Dictionary, second: Dictionary, key: StringName) -> bool:
	return str(first[key]) < str(second[key])


static func _exact_keys(value: Dictionary, expected: Array[StringName]) -> bool:
	if value.size() != expected.size():
		return false
	for key: StringName in expected:
		if not value.has(key):
			return false
	return true


static func _result(ok: bool, candidate: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": candidate.duplicate(true), &"reason": reason}
