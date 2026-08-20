extends Node2D

const BiomeDestructiblesScript: GDScript = preload("res://scripts/biome_destructibles.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const SCRAP: Color = Color("4eb6aa")
const CHASSIS_SPARK: Color = Color("ffb12d")
const DEBRIS_LIFETIME_SECONDS: float = 1.0
const MAX_POOL_SIZE: int = 128
const MAX_ACTIVE_PARTICLES: int = 128

var _camera: Camera2D
var _camera_mixer: RefCounted
var _performance_sampler: Node
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0
var _shake_seed: int = 0
var _particles: Array[Dictionary] = []
var _particle_pool: Array[Dictionary] = []
var _emission_count: int = 0
var _damage_emission_count: int = 0
var _aftershock_emission_count: int = 0
var _created_particle_count: int = 0
var _reused_particle_count: int = 0
var _reclaimed_particle_count: int = 0
var _peak_particle_count: int = 0
var _last_debris_kind: StringName = BiomeDestructiblesScript.KIND_DESERT_ROCK
var _last_debris_palette: Array[Color] = []
var _shake_enabled: bool = true
var _redraw_request_count: int = 0


func _init() -> void:
	_prewarm_particle_pool()


func _ready() -> void:
	call_deferred("_bind_accessibility")


func bind_camera(camera: Camera2D) -> void:
	_camera = camera


func bind_camera_mixer(camera_mixer: RefCounted) -> void:
	_camera_mixer = camera_mixer


func bind_performance(performance_sampler: Node) -> void:
	_performance_sampler = performance_sampler
	_sync_metrics()


func emit_rock_impact(
	position: Vector2,
	cell: Vector2i,
	destructible_kind: StringName = BiomeDestructiblesScript.KIND_DESERT_ROCK,
	start_camera: bool = true,
	particle_limit: int = 28,
) -> void:
	_emission_count += 1
	_last_debris_kind = destructible_kind
	_last_debris_palette = (
		BiomeDestructiblesScript.debris_palette_for(destructible_kind).duplicate()
	)
	if start_camera:
		_start_shake(0.24, 11.0, cell.x * 92821 + cell.y * 68917 + _emission_count * 31)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = cell.x * 73856093 ^ cell.y * 19349663 ^ _emission_count * 83492791
	var primary_count: int = mini(18, clampi(particle_limit, 1, 28))
	var secondary_count: int = maxi(clampi(particle_limit, 1, 28) - primary_count, 0)
	for index: int in range(primary_count):
		var angle: float = rng.randf_range(-PI * 0.92, -PI * 0.08)
		var speed: float = rng.randf_range(90.0, 245.0)
		_spawn_particle(
			position + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-8.0, 6.0)),
			Vector2(cos(angle), sin(angle)) * speed,
			DEBRIS_LIFETIME_SECONDS,
			DEBRIS_LIFETIME_SECONDS,
			rng.randf_range(2.5, 6.5),
			_last_debris_palette[index % _last_debris_palette.size()],
		)
	for index: int in range(secondary_count):
		_spawn_particle(
			position + Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-2.0, 10.0)),
			Vector2(rng.randf_range(-65.0, 65.0), rng.randf_range(-95.0, -30.0)),
			DEBRIS_LIFETIME_SECONDS,
			DEBRIS_LIFETIME_SECONDS,
			rng.randf_range(3.0, 8.0),
			_last_debris_palette[(index + 2) % _last_debris_palette.size()],
		)
	_sync_metrics()
	_request_redraw()


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
		_spawn_particle(
			start,
			velocity,
			life,
			0.48,
			rng.randf_range(2.0, 4.0),
			SCRAP,
			0.0 if magnetized else 480.0,
		)
	_sync_metrics()
	_request_redraw()


func emit_chassis_damage(position: Vector2, amount: int) -> void:
	_damage_emission_count += 1
	_start_shake(0.15, 6.0, amount * 4099 + _damage_emission_count * 131)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = amount * 65537 + _damage_emission_count * 8191
	for index: int in range(clampi(7 + amount, 8, 14)):
		var angle: float = rng.randf_range(-PI * 0.96, -PI * 0.04)
		_spawn_particle(
			position + Vector2(rng.randf_range(-18.0, 18.0), -22.0),
			Vector2(cos(angle), sin(angle)) * rng.randf_range(80.0, 175.0),
			rng.randf_range(0.22, 0.46),
			0.46,
			rng.randf_range(1.8, 4.2),
			CHASSIS_SPARK if index % 3 != 0 else SCRAP,
		)
	_sync_metrics()
	_request_redraw()


