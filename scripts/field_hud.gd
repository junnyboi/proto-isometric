extends CanvasLayer

signal repair_requested

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const OutpostInterfaceScript: GDScript = preload("res://scripts/outpost_interface.gd")
const AccessibilityPanelScript: GDScript = preload("res://scripts/accessibility_panel.gd")
const ExpeditionRadarScript: GDScript = preload("res://scripts/expedition_radar.gd")
const FieldUIBuilderScript: GDScript = preload("res://scripts/field_ui_builder.gd")
const OnboardingOverlayScript: GDScript = preload("res://scripts/onboarding_overlay.gd")
const RefitServiceScript: GDScript = preload("res://scripts/refit_service.gd")
const FIELD_THEME: Resource = preload("res://data/field_hud_theme.tres")
const AMBER: Color = Color("f5a62d")
const TEAL: Color = Color("4eb6aa")
const MUTED: Color = Color("9f9787")

var _state: RefCounted
var _state_snapshot: Dictionary = {}
var _layout: Dictionary = {}
var _layout_signature: Array = []
var _drive_panel: ColorRect
var _status_label: Label
var _charge_fill: ColorRect
var _charge_label: Label
var _relay_label: Label
var _mobile_charge_panel: ColorRect
var _mobile_charge_fill: ColorRect
var _outpost_interface: Control
var _refit_service: RefCounted
var _ui_scale: float = 1.0
var _onboarding: CanvasLayer
var _radar: Control
var _radar_coordinator: RefCounted
var _performance_sampler: Node
var _left_handed: bool = false
var _panel_title: Label
var _panel_subtitle: Label
var _strike_instruction: Label
var _drive_instruction: Label
var _state_apply_count: int = 0
var _state_skip_count: int = 0
var _layout_apply_count: int = 0


func _ready() -> void:
	layer = 5
	_build_drive_panel()
	_build_mobile_charge()
	add_to_group("localization_listeners")
	_outpost_interface = OutpostInterfaceScript.new() as Control
	_outpost_interface.name = "OutpostInterface"
	_outpost_interface.connect("repair_requested", func() -> void: repair_requested.emit())
	_outpost_interface.connect("refit_requested", _on_refit_requested)
	add_child(_outpost_interface)
	var accessibility: CanvasLayer = AccessibilityPanelScript.new() as CanvasLayer
	accessibility.connect("preferences_changed", _on_preferences_changed)
	add_child(accessibility)
	_on_preferences_changed(accessibility.call("get_preferences") as Dictionary)
	_onboarding = OnboardingOverlayScript.new() as CanvasLayer
	add_child(_onboarding)
	_radar = ExpeditionRadarScript.new() as Control
	add_child(_radar)
	if _radar_coordinator != null:
		_radar.call("configure", _radar_coordinator)
	get_viewport().size_changed.connect(_on_viewport_resized)
	apply_layout(get_viewport().get_visible_rect().size, false, true)


func configure_refit(coordinator: RefCounted, save_callback: Callable) -> bool:
	_radar_coordinator = coordinator
	_refit_service = RefitServiceScript.new() as RefCounted
	if _radar != null:
		_radar.call("configure", coordinator)
	return bool(_refit_service.call("configure", coordinator, save_callback))


func set_performance_sampler(sampler: Node) -> void:
	_performance_sampler = sampler
	FieldUIBuilderScript.configure_performance(sampler)


