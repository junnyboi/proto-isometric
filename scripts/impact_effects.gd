extends Node2D

const ROCK: Color = Color("934d35")
const ROCK_LIGHT: Color = Color("bd7152")
const DUST: Color = Color("e8b861")
const SCRAP: Color = Color("4eb6aa")
const CHASSIS_SPARK: Color = Color("ffb12d")

var _camera: Camera2D
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0
var _shake_seed: int = 0
var _particles: Array[Dictionary] = []
var _emission_count: int = 0
var _damage_emission_count: int = 0
var _aftershock_emission_count: int = 0
var _shake_enabled: bool = true


func _ready() -> void:
	call_deferred("_bind_accessibility")


func bind_camera(camera: Camera2D) -> void:
	_camera = camera


func emit_rock_impact(position: Vector2, cell: Vector2i) -> void:
	_emission_count += 1
	_start_shake(0.24, 11.0, cell.x * 92821 + cell.y * 68917 + _emission_count * 31)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = cell.x * 73856093 ^ cell.y * 19349663 ^ _emission_count * 83492791
	for index: int in range(18):
		var angle: float = rng.randf_range(-PI * 0.92, -PI * 0.08)
		var speed: float = rng.randf_range(90.0, 245.0)
		(
			_particles
			. append(
				{
					"position":
					position + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-8.0, 6.0)),
					"velocity": Vector2(cos(angle), sin(angle)) * speed,
					"life": rng.randf_range(0.38, 0.72),
					"maximum_life": 0.72,
					"radius": rng.randf_range(2.5, 6.5),
					"color": ROCK_LIGHT if index % 3 == 0 else ROCK,
				}
			)
		)
	for index: int in range(10):
		(
			_particles
			. append(
				{
					"position":
					position + Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-2.0, 10.0)),
					"velocity":
					Vector2(rng.randf_range(-65.0, 65.0), rng.randf_range(-95.0, -30.0)),
					"life": rng.randf_range(0.42, 0.8),
					"maximum_life": 0.8,
					"radius": rng.randf_range(3.0, 8.0),
					"color": DUST,
				}
			)
		)
	queue_redraw()


func emit_scrap_pickup(
	position: Vector2,
	amount: int,
	destination: Vector2 = Vector2.INF,
) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = amount * 104729 + _emission_count * 17
	var particle_count: int = clampi(amount * 4, 5, 14)
	var magnetized: bool = destination.is_finite() and not destination.is_equal_approx(position)
	for index: int in range(particle_count):
		var angle: float = TAU * float(index) / float(particle_count)
		var start: Vector2 = position + Vector2.from_angle(angle) * rng.randf_range(2.0, 10.0)
		var life: float = rng.randf_range(0.28, 0.48)
		var velocity: Vector2 = Vector2.from_angle(angle) * rng.randf_range(55.0, 115.0)
		if magnetized:
			velocity = (destination - start) / life
		(
			_particles
			. append(
				{
					"position": start,
					"velocity": velocity,
					"life": life,
					"maximum_life": 0.48,
					"radius": rng.randf_range(2.0, 4.0),
					"color": SCRAP,
					"gravity": 0.0 if magnetized else 480.0,
				}
			)
		)
	queue_redraw()


func emit_chassis_damage(position: Vector2, amount: int) -> void:
	_damage_emission_count += 1
	_start_shake(0.15, 6.0, amount * 4099 + _damage_emission_count * 131)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = amount * 65537 + _damage_emission_count * 8191
	for index: int in range(clampi(7 + amount, 8, 14)):
		var angle: float = rng.randf_range(-PI * 0.96, -PI * 0.04)
		(
			_particles
			. append(
				{
					"position": position + Vector2(rng.randf_range(-18.0, 18.0), -22.0),
					"velocity": Vector2(cos(angle), sin(angle)) * rng.randf_range(80.0, 175.0),
					"life": rng.randf_range(0.22, 0.46),
					"maximum_life": 0.46,
					"radius": rng.randf_range(1.8, 4.2),
					"color": CHASSIS_SPARK if index % 3 != 0 else SCRAP,
				}
			)
		)
	queue_redraw()


