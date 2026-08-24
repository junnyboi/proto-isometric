extends RigidBody2D

var _life: float = 0.0
var _maximum_life: float = 1.0
var _fragment_size: float = 6.0
var _fragment_color: Color = Color.WHITE
var _shape_kind: StringName = &"stone"


func _init() -> void:
	collision_layer = 0
	collision_mask = 0
	freeze = true
	visible = false
	z_index = 5


func activate(
	start_position: Vector2,
	velocity: Vector2,
	spin: float,
	gravity: float,
	life: float,
	fragment_size: float,
	color: Color,
	shape_kind: StringName,
) -> void:
	position = start_position
	rotation = 0.0
	linear_velocity = velocity
	angular_velocity = spin
	gravity_scale = maxf(gravity, 0.0)
	_life = maxf(life, 0.001)
	_maximum_life = _life
	_fragment_size = maxf(fragment_size, 1.0)
	_fragment_color = color
	_shape_kind = shape_kind
	modulate = Color.WHITE
	freeze = false
	sleeping = false
	visible = true
	queue_redraw()


func advance_lifetime(delta: float) -> bool:
	if freeze:
		return false
	_life = maxf(_life - maxf(delta, 0.0), 0.0)
	modulate.a = clampf(_life / _maximum_life, 0.0, 1.0)
	if _life > 0.0:
		return true
	deactivate()
	return false


func deactivate() -> void:
	freeze = true
	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	gravity_scale = 0.0
	visible = false
	modulate = Color.WHITE


func get_life() -> float:
	return _life


func get_shape_kind() -> StringName:
	return _shape_kind


func _draw() -> void:
	var size: float = _fragment_size
	var points: PackedVector2Array
	match _shape_kind:
		&"splinter":
			points = PackedVector2Array([
				Vector2(-size * 0.32, -size), Vector2(size * 0.34, -size * 0.82),
				Vector2(size * 0.28, size), Vector2(-size * 0.22, size * 0.72),
			])
		&"ice":
			points = PackedVector2Array([
				Vector2(0.0, -size), Vector2(size * 0.55, size * 0.16),
				Vector2(0.0, size), Vector2(-size * 0.48, size * 0.1),
			])
		&"jagged":
			points = PackedVector2Array([
				Vector2(-size * 0.72, size * 0.62), Vector2(-size * 0.12, -size),
				Vector2(size * 0.7, size * 0.18), Vector2(size * 0.34, size * 0.86),
			])
		_:
			points = PackedVector2Array([
				Vector2(-size * 0.78, -size * 0.2), Vector2(-size * 0.28, -size),
				Vector2(size * 0.66, -size * 0.54), Vector2(size, size * 0.3),
				Vector2(size * 0.18, size), Vector2(-size * 0.7, size * 0.58),
			])
	draw_colored_polygon(points, _fragment_color)
	draw_polyline(points + PackedVector2Array([points[0]]), _fragment_color.darkened(0.28), 1.0)
