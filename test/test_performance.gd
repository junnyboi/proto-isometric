extends RefCounted

const ImpactEffectsScript: GDScript = preload("res://scripts/impact_effects.gd")
const PerformanceSamplerScript: GDScript = preload("res://scripts/performance_sampler.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_bounded_ring(cases)
	_test_percentiles_and_hitches(cases)
	_test_workload_metrics(cases)
	_test_idle_effect_redraws(cases)
	return cases


static func _test_bounded_ring(cases: Array[Dictionary]) -> void:
	var sampler: Node = PerformanceSamplerScript.new() as Node
	for index: int in range(750):
		sampler.call("_sample", float(index % 40))
	var snapshot: Dictionary = sampler.call("get_snapshot") as Dictionary
	_add(
		cases, "performance sampler keeps a bounded 600-frame ring", int(snapshot[&"count"]) == 600
	)
	_add(
		cases,
		"performance sampler retains lifetime sample count",
		int(snapshot[&"total_samples"]) == 750
	)
	_add(
		cases,
		"performance sampler reports ordered finite percentiles",
		(
			float(snapshot[&"p50_ms"]) <= float(snapshot[&"p95_ms"])
			and float(snapshot[&"p95_ms"]) <= float(snapshot[&"p99_ms"])
			and float(snapshot[&"p99_ms"]) <= float(snapshot[&"max_ms"])
			and is_finite(float(snapshot[&"max_ms"]))
		),
	)
	sampler.free()


static func _test_percentiles_and_hitches(cases: Array[Dictionary]) -> void:
	var sampler: Node = PerformanceSamplerScript.new() as Node
	for value: float in [10.0, 20.0, 30.0, 40.0, 60.0, 120.0]:
		sampler.call("_sample", value)
	var snapshot: Dictionary = sampler.call("get_snapshot") as Dictionary
	_add(
		cases,
		"performance sampler reports deterministic P50",
		is_equal_approx(float(snapshot[&"p50_ms"]), 40.0)
	)
	_add(
		cases,
		"performance sampler reports deterministic P95",
		is_equal_approx(float(snapshot[&"p95_ms"]), 120.0)
	)
	_add(
		cases,
		"performance sampler reports deterministic P99",
		is_equal_approx(float(snapshot[&"p99_ms"]), 120.0)
	)
	_add(cases, "performance sampler counts 60 Hz misses", int(snapshot[&"over_16_67_ms"]) == 5)
	_add(cases, "performance sampler counts 30 Hz misses", int(snapshot[&"over_33_33_ms"]) == 3)
	_add(cases, "performance sampler counts long frames", int(snapshot[&"over_50_ms"]) == 2)
	_add(cases, "performance sampler counts severe frames", int(snapshot[&"over_100_ms"]) == 1)
	sampler.call("reset")
	var reset_snapshot: Dictionary = sampler.call("get_snapshot") as Dictionary
	_add(
		cases,
		"performance sampler reset clears frame history",
		int(reset_snapshot[&"count"]) == 0 and int(reset_snapshot[&"total_samples"]) == 0
	)
	sampler.free()


static func _test_workload_metrics(cases: Array[Dictionary]) -> void:
	var sampler: Node = PerformanceSamplerScript.new() as Node
	sampler.call("set_phase", &"field_idle")
	sampler.call("increment_counter", &"hud.state_builds")
	sampler.call("increment_counter", &"hud.state_builds", 2)
	sampler.call("set_gauge", &"world.visible_cells", 841.0)
	sampler.call("record_scope", &"hud.refresh", 0.25)
	sampler.call("record_scope", &"hud.refresh", 0.75)
	var snapshot: Dictionary = sampler.call("get_snapshot") as Dictionary
	var counters: Dictionary = snapshot[&"counters"] as Dictionary
	var gauges: Dictionary = snapshot[&"gauges"] as Dictionary
	var scopes: Dictionary = snapshot[&"scopes"] as Dictionary
	var hud_scope: Dictionary = scopes[&"hud.refresh"] as Dictionary
	_add(cases, "performance sampler labels benchmark phases", snapshot[&"phase"] == &"field_idle")
	_add(
		cases,
		"performance sampler accumulates workload counters",
		int(counters[&"hud.state_builds"]) == 3
	)
	_add(
		cases,
		"performance sampler records workload gauges",
		is_equal_approx(float(gauges[&"world.visible_cells"]), 841.0)
	)
	_add(cases, "performance sampler records scoped call counts", int(hud_scope[&"calls"]) == 2)
	_add(
		cases,
		"performance sampler records scoped totals",
		is_equal_approx(float(hud_scope[&"total_ms"]), 1.0)
	)
	_add(
		cases,
		"performance sampler records scoped maxima",
		is_equal_approx(float(hud_scope[&"max_ms"]), 0.75)
	)
	_add(
		cases,
		"performance sampler records scoped averages",
		is_equal_approx(float(hud_scope[&"average_ms"]), 0.5)
	)
	counters[&"hud.state_builds"] = 999
	_add(
		cases,
		"performance snapshots detach mutable metrics",
		(
			int(
				((sampler.call("get_snapshot") as Dictionary)[&"counters"] as Dictionary)[&"hud.state_builds"]
			)
			== 3
		),
	)
	sampler.free()


static func _test_idle_effect_redraws(cases: Array[Dictionary]) -> void:
	var effects: Node2D = ImpactEffectsScript.new() as Node2D
	var idle_before: int = int(effects.call("get_redraw_request_count"))
	effects.call("advance", 0.016)
	_add(
		cases,
		"idle impact effects request no redraw",
		int(effects.call("get_redraw_request_count")) == idle_before,
	)
	effects.call("emit_scrap_pickup", Vector2.ZERO, 1)
	var active_before: int = int(effects.call("get_redraw_request_count"))
	effects.call("advance", 1.0)
	var cleared: int = int(effects.call("get_redraw_request_count"))
	effects.call("advance", 0.016)
	_add(cases, "active impact effects redraw through final clear", cleared == active_before + 1)
	_add(
		cases,
		"cleared impact effects return to idle redraw gating",
		int(effects.call("get_redraw_request_count")) == cleared,
	)
	effects.free()


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})