func apply_state(state: RefCounted) -> bool:
	if state == null or not state.has_method("is_sealed") or not bool(state.call("is_sealed")):
		return false
	var candidate: Dictionary = state.call("to_dictionary") as Dictionary
	if candidate == _state_snapshot:
		_state_skip_count += 1
		_record_counter(&"hud.state_skips")
		return true
	var previous: Dictionary = _state_snapshot
	_state = state
	_state_snapshot = candidate.duplicate(true)
	_state_apply_count += 1
	_record_counter(&"hud.state_applies")
	if _section_changed(
		previous,
		candidate,
		[
			&"context_event",
			&"active_modifier_id",
			&"debug_visible",
			&"debug_cell",
			&"debug_facing",
			&"debug_speed_ratio",
			&"chassis",
			&"max_chassis",
			&"run_scrap",
			&"worm_cores",
		]
	):
		_apply_status()
	if _section_changed(
		previous,
		candidate,
		[
			&"impact_charge",
			&"impact_band",
			&"mobile_controls",
		]
	):
		_apply_impact()
	if _section_changed(
		previous,
		candidate,
		[
			&"relay_state",
			&"relay_progress",
			&"completed_relays",
			&"total_relays",
			&"alert_level",
			&"objective_guidance",
		]
	):
		_apply_objective()
	if _section_changed(
		previous,
		candidate,
		[
			&"outpost_linked",
			&"run_scrap",
			&"worm_cores",
			&"chassis",
			&"max_chassis",
			&"active_module_ids",
			&"refit_purchase_used",
			&"active_modifier_id",
		]
	):
		_apply_outpost()
	if (
		_onboarding != null
		and _section_changed(
			previous,
			candidate,
			[
				&"mobile_controls",
				&"impact_charge",
				&"completed_relays",
			]
		)
	):
		_onboarding.call("apply_state", state)
	if _radar != null:
		(
			_radar
			. call(
				"sync_state",
				candidate[&"debug_cell"] as Vector2i,
				int(candidate[&"completed_relays"]),
			)
		)
	return apply_layout(
		get_viewport().get_visible_rect().size,
		bool(candidate[&"mobile_controls"]),
	)


func apply_layout(viewport_size: Vector2, mobile: bool, force: bool = false) -> bool:
	var signature: Array = [viewport_size, mobile, _left_handed, _ui_scale]
	if not force and signature == _layout_signature:
		return true
	var candidate: Dictionary = FIELD_THEME.call("make_layout", viewport_size, mobile) as Dictionary
	if mobile and _left_handed:
		var charge: Rect2 = candidate[&"mobile_charge"] as Rect2
		candidate[&"mobile_charge"] = Rect2(
			Vector2(viewport_size.x - charge.end.x, charge.position.y), charge.size
		)
	if not bool(FIELD_THEME.call("validate_layout", candidate, mobile)):
		return false
	_layout_signature = signature
	_layout = candidate.duplicate(true)
	_layout_apply_count += 1
	_record_counter(&"hud.layout_applies")
	_apply_control_layout(
		_drive_panel,
		_layout[&"drive_panel"] as Rect2,
		float(_layout[&"drive_scale"]) * _ui_scale,
	)
	if _outpost_interface != null:
		(
			_outpost_interface
			. call(
				"apply_layout",
				_layout[&"outpost_panel"] as Rect2,
				float(_layout[&"outpost_scale"]) * _ui_scale,
			)
		)
	_apply_control_layout(
		_mobile_charge_panel,
		_layout[&"mobile_charge"] as Rect2,
		float(_layout[&"mobile_charge_scale"]) * _ui_scale,
	)
	return true


func _on_preferences_changed(snapshot: Dictionary) -> void:
	_ui_scale = clampf(float(snapshot.get(&"ui_scale", 1.0)), 0.85, 1.25)
	_left_handed = bool(snapshot.get(&"left_handed", false))
	if _drive_panel != null:
		apply_layout(
			get_viewport().get_visible_rect().size,
			_state != null and bool(_state.call("get_value", &"mobile_controls")),
		)


func get_layout_snapshot() -> Dictionary:
	return _layout.duplicate(true)


func get_touch_exclusions() -> Array[Rect2]:
	var mobile: bool = _state != null and bool(_state.call("get_value", &"mobile_controls"))
	return FIELD_THEME.call("touch_exclusions", _layout, mobile) as Array[Rect2]


func get_field_state_snapshot() -> Dictionary:
	return _state_snapshot.duplicate(true)


func get_status_text() -> String:
	return _status_label.text if _status_label != null else ""


func get_impact_text() -> String:
	return _charge_label.text if _charge_label != null else ""


func get_relay_text() -> String:
	return _relay_label.text if _relay_label != null else ""


func get_outpost_interface() -> Control:
	return _outpost_interface


func sync_radar(player_cell: Vector2i, completed_relays: int) -> bool:
	return (
		bool(_radar.call("sync_state", player_cell, completed_relays)) if _radar != null else false
	)


func get_performance_snapshot() -> Dictionary:
	return (
		_performance_sampler.call("get_snapshot") as Dictionary
		if _performance_sampler != null
		else {}
	)


