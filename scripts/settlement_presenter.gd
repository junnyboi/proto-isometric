extends CanvasLayer

signal action_requested(action: StringName, data: Dictionary)

const BlueprintCatalogScript: GDScript = preload(
	"res://scripts/construction_blueprint_catalog.gd"
)
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")

var _root: Control
var _panel: PanelContainer
var _offer_view: VBoxContainer
var _roster_view: VBoxContainer
var _offer_tab: Button
var _roster_tab: Button
var _portrait: TextureRect
var _offer_title: Label
var _offer_details: Label
var _offer_expiry: Label
var _offer_empty: Label
var _roster_list: ItemList
var _settler_select: OptionButton
var _site_select: OptionButton
var _slot_select: OptionButton
var _shift_select: OptionButton
var _assignment_grid: GridContainer
var _assignment_status: Label
var _buttons: Dictionary = {}
var _snapshot: Dictionary = {}
var _active_tab: StringName = &"offer"
var _ui_scale: float = 1.0


func _ready() -> void:
	layer = 49
	_build_interface()
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	visible = false


func present(snapshot: Dictionary, tab: StringName = &"offer") -> void:
	_snapshot = snapshot.duplicate(true)
	_active_tab = tab if tab in [&"offer", &"roster"] else &"offer"
	_refresh()
	visible = true
	_apply_layout()
	var focus: Button = _buttons.get(&"invite") as Button
	if _active_tab == &"roster":
		focus = _buttons.get(&"assign") as Button
	if focus != null and not focus.disabled:
		focus.grab_focus()
	else:
		_roster_tab.grab_focus()


func update_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_refresh()


func present_result(result: Dictionary) -> void:
	var ok: bool = bool(result.get(&"ok", false))
	var text: String = LocalizationScript.t(&"settlement.status.saved")
	if not ok:
		text = LocalizationScript.t(
			&"settlement.status.rejected",
			{&"reason": str(result.get(&"reason", &"rejected")).replace("_", " ")},
		)
	var label: Label = _assignment_status if _active_tab == &"roster" else _offer_expiry
	if label != null:
		label.text = text
		label.visible = true
		label.add_theme_color_override(
			"font_color", Color("75ead2") if ok else Color("ff8f87")
		)


func dismiss() -> void:
	visible = false
	_snapshot.clear()


func is_open() -> bool:
	return visible and not _snapshot.is_empty()


func panel_bounds() -> Rect2:
	return Rect2(_panel.position, _panel.size) if _panel != null and visible else Rect2()


func layout_snapshot() -> Dictionary:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	return {
		&"viewport": viewport,
		&"panel": panel_bounds(),
		&"portrait": viewport.y > viewport.x,
		&"compact": viewport.x < 900.0 or viewport.y < 560.0,
		&"minimum_touch_target": 44.0,
	}


func apply_preferences(snapshot: Dictionary) -> void:
	_ui_scale = clampf(float(snapshot.get(&"ui_scale", 1.0)), 0.85, 1.25)
	_apply_layout()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"ui_cancel"):
		action_requested.emit(&"close", {})
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _panel == null:
		return
	_refresh_offer()
	_refresh_roster()
	_offer_view.visible = _active_tab == &"offer"
	_roster_view.visible = _active_tab == &"roster"
	_offer_tab.disabled = _active_tab == &"offer"
	_roster_tab.disabled = _active_tab == &"roster"


func _refresh_offer() -> void:
	var offer: Dictionary = _snapshot.get(&"offer", {}) as Dictionary
	var has_offer: bool = not offer.is_empty()
	_offer_empty.visible = not has_offer
	_portrait.visible = has_offer
	_offer_title.visible = has_offer
	_offer_details.visible = has_offer
	_offer_expiry.visible = has_offer
	for action: StringName in [&"invite", &"defer", &"decline"]:
		var button: Button = _buttons.get(action) as Button
		button.visible = has_offer
	if not has_offer:
		_offer_empty.text = LocalizationScript.t(&"settlement.offer.none")
		return
	_portrait.texture = offer.get(&"portrait", null) as Texture2D
	_offer_title.text = "%s // %s" % [
		str(offer[&"name"]), LocalizationScript.t(offer[&"pronouns_key"])
	]
	var traits: Array[String] = _localized(offer[&"trait_keys"] as Array)
	var needs: Array[String] = _localized(offer[&"need_keys"] as Array)
	var jobs: Array[String] = []
	for raw_job: Variant in offer[&"preferred_job_types"] as Array:
		jobs.append(LocalizationScript.t(StringName("settlement.job.%s" % str(raw_job))))
	_offer_details.text = "%s\n\n%s: %s\n%s: %s\n%s: %s\n%s" % [
		LocalizationScript.t(offer[&"bio_key"]),
		LocalizationScript.t(&"settlement.traits"), ", ".join(traits),
		LocalizationScript.t(&"settlement.needs"), ", ".join(needs),
		LocalizationScript.t(&"settlement.preferences"), ", ".join(jobs),
		LocalizationScript.t(&"settlement.housing.promise"),
	]
	_offer_expiry.text = LocalizationScript.t(
		&"settlement.offer.expires", {&"day": int(offer[&"expires_day"])}
	)
	var deferred_until: int = int(offer[&"deferred_until_day"])
	var defer: Button = _buttons[&"defer"] as Button
	defer.disabled = deferred_until > 0 or int(offer[&"deferrals"]) >= 2


