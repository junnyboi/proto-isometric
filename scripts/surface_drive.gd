extends RefCounted

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