static func evaluate_live(map: Node, world: RefCounted) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var sampler: Node = map.get_node("PerformanceSampler")
	var hud: CanvasLayer = map.get_node("FieldHUD") as CanvasLayer
	var objects: Node2D = map.get_node("WorldObjectLayer/WorldObjects") as Node2D
	map.call("_refresh_outpost_interface")
	var snapshot: Dictionary = sampler.call("get_snapshot") as Dictionary
	var counters: Dictionary = snapshot[&"counters"] as Dictionary
	var gauges: Dictionary = snapshot[&"gauges"] as Dictionary
	_add(cases, "live performance telemetry exposes P99 frame time", snapshot.has(&"p99_ms"))
	_add(
		cases,
		"live performance telemetry counts HUD state builds",
		int(counters.get(&"hud.state_builds", 0)) >= 1,
	)
	_add(
		cases,
		"live performance telemetry validates visible workload",
		(
			int(round(float(gauges.get(&"world.visible_cells", 0.0))))
			== int(world.call("get_render_cell_limit"))
		),
	)
	var metrics_before: Dictionary = hud.call("get_work_metrics") as Dictionary
	var builds_before: int = int(counters.get(&"hud.state_builds", 0))
	var skips_before: int = int(counters.get(&"hud.build_skips", 0))
	map.call("_refresh_outpost_interface")
	map.call("_refresh_outpost_interface")
	var metrics_after: Dictionary = hud.call("get_work_metrics") as Dictionary
	var counters_after: Dictionary = (sampler.call("get_snapshot") as Dictionary)[&"counters"]
	_add(
		cases,
		"unchanged field state skips HUD construction",
		int(counters_after.get(&"hud.state_builds", 0)) == builds_before,
	)
	_add(
		cases,
		"unchanged field state records HUD build skips",
		int(counters_after.get(&"hud.build_skips", 0)) >= skips_before + 2,
	)
	_add(
		cases,
		"unchanged field state performs no HUD section application",
		int(metrics_after[&"state_applies"]) == int(metrics_before[&"state_applies"]),
	)
	_add(
		cases,
		"unchanged field state performs no HUD layout",
		int(metrics_after[&"layout_applies"]) == int(metrics_before[&"layout_applies"]),
	)
	var radar: Control = hud.get_node("ExpeditionRadar") as Control
	var radar_redraws: int = int(radar.call("get_redraw_request_count"))
	hud.call("sync_radar", map.call("get_robot_grid"), map.call("_get_completed_relays"))
	_add(
		cases,
		"unchanged expedition radar requests no redraw",
		int(radar.call("get_redraw_request_count")) == radar_redraws,
	)
	var object_redraws: int = int(objects.call("get_redraw_request_count"))
	map.call("_process", 0.016)
	_add(
		cases,
		"stationary field frame requests no static object redraw",
		int(objects.call("get_redraw_request_count")) == object_redraws,
	)
	return cases
