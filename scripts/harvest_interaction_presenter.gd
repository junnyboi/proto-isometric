extends CanvasLayer

const CommandsScript: GDScript = preload("res://scripts/harvest_command_intents.gd")
const ExecutionResultScript: GDScript = preload("res://scripts/interaction_execution_result.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")

const CHARCOAL: Color = Color("10181b")
const PANEL: Color = Color(0.035, 0.065, 0.07, 0.97)
const PANEL_ALT: Color = Color(0.055, 0.105, 0.105, 0.98)
const TEAL: Color = Color("4eb6aa")
const AMBER: Color = Color("f5a62d")
const TEXT: Color = Color("f4ecd8")
const MUTED: Color = Color("9eb1aa")
const DISABLED: Color = Color("7d8580")
const MAX_VISIBLE_COSTS: int = 3
const SAFE_INSET: float = 18.0
const MIN_WIDTH: float = 320.0
const MAX_WIDTH: float = 438.0
const HEADER_HEIGHT: float = 116.0
const FOOTER_HEIGHT: float = 38.0
const BASE_ROW_HEIGHT: float = 66.0
const VIEW_ACTIONS: StringName = &"actions"
const VIEW_DETAILS: StringName = &"details"

var _controller: Node
var _mobile_controls: CanvasLayer
var _root: Control
var _veil: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _subkind_label: Label
var _status_label: Label
var _tab_bar: HBoxContainer
var _details_tab: Button
var _actions_tab: Button
var _detail_panel: PanelContainer
var _detail_title_label: Label
var _detail_body_label: Label
var _detail_scroll: ScrollContainer
var _detail_stack: VBoxContainer
var _scroll: ScrollContainer
var _row_stack: VBoxContainer
var _touch_bar: HBoxContainer
var _back_button: Button
var _activate_button: Button
var _footer_label: Label
var _rows: Array[Button] = []
var _fact_rows: Array[Label] = []
var _snapshot: Dictionary = {}
var _detail_result: Dictionary = {}
var _layout: Dictionary = {}
var _selected_action_id: StringName = &""
var _ui_scale: float = 1.0
var _left_handed: bool = false
var _last_result_key: StringName = &""
var _active_view: StringName = VIEW_ACTIONS
var _last_activation_usec: int = 0


func _ready() -> void:
	layer = 24
	name = "HarvestInteractionPresenter"
	CommandsScript.install_defaults()
	_build_interface()
	add_to_group("localization_listeners")
	get_viewport().size_changed.connect(_on_viewport_resized)
	apply_preferences(
		(PlayerPreferencesScript.new() as RefCounted).call("load_preferences") as Dictionary
	)
	call_deferred("_bind_accessibility")
	set_process_input(true)


func bind(controller: Node, mobile_controls: CanvasLayer = null) -> bool:
	if controller == null:
		return false
	_controller = controller
	_mobile_controls = mobile_controls
	controller.connect("menu_snapshot_opened", _on_snapshot_opened)
	controller.connect("menu_snapshot_refreshed", _on_snapshot_refreshed)
	controller.connect("menu_snapshot_closed", _on_snapshot_closed)
	controller.connect("menu_selection_changed", _on_selection_changed)
	controller.connect("menu_execution_result", _on_execution_result)
	if bool(controller.call("is_menu_open")):
		_on_snapshot_opened(controller.call("get_menu_snapshot") as Dictionary)
	return true


func is_open() -> bool:
	return _panel != null and _panel.visible and MenuScript.validate(_snapshot)


func get_popup_bounds() -> Rect2:
	return _layout.get(&"popup", Rect2()) as Rect2


func get_layout_snapshot() -> Dictionary:
	return _layout.duplicate(true)


func get_pool_size() -> int:
	return _rows.size()


func get_visible_row_count() -> int:
	var count: int = 0
	for row: Button in _rows:
		if row.visible:
			count += 1
	return count


