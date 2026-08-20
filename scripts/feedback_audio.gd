extends Node

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const MAX_VOICES: int = 6

const SWING: AudioStream = preload("res://assets/audio/smash_swing.wav")
const FAUNA_CONTACT: AudioStream = preload("res://assets/audio/fauna_contact.wav")
const HEAVY_CONTACT: AudioStream = preload("res://assets/audio/heavy_contact.wav")
const STONE_BREAK: AudioStream = preload("res://assets/audio/stone_break.wav")
const WET_WOOD_BREAK: AudioStream = preload("res://assets/audio/wet_wood_break.wav")
const FAUNA_DEFEAT: AudioStream = preload("res://assets/audio/fauna_defeat.wav")

var _players: Array[AudioStreamPlayer] = []
var _enabled: bool = true
var _request_count: int = 0
var _played_count: int = 0
var _culled_count: int = 0
var _last_stream_path: String = ""


func _ready() -> void:
	_ensure_players()


func play_event(event: Dictionary) -> bool:
	if not _enabled:
		return false
	var stream: AudioStream = _stream_for(event)
	if stream == null:
		return false
	_request_count += 1
	_last_stream_path = stream.resource_path
	if DisplayServer.get_name() == "headless":
		return true
	_ensure_players()
	var player: AudioStreamPlayer = _available_player()
	if player == null:
		_culled_count += 1
		return false
	player.stream = stream
	player.pitch_scale = _pitch_for(event)
	player.play()
	_played_count += 1
	return true


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if enabled:
		return
	for player: AudioStreamPlayer in _players:
		player.stop()


func get_metrics() -> Dictionary:
	var active: int = 0
	for player: AudioStreamPlayer in _players:
		if player.playing:
			active += 1
	return {
		&"enabled": _enabled,
		&"requests": _request_count,
		&"played": _played_count,
		&"culled": _culled_count,
		&"active": active,
		&"capacity": MAX_VOICES,
		&"last_stream_path": _last_stream_path,
	}


func _stream_for(event: Dictionary) -> AudioStream:
	var event_id: StringName = event.get(&"event_id", &"") as StringName
	if event_id == RuntimeIdsScript.EVENT_SMASH_WHIFF:
		return SWING
	if event_id == RuntimeIdsScript.EVENT_SMASH_DEFEAT:
		return FAUNA_DEFEAT
	if event_id == RuntimeIdsScript.EVENT_SMASH_BREAK:
		return WET_WOOD_BREAK if event.get(&"material", &"") == &"wet_wood" else STONE_BREAK
	if event_id == RuntimeIdsScript.EVENT_SMASH_HEAVY_HIT:
		return HEAVY_CONTACT
	if event_id == RuntimeIdsScript.EVENT_SMASH_HIT:
		return FAUNA_CONTACT
	return null


func _pitch_for(event: Dictionary) -> float:
	var sequence_id: int = int(event.get(&"sequence_id", 0))
	return 0.97 + float(posmod(sequence_id * 17, 7)) * 0.01


func _ensure_players() -> void:
	if not _players.is_empty() or not is_inside_tree():
		return
	for index: int in range(MAX_VOICES):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "FeedbackVoice%02d" % index
		add_child(player)
		_players.append(player)


func _available_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			return player
	return null
