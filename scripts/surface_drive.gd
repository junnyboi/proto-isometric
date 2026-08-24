extends RefCounted

const IsometricControlsScript: GDScript = preload("res://scripts/isometric_controls.gd")
const ModuleEffectsScript: GDScript = preload("res://scripts/module_effects.gd")
const StatusLocalizerScript: GDScript = preload("res://scripts/status_localizer.gd")

const NORMAL_ACCELERATION: float = 310.0
const NORMAL_DECELERATION: float = 390.0
const MUD_SPEED_MULTIPLIER: float = 0.62
const ICE_LONGITUDINAL_ACCELERATION: float = 155.0
const ICE_LATERAL_ACCELERATION: float = 68.0
const ICE_DRAG: float = 24.0
const MAX_STEP: float = 0.05
const STOP_EPSILON: float = 0.05


static func advance(
	velocity: Vector2,
	desired_velocity: Vector2,
	speed_cap: float,
	surface: StringName,
	delta: float,
) -> Vector2:
	var step: float = minf(maxf(delta, 0.0), MAX_STEP)
	var next: Vector2 = velocity
	if surface == &"blue_ice":
		next = _advance_ice(velocity, desired_velocity, step)
		speed_cap = maxf(speed_cap, velocity.length())
	elif desired_velocity.is_zero_approx():
		next = velocity.move_toward(Vector2.ZERO, NORMAL_DECELERATION * step)
	else:
		next = velocity.move_toward(desired_velocity, NORMAL_ACCELERATION * step)
	if surface == &"mud":
		speed_cap *= MUD_SPEED_MULTIPLIER
	next = next.limit_length(maxf(speed_cap, 0.0))
	return Vector2.ZERO if next.length() < STOP_EPSILON else next


static func _advance_ice(velocity: Vector2, desired_velocity: Vector2, delta: float) -> Vector2:
	if desired_velocity.is_zero_approx():
		return velocity.move_toward(Vector2.ZERO, ICE_DRAG * delta)
	if velocity.length() < STOP_EPSILON:
		return velocity.move_toward(desired_velocity, ICE_LONGITUDINAL_ACCELERATION * delta)
	var forward: Vector2 = velocity.normalized()
	var side: Vector2 = forward.orthogonal()
	var change: Vector2 = desired_velocity - velocity
	var longitudinal: Vector2 = (
		forward
		* clampf(
			change.dot(forward),
			-ICE_LONGITUDINAL_ACCELERATION * delta,
			ICE_LONGITUDINAL_ACCELERATION * delta
		)
	)
	var lateral: Vector2 = (
		side
		* clampf(
			change.dot(side), -ICE_LATERAL_ACCELERATION * delta, ICE_LATERAL_ACCELERATION * delta
		)
	)
	return velocity + longitudinal + lateral


static func advance_map(map: Node, delta: float, input_direction: Vector2i) -> bool:
	var velocity: Vector2 = map.get("_velocity") as Vector2
	if velocity.is_zero_approx() or delta <= 0.0:
		return false
	var position: Vector2 = map.get("_robot_visual_position") as Vector2
	var origin: Vector2i = map.get("_robot_grid") as Vector2i
	var candidate: Vector2 = position + velocity * delta
	var target: Vector2i = map.call("screen_to_grid", candidate) as Vector2i
	if target != origin and not bool(map.call("_can_transition", origin, target)):
		var input_delta: Vector2i = IsometricControlsScript.screen_to_grid_delta(input_direction)
		var rammed: bool = (
			input_delta != Vector2i.ZERO
			and target == origin + input_delta
			and ModuleEffectsScript.try_ram(map, input_direction)
		)
		if not rammed or not bool(map.call("_can_transition", origin, target)):
			_stop_at_obstacle(map)
			return false
	map.set("_robot_visual_position", candidate)
	if target != origin:
		map.set("_robot_grid", target)
		map.call("_stream_world")
		map.call("_collect_scrap_near", target)
	return true


static func can_transition(map: Node, origin: Vector2i, target: Vector2i) -> bool:
	if not bool(map.call("is_walkable", target)):
		return false
	var delta: Vector2i = target - origin
	if absi(delta.x) > 1 or absi(delta.y) > 1:
		return false
	if delta.x != 0 and delta.y != 0:
		return (
			bool(map.call("is_walkable", origin + Vector2i(delta.x, 0)))
			and bool(map.call("is_walkable", origin + Vector2i(0, delta.y)))
		)
	return true


static func _stop_at_obstacle(map: Node) -> void:
	map.set("_velocity", Vector2.ZERO)
	map.set("_is_moving", false)
	var feedback: Node = map.get("_feedback_router") as Node
	feedback.call("notify_blocked")
	var facing: StringName = map.get("_facing") as StringName
	var scrap: int = int(map.get("_scrap_count"))
	map.call("_update_status", StatusLocalizerScript.vector_blocked(facing, scrap))