func get_fact_pool_size() -> int:
	return _fact_rows.size()


func get_visible_fact_count() -> int:
	var count: int = 0
	for row: Label in _fact_rows:
		if row.visible:
			count += 1
	return count


func get_selected_action_id() -> StringName:
	return _selected_action_id


func get_active_view() -> StringName:
	return _active_view


func has_terminal_controls() -> bool:
	return (
		_back_button != null
		and _activate_button != null
		and _back_button.custom_minimum_size.y >= 44.0
		and _activate_button.custom_minimum_size.y >= 44.0
	)


func apply_preferences(snapshot: Dictionary) -> void:
	_ui_scale = clampf(float(snapshot.get(&"ui_scale", 1.0)), 0.85, 1.25)
	_left_handed = bool(snapshot.get(&"left_handed", false))
	_apply_layout(get_viewport().get_visible_rect().size)


func handle_modal_event(event: InputEvent) -> bool:
	if _controller == null or event == null:
		return false
	if not bool(_controller.call("is_menu_open")):
		return (
			bool(_controller.call("open_menu"))
			if event.is_action_pressed(CommandsScript.CONTEXT, false, true)
			else false
		)
	var handled: bool = true
	if _is_pointer_press(event):
		var position: Vector2 = _pointer_position(event)
		if not get_popup_bounds().has_point(position):
			_controller.call("close_menu")
		else:
			return false
	elif event.is_action_pressed(CommandsScript.CANCEL, false, true) or event.is_action_pressed(
		"ui_cancel", false, true
	):
		_handle_back()
	elif _is_compact_layout() and event.is_action_pressed("ui_left", false, true):
		_set_active_view(VIEW_DETAILS)
	elif _is_compact_layout() and event.is_action_pressed("ui_right", false, true):
		_set_active_view(VIEW_ACTIONS)
	elif _is_up(event):
		_controller.call("navigate_menu", -1)
	elif _is_down(event):
		_controller.call("navigate_menu", 1)
	elif _is_confirm(event):
		_controller.call("confirm_menu")
	else:
		handled = _is_modal_action(event)
	return handled


func _is_modal_action(event: InputEvent) -> bool:
	for action: StringName in CommandsScript.action_ids():
		if event.is_action_pressed(action, false, true):
			return true
	return event is InputEventKey or event is InputEventJoypadButton


static func layout_for(
	viewport_size: Vector2,
	left_handed: bool = false,
	ui_scale: float = 1.0,
	mobile: bool = false,
	row_count: int = OptionScript.MAX_OPTIONS,
) -> Dictionary:
	var viewport: Vector2 = Vector2(maxf(viewport_size.x, 320.0), maxf(viewport_size.y, 320.0))
	var inset: float = minf(SAFE_INSET, minf(viewport.x, viewport.y) * 0.08)
	var safe: Rect2 = Rect2(Vector2.ONE * inset, viewport - Vector2.ONE * inset * 2.0)
	var scale_value: float = clampf(ui_scale, 0.85, 1.25)
	var desired_width: float = clampf(viewport.x * 0.37, MIN_WIDTH, MAX_WIDTH) * scale_value
	var width: float = minf(desired_width, safe.size.x)
	var x: float = safe.position.x
	if mobile and left_handed:
		x = safe.end.x - width
	var bottom_clearance: float = 0.0
	if viewport.y > viewport.x:
		bottom_clearance = minf(96.0 * scale_value, safe.size.y * 0.24)
	var popup: Rect2 = Rect2(
		Vector2(x, safe.position.y), Vector2(width, safe.size.y - bottom_clearance)
	)
	var header: float = minf(HEADER_HEIGHT * scale_value, popup.size.y * 0.38)
	var footer: float = minf(FOOTER_HEIGHT * scale_value, popup.size.y * 0.16)
	var row_viewport: Rect2 = Rect2(
		popup.position + Vector2(0.0, header),
		Vector2(popup.size.x, maxf(popup.size.y - header - footer, 48.0)),
	)
	var row_height: float = BASE_ROW_HEIGHT * scale_value
	return {
		&"viewport": viewport,
		&"safe_bounds": safe,
		&"popup": popup,
		&"row_viewport": row_viewport,
		&"row_height": row_height,
		&"scroll_required": max(row_count, 0) * row_height > row_viewport.size.y,
		&"left_handed": left_handed,
		&"ui_scale": scale_value,
		&"mobile": mobile,
	}


