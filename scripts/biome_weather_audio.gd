extends Node

const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")
const DESERT: AudioStream = preload(
	"res://assets/audio/weather/weather_desert_glasswind.wav"
)
const WETLAND: AudioStream = preload(
	"res://assets/audio/weather/weather_wetland_reedrain.wav"
)
const FROZEN: AudioStream = preload(
	"res://assets/audio/weather/weather_frozen_whiteout.wav"
)
const VOLCANIC: AudioStream = preload(
	"res://assets/audio/weather/weather_volcanic_ashfall.wav"
)

const MAX_VOICES: int = 2
const CROSSFADE_SECONDS: float = 2.4
const SILENT_VOLUME_DB: float = -80.0
const DUCK_DB: float = -4.5
const DUCK_LINEAR: float = 0.595662
const DUCK_HOLD_SECONDS: float = 0.35
const DUCK_ATTACK_RATE: float = 4.0
const DUCK_RELEASE_RATE: float = 0.58
const SOURCE_SAMPLE_SECONDS: float = 0.2
const MAX_HAZARD_BOOST: float = 0.25
const BASE_VOLUME_DB_BY_BIOME: Dictionary = {
	&"sand": -10.0,
	&"wetland": -11.0,
	&"frozen": -10.5,
	&"volcanic": -12.0,
}
const BASE_INTENSITY_BY_BIOME: Dictionary = {
	&"sand": 0.72,
	&"wetland": 0.74,
	&"frozen": 0.70,
	&"volcanic": 0.68,
}

var _players: Array[AudioStreamPlayer] = []
var _voice_gains: Array[float] = [0.0, 0.0]
var _voice_biomes: Array[StringName] = [&"sand", &"sand"]
var _current_biome: StringName = &"sand"
var _active_index: int = 0
var _outgoing_index: int = 0
var _incoming_index: int = 0
var _fade_elapsed: float = CROSSFADE_SECONDS
var _fade_start_gain: float = 1.0
var _fade_in_start_gain: float = 0.0
var _enabled: bool = true
var _volume: float = 1.0
var _intensity: float = 0.72
var _target_intensity: float = 0.72
var _duck_gain: float = 1.0
var _duck_hold_remaining: float = 0.0
var _source_sample_remaining: float = 0.0
var _hazard_activity: float = 0.0
var _hazard_source: Node
var _enemy_audio_router: Node
var _last_duck_kind: StringName = &""
var _switch_count: int = 0
var _completed_crossfades: int = 0
var _duck_requests: int = 0
var _restart_count: int = 0


func _ready() -> void:
	_ensure_players()
	_start_biome(_current_biome, true)
	call_deferred("_bind_runtime_sources")


