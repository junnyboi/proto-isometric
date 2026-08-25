extends RefCounted

const WeatherAudioScript: GDScript = preload("res://scripts/biome_weather_audio.gd")
const EnemyAudioScript: GDScript = preload("res://scripts/fauna_telegraph_audio.gd")

const WEATHER_PATHS: Dictionary = {
	&"sand": "res://assets/audio/weather/weather_desert_glasswind.wav",
	&"wetland": "res://assets/audio/weather/weather_wetland_reedrain.wav",
	&"frozen": "res://assets/audio/weather/weather_frozen_whiteout.wav",
	&"volcanic": "res://assets/audio/weather/weather_volcanic_ashfall.wav",
}


class FakeHazards:
	extends Node
	var tornadoes: int = 0
	var sandstorms: int = 0
	var events: Array[Dictionary] = []

	func get_hazard_count(kind: StringName = &"") -> int:
		if kind == &"tornado":
			return tornadoes
		if kind == &"sandstorm":
			return sandstorms
		return tornadoes + sandstorms

	func get_deep_event_snapshots() -> Array[Dictionary]:
		return events.duplicate(true)


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_assets_and_mapping(cases)
	_test_crossfade_contract(cases)
	_test_hazard_intensity(cases)
	_test_enemy_ducking(cases)
	_test_accessibility(cases)
	_test_shipping(cases)
	return cases


static func _test_assets_and_mapping(cases: Array[Dictionary]) -> void:
	var unique_paths: Dictionary = {}
	var all_valid: bool = true
	for biome: StringName in WEATHER_PATHS:
		var path: String = WeatherAudioScript.stream_path_for(biome)
		var stream: AudioStream = load(path) as AudioStream
		all_valid = (
			all_valid
			and path == WEATHER_PATHS[biome]
			and stream is AudioStreamWAV
			and is_equal_approx(stream.get_length(), 8.0)
		)
		unique_paths[path] = true
	_add(
		cases,
		"all four biome weather loops are distinct eight-second WAV resources",
		all_valid and unique_paths.size() == 4,
	)
	_add(
		cases,
		"weather biome aliases normalize to the matching layer",
		(
			WeatherAudioScript.normalize_biome(&"water") == &"wetland"
			and WeatherAudioScript.normalize_biome(&"blue_ice") == &"frozen"
			and WeatherAudioScript.normalize_biome(&"lava") == &"volcanic"
			and WeatherAudioScript.normalize_biome(&"rock") == &"sand"
		),
	)


static func _test_crossfade_contract(cases: Array[Dictionary]) -> void:
	var weather: Node = _weather_node()
	var initial: Dictionary = weather.call("get_metrics") as Dictionary
	_add(
		cases,
		"weather audio owns exactly two prewarmed Ambient-bus voices",
		(
			int(initial[&"capacity"]) == 2
			and weather.get_child_count() == 2
			and (weather.get_child(0) as AudioStreamPlayer).bus == &"Ambient"
			and (weather.get_child(1) as AudioStreamPlayer).bus == &"Ambient"
		),
	)
	var changed: bool = bool(weather.call("set_biome", &"water"))
	var during: Dictionary = weather.call("get_metrics") as Dictionary
	weather.call("_process", WeatherAudioScript.CROSSFADE_SECONDS)
	var after: Dictionary = weather.call("get_metrics") as Dictionary
	_add(
		cases,
		"biome changes use a bounded equal-power crossfade and reject duplicate switches",
		(
			changed
			and bool(during[&"crossfading"])
			and int(during[&"capacity"]) == 2
			and not bool(weather.call("set_biome", &"wetland"))
			and not bool(after[&"crossfading"])
			and after[&"biome"] == &"wetland"
			and int(after[&"completed_crossfades"]) == 1
		),
	)
	var midpoint: Vector2 = WeatherAudioScript.crossfade_gains(0.5)
	_add(
		cases,
		"weather crossfade midpoint preserves constant power",
		absf(midpoint.length_squared() - 1.0) <= 0.001,
	)
	weather.queue_free()


