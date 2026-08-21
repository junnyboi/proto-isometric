extends Node

const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")
const MAX_VOICES: int = AudioServiceScript.SPATIAL_VOICE_COUNT
const MAX_HISTORY: int = 32
const WORM_KIND: StringName = &"sandworm"
const SKIMMER_KIND: StringName = &"mud_skimmer"
const RIME_KIND: StringName = &"rime_stalker"
const CINDER_KIND: StringName = &"cinder_crawler"

const SANDWORM_WARNING: AudioStream = preload("res://assets/audio/fauna_telegraph_sandworm.wav")
const MUD_WARNING: AudioStream = preload("res://assets/audio/fauna_telegraph_mud.wav")
const RIME_WARNING: AudioStream = preload("res://assets/audio/fauna_telegraph_rime.wav")
const CINDER_WARNING: AudioStream = preload("res://assets/audio/fauna_telegraph_cinder.wav")

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
var _last_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	call_deferred("_bind_accessibility")


func play_warning(
	kind: StringName,
	enemy_id: int,
	attack_serial: int,
	position: Vector2 = Vector2.ZERO,
) -> bool:
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
	_last_position = position
	if DisplayServer.get_name() == "headless" and not is_inside_tree():
		_played_count += 1
		return true
	var service: Node = _audio_service()
	if service == null:
		_culled_count += 1
		return false
	var accepted: bool = bool(
		service.call(
			"play_spatial",
			stream,
			position,
			AudioServiceScript.BUS_ENEMY,
			1.0,
			0.0,
			3,
			1800.0,
		)
	)
	if accepted:
		_played_count += 1
	else:
		_culled_count += 1
	return accepted


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	var service: Node = _audio_service()
	if service != null:
		service.call("set_sfx_enabled", enabled)


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
	var service: Node = _audio_service()
	var service_metrics: Dictionary = (
		service.call("get_metrics") as Dictionary if service != null else {}
	)
	return {
		&"enabled": _enabled,
		&"warnings": _warning_count,
		&"requests": _request_count,
		&"played": _played_count,
		&"muted": _muted_count,
		&"duplicates": _duplicate_count,
		&"culled": _culled_count,
		&"active": int(service_metrics.get(&"spatial_active", 0)),
		&"capacity": MAX_VOICES,
		&"history": _history.size(),
		&"last_kind": _last_kind,
		&"last_stream_path": _last_stream_path,
		&"last_position": _last_position,
	}


func _remember(key: String) -> void:
	_seen[key] = true
	_history.append(key)
	if _history.size() <= MAX_HISTORY:
		return
	var expired: String = _history.pop_front()
	_seen.erase(expired)


func _bind_accessibility() -> void:
	var panel: Node = get_tree().get_first_node_in_group("accessibility_panel")
	if panel == null:
		return
	_apply_preferences(panel.call("get_preferences") as Dictionary)
	panel.connect("preferences_changed", _apply_preferences)


func _apply_preferences(snapshot: Dictionary) -> void:
	set_enabled(bool(snapshot.get(&"sfx_enabled", true)))


func _audio_service() -> Node:
	return get_node_or_null("/root/AudioService") if is_inside_tree() else null
