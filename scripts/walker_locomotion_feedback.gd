extends Node

const FeedbackEventScript: GDScript = preload("res://scripts/feedback_event.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const GAIT_CONTACT_FRAMES: Array[int] = [1, 5]
const STOP_SPEED: float = 0.05
const BLOCK_COOLDOWN: float = 0.15

var _field: Node
var _avatar: Node2D
var _router: Node
var _charge: Node2D
var _world: RefCounted
var _last_velocity: Vector2 = Vector2.ZERO
var _last_moving: bool = false
var _last_running: bool = false
var _last_frame: int = -1
var _last_animation: StringName = &""
var _blocked_cooldown: float = 0.0
var _event_counts: Dictionary = {}


func configure(
	field: Node,
	avatar: Node2D,
	router: Node,
	charge: Node2D,
	world: RefCounted,
) -> bool:
	_field = field
	_avatar = avatar
	_router = router
	_charge = charge
	_world = world
	if _charge != null and not _charge.is_connected("band_crossed", _on_charge_band_crossed):
		_charge.connect("band_crossed", _on_charge_band_crossed)
	return _field != null and _avatar != null and _router != null and _world != null


func _process(delta: float) -> void:
	_blocked_cooldown = maxf(_blocked_cooldown - maxf(delta, 0.0), 0.0)
	if _field == null or _avatar == null or _router == null or _world == null:
		return
	var velocity: Vector2 = _field.call("get_velocity") as Vector2
	var moving: bool = velocity.length() >= STOP_SPEED and not bool(_avatar.call("is_attacking"))
	var running: bool = bool(_field.get("_is_running")) and moving
	var position: Vector2 = _field.call("get_robot_position") as Vector2
	var surface: StringName = _surface_family()
	if moving and not _last_moving:
		_emit(RuntimeIdsScript.EVENT_LOCOMOTION_START, position, velocity, running, surface)
	elif not moving and _last_moving:
		_emit(RuntimeIdsScript.EVENT_LOCOMOTION_STOP, position, _last_velocity, false, surface)
	elif moving and _last_moving and _is_reversal(velocity, _last_velocity):
		_emit(RuntimeIdsScript.EVENT_LOCOMOTION_REVERSE, position, velocity, running, surface)
	if running and not _last_running:
		_emit(RuntimeIdsScript.EVENT_LOCOMOTION_RUN, position, velocity, true, surface)
	_emit_visible_gait_contact(position, velocity, moving, running, surface)
	_last_velocity = velocity
	_last_moving = moving
	_last_running = running


func notify_blocked() -> bool:
	if _field == null or _router == null or _blocked_cooldown > 0.0:
		return false
	_blocked_cooldown = BLOCK_COOLDOWN
	var direction: Vector2 = _last_velocity
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	return _emit(
		RuntimeIdsScript.EVENT_LOCOMOTION_BLOCKED,
		_field.call("get_robot_position") as Vector2,
		direction,
		false,
		_surface_family(),
	)


func get_event_counts() -> Dictionary:
	return _event_counts.duplicate()


static func is_gait_contact_frame(frame: int) -> bool:
	return frame in GAIT_CONTACT_FRAMES


static func surface_family_for(terrain: StringName) -> StringName:
	if terrain in [&"mud", &"wetland", &"water"]:
		return &"mud"
	if terrain in [&"snow", &"blue_ice", &"ice", &"frozen"]:
		return &"snow"
	if terrain in [&"volcanic", &"lava", &"basalt", &"obsidian"]:
		return &"volcanic"
	return &"sand"


static func _is_reversal(current: Vector2, previous: Vector2) -> bool:
	if current.length() < STOP_SPEED or previous.length() < STOP_SPEED:
		return false
	return current.normalized().dot(previous.normalized()) <= -0.45


func _emit_visible_gait_contact(
	position: Vector2,
	velocity: Vector2,
	moving: bool,
	running: bool,
	surface: StringName,
) -> void:
	var animation: StringName = _avatar.call("get_active_animation") as StringName
	var frame: int = int(_avatar.call("get_active_frame"))
	if animation != _last_animation:
		_last_animation = animation
		_last_frame = -1
	if not moving or not str(animation).begins_with("walk") or frame == _last_frame:
		return
	_last_frame = frame
	if not is_gait_contact_frame(frame):
		return
	var event_id: StringName = (
		RuntimeIdsScript.EVENT_LOCOMOTION_RUN_CONTACT
		if running
		else RuntimeIdsScript.EVENT_LOCOMOTION_WALK_CONTACT
	)
	_emit(event_id, position, velocity, running, surface, {&"visible_frame": frame})


func _on_charge_band_crossed(band: int) -> void:
	if _field == null:
		return
	var event_id: StringName = (
		RuntimeIdsScript.EVENT_CHARGE_HIGH if band >= 2 else RuntimeIdsScript.EVENT_CHARGE_LOW
	)
	_emit(
		event_id,
		_field.call("get_robot_position") as Vector2,
		_last_velocity,
		band >= 2,
		&"energy",
		{&"band": band},
	)


func _emit(
	event_id: StringName,
	position: Vector2,
	direction: Vector2,
	strong: bool,
	material: StringName,
	metadata: Dictionary = {},
) -> bool:
	var event: Dictionary = FeedbackEventScript.create(
		event_id, position, direction, 1 if strong else 0, material, -1, metadata
	)
	var accepted: bool = bool(_router.call("submit", event))
	if accepted:
		_event_counts[event_id] = int(_event_counts.get(event_id, 0)) + 1
		_avatar.call("_apply_locomotion_presentation", event_id, strong)
	return accepted


func _surface_family() -> StringName:
	var grid: Vector2i = _field.call("get_robot_grid") as Vector2i
	return surface_family_for(_world.call("terrain_at", grid) as StringName)
