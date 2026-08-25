extends RefCounted

const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")

const STATE_VERSION: int = 1
const MAX_HABITATS: int = 12
const MAX_DELTAS: int = 64
const MAX_POPULATION: int = 4
const MAX_TRUST: int = 100
const MAX_DAY: int = 559_944
const LARGE: StringName = &"territorial_large"
const NEST: StringName = &"nest_tiny"
const HERD: StringName = &"friendly_herd"
const RECORD_HABITAT: StringName = &"habitat"
const RECORD_TOKEN: StringName = &"token"
const IRONJAW_CLEAR_ID: StringName = &"boss.ironjaw.first_clear"
const DELTA_KEYS: Array[StringName] = [
	&"record_type", &"stable_id", &"value_a", &"value_b", &"day", &"available_day", &"token"
]
const HABITATS: Array[Dictionary] = [
	{
		"habitat_id": &"habitat.desert.ironjaw_range",
		"biome": &"desert",
		"category": LARGE,
		"kind": &"sandworm",
		"anchor": Vector2i(0, 42),
		"capacity": 1,
		"leash": 8,
		"schedule": Vector2i(360, 1260),
		"respawn_days": 3,
		"yield_item_id": &"item.wild.dune_sinew"
	},
	{
		"habitat_id": &"habitat.desert.glass_nest",
		"biome": &"desert",
		"category": NEST,
		"kind": &"glassback_scarab",
		"anchor": Vector2i(5, 34),
		"capacity": 4,
		"leash": 5,
		"schedule": Vector2i(300, 1320),
		"respawn_days": 2,
		"yield_item_id": &"item.wild.glass_chitin"
	},
	{
		"habitat_id": &"habitat.desert.dune_herd",
		"biome": &"desert",
		"category": HERD,
		"kind": &"dune_grazer",
		"anchor": Vector2i(-8, 32),
		"capacity": 4,
		"leash": 9,
		"schedule": Vector2i(420, 1140),
		"respawn_days": 1,
		"yield_item_id": &"item.wild.dune_fiber"
	},
	{
		"habitat_id": &"habitat.oasis.skimmer_pool",
		"biome": &"oasis",
		"category": LARGE,
		"kind": &"mud_skimmer",
		"anchor": Vector2i(45, 10),
		"capacity": 1,
		"leash": 7,
		"schedule": Vector2i(300, 1200),
		"respawn_days": 3,
		"yield_item_id": &"item.wild.mire_membrane"
	},
	{
		"habitat_id": &"habitat.oasis.tick_nest",
		"biome": &"oasis",
		"category": NEST,
		"kind": &"mire_tick",
		"anchor": Vector2i(38, 16),
		"capacity": 4,
		"leash": 5,
		"schedule": Vector2i(360, 1260),
		"respawn_days": 2,
		"yield_item_id": &"item.wild.mire_spore"
	},
	{
		"habitat_id": &"habitat.oasis.reedback_herd",
		"biome": &"oasis",
		"category": HERD,
		"kind": &"reedback",
		"anchor": Vector2i(36, 4),
		"capacity": 4,
		"leash": 9,
		"schedule": Vector2i(420, 1080),
		"respawn_days": 1,
		"yield_item_id": &"item.wild.reed_resin"
	},
	{
		"habitat_id": &"habitat.frozen.rime_range",
		"biome": &"frozen",
		"category": LARGE,
		"kind": &"rime_stalker",
		"anchor": Vector2i(8, -38),
		"capacity": 1,
		"leash": 8,
		"schedule": Vector2i(0, 1439),
		"respawn_days": 4,
		"yield_item_id": &"item.wild.rime_lens"
	},
	{
		"habitat_id": &"habitat.frozen.shard_nest",
		"biome": &"frozen",
		"category": NEST,
		"kind": &"rime_shardling",
		"anchor": Vector2i(-2, -31),
		"capacity": 4,
		"leash": 5,
		"schedule": Vector2i(0, 1439),
		"respawn_days": 3,
		"yield_item_id": &"item.wild.rime_shard"
	},
	{
		"habitat_id": &"habitat.frozen.rimehorn_herd",
		"biome": &"frozen",
		"category": HERD,
		"kind": &"rimehorn",
		"anchor": Vector2i(15, -29),
		"capacity": 4,
		"leash": 9,
		"schedule": Vector2i(480, 1020),
		"respawn_days": 1,
		"yield_item_id": &"item.wild.rime_wool"
	},
	{
		"habitat_id": &"habitat.lava.cinder_range",
		"biome": &"lava",
		"category": LARGE,
		"kind": &"cinder_crawler",
		"anchor": Vector2i(-39, 8),
		"capacity": 1,
		"leash": 7,
		"schedule": Vector2i(0, 1439),
		"respawn_days": 4,
		"yield_item_id": &"item.wild.cinder_gland"
	},
	{
		"habitat_id": &"habitat.lava.skitter_nest",
		"biome": &"lava",
		"category": NEST,
		"kind": &"ember_skitter",
		"anchor": Vector2i(-31, 16),
		"capacity": 4,
		"leash": 5,
		"schedule": Vector2i(0, 1439),
		"respawn_days": 3,
		"yield_item_id": &"item.wild.ember_shell"
	},
	{
		"habitat_id": &"habitat.lava.ember_herd",
		"biome": &"lava",
		"category": HERD,
		"kind": &"ember_ram",
		"anchor": Vector2i(-29, 2),
		"capacity": 4,
		"leash": 9,
		"schedule": Vector2i(360, 960),
		"respawn_days": 1,
		"yield_item_id": &"item.wild.ember_fleece"
	},
]


