extends Node

const MAX_SAMPLES: int = 600
const FRAME_BUDGET_60_MS: float = 16.67
const FRAME_BUDGET_30_MS: float = 33.33
const LONG_FRAME_MS: float = 50.0
const SEVERE_FRAME_MS: float = 100.0

var _samples: PackedFloat32Array = PackedFloat32Array()
var _cursor: int = 0
var _total_samples: int = 0
var _phase: StringName = &"boot"
var _counters: Dictionary = {}
var _gauges: Dictionary = {}
var _scopes: Dictionary = {}


func _process(delta: float) -> void:
	_sample(delta * 1000.0)


func reset() -> void:
	_samples.clear()
	_cursor = 0
	_total_samples = 0
	_counters.clear()
	_gauges.clear()
	_scopes.clear()


func set_phase(phase: StringName) -> void:
	_phase = phase


func increment_counter(counter: StringName, amount: int = 1) -> void:
	_counters[counter] = int(_counters.get(counter, 0)) + amount


func set_gauge(gauge: StringName, value: float) -> void:
	if is_finite(value):
		_gauges[gauge] = value


func capture_stream(world: RefCounted, visible_cells: int, started_usec: int) -> void:
	end_scope(&"stream.total", started_usec)
	increment_counter(&"stream.refreshes")
	set_gauge(&"world.visible_cells", float(visible_cells))
	set_gauge(&"world.loaded_chunks", float(world.call("get_loaded_chunk_count")))


func capture_save(saved: bool, started_usec: int) -> void:
	end_scope(&"save.total", started_usec)
	increment_counter(&"save.attempts")
	set_gauge(&"save.last_succeeded", 1.0 if saved else 0.0)


func begin_scope() -> int:
	return Time.get_ticks_usec()


func end_scope(scope: StringName, started_usec: int) -> float:
	var elapsed_usec: int = maxi(Time.get_ticks_usec() - started_usec, 0)
	var elapsed_ms: float = float(elapsed_usec) / 1000.0
	record_scope(scope, elapsed_ms)
	return elapsed_ms


func record_scope(scope: StringName, milliseconds: float) -> void:
	if not is_finite(milliseconds) or milliseconds < 0.0:
		return
	var metric: Dictionary = (
		(_scopes[scope] as Dictionary).duplicate()
		if _scopes.has(scope)
		else {&"calls": 0, &"total_ms": 0.0, &"max_ms": 0.0}
	)
	metric[&"calls"] = int(metric[&"calls"]) + 1
	metric[&"total_ms"] = float(metric[&"total_ms"]) + milliseconds
	metric[&"max_ms"] = maxf(float(metric[&"max_ms"]), milliseconds)
	metric[&"average_ms"] = float(metric[&"total_ms"]) / float(metric[&"calls"])
	_scopes[scope] = metric


func get_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		&"phase": _phase,
		&"count": _samples.size(),
		&"total_samples": _total_samples,
		&"p50_ms": 0.0,
		&"p95_ms": 0.0,
		&"p99_ms": 0.0,
		&"max_ms": 0.0,
		&"over_16_67_ms": 0,
		&"over_33_33_ms": 0,
		&"over_50_ms": 0,
		&"over_100_ms": 0,
		&"counters": _counters.duplicate(),
		&"gauges": _gauges.duplicate(),
		&"scopes": _scopes.duplicate(true),
	}
	if _samples.is_empty():
		return snapshot
	var ordered: PackedFloat32Array = _samples.duplicate()
	ordered.sort()
	snapshot[&"p50_ms"] = _percentile(ordered, 0.50)
	snapshot[&"p95_ms"] = _percentile(ordered, 0.95)
	snapshot[&"p99_ms"] = _percentile(ordered, 0.99)
	snapshot[&"max_ms"] = ordered[ordered.size() - 1]
	for sample: float in _samples:
		if sample > FRAME_BUDGET_60_MS:
			snapshot[&"over_16_67_ms"] = int(snapshot[&"over_16_67_ms"]) + 1
		if sample > FRAME_BUDGET_30_MS:
			snapshot[&"over_33_33_ms"] = int(snapshot[&"over_33_33_ms"]) + 1
		if sample > LONG_FRAME_MS:
			snapshot[&"over_50_ms"] = int(snapshot[&"over_50_ms"]) + 1
		if sample > SEVERE_FRAME_MS:
			snapshot[&"over_100_ms"] = int(snapshot[&"over_100_ms"]) + 1
	return snapshot


func _sample(milliseconds: float) -> void:
	var bounded: float = clampf(milliseconds, 0.0, 1000.0)
	_total_samples += 1
	if _samples.size() < MAX_SAMPLES:
		_samples.append(bounded)
		return
	_samples[_cursor] = bounded
	_cursor = (_cursor + 1) % MAX_SAMPLES


func _percentile(ordered: PackedFloat32Array, percentile: float) -> float:
	var index: int = clampi(
		roundi(float(ordered.size() - 1) * clampf(percentile, 0.0, 1.0)),
		0,
		ordered.size() - 1,
	)
	return ordered[index]
