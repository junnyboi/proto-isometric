extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const MOSSBACK_ID: StringName = RuntimeIdsScript.LIVESTOCK_MOSSBACK_ID
const COILHEN_ID: StringName = RuntimeIdsScript.LIVESTOCK_COILHEN_ID
const RUSTSNOUT_ID: StringName = RuntimeIdsScript.LIVESTOCK_RUSTSNOUT_ID
const SPECIES_IDS: Array[StringName] = [MOSSBACK_ID, COILHEN_ID, RUSTSNOUT_ID]
const MAX_ANIMALS: int = 12
const MAX_CARE_TOKENS: int = 64
const MAX_BOND: int = 100
const ATLAS_COLUMNS: int = 4
const ATLAS_ROWS: int = 2
const FRAME_SIZE: Vector2i = Vector2i(256, 256)
const DEFINITIONS: Array[Dictionary] = [
	{
		&"species_id": MOSSBACK_ID,
		&"display_name": "Mossback Grazer",
		&"housing_id": &"housing.home_paddock",
		&"capacity_cost": 2,
		&"feed_item_id": &"item.feed.mossgrass_fodder",
		&"product_item_id": &"item.product.mossback_milk",
		&"base_yield": 1,
		&"sprite_path": "res://assets/livestock/livestock_mossback_spritesheet.png",
		&"atlas_columns": ATLAS_COLUMNS,
		&"atlas_rows": ATLAS_ROWS,
		&"frame_size": FRAME_SIZE,
	},
	{
		&"species_id": COILHEN_ID,
		&"display_name": "Coilhen",
		&"housing_id": &"housing.greenhouse_coop",
		&"capacity_cost": 1,
		&"feed_item_id": &"item.feed.coilgrain_mix",
		&"product_item_id": &"item.product.coilhen_egg",
		&"base_yield": 1,
		&"sprite_path": "res://assets/livestock/livestock_coilhen_spritesheet.png",
		&"atlas_columns": ATLAS_COLUMNS,
		&"atlas_rows": ATLAS_ROWS,
		&"frame_size": FRAME_SIZE,
	},
	{
		&"species_id": RUSTSNOUT_ID,
		&"display_name": "Rustsnout Rooter",
		&"housing_id": &"housing.home_rooter_pen",
		&"capacity_cost": 2,
		&"feed_item_id": &"item.feed.root_mash",
		&"product_item_id": &"item.product.rustsnout_truffle",
		&"base_yield": 1,
		&"sprite_path": "res://assets/livestock/livestock_rustsnout_spritesheet.png",
		&"atlas_columns": ATLAS_COLUMNS,
		&"atlas_rows": ATLAS_ROWS,
		&"frame_size": FRAME_SIZE,
	},
]


