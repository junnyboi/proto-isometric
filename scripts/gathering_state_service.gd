extends RefCounted

const CatalogScript: GDScript = preload("res://scripts/resource_deposit_catalog.gd")
const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")


static func effective(farm: Dictionary, source: Dictionary, absolute_day: int) -> Dictionary:
	if not CatalogScript.validate_source(source):
		return {}
	var result: Dictionary = {
		&"source_id": str(source[&"source_id"]), &"capacity": int(source[&"capacity"]),
		&"remaining_charges": int(source[&"capacity"]), &"renewal_day": 0,
		&"reserved_by": "",
	}
	for delta: Dictionary in _section(farm)[&"resource_deltas"] as Array[Dictionary]:
		if delta[&"source_id"] == str(source[&"source_id"]):
			result[&"remaining_charges"] = int(delta[&"remaining_charges"])
			result[&"renewal_day"] = int(delta[&"renewal_day"])
			result[&"reserved_by"] = str(delta[&"reserved_by"])
			break
	if (
		bool(source[&"renewable"])
		and int(result[&"remaining_charges"]) == 0
		and int(result[&"renewal_day"]) > 0
		and absolute_day >= int(result[&"renewal_day"])
	):
		result[&"remaining_charges"] = int(source[&"capacity"])
		result[&"renewal_day"] = 0
	result[&"phase"] = _phase(source, result, absolute_day)
	return result


static func gather(
	farm: Dictionary,
	source: Dictionary,
	absolute_day: int,
	actor_kind: StringName,
	actor_id: String,
) -> Dictionary:
	var current: Dictionary = effective(farm, source, absolute_day)
	if current.is_empty():
		return _failure(farm, &"invalid_source")
	if int(current[&"remaining_charges"]) <= 0:
		return _failure(farm, &"source_exhausted")
	if actor_kind not in [&"manual", &"building"]:
		return _failure(farm, &"invalid_gather_actor")
	var reserved_by: String = str(current[&"reserved_by"])
	if actor_kind == &"manual" and not reserved_by.is_empty():
		return _failure(farm, &"source_reserved")
	if actor_kind == &"building" and (actor_id.is_empty() or reserved_by != actor_id):
		return _failure(farm, &"reservation_mismatch")
	if actor_kind == &"building":
		var authority_reason: StringName = _building_authority_reason(farm, source, actor_id)
		if authority_reason != &"":
			return _failure(farm, authority_reason)
	var next: Dictionary = current.duplicate(true)
	next[&"remaining_charges"] = int(current[&"remaining_charges"]) - 1
	if int(next[&"remaining_charges"]) == 0 and bool(source[&"renewable"]):
		next[&"renewal_day"] = absolute_day + int(source[&"renewal_days"])
	return _replace(farm, source, next, &"gathered")


static func set_reservation(
	farm: Dictionary,
	source: Dictionary,
	absolute_day: int,
	building_id: String,
) -> Dictionary:
	var current: Dictionary = effective(farm, source, absolute_day)
	if current.is_empty():
		return _failure(farm, &"invalid_source")
	var authority_reason: StringName = _building_authority_reason(farm, source, building_id)
	if authority_reason != &"":
		return _failure(farm, authority_reason)
	if not str(current[&"reserved_by"]).is_empty() and current[&"reserved_by"] != building_id:
		return _failure(farm, &"source_reserved")
	current[&"reserved_by"] = building_id
	return _replace(farm, source, current, &"reserved")


static func clear_reservation(
	farm: Dictionary,
	source: Dictionary,
	absolute_day: int,
	building_id: String,
) -> Dictionary:
	var current: Dictionary = effective(farm, source, absolute_day)
	if current.is_empty() or str(current[&"reserved_by"]) != building_id:
		return _failure(farm, &"reservation_mismatch")
	current[&"reserved_by"] = ""
	return _replace(farm, source, current, &"reservation_cleared")


static func advance_day(
	farm: Dictionary,
	world_seed: int,
	absolute_day: int,
	source_resolver: Callable = Callable(),
) -> Dictionary:
	var source_farm: Dictionary = farm.duplicate(true)
	var section: Dictionary = _section(source_farm)
	var next_deltas: Array[Dictionary] = []
	for delta: Dictionary in section[&"resource_deltas"] as Array[Dictionary]:
		var source_id: String = str(delta[&"source_id"])
		var cell: Vector2i = CatalogScript.cell_from_id(source_id)
		var source: Dictionary = (
			source_resolver.call(cell) as Dictionary
			if source_resolver.is_valid()
			else CatalogScript.project_at(cell, world_seed)
		)
		if source.is_empty() or source[&"source_id"] != source_id:
			return _failure(farm, &"orphan_resource_delta")
		var current: Dictionary = effective(source_farm, source, absolute_day)
		if not _is_default(source, current):
			next_deltas.append(_delta(current))
	section[&"resource_deltas"] = next_deltas
	source_farm[&"gathering"] = SectionsScript.validate_gathering(section)
	var normalized: Dictionary = FarmSchemaScript.validate(source_farm)
	return {
		&"ok": not normalized.is_empty(),
		&"candidate": normalized if not normalized.is_empty() else farm.duplicate(true),
		&"reason": &"" if not normalized.is_empty() else &"invalid_gathering_state",
	}


