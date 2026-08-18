extends RefCounted

const FieldUIStateScript: GDScript = preload("res://scripts/field_ui_state.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const FIELD_THEME: Resource = preload("res://data/field_hud_theme.tres")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_semantic_state(cases)
	_test_invalid_state(cases)
	_test_layouts(cases)
	return cases


static func _test_semantic_state(cases: Array[Dictionary]) -> void:
	var state: RefCounted = FieldUIStateScript.new() as RefCounted
	_add_case(
		cases,
		"field UI accepts bounded vital facts",
		bool(state.call("configure_vitals", 80, 100, 12, 0))
	)
	_add_case(
		cases,
		"field UI accepts semantic Impact facts",
		bool(state.call("configure_impact", 0.65, &"SHOCK LINE"))
	)
	_add_case(
		cases,
		"field UI accepts semantic objective facts",
		bool(state.call("configure_objective", 0, 1, 0.25, &"linking", 0, "SIGNAL NE")),
	)
	_add_case(
		cases,
		"field UI accepts contextual presentation facts",
		bool(
			(
				state
				. call(
					"configure_context",
					"RELAY CONTEST",
					RuntimeIdsScript.MODIFIER_NEUTRAL,
					false,
					true,
				)
			)
		),
	)
	_add_case(
		cases,
		"field UI accepts debug facts without enabling them",
		bool(state.call("configure_debug", false, &"NE", 0.75, Vector2i(12, 6))),
	)
	_add_case(cases, "complete field UI state seals once", bool(state.call("seal")))
	_add_case(cases, "sealed field UI state cannot reseal", not bool(state.call("seal")))
	_add_case(
		cases,
		"sealed field UI state rejects later mutation",
		not bool(state.call("configure_vitals", 100, 100, 0, 0)),
	)
	var snapshot: Dictionary = state.call("to_dictionary") as Dictionary
	_add_case(cases, "future Core field is present at zero", int(snapshot[&"worm_cores"]) == 0)
	_add_case(cases, "future Alert field is present at zero", int(snapshot[&"alert_level"]) == 0)
	_add_case(cases, "future relay total is explicit", int(snapshot[&"total_relays"]) == 1)
	_add_case(
		cases,
		"neutral modifier is explicit",
		snapshot[&"active_modifier_id"] == RuntimeIdsScript.MODIFIER_NEUTRAL,
	)
	_add_case(cases, "coordinate telemetry is debug-hidden", not bool(snapshot[&"debug_visible"]))
	snapshot[&"context_event"] = "MUTATED COPY"
	_add_case(
		cases,
		"field UI dictionary projection is detached",
		state.call("get_value", &"context_event") == "RELAY CONTEST",
	)


static func _test_invalid_state(cases: Array[Dictionary]) -> void:
	var state: RefCounted = FieldUIStateScript.new() as RefCounted
	_add_case(
		cases,
		"field UI rejects impossible chassis facts",
		not bool(state.call("configure_vitals", 101, 100, 0, 0)),
	)
	_add_case(
		cases,
		"field UI rejects unknown Impact bands",
		not bool(state.call("configure_impact", 0.5, &"UNKNOWN")),
	)
	_add_case(
		cases,
		"field UI rejects impossible relay counts",
		not bool(state.call("configure_objective", 2, 1, 0.0, &"dormant", 0, "SEARCHING")),
	)
	_add_case(
		cases,
		"field UI rejects unknown modifier IDs",
		not bool(state.call("configure_context", "TEST", &"modifier.unknown", false, false)),
	)
	_add_case(cases, "incomplete field UI state cannot seal", not bool(state.call("seal")))


static func _test_layouts(cases: Array[Dictionary]) -> void:
	var configurations: Array[Dictionary] = [
		{&"name": "desktop 1280x720", &"size": Vector2(1280.0, 720.0), &"mobile": false},
		{&"name": "mobile landscape 1024x576", &"size": Vector2(1024.0, 576.0), &"mobile": true},
		{&"name": "mobile portrait 720x1280", &"size": Vector2(720.0, 1280.0), &"mobile": true},
		{&"name": "narrow portrait 390x844", &"size": Vector2(390.0, 844.0), &"mobile": true},
	]
	for configuration: Dictionary in configurations:
		var mobile: bool = bool(configuration[&"mobile"])
		var layout: Dictionary = (
			FIELD_THEME.call("make_layout", configuration[&"size"], mobile) as Dictionary
		)
		var name: String = str(configuration[&"name"])
		_add_case(
			cases,
			"%s layout validates" % name,
			bool(FIELD_THEME.call("validate_layout", layout, mobile))
		)
		var exclusions: Array[Rect2] = (
			FIELD_THEME.call("touch_exclusions", layout, mobile) as Array[Rect2]
		)
		_add_case(
			cases,
			"%s exposes expected exclusions" % name,
			exclusions.size() == (4 if mobile else 2)
		)
		_add_case(cases, "%s exclusions do not overlap" % name, not _rects_overlap(exclusions))
		var clamped: Vector2 = (
			FIELD_THEME.call("clamp_touch_origin", Vector2(-50.0, 9000.0), layout, 76.0) as Vector2
		)
		_add_case(
			cases,
			"%s clamps joystick into safe bounds" % name,
			(layout[&"safe_bounds"] as Rect2).has_point(clamped)
		)


static func _rects_overlap(rects: Array[Rect2]) -> bool:
	for first_index: int in range(rects.size()):
		for second_index: int in range(first_index + 1, rects.size()):
			if rects[first_index].intersects(rects[second_index]):
				return true
	return false


static func _add_case(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