static func validate_layout(layout: Dictionary) -> bool:
	for key: StringName in [
		&"viewport", &"safe_bounds", &"popup", &"row_viewport", &"row_height", &"scroll_required"
	]:
		if not layout.has(key):
			return false
	var safe: Rect2 = layout[&"safe_bounds"] as Rect2
	var popup: Rect2 = layout[&"popup"] as Rect2
	var rows: Rect2 = layout[&"row_viewport"] as Rect2
	return (
		safe.encloses(popup)
		and popup.encloses(rows)
		and rows.size.y > 0.0
		and float(layout[&"row_height"]) >= 44.0
	)


func _input(event: InputEvent) -> void:
	if handle_modal_event(event):
		get_viewport().set_input_as_handled()


func _on_snapshot_opened(snapshot: Dictionary) -> void:
	if not MenuScript.validate(snapshot):
		return
	_snapshot = snapshot.duplicate(true)
	_detail_result.clear()
	_last_result_key = &""
	_active_view = VIEW_ACTIONS
	_panel.visible = true
	_veil.visible = true
	_apply_layout(get_viewport().get_visible_rect().size)
	_refresh_snapshot()
	_refresh_details()
	_set_mobile_modal(true)


func _on_snapshot_refreshed(snapshot: Dictionary) -> void:
	if not MenuScript.validate(snapshot):
		return
	_snapshot = snapshot.duplicate(true)
	_detail_result.clear()
	_refresh_snapshot()
	_refresh_details()


func _on_snapshot_closed() -> void:
	_snapshot.clear()
	_detail_result.clear()
	_selected_action_id = &""
	_active_view = VIEW_ACTIONS
	_panel.visible = false
	_veil.visible = false
	_refresh_details()
	_set_mobile_modal(false)


func _on_selection_changed(_index: int, action_id: StringName) -> void:
	_selected_action_id = action_id
	_refresh_selection()


func _on_execution_result(result: Dictionary) -> void:
	if ExecutionResultScript.validate(result):
		_detail_result = result.duplicate(true)
		_last_result_key = result[&"reason_key"] as StringName
		if _is_compact_layout():
			_active_view = VIEW_DETAILS
	else:
		_detail_result.clear()
		_last_result_key = result.get(&"reason_key", result.get(&"reason", &"")) as StringName
	if is_open():
		_refresh_details()
		_refresh_status()


func _refresh_snapshot() -> void:
	if not MenuScript.validate(_snapshot):
		return
	var title_key: StringName = _snapshot[&"target_title_key"] as StringName
	_title_label.text = _localized(title_key, _humanize(_snapshot[&"target_subkind"]))
	var subkind: StringName = _snapshot[&"target_subkind"] as StringName
	_subkind_label.text = LocalizationScript.t(
		&"interaction.menu.target_subkind",
		{"subkind": _localized(StringName("interaction.subkind.%s" % subkind), _humanize(subkind))},
	)
	var options: Array = _snapshot[&"options"] as Array
	_ensure_row_pool(options.size())
	for index: int in _rows.size():
		var row: Button = _rows[index]
		row.visible = index < options.size()
		if row.visible:
			_apply_option_to_row(row, options[index] as Dictionary, index)
	_selected_action_id = _controller.call("get_selected_action_id") as StringName
	_refresh_status()
	_refresh_selection()