static func _replace(
	farm: Dictionary,
	source: Dictionary,
	state: Dictionary,
	reason: StringName,
) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var section: Dictionary = _section(candidate)
	var deltas: Array[Dictionary] = []
	for delta: Dictionary in section[&"resource_deltas"] as Array[Dictionary]:
		if delta[&"source_id"] != str(source[&"source_id"]):
			deltas.append(delta.duplicate(true))
	if not _is_default(source, state):
		deltas.append(_delta(state))
	deltas.sort_custom(_delta_precedes)
	if deltas.size() > SectionsScript.MAX_RESOURCE_DELTAS:
		return _failure(farm, &"resource_delta_cap_reached")
	section[&"resource_deltas"] = deltas
	candidate[&"gathering"] = SectionsScript.validate_gathering(section)
	var normalized: Dictionary = FarmSchemaScript.validate(candidate)
	return {
		&"ok": not normalized.is_empty(),
		&"candidate": normalized if not normalized.is_empty() else farm.duplicate(true),
		&"reason": reason if not normalized.is_empty() else &"invalid_gathering_state",
		&"source_state": state.duplicate(true),
	}


static func _section(farm: Dictionary) -> Dictionary:
	return (farm.get(&"gathering", SectionsScript.neutral_gathering()) as Dictionary).duplicate(true)


static func _building_authority_reason(
	farm: Dictionary, source: Dictionary, building_id: String
) -> StringName:
	if building_id.is_empty():
		return &"unknown_building"
	var homestead_value: Variant = farm.get(&"homestead")
	if not homestead_value is Dictionary:
		return &"unknown_building"
	var construction_value: Variant = (homestead_value as Dictionary).get(&"construction")
	if not construction_value is Dictionary:
		return &"unknown_building"
	var buildings: Array[Dictionary] = (
		(construction_value as Dictionary).get(&"buildings", []) as Array[Dictionary]
	)
	for building: Dictionary in buildings:
		if str(building[&"instance_id"]) != building_id:
			continue
		if str(building[&"state"]) != "complete":
			return &"building_incomplete"
		var blueprint: StringName = StringName(str(building[&"blueprint_id"]))
		var level: int = int(building[&"level"])
		if not CatalogScript.compatible(source, blueprint, level):
			return &"source_incompatible"
		var encoded: Array = building[&"anchor"] as Array
		var anchor: Vector2i = Vector2i(int(encoded[0]), int(encoded[1]))
		var source_cell: Vector2i = source[&"cell"] as Vector2i
		var distance: int = maxi(absi(anchor.x - source_cell.x), absi(anchor.y - source_cell.y))
		return &"" if distance <= CatalogScript.effective_range(level) else &"source_out_of_range"
	return &"unknown_building"


static func _delta(state: Dictionary) -> Dictionary:
	return {
		&"source_id": str(state[&"source_id"]),
		&"remaining_charges": int(state[&"remaining_charges"]),
		&"renewal_day": int(state[&"renewal_day"]),
		&"reserved_by": str(state[&"reserved_by"]),
	}


static func _is_default(source: Dictionary, state: Dictionary) -> bool:
	return (
		int(state[&"remaining_charges"]) == int(source[&"capacity"])
		and int(state[&"renewal_day"]) == 0
		and str(state[&"reserved_by"]).is_empty()
	)


static func _phase(source: Dictionary, state: Dictionary, absolute_day: int) -> StringName:
	var remaining: int = int(state[&"remaining_charges"])
	var capacity: int = int(source[&"capacity"])
	if remaining >= capacity:
		return &"rich"
	if remaining > 0:
		return &"depleted"
	if not bool(source[&"renewable"]):
		return &"exhausted"
	return &"renewing" if absolute_day < int(state[&"renewal_day"]) else &"rich"


static func _failure(farm: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": false, &"candidate": farm.duplicate(true), &"reason": reason}


static func _delta_precedes(first: Dictionary, second: Dictionary) -> bool:
	return str(first[&"source_id"]) < str(second[&"source_id"])
