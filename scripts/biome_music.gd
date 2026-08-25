extends Node

const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")
const ClearingMusicScript: GDScript = preload("res://scripts/clearing_music_catalog.gd")
const DESERT_PRIMARY: AudioStream = preload("res://assets/audio/bgm_desert.ogg")
const DESERT_ALTERNATE: AudioStream = preload("res://assets/audio/bgm_desert_alt.ogg")
const WETLAND_PRIMARY: AudioStream = preload("res://assets/audio/bgm_wetland.ogg")
const WETLAND_ALTERNATE: AudioStream = preload("res://assets/audio/bgm_wetland_alt.ogg")
const FROZEN_PRIMARY: AudioStream = preload("res://assets/audio/bgm_frozen.ogg")
const FROZEN_ALTERNATE: AudioStream = preload("res://assets/audio/bgm_frozen_alt.ogg")
const VOLCANIC_PRIMARY: AudioStream = preload("res://assets/audio/bgm_volcanic.ogg")
const VOLCANIC_ALTERNATE: AudioStream = preload("res://assets/audio/bgm_volcanic_alt.ogg")
const CLEARING_DAY: AudioStream = preload(
	"res://assets/audio/harvest/music_clearing_day_loop.wav"
)
const CLEARING_NIGHT: AudioStream = preload(
	"res://assets/audio/harvest/music_clearing_night_loop.wav"
)
const CLEARING_RAIN: AudioStream = preload(
	"res://assets/audio/harvest/music_clearing_rain_loop.wav"
)

const MAX_VOICES: int = 2
const TRACK_VOLUME_DB_BY_BIOME: Dictionary = {
	&"sand": -6.0,
	&"wetland": -5.0,
	&"frozen": -4.0,
	&"volcanic": -7.0,
	ClearingMusicScript.TRACK_DAY: -8.0,
	ClearingMusicScript.TRACK_NIGHT: -9.0,
	ClearingMusicScript.TRACK_RAIN: -8.0,
}
const SILENT_VOLUME_DB: float = -80.0
const CROSSFADE_SECONDS: float = 4.0

var _players: Array[AudioStreamPlayer] = []
var _voice_gains: Array[float] = [0.0, 0.0]
var _voice_biomes: Array[StringName] = [&"sand", &"sand"]
var _voice_variants: Array[int] = [0, 0]
var _current_biome: StringName = &"sand"
var _current_variant: int = 0
var _active_index: int = 0
var _outgoing_index: int = 0
var _incoming_index: int = 0
var _fade_elapsed: float = CROSSFADE_SECONDS
var _fade_start_gain: float = 1.0
var _fade_in_start_gain: float = 0.0
var _enabled: bool = true
var _volume: float = 1.0
var _switch_count: int = 0
var _track_change_count: int = 0
var _completed_crossfades: int = 0
var _track_elapsed: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _variant_bags: Dictionary = {}
var _last_variants: Dictionary = {}
var _clearing_track: StringName = &""


func _init() -> void:
	_rng.randomize()


func _ready() -> void:
	_ensure_players()
	_start_biome(_current_biome, true)


func _process(delta: float) -> void:
	if not _enabled or _players.is_empty():
		return
	_restart_finished_voices()
	if not is_crossfading():
		_track_elapsed += maxf(delta, 0.0)
		if _should_rotate_track():
			advance_track()
	if not is_crossfading():
		return
	_fade_elapsed = minf(_fade_elapsed + maxf(delta, 0.0), CROSSFADE_SECONDS)
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
		_track_elapsed = CROSSFADE_SECONDS
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
	if _clearing_track == &"":
		_start_biome(normalized, false)
	return true


func set_clearing_context(
	active: bool, minute_of_day: int, weather_id: StringName
) -> StringName:
	var selected: StringName = (
		ClearingMusicScript.select_track(minute_of_day, weather_id) if active else &""
	)
	if selected == _clearing_track:
		return selected
	_clearing_track = selected
	_track_change_count += 1
	_start_biome(selected if selected != &"" else _current_biome, false)
	return selected


func advance_track() -> bool:
	if not _enabled or _volume <= 0.0 or is_crossfading() or _clearing_track != &"":
		return false
	_track_change_count += 1
	_start_biome(_current_biome, false)
	return true


func set_random_seed(seed_value: int) -> void:
	_rng.seed = seed_value
	_variant_bags.clear()
	_last_variants.clear()


func set_enabled(enabled: bool) -> void:
	if _enabled == enabled:
		return
	_enabled = enabled
	_ensure_players()
	if not enabled:
		_stop_all()
	elif _volume > 0.0:
		_start_biome(_active_track_id(), true)


func set_volume(volume: float) -> void:
	var previous: float = _volume
	_volume = clampf(volume, 0.0, 1.0)
	if _volume <= 0.0:
		_stop_all()
	elif _enabled and previous <= 0.0:
		_start_biome(_active_track_id(), true)
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
			&"clearing_track": _clearing_track,
		&"variant": _current_variant,
		&"variant_name": variant_name(_current_variant),
			&"stream_path": _stream_for(_active_track_id(), _current_variant).resource_path,
		&"stream_paths": stream_paths_for(_current_biome),
		&"track_volume_db": volume_db_for(_current_biome),
		&"track_elapsed": _track_elapsed,
		&"voice_biomes": _voice_biomes.duplicate(),
		&"voice_variants": _voice_variants.duplicate(),
		&"switches": _switch_count,
		&"track_changes": _track_change_count,
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


