extends RefCounted

const FeedbackAudioScript: GDScript = preload("res://scripts/feedback_audio.gd")
const HerdAudioScript: GDScript = preload("res://scripts/peaceful_herd_audio.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const SPECIES: Array[StringName] = [
	&"dune_grazer",
	&"reedback",
	&"rimehorn",
	&"ember_ram",
]


class ScreenProjection:
	extends RefCounted

	func grid_to_screen(position: Vector2) -> Vector2:
		return position * Vector2(10.0, 5.0) + Vector2(100.0, 50.0)


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_catalog(cases)
	_test_routing(cases)
	_test_schedule(cases)
	_test_generic_override(cases)
	return cases


static func _test_catalog(cases: Array[Dictionary]) -> void:
	var paths: Dictionary = {}
	for kind: StringName in SPECIES:
		for event: StringName in [HerdAudioScript.EVENT_AMBIENT, HerdAudioScript.EVENT_DEFEAT]:
			var stream: AudioStream = HerdAudioScript.stream_for(kind, event)
			var path: String = HerdAudioScript.cue_path(kind, event)
			var cue_valid: bool = (
				stream is AudioStreamWAV
				and stream.get_length() >= 1.0
				and stream.get_length() <= 3.0
				and (stream as AudioStreamWAV).mix_rate == 48_000
				and not (stream as AudioStreamWAV).stereo
			)
			_add(cases, "%s %s cue is runtime-safe" % [kind, event], cue_valid)
			paths[path] = true
	_add(cases, "all peaceful herd cues are unique", paths.size() == SPECIES.size() * 2)


static func _test_routing(cases: Array[Dictionary]) -> void:
	var audio: Node = HerdAudioScript.new() as Node
	audio.call("_ready")
	var projection: ScreenProjection = ScreenProjection.new()
	var ambient_ok: bool = bool(
		audio.call(
			"play_ambient",
			&"dune_grazer",
			100_004,
			Vector2(3.0, 4.0),
			Callable(projection, "grid_to_screen"),
		)
	)
	var ambient_metrics: Dictionary = audio.call("get_metrics") as Dictionary
	var defeat_ok: bool = bool(
		audio.call(
			"play_defeat",
			&"ember_ram",
			Vector2(7.0, 2.0),
			Callable(projection, "grid_to_screen"),
		)
	)
	var defeat_metrics: Dictionary = audio.call("get_metrics") as Dictionary
	_add(
		cases,
		"ambient call uses its species stream and projected position",
		ambient_ok
		and ambient_metrics[&"last_kind"] == &"dune_grazer"
		and str(ambient_metrics[&"last_stream_path"]).ends_with(
			"herd_dune_grazer_ambient.wav"
		)
		and ambient_metrics[&"last_position"] == Vector2(130.0, 70.0),
	)
	_add(
		cases,
		"defeat call uses its species stream at higher event priority",
		defeat_ok
		and defeat_metrics[&"last_kind"] == &"ember_ram"
		and defeat_metrics[&"last_event"] == HerdAudioScript.EVENT_DEFEAT
		and str(defeat_metrics[&"last_stream_path"]).ends_with(
			"herd_ember_ram_defeat.wav"
		)
		and int(defeat_metrics[&"defeat_requests"]) == 1,
	)
	audio.free()


static func _test_schedule(cases: Array[Dictionary]) -> void:
	var audio: Node = HerdAudioScript.new() as Node
	audio.call("_ready")
	var projection: ScreenProjection = ScreenProjection.new()
	var creatures: Array[Dictionary] = [
		{
			&"id": 100_010,
			&"kind": &"rimehorn",
			&"position": Vector2(2.0, 6.0),
		}
	]
	var before: Dictionary = audio.call("get_metrics") as Dictionary
	audio.call(
		"advance",
		HerdAudioScript.AMBIENT_MAX_SECONDS + 0.1,
		creatures,
		Callable(projection, "grid_to_screen"),
	)
	var after: Dictionary = audio.call("get_metrics") as Dictionary
	_add(
		cases,
		"ambient cadence is sparse and bounded",
		float(before[&"next_ambient_seconds"]) >= HerdAudioScript.AMBIENT_MIN_SECONDS
		and float(before[&"next_ambient_seconds"]) <= HerdAudioScript.AMBIENT_MAX_SECONDS
		and int(after[&"ambient_requests"]) == 1
		and after[&"last_kind"] == &"rimehorn",
	)
	audio.free()


static func _test_generic_override(cases: Array[Dictionary]) -> void:
	var feedback: Node = FeedbackAudioScript.new() as Node
	var peaceful: AudioStream = feedback.call(
		"_stream_for",
		{
			&"event_id": RuntimeIdsScript.EVENT_SMASH_DEFEAT,
			&"metadata": {&"kind": &"reedback"},
		},
	) as AudioStream
	var hostile: AudioStream = feedback.call(
		"_stream_for",
		{
			&"event_id": RuntimeIdsScript.EVENT_SMASH_DEFEAT,
			&"metadata": {&"kind": &"sandworm"},
		},
	) as AudioStream
	_add(
		cases,
		"generic defeat cue yields to peaceful species audio only",
		peaceful == null and hostile != null,
	)
	feedback.free()


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