static func validate_catalog() -> bool:
	var seen: Dictionary = {}
	var total: int = 0
	for habitat: Dictionary in HABITATS:
		var habitat_id: StringName = habitat[&"habitat_id"] as StringName
		var capacity: int = int(habitat[&"capacity"])
		if seen.has(habitat_id) or capacity < 1 or capacity > MAX_POPULATION:
			return false
		if habitat[&"category"] not in [LARGE, NEST, HERD] or int(habitat[&"leash"]) > 12:
			return false
		seen[habitat_id] = true
		total += capacity
	return seen.size() == MAX_HABITATS and total == 36


static func habitat(habitat_id: StringName) -> Dictionary:
	for definition: Dictionary in HABITATS:
		if definition[&"habitat_id"] == habitat_id:
			return definition.duplicate(true)
	return {}


static func population_snapshot(
	farm: Dictionary, world_seed: int, absolute_day: int, minute: int
) -> Array[Dictionary]:
	var deltas: Dictionary = _deltas_by_id(
		(farm.get(&"ecology", {}) as Dictionary).get(&"deltas", [])
	)
	var result: Array[Dictionary] = []
	for definition: Dictionary in HABITATS:
		var record: Dictionary = definition.duplicate(true)
		var habitat_id: StringName = definition[&"habitat_id"] as StringName
		var delta: Dictionary = deltas.get(String(habitat_id), {}) as Dictionary
		var population: int = int(definition[&"capacity"])
		var trust: int = 0
		var last_yield_day: int = 0
		var respawn_day: int = 0
		if not delta.is_empty():
			population = int(delta[&"value_a"])
			trust = int(delta[&"value_b"])
			last_yield_day = int(delta[&"day"])
			respawn_day = int(delta[&"available_day"])
			if population == 0 and respawn_day > 0 and absolute_day >= respawn_day:
				population = int(definition[&"capacity"])
				respawn_day = 0
		record[&"anchor"] = _seeded_anchor(definition, world_seed)
		record[&"population"] = population
		record[&"trust"] = trust
		record[&"last_yield_day"] = last_yield_day
		record[&"respawn_day"] = respawn_day
		record[&"active"] = (
			population > 0 and _schedule_contains(definition[&"schedule"] as Vector2i, minute)
		)
		record[&"trigger"] = &"habitat_entry"
		result.append(record)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"habitat_id"]) < str(b[&"habitat_id"])
	)
	return result