static func ensure_default(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate.get(&"homestead", {}) as Dictionary
	if homestead.has(&"home") and not homestead.has(&"animals"):
		homestead[&"animals"] = []
		candidate[&"homestead"] = homestead
	return candidate


static func validate_definitions() -> bool:
	if DEFINITIONS.size() != 3 or SPECIES_IDS.size() != 3:
		return false
	var species: Dictionary = {}
	var assets: Dictionary = {}
	for definition_value: Dictionary in DEFINITIONS:
		if not _definition_is_valid(definition_value):
			return false
		var species_id: StringName = definition_value[&"species_id"] as StringName
		var sprite_path: String = str(definition_value[&"sprite_path"])
		if species.has(species_id) or assets.has(sprite_path):
			return false
		species[species_id] = true
		assets[sprite_path] = true
	return species.size() == 3 and assets.size() == 3


static func definition(species_id: StringName) -> Dictionary:
	for definition_value: Dictionary in DEFINITIONS:
		if definition_value[&"species_id"] == species_id:
			return definition_value.duplicate(true)
	return {}


static func presentation_hook(species_id: StringName) -> Dictionary:
	var definition_value: Dictionary = definition(species_id)
	if definition_value.is_empty():
		return {}
	var path: String = str(definition_value[&"sprite_path"])
	return {
		&"species_id": species_id,
		&"sprite_path": path,
		&"atlas_columns": ATLAS_COLUMNS,
		&"atlas_rows": ATLAS_ROWS,
		&"frame_size": FRAME_SIZE,
		&"available": ResourceLoader.exists(path),
		&"texture": load(path) as Texture2D if ResourceLoader.exists(path) else null,
	}


static func add_animal(
	farm: Dictionary, animal_id: StringName, species_id: StringName, housing_id: StringName
) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var definition_value: Dictionary = definition(species_id)
	if definition_value.is_empty() or not _valid_animal_id(String(animal_id)):
		return _result(false, source, &"invalid_animal")
	if housing_id != definition_value[&"housing_id"]:
		return _result(false, source, &"invalid_housing")
	var animals: Array = _animals(source)
	if animals.size() >= MAX_ANIMALS or not _animal(source, animal_id).is_empty():
		return _result(false, source, &"animal_capacity_or_duplicate")
	if not _housing_is_available(source, housing_id):
		return _result(false, source, &"housing_unavailable")
	var used_capacity: int = 0
	for record: Dictionary in animals as Array[Dictionary]:
		var existing: Dictionary = definition(StringName(record[&"species_id"]))
		if existing.is_empty():
			return _result(false, source, &"invalid_existing_animal")
		used_capacity += int(existing[&"capacity_cost"])
	var home: Dictionary = HomesteadServiceScript.home_services(source)
	if used_capacity + int(definition_value[&"capacity_cost"]) > int(home[&"animal_capacity"]):
		return _result(false, source, &"housing_capacity_exceeded")
	animals.append(
		{
			&"animal_id": String(animal_id),
			&"species_id": String(species_id),
			&"housing_id": String(housing_id),
			&"bond": 0,
			&"last_feed_day": 0,
			&"last_pet_day": 0,
			&"last_product_day": 0,
			&"care_tokens": [],
		}
	)
	animals.sort_custom(_id_precedes.bind(&"animal_id"))
	_set_animals(source, animals)
	return _result(true, source, &"")


static func feed(farm: Dictionary, animal_id: StringName) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var record: Dictionary = _animal(source, animal_id)
	if record.is_empty():
		return _result(false, source, &"invalid_animal")
	var day: int = _day(source)
	var token: String = _care_token("feed", animal_id, day)
	if int(record[&"last_feed_day"]) == day or token in record[&"care_tokens"]:
		return _result(false, source, &"already_fed_today")
	var definition_value: Dictionary = definition(StringName(record[&"species_id"]))
	var removed: Dictionary = InventoryServiceScript.remove_across(
		source, definition_value[&"feed_item_id"] as StringName, 1
	)
	if not bool(removed[&"ok"]):
		return _result(false, source, &"feed_missing")
	var candidate: Dictionary = removed[&"candidate"] as Dictionary
	_set_animal_value(candidate, animal_id, &"last_feed_day", day)
	_append_care_token(candidate, animal_id, token)
	return _result(true, candidate, &"")


static func pet(farm: Dictionary, animal_id: StringName) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var record: Dictionary = _animal(source, animal_id)
	if record.is_empty():
		return _result(false, source, &"invalid_animal")
	var day: int = _day(source)
	var token: String = _care_token("pet", animal_id, day)
	if int(record[&"last_pet_day"]) == day or token in record[&"care_tokens"]:
		return _result(false, source, &"already_petted_today")
	_set_animal_value(source, animal_id, &"last_pet_day", day)
	_set_animal_value(source, animal_id, &"bond", mini(int(record[&"bond"]) + 1, MAX_BOND))
	_append_care_token(source, animal_id, token)
	return _result(true, source, &"")


static func claim_product(farm: Dictionary, animal_id: StringName) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var record: Dictionary = _animal(source, animal_id)
	if record.is_empty():
		return _result(false, source, &"invalid_animal")
	var day: int = _day(source)
	var token: String = _care_token("product", animal_id, day)
	if int(record[&"last_product_day"]) == day or token in record[&"care_tokens"]:
		return _result(false, source, &"product_already_claimed")
	if int(record[&"last_feed_day"]) != day or int(record[&"last_pet_day"]) != day:
		return _result(false, source, &"care_incomplete")
	var definition_value: Dictionary = definition(StringName(record[&"species_id"]))
	var yield_count: int = int(definition_value[&"base_yield"]) + int(int(record[&"bond"]) >= 20)
	var credited: Dictionary = InventoryServiceScript.credit_with_overflow(
		source, definition_value[&"product_item_id"] as StringName, yield_count
	)
	if not bool(credited[&"ok"]):
		return _result(false, source, &"product_storage_full")
	var candidate: Dictionary = credited[&"candidate"] as Dictionary
	_set_animal_value(candidate, animal_id, &"last_product_day", day)
	_append_care_token(candidate, animal_id, token)
	var result: Dictionary = _result(true, candidate, &"")
	result[&"yield"] = yield_count
	result[&"item_id"] = definition_value[&"product_item_id"]
	return result


static func _definition_is_valid(definition_value: Dictionary) -> bool:
	if not _exact_keys(
		definition_value,
		[
			&"species_id",
			&"display_name",
			&"housing_id",
			&"capacity_cost",
			&"feed_item_id",
			&"product_item_id",
			&"base_yield",
			&"sprite_path",
			&"atlas_columns",
			&"atlas_rows",
			&"frame_size",
		],
	):
		return false
	return (
		definition_value[&"species_id"] in SPECIES_IDS
		and definition_value[&"display_name"] is String
		and str(definition_value[&"housing_id"]).begins_with("housing.")
		and int(definition_value[&"capacity_cost"]) in [1, 2]
		and definition_value[&"feed_item_id"] in ItemCatalogScript.ids()
		and definition_value[&"product_item_id"] in ItemCatalogScript.ids()
		and int(definition_value[&"base_yield"]) in [1, 2]
		and str(definition_value[&"sprite_path"]).begins_with("res://assets/livestock/")
		and int(definition_value[&"atlas_columns"]) == ATLAS_COLUMNS
		and int(definition_value[&"atlas_rows"]) == ATLAS_ROWS
		and definition_value[&"frame_size"] == FRAME_SIZE
		and ResourceLoader.exists(str(definition_value[&"sprite_path"]))
	)


static func _housing_is_available(farm: Dictionary, housing_id: StringName) -> bool:
	if housing_id != &"housing.greenhouse_coop":
		return bool(HomesteadServiceScript.home_services(farm)[&"safehouse"])
	var greenhouse: Dictionary = HomesteadServiceScript.facility_state(
		farm, HomesteadServiceScript.GREENHOUSE_ID
	)
	return bool(greenhouse.get(&"repaired", false)) and bool(greenhouse.get(&"powered", false))


static func _animals(farm: Dictionary) -> Array:
	return (
		((farm.get(&"homestead", {}) as Dictionary).get(&"animals", []) as Array)
		. duplicate(true)
	)


static func _animal(farm: Dictionary, animal_id: StringName) -> Dictionary:
	var found: Dictionary = {}
	for record: Dictionary in _animals(farm) as Array[Dictionary]:
		if StringName(record.get(&"animal_id", "")) != animal_id:
			continue
		if not found.is_empty():
			return {}
		found = record.duplicate(true)
	return found


static func _set_animals(farm: Dictionary, animals: Array) -> void:
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	homestead[&"animals"] = animals.duplicate(true)
	farm[&"homestead"] = homestead


static func _set_animal_value(
	farm: Dictionary, animal_id: StringName, key: StringName, value: Variant
) -> void:
	var animals: Array = _animals(farm)
	for index: int in animals.size():
		var record: Dictionary = animals[index] as Dictionary
		if StringName(record[&"animal_id"]) == animal_id:
			record[key] = value
			animals[index] = record
			break
	_set_animals(farm, animals)


static func _append_care_token(farm: Dictionary, animal_id: StringName, token: String) -> void:
	var record: Dictionary = _animal(farm, animal_id)
	var tokens: Array = (record[&"care_tokens"] as Array).duplicate()
	if token in tokens:
		return
	tokens.append(token)
	if tokens.size() > MAX_CARE_TOKENS:
		_remove_oldest_token(tokens)
	tokens.sort()
	_set_animal_value(farm, animal_id, &"care_tokens", tokens)


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


static func _care_token(kind: String, animal_id: StringName, day: int) -> String:
	return "care:%s:%s:%d" % [kind, animal_id, day]


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


static func _day(farm: Dictionary) -> int:
	return CalendarStateScript.absolute_day(farm[&"calendar_weather"])


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
