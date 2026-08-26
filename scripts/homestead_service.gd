extends RefCounted

const DurableUpgradeCatalogScript: GDScript = preload("res://scripts/durable_upgrade_catalog.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const HOME_ID: StringName = RuntimeIdsScript.FACILITY_HOME_ID
const HOME_CELL: Vector2i = Vector2i(8, 4)
const HOME_CAPACITY: int = 3
const SAFEHOUSE_POWER_UPGRADE: StringName = &"upgrade.safehouse.power_capacity"
const GREENHOUSE_ID: StringName = RuntimeIdsScript.FACILITY_GREENHOUSE_ID
const WORKSHOP_ID: StringName = RuntimeIdsScript.FACILITY_WORKSHOP_ID
const CLINIC_ID: StringName = RuntimeIdsScript.FACILITY_CLINIC_ID
const FACILITY_IDS: Array[StringName] = [GREENHOUSE_ID, WORKSHOP_ID, CLINIC_ID]
const HOME_SERVICE_IDS: Array[StringName] = [
	&"service.home.bed", &"service.home.safehouse", &"service.home.storage"
]
const MAX_SERVICE_IDS: int = 4
const DEFINITIONS: Array[Dictionary] = [
	{
		&"facility_id": GREENHOUSE_ID,
		&"ruin_id": &"ruin.facility.greenhouse",
		&"cell": Vector2i(1, 10),
		&"ruin_kind": &"ancient_temple",
		&"repair_materials": {&"item.material.wood": 4, &"item.material.stone": 2},
		&"power_materials": {&"item.part.irrigation_coil": 1},
		&"power_prerequisite": SAFEHOUSE_POWER_UPGRADE,
		&"service_ids": [&"service.greenhouse", &"service.seed_shop"],
	},
	{
		&"facility_id": WORKSHOP_ID,
		&"ruin_id": &"ruin.facility.workshop",
		&"cell": Vector2i(15, 8),
		&"ruin_kind": &"ancient_ziggurat",
		&"repair_materials": {&"item.material.wood": 6, &"item.material.scrap": 2},
		&"power_materials": {&"item.part.iron_ingot": 1},
		&"power_prerequisite": SAFEHOUSE_POWER_UPGRADE,
		&"service_ids": [&"service.construction", &"service.tool_upgrade"],
	},
	{
		&"facility_id": CLINIC_ID,
		&"ruin_id": &"ruin.facility.clinic_kitchen",
		&"cell": Vector2i(5, 15),
		&"ruin_kind": &"ancient_palace",
		&"repair_materials": {&"item.material.wood": 4, &"item.material.stone": 4},
		&"power_materials": {&"item.material.scrap": 2},
		&"power_prerequisite": SAFEHOUSE_POWER_UPGRADE,
		&"service_ids": [&"service.clinic", &"service.kitchen"],
	},
]


static func ensure_default(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	if StringName(str(candidate.get(&"mode", ""))) != RuntimeIdsScript.MODE_FRESH_FARM:
		return candidate
	var homestead: Dictionary = candidate.get(&"homestead", {}) as Dictionary
	if homestead.has(&"home"):
		return candidate
	var facilities: Array[Dictionary] = []
	var ruins: Array[Dictionary] = [_home_ruin()]
	for definition_value: Dictionary in DEFINITIONS:
		facilities.append(_facility_record(definition_value))
		ruins.append(_ruin_record(definition_value))
	facilities.sort_custom(_id_precedes.bind(&"facility_id"))
	ruins.sort_custom(_id_precedes.bind(&"ruin_id"))
	var construction: Dictionary = homestead[&"construction"] as Dictionary
	var workforce: Dictionary = homestead[&"workforce"] as Dictionary
	candidate[&"homestead"] = {
		&"state_version": 2,
		&"home": {
			&"home_id": String(HOME_ID),
			&"cell": [HOME_CELL.x, HOME_CELL.y],
			&"repaired": true,
			&"powered": true,
			&"bed_enabled": true,
			&"storage_enabled": true,
			&"animal_capacity": HOME_CAPACITY,
		},
		&"facilities": facilities,
		&"residents": [],
		&"relationships": [],
		&"requests": [],
		&"animals": [],
		&"ruins": ruins,
		&"construction": construction.duplicate(true),
		&"workforce": workforce.duplicate(true),
	}
	return candidate


static func reconcile(farm: Dictionary) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = source.get(&"homestead", {}) as Dictionary
	if not homestead.has(&"home"):
		return _result(true, source, &"")
	if not _records_are_complete(source):
		return _result(false, source, &"invalid_homestead_records")
	var candidate: Dictionary = source.duplicate(true)
	for facility_id: StringName in FACILITY_IDS:
		_sync_ruin(candidate, facility_id)
	_sync_home_ruin(candidate)
	return _result(true, candidate, &"")


static func validate_definitions() -> bool:
	var facilities: Dictionary = {}
	var ruins: Dictionary = {}
	var cells: Dictionary = {}
	for definition_value: Dictionary in DEFINITIONS:
		if not _definition_is_valid(definition_value):
			return false
		var facility_id: StringName = definition_value[&"facility_id"] as StringName
		var ruin_id: StringName = definition_value[&"ruin_id"] as StringName
		var cell: Vector2i = definition_value[&"cell"] as Vector2i
		if facilities.has(facility_id) or ruins.has(ruin_id) or cells.has(cell):
			return false
		facilities[facility_id] = true
		ruins[ruin_id] = true
		cells[cell] = true
	return facilities.size() == FACILITY_IDS.size()


static func definition(facility_id: StringName) -> Dictionary:
	for definition_value: Dictionary in DEFINITIONS:
		if definition_value[&"facility_id"] == facility_id:
			return definition_value.duplicate(true)
	return {}


static func facility_state(farm: Dictionary, facility_id: StringName) -> Dictionary:
	var found: Dictionary = {}
	for record: Dictionary in _homestead(farm).get(&"facilities", []) as Array[Dictionary]:
		if StringName(record.get(&"facility_id", "")) != facility_id:
			continue
		if not found.is_empty():
			return {}
		found = record.duplicate(true)
	return found


static func facility_id_at(cell: Vector2i) -> StringName:
	for definition_value: Dictionary in DEFINITIONS:
		if definition_value[&"cell"] == cell:
			return definition_value[&"facility_id"] as StringName
	return &""


static func repair(farm: Dictionary, facility_id: StringName) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var definition_value: Dictionary = definition(facility_id)
	var state: Dictionary = facility_state(source, facility_id)
	if definition_value.is_empty() or state.is_empty() or _ruin_count(source, facility_id) != 1:
		return _result(false, source, &"invalid_facility")
	if bool(state[&"repaired"]):
		return _result(false, source, &"facility_already_repaired")
	var candidate: Dictionary = _consume(source, definition_value[&"repair_materials"])
	if candidate.is_empty():
		return _result(false, source, &"repair_materials_missing")
	_set_facility_value(candidate, facility_id, &"repaired", true)
	_set_facility_value(candidate, facility_id, &"repair_token", "repair:%s" % facility_id)
	_sync_ruin(candidate, facility_id)
	return _result(true, candidate, &"")


static func power(farm: Dictionary, facility_id: StringName) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var definition_value: Dictionary = definition(facility_id)
	var state: Dictionary = facility_state(source, facility_id)
	if definition_value.is_empty() or state.is_empty() or _ruin_count(source, facility_id) != 1:
		return _result(false, source, &"invalid_facility")
	if not bool(state[&"repaired"]):
		return _result(false, source, &"facility_requires_repair")
	if bool(state[&"powered"]):
		return _result(false, source, &"facility_already_powered")
	var upgrades: Array = (source.get(&"tools", {}) as Dictionary).get(&"upgrade_ids", [])
	if String(definition_value[&"power_prerequisite"]) not in upgrades:
		return _result(false, source, &"facility_power_prerequisite_missing")
	var candidate: Dictionary = _consume(source, definition_value[&"power_materials"])
	if candidate.is_empty():
		return _result(false, source, &"power_materials_missing")
	_set_facility_value(candidate, facility_id, &"powered", true)
	_set_facility_value(candidate, facility_id, &"power_token", "power:%s" % facility_id)
	_sync_ruin(candidate, facility_id)
	return _result(true, candidate, &"")


static func active_services(farm: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	var home: Dictionary = home_services(farm)
	if bool(home[&"bed"]):
		result.append(&"service.home.bed")
	if bool(home[&"safehouse"]):
		result.append(&"service.home.safehouse")
	if bool(home[&"storage"]):
		result.append(&"service.home.storage")
	for definition_value: Dictionary in DEFINITIONS:
		var state: Dictionary = facility_state(farm, definition_value[&"facility_id"])
		if state.is_empty() or not bool(state[&"repaired"]) or not bool(state[&"powered"]):
			continue
		for service_id: StringName in definition_value[&"service_ids"] as Array[StringName]:
			if service_id not in result:
				result.append(service_id)
	result.sort_custom(_name_precedes)
	return result


static func home_services(farm: Dictionary) -> Dictionary:
	var home: Dictionary = _homestead(farm).get(&"home", {}) as Dictionary
	var fixed: bool = bool(home.get(&"repaired", false)) and bool(home.get(&"powered", false))
	return {
		&"home_id": HOME_ID,
		&"bed": fixed and bool(home.get(&"bed_enabled", false)),
		&"storage": fixed and bool(home.get(&"storage_enabled", false)),
		&"safehouse": fixed,
		&"animal_capacity": int(home.get(&"animal_capacity", 0)) if fixed else 0,
	}


static func _definition_is_valid(definition_value: Dictionary) -> bool:
	if not _exact_keys(
		definition_value,
		[
			&"facility_id",
			&"ruin_id",
			&"cell",
			&"ruin_kind",
			&"repair_materials",
			&"power_materials",
			&"power_prerequisite",
			&"service_ids",
		],
	):
		return false
	if (
		definition_value[&"facility_id"] not in FACILITY_IDS
		or not definition_value[&"cell"] is Vector2i
		or not _stable_id(definition_value[&"ruin_id"], "ruin.")
		or not _stable_id(definition_value[&"ruin_kind"], "ancient_")
		or definition_value[&"power_prerequisite"] != SAFEHOUSE_POWER_UPGRADE
		or DurableUpgradeCatalogScript.definition(SAFEHOUSE_POWER_UPGRADE).is_empty()
		or not _materials_are_valid(definition_value[&"repair_materials"])
		or not _materials_are_valid(definition_value[&"power_materials"])
	):
		return false
	var services: Array = definition_value[&"service_ids"] as Array
	if services.is_empty() or services.size() > MAX_SERVICE_IDS:
		return false
	var seen: Dictionary = {}
	for service_id: Variant in services:
		if not _stable_id(service_id, "service.") or seen.has(service_id):
			return false
		seen[service_id] = true
	return true


static func _materials_are_valid(value: Variant) -> bool:
	if not value is Dictionary or (value as Dictionary).is_empty():
		return false
	for raw_id: Variant in value:
		var item_id: StringName = StringName(str(raw_id))
		if item_id not in ItemCatalogScript.ids() or not value[raw_id] is int:
			return false
		if int(value[raw_id]) < 1 or int(value[raw_id]) > 99:
			return false
	return true


static func _records_are_complete(farm: Dictionary) -> bool:
	var seen: Dictionary = {}
	for record: Dictionary in _homestead(farm).get(&"facilities", []) as Array[Dictionary]:
		var facility_id: StringName = StringName(str(record.get(&"facility_id", "")))
		if facility_id not in FACILITY_IDS or seen.has(facility_id):
			return false
		seen[facility_id] = true
		if _ruin_count(farm, facility_id) != 1:
			return false
	return seen.size() == FACILITY_IDS.size() and _ruin_count(farm, HOME_ID) == 1


static func _facility_record(definition_value: Dictionary) -> Dictionary:
	var cell: Vector2i = definition_value[&"cell"] as Vector2i
	return {
		&"facility_id": String(definition_value[&"facility_id"]),
		&"cell": [cell.x, cell.y],
		&"repaired": false,
		&"powered": false,
		&"repair_token": "",
		&"power_token": "",
	}


static func _home_ruin() -> Dictionary:
	return {
		&"ruin_id": "ruin.home.8.4",
		&"facility_id": String(HOME_ID),
		&"cell": [HOME_CELL.x, HOME_CELL.y],
		&"kind": "ancient_safehouse",
		&"discovered": true,
		&"repaired": true,
		&"powered": true,
	}


static func _ruin_record(definition_value: Dictionary) -> Dictionary:
	var cell: Vector2i = definition_value[&"cell"] as Vector2i
	return {
		&"ruin_id": String(definition_value[&"ruin_id"]),
		&"facility_id": String(definition_value[&"facility_id"]),
		&"cell": [cell.x, cell.y],
		&"kind": String(definition_value[&"ruin_kind"]),
		&"discovered": true,
		&"repaired": false,
		&"powered": false,
	}


static func _consume(farm: Dictionary, materials: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var item_ids: Array[StringName] = []
	for raw_id: Variant in materials:
		item_ids.append(StringName(str(raw_id)))
	item_ids.sort_custom(_name_precedes)
	for item_id: StringName in item_ids:
		var count: int = int(materials[item_id])
		if InventoryServiceScript.count_all(candidate, item_id) < count:
			return {}
		var removed: Dictionary = InventoryServiceScript.remove_across(candidate, item_id, count)
		if not bool(removed[&"ok"]):
			return {}
		candidate = removed[&"candidate"] as Dictionary
	return candidate


static func _set_facility_value(
	farm: Dictionary, facility_id: StringName, key: StringName, value: Variant
) -> void:
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	var facilities: Array = (homestead[&"facilities"] as Array).duplicate(true)
	for index: int in facilities.size():
		var record: Dictionary = facilities[index] as Dictionary
		if StringName(record[&"facility_id"]) == facility_id:
			record[key] = value
			facilities[index] = record
			break
	homestead[&"facilities"] = facilities
	farm[&"homestead"] = homestead


static func _sync_ruin(farm: Dictionary, facility_id: StringName) -> void:
	var state: Dictionary = facility_state(farm, facility_id)
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	var ruins: Array = (homestead[&"ruins"] as Array).duplicate(true)
	for index: int in ruins.size():
		var ruin: Dictionary = ruins[index] as Dictionary
		if StringName(ruin[&"facility_id"]) == facility_id:
			ruin[&"repaired"] = state[&"repaired"]
			ruin[&"powered"] = state[&"powered"]
			ruins[index] = ruin
			break
	homestead[&"ruins"] = ruins
	farm[&"homestead"] = homestead


static func _sync_home_ruin(farm: Dictionary) -> void:
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	var home: Dictionary = homestead[&"home"] as Dictionary
	var ruins: Array = (homestead[&"ruins"] as Array).duplicate(true)
	for index: int in ruins.size():
		var ruin: Dictionary = ruins[index] as Dictionary
		if StringName(ruin[&"facility_id"]) == HOME_ID:
			ruin[&"repaired"] = home[&"repaired"]
			ruin[&"powered"] = home[&"powered"]
			ruins[index] = ruin
			break
	homestead[&"ruins"] = ruins
	farm[&"homestead"] = homestead


static func _ruin_count(farm: Dictionary, facility_id: StringName) -> int:
	var count: int = 0
	for ruin: Dictionary in _homestead(farm).get(&"ruins", []) as Array[Dictionary]:
		count += int(StringName(str(ruin.get(&"facility_id", ""))) == facility_id)
	return count


static func _homestead(farm: Dictionary) -> Dictionary:
	return farm.get(&"homestead", {}) as Dictionary


static func _stable_id(value: Variant, prefix: String) -> bool:
	if not value is String and not value is StringName:
		return false
	var identifier: String = str(value)
	return identifier.begins_with(prefix) and identifier.length() <= 64


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