static func stream_path_for(biome: StringName, variant: int = 0) -> String:
	return _stream_for(normalize_biome(biome), variant).resource_path


static func stream_paths_for(biome: StringName) -> Array[String]:
	var normalized: StringName = normalize_biome(biome)
	return [
		_stream_for(normalized, 0).resource_path,
		_stream_for(normalized, 1).resource_path,
	]


static func variant_name(variant: int) -> StringName:
	return &"alternate" if posmod(variant, 2) == 1 else &"primary"


static func volume_db_for(biome: StringName) -> float:
	if TRACK_VOLUME_DB_BY_BIOME.has(biome):
		return float(TRACK_VOLUME_DB_BY_BIOME[biome])
	var normalized: StringName = normalize_biome(biome)
	return float(TRACK_VOLUME_DB_BY_BIOME.get(normalized, -6.0))


static func crossfade_gains(progress: float) -> Vector2:
	var phase: float = clampf(progress, 0.0, 1.0) * PI * 0.5
	return Vector2(cos(phase), sin(phase))


func _start_biome(biome: StringName, immediate: bool) -> void:
	if not _enabled or _volume <= 0.0:
		return
	_ensure_players()
	if _players.is_empty():
		return
	var variant: int = 0 if biome in ClearingMusicScript.PATHS else _draw_variant(biome)
	_current_variant = variant
	_track_elapsed = 0.0
	if immediate:
		_active_index = 0
		_outgoing_index = 0
		_incoming_index = 0
		_fade_elapsed = CROSSFADE_SECONDS
		_fade_in_start_gain = 0.0
		_voice_biomes[0] = biome
		_voice_variants[0] = variant
		_players[0].stream = _stream_for(biome, variant)
		_apply_voice_gain(0, 1.0)
		_play_voice(0)
		_players[1].stop()
		_apply_voice_gain(1, 0.0)
		return
	var existing_index: int = _voice_index_for_track(biome, variant)
	if existing_index >= 0:
		_incoming_index = existing_index
		_outgoing_index = 1 - existing_index
	else:
		_outgoing_index = _dominant_voice_index()
		_incoming_index = 1 - _outgoing_index
		_players[_incoming_index].stop()
		_voice_biomes[_incoming_index] = biome
		_voice_variants[_incoming_index] = variant
		_players[_incoming_index].stream = _stream_for(biome, variant)
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
		player.name = "BiomeMusic%02d" % index
		player.bus = AudioServiceScript.BUS_MUSIC
		player.volume_db = SILENT_VOLUME_DB
		add_child(player)
		_players.append(player)


func _configure_stream_loops() -> void:
	for stream: AudioStream in [
		DESERT_PRIMARY,
		DESERT_ALTERNATE,
		WETLAND_PRIMARY,
		WETLAND_ALTERNATE,
		FROZEN_PRIMARY,
		FROZEN_ALTERNATE,
		VOLCANIC_PRIMARY,
		VOLCANIC_ALTERNATE,
		CLEARING_DAY,
		CLEARING_NIGHT,
		CLEARING_RAIN,
	]:
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamWAV:
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
		else _voice_volume_db(index) + linear_to_db(normalized)
	)


func _dominant_voice_index() -> int:
	return 0 if _voice_gains[0] >= _voice_gains[1] else 1


func _voice_index_for_track(biome: StringName, variant: int) -> int:
	for index: int in range(_players.size()):
		if (
			_voice_gains[index] > 0.0
			and _voice_biomes[index] == biome
			and _voice_variants[index] == variant
		):
			return index
	return -1


func _voice_volume_db(index: int) -> float:
	return volume_db_for(_voice_biomes[index]) + linear_to_db(maxf(_volume, 0.001))


func _active_track_id() -> StringName:
	return _clearing_track if _clearing_track != &"" else _current_biome


func _should_rotate_track() -> bool:
	if _clearing_track != &"":
		return false
	if _active_index < 0 or _active_index >= _players.size():
		return false
	var stream: AudioStream = _players[_active_index].stream
	if stream == null:
		return false
	var rotation_time: float = maxf(stream.get_length() - CROSSFADE_SECONDS, CROSSFADE_SECONDS)
	return _track_elapsed >= rotation_time


func _draw_variant(biome: StringName) -> int:
	var bag: Array[int] = []
	if _variant_bags.has(biome):
		bag.assign(_variant_bags[biome] as Array)
	if bag.is_empty():
		bag = [0, 1]
		if _rng.randi_range(0, 1) == 1:
			bag.reverse()
		var previous: int = int(_last_variants.get(biome, -1))
		if bag[-1] == previous:
			bag.reverse()
	var variant: int = bag.pop_back()
	_variant_bags[biome] = bag
	_last_variants[biome] = variant
	return variant


static func _stream_for(biome: StringName, variant: int) -> AudioStream:
	var alternate: bool = posmod(variant, 2) == 1
	match biome:
		ClearingMusicScript.TRACK_DAY:
			return CLEARING_DAY
		ClearingMusicScript.TRACK_NIGHT:
			return CLEARING_NIGHT
		ClearingMusicScript.TRACK_RAIN:
			return CLEARING_RAIN
		&"wetland":
			return WETLAND_ALTERNATE if alternate else WETLAND_PRIMARY
		&"frozen":
			return FROZEN_ALTERNATE if alternate else FROZEN_PRIMARY
		&"volcanic":
			return VOLCANIC_ALTERNATE if alternate else VOLCANIC_PRIMARY
	return DESERT_ALTERNATE if alternate else DESERT_PRIMARY