static func deplete(
	farm: Dictionary, habitat_id: StringName, count: int, absolute_day: int
) -> Dictionary:
	var definition: Dictionary = habitat(habitat_id)
	if definition.is_empty() or definition[&"category"] == HERD or count <= 0:
		return _result(false, farm, &"invalid_depletion")
	var current: Dictionary = _habitat_delta(farm, definition)
	var remaining: int = maxi(int(current[&"value_a"]) - count, 0)
	current[&"value_a"] = remaining
	current[&"available_day"] = (
		absolute_day + int(definition[&"respawn_days"]) if remaining == 0 else 0
	)
	return _replace_delta(farm, current)


static func interact_herd(
	farm: Dictionary, habitat_id: StringName, absolute_day: int
) -> Dictionary:
	var definition: Dictionary = habitat(habitat_id)
	if definition.is_empty() or definition[&"category"] != HERD or absolute_day < 1:
		return _result(false, farm, &"invalid_herd")
	var delta: Dictionary = _habitat_delta(farm, definition)
	delta[&"value_b"] = mini(int(delta[&"value_b"]) + 25, MAX_TRUST)
	var candidate: Dictionary = farm.duplicate(true)
	var yielded: bool = int(delta[&"value_b"]) >= 25 and int(delta[&"day"]) != absolute_day
	if yielded:
		var credited: Dictionary = InventoryServiceScript.credit_with_overflow(
			candidate, definition[&"yield_item_id"] as StringName, 1
		)
		if not bool(credited[&"ok"]):
			return _result(false, farm, &"inventory_full")
		candidate = credited[&"candidate"] as Dictionary
		delta[&"day"] = absolute_day
	var replaced: Dictionary = _replace_delta(candidate, delta)
	replaced[&"yielded"] = yielded
	replaced[&"trust"] = int(delta[&"value_b"])
	return replaced


static func add_token(farm: Dictionary, token: String) -> Dictionary:
	if not _valid_token(token):
		return _result(false, farm, &"invalid_token")
	var stable_id: String = "token:%s" % token
	for record: Dictionary in (
		(farm.get(&"ecology", {}) as Dictionary).get(&"deltas", []) as Array[Dictionary]
	):
		if str(record[&"stable_id"]) == stable_id:
			return _result(false, farm, &"token_already_applied")
	return _replace_delta(farm, _make_token(stable_id, token))


static func has_token(farm: Dictionary, token: String) -> bool:
	for record: Dictionary in (
		(farm.get(&"ecology", {}) as Dictionary).get(&"deltas", []) as Array[Dictionary]
	):
		if record[&"record_type"] == String(RECORD_TOKEN) and str(record[&"token"]) == token:
			return true
	return false


static func normalize_deltas(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_DELTAS:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw: Variant in value as Array:
		var record: Dictionary = raw as Dictionary if raw is Dictionary else {}
		if not _exact_keys(record, DELTA_KEYS):
			return null
		var record_type: StringName = StringName(str(record[&"record_type"]))
		var stable_id: String = str(record[&"stable_id"])
		var value_a: Variant = _integer(record[&"value_a"], 0, MAX_POPULATION)
		var value_b: Variant = _integer(record[&"value_b"], 0, MAX_TRUST)
		var day: Variant = _integer(record[&"day"], 0, MAX_DAY)
		var available: Variant = _integer(record[&"available_day"], 0, MAX_DAY)
		var token: String = str(record[&"token"])
		if (
			seen.has(stable_id)
			or stable_id.is_empty()
			or stable_id.length() > 160
			or value_a == null
			or value_b == null
			or day == null
			or available == null
		):
			return null
		if record_type == RECORD_HABITAT:
			var definition: Dictionary = habitat(StringName(stable_id))
			if definition.is_empty() or token != "" or int(value_a) > int(definition[&"capacity"]):
				return null
		elif record_type == RECORD_TOKEN:
			if (
				stable_id != "token:%s" % token
				or not _valid_token(token)
				or int(value_a) != 0
				or int(value_b) != 0
				or int(day) != 0
				or int(available) != 0
			):
				return null
		else:
			return null
		seen[stable_id] = true
		result.append(
			{
				&"record_type": String(record_type),
				&"stable_id": stable_id,
				&"value_a": int(value_a),
				&"value_b": int(value_b),
				&"day": int(day),
				&"available_day": int(available),
				&"token": token
			}
		)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"stable_id"]) < str(b[&"stable_id"])
	)
	return result