func _process(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	if not _enabled or _players.is_empty():
		return
	_restart_finished_voices()
	_source_sample_remaining -= step
	if _source_sample_remaining <= 0.0:
		_bind_runtime_sources()
		_sample_hazard_activity()
		_source_sample_remaining = SOURCE_SAMPLE_SECONDS
	_advance_crossfade(step)
	_advance_mix(step)


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
	_target_intensity = base_intensity_for(normalized)
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


func set_intensity(intensity: float) -> void:
	_target_intensity = clampf(intensity, 0.0, 1.0)


func bind_hazard_source(source: Node) -> void:
	_hazard_source = source
	_source_sample_remaining = 0.0


func request_enemy_duck(category: StringName) -> bool:
	if category not in [&"warning", &"attack"]:
		return false
	_duck_hold_remaining = DUCK_HOLD_SECONDS
	_duck_requests += 1
	return true


func is_crossfading() -> bool:
	return _incoming_index != _outgoing_index and _fade_elapsed < CROSSFADE_SECONDS


func get_metrics() -> Dictionary:
	var active: int = 0
	for player: AudioStreamPlayer in _players:
		active += 1 if player.playing else 0
	return {
		&"enabled": _enabled,
		&"volume": _volume,
		&"biome": _current_biome,
		&"stream_path": stream_path_for(_current_biome),
		&"base_volume_db": volume_db_for(_current_biome),
		&"intensity": _intensity,
		&"target_intensity": _target_intensity,
		&"duck_db": DUCK_DB,
		&"duck_gain": _duck_gain,
		&"duck_requests": _duck_requests,
		&"duck_hold_remaining": _duck_hold_remaining,
		&"last_duck_kind": _last_duck_kind,
		&"hazard_activity": _hazard_activity,
		&"hazard_bound": is_instance_valid(_hazard_source),
		&"enemy_audio_bound": is_instance_valid(_enemy_audio_router),
		&"voice_biomes": _voice_biomes.duplicate(),
		&"voice_gains": _voice_gains.duplicate(),
		&"switches": _switch_count,
		&"active": active,
		&"capacity": MAX_VOICES,
		&"crossfading": is_crossfading(),
		&"crossfade_seconds": CROSSFADE_SECONDS,
		&"crossfade_progress": minf(_fade_elapsed / CROSSFADE_SECONDS, 1.0),
		&"completed_crossfades": _completed_crossfades,
		&"restarts": _restart_count,
	}


static func normalize_biome(biome: StringName) -> StringName:
	if biome in [&"mud", &"wetland", &"water", &"oasis"]:
		return &"wetland"
	if biome in [&"snow", &"blue_ice", &"ice", &"frozen"]:
		return &"frozen"
	if biome in [&"volcanic", &"lava", &"basalt", &"obsidian"]:
		return &"volcanic"
	return &"sand"


static func stream_path_for(biome: StringName) -> String:
	return _stream_for(normalize_biome(biome)).resource_path


static func volume_db_for(biome: StringName) -> float:
	return float(BASE_VOLUME_DB_BY_BIOME.get(normalize_biome(biome), -10.0))


static func base_intensity_for(biome: StringName) -> float:
	return float(BASE_INTENSITY_BY_BIOME.get(normalize_biome(biome), 0.72))


static func crossfade_gains(progress: float) -> Vector2:
	var phase: float = clampf(progress, 0.0, 1.0) * PI * 0.5
	return Vector2(cos(phase), sin(phase))


func _bind_runtime_sources() -> void:
	if not is_inside_tree():
		return
	if not is_instance_valid(_hazard_source):
		_hazard_source = get_tree().get_first_node_in_group("weather_audio_source")
	if is_instance_valid(_enemy_audio_router):
		return
	_enemy_audio_router = get_tree().get_first_node_in_group("enemy_audio_router")
	if _enemy_audio_router == null:
		return
	var callback: Callable = Callable(self, "_on_enemy_cue")
	if not _enemy_audio_router.is_connected("cue_played", callback):
		_enemy_audio_router.connect("cue_played", callback)


func _sample_hazard_activity() -> void:
	var activity: float = 0.0
	if is_instance_valid(_hazard_source):
		if _current_biome == &"sand":
			var tornadoes: int = int(_hazard_source.call("get_hazard_count", &"tornado"))
			var storms: int = int(_hazard_source.call("get_hazard_count", &"sandstorm"))
			activity = clampf(float(tornadoes + storms) / 3.0, 0.0, 1.0)
		var events: Array = _hazard_source.call("get_deep_event_snapshots") as Array
		for event_value: Variant in events:
			var event: Dictionary = event_value as Dictionary
			if normalize_biome(event.get(&"biome", &"sand") as StringName) == _current_biome:
				activity = maxf(activity, 0.65)
	_hazard_activity = activity
	_target_intensity = clampf(
		base_intensity_for(_current_biome) + activity * MAX_HAZARD_BOOST, 0.0, 1.0
	)


func _on_enemy_cue(category: StringName, kind: StringName) -> void:
	if request_enemy_duck(category):
		_last_duck_kind = kind


func _advance_crossfade(delta: float) -> void:
	if not is_crossfading():
		return
	_fade_elapsed = minf(_fade_elapsed + delta, CROSSFADE_SECONDS)
	var gains: Vector2 = crossfade_gains(_fade_elapsed / CROSSFADE_SECONDS)
	_apply_voice_gain(_outgoing_index, _fade_start_gain * gains.x)
	_apply_voice_gain(
		_incoming_index,
		_fade_in_start_gain + (1.0 - _fade_in_start_gain) * gains.y,
	)
	if _fade_elapsed >= CROSSFADE_SECONDS:
		_players[_outgoing_index].stop()
		_apply_voice_gain(_outgoing_index, 0.0)
		_active_index = _incoming_index
		_completed_crossfades += 1


func _advance_mix(delta: float) -> void:
	_intensity = move_toward(_intensity, _target_intensity, delta * 1.8)
	_duck_hold_remaining = maxf(_duck_hold_remaining - delta, 0.0)
	var duck_target: float = DUCK_LINEAR if _duck_hold_remaining > 0.0 else 1.0
	var rate: float = DUCK_ATTACK_RATE if duck_target < _duck_gain else DUCK_RELEASE_RATE
	_duck_gain = move_toward(_duck_gain, duck_target, delta * rate)
	_refresh_voice_levels()


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
		_fade_in_start_gain = 0.0
		_voice_biomes[0] = biome
		_players[0].stream = _stream_for(biome)
		_apply_voice_gain(0, 1.0)
		_play_voice(0)
		_players[1].stop()
		_apply_voice_gain(1, 0.0)
		return
	var existing_index: int = _voice_index_for_biome(biome)
	if existing_index >= 0:
		_incoming_index = existing_index
		_outgoing_index = 1 - existing_index
	else:
		_outgoing_index = _dominant_voice_index()
		_incoming_index = 1 - _outgoing_index
		_players[_incoming_index].stop()
		_voice_biomes[_incoming_index] = biome
		_players[_incoming_index].stream = _stream_for(biome)
		_apply_voice_gain(_incoming_index, 0.0)
		_play_voice(_incoming_index)
	_active_index = _outgoing_index
	_fade_start_gain = _voice_gains[_outgoing_index]
	_fade_in_start_gain = _voice_gains[_incoming_index]
	_fade_elapsed = 0.0


func _ensure_players() -> void:
	if not _players.is_empty() or not is_inside_tree():
		return
	_configure_stream_loops()
	for index: int in range(MAX_VOICES):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "BiomeWeather%02d" % index
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
			_restart_count += 1


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
	var mix: float = normalized * _volume * _intensity * _duck_gain
	_players[index].volume_db = (
		SILENT_VOLUME_DB
		if mix <= 0.0
		else volume_db_for(_voice_biomes[index]) + linear_to_db(mix)
	)


func _dominant_voice_index() -> int:
	return 0 if _voice_gains[0] >= _voice_gains[1] else 1


func _voice_index_for_biome(biome: StringName) -> int:
	for index: int in range(_players.size()):
		if _voice_gains[index] > 0.0 and _voice_biomes[index] == biome:
			return index
	return -1


static func _stream_for(biome: StringName) -> AudioStream:
	match biome:
		&"wetland":
			return WETLAND
		&"frozen":
			return FROZEN
		&"volcanic":
			return VOLCANIC
	return DESERT