func _refresh_status() -> void:
	if _status_label == null:
		return
	if _last_result_key != &"":
		_status_label.text = LocalizationScript.t(
			&"interaction.menu.result", {"result": _localized(_last_result_key, _humanize(_last_result_key))}
		)
	elif not _detail_result.is_empty():
		_status_label.text = LocalizationScript.t(&"interaction.menu.status_inspected")
	else:
		_status_label.text = LocalizationScript.t(&"interaction.menu.status_ready")
	_footer_label.text = LocalizationScript.t(&"interaction.menu.bindings")
	_refresh_terminal_labels()


func _refresh_details() -> void:
	if _detail_panel == null:
		return
	var view: Dictionary = _detail_result.get(&"view", {}) as Dictionary
	if not ExecutionResultScript.validate_view(view):
		_detail_panel.visible = false
		for row: Label in _fact_rows:
			row.visible = false
		_active_view = VIEW_ACTIONS
		_apply_view_visibility()
		return
	_detail_panel.visible = true
	_detail_title_label.text = _localized(
		view[&"title_key"] as StringName,
		LocalizationScript.t(&"interaction.inspect.generic.title"),
	)
	_detail_body_label.text = LocalizationScript.t(
		view[&"body_key"] as StringName,
		_localized_parameters(view[&"parameters"] as Dictionary),
	)
	var facts: Array = view[&"facts"] as Array
	for index: int in _fact_rows.size():
		var row: Label = _fact_rows[index]
		row.visible = index < facts.size()
		if not row.visible:
			continue
		var fact: Dictionary = facts[index] as Dictionary
		var label: String = _localized(
			fact[&"label_key"] as StringName,
			LocalizationScript.t(&"interaction.inspect.fact.unknown"),
		)
		var value_text: String = _fact_value_text(fact)
		row.text = "%s  //  %s" % [label, value_text]
		row.accessibility_name = "%s, %s" % [label, value_text]
	_apply_view_visibility()
	_update_detail_minimum_size()


func _localized_parameters(parameters: Dictionary) -> Dictionary:
	var result: Dictionary = parameters.duplicate(true)
	for key: Variant in result.keys():
		if str(key).ends_with("_key") and result[key] is StringName:
			result[key] = _localized(
				result[key] as StringName,
				LocalizationScript.t(&"interaction.inspect.next.none"),
			)
	return result


func _fact_value_text(fact: Dictionary) -> String:
	var kind: StringName = fact[&"value_kind"] as StringName
	var value: Variant = fact[&"value"]
	match kind:
		ExecutionResultScript.VALUE_TEXT_KEY:
			return _localized(
				value as StringName,
				LocalizationScript.t(&"interaction.value.unknown"),
			)
		ExecutionResultScript.VALUE_BOOLEAN:
			return LocalizationScript.t(
				&"interaction.value.boolean.true"
				if bool(value)
				else &"interaction.value.boolean.false"
			)
		ExecutionResultScript.VALUE_INTEGER:
			return str(int(value))
		ExecutionResultScript.VALUE_DECIMAL:
			return String.num(float(value), 2)
	return LocalizationScript.t(&"interaction.value.unknown")


func _refresh_selection() -> void:
	if _controller == null:
		return
	var selected: int = int(_controller.call("get_selected_menu_index"))
	for index: int in _rows.size():
		var row: Button = _rows[index]
		if not row.visible:
			continue
		var enabled: bool = bool(row.get_meta("option_enabled", false))
		row.add_theme_stylebox_override(
			"normal", _row_style(index == selected, enabled, false)
		)
		row.add_theme_color_override("font_color", TEXT if enabled else DISABLED)
		row.add_theme_color_override("font_hover_color", TEXT if enabled else DISABLED)
		if index == selected:
			row.grab_focus()
			_scroll.ensure_control_visible(row)


