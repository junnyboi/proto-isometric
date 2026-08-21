extends Node

const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const MAX_VOICES: int = AudioServiceScript.SPATIAL_VOICE_COUNT

const SWING: AudioStream = preload("res://assets/audio/smash_swing.wav")
const FAUNA_CONTACT: AudioStream = preload("res://assets/audio/fauna_contact.wav")
const HEAVY_CONTACT: AudioStream = preload("res://assets/audio/heavy_contact.wav")
const STONE_BREAK: AudioStream = preload("res://assets/audio/stone_break.wav")
const WET_WOOD_BREAK: AudioStream = preload("res://assets/audio/wet_wood_break.wav")
const FAUNA_DEFEAT: AudioStream = preload("res://assets/audio/fauna_defeat.wav")
const SERVO_ENGAGE: AudioStream = preload("res://assets/audio/servo_engage.wav")
const HEAVY_GAIT: AudioStream = preload("res://assets/audio/heavy_gait.wav")
const SURFACE_STEP: AudioStream = preload("res://assets/audio/surface_step.wav")
const CHARGE_DETENT: AudioStream = preload("res://assets/audio/charge_detent.wav")
const BLOCKED_CLANK: AudioStream = preload("res://assets/audio/blocked_clank.wav")
const PICKUP: AudioStream = preload("res://assets/audio/charge_ready.wav")
const RELAY_COMPLETE: AudioStream = preload("res://assets/audio/relay_complete.wav")
const SERVO_EVENTS: Array[StringName] = [
	RuntimeIdsScript.EVENT_LOCOMOTION_START,
	RuntimeIdsScript.EVENT_LOCOMOTION_STOP,
	RuntimeIdsScript.EVENT_LOCOMOTION_REVERSE,
]
const RUN_EVENTS: Array[StringName] = [
	RuntimeIdsScript.EVENT_LOCOMOTION_RUN,
	RuntimeIdsScript.EVENT_LOCOMOTION_RUN_CONTACT,
]
const CHARGE_EVENTS: Array[StringName] = [
	RuntimeIdsScript.EVENT_CHARGE_LOW,
	RuntimeIdsScript.EVENT_CHARGE_HIGH,
]
const WALKER_EVENTS: Array[StringName] = SERVO_EVENTS + RUN_EVENTS + CHARGE_EVENTS + [
	RuntimeIdsScript.EVENT_LOCOMOTION_WALK_CONTACT,
	RuntimeIdsScript.EVENT_LOCOMOTION_BLOCKED,
]
const COMBAT_EVENTS: Array[StringName] = [
	RuntimeIdsScript.EVENT_SMASH_WHIFF,
	RuntimeIdsScript.EVENT_SMASH_HIT,
	RuntimeIdsScript.EVENT_SMASH_HEAVY_HIT,
	RuntimeIdsScript.EVENT_SMASH_DEFEAT,
	RuntimeIdsScript.EVENT_SMASH_BREAK,
]

var _enabled: bool = true
var _request_count: int = 0
var _played_count: int = 0
var _culled_count: int = 0
var _last_stream_path: String = ""
var _last_bus: StringName = &""
var _last_position: Vector2 = Vector2.ZERO


func play_event(event: Dictionary) -> bool:
	if not _enabled:
		return false
	var stream: AudioStream = _stream_for(event)
	if stream == null:
		return false
	_request_count += 1
	_last_stream_path = stream.resource_path
	var event_id: StringName = event.get(&"event_id", &"") as StringName
	_last_bus = _bus_for(event_id)
	_last_position = event.get(&"position", Vector2.ZERO) as Vector2
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
			_last_position,
			_last_bus,
			_pitch_for(event),
			0.0,
			_priority_for(event_id),
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


func get_metrics() -> Dictionary:
	var service: Node = _audio_service()
	var service_metrics: Dictionary = (
		service.call("get_metrics") as Dictionary if service != null else {}
	)
	return {
		&"enabled": _enabled,
		&"requests": _request_count,
		&"played": _played_count,
		&"culled": _culled_count,
		&"active": int(service_metrics.get(&"spatial_active", 0)),
		&"capacity": MAX_VOICES,
		&"last_stream_path": _last_stream_path,
		&"last_bus": _last_bus,
		&"last_position": _last_position,
	}


func _stream_for(event: Dictionary) -> AudioStream:
	var event_id: StringName = event.get(&"event_id", &"") as StringName
	var stream: AudioStream
	if event_id in SERVO_EVENTS:
		stream = SERVO_ENGAGE
	elif event_id in RUN_EVENTS:
		stream = HEAVY_GAIT
	elif event_id in CHARGE_EVENTS:
		stream = CHARGE_DETENT
	else:
		match event_id:
			RuntimeIdsScript.EVENT_SMASH_WHIFF:
				stream = SWING
			RuntimeIdsScript.EVENT_SMASH_DEFEAT:
				stream = FAUNA_DEFEAT
			RuntimeIdsScript.EVENT_SMASH_BREAK:
				stream = (
					WET_WOOD_BREAK
					if event.get(&"material", &"") == &"wet_wood"
					else STONE_BREAK
				)
			RuntimeIdsScript.EVENT_SMASH_HEAVY_HIT:
				stream = HEAVY_CONTACT
			RuntimeIdsScript.EVENT_SMASH_HIT:
				stream = FAUNA_CONTACT
			RuntimeIdsScript.EVENT_LOCOMOTION_WALK_CONTACT:
				stream = SURFACE_STEP
			RuntimeIdsScript.EVENT_LOCOMOTION_BLOCKED:
				stream = BLOCKED_CLANK
			RuntimeIdsScript.EVENT_SCRAP_COLLECTED:
				stream = PICKUP
			RuntimeIdsScript.EVENT_RELAY_COMPLETED:
				stream = RELAY_COMPLETE
	return stream


func _pitch_for(event: Dictionary) -> float:
	var event_id: StringName = event.get(&"event_id", &"") as StringName
	if event_id == RuntimeIdsScript.EVENT_SCRAP_COLLECTED:
		var metadata: Dictionary = event.get(&"metadata", {}) as Dictionary
		return clampf(1.2 + float(int(metadata.get(&"amount", 1))) * 0.02, 1.2, 1.42)
	var sequence_id: int = int(event.get(&"sequence_id", 0))
	return 0.97 + float(posmod(sequence_id * 17, 7)) * 0.01


func _bus_for(event_id: StringName) -> StringName:
	if event_id in WALKER_EVENTS:
		return AudioServiceScript.BUS_WALKER
	if event_id in COMBAT_EVENTS:
		return AudioServiceScript.BUS_COMBAT
	return AudioServiceScript.BUS_WORLD


func _priority_for(event_id: StringName) -> int:
	if event_id in [
		RuntimeIdsScript.EVENT_SMASH_HEAVY_HIT,
		RuntimeIdsScript.EVENT_SMASH_DEFEAT,
		RuntimeIdsScript.EVENT_RELAY_COMPLETED,
		RuntimeIdsScript.EVENT_CHARGE_HIGH,
		RuntimeIdsScript.EVENT_LOCOMOTION_BLOCKED,
	]:
		return 2
	return 1


func _audio_service() -> Node:
	return get_node_or_null("/root/AudioService") if is_inside_tree() else null