func get_work_metrics() -> Dictionary:
	return {
		&"state_applies": _state_apply_count,
		&"state_skips": _state_skip_count,
		&"layout_applies": _layout_apply_count,
		&"radar_redraw_requests":
		int(_radar.call("get_redraw_request_count")) if _radar != null else 0,
	}


func _apply_status() -> void:
	var context: String = str(_state.call("get_value", &"context_event"))
	var modifier: String = str(_state.call("get_value", &"active_modifier_id"))
	var modifier_suffix: String = ""
	if modifier != "modifier.neutral":
		modifier_suffix = LocalizationScript.t(
			&"hud.modifier", {"name": LocalizationScript.t("%s.title" % modifier)}
		)
	var debug: String = ""
	if bool(_state.call("get_value", &"debug_visible")):
		var cell: Vector2i = _state.call("get_value", &"debug_cell") as Vector2i
		var facing: String = str(_state.call("get_value", &"debug_facing"))
		debug = (
			LocalizationScript
			. t(
				&"hud.debug",
				{
					"facing": LocalizationScript.t("direction.%s" % facing),
					"speed": "%.2f" % float(_state.call("get_value", &"debug_speed_ratio")),
					"x": cell.x,
					"y": cell.y,
				}
			)
		)
	_status_label.text = (
		LocalizationScript
		. t(
			&"hud.status",
			{
				"context": context,
				"modifier": modifier_suffix,
				"debug": debug,
				"chassis": "%03d" % int(_state.call("get_value", &"chassis")),
				"max_chassis": "%03d" % int(_state.call("get_value", &"max_chassis")),
				"scrap": "%03d" % int(_state.call("get_value", &"run_scrap")),
				"cores": "%03d" % int(_state.call("get_value", &"worm_cores")),
			}
		)
	)


func _apply_impact() -> void:
	var value: float = float(_state.call("get_value", &"impact_charge"))
	var color: Color = TEAL if value < 0.4 else AMBER
	_charge_fill.size.x = 300.0 * value
	_charge_fill.color = color
	_charge_label.text = (
		LocalizationScript
		. t(
			&"hud.impact",
			{
				"charge": "%03d" % roundi(value * 100.0),
				"band": LocalizationScript.t(_state.call("get_value", &"impact_band")),
				"bonus": LocalizationScript.t(&"module.worn_plates.short_bonus"),
			}
		)
	)
	var mobile: bool = bool(_state.call("get_value", &"mobile_controls"))
	_mobile_charge_panel.visible = mobile
	_mobile_charge_fill.size.x = 146.0 * value
	_mobile_charge_fill.color = color


func _apply_objective() -> void:
	var state: StringName = _state.call("get_value", &"relay_state") as StringName
	var alert: int = int(_state.call("get_value", &"alert_level"))
	if state == &"linking":
		_relay_label.text = (
			LocalizationScript
			. t(
				&"hud.relay_linking",
				{
					"progress":
					"%03d" % roundi(float(_state.call("get_value", &"relay_progress")) * 100.0),
					"alert": alert,
				}
			)
		)
	else:
		_relay_label.text = (
			LocalizationScript
			. t(
				&"hud.relay",
				{
					"completed": int(_state.call("get_value", &"completed_relays")),
					"total": int(_state.call("get_value", &"total_relays")),
					"alert": alert,
					"guidance": str(_state.call("get_value", &"objective_guidance")),
				}
			)
		)


func _apply_outpost() -> void:
	(
		_outpost_interface
		. call(
			"set_state",
			bool(_state.call("get_value", &"outpost_linked")),
			int(_state.call("get_value", &"run_scrap")),
			int(_state.call("get_value", &"worm_cores")),
			int(_state.call("get_value", &"chassis")),
			int(_state.call("get_value", &"max_chassis")),
			_state.call("get_value", &"active_module_ids"),
			bool(_state.call("get_value", &"refit_purchase_used")),
			_state.call("get_value", &"active_modifier_id"),
		)
	)


func _on_refit_requested(module_id: StringName) -> void:
	if _state == null or _refit_service == null:
		return
	(
		_refit_service
		. call(
			"purchase",
			module_id,
			bool(_state.call("get_value", &"outpost_linked")),
			int(_state.call("get_value", &"chassis")) <= 0,
		)
	)