func _ensure_row_pool(count: int) -> void:
	while _rows.size() < mini(count, OptionScript.MAX_OPTIONS):
		var row: Button = Button.new()
		var index: int = _rows.size()
		row.name = "ActionRow%02d" % index
		row.focus_mode = Control.FOCUS_ALL
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_theme_font_size_override("font_size", 14)
		row.add_theme_stylebox_override("hover", _row_style(false, true, true))
		row.add_theme_stylebox_override("pressed", _row_style(true, true, true))
		row.pressed.connect(_on_row_pressed.bind(index))
		_row_stack.add_child(row)
		_rows.append(row)


func _apply_option_to_row(row: Button, option: Dictionary, index: int) -> void:
	var enabled: bool = bool(option[&"enabled"])
	var label_key: StringName = option[&"label_key"] as StringName
	var label: String = _localized(label_key, _fallback_action_label(option[&"action_id"]))
	var detail: String = _cost_text(option[&"cost_preview"] as Array)
	if not enabled:
		var reason_key: StringName = option[&"reason_key"] as StringName
		detail = LocalizationScript.t(
			&"interaction.menu.disabled", {"reason": _localized(reason_key, _humanize(reason_key))}
		)
	if detail.is_empty():
		detail = LocalizationScript.t(&"interaction.menu.no_cost")
	row.custom_minimum_size = Vector2(0.0, float(_layout[&"row_height"]))
	row.text = "%02d  %s  %s\n      %s" % [index + 1, _glyph_for(option), label, detail]
	row.tooltip_text = "%s — %s" % [label, detail]
	row.set_meta("option_enabled", enabled)
	row.set_meta("action_id", option[&"action_id"])
	row.accessibility_name = row.text.replace("\n", " ")


func _on_row_pressed(index: int) -> void:
	if _controller == null or index < 0 or index >= _rows.size():
		return
	var selected: int = int(_controller.call("get_selected_menu_index"))
	if index != selected:
		_controller.call("select_menu_index", index)
		return
	if bool(_rows[index].get_meta("option_enabled", false)):
		_controller.call("confirm_menu")


func _cost_text(costs: Array) -> String:
	if costs.is_empty():
		return ""
	var pieces: PackedStringArray = []
	for index: int in mini(costs.size(), MAX_VISIBLE_COSTS):
		var cost: Dictionary = costs[index] as Dictionary
		var cost_id: StringName = cost[&"cost_id"] as StringName
		pieces.append(
			LocalizationScript.t(
				&"interaction.menu.cost_entry",
				{
					"amount": int(cost[&"amount"]),
					"name": _localized(cost_id, _humanize(cost_id)),
				},
			)
		)
	if costs.size() > MAX_VISIBLE_COSTS:
		pieces.append("+%d" % (costs.size() - MAX_VISIBLE_COSTS))
	return LocalizationScript.t(&"interaction.menu.cost", {"cost": " · ".join(pieces)})


func _localized(key: StringName, fallback: String) -> String:
	if key != &"" and LocalizationScript.has_key(LocalizationScript.get_locale(), key):
		return LocalizationScript.t(key)
	return fallback


func _fallback_action_label(action_id: Variant) -> String:
	var text: String = str(action_id).trim_prefix("interaction.action.").trim_suffix(".label")
	var segments: PackedStringArray = text.split(".")
	if segments.is_empty():
		return LocalizationScript.t(&"interaction.action.unavailable.label")
	var verb: String = segments[0].replace("_", " ").capitalize()
	if segments.size() == 1:
		return verb
	return "%s — %s" % [verb, _humanize(segments[segments.size() - 1])]


func _humanize(value: Variant) -> String:
	var text: String = str(value)
	var parts: PackedStringArray = text.split(".")
	text = parts[parts.size() - 1] if not parts.is_empty() else text
	return text.replace("_", " ").replace("-", " ").capitalize()