func _refresh_roster() -> void:
	var roster: Array = _snapshot.get(&"roster", []) as Array
	var previous_settler: String = _selected_metadata(_settler_select)
	_roster_list.clear()
	_settler_select.clear()
	for entry: Dictionary in roster as Array[Dictionary]:
		var settler_id: String = str(entry[&"settler_id"])
		var state: Dictionary = entry[&"state"] as Dictionary
		var housing: Dictionary = entry[&"housing"] as Dictionary
		var assignment: Dictionary = entry[&"assignment"] as Dictionary
		var work_text: String = LocalizationScript.t(&"settlement.roster.unassigned")
		var work_status: String = LocalizationScript.t(
			StringName("settlement.work.status.%s" % str(entry.get(&"work_status", "resting")))
		)
		var shift_report: Dictionary = entry.get(&"shift_report", {}) as Dictionary
		if str(entry.get(&"work_status", "")) == "idle" and not shift_report.is_empty():
			work_status = LocalizationScript.t(
				StringName("settlement.work.idle.%s" % str(shift_report[&"reason"]))
			)
		if not assignment.is_empty():
			work_text = "%s #%d // %s // %s" % [
					_site_label(str(assignment[&"site_id"])),
					int(assignment[&"slot"]) + 1,
					_shift_label(int(assignment[&"shift"])),
					work_status,
				]
		else:
			work_text = "%s // %s" % [work_text, work_status]
		_roster_list.add_item(
			"%s  //  %s  //  %s  //  %s" % [
				str(entry[&"name"]), str(state[&"status"]),
				_bed_label(str(housing.get(&"bed_id", ""))), work_text
			]
		)
		_settler_select.add_item(str(entry[&"name"]))
		_settler_select.set_item_metadata(_settler_select.item_count - 1, settler_id)
	_select_metadata(_settler_select, previous_settler)
	_refresh_sites()
	var has_roster: bool = not roster.is_empty()
	_settler_select.disabled = not has_roster
	_site_select.disabled = not has_roster or _site_select.item_count == 0
	var assign: Button = _buttons[&"assign"] as Button
	var unassign: Button = _buttons[&"unassign"] as Button
	assign.disabled = not has_roster or _site_select.item_count == 0
	unassign.disabled = not has_roster or not _selected_has_assignment(roster)
	if not has_roster:
		_assignment_status.text = LocalizationScript.t(&"settlement.roster.empty")
	elif _site_select.item_count == 0:
		_assignment_status.text = LocalizationScript.t(&"settlement.work.no_sites")
	else:
		_assignment_status.text = LocalizationScript.t(&"settlement.work.ethical_notice")


func _refresh_sites() -> void:
	var previous_site: String = _selected_metadata(_site_select)
	_site_select.clear()
	for site: Dictionary in _snapshot.get(&"sites", []) as Array[Dictionary]:
		var blueprint_id: StringName = StringName(str(site[&"blueprint_id"]))
		var definition: Dictionary = BlueprintCatalogScript.definition(blueprint_id)
		var label: String = LocalizationScript.t(definition[&"label_key"])
		var output_count: int = 0
		for stack: Dictionary in site.get(&"local_stacks", []) as Array[Dictionary]:
			output_count += int(stack[&"count"])
		if output_count > 0:
			label += " // " + LocalizationScript.t(
				&"settlement.work.output_count", {&"count": output_count}
			)
		for report: Dictionary in site.get(&"shift_reports", []) as Array[Dictionary]:
			if str(report[&"reason"]) == "no_worker":
				label += " // " + LocalizationScript.t(&"settlement.work.idle.no_worker")
				break
		_site_select.add_item(label)
		_site_select.set_item_metadata(_site_select.item_count - 1, str(site[&"site_id"]))
	_select_metadata(_site_select, previous_site)
	_refresh_slots()


