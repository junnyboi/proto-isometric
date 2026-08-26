extends CanvasLayer

signal action_requested(action: StringName)

const CatalogScript: GDScript = preload("res://scripts/construction_blueprint_catalog.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const ICON: Texture2D = preload(
	"res://assets/settlement/construction/icon_build_blueprint.png"
)
const ROTATE_ICON: Texture2D = preload(
	"res://assets/settlement/construction/icon_rotate_building.png"
)

const ACTIONS: Array[StringName] = [
	&"move_up", &"move_left", &"move_right", &"move_down",
	&"previous", &"next", &"rotate", &"confirm", &"cancel",
]

var _root: Control
var _panel: PanelContainer
var _title: Label
var _purpose: Label
var _bill: Label
var _status: Label
var _icon: TextureRect
var _buttons: Dictionary = {}
var _snapshot: Dictionary = {}
var _ui_scale: float = 1.0


func _ready() -> void:
	layer = 48
	_build_interface()
	get_viewport().size_changed.connect(_apply_layout)
	visible = false


func present(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_refresh()
	visible = true
	_apply_layout()
	var confirm: Button = _buttons.get(&"confirm") as Button
	if confirm != null:
		confirm.grab_focus()


func dismiss() -> void:
	visible = false
	_snapshot.clear()


func is_open() -> bool:
	return visible and not _snapshot.is_empty()


func panel_bounds() -> Rect2:
	return Rect2(_panel.position, _panel.size) if _panel != null and visible else Rect2()


func apply_preferences(snapshot: Dictionary) -> void:
	_ui_scale = clampf(float(snapshot.get(&"ui_scale", 1.0)), 0.85, 1.25)
	_apply_layout()


func _refresh() -> void:
	var blueprint_id: StringName = _snapshot.get(&"blueprint_id", &"") as StringName
	var definition: Dictionary = CatalogScript.definition(blueprint_id)
	if definition.is_empty():
		return
	_title.text = LocalizationScript.t(definition[&"label_key"] as StringName)
	_purpose.text = LocalizationScript.t(definition[&"purpose_key"] as StringName)
	_bill.text = _bill_text(CatalogScript.bill(blueprint_id))
	var valid: bool = bool(_snapshot.get(&"valid", false))
	var reason: StringName = _snapshot.get(&"reason", &"") as StringName
	_status.text = (
		LocalizationScript.t(&"construction.status.valid")
		if valid
		else LocalizationScript.t(StringName("construction.reason.%s" % str(reason)))
	)
	_status.add_theme_color_override(
		"font_color", Color("75ead2") if valid else Color("ff8f87")
	)
	var confirm: Button = _buttons.get(&"confirm") as Button
	if confirm != null:
		confirm.disabled = not valid


func _bill_text(bill: Dictionary) -> String:
	var parts: Array[String] = []
	var ids: Array[String] = []
	for value: Variant in bill:
		ids.append(str(value))
	ids.sort()
	for raw_id: String in ids:
		parts.append("%s ×%d" % [_item_label(StringName(raw_id)), int(bill[StringName(raw_id)])])
	return "%s: %s" % [LocalizationScript.t(&"construction.materials"), ", ".join(parts)]


func _item_label(item_id: StringName) -> String:
	match item_id:
		&"item.material.wood":
			return LocalizationScript.t(&"construction.material.wood")
		&"item.material.stone":
			return LocalizationScript.t(&"construction.material.stone")
		&"item.material.scrap":
			return LocalizationScript.t(&"construction.material.scrap")
	return str(item_id)


func _build_interface() -> void:
	_root = Control.new()
	_root.name = "ConstructionModeRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.name = "ConstructionModePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.055, 0.06, 0.96)
	panel_style.border_color = Color("4da99e")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(5)
	panel_style.set_content_margin_all(10.0)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(_panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_panel.add_child(content)
	var heading: HBoxContainer = HBoxContainer.new()
	content.add_child(heading)
	_icon = TextureRect.new()
	_icon.texture = ICON
	_icon.custom_minimum_size = Vector2(48.0, 48.0)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heading.add_child(_icon)
	_title = _label(18, Color("fff2cc"))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_title)
	_purpose = _label(13, Color("c2d9d3"))
	_purpose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_purpose)
	_bill = _label(13, Color("f3d39a"))
	_bill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_bill)
	_status = _label(13, Color("75ead2"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)
	var directions: GridContainer = GridContainer.new()
	directions.columns = 5
	content.add_child(directions)
	_add_button(directions, &"move_up", "↑")
	_add_button(directions, &"move_left", "←")
	_add_button(directions, &"rotate", LocalizationScript.t(&"construction.rotate"))
	_add_button(directions, &"move_right", "→")
	_add_button(directions, &"move_down", "↓")
	var actions: GridContainer = GridContainer.new()
	actions.columns = 4
	content.add_child(actions)
	_add_button(actions, &"previous", LocalizationScript.t(&"construction.previous"))
	_add_button(actions, &"next", LocalizationScript.t(&"construction.next"))
	_add_button(actions, &"confirm", LocalizationScript.t(&"construction.confirm"))
	_add_button(actions, &"cancel", LocalizationScript.t(&"construction.cancel"))


func _add_button(parent: Container, action: StringName, text: String) -> void:
	var button: Button = Button.new()
	button.name = "%sButton" % String(action).to_pascal_case()
	button.text = text
	if action == &"rotate":
		button.icon = ROTATE_ICON
		button.expand_icon = true
	button.custom_minimum_size = Vector2(44.0 if str(action).begins_with("move_") else 66.0, 44.0)
	button.pressed.connect(func() -> void: action_requested.emit(action))
	parent.add_child(button)
	_buttons[action] = button


func _add_spacer(parent: Container) -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(66.0, 44.0)
	parent.add_child(spacer)


func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _apply_layout() -> void:
	if _panel == null:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var bounds: Rect2 = _layout_for(viewport, _ui_scale)
	_panel.position = bounds.position
	_panel.size = bounds.size
	_apply_compact_labels(viewport.x < 900.0 or viewport.y < 500.0)


func _apply_compact_labels(compact: bool) -> void:
	var labels: Dictionary = {
		&"previous": "‹" if compact else LocalizationScript.t(&"construction.previous"),
		&"next": "›" if compact else LocalizationScript.t(&"construction.next"),
		&"confirm": "✓" if compact else LocalizationScript.t(&"construction.confirm"),
		&"cancel": "×" if compact else LocalizationScript.t(&"construction.cancel"),
	}
	for action: StringName in labels:
		var button: Button = _buttons.get(action) as Button
		if button != null:
			button.text = labels[action]
			button.tooltip_text = LocalizationScript.t(
				StringName("construction.%s" % str(action))
			)


static func _layout_for(viewport: Vector2, scale: float) -> Rect2:
	var portrait: bool = viewport.y > viewport.x
	var margin: float = 12.0
	var width: float = minf(viewport.x - margin * 2.0, 360.0 * scale)
	var height: float = minf(
		viewport.y - margin * 2.0, (374.0 if portrait else 350.0) * scale
	)
	var position: Vector2 = (
		Vector2((viewport.x - width) * 0.5, viewport.y - height - margin)
		if portrait
		else Vector2(viewport.x - width - margin, (viewport.y - height) * 0.5)
	)
	return Rect2(position, Vector2(width, height))
