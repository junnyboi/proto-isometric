extends RefCounted

const TRACK_DAY: StringName = &"clearing_day"
const TRACK_NIGHT: StringName = &"clearing_night"
const TRACK_RAIN: StringName = &"clearing_rain"
const DAY_START_MINUTE: int = 360
const NIGHT_START_MINUTE: int = 1140
const PATHS: Dictionary = {
	TRACK_DAY: "res://assets/audio/harvest/music_clearing_day_loop.wav",
	TRACK_NIGHT: "res://assets/audio/harvest/music_clearing_night_loop.wav",
	TRACK_RAIN: "res://assets/audio/harvest/music_clearing_rain_loop.wav",
}


static func select_track(minute_of_day: int, weather_id: StringName) -> StringName:
	if weather_id == &"weather.rain":
		return TRACK_RAIN
	var minute: int = clampi(minute_of_day, 0, 1439)
	if minute < DAY_START_MINUTE or minute >= NIGHT_START_MINUTE:
		return TRACK_NIGHT
	return TRACK_DAY


static func path_for(track_id: StringName) -> String:
	return str(PATHS.get(track_id, ""))


static func validate() -> bool:
	for track_id: StringName in [TRACK_DAY, TRACK_NIGHT, TRACK_RAIN]:
		var path: String = path_for(track_id)
		if path.is_empty() or not ResourceLoader.exists(path) or not load(path) is AudioStream:
			return false
	return true
