extends RefCounted

const BiomeDestructiblesScript: GDScript = preload("res://scripts/biome_destructibles.gd")
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


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
