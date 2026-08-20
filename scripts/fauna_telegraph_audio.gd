extends Node

const MAX_VOICES: int = 4
const MAX_HISTORY: int = 32
const WORM_KIND: StringName = &"sandworm"
const SKIMMER_KIND: StringName = &"mud_skimmer"
const RIME_KIND: StringName = &"rime_stalker"
const CINDER_KIND: StringName = &"cinder_crawler"

const SANDWORM_WARNING: AudioStream = preload("res://assets/audio/fauna_telegraph_sandworm.wav")
const MUD_WARNING: AudioStream = preload("res://assets/audio/fauna_telegraph_mud.wav")
const RIME_WARNING: AudioStream = preload("res://assets/audio/fauna_telegraph_rime.wav")
const CINDER_WARNING: AudioStream = preload("res://assets/audio/fauna_telegraph_cinder.wav")

var _players: Array[AudioStreamPlayer] = []
var _enabled: bool = true
var _seen: Dictionary = {}
var _history: Array[String] = []
var _warning_count: int = 0
var _request_count: int = 0
var _played_count: int = 0
var _muted_count: int = 0
var _duplicate_count: int = 0
var _culled_count: int = 0
var _last_kind: StringName = &""
var _last_stream_path: String = ""


func _ready() -> void:
	_ensure_players()
	call_deferred("_bind_accessibility")


func play_warning(kind: StringName, enemy_id: int, attack_serial: int) -> bool:
	var stream: AudioStream = stream_for(kind)
	if stream == null or enemy_id < 0 or attack_serial <= 0:
		return false
	var key: String = "%s:%d:%d" % [kind, enemy_id, attack_serial]
	if _seen.has(key):
		_duplicate_count += 1
		return false
	_remember(key)
	_warning_count += 1
	if not _enabled:
		_muted_count += 1
		return false
	_request_count += 1
	_last_kind = kind
	_last_stream_path = stream.resource_path
	if DisplayServer.get_name() == "headless":
		return true
	_ensure_players()
	var player: AudioStreamPlayer = _available_player()
	if player == null:
		_culled_count += 1
		return false
	player.stream = stream
	player.pitch_scale = 1.0
	player.play()
	_played_count += 1
	return true


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if enabled:
		return
	for player: AudioStreamPlayer in _players:
		player.stop()


func stream_for(kind: StringName) -> AudioStream:
	if kind == WORM_KIND:
		return SANDWORM_WARNING
	if kind == SKIMMER_KIND:
		return MUD_WARNING
	if kind == RIME_KIND:
		return RIME_WARNING
	if kind == CINDER_KIND:
		return CINDER_WARNING
	return null


func get_metrics() -> Dictionary:
	var active: int = 0
	for player: AudioStreamPlayer in _players:
		if player.playing:
			active += 1
	return {
		&"enabled": _enabled,
		&"warnings": _warning_count,
		&"requests": _request_count,
		&"played": _played_count,
		&"muted": _muted_count,
		&"duplicates": _duplicate_count,
		&"culled": _culled_count,
		&"active": active,
		&"capacity": MAX_VOICES,
		&"history": _history.size(),
		&"last_kind": _last_kind,
		&"last_stream_path": _last_stream_path,
	}


func _remember(key: String) -> void:
	_seen[key] = true
	_history.append(key)
	if _history.size() <= MAX_HISTORY:
		return
	var expired: String = _history.pop_front()
	_seen.erase(expired)


func _ensure_players() -> void:
	if not _players.is_empty() or not is_inside_tree():
		return
	for index: int in range(MAX_VOICES):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "TelegraphVoice%02d" % index
		add_child(player)
		_players.append(player)


func _available_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			return player
	return null


func _bind_accessibility() -> void:
	var panel: Node = get_tree().get_first_node_in_group("accessibility_panel")
	if panel == null:
		return
	_apply_preferences(panel.call("get_preferences") as Dictionary)
	panel.connect("preferences_changed", _apply_preferences)


func _apply_preferences(snapshot: Dictionary) -> void:
	set_enabled(bool(snapshot.get(&"sfx_enabled", true)))