func emit_aftershock(
	position: Vector2, cell: Vector2i, band: int, start_camera: bool = true, limit: int = -1
) -> void:
	_aftershock_emission_count += 1
	var strength: float = 13.0 if band >= 2 else 8.5
	if start_camera:
		_start_shake(0.28, strength, cell.x * 4099 + cell.y * 8191 + band * 131)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = cell.x * 73856093 ^ cell.y * 19349663 ^ _aftershock_emission_count * 83492791
	var particle_count: int = 28 if band >= 2 else 16
	if limit >= 0:
		particle_count = clampi(limit, 0, 32)
	for index: int in range(particle_count):
		var angle: float = TAU * float(index) / float(particle_count) + rng.randf_range(-0.16, 0.16)
		_spawn_particle(
			position + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-6.0, 6.0)),
			Vector2(cos(angle), sin(angle)) * rng.randf_range(80.0, 190.0),
			rng.randf_range(0.32, 0.62),
			0.62,
			rng.randf_range(2.0, 5.5),
			CHASSIS_SPARK if index % 3 != 0 else SCRAP,
		)
	_sync_metrics()
	_request_redraw()


func emit_feedback(event: Dictionary, profile: Dictionary) -> void:
	var event_id: StringName = event.get(&"event_id", &"") as StringName
	if event_id == RuntimeIdsScript.EVENT_SMASH_WHIFF:
		return
	var position: Vector2 = event.get(&"position", Vector2.ZERO) as Vector2
	var count: int = int(profile.get(&"particle_count", 0))
	var metadata: Dictionary = event.get(&"metadata", {}) as Dictionary
	if str(event_id).begins_with("event.locomotion.") or str(event_id).begins_with("event.charge."):
		_emit_surface_wake(event, count)
		return
	if event_id == RuntimeIdsScript.EVENT_SMASH_BREAK:
		emit_rock_impact(
			position,
			metadata.get(&"cell", Vector2i.ZERO) as Vector2i,
			metadata.get(&"kind", BiomeDestructiblesScript.KIND_DESERT_ROCK) as StringName,
			false,
			count,
		)
		return
	if event_id in [RuntimeIdsScript.EVENT_SMASH_HEAVY_HIT, RuntimeIdsScript.EVENT_SMASH_DEFEAT]:
		emit_aftershock(
			position,
			Vector2i((metadata.get(&"position", Vector2.ZERO) as Vector2).round()),
			int(event.get(&"strength", 0)),
			false,
			count,
		)
		return
	_emit_directional_contact(event, count)


func advance(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	var had_particles: bool = not _particles.is_empty()
	var recycled: bool = false
	if _camera_mixer != null:
		_camera_mixer.call("advance", step)
	elif _shake_time > 0.0:
		_shake_time = maxf(_shake_time - step, 0.0)
		_apply_camera_offset()
	elif _camera_mixer == null and _camera != null and _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO

	for index: int in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[index]
		var velocity: Vector2 = particle["velocity"] as Vector2
		velocity.y += float(particle["gravity"]) * step
		particle["velocity"] = velocity
		particle["position"] = (particle["position"] as Vector2) + velocity * step
		particle["life"] = float(particle["life"]) - step
		if float(particle["life"]) <= 0.0:
			var last_index: int = _particles.size() - 1
			if index != last_index:
				_particles[index] = _particles[last_index]
			_particles.pop_back()
			_recycle_particle(particle)
			recycled = true
		else:
			_particles[index] = particle
	if recycled:
		_sync_metrics()
	if had_particles:
		_request_redraw()


func get_particle_count() -> int:
	return _particles.size()


func get_particle_pool_size() -> int:
	return _particle_pool.size()


func get_created_particle_count() -> int:
	return _created_particle_count


func get_reused_particle_count() -> int:
	return _reused_particle_count


func _get_reclaimed_particle_count() -> int:
	return _reclaimed_particle_count


func get_peak_particle_count() -> int:
	return _peak_particle_count


func get_emission_count() -> int:
	return _emission_count


func get_damage_emission_count() -> int:
	return _damage_emission_count


func get_aftershock_emission_count() -> int:
	return _aftershock_emission_count


func _get_last_debris_kind() -> StringName:
	return _last_debris_kind


func _get_last_debris_palette() -> Array[Color]:
	return _last_debris_palette.duplicate()


func get_redraw_request_count() -> int:
	return _redraw_request_count


func get_shake_remaining() -> float:
	return float(_camera_mixer.call("get_remaining")) if _camera_mixer != null else _shake_time


func get_camera_offset() -> Vector2:
	return _camera.offset if _camera != null else Vector2.ZERO


func _spawn_particle(
	position: Vector2,
	velocity: Vector2,
	life: float,
	maximum_life: float,
	radius: float,
	color: Color,
	gravity: float = 480.0,
) -> void:
	if _particle_pool.is_empty() and _particles.is_empty():
		_prewarm_particle_pool()
	var particle: Dictionary
	if _particle_pool.is_empty():
		var oldest_index: int = 0
		particle = _particles[oldest_index]
		_particles[oldest_index] = _particles[_particles.size() - 1]
		_particles.pop_back()
		_reclaimed_particle_count += 1
		_record_counter(&"particles.reclaimed")
	else:
		particle = _particle_pool.pop_back()
		_reused_particle_count += 1
		_record_counter(&"particles.reused")
	particle["position"] = position
	particle["velocity"] = velocity
	particle["life"] = life
	particle["maximum_life"] = maximum_life
	particle["radius"] = radius
	particle["color"] = color
	particle["gravity"] = gravity
	_particles.append(particle)
	_peak_particle_count = maxi(_peak_particle_count, _particles.size())
	assert(_particles.size() <= MAX_ACTIVE_PARTICLES)


func _emit_directional_contact(event: Dictionary, count: int) -> void:
	var position: Vector2 = event.get(&"position", Vector2.ZERO) as Vector2
	var direction: Vector2 = event.get(&"direction", Vector2.RIGHT) as Vector2
	direction = Vector2.RIGHT if direction.is_zero_approx() else direction.normalized()
	var screen_direction: Vector2 = (
		Vector2(direction.x - direction.y, direction.x + direction.y).normalized()
	)
	var seed: int = int(event.get(&"sequence_id", 0)) * 104729
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	for index: int in range(clampi(count, 0, 32)):
		var spread: Vector2 = screen_direction.rotated(rng.randf_range(-0.65, 0.65))
		_spawn_particle(
			position + Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-6.0, 4.0)),
			spread * rng.randf_range(70.0, 170.0),
			rng.randf_range(0.18, 0.38),
			0.38,
			rng.randf_range(1.6, 3.8),
			CHASSIS_SPARK if index % 3 != 0 else SCRAP,
		)
	_sync_metrics()
	_request_redraw()


