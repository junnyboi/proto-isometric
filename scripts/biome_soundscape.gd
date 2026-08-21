extends Node

const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")
const DESERT: AudioStream = preload("res://assets/audio/ambience_desert.wav")
const WETLAND: AudioStream = preload("res://assets/audio/ambience_wetland.wav")
const FROZEN: AudioStream = preload("res://assets/audio/ambience_frozen.wav")
const VOLCANIC: AudioStream = preload("res://assets/audio/ambience_volcanic.wav")

const MAX_VOICES: int = 2
const BED_VOLUME_DB: float = -30.0
const SILENT_VOLUME_DB: float = -80.0
const CROSSFADE_SECONDS: float = 2.0

var _players: Array[AudioStreamPlayer] = []
var _voice_gains: Array[float] = [0.0, 0.0]
var _current_biome: StringName = &"sand"
var _active_index: int = 0
var _outgoing_index: int = 0
var _incoming_index: int = 0
var _fade_elapsed: float = CROSSFADE_SECONDS
var _fade_start_gain: float = 1.0
var _enabled: bool = true
var _volume: float = 1.0
var _switch_count: int = 0
var _completed_crossfades: int = 0


func _ready() -> void:
	_ensure_players()
	_start_biome(_current_biome, true)


func _process(delta: float) -> void:
	if not _enabled or _players.is_empty():
		return
	_restart_finished_voices()
	if not is_crossfading():
		return
	_fade_elapsed = minf(_fade_elapsed + maxf(delta, 0.0), CROSSFADE_SECONDS)
	var gains: Vector2 = crossfade_gains(_fade_elapsed / CROSSFADE_SECONDS)
	_apply_voice_gain(_outgoing_index, _fade_start_gain * gains.x)
	_apply_voice_gain(_incoming_index, gains.y)
	if _fade_elapsed >= CROSSFADE_SECONDS:
		_players[_outgoing_index].stop()
		_apply_voice_gain(_outgoing_index, 0.0)
		_active_index = _incoming_index
		_completed_crossfades += 1


func present(event: Dictionary) -> bool:
	var event_id: String = str(event.get(&"event_id", ""))
	if not event_id.begins_with("event.locomotion."):
		return false
	return set_biome(event.get(&"material", &"sand") as StringName)


func set_biome(biome: StringName) -> bool:
	var normalized: StringName = normalize_biome(biome)
	if normalized == _current_biome:
		return false
	_current_biome = normalized
	_switch_count += 1
	_start_biome(normalized, false)
	return true


func set_enabled(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	_ensure_players()
	if not enabled:
		_stop_all()
	elif _volume > 0.0:
		_start_biome(_current_biome, true)


func set_volume(volume: float) -> void:
	var previous: float = _volume
	_volume = clampf(volume, 0.0, 1.0)
	if _volume <= 0.0:
		_stop_all()
	elif _enabled and previous <= 0.0:
		_start_biome(_current_biome, true)
	else:
		_refresh_voice_levels()


func is_crossfading() -> bool:
	return _incoming_index != _outgoing_index and _fade_elapsed < CROSSFADE_SECONDS


func get_metrics() -> Dictionary:
	var active: int = 0
	for player: AudioStreamPlayer in _players:
		if player.playing:
			active += 1
	return {
		&"enabled": _enabled,
		&"volume": _volume,
		&"biome": _current_biome,
		&"switches": _switch_count,
		&"active": active,
		&"capacity": MAX_VOICES,
		&"crossfading": is_crossfading(),
		&"crossfade_seconds": CROSSFADE_SECONDS,
		&"crossfade_progress": minf(_fade_elapsed / CROSSFADE_SECONDS, 1.0),
		&"completed_crossfades": _completed_crossfades,
		&"voice_gains": _voice_gains.duplicate(),
	}


static func normalize_biome(biome: StringName) -> StringName:
	if biome in [&"mud", &"wetland", &"water"]:
		return &"wetland"
	if biome in [&"snow", &"blue_ice", &"ice", &"frozen"]:
		return &"frozen"
	if biome in [&"volcanic", &"lava", &"basalt", &"obsidian"]:
		return &"volcanic"
	return &"sand"


static func stream_path_for(biome: StringName) -> String:
	return _stream_for(normalize_biome(biome)).resource_path


static func crossfade_gains(progress: float) -> Vector2:
	var phase: float = clampf(progress, 0.0, 1.0) * PI * 0.5
	return Vector2(cos(phase), sin(phase))


func _start_biome(biome: StringName, immediate: bool) -> void:
	if not _enabled or _volume <= 0.0:
		return
	_ensure_players()
	if _players.is_empty():
		return
	if immediate:
		_active_index = 0
		_outgoing_index = 0
		_incoming_index = 0
		_fade_elapsed = CROSSFADE_SECONDS
		_players[0].stream = _stream_for(biome)
		_apply_voice_gain(0, 1.0)
		_play_voice(0)
		_players[1].stop()
		_apply_voice_gain(1, 0.0)
		return
	_outgoing_index = _dominant_voice_index()
	_incoming_index = 1 - _outgoing_index
	_active_index = _outgoing_index
	_fade_start_gain = _voice_gains[_outgoing_index]
	_players[_incoming_index].stop()
	_players[_incoming_index].stream = _stream_for(biome)
	_apply_voice_gain(_incoming_index, 0.0)
	_play_voice(_incoming_index)
	_fade_elapsed = 0.0


func _ensure_players() -> void:
	if not _players.is_empty() or not is_inside_tree():
		return
	_configure_stream_loops()
	for index: int in range(MAX_VOICES):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "BiomeBed%02d" % index
		player.bus = AudioServiceScript.BUS_AMBIENT
		player.volume_db = SILENT_VOLUME_DB
		add_child(player)
		_players.append(player)


func _configure_stream_loops() -> void:
	for stream: AudioStream in [DESERT, WETLAND, FROZEN, VOLCANIC]:
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func _restart_finished_voices() -> void:
	for index: int in range(_players.size()):
		if _voice_gains[index] > 0.0 and not _players[index].playing:
			_play_voice(index)


func _play_voice(index: int) -> void:
	if DisplayServer.get_name() != "headless" and _players[index].stream != null:
		_players[index].play()


func _stop_all() -> void:
	for index: int in range(_players.size()):
		_players[index].stop()
		_apply_voice_gain(index, 0.0)
	_outgoing_index = _active_index
	_incoming_index = _active_index
	_fade_elapsed = CROSSFADE_SECONDS


func _refresh_voice_levels() -> void:
	for index: int in range(_players.size()):
		_apply_voice_gain(index, _voice_gains[index])


func _apply_voice_gain(index: int, gain: float) -> void:
	var normalized: float = clampf(gain, 0.0, 1.0)
	_voice_gains[index] = normalized
	_players[index].volume_db = (
		SILENT_VOLUME_DB
		if normalized <= 0.0
		else _bed_volume_db() + linear_to_db(normalized)
	)


func _dominant_voice_index() -> int:
	return 0 if _voice_gains[0] >= _voice_gains[1] else 1


func _bed_volume_db() -> float:
	return BED_VOLUME_DB + linear_to_db(maxf(_volume, 0.001))


static func _stream_for(biome: StringName) -> AudioStream:
	match biome:
		&"wetland":
			return WETLAND
		&"frozen":
			return FROZEN
		&"volcanic":
			return VOLCANIC
	return DESERT
