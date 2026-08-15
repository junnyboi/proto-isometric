extends CanvasLayer

signal repair_requested

const OutpostInterfaceScript: GDScript = preload("res://scripts/outpost_interface.gd")
const AMBER: Color = Color("f5a62d")
const TEAL: Color = Color("4eb6aa")
const MUTED: Color = Color("9f9787")

var _status_label: Label
var _outpost_interface: Control


func _ready() -> void:
	layer = 2
	_build_drive_panel()
	_outpost_interface = OutpostInterfaceScript.new() as Control
	_outpost_interface.name = "OutpostInterface"
	_outpost_interface.connect("repair_requested", func() -> void: repair_requested.emit())
	add_child(_outpost_interface)


func set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func get_status_text() -> String:
	return _status_label.text if _status_label != null else ""


func set_outpost_state(linked: bool, scrap: int, chassis: int, max_chassis: int) -> void:
	if _outpost_interface != null:
		_outpost_interface.call("set_state", linked, scrap, chassis, max_chassis)


func get_outpost_interface() -> Control:
	return _outpost_interface


func _build_drive_panel() -> void:
	var panel: ColorRect = ColorRect.new()
	panel.position = Vector2(28.0, 28.0)
	panel.size = Vector2(430.0, 246.0)
	panel.color = Color(0.04, 0.055, 0.06, 0.9)
	add_child(panel)

	var title: Label = Label.new()
	title.position = Vector2(24.0, 18.0)
	title.size = Vector2(380.0, 48.0)
	title.text = "CARDINAL // FIELD DRIVE"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", AMBER)
	panel.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.position = Vector2(25.0, 66.0)
	subtitle.size = Vector2(380.0, 54.0)
	subtitle.text = "HEAVY FRAME ONLINE\nSALVAGE. SURVIVE THE WIND."
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("d8d0b5"))
	panel.add_child(subtitle)

	_status_label = Label.new()
	_status_label.position = Vector2(25.0, 128.0)
	_status_label.size = Vector2(390.0, 32.0)
	_status_label.text = "VECTOR SE // DRIVE 0.00 // CHASSIS 100 // SCRAP 000"
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", TEAL)
	panel.add_child(_status_label)

	var interaction: Label = Label.new()
	interaction.position = Vector2(25.0, 162.0)
	interaction.size = Vector2(380.0, 26.0)
	interaction.text = "SPACE / J / K: IMPACT STRIKE"
	interaction.add_theme_font_size_override("font_size", 14)
	interaction.add_theme_color_override("font_color", AMBER)
	panel.add_child(interaction)

	var help: Label = Label.new()
	help.position = Vector2(25.0, 202.0)
	help.size = Vector2(390.0, 24.0)
	help.text = "WASD/ARROWS: 8D  SHIFT: RUN  OUTPOSTS: SERVICE"
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", MUTED)
	panel.add_child(help)
