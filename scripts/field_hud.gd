extends CanvasLayer

signal repair_requested

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const OutpostInterfaceScript: GDScript = preload("res://scripts/outpost_interface.gd")
const AccessibilityPanelScript: GDScript = preload("res://scripts/accessibility_panel.gd")
const CharacterHoverCardScript: GDScript = preload("res://scripts/character_hover_card.gd")
const ExpeditionRadarScript: GDScript = preload("res://scripts/expedition_radar.gd")
const FieldUIBuilderScript: GDScript = preload("res://scripts/field_ui_builder.gd")
const OnboardingOverlayScript: GDScript = preload("res://scripts/onboarding_overlay.gd")
const RefitServiceScript: GDScript = preload("res://scripts/refit_service.gd")
const FIELD_THEME: Resource = preload("res://data/field_hud_theme.tres")
const AMBER: Color = Color("f5a62d")
const TEAL: Color = Color("4eb6aa")
const HUD_PULSE_SECONDS: float = 0.18

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
var _accessibility: CanvasLayer
var _refit_service: RefCounted
var _ui_scale: float = 1.0
var _onboarding: CanvasLayer
var _radar: Control
var _radar_coordinator: RefCounted
var _radar_contacts_source: Node
var _performance_sampler: Node
var _left_handed: bool = false
var _vfx_intensity: float = 1.0
var _objectives_header: Label
var _resource_goal_label: Label
var _state_apply_count: int = 0
var _state_skip_count: int = 0
var _layout_apply_count: int = 0
var _character_hover_card: Control
var _charge_pulse_phase: float = 0.0
var _feedback_pulse_count: int = 0
var _reward_pulse_count: int = 0


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
	_accessibility = AccessibilityPanelScript.new() as CanvasLayer
	_accessibility.connect("preferences_changed", _on_preferences_changed)
	add_child(_accessibility)
	_on_preferences_changed(_accessibility.call("get_preferences") as Dictionary)
	_onboarding = OnboardingOverlayScript.new() as CanvasLayer
	add_child(_onboarding)
	_radar = ExpeditionRadarScript.new() as Control
	add_child(_radar)
	if _radar_coordinator != null:
		_radar.call("configure", _radar_coordinator)
	get_viewport().size_changed.connect(_on_viewport_resized)
	apply_layout(get_viewport().get_visible_rect().size, false, true)


func configure_refit(
	coordinator: RefCounted, save_callback: Callable, contacts_source: Node = null
) -> bool:
	_radar_coordinator = coordinator
	_radar_contacts_source = contacts_source
	_refit_service = RefitServiceScript.new() as RefCounted
	if _radar != null:
		_radar.call("configure", coordinator)
	return bool(_refit_service.call("configure", coordinator, save_callback))


func _process(delta: float) -> void:
	if _radar != null and _radar_contacts_source != null:
		_radar.call("sync_contacts", _radar_contacts_source.call("get_combat_snapshots"))
	_advance_charge_pulse(delta)


func set_performance_sampler(sampler: Node) -> void:
	_performance_sampler = sampler
	FieldUIBuilderScript.configure_performance(sampler)


func configure_character_hover(
	avatar: Node2D, enemies: Node2D, walk_speed: float, run_speed: float
) -> bool:
	if _character_hover_card != null:
		_character_hover_card.queue_free()
	_character_hover_card = CharacterHoverCardScript.new() as Control
	add_child(_character_hover_card)
	return bool(
		(
			_character_hover_card
			. call(
				"bind_sources",
				avatar,
				enemies,
				Callable(self, "get_field_state_snapshot"),
				walk_speed,
				run_speed,
			)
		)
	)


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
	_present_state_deltas(previous, candidate)
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
				&"run_scrap",
				&"worm_cores",
				&"scrap_goal",
				&"core_goal",
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
			&"current_biome",
			&"terrain_surface",
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
	if _accessibility != null:
		var settings_clearance: float = 0.0
		if mobile:
			var charge_rect: Rect2 = _layout[&"mobile_charge"] as Rect2
			settings_clearance = viewport_size.y - charge_rect.position.y + 16.0
		_accessibility.call("set_trigger_bottom_clearance", settings_clearance)
	return true


func _on_preferences_changed(snapshot: Dictionary) -> void:
	_ui_scale = clampf(float(snapshot.get(&"ui_scale", 1.0)), 0.85, 1.25)
	_left_handed = bool(snapshot.get(&"left_handed", false))
	_vfx_intensity = clampf(float(snapshot.get(&"vfx_intensity", 1.0)), 0.0, 1.0)
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


func get_character_hover_card() -> Control:
	return _character_hover_card


func get_status_text() -> String:
	return _status_label.text if _status_label != null else ""


func get_impact_text() -> String:
	return _charge_label.text if _charge_label != null else ""


func get_relay_text() -> String:
	return _relay_label.text if _relay_label != null else ""


func get_objectives_text() -> String:
	return _resource_goal_label.text if _resource_goal_label != null else ""


func get_accessibility_panel() -> CanvasLayer:
	return _accessibility


func get_outpost_interface() -> Control:
	return _outpost_interface


func sync_radar(player_cell: Vector2i, completed_relays: int, contacts: Variant = null) -> bool:
	if _radar == null:
		return false
	var state_changed: bool = bool(_radar.call("sync_state", player_cell, completed_relays))
	var contacts_changed: bool = contacts is Array and bool(_radar.call("sync_contacts", contacts))
	return contacts_changed or state_changed


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
		&"feedback_pulses": _feedback_pulse_count,
		&"reward_pulses": _reward_pulse_count,
		&"radar_redraw_requests":
		int(_radar.call("get_redraw_request_count")) if _radar != null else 0,
	}


