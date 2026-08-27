extends PanelContainer

const MIN_TOUCH_HEIGHT: float = 44.0
const BASE_HEIGHT: float = 48.0
const MIN_UI_SCALE: float = 0.85
const MAX_UI_SCALE: float = 1.25
const MAX_LABEL_CHARS: int = 64
const MAX_VALUE_CHARS: int = 160
const MAX_KIND_CHARS: int = 32
const PANEL_ALT: Color = Color(0.055, 0.105, 0.105, 0.92)
const TEAL: Color = Color("4eb6aa")
const AMBER: Color = Color("f5a62d")
const TEXT: Color = Color("f4ecd8")
const MUTED: Color = Color("9eb1aa")

var _label_node: Label
var _value_node: Label
var _kind_node: Label
var _kind: StringName = &""
var _ui_scale: float = 1.0


func _init() -> void:
	_build()
	reset()


func apply_presentation(presentation: Dictionary) -> void:
	set_fact(
		str(presentation.get(&"label", "")),
		str(presentation.get(&"value", "")),
		StringName(str(presentation.get(&"kind", ""))),
	)


func set_fact(label_text: String, value_text: String, kind: StringName = &"") -> void:
	_label_node.text = _bounded(label_text, MAX_LABEL_CHARS)
	_value_node.text = _bounded(value_text, MAX_VALUE_CHARS)
	_kind = StringName(_bounded(str(kind), MAX_KIND_CHARS))
	_kind_node.text = str(_kind).replace("_", " ").to_upper()
	_kind_node.visible = not _kind_node.text.is_empty()
	tooltip_text = "%s — %s" % [_label_node.text, _value_node.text]
	accessibility_name = "%s, %s" % [_label_node.text, _value_node.text]


func set_ui_scale(value: float) -> void:
	_ui_scale = clampf(value, MIN_UI_SCALE, MAX_UI_SCALE)
	custom_minimum_size.y = maxf(MIN_TOUCH_HEIGHT, BASE_HEIGHT * _ui_scale)
	_label_node.add_theme_font_size_override("font_size", roundi(12.0 * _ui_scale))
	_value_node.add_theme_font_size_override("font_size", roundi(13.0 * _ui_scale))
	_kind_node.add_theme_font_size_override("font_size", roundi(10.0 * _ui_scale))


func reset() -> void:
	set_ui_scale(1.0)
	set_fact("", "", &"")
	visible = false


func presentation_snapshot() -> Dictionary:
	return {
		&"label": _label_node.text,
		&"value": _value_node.text,
		&"kind": _kind,
		&"minimum_height": custom_minimum_size.y,
	}


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _style())
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	_label_node = _new_label("Label", MUTED)
	_label_node.custom_minimum_size.x = 88.0
	_label_node.size_flags_stretch_ratio = 0.4
	row.add_child(_label_node)
	_value_node = _new_label("Value", TEXT)
	_value_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_node.size_flags_stretch_ratio = 0.6
	row.add_child(_value_node)
	_kind_node = _new_label("Kind", AMBER)
	_kind_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kind_node.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(_kind_node)


func _new_label(node_name: String, color: Color) -> Label:
	var result := Label.new()
	result.name = node_name
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	result.add_theme_color_override("font_color", color)
	return result


func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_ALT
	style.border_color = Color(TEAL, 0.46)
	style.border_width_left = 2
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_left = 2
	return style


func _bounded(value: String, maximum: int) -> String:
	var clean: String = value.strip_edges().replace("\n", " ").replace("\r", " ")
	return clean if clean.length() <= maximum else clean.left(maximum - 1) + "…"