static func _test_hazard_intensity(cases: Array[Dictionary]) -> void:
	var weather: Node = _weather_node()
	var hazards: FakeHazards = FakeHazards.new()
	hazards.tornadoes = 1
	hazards.sandstorms = 2
	weather.call("bind_hazard_source", hazards)
	weather.call("set_biome", &"sand")
	weather.call("_process", 0.21)
	var desert: Dictionary = weather.call("get_metrics") as Dictionary
	_add(
		cases,
		"live desert storms raise only the desert weather target within the cap",
		(
			is_equal_approx(float(desert[&"hazard_activity"]), 1.0)
			and is_equal_approx(float(desert[&"target_intensity"]), 0.97)
		),
	)
	hazards.tornadoes = 0
	hazards.sandstorms = 0
	hazards.events = [
		{&"biome": &"oasis", &"kind": &"bog_gas_bloom"},
	]
	weather.call("set_biome", &"wetland")
	weather.call("_process", 0.21)
	var wetland: Dictionary = weather.call("get_metrics") as Dictionary
	_add(
		cases,
		"matching deep-biome events raise the local weather layer",
		(
			is_equal_approx(float(wetland[&"hazard_activity"]), 0.65)
			and is_equal_approx(float(wetland[&"target_intensity"]), 0.9025)
		),
	)
	weather.call("set_biome", &"frozen")
	weather.call("_process", 0.21)
	var frozen: Dictionary = weather.call("get_metrics") as Dictionary
	_add(
		cases,
		"nonmatching deep events do not raise another biome weather layer",
		(
			is_zero_approx(float(frozen[&"hazard_activity"]))
			and is_equal_approx(float(frozen[&"target_intensity"]), 0.70)
		),
	)
	weather.queue_free()
	hazards.free()


static func _test_enemy_ducking(cases: Array[Dictionary]) -> void:
	var weather: Node = _weather_node()
	var enemy_audio: Node = EnemyAudioScript.new() as Node
	var callback: Callable = Callable(weather, "_on_enemy_cue")
	enemy_audio.connect("cue_played", callback)
	var moved: bool = bool(
		enemy_audio.call("play_movement", &"glassback_scarab", 44, 1, Vector2.ZERO)
	)
	weather.call("_process", 0.10)
	var movement: Dictionary = weather.call("get_metrics") as Dictionary
	var attacked: bool = bool(
		enemy_audio.call("play_attack", &"glassback_scarab", 44, 2, Vector2.ZERO)
	)
	weather.call("_process", 0.10)
	var attack: Dictionary = weather.call("get_metrics") as Dictionary
	_add(
		cases,
		"enemy movement remains audible without ducking weather",
		moved and int(movement[&"duck_requests"]) == 0,
	)
	_add(
		cases,
		"accepted enemy attacks trigger one bounded weather duck",
		(
			attacked
			and int(attack[&"duck_requests"]) == 1
			and float(attack[&"duck_gain"]) < 1.0
			and attack[&"last_duck_kind"] == &"glassback_scarab"
		),
	)
	weather.call("_process", 2.0)
	var recovered: Dictionary = weather.call("get_metrics") as Dictionary
	_add(
		cases,
		"weather duck releases smoothly back to full gain",
		is_equal_approx(float(recovered[&"duck_gain"]), 1.0),
	)
	weather.queue_free()
	enemy_audio.free()


static func _test_accessibility(cases: Array[Dictionary]) -> void:
	var weather: Node = _weather_node()
	weather.call("set_enabled", false)
	var muted: Dictionary = weather.call("get_metrics") as Dictionary
	weather.call("set_enabled", true)
	var restored: Dictionary = weather.call("get_metrics") as Dictionary
	_add(
		cases,
		"Ambience true-zero disable stops weather and positive restore re-enables it",
		(
			not bool(muted[&"enabled"])
			and int(muted[&"active"]) == 0
			and bool(restored[&"enabled"])
			and int(restored[&"capacity"]) == 2
		),
	)
	weather.queue_free()


static func _test_shipping(cases: Array[Dictionary]) -> void:
	var export_text: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	var complete: bool = "res://scripts/biome_weather_audio.gd" in export_text
	for path_value: Variant in WEATHER_PATHS.values():
		complete = complete and str(path_value) in export_text
	_add(
		cases,
		"Web export ships the weather controller and every biome loop",
		complete and "assets/audio/weather/*.wav" in export_text,
	)


static func _weather_node() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var weather: Node = WeatherAudioScript.new() as Node
	tree.root.add_child(weather)
	return weather


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
