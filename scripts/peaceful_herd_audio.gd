extends Node

const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")

const EVENT_AMBIENT: StringName = &"ambient"
const EVENT_DEFEAT: StringName = &"defeat"
const AMBIENT_MIN_SECONDS: float = 5.5
const AMBIENT_MAX_SECONDS: float = 9.0
const AMBIENT_VOLUME_DB: float = -12.0
const DEFEAT_VOLUME_DB: float = -2.0
const AMBIENT_MAX_DISTANCE: float = 980.0
const DEFEAT_MAX_DISTANCE: float = 1400.0

const DUNE_AMBIENT: AudioStream = preload(
	"res://assets/audio/herd_dune_grazer_ambient.wav"
)
const DUNE_DEFEAT: AudioStream = preload(
	"res://assets/audio/herd_dune_grazer_defeat.wav"
)
const REEDBACK_AMBIENT: AudioStream = preload(
	"res://assets/audio/herd_reedback_ambient.wav"
)
const REEDBACK_DEFEAT: AudioStream = preload(
	"res://assets/audio/herd_reedback_defeat.wav"
)
const RIMEHORN_AMBIENT: AudioStream = preload(
	"res://assets/audio/herd_rimehorn_ambient.wav"
)
const RIMEHORN_DEFEAT: AudioStream = preload(
	"res://assets/audio/herd_rimehorn_defeat.wav"
)
const EMBER_AMBIENT: AudioStream = preload(
	"res://assets/audio/herd_ember_ram_ambient.wav"
)
const EMBER_DEFEAT: AudioStream = preload(
	"res://assets/audio/herd_ember_ram_defeat.wav"
)

const AMBIENT_CUES: Dictionary = {
	&"dune_grazer": DUNE_AMBIENT,
	&"reedback": REEDBACK_AMBIENT,
	&"rimehorn": RIMEHORN_AMBIENT,
	&"ember_ram": EMBER_AMBIENT,
}
const DEFEAT_CUES: Dictionary = {
	&"dune_grazer": DUNE_DEFEAT,
	&"reedback": REEDBACK_DEFEAT,
	&"rimehorn": RIMEHORN_DEFEAT,
	&"ember_ram": EMBER_DEFEAT,
}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _enabled: bool = true
var _ambient_elapsed: float = 0.0
var _next_ambient_seconds: float = AMBIENT_MIN_SECONDS
var _ambient_cursor: int = 0
var _ambient_requests: int = 0
var _defeat_requests: int = 0
var _played_count: int = 0
var _culled_count: int = 0
var _last_kind: StringName = &""
var _last_event: StringName = &""
var _last_stream_path: String = ""
var _last_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_rng.seed = 0xA011D10
	_schedule_next()


func advance(delta: float, creatures: Array[Dictionary], projection: Callable) -> bool:
	if not _enabled or creatures.is_empty() or not projection.is_valid():
		return false
	_ambient_elapsed += maxf(delta, 0.0)
	if _ambient_elapsed < _next_ambient_seconds:
		return false
	var index: int = _ambient_cursor % creatures.size()
	_ambient_cursor += 1
	var creature: Dictionary = creatures[index]
	var accepted: bool = play_ambient(
		creature.get(&"kind", &"") as StringName,
		int(creature.get(&"id", -1)),
		creature.get(&"position", Vector2.ZERO) as Vector2,
		projection,
	)
	_schedule_next()
	return accepted


func play_ambient(
	kind: StringName,
	creature_id: int,
	grid_position: Vector2,
	projection: Callable,
) -> bool:
	if creature_id < 0:
		return false
	var pitch: float = 0.97 + float(posmod(creature_id * 13, 7)) * 0.01
	return _play(kind, EVENT_AMBIENT, grid_position, projection, pitch)


func play_defeat(kind: StringName, grid_position: Vector2, projection: Callable) -> bool:
	return _play(kind, EVENT_DEFEAT, grid_position, projection, 1.0)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func reset_schedule() -> void:
	_ambient_elapsed = 0.0
	_schedule_next()


func get_metrics() -> Dictionary:
	return {
		&"enabled": _enabled,
		&"ambient_requests": _ambient_requests,
		&"defeat_requests": _defeat_requests,
		&"played": _played_count,
		&"culled": _culled_count,
		&"last_kind": _last_kind,
		&"last_event": _last_event,
		&"last_stream_path": _last_stream_path,
		&"last_position": _last_position,
		&"next_ambient_seconds": _next_ambient_seconds,
	}


static func stream_for(kind: StringName, event: StringName) -> AudioStream:
	if event == EVENT_AMBIENT:
		return AMBIENT_CUES.get(kind) as AudioStream
	if event == EVENT_DEFEAT:
		return DEFEAT_CUES.get(kind) as AudioStream
	return null


static func cue_path(kind: StringName, event: StringName) -> String:
	var stream: AudioStream = stream_for(kind, event)
	return stream.resource_path if stream != null else ""


func _play(
	kind: StringName,
	event: StringName,
	grid_position: Vector2,
	projection: Callable,
	pitch: float,
) -> bool:
	if not _enabled or not projection.is_valid():
		return false
	var stream: AudioStream = stream_for(kind, event)
	if stream == null:
		return false
	var screen_position: Vector2 = projection.call(grid_position) as Vector2
	_last_kind = kind
	_last_event = event
	_last_stream_path = stream.resource_path
	_last_position = screen_position
	if event == EVENT_AMBIENT:
		_ambient_requests += 1
	else:
		_defeat_requests += 1
	if DisplayServer.get_name() == "headless" and not is_inside_tree():
		_played_count += 1
		return true
	var service: Node = _audio_service()
	if service == null:
		_culled_count += 1
		return false
	var volume_db: float = AMBIENT_VOLUME_DB if event == EVENT_AMBIENT else DEFEAT_VOLUME_DB
	var priority: int = 0 if event == EVENT_AMBIENT else 2
	var max_distance: float = (
		AMBIENT_MAX_DISTANCE if event == EVENT_AMBIENT else DEFEAT_MAX_DISTANCE
	)
	var accepted: bool = bool(
		service.call(
			"play_spatial",
			stream,
			screen_position,
			AudioServiceScript.BUS_WORLD,
			pitch,
			volume_db,
			priority,
			max_distance,
		)
	)
	if accepted:
		_played_count += 1
	else:
		_culled_count += 1
	return accepted


func _schedule_next() -> void:
	_ambient_elapsed = 0.0
	_next_ambient_seconds = _rng.randf_range(AMBIENT_MIN_SECONDS, AMBIENT_MAX_SECONDS)


func _audio_service() -> Node:
	return get_node_or_null("/root/AudioService") if is_inside_tree() else null
