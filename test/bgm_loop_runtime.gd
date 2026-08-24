extends SceneTree

const TRACK_PATHS: Array[String] = [
	"res://assets/audio/bgm_desert.ogg",
	"res://assets/audio/bgm_wetland.ogg",
	"res://assets/audio/bgm_frozen.ogg",
	"res://assets/audio/bgm_volcanic.ogg",
]
const MUSIC_BUS: StringName = &"Music"
const MINIMUM_LENGTH_SECONDS: float = 80.0
const SEEK_BEFORE_END_SECONDS: float = 0.12
const WAIT_AFTER_SEEK_SECONDS: float = 0.32
const MAXIMUM_WRAPPED_POSITION_SECONDS: float = 1.0
const FINAL_RELEASE_WAIT_SECONDS: float = 0.25

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) < 0:
		_failures.append("Music bus is missing")
	for path: String in TRACK_PATHS:
		await _test_track(path)
	await create_timer(FINAL_RELEASE_WAIT_SECONDS).timeout
	await process_frame
	await process_frame
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error("[BGM_LOOP_GODOT_FAIL] %s" % failure)
		quit(1)
		return
	print("[BGM_LOOP_GODOT_PASS] tracks=%d" % TRACK_PATHS.size())
	quit()


func _test_track(path: String) -> void:
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		_failures.append("%s did not load" % path)
		return
	if not stream is AudioStreamOggVorbis:
		_failures.append("%s is not AudioStreamOggVorbis" % path)
		return
	var ogg_stream: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
	if ogg_stream.get_length() < MINIMUM_LENGTH_SECONDS:
		_failures.append("%s is shorter than %.1f seconds" % [path, MINIMUM_LENGTH_SECONDS])
		return
	ogg_stream.loop = true
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = MUSIC_BUS
	player.stream = ogg_stream
	root.add_child(player)
	player.play()
	await process_frame
	await process_frame
	if not player.playing:
		_failures.append("%s did not begin playback" % path)
		player.free()
		await process_frame
		return
	player.seek(maxf(ogg_stream.get_length() - SEEK_BEFORE_END_SECONDS, 0.0))
	await create_timer(WAIT_AFTER_SEEK_SECONDS).timeout
	var wrapped_position: float = player.get_playback_position()
	if not player.playing:
		_failures.append("%s stopped instead of looping" % path)
	elif wrapped_position > MAXIMUM_WRAPPED_POSITION_SECONDS:
		_failures.append("%s did not wrap near zero; position=%.3f" % [path, wrapped_position])
	else:
		print(
			(
				"[BGM_LOOP_GODOT_TRACK_PASS] path=%s length=%.3f wrapped_position=%.3f"
				% [path, ogg_stream.get_length(), wrapped_position]
			)
		)
	player.stop()
	player.stream = null
	root.remove_child(player)
	player.free()
	ogg_stream = null
	stream = null
	for _index: int in range(10):
		await process_frame
