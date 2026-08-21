extends Node

const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")
const DESERT: AudioStream = preload("res://assets/audio/ambience_desert.wav")
const WETLAND: AudioStream = preload("res://assets/audio/ambience_wetland.wav")
const FROZEN: AudioStream = preload("res://assets/audio/ambience_frozen.wav")
const VOLCANIC: AudioStream = preload("res://assets/audio/ambience_volcanic.wav")

const MAX_VOICES: int = 2
const BED_VOLUME_DB: float = -30.0
const SILENT_VOLUME_DB: float = -48.0
const CROSSFADE_SECONDS: float = 1.25

var _players: Array[AudioStreamPlayer] = []
var _current_biome: StringName = &"sand"
var _active_index: int = 0
var _incoming_index: int = 0
var _fade_elapsed: float = CROSSFADE_SECONDS
var _enabled: bool = true
var _volume: float = 1.0
var _switch_count: int = 0


func _ready() -> void:
	_ensure_players()
	_start_biome(_current_biome, true)


func _process(delta: float) -> void:
	if not _enabled or _players.is_empty():
		return
	_restart_finished_voice()
	if _fade_elapsed >= CROSSFADE_SECONDS or _incoming_index == _active_index:
		return
	_fade_elapsed = minf(_fade_elapsed + maxf(delta, 0.0), CROSSFADE_SECONDS)
	var ratio: float = _fade_elapsed / CROSSFADE_SECONDS
	var bed_db: float = _bed_volume_db()
	_players[_incoming_index].volume_db = lerpf(SILENT_VOLUME_DB, bed_db, ratio)
	_players[_active_index].volume_db = lerpf(bed_db, SILENT_VOLUME_DB, ratio)
	if _fade_elapsed >= CROSSFADE_SECONDS:
		_players[_active_index].stop()
		_active_index = _incoming_index


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
	_enabled = enabled
	_ensure_players()
	if not enabled:
		for player: AudioStreamPlayer in _players:
			player.stop()
		return
	if _volume > 0.0:
		_start_biome(_current_biome, true)


func set_volume(volume: float) -> void:
	_volume = clampf(volume, 0.0, 1.0)
	if _volume <= 0.0:
		for player: AudioStreamPlayer in _players:
			player.stop()
		return
	if _enabled:
		_start_biome(_current_biome, true)


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


func _start_biome(biome: StringName, immediate: bool) -> void:
	if not _enabled or DisplayServer.get_name() == "headless":
		return
	_ensure_players()
	var next_index: int = _active_index if immediate else 1 - _active_index
	var player: AudioStreamPlayer = _players[next_index]
	player.stream = _stream_for(biome)
	player.volume_db = _bed_volume_db() if immediate else SILENT_VOLUME_DB
	player.play()
	if immediate:
		for index: int in range(_players.size()):
			if index != next_index:
				_players[index].stop()
		_active_index = next_index
		_incoming_index = next_index
		_fade_elapsed = CROSSFADE_SECONDS
		return
	_incoming_index = next_index
	_fade_elapsed = 0.0


func _ensure_players() -> void:
	if not _players.is_empty() or not is_inside_tree():
		return
	for index: int in range(MAX_VOICES):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "BiomeBed%02d" % index
		player.bus = AudioServiceScript.BUS_AMBIENT
		player.volume_db = SILENT_VOLUME_DB
		add_child(player)
		_players.append(player)


func _restart_finished_voice() -> void:
	var player: AudioStreamPlayer = _players[_active_index]
	if _volume > 0.0 and not player.playing and player.stream != null:
		player.play()


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
