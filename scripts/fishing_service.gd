extends RefCounted

const CalendarScript: GDScript = preload("res://scripts/calendar_state.gd")
const FishingCatalogScript: GDScript = preload("res://scripts/fishing_catalog.gd")
const InventoryScript: GDScript = preload("res://scripts/inventory_service.gd")

const ROD_ITEM: StringName = &"item.tool.fishing_rod"
const BAIT_ITEM: StringName = &"item.bait.luminous"


static func cast(
	farm: Dictionary,
	spot_id: StringName,
	absolute_day: int,
	world_seed: int,
	use_bait: bool,
) -> Dictionary:
	var spot_definition: Dictionary = FishingCatalogScript.spot(spot_id)
	if spot_definition.is_empty():
		return _result(false, farm, &"unknown_fishing_spot")
	if InventoryScript.count_all(farm, ROD_ITEM) <= 0:
		return _result(false, farm, &"missing_fishing_rod")
	if use_bait and InventoryScript.count_all(farm, BAIT_ITEM) <= 0:
		return _result(false, farm, &"missing_fishing_bait")
	var current: Dictionary = _current_spot(farm, spot_id, absolute_day)
	if int(current[&"remaining_catches"]) <= 0:
		return _result(false, farm, &"fishing_spot_depleted")
	var calendar: Dictionary = farm[&"calendar_weather"] as Dictionary
	var selected: Dictionary = _select_fish(
		spot_id,
		StringName(str(calendar[&"season_id"])),
		StringName(str(calendar[&"current_weather_id"])),
		world_seed,
		absolute_day,
		int(current[&"cast_sequence"]),
		use_bait,
	)
	if selected.is_empty():
		return _result(false, farm, &"no_fish_available")
	var candidate: Dictionary = farm.duplicate(true)
	if use_bait:
		var removed: Dictionary = InventoryScript.remove_across(candidate, BAIT_ITEM, 1)
		if not bool(removed[&"ok"]):
			return _result(false, farm, &"missing_fishing_bait")
		candidate = removed[&"candidate"] as Dictionary
	var credited: Dictionary = InventoryScript.credit_with_overflow(
		candidate, selected[&"item_id"] as StringName, 1
	)
	if not bool(credited[&"ok"]):
		return _result(false, farm, &"inventory_full")
	candidate = credited[&"candidate"] as Dictionary
	current[&"cast_sequence"] = int(current[&"cast_sequence"]) + 1
	current[&"remaining_catches"] = int(current[&"remaining_catches"]) - 1
	current[&"renewal_day"] = absolute_day + 1
	_set_spot(candidate, current)
	var result: Dictionary = _result(true, candidate, &"")
	result[&"fish_id"] = selected[&"fish_id"]
	result[&"item_id"] = selected[&"item_id"]
	result[&"cast_sequence"] = current[&"cast_sequence"]
	result[&"remaining_catches"] = current[&"remaining_catches"]
	result[&"bait_used"] = use_bait
	return result


static func advance_day(farm: Dictionary, absolute_day: int) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var spots: Array = (candidate[&"fishing"][&"spots"] as Array).duplicate(true)
	for index: int in spots.size():
		var state: Dictionary = (spots[index] as Dictionary).duplicate(true)
		if absolute_day >= int(state[&"renewal_day"]):
			var definition: Dictionary = FishingCatalogScript.spot(
				StringName(str(state[&"spot_id"]))
			)
			state[&"remaining_catches"] = int(definition[&"capacity"])
			state[&"renewal_day"] = absolute_day + 1
			spots[index] = state
	(candidate[&"fishing"] as Dictionary)[&"spots"] = spots
	return candidate


static func spot_snapshot(
	farm: Dictionary, spot_id: StringName, absolute_day: int
) -> Dictionary:
	if FishingCatalogScript.spot(spot_id).is_empty():
		return {}
	return _current_spot(farm, spot_id, absolute_day)


static func _current_spot(
	farm: Dictionary, spot_id: StringName, absolute_day: int
) -> Dictionary:
	for state: Dictionary in farm[&"fishing"][&"spots"] as Array[Dictionary]:
		if StringName(str(state[&"spot_id"])) != spot_id:
			continue
		var result: Dictionary = state.duplicate(true)
		if absolute_day >= int(result[&"renewal_day"]):
			result[&"remaining_catches"] = int(
				FishingCatalogScript.spot(spot_id)[&"capacity"]
			)
			result[&"renewal_day"] = absolute_day + 1
		return result
	var definition: Dictionary = FishingCatalogScript.spot(spot_id)
	return {
		&"spot_id": str(spot_id),
		&"cast_sequence": 0,
		&"remaining_catches": int(definition[&"capacity"]),
		&"renewal_day": absolute_day + 1,
	}


static func _set_spot(farm: Dictionary, state: Dictionary) -> void:
	var spots: Array = (farm[&"fishing"][&"spots"] as Array).duplicate(true)
	var replaced: bool = false
	for index: int in spots.size():
		if str((spots[index] as Dictionary)[&"spot_id"]) == str(state[&"spot_id"]):
			spots[index] = state.duplicate(true)
			replaced = true
			break
	if not replaced:
		spots.append(state.duplicate(true))
	spots.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return str(first[&"spot_id"]) < str(second[&"spot_id"])
	)
	(farm[&"fishing"] as Dictionary)[&"spots"] = spots


static func _select_fish(
	spot_id: StringName,
	season_id: StringName,
	weather_id: StringName,
	world_seed: int,
	absolute_day: int,
	cast_sequence: int,
	use_bait: bool,
) -> Dictionary:
	var pool: Array[Dictionary] = FishingCatalogScript.eligible(
		spot_id, season_id, weather_id
	)
	var total: int = 0
	for record: Dictionary in pool:
		total += int(record[&"weight"]) + (int(record[&"bait_bonus"]) if use_bait else 0)
	if total <= 0:
		return {}
	var value: int = world_seed ^ absolute_day * 1_103_515_245
	value ^= cast_sequence * 83_492_791
	for index: int in String(spot_id).length():
		value = value * 33 ^ String(spot_id).unicode_at(index)
	var roll: int = posmod(value ^ (value >> 16), total)
	for record: Dictionary in pool:
		var weight: int = int(record[&"weight"])
		weight += int(record[&"bait_bonus"]) if use_bait else 0
		if roll < weight:
			return record.duplicate(true)
		roll -= weight
	return pool.back().duplicate(true) if not pool.is_empty() else {}


static func _result(ok: bool, farm: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": farm.duplicate(true), &"reason": reason}