func _glyph_for(option: Dictionary) -> String:
	var action: String = str(option[&"action_id"])
	if not bool(option[&"enabled"]):
		return "×"
	if action.contains("inspect") or action.contains("review") or action.contains("progress"):
		return "◇"
	if action.contains("plant") or action.contains("water") or action.contains("harvest"):
		return "◆"
	if action.contains("chop") or action.contains("mine") or action.contains("break"):
		return "▰"
	if action.contains("talk") or action.contains("relationship") or action.contains("gift"):
		return "◎"
	return "▸"


func _apply_layout(viewport_size: Vector2) -> void:
	if _panel == null:
		return
	var mobile: bool = _mobile_controls != null and bool(_mobile_controls.call("is_mobile_device"))
	var row_count: int = int((_snapshot.get(&"options", []) as Array).size())
	_layout = layout_for(viewport_size, _left_handed, _ui_scale, mobile, row_count)
	if not validate_layout(_layout):
		return
	var popup: Rect2 = _layout[&"popup"] as Rect2
	_panel.position = popup.position
	_panel.size = popup.size
	var rows: Rect2 = _layout[&"row_viewport"] as Rect2
	_scroll.custom_minimum_size = Vector2(0.0, minf(rows.size.y, 48.0))
	_apply_view_visibility()
	_title_label.add_theme_font_size_override("font_size", roundi(24.0 * _ui_scale))
	_subkind_label.add_theme_font_size_override("font_size", roundi(12.0 * _ui_scale))
	_status_label.add_theme_font_size_override("font_size", roundi(12.0 * _ui_scale))
	_detail_title_label.add_theme_font_size_override("font_size", roundi(15.0 * _ui_scale))
	_detail_body_label.add_theme_font_size_override("font_size", roundi(12.0 * _ui_scale))
	_footer_label.add_theme_font_size_override("font_size", roundi(11.0 * _ui_scale))
	_update_detail_minimum_size()
	for button: Button in [_details_tab, _actions_tab, _back_button, _activate_button]:
		button.add_theme_font_size_override("font_size", roundi(13.0 * _ui_scale))
	for fact_row: Label in _fact_rows:
		fact_row.add_theme_font_size_override("font_size", roundi(12.0 * _ui_scale))
	for row: Button in _rows:
		row.custom_minimum_size.y = float(_layout[&"row_height"])
		row.add_theme_font_size_override("font_size", roundi(14.0 * _ui_scale))
	if is_open():
		_set_mobile_modal(true)


func _update_detail_minimum_size() -> void:
	if _detail_panel == null or not validate_layout(_layout):
		return
	var popup: Rect2 = _layout[&"popup"] as Rect2
	var detail_share: float = 0.62 if _is_compact_layout() else 0.4
	_detail_panel.custom_minimum_size.y = (
		minf(360.0 * _ui_scale, popup.size.y * detail_share)
		if _detail_panel.visible
		else 0.0
	)