static func normalize_boss_clears(value: Variant, maximum: int) -> Variant:
	if not value is Array or (value as Array).size() > maximum:
		return null
	var result: Array[String] = []
	for raw: Variant in value as Array:
		var clear_id: String = str(raw)
		if clear_id != String(IRONJAW_CLEAR_ID) or clear_id in result:
			return null
		result.append(clear_id)
	result.sort()
	return result


static func _habitat_delta(farm: Dictionary, definition: Dictionary) -> Dictionary:
	var habitat_id: String = str(definition[&"habitat_id"])
	for record: Dictionary in (
		(farm.get(&"ecology", {}) as Dictionary).get(&"deltas", []) as Array[Dictionary]
	):
		if str(record[&"stable_id"]) == habitat_id:
			return record.duplicate(true)
	return {
		&"record_type": String(RECORD_HABITAT),
		&"stable_id": habitat_id,
		&"value_a": int(definition[&"capacity"]),
		&"value_b": 0,
		&"day": 0,
		&"available_day": 0,
		&"token": ""
	}


static func _replace_delta(farm: Dictionary, delta: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var ecology: Dictionary = candidate.get(&"ecology", {}) as Dictionary
	var deltas: Array = (ecology.get(&"deltas", []) as Array).duplicate(true)
	var replaced: bool = false
	for index: int in deltas.size():
		if str((deltas[index] as Dictionary)[&"stable_id"]) == str(delta[&"stable_id"]):
			deltas[index] = delta.duplicate(true)
			replaced = true
			break
	if not replaced:
		if deltas.size() >= MAX_DELTAS:
			return _result(false, farm, &"ecology_delta_cap")
		deltas.append(delta.duplicate(true))
	var normalized: Variant = normalize_deltas(deltas)
	if normalized == null:
		return _result(false, farm, &"invalid_ecology_delta")
	ecology[&"deltas"] = normalized
	candidate[&"ecology"] = ecology
	return _result(true, candidate, &"")


static func _deltas_by_id(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	for record: Dictionary in value as Array[Dictionary]:
		if record[&"record_type"] == String(RECORD_HABITAT):
			result[str(record[&"stable_id"])] = record
	return result


static func _seeded_anchor(definition: Dictionary, seed: int) -> Vector2i:
	var base: Vector2i = definition[&"anchor"] as Vector2i
	var salt: int = str(definition[&"habitat_id"]).hash() ^ seed
	return base + Vector2i(posmod(salt, 3) - 1, posmod(salt >> 4, 3) - 1)


static func _schedule_contains(schedule: Vector2i, minute: int) -> bool:
	return minute >= schedule.x and minute <= schedule.y


static func _make_token(stable_id: String, token: String) -> Dictionary:
	return {
		&"record_type": String(RECORD_TOKEN),
		&"stable_id": stable_id,
		&"value_a": 0,
		&"value_b": 0,
		&"day": 0,
		&"available_day": 0,
		&"token": token
	}


static func _valid_token(token: String) -> bool:
	return (
		token.length() <= 128
		and (
			token.begins_with("capability:")
			or token.begins_with("hazard:")
			or token.begins_with("ruin:")
		)
	)


static func _integer(value: Variant, minimum: int, maximum: int) -> Variant:
	if not value is int and not value is float:
		return null
	var number: float = float(value)
	return (
		int(number)
		if is_finite(number) and number == floor(number) and number >= minimum and number <= maximum
		else null
	)


static func _exact_keys(value: Dictionary, expected: Array[StringName]) -> bool:
	if value.size() != expected.size():
		return false
	for key: StringName in expected:
		if not value.has(key):
			return false
	return true


static func _result(ok: bool, farm: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": farm.duplicate(true), &"reason": reason}
