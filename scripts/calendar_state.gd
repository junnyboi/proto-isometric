extends RefCounted

const SEASONS: Array[StringName] = [
	&"season.spring", &"season.summer", &"season.autumn", &"season.winter"
]
const WEATHER_IDS: Array[StringName] = [
	&"weather.clear", &"weather.cloudy", &"weather.rain", &"weather.wind"
]
const DAYS_PER_SEASON: int = 14
const DEFAULT_WORLD_SEED: int = 0x48415256
const DEFAULT_DAY_REAL_MINUTES: int = 15


static func ensure_default(farm: Dictionary, world_seed: int = DEFAULT_WORLD_SEED) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var calendar: Dictionary = candidate.get(&"calendar_weather", {}) as Dictionary
	if calendar.get(&"season_id", "") != "season.neutral":
		return candidate
	calendar[&"year"] = 1
	calendar[&"season_id"] = String(SEASONS[0])
	calendar[&"day"] = 1
	calendar[&"minute_of_day"] = 360
	calendar[&"current_weather_id"] = String(weather_for(world_seed, 1))
	calendar[&"forecast_weather_id"] = String(weather_for(world_seed, 2))
	calendar[&"day_token"] = token_for(1, SEASONS[0], 1)
	candidate[&"calendar_weather"] = calendar
	return candidate


static func weather_for(world_seed: int, absolute_day: int) -> StringName:
	var value: int = world_seed ^ absolute_day * 1_103_515_245
	value = (value ^ (value >> 16)) * 2_246_822_519
	value ^= value >> 13
	var roll: int = posmod(value, 100)
	if roll < 25:
		return &"weather.rain"
	if roll < 45:
		return &"weather.cloudy"
	if roll < 60:
		return &"weather.wind"
	return &"weather.clear"


static func absolute_day(calendar: Dictionary) -> int:
	var season_index: int = SEASONS.find(StringName(calendar.get(&"season_id", SEASONS[0])))
	season_index = maxi(season_index, 0)
	return (
		(int(calendar.get(&"year", 1)) - 1) * SEASONS.size() * DAYS_PER_SEASON
		+ season_index * DAYS_PER_SEASON
		+ int(calendar.get(&"day", 1))
	)


static func advance_calendar(farm: Dictionary, world_seed: int = DEFAULT_WORLD_SEED) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var calendar: Dictionary = candidate[&"calendar_weather"] as Dictionary
	var year: int = int(calendar[&"year"])
	var season_index: int = maxi(SEASONS.find(StringName(calendar[&"season_id"])), 0)
	var day: int = int(calendar[&"day"]) + 1
	if day > DAYS_PER_SEASON:
		day = 1
		season_index += 1
		if season_index >= SEASONS.size():
			season_index = 0
			year += 1
	var next_absolute: int = (
		(year - 1) * SEASONS.size() * DAYS_PER_SEASON + season_index * DAYS_PER_SEASON + day
	)
	calendar[&"year"] = year
	calendar[&"season_id"] = String(SEASONS[season_index])
	calendar[&"day"] = day
	calendar[&"minute_of_day"] = 360
	calendar[&"current_weather_id"] = str(calendar[&"forecast_weather_id"])
	calendar[&"forecast_weather_id"] = String(weather_for(world_seed, next_absolute + 1))
	calendar[&"day_token"] = token_for(year, SEASONS[season_index], day)
	candidate[&"calendar_weather"] = calendar
	return candidate


static func advance_time(
	farm: Dictionary,
	real_seconds: float,
	modal_open: bool,
	day_real_minutes: int = DEFAULT_DAY_REAL_MINUTES
) -> Dictionary:
	if modal_open or real_seconds <= 0.0 or day_real_minutes < 10 or day_real_minutes > 30:
		return farm.duplicate(true)
	var candidate: Dictionary = farm.duplicate(true)
	var calendar: Dictionary = candidate[&"calendar_weather"] as Dictionary
	var game_minutes_per_second: float = 1_080.0 / float(day_real_minutes * 60)
	calendar[&"minute_of_day"] = clampi(
		int(calendar[&"minute_of_day"]) + floori(real_seconds * game_minutes_per_second),
		0,
		1_439,
	)
	candidate[&"calendar_weather"] = calendar
	return candidate


static func time_pauses_for(reason: StringName) -> bool:
	return (
		reason
		in [
			&"dialogue",
			&"inventory",
			&"shop",
			&"construction",
			&"sleep_summary",
			&"settings",
			&"loading",
		]
	)


static func token_for(year: int, season_id: StringName, day: int) -> String:
	return "day:%d:%s:%d" % [year, String(season_id), day]
