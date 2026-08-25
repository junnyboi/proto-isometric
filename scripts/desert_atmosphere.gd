extends Node2D

const ParticleCatalogScript: GDScript = preload(
	"res://scripts/biome_weather_particle_catalog.gd"
)
const PARTICLE_COUNT: int = 128
const BIOME_BLEND_SECONDS: float = 0.8
const PUNCTUATION_PERIOD_SECONDS: float = 4.8
const VIEW_PADDING: float = 160.0
const QUALITY_MULTIPLIERS: Dictionary = {
	&"full": 1.0,
	&"reduced": 0.65,
	&"minimal": 0.35,
}
const BASE_INTENSITY: Dictionary = {
	&"sand": 0.72,
	&"wetland": 0.74,
	&"frozen": 0.70,
	&"volcanic": 0.68,
}

var _time: float = 0.0
var _wind_intensity: float = 0.55
var _punctuation_strength: float = 0.0
var _profile: StringName = &"sand"
var _previous_profile: StringName = &"sand"
var _blend_elapsed: float = BIOME_BLEND_SECONDS
var _weather_intensity: float = 0.72
var _target_intensity: float = 0.72
var _field: Node
var _world: RefCounted
var _weather_audio: Node
var _effects_quality: StringName = &"full"
var _vfx_intensity: float = 1.0
var _redraw_request_count: int = 0


func _ready() -> void:
	_field = get_parent()
	if _field != null:
		_world = _field.get("_world") as RefCounted
	call_deferred("_bind_runtime_sources")
	call_deferred("_bind_accessibility")


