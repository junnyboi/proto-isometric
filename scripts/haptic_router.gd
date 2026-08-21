extends RefCounted

var _enabled: bool = true
var _intensity: float = 1.0
var _request_count: int = 0
var _played_count: int = 0
var _last_duration_ms: int = 0
var _last_weak: float = 0.0
var _last_strong: float = 0.0
var _active_device: int = -1


func pulse(profile: Dictionary) -> bool:
	if not _enabled or _intensity <= 0.0:
		return false
	var duration_ms: int = roundi(float(profile.get(&"haptic_duration_seconds", 0.0)) * 1000.0)
	var weak: float = clampf(float(profile.get(&"haptic_weak", 0.0)) * _intensity, 0.0, 1.0)
	var strong: float = clampf(float(profile.get(&"haptic_strong", 0.0)) * _intensity, 0.0, 1.0)
	if duration_ms <= 0 or (weak <= 0.0 and strong <= 0.0):
		return false
	_request_count += 1
	_last_duration_ms = duration_ms
	_last_weak = weak
	_last_strong = strong
	if DisplayServer.get_name() == "headless":
		return true
	Input.vibrate_handheld(duration_ms)
	for device: int in _target_devices():
		Input.start_joy_vibration(device, weak, strong, float(duration_ms) / 1000.0)
	_played_count += 1
	return true


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		stop()


func set_intensity(intensity: float) -> void:
	_intensity = clampf(intensity, 0.0, 1.0)
	_enabled = _intensity > 0.0
	if not _enabled:
		stop()


func set_active_device(device: int) -> void:
	_active_device = device if device in Input.get_connected_joypads() else -1


func stop() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for device: int in _target_devices():
		Input.stop_joy_vibration(device)


func get_metrics() -> Dictionary:
	return {
		&"enabled": _enabled,
		&"intensity": _intensity,
		&"requests": _request_count,
		&"played": _played_count,
		&"last_duration_ms": _last_duration_ms,
		&"last_weak": _last_weak,
		&"last_strong": _last_strong,
		&"active_device": _active_device,
	}


func _target_devices() -> Array[int]:
	var connected: Array[int] = Input.get_connected_joypads()
	if _active_device >= 0 and _active_device in connected:
		return [_active_device]
	return connected
