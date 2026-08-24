extends Node

const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")
const MAX_VOICES: int = AudioServiceScript.SPATIAL_VOICE_COUNT
const MAX_HISTORY: int = 64
const WORM_KIND: StringName = &"sandworm"
const SKIMMER_KIND: StringName = &"mud_skimmer"
const RIME_KIND: StringName = &"rime_stalker"
const CINDER_KIND: StringName = &"cinder_crawler"
const GLASSBACK_KIND: StringName = &"glassback_scarab"
const MIRE_TICK_KIND: StringName = &"mire_tick"
const RIME_SHARDLING_KIND: StringName = &"rime_shardling"
const EMBER_SKITTER_KIND: StringName = &"ember_skitter"
const KILNHEART_KIND: StringName = &"kilnheart_colossus"
const PATTERN_FORGE_SWEEP: StringName = &"forge_sweep"
const PATTERN_MAGMA_RAM: StringName = &"magma_ram"
const PATTERN_CALDERA_BARRAGE: StringName = &"caldera_barrage"

const SANDWORM_WARNING: AudioStream = preload("res://assets/audio/fauna_telegraph_sandworm.wav")
const MUD_WARNING: AudioStream = preload("res://assets/audio/fauna_telegraph_mud.wav")
const RIME_WARNING: AudioStream = preload("res://assets/audio/fauna_telegraph_rime.wav")
const CINDER_WARNING: AudioStream = preload("res://assets/audio/fauna_telegraph_cinder.wav")
const GLASSBACK_MOVE: AudioStream = preload(
	"res://assets/audio/enemies/mob_glassback_move.wav"
)
const GLASSBACK_ATTACK: AudioStream = preload(
	"res://assets/audio/enemies/mob_glassback_attack.wav"
)
const MIRE_TICK_MOVE: AudioStream = preload("res://assets/audio/enemies/mob_mire_tick_move.wav")
const MIRE_TICK_ATTACK: AudioStream = preload(
	"res://assets/audio/enemies/mob_mire_tick_attack.wav"
)
const RIME_SHARDLING_MOVE: AudioStream = preload(
	"res://assets/audio/enemies/mob_rime_shardling_move.wav"
)
const RIME_SHARDLING_ATTACK: AudioStream = preload(
	"res://assets/audio/enemies/mob_rime_shardling_attack.wav"
)
const EMBER_SKITTER_MOVE: AudioStream = preload(
	"res://assets/audio/enemies/mob_ember_skitter_move.wav"
)
const EMBER_SKITTER_ATTACK: AudioStream = preload(
	"res://assets/audio/enemies/mob_ember_skitter_attack.wav"
)
const KILNHEART_MOVE: AudioStream = preload(
	"res://assets/audio/enemies/boss_kilnheart_move.wav"
)
const KILNHEART_SWEEP: AudioStream = preload(
	"res://assets/audio/enemies/boss_kilnheart_forge_sweep.wav"
)
const KILNHEART_RAM: AudioStream = preload(
	"res://assets/audio/enemies/boss_kilnheart_magma_ram.wav"
)
const KILNHEART_BARRAGE: AudioStream = preload(
	"res://assets/audio/enemies/boss_kilnheart_caldera_barrage.wav"
)
const MOB_ATTACKS: Dictionary = {
	GLASSBACK_KIND: GLASSBACK_ATTACK,
	MIRE_TICK_KIND: MIRE_TICK_ATTACK,
	RIME_SHARDLING_KIND: RIME_SHARDLING_ATTACK,
	EMBER_SKITTER_KIND: EMBER_SKITTER_ATTACK,
}
const KILNHEART_ATTACKS: Dictionary = {
	PATTERN_FORGE_SWEEP: KILNHEART_SWEEP,
	PATTERN_MAGMA_RAM: KILNHEART_RAM,
	PATTERN_CALDERA_BARRAGE: KILNHEART_BARRAGE,
}

var _enabled: bool = true
var _seen: Dictionary = {}
var _history: Array[String] = []
var _warning_count: int = 0
var _movement_count: int = 0
var _attack_count: int = 0
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
	pattern: StringName = &"",
) -> bool:
	_warning_count += 1
	return _play_once(
		attack_stream_for(kind, pattern) if kind == KILNHEART_KIND else stream_for(kind),
		kind,
		"warning:%s:%d:%d" % [kind, enemy_id, attack_serial],
		position,
		0.0,
		1.0,
		3,
		1800.0,
	)


func play_movement(
	kind: StringName,
	enemy_id: int,
	movement_serial: int,
	position: Vector2 = Vector2.ZERO,
) -> bool:
	_movement_count += 1
	var pitch: float = 1.0 + float((movement_serial % 3) - 1) * 0.025
	return _play_once(
		movement_stream_for(kind),
		kind,
		"move:%s:%d:%d" % [kind, enemy_id, movement_serial],
		position,
		-6.0 if kind != KILNHEART_KIND else -2.0,
		pitch,
		1 if kind != KILNHEART_KIND else 3,
		1250.0 if kind != KILNHEART_KIND else 1900.0,
	)


func play_attack(
	kind: StringName,
	enemy_id: int,
	attack_serial: int,
	position: Vector2 = Vector2.ZERO,
	pattern: StringName = &"",
) -> bool:
	_attack_count += 1
	return _play_once(
		attack_stream_for(kind, pattern),
		kind,
		"attack:%s:%d:%d" % [kind, enemy_id, attack_serial],
		position,
		-2.0,
		1.0,
		3,
		1500.0 if kind != KILNHEART_KIND else 1900.0,
	)


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
	if kind == KILNHEART_KIND:
		return KILNHEART_SWEEP
	return null


func movement_stream_for(kind: StringName) -> AudioStream:
	if kind == GLASSBACK_KIND:
		return GLASSBACK_MOVE
	if kind == MIRE_TICK_KIND:
		return MIRE_TICK_MOVE
	if kind == RIME_SHARDLING_KIND:
		return RIME_SHARDLING_MOVE
	if kind == EMBER_SKITTER_KIND:
		return EMBER_SKITTER_MOVE
	if kind == KILNHEART_KIND:
		return KILNHEART_MOVE
	return null


func attack_stream_for(kind: StringName, pattern: StringName = &"") -> AudioStream:
	if kind == KILNHEART_KIND:
		return KILNHEART_ATTACKS.get(pattern, KILNHEART_SWEEP) as AudioStream
	return MOB_ATTACKS.get(kind, null) as AudioStream


func get_metrics() -> Dictionary:
	var service: Node = _audio_service()
	var service_metrics: Dictionary = (
		service.call("get_metrics") as Dictionary if service != null else {}
	)
	return {
		&"enabled": _enabled,
		&"warnings": _warning_count,
		&"movements": _movement_count,
		&"attacks": _attack_count,
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


func _play_once(
	stream: AudioStream,
	kind: StringName,
	key: String,
	position: Vector2,
	volume_db: float,
	pitch: float,
	priority: int,
	max_distance: float,
) -> bool:
	if stream == null:
		return false
	if _seen.has(key):
		_duplicate_count += 1
		return false
	_remember(key)
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
			pitch,
			volume_db,
			priority,
			max_distance,
		)
	)
	_played_count += 1 if accepted else 0
	_culled_count += 0 if accepted else 1
	return accepted


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