func advance(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	_time += step
	_bind_runtime_sources()
	_sync_weather_authority()
	_blend_elapsed = minf(_blend_elapsed + step, BIOME_BLEND_SECONDS)
	_weather_intensity = move_toward(_weather_intensity, _target_intensity, step * 1.8)
	_wind_intensity = 0.48 + 0.24 * (0.5 + 0.5 * sin(_time * 0.37))
	_punctuation_strength = pow(
		maxf(sin(_time * TAU / PUNCTUATION_PERIOD_SECONDS), 0.0), 8.0
	)
	if get_visible_mark_count() > 0:
		_redraw_request_count += 1
		queue_redraw()


func set_profile(profile: StringName, intensity: float = -1.0) -> bool:
	var normalized: StringName = profile_for_surface(profile)
	if intensity >= 0.0:
		_target_intensity = clampf(intensity, 0.0, 1.0)
	if normalized == _profile:
		return false
	_previous_profile = _profile
	_profile = normalized
	_blend_elapsed = 0.0
	queue_redraw()
	return true


func get_particle_count() -> int:
	return PARTICLE_COUNT


func get_visible_mark_count() -> int:
	var quality: float = float(QUALITY_MULTIPLIERS.get(_effects_quality, 1.0))
	var density: float = lerpf(0.62, 1.0, clampf(_weather_intensity, 0.0, 1.0))
	return clampi(
		roundi(float(PARTICLE_COUNT) * quality * _vfx_intensity * density),
		0,
		PARTICLE_COUNT,
	)


func get_wind_intensity() -> float:
	return _wind_intensity


func get_punctuation_strength() -> float:
	return _punctuation_strength


func get_profile() -> StringName:
	return _profile


func get_weather_intensity() -> float:
	return _weather_intensity


func get_profile_counts() -> Dictionary:
	return ParticleCatalogScript.class_counts(_profile, get_visible_mark_count())


func get_particle_snapshot(index: int) -> Dictionary:
	var count: int = get_visible_mark_count()
	if index < 0 or index >= count:
		return {}
	return ParticleCatalogScript.snapshot(
		index,
		count,
		_profile,
		_time,
		_draw_rect(),
		_weather_intensity,
	)


func get_metrics() -> Dictionary:
	return {
		&"profile": _profile,
		&"previous_profile": _previous_profile,
		&"particle_count": PARTICLE_COUNT,
		&"visible_count": get_visible_mark_count(),
		&"class_counts": get_profile_counts(),
		&"weather_intensity": _weather_intensity,
		&"target_intensity": _target_intensity,
		&"effects_quality": _effects_quality,
		&"vfx_intensity": _vfx_intensity,
		&"blend_progress": minf(_blend_elapsed / BIOME_BLEND_SECONDS, 1.0),
		&"blending": _blend_elapsed < BIOME_BLEND_SECONDS,
		&"weather_audio_bound": is_instance_valid(_weather_audio),
		&"redraw_requests": _redraw_request_count,
		&"draw_rect": _draw_rect(),
	}


static func profile_for_surface(surface: StringName) -> StringName:
	return ParticleCatalogScript.normalize_profile(surface)


func _bind_runtime_sources() -> void:
	if not is_inside_tree() or is_instance_valid(_weather_audio):
		return
	_weather_audio = get_tree().get_first_node_in_group("weather_audio_layer")


func _sync_weather_authority() -> void:
	if is_instance_valid(_weather_audio):
		var metrics: Dictionary = _weather_audio.call("get_metrics") as Dictionary
		set_profile(metrics.get(&"biome", &"sand") as StringName)
		_target_intensity = clampf(float(metrics.get(&"intensity", 0.72)), 0.0, 1.0)
		return
	if _field != null and _world != null:
		var grid: Vector2i = _field.call("get_robot_grid") as Vector2i
		set_profile(_world.call("terrain_at", grid) as StringName)
	_target_intensity = float(BASE_INTENSITY.get(_profile, 0.72))


func _bind_accessibility() -> void:
	if not is_inside_tree():
		return
	var panel: Node = get_tree().get_first_node_in_group("accessibility_panel")
	if panel == null:
		return
	_apply_preferences(panel.call("get_preferences") as Dictionary)
	var callback: Callable = Callable(self, "_apply_preferences")
	if not panel.is_connected("preferences_changed", callback):
		panel.connect("preferences_changed", callback)


func _apply_preferences(snapshot: Dictionary) -> void:
	_vfx_intensity = clampf(float(snapshot.get(&"vfx_intensity", 1.0)), 0.0, 1.0)
	var quality: StringName = StringName(snapshot.get(&"effects_quality", &"full"))
	_effects_quality = quality if QUALITY_MULTIPLIERS.has(quality) else &"full"
	queue_redraw()


func _draw_rect() -> Rect2:
	var size: Vector2 = Vector2(1280.0, 720.0)
	if is_inside_tree() and get_viewport() != null:
		size = get_viewport_rect().size
	var center: Vector2 = Vector2.ZERO
	if _field != null and _field.has_method("get_camera_position"):
		center = _field.call("get_camera_position") as Vector2
	return Rect2(
		center - size * 0.5 - Vector2.ONE * VIEW_PADDING,
		size + Vector2.ONE * VIEW_PADDING * 2.0,
	)


func _draw() -> void:
	var count: int = get_visible_mark_count()
	if count <= 0:
		return
	var progress: float = minf(_blend_elapsed / BIOME_BLEND_SECONDS, 1.0)
	var incoming_count: int = count
	var outgoing_count: int = 0
	if _previous_profile != _profile and progress < 1.0:
		incoming_count = clampi(roundi(float(count) * progress), 0, count)
		outgoing_count = count - incoming_count
	_draw_profile(_previous_profile, outgoing_count, count, 1.0 - progress)
	_draw_profile(_profile, incoming_count, count, progress if outgoing_count > 0 else 1.0)


func _draw_profile(
	profile: StringName, visible_count: int, total_count: int, strength: float
) -> void:
	for index: int in range(visible_count):
		var particle: Dictionary = ParticleCatalogScript.snapshot(
			index,
			total_count,
			profile,
			_time,
			_draw_rect(),
			_weather_intensity + _punctuation_strength * 0.08,
		)
		ParticleCatalogScript.draw_particle(self, particle, strength * _vfx_intensity)
