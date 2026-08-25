extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const ResidentServiceScript: GDScript = preload("res://scripts/resident_service.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const MAX_POINTS: int = 500
const POINTS_PER_HEART: int = 100
const MAX_HEARTS: int = 5
const MAX_COMPLETED_REQUESTS: int = 3
const MAX_BOARD_REQUESTS: int = 3
const MAX_TOKENS: int = 64
const TALK_POINTS: int = 10
const REQUEST_IDS: Array[StringName] = [
	RuntimeIdsScript.REQUEST_LYRA_ID,
	RuntimeIdsScript.REQUEST_ROOK_ID,
	RuntimeIdsScript.REQUEST_MIRA_ID,
]
const REQUESTS: Array[Dictionary] = [
	{
		&"request_id": RuntimeIdsScript.REQUEST_LYRA_ID,
		&"resident_id": ResidentServiceScript.LYRA_ID,
		&"unlock_points": 20,
		&"item_id": &"item.produce.rainleaf",
		&"count": 1,
		&"money_reward": 120,
		&"relationship_reward": 35,
	},
	{
		&"request_id": RuntimeIdsScript.REQUEST_ROOK_ID,
		&"resident_id": ResidentServiceScript.ROOK_ID,
		&"unlock_points": 20,
		&"item_id": &"item.material.scrap",
		&"count": 2,
		&"money_reward": 140,
		&"relationship_reward": 35,
	},
	{
		&"request_id": RuntimeIdsScript.REQUEST_MIRA_ID,
		&"resident_id": ResidentServiceScript.MIRA_ID,
		&"unlock_points": 20,
		&"item_id": &"item.produce.glowroot",
		&"count": 1,
		&"money_reward": 130,
		&"relationship_reward": 35,
	},
]
const GIFT_POINTS: Dictionary = {
	ResidentServiceScript.LYRA_ID: {
		&"item.produce.rainleaf": 30, &"item.produce.starbloom": 24
	},
	ResidentServiceScript.ROOK_ID: {
		&"item.material.scrap": 24, &"item.part.iron_ingot": 30
	},
	ResidentServiceScript.MIRA_ID: {
		&"item.produce.glowroot": 24, &"item.food.field_ration": 30
	},
}


static func ensure_default(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate.get(&"homestead", {}) as Dictionary
	if not homestead.has(&"home"):
		return candidate
	if (homestead.get(&"relationships", []) as Array).is_empty():
		var relationships: Array[Dictionary] = []
		for resident_id: StringName in ResidentServiceScript.RESIDENT_IDS:
			relationships.append(
				{
					&"resident_id": String(resident_id),
					&"points": 0,
					&"hearts": 0,
					&"last_talk_day": 0,
					&"last_gift_day": 0,
					&"completed_request_ids": [],
					&"interaction_tokens": [],
				}
			)
		relationships.sort_custom(_id_precedes.bind(&"resident_id"))
		homestead[&"relationships"] = relationships
	if (homestead.get(&"requests", []) as Array).is_empty():
		var requests: Array[Dictionary] = []
		for request_id: StringName in REQUEST_IDS:
			requests.append(
				{&"request_id": String(request_id), &"status": "pending", &"completed_day": 0}
			)
		requests.sort_custom(_id_precedes.bind(&"request_id"))
		homestead[&"requests"] = requests
	candidate[&"homestead"] = homestead
	return candidate


static func validate_definitions() -> bool:
	if REQUESTS.size() != 3 or REQUEST_IDS.size() != 3 or GIFT_POINTS.size() != 3:
		return false
	var requests: Dictionary = {}
	var residents: Dictionary = {}
	for definition_value: Dictionary in REQUESTS:
		if not _request_definition_is_valid(definition_value):
			return false
		var request_id: StringName = definition_value[&"request_id"] as StringName
		var resident_id: StringName = definition_value[&"resident_id"] as StringName
		if requests.has(request_id) or residents.has(resident_id):
			return false
		requests[request_id] = true
		residents[resident_id] = true
	for resident_id: StringName in ResidentServiceScript.RESIDENT_IDS:
		var gifts: Dictionary = GIFT_POINTS.get(resident_id, {}) as Dictionary
		if gifts.is_empty() or gifts.size() > 4:
			return false
		for raw_item_id: Variant in gifts:
			var item_id: StringName = StringName(str(raw_item_id))
			if item_id not in ItemCatalogScript.ids() or int(gifts[raw_item_id]) not in range(1, 51):
				return false
	return requests.size() == REQUEST_IDS.size() and residents.size() == 3


static func relationship(farm: Dictionary, resident_id: StringName) -> Dictionary:
	var found: Dictionary = {}
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	for record: Dictionary in homestead.get(&"relationships", []) as Array[Dictionary]:
		if StringName(record.get(&"resident_id", "")) != resident_id:
			continue
		if not found.is_empty():
			return {}
		found = record.duplicate(true)
	return found


static func request_definition(request_id: StringName) -> Dictionary:
	for definition_value: Dictionary in REQUESTS:
		if definition_value[&"request_id"] == request_id:
			return definition_value.duplicate(true)
	return {}


static func talk(farm: Dictionary, resident_id: StringName) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	if not _resident_is_valid(source, resident_id):
		return _result(false, source, &"invalid_resident")
	var relation: Dictionary = relationship(source, resident_id)
	if relation.is_empty():
		return _result(false, source, &"invalid_relationship")
	var day: int = _day(source)
	var token: String = _interaction_token("talk", resident_id, day)
	if int(relation[&"last_talk_day"]) == day or token in relation[&"interaction_tokens"]:
		return _result(false, source, &"already_talked_today")
	var candidate: Dictionary = source.duplicate(true)
	_add_points(candidate, resident_id, TALK_POINTS)
	_set_relationship(candidate, resident_id, &"last_talk_day", day)
	_append_token(candidate, resident_id, token)
	return _result(true, candidate, &"")


static func gift(farm: Dictionary, resident_id: StringName, item_id: StringName) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	if not _resident_is_valid(source, resident_id):
		return _result(false, source, &"invalid_resident")
	var relation: Dictionary = relationship(source, resident_id)
	var gifts: Dictionary = GIFT_POINTS.get(resident_id, {}) as Dictionary
	if relation.is_empty() or item_id not in ItemCatalogScript.ids() or not gifts.has(item_id):
		return _result(false, source, &"invalid_gift")
	var day: int = _day(source)
	var token: String = _interaction_token("gift", resident_id, day)
	if int(relation[&"last_gift_day"]) == day or token in relation[&"interaction_tokens"]:
		return _result(false, source, &"already_gifted_today")
	var removed: Dictionary = InventoryServiceScript.remove_across(source, item_id, 1)
	if not bool(removed[&"ok"]):
		return _result(false, source, &"gift_item_missing")
	var candidate: Dictionary = removed[&"candidate"] as Dictionary
	_add_points(candidate, resident_id, int(gifts[item_id]))
	_set_relationship(candidate, resident_id, &"last_gift_day", day)
	_append_token(candidate, resident_id, token)
	return _result(true, candidate, &"")


static func board(farm: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition_value: Dictionary in REQUESTS:
		if result.size() >= MAX_BOARD_REQUESTS:
			break
		var resident_id: StringName = definition_value[&"resident_id"] as StringName
		var relation: Dictionary = relationship(farm, resident_id)
		var request_state: Dictionary = _request_state(farm, definition_value[&"request_id"])
		if (
			_resident_is_valid(farm, resident_id)
			and not relation.is_empty()
			and int(relation[&"points"]) >= int(definition_value[&"unlock_points"])
			and request_state.get(&"status", "") == "pending"
		):
			result.append(definition_value.duplicate(true))
	return result.duplicate(true)


static func complete_request(farm: Dictionary, request_id: StringName) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var definition_value: Dictionary = request_definition(request_id)
	if definition_value.is_empty():
		return _result(false, source, &"invalid_request")
	var resident_id: StringName = definition_value[&"resident_id"] as StringName
	if not _resident_is_valid(source, resident_id):
		return _result(false, source, &"invalid_resident")
	var relation: Dictionary = relationship(source, resident_id)
	var state_value: Dictionary = _request_state(source, request_id)
	if relation.is_empty() or state_value.is_empty():
		return _result(false, source, &"invalid_request_state")
	var completed: Array = (relation[&"completed_request_ids"] as Array).duplicate()
	if state_value[&"status"] == "completed" or String(request_id) in completed:
		return _result(false, source, &"request_already_completed")
	if int(relation[&"points"]) < int(definition_value[&"unlock_points"]):
		return _result(false, source, &"request_locked")
	if completed.size() >= MAX_COMPLETED_REQUESTS:
		return _result(false, source, &"request_history_full")
	var removed: Dictionary = InventoryServiceScript.remove_across(
		source, definition_value[&"item_id"] as StringName, int(definition_value[&"count"])
	)
	if not bool(removed[&"ok"]):
		return _result(false, source, &"request_items_missing")
	var candidate: Dictionary = removed[&"candidate"] as Dictionary
	var economy: Dictionary = candidate[&"economy"] as Dictionary
	var reward_money: int = int(definition_value[&"money_reward"])
	if int(economy[&"money"]) > 1_000_000_000 - reward_money:
		return _result(false, source, &"money_cap_exceeded")
	economy[&"money"] = int(economy[&"money"]) + reward_money
	candidate[&"economy"] = economy
	_add_points(candidate, resident_id, int(definition_value[&"relationship_reward"]))
	_set_request_completed(candidate, request_id, _day(candidate))
	completed.append(String(request_id))
	completed.sort()
	_set_relationship(candidate, resident_id, &"completed_request_ids", completed)
	return _result(true, candidate, &"")


static func _request_definition_is_valid(definition_value: Dictionary) -> bool:
	if not _exact_keys(
		definition_value,
		[
			&"request_id",
			&"resident_id",
			&"unlock_points",
			&"item_id",
			&"count",
			&"money_reward",
			&"relationship_reward",
		],
	):
		return false
	return (
		definition_value[&"request_id"] in REQUEST_IDS
		and definition_value[&"resident_id"] in ResidentServiceScript.RESIDENT_IDS
		and definition_value[&"item_id"] in ItemCatalogScript.ids()
		and int(definition_value[&"unlock_points"]) == 20
		and int(definition_value[&"count"]) in range(1, 100)
		and int(definition_value[&"money_reward"]) in range(1, 1_001)
		and int(definition_value[&"relationship_reward"]) in range(1, 101)
	)


static func _resident_is_valid(farm: Dictionary, resident_id: StringName) -> bool:
	if resident_id not in ResidentServiceScript.RESIDENT_IDS:
		return false
	var state_value: Dictionary = ResidentServiceScript.state(farm, resident_id)
	return not state_value.is_empty() and bool(state_value[&"arrived"])


static func _day(farm: Dictionary) -> int:
	return CalendarStateScript.absolute_day(farm[&"calendar_weather"])


static func _add_points(farm: Dictionary, resident_id: StringName, amount: int) -> void:
	var current: Dictionary = relationship(farm, resident_id)
	var points: int = clampi(int(current[&"points"]) + amount, 0, MAX_POINTS)
	_set_relationship(farm, resident_id, &"points", points)
	_set_relationship(farm, resident_id, &"hearts", mini(points / POINTS_PER_HEART, MAX_HEARTS))


static func _append_token(farm: Dictionary, resident_id: StringName, token: String) -> void:
	var relation: Dictionary = relationship(farm, resident_id)
	var tokens: Array = (relation[&"interaction_tokens"] as Array).duplicate()
	if token in tokens:
		return
	tokens.append(token)
	if tokens.size() > MAX_TOKENS:
		_remove_oldest_token(tokens)
	tokens.sort()
	_set_relationship(farm, resident_id, &"interaction_tokens", tokens)


static func _set_relationship(
	farm: Dictionary, resident_id: StringName, key: StringName, value: Variant
) -> void:
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	var records: Array = (homestead[&"relationships"] as Array).duplicate(true)
	for index: int in records.size():
		var record: Dictionary = records[index] as Dictionary
		if StringName(record[&"resident_id"]) == resident_id:
			record[key] = value
			records[index] = record
			break
	homestead[&"relationships"] = records
	farm[&"homestead"] = homestead


static func _request_state(farm: Dictionary, request_id: StringName) -> Dictionary:
	var found: Dictionary = {}
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	for record: Dictionary in homestead.get(&"requests", []) as Array[Dictionary]:
		if StringName(record.get(&"request_id", "")) != request_id:
			continue
		if not found.is_empty():
			return {}
		found = record.duplicate(true)
	return found


static func _set_request_completed(farm: Dictionary, request_id: StringName, day: int) -> void:
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	var records: Array = (homestead[&"requests"] as Array).duplicate(true)
	for index: int in records.size():
		var record: Dictionary = records[index] as Dictionary
		if StringName(record[&"request_id"]) == request_id:
			record[&"status"] = "completed"
			record[&"completed_day"] = day
			records[index] = record
			break
	homestead[&"requests"] = records
	farm[&"homestead"] = homestead


static func _interaction_token(kind: String, resident_id: StringName, day: int) -> String:
	return "relationship:%s:%s:%d" % [kind, resident_id, day]


static func _remove_oldest_token(tokens: Array) -> void:
	var oldest_index: int = 0
	for index: int in range(1, tokens.size()):
		var candidate: String = str(tokens[index])
		var oldest: String = str(tokens[oldest_index])
		var candidate_day: int = int(candidate.get_slice(":", 3))
		var oldest_day: int = int(oldest.get_slice(":", 3))
		if candidate_day < oldest_day or (candidate_day == oldest_day and candidate < oldest):
			oldest_index = index
	tokens.remove_at(oldest_index)


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
