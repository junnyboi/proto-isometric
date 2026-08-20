extends Control

signal repair_requested
signal refit_requested(module_id: StringName)

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const RunModifierEffectsScript: GDScript = preload("res://scripts/run_modifier_effects.gd")
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
const INTERACTION_PULSE_SECONDS: float = 0.16

var _title_label: Label
var _status: Label
var _inventory: Label
var _repair_button: Button
var _module_buttons: Array[Button] = []
var _footer_label: Label
var _last_state: Dictionary = {}


func _ready() -> void:
	size = DESIGN_SIZE
	_build_panel()
	add_to_group("localization_listeners")
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
	active_modifier: StringName = RuntimeIdsScript.MODIFIER_NEUTRAL,
) -> void:
	_last_state = {
		&"linked": linked,
		&"scrap": scrap,
		&"cores": cores,
		&"chassis": chassis,
		&"max_chassis": max_chassis,
		&"active_modules": active_modules.duplicate(),
		&"refit_used": refit_used,
		&"active_modifier": active_modifier,
	}
	_refresh_state()


func _refresh_state() -> void:
	if _status == null or _last_state.is_empty():
		return
	var linked: bool = bool(_last_state[&"linked"])
	var scrap: int = int(_last_state[&"scrap"])
	var cores: int = int(_last_state[&"cores"])
	var chassis: int = int(_last_state[&"chassis"])
	var max_chassis: int = int(_last_state[&"max_chassis"])
	var active_modules: Array = _last_state[&"active_modules"] as Array
	var refit_used: bool = bool(_last_state[&"refit_used"])
	var active_modifier: StringName = _last_state[&"active_modifier"] as StringName
	_status.text = LocalizationScript.t(
		&"outpost.status_linked" if linked else &"outpost.status_searching"
	)
	_status.add_theme_color_override("font_color", TEAL if linked else MUTED)
	_inventory.text = (
		LocalizationScript
		. t(
			&"outpost.inventory",
			{
				"scrap": "%03d" % scrap,
				"cores": "%03d" % cores,
				"chassis": "%03d" % chassis,
				"max_chassis": "%03d" % max_chassis,
			}
		)
	)
	var repair_cost: int = RunModifierEffectsScript.repair_cost(REPAIR_COST, active_modifier)
	_repair_button.text = LocalizationScript.t(&"outpost.repair", {"cost": repair_cost})
	_repair_button.disabled = not linked or scrap < repair_cost or chassis >= max_chassis
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
			LocalizationScript.t(&"outpost.module_installed")
			if installed
			else (
				LocalizationScript
				. t(
					&"outpost.module_available",
					{
						"name": LocalizationScript.t(definition.get("display_name")),
						"cores": definition.get("core_cost"),
						"scrap": definition.get("scrap_cost"),
					}
				)
			)
		)
		button.tooltip_text = (
			LocalizationScript
			. t(
				&"outpost.module_tooltip",
				{
					"summary": LocalizationScript.t(definition.get("summary")),
					"cores": definition.get("core_cost"),
					"scrap": definition.get("scrap_cost"),
				}
			)
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


func _on_locale_changed(_locale: StringName) -> void:
	_refresh_static_text()
	_refresh_state()


func _refresh_static_text() -> void:
	if _title_label == null:
		return
	_title_label.text = LocalizationScript.t(&"outpost.title")
	_footer_label.text = LocalizationScript.t(&"outpost.footer")


func _build_panel() -> void:
	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.04, 0.055, 0.06, 0.92)
	add_child(background)
	_title_label = _make_label(
		LocalizationScript.t(&"outpost.title"), Vector2(22.0, 14.0), 24, AMBER
	)
	background.add_child(_title_label)
	_status = _make_label("", Vector2(22.0, 54.0), 13, MUTED)
	background.add_child(_status)
	_inventory = _make_label("", Vector2(22.0, 82.0), 14, Color("d8d0b5"))
	background.add_child(_inventory)
	_repair_button = _make_button("", Vector2(22.0, 112.0))
	_repair_button.size = Vector2(340.0, 34.0)
	_repair_button.pressed.connect(_on_repair_pressed)
	background.add_child(_repair_button)
	for index: int in range(DEFINITIONS.size()):
		_build_module_button(background, DEFINITIONS[index], index)
	_footer_label = _make_label(
		LocalizationScript.t(&"outpost.footer"), Vector2(22.0, 229.0), 10, MUTED
	)
	background.add_child(_footer_label)


func _build_module_button(parent: Control, definition: Resource, index: int) -> void:
	var button: Button = _make_button(
		LocalizationScript.t(definition.get("display_name")), Vector2(22.0 + index * 114.0, 153.0)
	)
	button.size = Vector2(110.0, 70.0)
	button.icon = definition.get("icon") as Texture2D
	button.add_theme_constant_override("icon_max_width", 38)
	button.expand_icon = true
	button.add_theme_font_size_override("font_size", 10)
	var module_id: StringName = definition.get("module_id") as StringName
	button.pressed.connect(_on_refit_pressed.bind(button, module_id))
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


func _on_repair_pressed() -> void:
	_pulse_button(_repair_button)
	repair_requested.emit()


func _on_refit_pressed(button: Button, module_id: StringName) -> void:
	_pulse_button(button)
	refit_requested.emit(module_id)


func _pulse_button(button: Button) -> void:
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2(0.97, 0.97)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, INTERACTION_PULSE_SECONDS)
