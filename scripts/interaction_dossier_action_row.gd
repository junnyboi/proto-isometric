extends Button

const MIN_TOUCH_HEIGHT: float = 44.0
const BASE_HEIGHT: float = 68.0
const MIN_UI_SCALE: float = 0.85
const MAX_UI_SCALE: float = 1.25
const MAX_LABEL_CHARS: int = 80
const MAX_DESCRIPTION_CHARS: int = 180
const MAX_AUXILIARY_CHARS: int = 120
const CHARCOAL: Color = Color("10181b")
const PANEL_ALT: Color = Color(0.055, 0.105, 0.105, 0.98)
const TEAL: Color = Color("4eb6aa")
const AMBER: Color = Color("f5a62d")
const TEXT: Color = Color("f4ecd8")
const MUTED: Color = Color("9eb1aa")
const DISABLED_COLOR: Color = Color("7d8580")

var _icon_slot: TextureRect
var _label_node: Label
var _description_node: Label
var _cost_node: Label
var _reason_node: Label
var _selected: bool = false
var _enabled: bool = true
var _ui_scale: float = 1.0


func _init() -> void:
	_build()
	reset()


func apply_presentation(presentation: Dictionary, selected: bool = false) -> void:
	set_content(
		str(presentation.get(&"label", "")),
		str(presentation.get(&"description", "")),
		str(presentation.get(&"cost", "")),
		str(presentation.get(&"reason", "")),
		presentation.get(&"icon") as Texture2D,
		bool(presentation.get(&"enabled", true)),
		selected,
		str(presentation.get(&"accessible_name", "")),
	)


func set_content(
	label_text: String,
	description_text: String = "",
	cost_text: String = "",
	reason_text: String = "",
	icon_texture: Texture2D = null,
	enabled: bool = true,
	selected: bool = false,
	accessible_text: String = "",
) -> void:
	_label_node.text = _bounded(label_text, MAX_LABEL_CHARS)
	_description_node.text = _bounded(description_text, MAX_DESCRIPTION_CHARS)
	_cost_node.text = _bounded(cost_text, MAX_AUXILIARY_CHARS)
	_reason_node.text = _bounded(reason_text, MAX_AUXILIARY_CHARS)
	_icon_slot.texture = icon_texture
	_enabled = enabled
	_selected = selected
	disabled = not enabled
	_description_node.visible = not _description_node.text.is_empty()
	_cost_node.visible = enabled and not _cost_node.text.is_empty()
	_reason_node.visible = not enabled and not _reason_node.text.is_empty()
	var detail: String = _reason_node.text if not enabled else _join_detail()
	tooltip_text = _label_node.text if detail.is_empty() else "%s — %s" % [_label_node.text, detail]
	accessibility_name = accessible_text.strip_edges()
	if accessibility_name.is_empty():
		accessibility_name = tooltip_text
	_update_visual_state()


func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	_update_visual_state()


func set_enabled(value: bool, reason_text: String = "") -> void:
	_enabled = value
	disabled = not value
	if not reason_text.is_empty():
		_reason_node.text = _bounded(reason_text, MAX_AUXILIARY_CHARS)
	_cost_node.visible = value and not _cost_node.text.is_empty()
	_reason_node.visible = not value and not _reason_node.text.is_empty()
	var detail: String = _reason_node.text if not value else _join_detail()
	tooltip_text = _label_node.text if detail.is_empty() else "%s — %s" % [_label_node.text, detail]
	accessibility_name = tooltip_text
	_update_visual_state()


func set_ui_scale(value: float) -> void:
	_ui_scale = clampf(value, MIN_UI_SCALE, MAX_UI_SCALE)
	custom_minimum_size.y = maxf(MIN_TOUCH_HEIGHT, BASE_HEIGHT * _ui_scale)
	_icon_slot.custom_minimum_size = Vector2.ONE * clampf(32.0 * _ui_scale, 28.0, 40.0)
	_label_node.add_theme_font_size_override("font_size", roundi(15.0 * _ui_scale))
	_description_node.add_theme_font_size_override("font_size", roundi(12.0 * _ui_scale))
	_cost_node.add_theme_font_size_override("font_size", roundi(12.0 * _ui_scale))
	_reason_node.add_theme_font_size_override("font_size", roundi(12.0 * _ui_scale))


func reset() -> void:
	set_ui_scale(1.0)
	set_content("", "", "", "", null, true, false)
	visible = false


func is_selected() -> bool:
	return _selected


func is_enabled() -> bool:
	return _enabled


func presentation_snapshot() -> Dictionary:
	return {
		&"label": _label_node.text,
		&"description": _description_node.text,
		&"cost": _cost_node.text,
		&"reason": _reason_node.text,
		&"has_icon": _icon_slot.texture != null,
		&"enabled": _enabled,
		&"selected": _selected,
		&"minimum_height": custom_minimum_size.y,
	}


func _build() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	text = ""
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)
	_icon_slot = TextureRect.new()
	_icon_slot.name = "IconSlot"
	_icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_icon_slot)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	_label_node = _new_label("Label", TEXT)
	_label_node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(_label_node)
	_description_node = _new_label("Description", MUTED)
	_description_node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(_description_node)
	var auxiliary := HBoxContainer.new()
	auxiliary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	auxiliary.add_theme_constant_override("separation", 8)
	copy.add_child(auxiliary)
	_cost_node = _new_label("Cost", AMBER)
	_cost_node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	auxiliary.add_child(_cost_node)
	_reason_node = _new_label("Reason", DISABLED_COLOR)
	_reason_node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	auxiliary.add_child(_reason_node)


func _new_label(node_name: String, color: Color) -> Label:
	var result := Label.new()
	result.name = node_name
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_color_override("font_color", color)
	return result


func _update_visual_state() -> void:
	add_theme_stylebox_override("normal", _style(_selected, _enabled, false))
	add_theme_stylebox_override("hover", _style(_selected, _enabled, true))
	add_theme_stylebox_override("pressed", _style(true, _enabled, true))
	add_theme_stylebox_override("focus", _style(true, _enabled, false))
	add_theme_stylebox_override("disabled", _style(_selected, false, false))
	_label_node.add_theme_color_override("font_color", TEXT if _enabled else DISABLED_COLOR)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _enabled else Control.CURSOR_ARROW


func _style(selected: bool, enabled: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_ALT if enabled else Color(CHARCOAL, 0.86)
	if hovered and enabled:
		style.bg_color = Color(TEAL, 0.25)
	style.border_color = AMBER if selected else Color(TEAL if enabled else DISABLED_COLOR, 0.5)
	style.border_width_left = 5 if selected else 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_left = 2
	return style


func _join_detail() -> String:
	if _description_node.text.is_empty():
		return _cost_node.text
	if _cost_node.text.is_empty():
		return _description_node.text
	return "%s; %s" % [_description_node.text, _cost_node.text]


func _bounded(value: String, maximum: int) -> String:
	var clean: String = value.strip_edges().replace("\n", " ").replace("\r", " ")
	return clean if clean.length() <= maximum else clean.left(maximum - 1) + "…"
