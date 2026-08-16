extends CanvasLayer

signal repair_requested

const OutpostInterfaceScript: GDScript = preload("res://scripts/outpost_interface.gd")
const AMBER: Color = Color("f5a62d")
const TEAL: Color = Color("4eb6aa")
const MUTED: Color = Color("9f9787")

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


func set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func get_status_text() -> String:
	return _status_label.text if _status_label != null else ""


func set_impact_state(charge: float, band_name: StringName, mobile: bool) -> void:
	var value: float = clampf(charge, 0.0, 1.0)
	var color: Color = TEAL if value < 0.4 else AMBER
	if _charge_fill != null:
		_charge_fill.size.x = 300.0 * value
		_charge_fill.color = color
	if _charge_label != null:
		_charge_label.text = "IMPACT %03d%% // %s" % [roundi(value * 100.0), String(band_name)]
	if _mobile_charge_panel != null:
		_mobile_charge_panel.visible = mobile
	if _mobile_charge_fill != null:
		_mobile_charge_fill.size.x = 146.0 * value
		_mobile_charge_fill.color = color


func set_relay_state(
	completed_relays: int,
	total_relays: int,
	progress: float,
	state: StringName,
	signal_hint: String,
) -> void:
	if _relay_label == null:
		return
	var alert: int = clampi(completed_relays, 0, 3)
	if state == &"linking":
		_relay_label.text = "RELAY LINKING %03d%% // ALERT %d" % [roundi(progress * 100.0), alert]
	else:
		_relay_label.text = (
			"RELAY %d/%d // ALERT %d // %s" % [completed_relays, total_relays, alert, signal_hint]
		)


func set_outpost_state(linked: bool, scrap: int, chassis: int, max_chassis: int) -> void:
	if _outpost_interface != null:
		_outpost_interface.call("set_state", linked, scrap, chassis, max_chassis)


func get_impact_text() -> String:
	return _charge_label.text if _charge_label != null else ""


func get_relay_text() -> String:
	return _relay_label.text if _relay_label != null else ""


func get_outpost_interface() -> Control:
	return _outpost_interface


func _build_drive_panel() -> void:
	var panel: ColorRect = ColorRect.new()
	panel.position = Vector2(28.0, 28.0)
	panel.size = Vector2(430.0, 294.0)
	panel.color = Color(0.04, 0.055, 0.06, 0.9)
	add_child(panel)

	var title: Label = _make_label("CARDINAL // FIELD DRIVE", Vector2(24.0, 18.0), 30, AMBER)
	panel.add_child(title)
	var subtitle: Label = _make_label(
		"HEAVY FRAME ONLINE\nSALVAGE. SURVIVE THE WIND.", Vector2(25.0, 66.0), 18, Color("d8d0b5")
	)
	subtitle.size.y = 54.0
	panel.add_child(subtitle)

	_status_label = _make_label(
		"VECTOR SE // DRIVE 0.00 // CHASSIS 100 // SCRAP 000", Vector2(25.0, 128.0), 14, TEAL
	)
	_status_label.size.x = 390.0
	panel.add_child(_status_label)

	var charge_back: ColorRect = ColorRect.new()
	charge_back.position = Vector2(25.0, 165.0)
	charge_back.size = Vector2(304.0, 14.0)
	charge_back.color = TEAL.darkened(0.72)
	panel.add_child(charge_back)
	_charge_fill = ColorRect.new()
	_charge_fill.position = Vector2(2.0, 2.0)
	_charge_fill.size = Vector2(0.0, 10.0)
	_charge_fill.color = TEAL
	charge_back.add_child(_charge_fill)
	_charge_label = _make_label("IMPACT 000% // CONTACT", Vector2(25.0, 183.0), 13, AMBER)
	panel.add_child(_charge_label)
	_relay_label = _make_label("RELAY 0/1 // ALERT 0 // SEARCHING", Vector2(25.0, 211.0), 13, TEAL)
	_relay_label.size.x = 390.0
	panel.add_child(_relay_label)

	var interaction: Label = _make_label(
		"SPACE / J / K: IMPACT STRIKE", Vector2(25.0, 241.0), 14, AMBER
	)
	panel.add_child(interaction)
	var help: Label = _make_label(
		"WASD/ARROWS: 8D  SHIFT: RUN  OUTPOSTS: SERVICE", Vector2(25.0, 271.0), 11, MUTED
	)
	panel.add_child(help)


func _build_mobile_charge() -> void:
	_mobile_charge_panel = ColorRect.new()
	_mobile_charge_panel.position = Vector2(1084.0, 490.0)
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