func present_feedback(event: Dictionary, _profile: Dictionary) -> bool:
	var target_name: StringName = feedback_target_for(event.get(&"event_id", &"") as StringName)
	var target: Control
	if target_name == &"charge":
		target = _charge_label
	elif target_name == &"objective":
		target = _relay_label
	if target == null:
		return false
	_feedback_pulse_count += 1
	_pulse_control(target, 1.12 if target_name == &"charge" else 1.06, AMBER)
	return true


static func feedback_target_for(event_id: StringName) -> StringName:
	if event_id in [&"event.charge.low", &"event.charge.high"]:
		return &"charge"
	if event_id == &"event.reward.relay":
		return &"objective"
	return &""


static func state_reward_deltas(previous: Dictionary, candidate: Dictionary) -> Dictionary:
	return {
		&"scrap": maxi(int(candidate.get(&"run_scrap", 0)) - int(previous.get(&"run_scrap", 0)), 0),
		&"cores":
		maxi(int(candidate.get(&"worm_cores", 0)) - int(previous.get(&"worm_cores", 0)), 0),
		&"relays":
		maxi(
			int(candidate.get(&"completed_relays", 0)) - int(previous.get(&"completed_relays", 0)),
			0,
		),
	}


func _present_state_deltas(previous: Dictionary, candidate: Dictionary) -> void:
	if previous.is_empty():
		return
	var deltas: Dictionary = state_reward_deltas(previous, candidate)
	if int(deltas[&"scrap"]) > 0 or int(deltas[&"cores"]) > 0:
		_reward_pulse_count += 1
		_pulse_control(_resource_goal_label, 1.04, TEAL)
	if int(deltas[&"relays"]) > 0:
		_reward_pulse_count += 1
		_pulse_control(_relay_label, 1.06, TEAL)


func _advance_charge_pulse(delta: float) -> void:
	if _charge_label == null:
		return
	var charge: float = float(_state_snapshot.get(&"impact_charge", 0.0))
	if charge < 0.4:
		_charge_label.modulate.a = 1.0
		return
	_charge_pulse_phase = fmod(_charge_pulse_phase + maxf(delta, 0.0) * 2.4, TAU)
	var pulse_range: float = 0.12 * _vfx_intensity
	_charge_label.modulate.a = 1.0 - pulse_range + sin(_charge_pulse_phase) * pulse_range


func _pulse_control(control: Control, scale_peak: float, color: Color) -> void:
	if control == null or not control.is_inside_tree():
		return
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * lerpf(1.0, scale_peak, _vfx_intensity)
	control.modulate = Color.WHITE.lerp(color, _vfx_intensity)
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, HUD_PULSE_SECONDS)
	tween.tween_property(control, "modulate", Color.WHITE, HUD_PULSE_SECONDS)


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
	_resource_goal_label.text = (
		LocalizationScript
		. t(
			&"hud.resource_goals",
			{
				"scrap": "%03d" % int(_state.call("get_value", &"run_scrap")),
				"scrap_goal": "%03d" % int(_state.call("get_value", &"scrap_goal")),
				"cores": "%02d" % int(_state.call("get_value", &"worm_cores")),
				"core_goal": "%02d" % int(_state.call("get_value", &"core_goal")),
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
			_state.call("get_value", &"current_biome"),
			_state.call("get_value", &"terrain_surface"),
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
	_status_label = _make_label(
		LocalizationScript.t(&"status.heavy_frame_online"), Vector2(25.0, 18.0), 16, TEAL
	)
	_status_label.size = Vector2(390.0, 50.0)
	_drive_panel.add_child(_status_label)
	var charge_back: ColorRect = ColorRect.new()
	charge_back.position = Vector2(25.0, 77.0)
	charge_back.size = Vector2(304.0, 16.0)
	charge_back.color = TEAL.darkened(0.72)
	_drive_panel.add_child(charge_back)
	_charge_fill = ColorRect.new()
	_charge_fill.position = Vector2(2.0, 2.0)
	_charge_fill.size = Vector2(0.0, 12.0)
	_charge_fill.color = TEAL
	charge_back.add_child(_charge_fill)
	_charge_label = _make_label("", Vector2(25.0, 101.0), 16, AMBER)
	_charge_label.size = Vector2(390.0, 30.0)
	_drive_panel.add_child(_charge_label)
	_relay_label = _make_label("", Vector2(25.0, 135.0), 16, TEAL)
	_relay_label.size = Vector2(390.0, 48.0)
	_drive_panel.add_child(_relay_label)
	_objectives_header = _make_label(
		LocalizationScript.t(&"hud.objectives"), Vector2(25.0, 196.0), 19, AMBER
	)
	_drive_panel.add_child(_objectives_header)
	_resource_goal_label = _make_label("", Vector2(25.0, 226.0), 16, Color("d8d0b5"))
	_resource_goal_label.size = Vector2(390.0, 58.0)
	_drive_panel.add_child(_resource_goal_label)


func _refresh_static_text() -> void:
	if _objectives_header == null:
		return
	_objectives_header.text = LocalizationScript.t(&"hud.objectives")
	if _state != null:
		_apply_objective()


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
