extends RefCounted

const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")
const LivestockServiceScript: GDScript = preload("res://scripts/livestock_service.gd")
const RelationshipServiceScript: GDScript = preload("res://scripts/relationship_service.gd")
const ResidentServiceScript: GDScript = preload("res://scripts/resident_service.gd")
const SettlementSectionsScript: GDScript = preload(
	"res://scripts/settlement_persistence_sections.gd"
)

const STATE_VERSION: int = 2
const MAX_FACILITIES: int = 64
const MAX_RESIDENTS: int = 64
const MAX_RUINS: int = 1_024
const MAX_RELATIONSHIPS: int = 64
const MAX_REQUESTS: int = 16
const MAX_ANIMALS: int = 12
const MAX_ABSOLUTE_DAY: int = 9_999 * 4 * 14
const MAX_COORDINATE: int = 1_000_000


static func make_neutral() -> Dictionary:
	return {
		&"state_version": STATE_VERSION,
		&"facilities": [],
		&"residents": [],
		&"ruins": [],
		&"construction": SettlementSectionsScript.neutral_construction(),
		&"workforce": SettlementSectionsScript.neutral_workforce(),
	}


static func migrate_v1(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var legacy: Dictionary = value as Dictionary
	var active: bool = legacy.has(&"home")
	var keys: Array[StringName] = [&"state_version", &"facilities", &"residents", &"ruins"]
	if active:
		keys.append_array([&"home", &"relationships", &"requests", &"animals"])
	if not _exact_keys(legacy, keys) or _json_integer(legacy[&"state_version"], 1, 1) == null:
		return {}
	var candidate: Dictionary = legacy.duplicate(true)
	candidate[&"state_version"] = STATE_VERSION
	candidate[&"construction"] = SettlementSectionsScript.neutral_construction()
	candidate[&"workforce"] = SettlementSectionsScript.neutral_workforce()
	return normalize(candidate)


static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var homestead: Dictionary = value as Dictionary
	var neutral: bool = not homestead.has(&"home")
	var keys: Array[StringName] = [
		&"state_version", &"facilities", &"residents", &"ruins", &"construction", &"workforce"
	]
	if not neutral:
		keys.append_array([&"home", &"relationships", &"requests", &"animals"])
	if not _exact_keys(homestead, keys):
		return {}
	var version: Variant = _json_integer(
		homestead.get(&"state_version"), STATE_VERSION, STATE_VERSION
	)
	if version == null:
		return {}
	if neutral:
		return _normalize_neutral(homestead)
	return _normalize_active(homestead)


static func _normalize_neutral(homestead: Dictionary) -> Dictionary:
	for key: StringName in [&"facilities", &"residents", &"ruins"]:
		if not homestead[key] is Array or not (homestead[key] as Array).is_empty():
			return {}
	var construction: Dictionary = SettlementSectionsScript.validate_construction(
		homestead[&"construction"]
	)
	var workforce: Dictionary = SettlementSectionsScript.validate_workforce(homestead[&"workforce"])
	if construction.is_empty() or workforce.is_empty():
		return {}
	return {
		&"state_version": STATE_VERSION,
		&"facilities": [],
		&"residents": [],
		&"ruins": [],
		&"construction": construction,
		&"workforce": workforce,
	}


static func _normalize_active(homestead: Dictionary) -> Dictionary:
	var home: Dictionary = _normalize_home(homestead.get(&"home"))
	var facilities: Variant = _normalize_facilities(homestead.get(&"facilities"))
	var residents: Variant = _normalize_residents(homestead.get(&"residents"))
	var relationships: Variant = _normalize_relationships(homestead.get(&"relationships"))
	var requests: Variant = _normalize_requests(homestead.get(&"requests"))
	var animals: Variant = _normalize_animals(homestead.get(&"animals"))
	var ruins: Variant = _normalize_ruins(homestead.get(&"ruins"))
	var construction: Dictionary = SettlementSectionsScript.validate_construction(
		homestead.get(&"construction")
	)
	var workforce: Dictionary = SettlementSectionsScript.validate_workforce(
		homestead.get(&"workforce")
	)
	if (
		home.is_empty()
		or facilities == null
		or residents == null
		or relationships == null
		or requests == null
		or animals == null
		or ruins == null
		or construction.is_empty()
		or workforce.is_empty()
	):
		return {}
	if not _ruins_synchronized(home, facilities as Array, ruins as Array):
		return {}
	if not _requests_synchronized(relationships as Array, requests as Array):
		return {}
	return {
		&"state_version": STATE_VERSION,
		&"home": home,
		&"facilities": facilities,
		&"residents": residents,
		&"relationships": relationships,
		&"requests": requests,
		&"animals": animals,
		&"ruins": ruins,
		&"construction": construction,
		&"workforce": workforce,
	}


static func _normalize_home(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var home: Dictionary = value as Dictionary
	if not _exact_keys(
		home,
		[
			&"home_id",
			&"cell",
			&"repaired",
			&"powered",
			&"bed_enabled",
			&"storage_enabled",
			&"animal_capacity",
		],
	):
		return {}
	var cell: Variant = _normalize_cell(home[&"cell"])
	var capacity: Variant = _json_integer(home[&"animal_capacity"], 0, MAX_ANIMALS)
	if (
		str(home[&"home_id"]) != String(HomesteadServiceScript.HOME_ID)
		or cell != [HomesteadServiceScript.HOME_CELL.x, HomesteadServiceScript.HOME_CELL.y]
		or capacity == null
		or int(capacity) != HomesteadServiceScript.HOME_CAPACITY
		or not home[&"repaired"] is bool
		or not home[&"powered"] is bool
		or not home[&"bed_enabled"] is bool
		or not home[&"storage_enabled"] is bool
		or not bool(home[&"repaired"])
		or not bool(home[&"powered"])
		or not bool(home[&"bed_enabled"])
		or not bool(home[&"storage_enabled"])
	):
		return {}
	return {
		&"home_id": String(HomesteadServiceScript.HOME_ID),
		&"cell": cell,
		&"repaired": true,
		&"powered": true,
		&"bed_enabled": true,
		&"storage_enabled": true,
		&"animal_capacity": HomesteadServiceScript.HOME_CAPACITY,
	}


static func _normalize_facilities(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_FACILITIES:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_record: Variant in value as Array:
		var record: Dictionary = raw_record as Dictionary if raw_record is Dictionary else {}
		if not _exact_keys(
			record,
			[&"facility_id", &"cell", &"repaired", &"powered", &"repair_token", &"power_token"],
		):
			return null
		var facility_id: StringName = StringName(str(record[&"facility_id"]))
		var definition_value: Dictionary = HomesteadServiceScript.definition(facility_id)
		var cell: Variant = _normalize_cell(record[&"cell"])
		if (
			definition_value.is_empty()
			or seen.has(facility_id)
			or cell != _cell_array(definition_value[&"cell"] as Vector2i)
			or not record[&"repaired"] is bool
			or not record[&"powered"] is bool
			or (bool(record[&"powered"]) and not bool(record[&"repaired"]))
			or not record[&"repair_token"] is String
			or not record[&"power_token"] is String
		):
			return null
		var repair_token: String = "repair:%s" % facility_id if record[&"repaired"] else ""
		var power_token: String = "power:%s" % facility_id if record[&"powered"] else ""
		if record[&"repair_token"] != repair_token or record[&"power_token"] != power_token:
			return null
		seen[facility_id] = true
		result.append(
			{
				&"facility_id": String(facility_id),
				&"cell": cell,
				&"repaired": bool(record[&"repaired"]),
				&"powered": bool(record[&"powered"]),
				&"repair_token": repair_token,
				&"power_token": power_token,
			}
		)
	result.sort_custom(_id_precedes.bind(&"facility_id"))
	return result if result.size() == HomesteadServiceScript.FACILITY_IDS.size() else null


static func _normalize_residents(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_RESIDENTS:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_record: Variant in value as Array:
		var record: Dictionary = raw_record as Dictionary if raw_record is Dictionary else {}
		if not _exact_keys(record, [&"resident_id", &"facility_id", &"arrived", &"arrival_day"]):
			return null
		var resident_id: StringName = StringName(str(record[&"resident_id"]))
		var definition_value: Dictionary = ResidentServiceScript.definition(resident_id)
		var arrival_day: Variant = _json_integer(record[&"arrival_day"], 0, MAX_ABSOLUTE_DAY)
		if (
			definition_value.is_empty()
			or seen.has(resident_id)
			or str(record[&"facility_id"]) != String(definition_value[&"facility_id"])
			or not record[&"arrived"] is bool
			or arrival_day == null
			or (bool(record[&"arrived"]) != (int(arrival_day) > 0))
		):
			return null
		seen[resident_id] = true
		result.append(
			{
				&"resident_id": String(resident_id),
				&"facility_id": String(definition_value[&"facility_id"]),
				&"arrived": bool(record[&"arrived"]),
				&"arrival_day": int(arrival_day),
			}
		)
	result.sort_custom(_id_precedes.bind(&"resident_id"))
	return result if result.size() == ResidentServiceScript.RESIDENT_IDS.size() else null


static func _normalize_relationships(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_RELATIONSHIPS:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_record: Variant in value as Array:
		var record: Dictionary = raw_record as Dictionary if raw_record is Dictionary else {}
		if not _relationship_keys_are_exact(record):
			return null
		var resident_id: StringName = StringName(str(record[&"resident_id"]))
		var points: Variant = _json_integer(record[&"points"], 0, RelationshipServiceScript.MAX_POINTS)
		var hearts: Variant = _json_integer(record[&"hearts"], 0, RelationshipServiceScript.MAX_HEARTS)
		var talk_day: Variant = _json_integer(record[&"last_talk_day"], 0, MAX_ABSOLUTE_DAY)
		var gift_day: Variant = _json_integer(record[&"last_gift_day"], 0, MAX_ABSOLUTE_DAY)
		var completed: Variant = _normalize_request_ids(record[&"completed_request_ids"])
		var tokens: Variant = _normalize_interaction_tokens(
			record[&"interaction_tokens"], resident_id
		)
		if (
			resident_id not in ResidentServiceScript.RESIDENT_IDS
			or seen.has(resident_id)
			or points == null
			or hearts == null
			or talk_day == null
			or gift_day == null
			or completed == null
			or tokens == null
			or int(hearts) != _hearts_for(int(points))
			or not _latest_interactions_exist(tokens as Array, resident_id, talk_day, gift_day)
		):
			return null
		seen[resident_id] = true
		result.append(
			{
				&"resident_id": String(resident_id),
				&"points": int(points),
				&"hearts": int(hearts),
				&"last_talk_day": int(talk_day),
				&"last_gift_day": int(gift_day),
				&"completed_request_ids": completed,
				&"interaction_tokens": tokens,
			}
		)
	result.sort_custom(_id_precedes.bind(&"resident_id"))
	return result if result.size() == ResidentServiceScript.RESIDENT_IDS.size() else null


static func _normalize_requests(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_REQUESTS:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_record: Variant in value as Array:
		var record: Dictionary = raw_record as Dictionary if raw_record is Dictionary else {}
		if not _exact_keys(record, [&"request_id", &"status", &"completed_day"]):
			return null
		var request_id: StringName = StringName(str(record[&"request_id"]))
		var completed_day: Variant = _json_integer(record[&"completed_day"], 0, MAX_ABSOLUTE_DAY)
		var status: String = str(record[&"status"])
		if (
			request_id not in RelationshipServiceScript.REQUEST_IDS
			or seen.has(request_id)
			or completed_day == null
			or status not in ["pending", "completed"]
			or ((status == "completed") != (int(completed_day) > 0))
		):
			return null
		seen[request_id] = true
		result.append(
			{
				&"request_id": String(request_id),
				&"status": status,
				&"completed_day": int(completed_day),
			}
		)
	result.sort_custom(_id_precedes.bind(&"request_id"))
	return result if result.size() == RelationshipServiceScript.REQUEST_IDS.size() else null


static func _normalize_ruins(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_RUINS:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_record: Variant in value as Array:
		var record: Dictionary = raw_record as Dictionary if raw_record is Dictionary else {}
		if not _ruin_keys_are_exact(record):
			return null
		var ruin_id: String = str(record[&"ruin_id"])
		var facility_id: StringName = StringName(str(record[&"facility_id"]))
		var expected: Dictionary = _expected_ruin(facility_id)
		var cell: Variant = _normalize_cell(record[&"cell"])
		if (
			expected.is_empty()
			or ruin_id != str(expected[&"ruin_id"])
			or seen.has(ruin_id)
			or cell != expected[&"cell"]
			or str(record[&"kind"]) != str(expected[&"kind"])
			or not record[&"discovered"] is bool
			or not record[&"repaired"] is bool
			or not record[&"powered"] is bool
			or not bool(record[&"discovered"])
			or (bool(record[&"powered"]) and not bool(record[&"repaired"]))
		):
			return null
		seen[ruin_id] = true
		result.append(
			{
				&"ruin_id": ruin_id,
				&"facility_id": String(facility_id),
				&"cell": cell,
				&"kind": str(expected[&"kind"]),
				&"discovered": true,
				&"repaired": bool(record[&"repaired"]),
				&"powered": bool(record[&"powered"]),
			}
		)
	result.sort_custom(_id_precedes.bind(&"ruin_id"))
	var expected_size: int = HomesteadServiceScript.FACILITY_IDS.size() + 1
	return result if result.size() == expected_size else null


static func _normalize_animals(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_ANIMALS:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_record: Variant in value as Array:
		var record: Dictionary = raw_record as Dictionary if raw_record is Dictionary else {}
		if not _animal_keys_are_exact(record):
			return null
		var animal_id: String = str(record[&"animal_id"])
		var species_id: StringName = StringName(str(record[&"species_id"]))
		var definition_value: Dictionary = LivestockServiceScript.definition(species_id)
		var bond: Variant = _json_integer(record[&"bond"], 0, LivestockServiceScript.MAX_BOND)
		var feed_day: Variant = _json_integer(record[&"last_feed_day"], 0, MAX_ABSOLUTE_DAY)
		var pet_day: Variant = _json_integer(record[&"last_pet_day"], 0, MAX_ABSOLUTE_DAY)
		var product_day: Variant = _json_integer(record[&"last_product_day"], 0, MAX_ABSOLUTE_DAY)
		var tokens: Variant = _normalize_care_tokens(record[&"care_tokens"], animal_id)
		if (
			not _valid_animal_id(animal_id)
			or seen.has(animal_id)
			or definition_value.is_empty()
			or str(record[&"housing_id"]) != String(definition_value[&"housing_id"])
			or bond == null
			or feed_day == null
			or pet_day == null
			or product_day == null
			or tokens == null
			or int(product_day) > int(feed_day)
			or int(product_day) > int(pet_day)
			or not _latest_care_exists(tokens as Array, animal_id, feed_day, pet_day, product_day)
		):
			return null
		seen[animal_id] = true
		result.append(
			{
				&"animal_id": animal_id,
				&"species_id": String(species_id),
				&"housing_id": String(definition_value[&"housing_id"]),
				&"bond": int(bond),
				&"last_feed_day": int(feed_day),
				&"last_pet_day": int(pet_day),
				&"last_product_day": int(product_day),
				&"care_tokens": tokens,
			}
		)
	result.sort_custom(_id_precedes.bind(&"animal_id"))
	return result


static func _normalize_request_ids(value: Variant) -> Variant:
	if (
		not value is Array
		or (value as Array).size() > RelationshipServiceScript.MAX_COMPLETED_REQUESTS
	):
		return null
	var result: Array[String] = []
	for raw_id: Variant in value as Array:
		var request_id: StringName = StringName(str(raw_id))
		if request_id not in RelationshipServiceScript.REQUEST_IDS or String(request_id) in result:
			return null
		result.append(String(request_id))
	result.sort()
	return result


static func _normalize_interaction_tokens(value: Variant, resident_id: StringName) -> Variant:
	if not value is Array or (value as Array).size() > RelationshipServiceScript.MAX_TOKENS:
		return null
	var result: Array[String] = []
	for raw_token: Variant in value as Array:
		if not raw_token is String:
			return null
		var token: String = str(raw_token)
		var parts: PackedStringArray = token.split(":")
		if (
			parts.size() != 4
			or parts[0] != "relationship"
			or parts[1] not in ["talk", "gift"]
			or parts[2] != String(resident_id)
			or not parts[3].is_valid_int()
			or int(parts[3]) < 1
			or int(parts[3]) > MAX_ABSOLUTE_DAY
			or token.length() > 128
			or token in result
		):
			return null
		result.append(token)
	result.sort()
	return result


static func _normalize_care_tokens(value: Variant, animal_id: String) -> Variant:
	if not value is Array or (value as Array).size() > LivestockServiceScript.MAX_CARE_TOKENS:
		return null
	var result: Array[String] = []
	for raw_token: Variant in value as Array:
		if not raw_token is String:
			return null
		var token: String = str(raw_token)
		var parts: PackedStringArray = token.split(":")
		if (
			parts.size() != 4
			or parts[0] != "care"
			or parts[1] not in ["feed", "pet", "product"]
			or parts[2] != animal_id
			or not parts[3].is_valid_int()
			or int(parts[3]) < 1
			or int(parts[3]) > MAX_ABSOLUTE_DAY
			or token.length() > 128
			or token in result
		):
			return null
		result.append(token)
	result.sort()
	return result


static func _ruins_synchronized(home: Dictionary, facilities: Array, ruins: Array) -> bool:
	var states: Dictionary = {
		String(HomesteadServiceScript.HOME_ID): {
			&"repaired": home[&"repaired"], &"powered": home[&"powered"]
		}
	}
	for facility: Dictionary in facilities:
		states[str(facility[&"facility_id"])] = {
			&"repaired": facility[&"repaired"], &"powered": facility[&"powered"]
		}
	for ruin: Dictionary in ruins:
		var state: Dictionary = states.get(str(ruin[&"facility_id"]), {}) as Dictionary
		if (
			state.is_empty()
			or ruin[&"repaired"] != state[&"repaired"]
			or ruin[&"powered"] != state[&"powered"]
		):
			return false
	return true


static func _requests_synchronized(relationships: Array, requests: Array) -> bool:
	var completed_by_resident: Dictionary = {}
	for relationship: Dictionary in relationships:
		completed_by_resident[str(relationship[&"resident_id"])] = (
			relationship[&"completed_request_ids"]
		)
	for request: Dictionary in requests:
		var definition_value: Dictionary = RelationshipServiceScript.request_definition(
			StringName(request[&"request_id"])
		)
		var resident_id: String = str(definition_value[&"resident_id"])
		var history: Array = completed_by_resident.get(resident_id, []) as Array
		var in_history: bool = str(request[&"request_id"]) in history
		if in_history != (request[&"status"] == "completed"):
			return false
	return true


static func _latest_interactions_exist(
	tokens: Array, resident_id: StringName, talk_day: Variant, gift_day: Variant
) -> bool:
	if int(talk_day) > 0:
		var talk_token: String = "relationship:talk:%s:%d" % [resident_id, int(talk_day)]
		if talk_token not in tokens:
			return false
	if int(gift_day) > 0:
		var gift_token: String = "relationship:gift:%s:%d" % [resident_id, int(gift_day)]
		if gift_token not in tokens:
			return false
	return true


static func _latest_care_exists(
	tokens: Array, animal_id: String, feed_day: Variant, pet_day: Variant, product_day: Variant
) -> bool:
	for entry: Array in [
		["feed", int(feed_day)], ["pet", int(pet_day)], ["product", int(product_day)]
	]:
		if int(entry[1]) > 0 and "care:%s:%s:%d" % [entry[0], animal_id, entry[1]] not in tokens:
			return false
	return true


static func _expected_ruin(facility_id: StringName) -> Dictionary:
	if facility_id == HomesteadServiceScript.HOME_ID:
		return {
			&"ruin_id": "ruin.home.8.4",
			&"cell": _cell_array(HomesteadServiceScript.HOME_CELL),
			&"kind": "ancient_safehouse",
		}
	var definition_value: Dictionary = HomesteadServiceScript.definition(facility_id)
	if definition_value.is_empty():
		return {}
	return {
		&"ruin_id": String(definition_value[&"ruin_id"]),
		&"cell": _cell_array(definition_value[&"cell"] as Vector2i),
		&"kind": String(definition_value[&"ruin_kind"]),
	}


static func _relationship_keys_are_exact(record: Dictionary) -> bool:
	return _exact_keys(
		record,
		[
			&"resident_id",
			&"points",
			&"hearts",
			&"last_talk_day",
			&"last_gift_day",
			&"completed_request_ids",
			&"interaction_tokens",
		],
	)


static func _ruin_keys_are_exact(record: Dictionary) -> bool:
	return _exact_keys(
		record,
		[&"ruin_id", &"facility_id", &"cell", &"kind", &"discovered", &"repaired", &"powered"],
	)


static func _animal_keys_are_exact(record: Dictionary) -> bool:
	return _exact_keys(
		record,
		[
			&"animal_id",
			&"species_id",
			&"housing_id",
			&"bond",
			&"last_feed_day",
			&"last_pet_day",
			&"last_product_day",
			&"care_tokens",
		],
	)


static func _valid_animal_id(animal_id: String) -> bool:
	if (
		not animal_id.begins_with("animal.")
		or animal_id.length() > 64
		or animal_id.ends_with(".")
		or ".." in animal_id
	):
		return false
	for index: int in animal_id.length():
		var code: int = animal_id.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57):
			if code not in [45, 46, 95]:
				return false
	return true


static func _hearts_for(points: int) -> int:
	return mini(
		points / RelationshipServiceScript.POINTS_PER_HEART,
		RelationshipServiceScript.MAX_HEARTS,
	)


static func _normalize_cell(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() != 2:
		return null
	var x: Variant = _json_integer(value[0], -MAX_COORDINATE, MAX_COORDINATE)
	var y: Variant = _json_integer(value[1], -MAX_COORDINATE, MAX_COORDINATE)
	return null if x == null or y == null else [int(x), int(y)]


static func _json_integer(value: Variant, minimum: int, maximum: int) -> Variant:
	if not value is int and not value is float:
		return null
	var number: float = float(value)
	if not is_finite(number) or number != floor(number) or number < minimum or number > maximum:
		return null
	return int(number)


static func _cell_array(cell: Vector2i) -> Array[int]:
	return [cell.x, cell.y]


static func _id_precedes(first: Dictionary, second: Dictionary, key: StringName) -> bool:
	return str(first[key]) < str(second[key])


static func _exact_keys(value: Dictionary, expected: Array[StringName]) -> bool:
	if value.size() != expected.size():
		return false
	for key: StringName in expected:
		if not value.has(key):
			return false
	return true
