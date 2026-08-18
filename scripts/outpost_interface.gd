extends Control

signal repair_requested
signal refit_requested(module_id: StringName)

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const DEFINITIONS: Array[Resource] = [
	preload("res://data/modules/ram_plating.tres"),
	preload("res://data/modules/aftershock.tres"),
	preload("res://data/modules/storm_seal.tres"),
]
const AMBER: Color = Color("f5a62d")
const TEAL: Color = Color("4eb6aa")
const MUTED: Color = Color("9f9787")
const REPAIR_COST: int = 5
const DESIGN_SIZE: Vector2 = Vector2(386.0, 252.0)

var _status: Label
var _inventory: Label
var _repair_button: Button
var _module_buttons: Array[Button] = []


func _ready() -> void:
	size = DESIGN_SIZE
	_build_panel()
	set_state(false, 0, 0, 100, 100)


func apply_layout(rect: Rect2, scale_value: float) -> bool:
	if scale_value <= 0.0 or not is_finite(scale_value):
		return false
	position = rect.position
	size = DESIGN_SIZE
	scale = Vector2.ONE * scale_value
	return true


func get_layout_rect() -> Rect2:
	return Rect2(position, DESIGN_SIZE * scale)


func set_state(
	linked: bool,
	scrap: int,
	cores: int,
	chassis: int,
	max_chassis: int,
	active_modules: Array = [RuntimeIdsScript.MODULE_WORN_PLATES],
	refit_used: bool = false,
) -> void:
	if _status == null:
		return
	_status.text = "LINKED // REFIT BUS ONLINE" if linked else "SEARCHING // ENTER AN OUTPOST"
	_status.add_theme_color_override("font_color", TEAL if linked else MUTED)
	_inventory.text = (
		"SCRAP %03d   CORE %03d   CHASSIS %03d/%03d" % [scrap, cores, chassis, max_chassis]
	)
	_repair_button.disabled = not linked or scrap < REPAIR_COST or chassis >= max_chassis
	for index: int in range(DEFINITIONS.size()):
		var definition: Resource = DEFINITIONS[index]
		var module_id: StringName = definition.get("module_id") as StringName
		var button: Button = _module_buttons[index]
		var installed: bool = module_id in active_modules
		button.disabled = (
			not linked
			or refit_used
			or installed
			or cores < int(definition.get("core_cost"))
			or scrap < int(definition.get("scrap_cost"))
		)
		button.text = (
			"INSTALLED  ◆"
			if installed
			else (
				"%s\n◇ %dC %dS"
				% [
					definition.get("display_name"),
					definition.get("core_cost"),
					definition.get("scrap_cost")
				]
			)
		)
		button.tooltip_text = (
			"%s\n%d CORE + %d SCRAP"
			% [definition.get("summary"), definition.get("core_cost"), definition.get("scrap_cost")]
		)


func is_repair_enabled() -> bool:
	return _repair_button != null and not _repair_button.disabled


func are_locked_actions_disabled() -> bool:
	for button: Button in _module_buttons:
		if not button.disabled:
			return false
	return true


func get_status_text() -> String:
	return _status.text if _status != null else ""


func get_module_button(module_id: StringName) -> Button:
	for index: int in range(DEFINITIONS.size()):
		if DEFINITIONS[index].get("module_id") == module_id:
			return _module_buttons[index]
	return null


func _build_panel() -> void:
	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.04, 0.055, 0.06, 0.92)
	add_child(background)
	background.add_child(_make_label("HARVESTED OUTPOST", Vector2(22.0, 14.0), 24, AMBER))
	_status = _make_label("SEARCHING", Vector2(22.0, 54.0), 13, MUTED)
	background.add_child(_status)
	_inventory = _make_label("SCRAP 000", Vector2(22.0, 82.0), 14, Color("d8d0b5"))
	background.add_child(_inventory)
	_repair_button = _make_button("REPAIR CHASSIS  [5 SCRAP]", Vector2(22.0, 112.0))
	_repair_button.size = Vector2(340.0, 34.0)
	_repair_button.pressed.connect(func() -> void: repair_requested.emit())
	background.add_child(_repair_button)
	for index: int in range(DEFINITIONS.size()):
		_build_module_button(background, DEFINITIONS[index], index)
	background.add_child(
		_make_label(
			"ONE REFIT PER EXPEDITION // PASSIVE FIELD SYSTEM", Vector2(22.0, 229.0), 10, MUTED
		)
	)


func _build_module_button(parent: Control, definition: Resource, index: int) -> void:
	var button: Button = _make_button(
		str(definition.get("display_name")), Vector2(22.0 + index * 114.0, 153.0)
	)
	button.size = Vector2(110.0, 70.0)
	button.icon = definition.get("icon") as Texture2D
	button.add_theme_constant_override("icon_max_width", 38)
	button.expand_icon = true
	button.add_theme_font_size_override("font_size", 10)
	var module_id: StringName = definition.get("module_id") as StringName
	button.pressed.connect(func() -> void: refit_requested.emit(module_id))
	_module_buttons.append(button)
	parent.add_child(button)


func _make_label(text: String, label_position: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.position = label_position
	label.size = Vector2(340.0, 26.0)
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(text: String, button_position: Vector2) -> Button:
	var button: Button = Button.new()
	button.position = button_position
	button.size = Vector2(340.0, 36.0)
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 13)
	return button