func emit_aftershock(position: Vector2, cell: Vector2i, band: int) -> void:
	_aftershock_emission_count += 1
	var strength: float = 13.0 if band >= 2 else 8.5
	_start_shake(0.28, strength, cell.x * 4099 + cell.y * 8191 + band * 131)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = cell.x * 73856093 ^ cell.y * 19349663 ^ _aftershock_emission_count * 83492791
	var particle_count: int = 28 if band >= 2 else 16
	for index: int in range(particle_count):
		var angle: float = TAU * float(index) / float(particle_count) + rng.randf_range(-0.16, 0.16)
		(
			_particles
			. append(
				{
					"position":
					position + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-6.0, 6.0)),
					"velocity": Vector2(cos(angle), sin(angle)) * rng.randf_range(80.0, 190.0),
					"life": rng.randf_range(0.32, 0.62),
					"maximum_life": 0.62,
					"radius": rng.randf_range(2.0, 5.5),
					"color": CHASSIS_SPARK if index % 3 != 0 else SCRAP,
				}
			)
		)
	queue_redraw()


func advance(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	if _shake_time > 0.0:
		_shake_time = maxf(_shake_time - step, 0.0)
		_apply_camera_offset()
	elif _camera != null and _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO

	for index: int in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[index]
		var velocity: Vector2 = particle["velocity"] as Vector2
		velocity.y += float(particle.get("gravity", 480.0)) * step
		particle["velocity"] = velocity
		particle["position"] = (particle["position"] as Vector2) + velocity * step
		particle["life"] = float(particle["life"]) - step
		if float(particle["life"]) <= 0.0:
			_particles.remove_at(index)
		else:
			_particles[index] = particle
	queue_redraw()


func get_particle_count() -> int:
	return _particles.size()


func get_emission_count() -> int:
	return _emission_count


func get_damage_emission_count() -> int:
	return _damage_emission_count


func get_aftershock_emission_count() -> int:
	return _aftershock_emission_count


func get_shake_remaining() -> float:
	return _shake_time


func get_camera_offset() -> Vector2:
	return _camera.offset if _camera != null else Vector2.ZERO


func _start_shake(duration: float, strength: float, seed: int) -> void:
	if not _shake_enabled:
		_shake_time = 0.0
		if _camera != null:
			_camera.offset = Vector2.ZERO
		return
	_shake_duration = duration
	_shake_time = duration
	_shake_strength = strength
	_shake_seed = seed
	_apply_camera_offset()


func _bind_accessibility() -> void:
	var panel: Node = get_tree().get_first_node_in_group("accessibility_panel")
	if panel == null:
		return
	_apply_preferences(panel.call("get_preferences") as Dictionary)
	panel.connect("preferences_changed", _apply_preferences)


func _apply_preferences(snapshot: Dictionary) -> void:
	_shake_enabled = bool(snapshot.get(&"camera_shake", true))


func _apply_camera_offset() -> void:
	if _camera == null or _shake_duration <= 0.0:
		return
	var normalized: float = clampf(_shake_time / _shake_duration, 0.0, 1.0)
	var phase: float = float(_shake_seed) * 0.017 + (_shake_duration - _shake_time) * 53.0
	var direction: Vector2 = Vector2(sin(phase * 1.7), cos(phase * 2.3)).normalized()
	_camera.offset = direction * _shake_strength * normalized


func _draw() -> void:
	for particle: Dictionary in _particles:
		var life_ratio: float = clampf(
			float(particle["life"]) / float(particle["maximum_life"]), 0.0, 1.0
		)
		var color: Color = particle["color"] as Color
		color.a = life_ratio
		draw_circle(particle["position"] as Vector2, float(particle["radius"]) * life_ratio, color)
