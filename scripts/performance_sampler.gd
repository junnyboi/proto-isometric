extends Node

const MAX_SAMPLES: int = 600

var _samples: PackedFloat32Array = PackedFloat32Array()
var _cursor: int = 0


func _process(delta: float) -> void:
	_sample(delta * 1000.0)


func get_snapshot() -> Dictionary:
	if _samples.is_empty():
		return {&"count": 0, &"p50_ms": 0.0, &"p95_ms": 0.0, &"max_ms": 0.0}
	var ordered: PackedFloat32Array = _samples.duplicate()
	ordered.sort()
	return {
		&"count": ordered.size(),
		&"p50_ms": ordered[clampi(roundi(float(ordered.size() - 1) * 0.50), 0, ordered.size() - 1)],
		&"p95_ms": ordered[clampi(roundi(float(ordered.size() - 1) * 0.95), 0, ordered.size() - 1)],
		&"max_ms": ordered[ordered.size() - 1],
	}


func _sample(milliseconds: float) -> void:
	var bounded: float = clampf(milliseconds, 0.0, 1000.0)
	if _samples.size() < MAX_SAMPLES:
		_samples.append(bounded)
		return
	_samples[_cursor] = bounded
	_cursor = (_cursor + 1) % MAX_SAMPLES
