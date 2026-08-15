extends Node2D

const PARTICLE_COUNT: int = 96
const DUST: Color = Color("dca45a")
const PALE_DUST: Color = Color("f0c985")

var _time: float = 0.0
var _wind_intensity: float = 0.55


func advance(delta: float) -> void:
	_time += maxf(delta, 0.0)
	_wind_intensity = 0.48 + 0.24 * (0.5 + 0.5 * sin(_time * 0.37))
	queue_redraw()


func get_particle_count() -> int:
	return PARTICLE_COUNT


func get_wind_intensity() -> float:
	return _wind_intensity


func _draw() -> void:
	for index: int in range(PARTICLE_COUNT):
		var seed: float = float(index)
		var speed: float = 75.0 + fmod(seed * 29.0, 95.0)
		var x: float = fposmod(seed * 173.0 + _time * speed, 2300.0) - 500.0
		var y: float = fposmod(seed * 83.0, 1050.0) - 120.0
		y += sin(_time * (0.8 + fmod(seed, 7.0) * 0.05) + seed * 1.7) * 16.0
		var length: float = 9.0 + fmod(seed * 13.0, 24.0) * _wind_intensity
		var alpha: float = (0.08 + fmod(seed * 7.0, 10.0) * 0.008) * _wind_intensity
		var color: Color = DUST.lerp(PALE_DUST, fmod(seed * 0.37, 1.0))
		color.a = alpha
		var start: Vector2 = Vector2(x, y)
		draw_line(start, start + Vector2(length, -length * 0.16), color, 1.0 + fmod(seed, 2.0))
