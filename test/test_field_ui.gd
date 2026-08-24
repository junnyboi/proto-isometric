extends RefCounted

const AccessibilityPanelScript: GDScript = preload("res://scripts/accessibility_panel.gd")
const FieldHUDScript: GDScript = preload("res://scripts/field_hud.gd")
const FieldUIStateScript: GDScript = preload("res://scripts/field_ui_state.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const FIELD_THEME: Resource = preload("res://data/field_hud_theme.tres")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_semantic_state(cases)
	_test_invalid_state(cases)
	_test_field_hud_presentation(cases)
	_test_layouts(cases)
	return cases


static func _test_semantic_state(cases: Array[Dictionary]) -> void:
	var state: RefCounted = FieldUIStateScript.new() as RefCounted
	_add_case(
		cases,
		"field UI accepts bounded vital facts",
		bool(state.call("configure_vitals", 80, 100, 12, 3))
	)
	_add_case(
		cases,
		"field UI accepts semantic Impact facts",
		bool(state.call("configure_impact", 0.65, &"impact.band.shock_line"))
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
	_add_case(cases, "collected Core wallet is explicit", int(snapshot[&"worm_cores"]) == 3)
	_add_case(
		cases,
		"resource collection goals match repair and refit thresholds",
		int(snapshot[&"scrap_goal"]) == 5 and int(snapshot[&"core_goal"]) == 1,
	)
	_add_case(
		cases,
		"field UI carries validated biome and terrain context",
		snapshot[&"current_biome"] == &"desert"
		and snapshot[&"terrain_surface"] == &"sand"
		and snapshot[&"current_outpost_kind"] == &"",
	)
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
	_add_case(
		cases,
		"field UI rejects unknown biome and terrain context",
		not bool(
			state.call(
				"configure_context",
				"TEST",
				RuntimeIdsScript.MODIFIER_NEUTRAL,
				false,
				false,
				[RuntimeIdsScript.MODULE_WORN_PLATES],
				false,
				&"unknown",
				&"mystery",
			)
		),
	)
	_add_case(
		cases,
		"linked outpost context requires a supported building identity",
		not bool(
			state.call(
				"configure_context",
				"TEST",
				RuntimeIdsScript.MODIFIER_NEUTRAL,
				true,
				false,
				[RuntimeIdsScript.MODULE_WORN_PLATES],
				false,
				&"desert",
				&"sand",
				&"",
			)
		),
	)
	_add_case(
		cases,
		"field UI accepts a biome-matched rendered outpost kind",
		bool(
			state.call(
				"configure_context",
				"TEST",
				RuntimeIdsScript.MODIFIER_NEUTRAL,
				true,
				false,
				[RuntimeIdsScript.MODULE_WORN_PLATES],
				false,
				&"desert",
				&"sand",
				&"ancient_temple",
			)
		),
	)
	_add_case(cases, "incomplete field UI state cannot seal", not bool(state.call("seal")))


static func _test_field_hud_presentation(cases: Array[Dictionary]) -> void:
	var state: RefCounted = FieldUIStateScript.new() as RefCounted
	state.call("configure_vitals", 80, 100, 12, 3)
	state.call("configure_impact", 0.65, &"impact.band.shock_line")
	state.call("configure_objective", 1, 3, 0.0, &"signaling", 1, "SIGNAL NE")
	state.call(
		"configure_context",
		"FIELD ONLINE",
		RuntimeIdsScript.MODIFIER_NEUTRAL,
		false,
		false,
	)
	state.call("configure_debug", false, &"NE", 0.75, Vector2i(12, 6))
	state.call("seal")
	var hud: CanvasLayer = FieldHUDScript.new() as CanvasLayer
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	hud.call("apply_state", state)
	var drive_panel: ColorRect = hud.get("_drive_panel") as ColorRect
	var all_text: String = ""
	for label: Node in drive_panel.find_children("*", "Label", true, false):
		all_text += (label as Label).text + "\n"
	var settings_panel: CanvasLayer = hud.call("get_accessibility_panel") as CanvasLayer
	var settings_button: Button = settings_panel.call("get_trigger_button") as Button
	_add_case(
		cases,
		"field panel removes title, subtitle, and movement instructions",
		not all_text.contains("WALKER // FIELD DRIVE")
		and not all_text.contains("SALVAGE. SURVIVE THE WIND")
		and not all_text.contains("WASD/L-STICK"),
	)
	_add_case(
		cases,
		"field panel exposes tracked scrap and Core objectives",
		str(hud.call("get_objectives_text")).contains("012/005")
		and str(hud.call("get_objectives_text")).contains("03/01"),
	)
	_add_case(
		cases,
		"field dialog uses enlarged status, relay, and objective type",
		int((hud.get("_status_label") as Label).get_theme_font_size("font_size")) >= 16
		and int((hud.get("_relay_label") as Label).get_theme_font_size("font_size")) >= 16
		and int((hud.get("_objectives_header") as Label).get_theme_font_size("font_size")) >= 19,
	)
	_add_case(
		cases,
		"Settings trigger uses the localized Settings label",
		settings_button.text == LocalizationScript.t(&"access.button"),
	)
	var desktop_settings: Rect2 = AccessibilityPanelScript.trigger_rect_for(
		Vector2(1280.0, 720.0)
	) as Rect2
	var mobile_layout: Dictionary = FIELD_THEME.call(
		"make_layout", Vector2(720.0, 1280.0), true
	) as Dictionary
	var mobile_charge: Rect2 = mobile_layout[&"mobile_charge"] as Rect2
	var mobile_clearance: float = 1280.0 - mobile_charge.position.y + 16.0
	var mobile_settings: Rect2 = AccessibilityPanelScript.trigger_rect_for(
		Vector2(720.0, 1280.0), mobile_clearance
	) as Rect2
	_add_case(
		cases,
		"Settings trigger anchors to desktop bottom right",
		desktop_settings.position == Vector2(1072.0, 660.0)
		and Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)).encloses(desktop_settings),
	)
	_add_case(
		cases,
		"mobile Settings trigger stays right-aligned above gameplay controls",
		mobile_settings.position.x == 512.0
		and mobile_settings.end.y <= mobile_charge.position.y - 16.0
		and Rect2(Vector2.ZERO, Vector2(720.0, 1280.0)).encloses(mobile_settings),
	)
	hud.free()


static func _test_layouts(cases: Array[Dictionary]) -> void:
	var configurations: Array[Dictionary] = [
		{&"name": "desktop 1280x720", &"size": Vector2(1280.0, 720.0), &"mobile": false},
		{&"name": "mobile landscape 1024x576", &"size": Vector2(1024.0, 576.0), &"mobile": true},
		{&"name": "short landscape 844x390", &"size": Vector2(844.0, 390.0), &"mobile": true},
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
