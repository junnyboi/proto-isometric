extends RefCounted

var _direction: Vector2 = Vector2.ZERO
var _running: bool = false
var _pending: bool = false
var _resolved_running: bool = false


func clear() -> void:
	_direction = Vector2.ZERO
	_running = false
	_pending = false
	_resolved_running = false


func resolve(direction: Vector2, running: bool, locked: bool) -> Vector2:
	var current: Vector2 = direction.limit_length(1.0)
	if locked:
		if current.length() >= 0.05:
			_direction = current
			_running = running
			_pending = true
		_resolved_running = false
		return Vector2.ZERO
	if current.length() >= 0.05:
		_pending = false
		_resolved_running = running
		return current
	if not _pending:
		_resolved_running = false
		return Vector2.ZERO
	var buffered: Vector2 = _direction
	_resolved_running = _running
	_direction = Vector2.ZERO
	_running = false
	_pending = false
	return buffered


func is_running() -> bool:
	return _resolved_running


func has_pending_input() -> bool:
	return _pending
