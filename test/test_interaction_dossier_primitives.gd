extends SceneTree

const SafeAreaScript: GDScript = preload("res://scripts/platform_safe_area.gd")
const ActionRowScript: GDScript = preload("res://scripts/interaction_dossier_action_row.gd")
const FactRowScript: GDScript = preload("res://scripts/interaction_dossier_fact_row.gd")
const VIEWPORTS: Array[Vector2] = [
	Vector2(320.0, 568.0),
	Vector2(390.0, 844.0),
	Vector2(720.0, 1280.0),
	Vector2(844.0, 390.0),
]
const UI_SCALES: Array[float] = [0.85, 1.0, 1.25]
const INSETS: Array[Dictionary] = [
	{&"left": 0.0, &"top": 28.0, &"right": 0.0, &"bottom": 22.0},
	{&"left": 0.0, &"top": 47.0, &"right": 0.0, &"bottom": 34.0},
	{&"left": 0.0, &"top": 24.0, &"right": 0.0, &"bottom": 28.0},
	{&"left": 42.0, &"top": 0.0, &"right": 28.0, &"bottom": 16.0},
]

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_pure_cases()
	await _run_live_cases()
	if _failures == 0:
		print("[INTERACTION_DOSSIER_PRIMITIVES_PASS] checks=%d" % _checks)
		quit(0)
	else:
		print(
			"[INTERACTION_DOSSIER_PRIMITIVES_FAIL] checks=%d failures=%d"
			% [_checks, _failures]
		)
		quit(1)


func _run_pure_cases() -> void:
	for viewport_index: int in VIEWPORTS.size():
		var viewport: Vector2 = VIEWPORTS[viewport_index]
		for ui_scale: float in UI_SCALES:
			var result: Dictionary = SafeAreaScript.resolve(
				viewport, INSETS[viewport_index], ui_scale
			)
			var bounds: Rect2 = result[&"bounds"] as Rect2
			var visible := Rect2(Vector2.ZERO, viewport)
			_check(
				visible.encloses(bounds) and bounds.size.x >= 0.0 and bounds.size.y >= 0.0,
				"%s at %.2f safe bounds remain viewport-local" % [viewport, ui_scale],
			)
			_check(
				is_equal_approx(float(result[&"ui_scale"]), ui_scale),
				"%s accepts UI scale %.2f without scaling platform insets" % [viewport, ui_scale],
			)
	var clamped: Dictionary = SafeAreaScript.resolve(
		Vector2(320.0, 568.0),
		{&"left": -50.0, &"top": NAN, &"right": 900.0, &"bottom": INF},
	)
	var clamped_bounds: Rect2 = clamped[&"bounds"] as Rect2
	_check(
		clamped_bounds.position.x >= 0.0
		and clamped_bounds.position.y >= 0.0
		and clamped_bounds.end.x <= 320.0
		and clamped_bounds.end.y <= 568.0,
		"invalid and oversized injected insets clamp without escaping the viewport",
	)
	var collapsed: Dictionary = SafeAreaScript.resolve(
		Vector2(20.0, 10.0),
		{&"left": 100.0, &"top": 100.0, &"right": 100.0, &"bottom": 100.0},
	)
	_check(
		(collapsed[&"bounds"] as Rect2).size == Vector2.ZERO,
		"opposing insets collapse safely to a non-negative zero-sized rectangle",
	)


func _run_live_cases() -> void:
	var host := Control.new()
	host.name = "PrimitiveTestHost"
	get_root().add_child(host)
	for viewport: Vector2 in VIEWPORTS:
		for ui_scale: float in UI_SCALES:
			var action: Button = ActionRowScript.new() as Button
			host.add_child(action)
			action.call("set_ui_scale", ui_scale)
			action.call(
				"set_content",
				"Inspect relay",
				"Read provider-backed condition details",
				"2 Scrap",
				"Requires a calibrated scanner",
				null,
				true,
				true,
			)
			action.visible = true
			var fact: Control = FactRowScript.new() as Control
			host.add_child(fact)
			fact.call("set_ui_scale", ui_scale)
			fact.call("set_fact", "Surface", "Ancient reinforced alloy", &"text_key")
			fact.visible = true
			await process_frame
			var action_snapshot: Dictionary = action.call("presentation_snapshot") as Dictionary
			var fact_snapshot: Dictionary = fact.call("presentation_snapshot") as Dictionary
			_check(
				float(action_snapshot[&"minimum_height"]) >= 44.0
				and float(fact_snapshot[&"minimum_height"]) >= 44.0,
				"%s at %.2f keeps both pooled rows at least 44 px" % [viewport, ui_scale],
			)
			_check(
				bool(action_snapshot[&"enabled"])
				and bool(action_snapshot[&"selected"])
				and not action.accessibility_name.is_empty()
				and not action.tooltip_text.is_empty(),
				"%s at %.2f exposes enabled/selected and accessible action text"
				% [viewport, ui_scale],
			)
			action.call("set_enabled", false, "Requires a calibrated scanner")
			action_snapshot = action.call("presentation_snapshot") as Dictionary
			_check(
				action.disabled
				and not bool(action_snapshot[&"enabled"])
				and str(action_snapshot[&"reason"]) == "Requires a calibrated scanner",
				"%s at %.2f renders a disabled reason without dispatch authority"
				% [viewport, ui_scale],
			)
			action.queue_free()
			fact.queue_free()
			await process_frame
	var bounded_action: Button = ActionRowScript.new() as Button
	host.add_child(bounded_action)
	bounded_action.call("set_content", "L".repeat(200), "D".repeat(400))
	var bounded_fact: Control = FactRowScript.new() as Control
	host.add_child(bounded_fact)
	bounded_fact.call("set_fact", "K".repeat(200), "V".repeat(400), StringName("kind".repeat(20)))
	var action_data: Dictionary = bounded_action.call("presentation_snapshot") as Dictionary
	var fact_data: Dictionary = bounded_fact.call("presentation_snapshot") as Dictionary
	_check(
		str(action_data[&"label"]).length() <= 80
		and str(action_data[&"description"]).length() <= 180
		and str(fact_data[&"label"]).length() <= 64
		and str(fact_data[&"value"]).length() <= 160
		and str(fact_data[&"kind"]).length() <= 32,
		"row presentation text is bounded before display",
	)
	host.queue_free()
	await process_frame


func _check(passed: bool, label: String) -> void:
	_checks += 1
	print("[%s] %s" % ["PASS" if passed else "FAIL", label])
	if not passed:
		_failures += 1
