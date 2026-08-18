extends RefCounted

const PerformanceSamplerScript: GDScript = preload("res://scripts/performance_sampler.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var sampler: Node = PerformanceSamplerScript.new() as Node
	for index: int in range(750):
		sampler.call("_sample", float(index % 40))
	var snapshot: Dictionary = sampler.call("get_snapshot") as Dictionary
	_add(
		cases, "performance sampler keeps a bounded 600-frame ring", int(snapshot[&"count"]) == 600
	)
	_add(
		cases,
		"performance sampler reports ordered finite percentiles",
		(
			float(snapshot[&"p50_ms"]) <= float(snapshot[&"p95_ms"])
			and float(snapshot[&"p95_ms"]) <= float(snapshot[&"max_ms"])
			and is_finite(float(snapshot[&"max_ms"]))
		),
	)
	sampler.free()
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