func _build_interface() -> void:
	_root = Control.new()
	_root.name = "InteractionTerminalRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_veil = ColorRect.new()
	_veil.name = "ModalVeil"
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.01, 0.025, 0.025, 0.14)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.visible = false
	_root.add_child(_veil)
	_panel = PanelContainer.new()
	_panel.name = "InteractionTerminal"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(_panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	_panel.add_child(stack)
	var accent: HBoxContainer = HBoxContainer.new()
	accent.custom_minimum_size.y = 5.0
	accent.add_theme_constant_override("separation", 4)
	stack.add_child(accent)
	var teal_bar: ColorRect = ColorRect.new()
	teal_bar.color = TEAL
	teal_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accent.add_child(teal_bar)
	var amber_bar: ColorRect = ColorRect.new()
	amber_bar.color = AMBER
	amber_bar.custom_minimum_size.x = 76.0
	accent.add_child(amber_bar)
	_subkind_label = _label(12, AMBER)
	stack.add_child(_subkind_label)
	_title_label = _label(24, TEXT)
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(_title_label)
	_status_label = _label(12, TEAL)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_status_label)
	_tab_bar = HBoxContainer.new()
	_tab_bar.name = "CompactViewTabs"
	_tab_bar.add_theme_constant_override("separation", 6)
	stack.add_child(_tab_bar)
	_details_tab = _terminal_button("DetailsTab", &"interaction.menu.tab.details")
	_details_tab.toggle_mode = true
	_details_tab.pressed.connect(_set_active_view.bind(VIEW_DETAILS))
	_tab_bar.add_child(_details_tab)
	_actions_tab = _terminal_button("ActionsTab", &"interaction.menu.tab.actions")
	_actions_tab.toggle_mode = true
	_actions_tab.pressed.connect(_set_active_view.bind(VIEW_ACTIONS))
	_tab_bar.add_child(_actions_tab)
	_detail_panel = PanelContainer.new()
	_detail_panel.name = "DecisionCard"
	_detail_panel.visible = false
	_detail_panel.add_theme_stylebox_override("panel", _detail_style())
	stack.add_child(_detail_panel)
	var detail_layout: VBoxContainer = VBoxContainer.new()
	detail_layout.add_theme_constant_override("separation", 4)
	_detail_panel.add_child(detail_layout)
	_detail_title_label = _label(15, AMBER)
	_detail_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_layout.add_child(_detail_title_label)
	_detail_body_label = _label(12, TEXT)
	_detail_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_layout.add_child(_detail_body_label)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "BoundedDetailScroll"
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	detail_layout.add_child(_detail_scroll)
	_detail_stack = VBoxContainer.new()
	_detail_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_stack.add_theme_constant_override("separation", 3)
	_detail_scroll.add_child(_detail_stack)
	for index: int in ExecutionResultScript.MAX_FACTS:
		var fact_row: Label = _label(12, MUTED)
		fact_row.name = "DecisionFact%02d" % index
		fact_row.visible = false
		fact_row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fact_row.custom_minimum_size.y = 24.0
		_detail_stack.add_child(fact_row)
		_fact_rows.append(fact_row)
	var divider: HSeparator = HSeparator.new()
	divider.add_theme_constant_override("separation", 2)
	stack.add_child(divider)
	_scroll = ScrollContainer.new()
	_scroll.name = "BoundedActionScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	stack.add_child(_scroll)
	_row_stack = VBoxContainer.new()
	_row_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row_stack.add_theme_constant_override("separation", 5)
	_scroll.add_child(_row_stack)
	_touch_bar = HBoxContainer.new()
	_touch_bar.name = "TerminalControls"
	_touch_bar.add_theme_constant_override("separation", 6)
	stack.add_child(_touch_bar)
	_back_button = _terminal_button("BackButton", &"interaction.menu.back")
	_back_button.pressed.connect(_handle_back)
	_touch_bar.add_child(_back_button)
	_activate_button = _terminal_button("ActivateButton", &"interaction.menu.activate")
	_activate_button.pressed.connect(_activate_selected)
	_touch_bar.add_child(_activate_button)
	_footer_label = _label(11, MUTED)
	_footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_footer_label)


func _terminal_button(control_name: String, label_key: StringName) -> Button:
	var button: Button = Button.new()
	button.name = control_name
	button.text = LocalizationScript.t(label_key)
	button.set_meta("label_key", label_key)
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_disabled_color", DISABLED)
	button.add_theme_stylebox_override("normal", _row_style(false, true, false))
	button.add_theme_stylebox_override("hover", _row_style(false, true, true))
	button.add_theme_stylebox_override("pressed", _row_style(true, true, true))
	return button


func _refresh_terminal_labels() -> void:
	for button: Button in [_details_tab, _actions_tab, _back_button, _activate_button]:
		if button != null:
			button.text = LocalizationScript.t(button.get_meta("label_key") as StringName)


