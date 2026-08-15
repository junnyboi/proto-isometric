extends Control

signal repair_requested

const AMBER: Color = Color("f5a62d")
const TEAL: Color = Color("4eb6aa")
const MUTED: Color = Color("9f9787")
const REPAIR_COST: int = 5

var _status: Label
var _inventory: Label
var _repair_button: Button
var _craft_button: Button
var _upgrade_button: Button


func _ready() -> void:
	position = Vector2(866.0, 28.0)
	size = Vector2(386.0, 252.0)
	_build_panel()
	set_state(false, 0, 100, 100)


func set_state(linked: bool, scrap: int, chassis: int, max_chassis: int) -> void:
	if _status == null:
		return
	_status.text = "LINKED // SERVICE BUS ONLINE" if linked else "SEARCHING // ENTER AN OUTPOST"
	_status.add_theme_color_override("font_color", TEAL if linked else MUTED)
	_inventory.text = "SCRAP %03d   CHASSIS %03d/%03d" % [scrap, chassis, max_chassis]
	_repair_button.disabled = not linked or scrap < REPAIR_COST or chassis >= max_chassis
	_craft_button.disabled = true
	_upgrade_button.disabled = true


func is_repair_enabled() -> bool:
	return _repair_button != null and not _repair_button.disabled


func are_locked_actions_disabled() -> bool:
	return (
		_craft_button != null
		and _upgrade_button != null
		and _craft_button.disabled
		and _upgrade_button.disabled
	)


func get_status_text() -> String:
	return _status.text if _status != null else ""


func _build_panel() -> void:
	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.04, 0.055, 0.06, 0.92)
	add_child(background)

	var title: Label = Label.new()
	title.position = Vector2(22.0, 14.0)
	title.size = Vector2(340.0, 34.0)
	title.text = "HARVESTED OUTPOST"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", AMBER)
	background.add_child(title)

	_status = Label.new()
	_status.position = Vector2(22.0, 54.0)
	_status.size = Vector2(340.0, 24.0)
	_status.add_theme_font_size_override("font_size", 13)
	background.add_child(_status)

	_inventory = Label.new()
	_inventory.position = Vector2(22.0, 82.0)
	_inventory.size = Vector2(340.0, 24.0)
	_inventory.add_theme_font_size_override("font_size", 14)
	_inventory.add_theme_color_override("font_color", Color("d8d0b5"))
	background.add_child(_inventory)

	_repair_button = _make_button("REPAIR CHASSIS  [5 SCRAP]", Vector2(22.0, 118.0))
	_repair_button.pressed.connect(func() -> void: repair_requested.emit())
	background.add_child(_repair_button)

	_craft_button = _make_button("CRAFTING  [LOCKED]", Vector2(22.0, 162.0))
	_craft_button.size.x = 168.0
	background.add_child(_craft_button)

	_upgrade_button = _make_button("UPGRADES  [LOCKED]", Vector2(194.0, 162.0))
	_upgrade_button.size.x = 168.0
	background.add_child(_upgrade_button)

	var hint: Label = Label.new()
	hint.position = Vector2(22.0, 212.0)
	hint.size = Vector2(340.0, 22.0)
	hint.text = "FIELD SERVICES // PROTOTYPE CHANNEL"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", MUTED)
	background.add_child(hint)


func _make_button(text: String, button_position: Vector2) -> Button:
	var button: Button = Button.new()
	button.position = button_position
	button.size = Vector2(340.0, 36.0)
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 13)
	return button
