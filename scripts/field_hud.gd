extends CanvasLayer

signal repair_requested

const OutpostInterfaceScript: GDScript = preload("res://scripts/outpost_interface.gd")
const FIELD_THEME: Resource = preload("res://data/field_hud_theme.tres")
const AMBER: Color = Color("f5a62d")
const TEAL: Color = Color("4eb6aa")
const MUTED: Color = Color("9f9787")

var _state: RefCounted
var _layout: Dictionary = {}
var _drive_panel: ColorRect
var _status_label: Label
var _charge_fill: ColorRect
var _charge_label: Label
var _relay_label: Label
var _mobile_charge_panel: ColorRect
var _mobile_charge_fill: ColorRect
var _outpost_interface: Control


func _ready() -> void:
	layer = 5
	_build_drive_panel()
	_build_mobile_charge()
	_outpost_interface = OutpostInterfaceScript.new() as Control
	_outpost_interface.name = "OutpostInterface"
	_outpost_interface.connect("repair_requested", func() -> void: repair_requested.emit())
	add_child(_outpost_interface)
	get_viewport().size_changed.connect(_on_viewport_resized)
	apply_layout(get_viewport().get_visible_rect().size, false)


func apply_state(state: RefCounted) -> bool:
	if state == null or not state.has_method("is_sealed") or not bool(state.call("is_sealed")):
		return false
	_state = state
	_apply_status()
	_apply_impact()
	_apply_objective()
	_apply_outpost()
	return apply_layout(
		get_viewport().get_visible_rect().size,
		bool(_state.call("get_value", &"mobile_controls")),
	)


func apply_layout(viewport_size: Vector2, mobile: bool) -> bool:
	var candidate: Dictionary = FIELD_THEME.call("make_layout", viewport_size, mobile) as Dictionary
	if not bool(FIELD_THEME.call("validate_layout", candidate, mobile)):
		return false
	_layout = candidate.duplicate(true)
	_apply_control_layout(
		_drive_panel,
		_layout[&"drive_panel"] as Rect2,
		float(_layout[&"drive_scale"]),
	)
	if _outpost_interface != null:
		(
			_outpost_interface
			. call(
				"apply_layout",
				_layout[&"outpost_panel"] as Rect2,
				float(_layout[&"outpost_scale"]),
			)
		)
	_apply_control_layout(
		_mobile_charge_panel,
		_layout[&"mobile_charge"] as Rect2,
		float(_layout[&"mobile_charge_scale"]),
	)
	return true


func get_layout_snapshot() -> Dictionary:
	return _layout.duplicate(true)


func get_touch_exclusions() -> Array[Rect2]:
	var mobile: bool = _state != null and bool(_state.call("get_value", &"mobile_controls"))
	return FIELD_THEME.call("touch_exclusions", _layout, mobile) as Array[Rect2]


func get_field_state_snapshot() -> Dictionary:
	return _state.call("to_dictionary") as Dictionary if _state != null else {}


func get_status_text() -> String:
	return _status_label.text if _status_label != null else ""


func get_impact_text() -> String:
	return _charge_label.text if _charge_label != null else ""


func get_relay_text() -> String:
	return _relay_label.text if _relay_label != null else ""


func get_outpost_interface() -> Control:
	return _outpost_interface


func _apply_status() -> void:
	var context: String = str(_state.call("get_value", &"context_event"))
	var debug: String = ""
	if bool(_state.call("get_value", &"debug_visible")):
		var cell: Vector2i = _state.call("get_value", &"debug_cell") as Vector2i
		debug = (
			" // %s %.2f @ %d,%d"
			% [
				_state.call("get_value", &"debug_facing"),
				float(_state.call("get_value", &"debug_speed_ratio")),
				cell.x,
				cell.y,
			]
		)
	_status_label.text = (
		"%s%s\nCHASSIS %03d/%03d // SCRAP %03d // CORE %03d"
		% [
			context,
			debug,
			int(_state.call("get_value", &"chassis")),
			int(_state.call("get_value", &"max_chassis")),
			int(_state.call("get_value", &"run_scrap")),
			int(_state.call("get_value", &"worm_cores")),
		]
	)


func _apply_impact() -> void:
	var value: float = float(_state.call("get_value", &"impact_charge"))
	var color: Color = TEAL if value < 0.4 else AMBER
	_charge_fill.size.x = 300.0 * value
	_charge_fill.color = color
	_charge_label.text = (
		"IMPACT %03d%% // %s"
		% [
			roundi(value * 100.0),
			String(_state.call("get_value", &"impact_band")),
		]
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
			"RELAY LINKING %03d%% // ALERT %d"
			% [roundi(float(_state.call("get_value", &"relay_progress")) * 100.0), alert]
		)
	else:
		_relay_label.text = (
			"RELAY %d/%d // ALERT %d // %s"
			% [
				int(_state.call("get_value", &"completed_relays")),
				int(_state.call("get_value", &"total_relays")),
				alert,
				str(_state.call("get_value", &"objective_guidance")),
			]
		)


func _apply_outpost() -> void:
	(
		_outpost_interface
		. call(
			"set_state",
			bool(_state.call("get_value", &"outpost_linked")),
			int(_state.call("get_value", &"run_scrap")),
			int(_state.call("get_value", &"chassis")),
			int(_state.call("get_value", &"max_chassis")),
		)
	)


func _on_viewport_resized() -> void:
	var mobile: bool = _state != null and bool(_state.call("get_value", &"mobile_controls"))
	apply_layout(get_viewport().get_visible_rect().size, mobile)


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
	var title: Label = _make_label("CARDINAL // FIELD DRIVE", Vector2(24.0, 18.0), 30, AMBER)
	_drive_panel.add_child(title)
	var subtitle: Label = _make_label(
		"HEAVY FRAME ONLINE\nSALVAGE. SURVIVE THE WIND.", Vector2(25.0, 66.0), 18, Color("d8d0b5")
	)
	subtitle.size.y = 54.0
	_drive_panel.add_child(subtitle)
	_status_label = _make_label("HEAVY FRAME ONLINE", Vector2(25.0, 124.0), 12, TEAL)
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
	_charge_label = _make_label("IMPACT 000% // CONTACT", Vector2(25.0, 183.0), 13, AMBER)
	_drive_panel.add_child(_charge_label)
	_relay_label = _make_label("RELAY 0/1 // ALERT 0 // SEARCHING", Vector2(25.0, 211.0), 13, TEAL)
	_relay_label.size.x = 390.0
	_drive_panel.add_child(_relay_label)
	_drive_panel.add_child(
		_make_label("SPACE / J / K: IMPACT STRIKE", Vector2(25.0, 241.0), 14, AMBER)
	)
	_drive_panel.add_child(
		_make_label(
			"WASD/ARROWS: 8D  SHIFT: RUN  OUTPOSTS: SERVICE", Vector2(25.0, 271.0), 11, MUTED
		)
	)


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