func _on_viewport_resized() -> void:
	var mobile: bool = _state != null and bool(_state.call("get_value", &"mobile_controls"))
	apply_layout(get_viewport().get_visible_rect().size, mobile)


func _on_locale_changed(_locale: StringName) -> void:
	_refresh_static_text()
	if _state != null:
		_apply_status()
		_apply_impact()
		_apply_objective()


func _section_changed(previous: Dictionary, candidate: Dictionary, keys: Array) -> bool:
	if previous.is_empty():
		return true
	for key: StringName in keys:
		if previous.get(key) != candidate.get(key):
			return true
	return false


func _record_counter(counter: StringName) -> void:
	if _performance_sampler != null:
		_performance_sampler.call("increment_counter", counter)


func _apply_control_layout(control: Control, rect: Rect2, scale_value: float) -> void:
	if control == null:
		return
	control.position = rect.position
	control.scale = Vector2.ONE * scale_value


func _build_drive_panel() -> void:
	_drive_panel = ColorRect.new()
	_drive_panel.size = Vector2(430.0, 294.0)
	_drive_panel.color = Color(0.04, 0.055, 0.06, 0.9)
	add_child(_drive_panel)
	_panel_title = _make_label(
		LocalizationScript.t(&"hud.panel_title"), Vector2(24.0, 18.0), 30, AMBER
	)
	_drive_panel.add_child(_panel_title)
	_panel_subtitle = _make_label(
		LocalizationScript.t(&"hud.panel_subtitle"), Vector2(25.0, 66.0), 18, Color("d8d0b5")
	)
	_panel_subtitle.size.y = 54.0
	_drive_panel.add_child(_panel_subtitle)
	_status_label = _make_label(
		LocalizationScript.t(&"status.heavy_frame_online"), Vector2(25.0, 124.0), 12, TEAL
	)
	_status_label.size = Vector2(390.0, 38.0)
	_drive_panel.add_child(_status_label)
	var charge_back: ColorRect = ColorRect.new()
	charge_back.position = Vector2(25.0, 165.0)
	charge_back.size = Vector2(304.0, 14.0)
	charge_back.color = TEAL.darkened(0.72)
	_drive_panel.add_child(charge_back)
	_charge_fill = ColorRect.new()
	_charge_fill.position = Vector2(2.0, 2.0)
	_charge_fill.size = Vector2(0.0, 10.0)
	_charge_fill.color = TEAL
	charge_back.add_child(_charge_fill)
	_charge_label = _make_label("", Vector2(25.0, 183.0), 13, AMBER)
	_drive_panel.add_child(_charge_label)
	_relay_label = _make_label("", Vector2(25.0, 211.0), 13, TEAL)
	_relay_label.size.x = 390.0
	_drive_panel.add_child(_relay_label)
	_strike_instruction = _make_label(
		LocalizationScript.t(&"hud.strike_instruction"), Vector2(25.0, 241.0), 14, AMBER
	)
	_drive_panel.add_child(_strike_instruction)
	_drive_instruction = _make_label(
		LocalizationScript.t(&"hud.drive_instruction"), Vector2(25.0, 271.0), 11, MUTED
	)
	_drive_panel.add_child(_drive_instruction)


func _refresh_static_text() -> void:
	if _panel_title == null:
		return
	_panel_title.text = LocalizationScript.t(&"hud.panel_title")
	_panel_subtitle.text = LocalizationScript.t(&"hud.panel_subtitle")
	_strike_instruction.text = LocalizationScript.t(&"hud.strike_instruction")
	_drive_instruction.text = LocalizationScript.t(&"hud.drive_instruction")


func _build_mobile_charge() -> void:
	_mobile_charge_panel = ColorRect.new()
	_mobile_charge_panel.size = Vector2(150.0, 12.0)
	_mobile_charge_panel.color = Color(TEAL, 0.54)
	_mobile_charge_panel.visible = false
	add_child(_mobile_charge_panel)
	_mobile_charge_fill = ColorRect.new()
	_mobile_charge_fill.position = Vector2(2.0, 2.0)
	_mobile_charge_fill.size = Vector2(0.0, 8.0)
	_mobile_charge_fill.color = TEAL
	_mobile_charge_panel.add_child(_mobile_charge_fill)


func _make_label(text: String, label_position: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.position = label_position
	label.size = Vector2(380.0, 26.0)
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
