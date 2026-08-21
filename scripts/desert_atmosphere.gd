extends Node2D

const PARTICLE_COUNT: int = 96
const DUST: Color = Color("dca45a")
const PALE_DUST: Color = Color("f0c985")
const PUNCTUATION_PERIOD_SECONDS: float = 4.8

var _time: float = 0.0
var _wind_intensity: float = 0.55
var _punctuation_strength: float = 0.0
var _profile: StringName = &"sand"
var _field: Node
var _world: RefCounted
var _vfx_intensity: float = 1.0


func _ready() -> void:
	_field = get_parent()
	if _field != null:
		_world = _field.get("_world") as RefCounted
	call_deferred("_bind_accessibility")


func advance(delta: float) -> void:
	_time += maxf(delta, 0.0)
	_wind_intensity = 0.48 + 0.24 * (0.5 + 0.5 * sin(_time * 0.37))
	_punctuation_strength = pow(maxf(sin(_time * TAU / PUNCTUATION_PERIOD_SECONDS), 0.0), 8.0)
	if _field != null and _world != null:
		var grid: Vector2i = _field.call("get_robot_grid") as Vector2i
		_profile = profile_for_surface(_world.call("terrain_at", grid) as StringName)
	if _vfx_intensity > 0.0:
		queue_redraw()


func get_particle_count() -> int:
	return PARTICLE_COUNT


func get_visible_mark_count() -> int:
	return roundi(float(PARTICLE_COUNT) * _vfx_intensity)


func get_wind_intensity() -> float:
	return _wind_intensity


func get_punctuation_strength() -> float:
	return _punctuation_strength


func get_profile() -> StringName:
	return _profile


func _bind_accessibility() -> void:
	var panel: Node = get_tree().get_first_node_in_group("accessibility_panel")
	if panel == null:
		return
	_apply_preferences(panel.call("get_preferences") as Dictionary)
	panel.connect("preferences_changed", _apply_preferences)


func _apply_preferences(snapshot: Dictionary) -> void:
	_vfx_intensity = clampf(float(snapshot.get(&"vfx_intensity", 1.0)), 0.0, 1.0)
	queue_redraw()


static func profile_for_surface(surface: StringName) -> StringName:
	if surface in [&"mud", &"wetland", &"water"]:
		return &"wetland"
	if surface in [&"snow", &"blue_ice", &"ice", &"frozen"]:
		return &"frozen"
	if surface in [&"lava", &"lava_basalt", &"volcanic_ash", &"volcanic"]:
		return &"volcanic"
	return &"sand"


func _draw() -> void:
	var colors: Array[Color] = _profile_colors(_profile)
	for index: int in range(get_visible_mark_count()):
		var seed: float = float(index)
		var speed: float = 75.0 + fmod(seed * 29.0, 95.0) + _punctuation_strength * 45.0
		var x: float = fposmod(seed * 173.0 + _time * speed, 2300.0) - 500.0
		var y: float = fposmod(seed * 83.0, 1050.0) - 120.0
		y += sin(_time * (0.8 + fmod(seed, 7.0) * 0.05) + seed * 1.7) * 16.0
		var length: float = 9.0 + fmod(seed * 13.0, 24.0) * _wind_intensity
		var alpha: float = (
			(0.08 + fmod(seed * 7.0, 10.0) * 0.008)
			* (_wind_intensity + _punctuation_strength * 0.22)
		)
		var color: Color = colors[0].lerp(colors[1], fmod(seed * 0.37, 1.0))
		color.a = alpha * _vfx_intensity
		var start: Vector2 = Vector2(x, y)
		var drift: Vector2 = Vector2(length, -length * 0.16)
		if _profile == &"volcanic":
			drift = Vector2(length * 0.18, -length)
		elif _profile == &"wetland":
			drift = Vector2(length * 0.45, -length * 0.08)
		draw_line(start, start + drift, color, 1.0 + fmod(seed, 2.0))


static func _profile_colors(profile: StringName) -> Array[Color]:
	match profile:
		&"wetland":
			return [Color("6f8f73"), Color("b4c88a")]
		&"frozen":
			return [Color("b8dbe5"), Color("f0fbff")]
		&"volcanic":
			return [Color("d85f31"), Color("ffc14d")]
	return [DUST, PALE_DUST]
