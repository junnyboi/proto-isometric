extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const STATE_VERSION: int = 1
const MAX_YEAR: int = 9_999
const MAX_DAY: int = 366
const MAX_MINUTE_OF_DAY: int = 1_439
const MAX_MONEY: int = 1_000_000_000
const MAX_PLOTS: int = 100_000
const MAX_INVENTORIES: int = 1_024
const MAX_SHIPPING_ENTRIES: int = 10_000
const MAX_PLACED_ENTITIES: int = 100_000
const MAX_MACHINES: int = 10_000
const MAX_FACILITIES: int = 1_024
const MAX_RESIDENTS: int = 1_024
const MAX_RUINS: int = 10_000
const MAX_TOOL_UPGRADES: int = 1_024
const MAX_ECOLOGY_DELTAS: int = 100_000
const MAX_BOSS_CLEARS: int = 1_024
const MAX_MIGRATION_TOKENS: int = 8
const MAX_DAY_TOKENS: int = 64

const SEASON_NEUTRAL: String = "season.neutral"
const WEATHER_NEUTRAL: String = "weather.neutral"


static func make_neutral(
	mode: StringName = RuntimeIdsScript.MODE_FRESH_FARM, migrated_from_v3: bool = false
) -> Dictionary:
	var migration_tokens: Array[String] = []
	if migrated_from_v3:
		migration_tokens.append(String(RuntimeIdsScript.MIGRATION_FARM_V3_TO_V4))
	return {
		&"state_version": STATE_VERSION,
		&"mode": String(mode),
		&"calendar_weather":
		{
			&"state_version": STATE_VERSION,
			&"year": 1,
			&"season_id": SEASON_NEUTRAL,
			&"day": 1,
			&"minute_of_day": 0,
			&"current_weather_id": WEATHER_NEUTRAL,
			&"forecast_weather_id": WEATHER_NEUTRAL,
			&"day_token": "",
		},
		&"plots": [],
		&"inventories": [],
		&"economy": {&"state_version": STATE_VERSION, &"money": 0, &"shipping": []},
		&"placed_entities": [],
		&"machines": [],
		&"homestead":
		{
			&"state_version": STATE_VERSION,
			&"facilities": [],
			&"residents": [],
			&"ruins": [],
		},
		&"tools":
		{
			&"state_version": STATE_VERSION,
			&"equipped_tool_id": "",
			&"upgrade_ids": [],
		},
		&"ecology":
		{
			&"state_version": STATE_VERSION,
			&"deltas": [],
			&"boss_first_clear_ids": [],
		},
		&"migration_tokens": migration_tokens,
		&"day_tokens": [],
	}


static func validate(snapshot: Variant) -> Dictionary:
	if not snapshot is Dictionary:
		return {}
	var farm: Dictionary = snapshot as Dictionary
	if not _exact_keys(
		farm,
		[
			&"state_version",
			&"mode",
			&"calendar_weather",
			&"plots",
			&"inventories",
			&"economy",
			&"placed_entities",
			&"machines",
			&"homestead",
			&"tools",
			&"ecology",
			&"migration_tokens",
			&"day_tokens",
		],
	):
		return {}
	var state_version: Variant = _json_integer(
		farm.get(&"state_version"), STATE_VERSION, STATE_VERSION
	)
	var mode: Variant = farm.get(&"mode")
	if (
		state_version == null
		or (not mode is String and not mode is StringName)
		or StringName(str(mode)) not in RuntimeIdsScript.gameplay_mode_ids()
	):
		return {}
	var calendar_weather: Dictionary = _normalize_calendar(farm.get(&"calendar_weather"))
	var economy: Dictionary = _normalize_economy(farm.get(&"economy"))
	var homestead: Dictionary = _normalize_homestead(farm.get(&"homestead"))
	var tools: Dictionary = _normalize_tools(farm.get(&"tools"))
	var ecology: Dictionary = _normalize_ecology(farm.get(&"ecology"))
	var plots: Variant = _normalize_empty_array(farm.get(&"plots"), MAX_PLOTS)
	var inventories: Variant = _normalize_empty_array(farm.get(&"inventories"), MAX_INVENTORIES)
	var placed: Variant = _normalize_empty_array(farm.get(&"placed_entities"), MAX_PLACED_ENTITIES)
	var machines: Variant = _normalize_empty_array(farm.get(&"machines"), MAX_MACHINES)
	var migration_tokens: Variant = _normalize_migration_tokens(farm.get(&"migration_tokens"))
	var day_tokens: Variant = _normalize_empty_array(farm.get(&"day_tokens"), MAX_DAY_TOKENS)
	if (
		calendar_weather.is_empty()
		or economy.is_empty()
		or homestead.is_empty()
		or tools.is_empty()
		or ecology.is_empty()
		or plots == null
		or inventories == null
		or placed == null
		or machines == null
		or migration_tokens == null
		or day_tokens == null
	):
		return {}
	return {
		&"state_version": STATE_VERSION,
		&"mode": str(mode),
		&"calendar_weather": calendar_weather,
		&"plots": plots,
		&"inventories": inventories,
		&"economy": economy,
		&"placed_entities": placed,
		&"machines": machines,
		&"homestead": homestead,
		&"tools": tools,
		&"ecology": ecology,
		&"migration_tokens": migration_tokens,
		&"day_tokens": day_tokens,
	}


static func canonical_json(snapshot: Variant) -> String:
	var normalized: Dictionary = validate(snapshot)
	return "" if normalized.is_empty() else JSON.stringify(normalized, "", true, true)


static func mode_of(snapshot: Variant) -> StringName:
	var normalized: Dictionary = validate(snapshot)
	return &"" if normalized.is_empty() else StringName(str(normalized[&"mode"]))


