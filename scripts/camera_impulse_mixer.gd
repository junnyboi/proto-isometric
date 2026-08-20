extends RefCounted

const MAX_IMPULSES: int = 8
const MAX_OFFSET: float = 11.0

var _camera: Camera2D
var _impulses: Array[Dictionary] = []
var _enabled: bool = true
var _intensity: float = 1.0
var _submitted_count: int = 0
var _culled_count: int = 0
var _peak_impulses: int = 0


func bind_camera(camera: Camera2D) -> void:
	_camera = camera
	_apply_offset(Vector2.ZERO)


func submit(duration: float, strength: float, direction: Vector2, seed: int) -> bool:
	if not _enabled or _intensity <= 0.0 or duration <= 0.0 or strength <= 0.0:
		return false
	_submitted_count += 1
	if _impulses.size() >= MAX_IMPULSES:
		_impulses.remove_at(0)
		_culled_count += 1
	var normalized: Vector2 = (
		Vector2.RIGHT if direction.is_zero_approx() else direction.normalized()
	)
	(
		_impulses
		. append(
			{
				&"remaining": minf(duration, 0.4),
				&"duration": minf(duration, 0.4),
				&"strength": minf(strength * _intensity, MAX_OFFSET),
				&"direction": normalized,
				&"seed": seed,
			}
		)
	)
	_peak_impulses = maxi(_peak_impulses, _impulses.size())
	_apply_current_offset()
	return true


func advance(delta: float) -> void:
	if not _enabled:
		clear()
		return
	var step: float = maxf(delta, 0.0)
	for index: int in range(_impulses.size() - 1, -1, -1):
		var impulse: Dictionary = _impulses[index]
		impulse[&"remaining"] = maxf(float(impulse[&"remaining"]) - step, 0.0)
		if float(impulse[&"remaining"]) <= 0.0:
			_impulses.remove_at(index)
		else:
			_impulses[index] = impulse
	_apply_current_offset()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		clear()


func set_intensity(intensity: float) -> void:
	_intensity = clampf(intensity, 0.0, 1.0)
	_enabled = _intensity > 0.0
	if not _enabled:
		clear()


func clear() -> void:
	_impulses.clear()
	_apply_offset(Vector2.ZERO)


func get_remaining() -> float:
	var longest: float = 0.0
	for impulse: Dictionary in _impulses:
		longest = maxf(longest, float(impulse[&"remaining"]))
	return longest


func get_offset() -> Vector2:
	return _camera.offset if _camera != null else Vector2.ZERO


func get_metrics() -> Dictionary:
	return {
		&"active": _impulses.size(),
		&"peak": _peak_impulses,
		&"submitted": _submitted_count,
		&"culled": _culled_count,
		&"enabled": _enabled,
		&"intensity": _intensity,
	}


func _apply_current_offset() -> void:
	var total: Vector2 = Vector2.ZERO
	for impulse: Dictionary in _impulses:
		var duration: float = maxf(float(impulse[&"duration"]), 0.001)
		var normalized: float = clampf(float(impulse[&"remaining"]) / duration, 0.0, 1.0)
		var elapsed: float = duration - float(impulse[&"remaining"])
		var phase: float = float(impulse[&"seed"]) * 0.017 + elapsed * 53.0
		var direction: Vector2 = impulse[&"direction"] as Vector2
		var jitter: Vector2 = (
			(direction + direction.orthogonal() * sin(phase * 2.3) * 0.55).normalized()
		)
		total += jitter * float(impulse[&"strength"]) * normalized
	_apply_offset(total.limit_length(MAX_OFFSET))


func _apply_offset(value: Vector2) -> void:
	if _camera != null:
		_camera.offset = value