func _emit_surface_wake(event: Dictionary, count: int) -> void:
	var position: Vector2 = event.get(&"position", Vector2.ZERO) as Vector2
	var material: StringName = event.get(&"material", &"sand") as StringName
	var color: Color = Color("d8ba78")
	match material:
		&"mud":
			color = Color("537b6a")
		&"snow":
			color = Color("c8e8ed")
		&"volcanic":
			color = Color("d96632")
		&"energy":
			color = CHASSIS_SPARK
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(event.get(&"sequence_id", 0)) * 16127
	for index: int in range(clampi(count, 0, 8)):
		_spawn_particle(
			position + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(6.0, 14.0)),
			Vector2(rng.randf_range(-28.0, 28.0), rng.randf_range(-34.0, -12.0)),
			rng.randf_range(0.16, 0.3),
			0.3,
			rng.randf_range(1.4, 3.0),
			color,
			90.0,
		)
	_sync_metrics()
	_request_redraw()


func _prewarm_particle_pool() -> void:
	if not _particle_pool.is_empty() or not _particles.is_empty():
		return
	for _index: int in range(MAX_POOL_SIZE):
		_particle_pool.append({})
		_created_particle_count += 1
		_record_counter(&"particles.created")
	_sync_metrics()


func _recycle_particle(particle: Dictionary) -> void:
	if _particle_pool.size() >= MAX_POOL_SIZE:
		return
	particle.clear()
	_particle_pool.append(particle)


func _start_shake(duration: float, strength: float, seed: int) -> void:
	if not _shake_enabled:
		_shake_time = 0.0
		if _camera != null:
			_camera.offset = Vector2.ZERO
		return
	if _camera_mixer != null:
		_camera_mixer.call("submit", duration, strength, Vector2.RIGHT, seed)
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
	if _camera_mixer != null:
		_camera_mixer.call("set_enabled", _shake_enabled)


func _apply_camera_offset() -> void:
	if _camera == null or _shake_duration <= 0.0:
		return
	var normalized: float = clampf(_shake_time / _shake_duration, 0.0, 1.0)
	var phase: float = float(_shake_seed) * 0.017 + (_shake_duration - _shake_time) * 53.0
	var direction: Vector2 = Vector2(sin(phase * 1.7), cos(phase * 2.3)).normalized()
	_camera.offset = direction * _shake_strength * normalized


func _record_counter(counter: StringName) -> void:
	if _performance_sampler != null:
		_performance_sampler.call("increment_counter", counter)


func _sync_metrics() -> void:
	if _performance_sampler == null:
		return
	_performance_sampler.call("set_gauge", &"particles.active", float(_particles.size()))
	_performance_sampler.call(
		"set_gauge", &"particles.pool_available", float(_particle_pool.size())
	)
	_performance_sampler.call(
		"set_gauge", &"particles.created_total", float(_created_particle_count)
	)
	_performance_sampler.call("set_gauge", &"particles.reused_total", float(_reused_particle_count))
	_performance_sampler.call(
		"set_gauge", &"particles.reclaimed_total", float(_reclaimed_particle_count)
	)
	_performance_sampler.call("set_gauge", &"particles.peak_active", float(_peak_particle_count))


func _request_redraw() -> void:
	_redraw_request_count += 1
	queue_redraw()


func _draw() -> void:
	for particle: Dictionary in _particles:
		var life_ratio: float = clampf(
			float(particle["life"]) / float(particle["maximum_life"]), 0.0, 1.0
		)
		var color: Color = particle["color"] as Color
		color.a = life_ratio
		draw_circle(particle["position"] as Vector2, float(particle["radius"]) * life_ratio, color)