func _set_active_view(view: StringName) -> void:
	if view not in [VIEW_ACTIONS, VIEW_DETAILS]:
		return
	if view == VIEW_DETAILS and _detail_result.is_empty():
		return
	_active_view = view
	_apply_view_visibility()
	_apply_layout(get_viewport().get_visible_rect().size)


func _handle_back() -> void:
	if _controller == null:
		return
	if _is_compact_layout() and _active_view == VIEW_DETAILS:
		_set_active_view(VIEW_ACTIONS)
	else:
		_controller.call("close_menu")


func _activate_selected() -> void:
	var now: int = Time.get_ticks_usec()
	if now - _last_activation_usec < 150_000:
		return
	_last_activation_usec = now
	if _controller != null and bool(_controller.call("is_menu_open")):
		_controller.call("confirm_menu")


func _is_compact_layout() -> bool:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var mobile: bool = _mobile_controls != null and bool(_mobile_controls.call("is_mobile_device"))
	return mobile or viewport.y > viewport.x or viewport.x < 700.0 or viewport.y < 500.0


func _apply_view_visibility() -> void:
	if _detail_panel == null or _scroll == null or _tab_bar == null:
		return
	var has_details: bool = ExecutionResultScript.validate_view(
		_detail_result.get(&"view", {}) as Dictionary
	)
	var compact: bool = _is_compact_layout()
	_tab_bar.visible = compact
	_details_tab.disabled = not has_details
	if compact:
		_detail_panel.visible = has_details and _active_view == VIEW_DETAILS
		_scroll.visible = _active_view == VIEW_ACTIONS
	else:
		_detail_panel.visible = has_details
		_scroll.visible = true
	_details_tab.button_pressed = compact and _active_view == VIEW_DETAILS
	_actions_tab.button_pressed = compact and _active_view == VIEW_ACTIONS


func _detail_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(PANEL_ALT, 0.92)
	style.border_color = Color(AMBER, 0.72)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style


func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = Color(TEAL, 0.9)
	style.set_border_width_all(2)
	style.border_width_left = 5
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 1
	style.content_margin_left = 15.0
	style.content_margin_top = 12.0
	style.content_margin_right = 15.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 12
	return style


func _row_style(selected: bool, enabled: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_ALT if enabled else Color(CHARCOAL, 0.86)
	if hovered and enabled:
		style.bg_color = Color(TEAL, 0.25)
	style.border_color = AMBER if selected else Color(TEAL if enabled else DISABLED, 0.5)
	style.border_width_left = 5 if selected else 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_left = 2
	style.content_margin_left = 11.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _set_mobile_modal(active: bool) -> void:
	if _mobile_controls == null:
		return
	_mobile_controls.call("_set_modal_input_suppressed", active)
	_mobile_controls.call("_set_modal_touch_exclusion", get_popup_bounds(), active)


func _bind_accessibility() -> void:
	var panel: Node = get_tree().get_first_node_in_group("accessibility_panel")
	if panel != null and panel.has_signal("preferences_changed"):
		panel.connect("preferences_changed", apply_preferences)


func _on_viewport_resized() -> void:
	_apply_layout(get_viewport().get_visible_rect().size)


func _on_locale_changed(_locale: StringName) -> void:
	var selected: StringName = _selected_action_id
	if is_open():
		_refresh_snapshot()
		_refresh_details()
		_selected_action_id = selected
		_refresh_selection()


func _is_up(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_up", false, true)


func _is_down(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_down", false, true)


func _is_confirm(event: InputEvent) -> bool:
	if event.is_action_pressed(CommandsScript.CONTEXT, false, true) or event.is_action_pressed(
		"ui_accept", false, true
	):
		return true
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return key.pressed and not key.echo and key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	return false


func _is_pointer_press(event: InputEvent) -> bool:
	return (
		(event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	)


func _pointer_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	return Vector2.ZERO
