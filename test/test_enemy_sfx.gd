extends RefCounted

const EnemyAudioScript: GDScript = preload("res://scripts/fauna_telegraph_audio.gd")
const MeleePressureScript: GDScript = preload("res://scripts/melee_pressure.gd")


class OpenWorld:
	extends RefCounted

	func is_walkable(_cell: Vector2i) -> bool:
		return true


class RecordingAudio:
	extends Node

	var movements: Array[Dictionary] = []
	var attacks: Array[Dictionary] = []

	func play_movement(
		kind: StringName, enemy_id: int, serial: int, position: Vector2
	) -> bool:
		movements.append(
			{&"kind": kind, &"id": enemy_id, &"serial": serial, &"position": position}
		)
		return true

	func play_attack(
		kind: StringName,
		enemy_id: int,
		serial: int,
		position: Vector2,
		_pattern: StringName = &"",
	) -> bool:
		attacks.append(
			{&"kind": kind, &"id": enemy_id, &"serial": serial, &"position": position}
		)
		return true


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_stream_matrix(cases)
	_test_router_bounds(cases)
	_test_live_mob_triggers(cases)
	return cases


static func _test_stream_matrix(cases: Array[Dictionary]) -> void:
	var audio: Node = EnemyAudioScript.new() as Node
	var mobs: Dictionary = {
		&"glassback_scarab": ["mob_glassback_move.wav", "mob_glassback_attack.wav"],
		&"mire_tick": ["mob_mire_tick_move.wav", "mob_mire_tick_attack.wav"],
		&"rime_shardling": ["mob_rime_shardling_move.wav", "mob_rime_shardling_attack.wav"],
		&"ember_skitter": ["mob_ember_skitter_move.wav", "mob_ember_skitter_attack.wav"],
	}
	var paths: Dictionary = {}
	for kind: StringName in mobs:
		var expected: Array = mobs[kind] as Array
		var movement: AudioStream = audio.call("movement_stream_for", kind) as AudioStream
		var attack: AudioStream = audio.call("attack_stream_for", kind) as AudioStream
		paths[movement.resource_path] = true
		paths[attack.resource_path] = true
		_add(
			cases,
			"%s owns distinct movement and attack cues" % kind,
			(
				movement.resource_path.ends_with(expected[0] as String)
				and attack.resource_path.ends_with(expected[1] as String)
				and movement.resource_path != attack.resource_path
			),
		)
		_add(
			cases,
			"%s cues are short gameplay-ready samples" % kind,
			movement.get_length() <= 0.81 and attack.get_length() <= 0.71,
		)
	var patterns: Dictionary = {
		&"forge_sweep": "boss_kilnheart_forge_sweep.wav",
		&"magma_ram": "boss_kilnheart_magma_ram.wav",
		&"caldera_barrage": "boss_kilnheart_caldera_barrage.wav",
	}
	var boss_move: AudioStream = audio.call(
		"movement_stream_for", &"kilnheart_colossus"
	) as AudioStream
	paths[boss_move.resource_path] = true
	for pattern: StringName in patterns:
		var stream: AudioStream = audio.call(
			"attack_stream_for", &"kilnheart_colossus", pattern
		) as AudioStream
		paths[stream.resource_path] = true
		_add(
			cases,
			"Kilnheart %s selects its own attack cue" % pattern,
			stream.resource_path.ends_with(patterns[pattern] as String),
		)
	_add(cases, "all twelve enemy SFX paths are distinct", paths.size() == 12)
	_add(
		cases,
		"Kilnheart movement cue is a bounded heavy cadence sample",
		boss_move.get_length() <= 1.26,
	)
	audio.free()


static func _test_router_bounds(cases: Array[Dictionary]) -> void:
	var audio: Node = EnemyAudioScript.new() as Node
	_add(
		cases,
		"one attack serial plays once",
		(
			bool(audio.call("play_attack", &"glassback_scarab", 11, 1))
			and not bool(audio.call("play_attack", &"glassback_scarab", 11, 1))
		),
	)
	_add(
		cases,
		"Kilnheart warning uses its committed attack pattern",
		bool(
			audio.call(
				"play_warning", &"kilnheart_colossus", 12, 1, Vector2.ZERO, &"magma_ram"
			)
		),
	)
	var routed: Dictionary = audio.call("get_metrics") as Dictionary
	_add(
		cases,
		"router records specialized movement and attack categories",
		int(routed[&"attacks"]) == 2 and routed[&"last_kind"] == &"kilnheart_colossus",
	)
	audio.call("set_enabled", false)
	_add(
		cases,
		"SFX mute rejects a new movement cue without playback work",
		not bool(audio.call("play_movement", &"mire_tick", 13, 1)),
	)
	for index: int in range(80):
		audio.call("play_movement", &"rime_shardling", 100 + index, 1)
	var stressed: Dictionary = audio.call("get_metrics") as Dictionary
	_add(
		cases,
		"specialized enemy audio remains voice and history bounded",
		(
			int(stressed[&"capacity"]) == EnemyAudioScript.MAX_VOICES
			and int(stressed[&"history"]) == EnemyAudioScript.MAX_HISTORY
		),
	)
	audio.free()


static func _test_live_mob_triggers(cases: Array[Dictionary]) -> void:
	var world: RefCounted = OpenWorld.new()
	var recorder: Node = RecordingAudio.new() as Node
	var mobs: Node2D = MeleePressureScript.new() as Node2D
	mobs.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, world, recorder)
	mobs.call("set_player_position", Vector2.ZERO)
	mobs.call("spawn_pack", Vector2.ZERO, 1)
	for _step: int in range(12):
		mobs.call("advance", 0.1)
	var movement_count: int = (recorder.get("movements") as Array).size()
	_add(cases, "moving tiny mobs emit cadence-gated movement audio", movement_count > 0)
	var records: Array = mobs.get("_mites") as Array
	var mite: Dictionary = records[0] as Dictionary
	mite[&"position"] = Vector2(0.5, 0.0)
	mite[&"state"] = MeleePressureScript.STATE_ADVANCE
	mite[&"attack_cooldown"] = 0.0
	mobs.call("advance", 0.1)
	var attacks: Array = recorder.get("attacks") as Array
	_add(
		cases,
		"tiny-mob warning transition emits one biome-specific attack cue",
		(
			attacks.size() == 1
			and attacks[0][&"kind"] == MeleePressureScript.GLASSBACK_SCARAB_KIND
			and int(attacks[0][&"serial"]) == 1
		),
	)
	mobs.free()
	recorder.free()


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