static func _normalize_calendar(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var calendar: Dictionary = value as Dictionary
	if not _exact_keys(
		calendar,
		[
			&"state_version",
			&"year",
			&"season_id",
			&"day",
			&"minute_of_day",
			&"current_weather_id",
			&"forecast_weather_id",
			&"day_token",
		],
	):
		return {}
	var state_version: Variant = _json_integer(
		calendar.get(&"state_version"), STATE_VERSION, STATE_VERSION
	)
	var year: Variant = _json_integer(calendar.get(&"year"), 1, MAX_YEAR)
	var day: Variant = _json_integer(calendar.get(&"day"), 1, MAX_DAY)
	var minute: Variant = _json_integer(calendar.get(&"minute_of_day"), 0, MAX_MINUTE_OF_DAY)
	if (
		state_version == null
		or year == null
		or day == null
		or minute == null
		or calendar.get(&"season_id") != SEASON_NEUTRAL
		or calendar.get(&"current_weather_id") != WEATHER_NEUTRAL
		or calendar.get(&"forecast_weather_id") != WEATHER_NEUTRAL
		or calendar.get(&"day_token") != ""
	):
		return {}
	return {
		&"state_version": STATE_VERSION,
		&"year": int(year),
		&"season_id": SEASON_NEUTRAL,
		&"day": int(day),
		&"minute_of_day": int(minute),
		&"current_weather_id": WEATHER_NEUTRAL,
		&"forecast_weather_id": WEATHER_NEUTRAL,
		&"day_token": "",
	}


static func _normalize_economy(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var economy: Dictionary = value as Dictionary
	if not _exact_keys(economy, [&"state_version", &"money", &"shipping"]):
		return {}
	var state_version: Variant = _json_integer(
		economy.get(&"state_version"), STATE_VERSION, STATE_VERSION
	)
	var money: Variant = _json_integer(economy.get(&"money"), 0, MAX_MONEY)
	var shipping: Variant = _normalize_empty_array(economy.get(&"shipping"), MAX_SHIPPING_ENTRIES)
	if state_version == null or money == null or shipping == null:
		return {}
	return {&"state_version": STATE_VERSION, &"money": int(money), &"shipping": shipping}


static func _normalize_homestead(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var homestead: Dictionary = value as Dictionary
	if not _exact_keys(homestead, [&"state_version", &"facilities", &"residents", &"ruins"]):
		return {}
	var state_version: Variant = _json_integer(
		homestead.get(&"state_version"), STATE_VERSION, STATE_VERSION
	)
	var facilities: Variant = _normalize_empty_array(homestead.get(&"facilities"), MAX_FACILITIES)
	var residents: Variant = _normalize_empty_array(homestead.get(&"residents"), MAX_RESIDENTS)
	var ruins: Variant = _normalize_empty_array(homestead.get(&"ruins"), MAX_RUINS)
	if state_version == null or facilities == null or residents == null or ruins == null:
		return {}
	return {
		&"state_version": STATE_VERSION,
		&"facilities": facilities,
		&"residents": residents,
		&"ruins": ruins,
	}


static func _normalize_tools(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var tools: Dictionary = value as Dictionary
	if not _exact_keys(tools, [&"state_version", &"equipped_tool_id", &"upgrade_ids"]):
		return {}
	var state_version: Variant = _json_integer(
		tools.get(&"state_version"), STATE_VERSION, STATE_VERSION
	)
	var upgrades: Variant = _normalize_empty_array(tools.get(&"upgrade_ids"), MAX_TOOL_UPGRADES)
	if state_version == null or tools.get(&"equipped_tool_id") != "" or upgrades == null:
		return {}
	return {
		&"state_version": STATE_VERSION,
		&"equipped_tool_id": "",
		&"upgrade_ids": upgrades,
	}


static func _normalize_ecology(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var ecology: Dictionary = value as Dictionary
	if not _exact_keys(ecology, [&"state_version", &"deltas", &"boss_first_clear_ids"]):
		return {}
	var state_version: Variant = _json_integer(
		ecology.get(&"state_version"), STATE_VERSION, STATE_VERSION
	)
	var deltas: Variant = _normalize_empty_array(ecology.get(&"deltas"), MAX_ECOLOGY_DELTAS)
	var boss_clears: Variant = _normalize_empty_array(
		ecology.get(&"boss_first_clear_ids"), MAX_BOSS_CLEARS
	)
	if state_version == null or deltas == null or boss_clears == null:
		return {}
	return {
		&"state_version": STATE_VERSION,
		&"deltas": deltas,
		&"boss_first_clear_ids": boss_clears,
	}


static func _normalize_migration_tokens(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_MIGRATION_TOKENS:
		return null
	var result: Array[String] = []
	for raw_token: Variant in value as Array:
		if not raw_token is String and not raw_token is StringName:
			return null
		var token: StringName = StringName(str(raw_token))
		if token != RuntimeIdsScript.MIGRATION_FARM_V3_TO_V4 or String(token) in result:
			return null
		result.append(String(token))
	result.sort()
	return result


static func _normalize_empty_array(value: Variant, maximum_size: int) -> Variant:
	if (
		not value is Array
		or (value as Array).size() > maximum_size
		or not (value as Array).is_empty()
	):
		return null
	return []


static func _json_integer(value: Variant, minimum: int, maximum: int) -> Variant:
	if not value is int and not value is float:
		return null
	var number: float = float(value)
	if not is_finite(number) or number != floor(number) or number < minimum or number > maximum:
		return null
	return int(number)


static func _exact_keys(value: Dictionary, expected: Array[StringName]) -> bool:
	if value.size() != expected.size():
		return false
	for key: StringName in expected:
		if not value.has(key):
			return false
	return true
