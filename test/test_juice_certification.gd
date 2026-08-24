extends RefCounted

const BiomeDestructiblesScript: GDScript = preload("res://scripts/biome_destructibles.gd")
const BiomeMusicScript: GDScript = preload("res://scripts/biome_music.gd")
const BiomeSoundscapeScript: GDScript = preload("res://scripts/biome_soundscape.gd")
const ImpactEffectsScript: GDScript = preload("res://scripts/impact_effects.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var paths: Array[String] = [
		BiomeSoundscapeScript.stream_path_for(&"sand"),
		BiomeSoundscapeScript.stream_path_for(&"mud"),
		BiomeSoundscapeScript.stream_path_for(&"snow"),
		BiomeSoundscapeScript.stream_path_for(&"volcanic"),
	]
	_add(
		cases,
		"four distinct biome ambience beds load",
		paths.size() == 4 and _unique_count(paths) == 4 and _all_runtime_wavs(paths),
	)
	_add(
		cases,
		"biome ambience normalization covers every terrain family",
		(
			BiomeSoundscapeScript.normalize_biome(&"sand") == &"sand"
			and BiomeSoundscapeScript.normalize_biome(&"water") == &"wetland"
			and BiomeSoundscapeScript.normalize_biome(&"blue_ice") == &"frozen"
			and BiomeSoundscapeScript.normalize_biome(&"lava") == &"volcanic"
		),
	)
	var music_paths: Array[String] = []
	for biome: StringName in [&"sand", &"mud", &"snow", &"volcanic"]:
		music_paths.append_array(BiomeMusicScript.stream_paths_for(biome))
	_add(
		cases,
		"eight distinct long-form biome BGM tracks load in two-track pools",
		(
			music_paths.size() == 8
			and _unique_count(music_paths) == 8
			and _all_runtime_oggs(music_paths)
			and _all_tracks_long_form(music_paths)
		),
	)
	_add(
		cases,
		"biome music normalization covers every terrain family",
		(
			BiomeMusicScript.normalize_biome(&"sand") == &"sand"
			and BiomeMusicScript.normalize_biome(&"water") == &"wetland"
			and BiomeMusicScript.normalize_biome(&"blue_ice") == &"frozen"
			and BiomeMusicScript.normalize_biome(&"lava") == &"volcanic"
		),
	)
	_add(
		cases,
		"per-biome BGM gains preserve SFX headroom while lifting sparse cues",
		(
			is_equal_approx(BiomeMusicScript.volume_db_for(&"sand"), -6.0)
			and is_equal_approx(BiomeMusicScript.volume_db_for(&"mud"), -5.0)
			and is_equal_approx(BiomeMusicScript.volume_db_for(&"snow"), -4.0)
			and is_equal_approx(BiomeMusicScript.volume_db_for(&"lava"), -7.0)
		),
	)
	var music: Node = BiomeMusicScript.new() as Node
	music.call("set_random_seed", 20260824)
	(Engine.get_main_loop() as SceneTree).root.add_child(music)
	var music_changed: bool = bool(music.call("set_biome", &"lava"))
	var music_metrics: Dictionary = music.call("get_metrics") as Dictionary
	var music_players: Array = music.get("_players") as Array
	_add(
		cases,
		"biome BGM starts a bounded Music-bus crossfade",
		(
			music_changed
			and music_metrics[&"biome"] == &"volcanic"
			and music_metrics[&"stream_path"] in BiomeMusicScript.stream_paths_for(&"lava")
			and int(music_metrics[&"variant"]) in [0, 1]
			and int(music_metrics[&"capacity"]) == 2
			and bool(music_metrics[&"crossfading"])
			and music_players.size() == 2
			and (music_players[0] as AudioStreamPlayer).bus == &"Music"
			and (music_players[1] as AudioStreamPlayer).bus == &"Music"
		),
	)
	music.call("_process", BiomeMusicScript.CROSSFADE_SECONDS * 0.5)
	var music_midpoint: Dictionary = music.call("get_metrics") as Dictionary
	var music_gains: Array = music_midpoint[&"voice_gains"] as Array
	_add(
		cases,
		"biome BGM midpoint uses equal-power gains without a silent gap",
		(
			bool(music_midpoint[&"crossfading"])
			and absf(float(music_gains[0]) - sqrt(0.5)) < 0.001
			and absf(float(music_gains[1]) - sqrt(0.5)) < 0.001
		),
	)
	music.call("set_biome", &"sand")
	var reversed_music: Dictionary = music.call("get_metrics") as Dictionary
	var reversed_music_gains: Array = reversed_music[&"voice_gains"] as Array
	_add(
		cases,
		"rapid border reversal keeps a sounding voice while selecting a sand alternate",
		(
			reversed_music[&"biome"] == &"sand"
			and bool(reversed_music[&"crossfading"])
			and maxf(float(reversed_music_gains[0]), float(reversed_music_gains[1]))
			>= sqrt(0.5) - 0.001
			and reversed_music[&"stream_path"] in BiomeMusicScript.stream_paths_for(&"sand")
		),
	)
	music.call("set_volume", 0.0)
	music.call("set_enabled", false)
	var muted_music: Dictionary = music.call("get_metrics") as Dictionary
	_add(
		cases,
		"muted biome BGM performs true-zero playback",
		not bool(muted_music[&"enabled"]) and float(muted_music[&"volume"]) == 0.0,
	)
	music.free()
	var shuffle_music: Node = BiomeMusicScript.new() as Node
	shuffle_music.call("set_random_seed", 424242)
	(Engine.get_main_loop() as SceneTree).root.add_child(shuffle_music)
	var first_variant: int = int((shuffle_music.call("get_metrics") as Dictionary)[&"variant"])
	var first_advanced: bool = bool(shuffle_music.call("advance_track"))
	var second_variant: int = int((shuffle_music.call("get_metrics") as Dictionary)[&"variant"])
	shuffle_music.call("_process", BiomeMusicScript.CROSSFADE_SECONDS)
	var second_advanced: bool = bool(shuffle_music.call("advance_track"))
	var third_variant: int = int((shuffle_music.call("get_metrics") as Dictionary)[&"variant"])
	shuffle_music.call("_process", BiomeMusicScript.CROSSFADE_SECONDS)
	shuffle_music.call("_process", 1000.0)
	var automatic_metrics: Dictionary = shuffle_music.call("get_metrics") as Dictionary
	var fourth_variant: int = int(automatic_metrics[&"variant"])
	_add(
		cases,
		"seeded shuffle bag alternates both biome tracks without immediate repeats",
		(
			first_advanced
			and second_advanced
			and first_variant != second_variant
			and second_variant != third_variant
			and third_variant != fourth_variant
		),
	)
	_add(
		cases,
		"track end automatically rotates through the bounded crossfader",
		(
			int(automatic_metrics[&"track_changes"]) == 3
			and int(automatic_metrics[&"completed_crossfades"]) >= 3
			and automatic_metrics[&"stream_path"]
			in BiomeMusicScript.stream_paths_for(&"sand")
		),
	)
	shuffle_music.free()
	_add(
		cases,
		"all ambience beds are raised and quietest frozen bed is compensated",
		(
			is_equal_approx(BiomeSoundscapeScript.volume_db_for(&"sand"), 2.0)
			and is_equal_approx(BiomeSoundscapeScript.volume_db_for(&"mud"), 2.5)
			and is_equal_approx(BiomeSoundscapeScript.volume_db_for(&"snow"), 6.0)
			and is_equal_approx(BiomeSoundscapeScript.volume_db_for(&"lava"), 1.5)
		),
	)
	var soundscape: Node = BiomeSoundscapeScript.new() as Node
	(Engine.get_main_loop() as SceneTree).root.add_child(soundscape)
	var changed: bool = bool(soundscape.call("set_biome", &"mud"))
	var soundscape_metrics: Dictionary = soundscape.call("get_metrics") as Dictionary
	_add(
		cases,
		"biome soundscape starts an interruptible two-voice crossfade",
		(
			changed
			and soundscape_metrics[&"biome"] == &"wetland"
			and int(soundscape_metrics[&"capacity"]) == 2
			and int(soundscape_metrics[&"switches"]) == 1
			and bool(soundscape_metrics[&"crossfading"])
			and is_equal_approx(
				float(soundscape_metrics[&"crossfade_seconds"]),
				BiomeSoundscapeScript.CROSSFADE_SECONDS,
			)
		),
	)
	soundscape.call("_process", BiomeSoundscapeScript.CROSSFADE_SECONDS * 0.5)
	var midpoint: Dictionary = soundscape.call("get_metrics") as Dictionary
	var gains: Array = midpoint[&"voice_gains"] as Array
	_add(
		cases,
		"biome midpoint uses equal-power gains without a silent gap",
		(
			bool(midpoint[&"crossfading"])
			and absf(float(gains[0]) - sqrt(0.5)) < 0.001
			and absf(float(gains[1]) - sqrt(0.5)) < 0.001
		),
	)
	soundscape.call("set_biome", &"snow")
	soundscape.call("_process", BiomeSoundscapeScript.CROSSFADE_SECONDS)
	var completed: Dictionary = soundscape.call("get_metrics") as Dictionary
	_add(
		cases,
		"interrupted biome crossfade completes on the latest requested bed",
		(
			completed[&"biome"] == &"frozen"
			and not bool(completed[&"crossfading"])
			and int(completed[&"switches"]) == 2
			and int(completed[&"completed_crossfades"]) == 1
		),
	)
	soundscape.call("set_volume", 0.0)
	soundscape.call("set_enabled", false)
	var muted_metrics: Dictionary = soundscape.call("get_metrics") as Dictionary
	_add(
		cases,
		"muted soundscape performs true-zero playback",
		not bool(muted_metrics[&"enabled"]) and float(muted_metrics[&"volume"]) == 0.0,
	)
	soundscape.free()
	var effects: Node2D = ImpactEffectsScript.new() as Node2D
	effects.call("_apply_preferences", {&"effects_quality": &"full"})
	var full_count: int = int(effects.call("_quality_particle_count", 28))
	effects.call("_apply_preferences", {&"effects_quality": &"reduced"})
	var reduced_count: int = int(effects.call("_quality_particle_count", 28))
	effects.call("_apply_preferences", {&"effects_quality": &"minimal"})
	var minimal_count: int = int(effects.call("_quality_particle_count", 28))
	_add(
		cases,
		"effects quality tiers reduce particles without reaching zero",
		full_count == 28 and reduced_count == 17 and minimal_count == 10,
	)
	var locomotion_event: Dictionary = {&"event_id": RuntimeIdsScript.EVENT_LOCOMOTION_WALK_CONTACT}
	var relay_event: Dictionary = {&"event_id": RuntimeIdsScript.EVENT_RELAY_COMPLETED}
	_add(
		cases,
		"minimal effects suppress low-priority bursts but preserve major rewards",
		(
			not bool(effects.call("_allows_semantic_burst", locomotion_event, 20))
			and bool(effects.call("_allows_semantic_burst", relay_event, 88))
		),
	)
	effects.call("_apply_preferences", {&"effects_quality": &"full"})
	for index: int in range(1000):
		(
			effects
			. call(
				"emit_rock_impact",
				Vector2.ZERO,
				Vector2i(index, 0),
				BiomeDestructiblesScript.KIND_DESERT_ROCK,
				false,
				28,
			)
		)
	var saturated: bool = (
		int(effects.call("get_particle_count")) == 128
		and int(effects.call("get_created_particle_count")) == 128
		and int(effects.call("get_peak_particle_count")) == 128
		and int(effects.call("_get_reclaimed_particle_count")) > 0
	)
	effects.call("advance", 1.1)
	_add(
		cases,
		"one thousand effect emissions stay pooled and return to idle",
		(
			saturated
			and int(effects.call("get_particle_count")) == 0
			and int(effects.call("get_particle_pool_size")) == 128
		),
	)
	effects.free()
	return cases


static func _unique_count(values: Array[String]) -> int:
	var unique: Dictionary = {}
	for value: String in values:
		unique[value] = true
	return unique.size()


static func _is_runtime_wav(path: String) -> bool:
	return path.begins_with("res://assets/audio/ambience_") and path.ends_with(".wav")


static func _all_runtime_wavs(paths: Array[String]) -> bool:
	for path: String in paths:
		if not _is_runtime_wav(path):
			return false
	return true


static func _all_runtime_oggs(paths: Array[String]) -> bool:
	for path: String in paths:
		if not path.begins_with("res://assets/audio/bgm_") or not path.ends_with(".ogg"):
			return false
	return true


static func _all_tracks_long_form(paths: Array[String]) -> bool:
	for path: String in paths:
		var stream: AudioStream = load(path) as AudioStream
		if stream == null or stream.get_length() < 80.0:
			return false
	return true


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
