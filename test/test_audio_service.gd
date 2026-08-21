extends RefCounted

const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")
const TEST_CUE: AudioStream = preload("res://assets/audio/blocked_clank.wav")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var service: Node = tree.root.get_node_or_null("AudioService") if tree != null else null
	_add(cases, "persistent audio service autoload exists", service != null)
	if service == null:
		return cases
	_test_buses(cases, service)
	_test_voice_layout(cases, service)
	_test_playback_contract(cases, service)
	_test_preferences(cases, service)
	return cases


static func _test_buses(cases: Array[Dictionary], service: Node) -> void:
	var status: Dictionary = service.call("get_bus_layout_status") as Dictionary
	var sends: Dictionary = status.get(&"sends", {}) as Dictionary
	_add(
		cases,
		"audio mixer hierarchy is complete",
		(
			bool(status.get(&"valid", false))
			and sends.get(AudioServiceScript.BUS_SFX) == AudioServiceScript.BUS_MASTER
			and sends.get(AudioServiceScript.BUS_UI) == AudioServiceScript.BUS_SFX
			and sends.get(AudioServiceScript.BUS_WALKER) == AudioServiceScript.BUS_SFX
			and sends.get(AudioServiceScript.BUS_COMBAT) == AudioServiceScript.BUS_SFX
			and sends.get(AudioServiceScript.BUS_ENEMY) == AudioServiceScript.BUS_SFX
			and sends.get(AudioServiceScript.BUS_WORLD) == AudioServiceScript.BUS_SFX
			and sends.get(AudioServiceScript.BUS_AMBIENT) == AudioServiceScript.BUS_MASTER
			and sends.get(AudioServiceScript.BUS_MUSIC) == AudioServiceScript.BUS_MASTER
		),
	)


static func _test_voice_layout(cases: Array[Dictionary], service: Node) -> void:
	var layout: Dictionary = service.call("get_voice_layout") as Dictionary
	var globals: Array = layout.get(&"global", []) as Array
	var spatials: Array = layout.get(&"spatial", []) as Array
	var spatial_valid: bool = spatials.size() == AudioServiceScript.SPATIAL_VOICE_COUNT
	for voice: Dictionary in spatials:
		spatial_valid = (
			spatial_valid
			and bool(voice.get(&"positional", false))
			and float(voice.get(&"max_distance", 0.0)) == AudioServiceScript.SPATIAL_MAX_DISTANCE
		)
	_add(
		cases,
		"persistent audio owns bounded global and positional pools",
		(
			globals.size() == AudioServiceScript.GLOBAL_VOICE_COUNT
			and spatial_valid
		),
	)


static func _test_playback_contract(cases: Array[Dictionary], service: Node) -> void:
	service.call("set_sfx_enabled", true)
	var before: Dictionary = service.call("get_metrics") as Dictionary
	var global_ok: bool = bool(
		service.call("play_global", TEST_CUE, AudioServiceScript.BUS_UI, 1.0, -3.0, 1)
	)
	var position: Vector2 = Vector2(321.0, 123.0)
	var spatial_ok: bool = bool(
		service.call(
			"play_spatial",
			TEST_CUE,
			position,
			AudioServiceScript.BUS_WORLD,
			1.0,
			-2.0,
			2,
		)
	)
	var after: Dictionary = service.call("get_metrics") as Dictionary
	_add(
		cases,
		"global and positional requests use the persistent pools",
		(
			global_ok
			and spatial_ok
			and int(after[&"global_requests"]) == int(before[&"global_requests"]) + 1
			and int(after[&"spatial_requests"]) == int(before[&"spatial_requests"]) + 1
			and after[&"last_bus"] == AudioServiceScript.BUS_WORLD
			and after[&"last_position"] == position
		),
	)
	service.call("set_sfx_enabled", false)
	_add(
		cases,
		"SFX mute rejects new gameplay voices",
		not bool(service.call("play_spatial", TEST_CUE, position, AudioServiceScript.BUS_WORLD)),
	)
	service.call("set_sfx_enabled", true)
	_add(
		cases,
		"unknown audio buses fail closed",
		not bool(service.call("play_global", TEST_CUE, &"MissingBus")),
	)


static func _test_preferences(cases: Array[Dictionary], service: Node) -> void:
	service.call(
		"apply_preferences",
		{
			&"sfx_enabled": true,
			&"master_volume": 0.55,
			&"sfx_volume": 0.65,
			&"music_volume": 0.45,
		},
	)
	_add(
		cases,
		"audio preferences apply independent bus gains",
		(
			_volume_is(AudioServiceScript.BUS_MASTER, 0.55)
			and _volume_is(AudioServiceScript.BUS_SFX, 0.65)
			and _volume_is(AudioServiceScript.BUS_MUSIC, 0.45)
		),
	)
	service.call(
		"apply_preferences",
		{
			&"sfx_enabled": true,
			&"master_volume": 1.0,
			&"sfx_volume": 1.0,
			&"music_volume": 1.0,
		},
	)


static func _volume_is(bus: StringName, expected: float) -> bool:
	var index: int = AudioServer.get_bus_index(bus)
	return index >= 0 and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(index)), expected)


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