func _refresh_slots() -> void:
	_slot_select.clear()
	var site_id: String = _selected_metadata(_site_select)
	for site: Dictionary in _snapshot.get(&"sites", []) as Array[Dictionary]:
		if str(site[&"site_id"]) != site_id:
			continue
		var slot_types: Array = site[&"slot_types"] as Array
		for index: int in slot_types.size():
			var label: String = LocalizationScript.t(
				StringName("settlement.job.%s" % str(slot_types[index]))
			)
			_slot_select.add_item("%d // %s" % [index + 1, label])
			_slot_select.set_item_metadata(_slot_select.item_count - 1, index)
	_slot_select.disabled = _slot_select.item_count == 0


func _build_interface() -> void:
	_root = Control.new()
	_root.name = "SettlementModalRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.01, 0.025, 0.03, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)
	_panel = PanelContainer.new()
	_panel.name = "SettlementModalPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.06, 0.985)
	style.border_color = Color("68c5b7")
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(14.0)
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	_panel.add_child(content)
	var title_row: HBoxContainer = HBoxContainer.new()
	content.add_child(title_row)
	var title: Label = _label(20, Color("fff2cc"))
	title.text = LocalizationScript.t(&"settlement.title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close: Button = _button("×", &"close")
	close.tooltip_text = LocalizationScript.t(&"settlement.close")
	title_row.add_child(close)
	var tabs: HBoxContainer = HBoxContainer.new()
	content.add_child(tabs)
	_offer_tab = _button(LocalizationScript.t(&"settlement.tab.applicant"), &"tab_offer")
	_roster_tab = _button(LocalizationScript.t(&"settlement.tab.roster"), &"tab_roster")
	_offer_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(_offer_tab)
	tabs.add_child(_roster_tab)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var view_stack: VBoxContainer = VBoxContainer.new()
	view_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(view_stack)
	_offer_view = VBoxContainer.new()
	_offer_view.add_theme_constant_override("separation", 8)
	_offer_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_stack.add_child(_offer_view)
	_build_offer_view()
	_roster_view = VBoxContainer.new()
	_roster_view.add_theme_constant_override("separation", 8)
	_roster_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_stack.add_child(_roster_view)
	_build_roster_view()


func _build_offer_view() -> void:
	_offer_empty = _label(16, Color("c2d9d3"))
	_offer_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_offer_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_offer_view.add_child(_offer_empty)
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	_offer_view.add_child(body)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(160, 200)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.add_child(_portrait)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(text)
	_offer_title = _label(19, Color("fff2cc"))
	text.add_child(_offer_title)
	_offer_details = _label(14, Color("c2d9d3"))
	_offer_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_offer_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_child(_offer_details)
	_offer_expiry = _label(14, Color("f3d39a"))
	text.add_child(_offer_expiry)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	_offer_view.add_child(actions)
	actions.add_child(_button(LocalizationScript.t(&"settlement.action.invite"), &"invite"))
	actions.add_child(_button(LocalizationScript.t(&"settlement.action.defer"), &"defer"))
	actions.add_child(_button(LocalizationScript.t(&"settlement.action.decline"), &"decline"))


func _build_roster_view() -> void:
	_roster_list = ItemList.new()
	_roster_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster_list.custom_minimum_size = Vector2(0, 120)
	_roster_list.add_theme_font_size_override("font_size", 16)
	_roster_view.add_child(_roster_list)
	_assignment_grid = GridContainer.new()
	_assignment_grid.columns = 4
	_assignment_grid.add_theme_constant_override("h_separation", 8)
	_roster_view.add_child(_assignment_grid)
	_settler_select = _selector(_assignment_grid, &"settler")
	_site_select = _selector(_assignment_grid, &"site")
	_site_select.item_selected.connect(func(_index: int) -> void: _refresh_slots())
	_slot_select = _selector(_assignment_grid, &"slot")
	_shift_select = _selector(_assignment_grid, &"shift")
	_shift_select.add_item(LocalizationScript.t(&"settlement.shift.day"))
	_shift_select.set_item_metadata(0, 0)
	_shift_select.add_item(LocalizationScript.t(&"settlement.shift.evening"))
	_shift_select.set_item_metadata(1, 1)
	_assignment_status = _label(13, Color("75ead2"))
	_assignment_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_roster_view.add_child(_assignment_status)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	_roster_view.add_child(actions)
	actions.add_child(_button(LocalizationScript.t(&"settlement.action.assign"), &"assign"))
	actions.add_child(_button(LocalizationScript.t(&"settlement.action.unassign"), &"unassign"))


func _selector(parent: Container, prefix: StringName) -> OptionButton:
	var selector: OptionButton = OptionButton.new()
	selector.name = "%sSelector" % String(prefix).to_pascal_case()
	selector.custom_minimum_size = Vector2(96, 44)
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.fit_to_longest_item = false
	selector.clip_text = true
	selector.add_theme_font_size_override("font_size", 15)
	parent.add_child(selector)
	return selector


func _button(text: String, action: StringName) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(64, 44)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(func() -> void: _emit_action(action))
	_buttons[action] = button
	return button


func _emit_action(action: StringName) -> void:
	if action == &"tab_offer":
		_active_tab = &"offer"
		_refresh()
		return
	if action == &"tab_roster":
		_active_tab = &"roster"
		_refresh()
		return
	var data: Dictionary = {}
	if action in [&"invite", &"decline", &"defer"]:
		var offer: Dictionary = _snapshot.get(&"offer", {}) as Dictionary
		data[&"applicant_id"] = str(offer.get(&"settler_id", ""))
		data[&"offer_sequence"] = int(offer.get(&"sequence", -1))
	if action in [&"assign", &"unassign"]:
		data[&"settler_id"] = _selected_metadata(_settler_select)
		data[&"source_revision"] = int(_snapshot.get(&"source_revision", -1))
	if action == &"assign":
		data[&"site_id"] = _selected_metadata(_site_select)
		data[&"slot"] = int(_slot_select.get_item_metadata(_slot_select.selected))
		data[&"shift"] = int(_shift_select.get_item_metadata(_shift_select.selected))
	action_requested.emit(action, data)


func _localized(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(LocalizationScript.t(value))
	return result


func _selected_metadata(selector: OptionButton) -> String:
	if selector == null or selector.item_count == 0 or selector.selected < 0:
		return ""
	return str(selector.get_item_metadata(selector.selected))


func _select_metadata(selector: OptionButton, value: String) -> void:
	if selector.item_count == 0:
		return
	for index: int in selector.item_count:
		if str(selector.get_item_metadata(index)) == value:
			selector.select(index)
			return
	selector.select(0)


func _selected_has_assignment(roster: Array) -> bool:
	var settler_id: String = _selected_metadata(_settler_select)
	for entry: Dictionary in roster as Array[Dictionary]:
		if str(entry[&"settler_id"]) == settler_id:
			return not (entry[&"assignment"] as Dictionary).is_empty()
	return false


func _shift_label(shift: int) -> String:
	return LocalizationScript.t(
		&"settlement.shift.day" if shift == 0 else &"settlement.shift.evening"
	)


func _site_label(site_id: String) -> String:
	for site: Dictionary in _snapshot.get(&"sites", []) as Array[Dictionary]:
		if str(site[&"site_id"]) != site_id:
			continue
		var blueprint: Dictionary = BlueprintCatalogScript.definition(
			StringName(str(site[&"blueprint_id"]))
		)
		return LocalizationScript.t(blueprint[&"label_key"])
	return LocalizationScript.t(&"settlement.roster.assigned_site")


func _bed_label(bed_id: String) -> String:
	if bed_id.begins_with("bed.home."):
		return LocalizationScript.t(&"settlement.bed.safehouse")
	if bed_id.begins_with("bed.building."):
		return LocalizationScript.t(&"settlement.bed.shelter")
	return LocalizationScript.t(&"settlement.bed.none")


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
	var compact: bool = viewport.x < 900.0 or viewport.y < 560.0
	if _assignment_grid != null:
		_assignment_grid.columns = 2 if compact else 4
	_portrait.custom_minimum_size = Vector2(112, 140) if compact else Vector2(160, 200)


static func _layout_for(viewport: Vector2, scale: float) -> Rect2:
	var margin: float = 16.0
	var portrait: bool = viewport.y > viewport.x
	var width: float = minf(viewport.x - margin * 2.0, (720.0 if portrait else 860.0) * scale)
	var height: float = minf(viewport.y - margin * 2.0, (720.0 if portrait else 560.0) * scale)
	var position: Vector2 = Vector2(
		(viewport.x - width) * 0.5, (viewport.y - height) * 0.5
	)
	return Rect2(position, Vector2(width, height))
