extends "res://scripts/interaction_dossier_interface.gd"

const ActionPresentationScript: GDScript = preload(
	"res://scripts/interaction_action_presentation_catalog.gd"
)
const DossierCoordinatorScript: GDScript = preload(
	"res://scripts/interaction_dossier_coordinator.gd"
)
const DossierLayoutScript: GDScript = preload("res://scripts/interaction_dossier_layout.gd")
const SafeAreaScript: GDScript = preload("res://scripts/platform_safe_area.gd")
const OperationCatalogScript: GDScript = preload(
	"res://scripts/interaction_operation_catalog.gd"
)

const DOSSIER_FEATURE: String = "features/interaction_dossier_v2"

var _dossier_coordinator: RefCounted
var _sealed_anchor: Callable
var _dossier_state: Dictionary = {}
var _active_dossier_tab: StringName = TAB_SUMMARY
var _camera_generation: int = 0
var _cached_target_anchor: Vector2 = Vector2.ZERO
var _has_target_anchor: bool = false

func _ready() -> void:
	layer = 24
	name = "HarvestInteractionPresenter"
	_dossier_enabled = bool(ProjectSettings.get_setting(DOSSIER_FEATURE, false))
	CommandsScript.install_defaults()
	_build_interface()
	if _dossier_enabled:
		_build_dossier_interface()
	add_to_group("localization_listeners")
	get_viewport().size_changed.connect(_on_viewport_resized)
	apply_preferences(
		(PlayerPreferencesScript.new() as RefCounted).call("load_preferences") as Dictionary
	)
	call_deferred("_bind_accessibility")
	set_process_input(true)

func bind(
	controller: Node,
	mobile_controls: CanvasLayer = null,
	dossier_coordinator: RefCounted = null,
	sealed_anchor: Callable = Callable(),
) -> bool:
	if controller == null:
		return false
	_controller = controller
	_mobile_controls = mobile_controls
	_sealed_anchor = sealed_anchor
	if _dossier_enabled:
		_dossier_coordinator = (
			dossier_coordinator
			if dossier_coordinator != null
			else DossierCoordinatorScript.new() as RefCounted
		)
	controller.connect("menu_snapshot_opened", _on_snapshot_opened)
	controller.connect("menu_snapshot_refreshed", _on_snapshot_refreshed)
	controller.connect("menu_snapshot_closed", _on_snapshot_closed)
	controller.connect("menu_selection_changed", _on_selection_changed)
	controller.connect("menu_execution_result", _on_execution_result)
	if bool(controller.call("is_menu_open")):
		_on_snapshot_opened(controller.call("get_menu_snapshot") as Dictionary)
	return true

func is_open() -> bool:
	var visible_panel: bool = (
		_dossier_panel != null and _dossier_panel.visible
		if _dossier_enabled
		else _panel != null and _panel.visible
	)
	return visible_panel and MenuScript.validate(_snapshot)

func get_panel_bounds() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for value: Variant in _layout.get(&"panel_rects", [get_popup_bounds()]):
		if value is Rect2:
			result.append(value as Rect2)
	return result

func get_layout_mode() -> StringName:
	return _layout.get(&"mode", LAYOUT_COMPACT_SIDE) as StringName

func get_pool_size() -> int:
	if _dossier_enabled:
		return (_snapshot.get(&"options", []) as Array).size()
	return _rows.size()

func get_visible_row_count() -> int:
	var count: int = 0
	var pool: Array[Button] = _dossier_rows if _dossier_enabled else _rows
	for row: Button in pool:
		if row.visible:
			count += 1
	return count

func get_fact_pool_size() -> int:
	return _summary_fact_rows.size() if _dossier_enabled else _fact_rows.size()

func get_visible_fact_count() -> int:
	var count: int = 0
	if _dossier_enabled:
		for row: Control in _summary_fact_rows:
			if row.visible:
				count += 1
		return count
	for row: Label in _fact_rows:
		if row.visible:
			count += 1
	return count

func get_active_view() -> StringName:
	if not _dossier_enabled:
		return _active_view
	return VIEW_DETAILS if _active_dossier_tab == TAB_SUMMARY else _active_dossier_tab

func get_active_tab() -> StringName:
	return _active_dossier_tab if _dossier_enabled else _active_view

func get_dossier_state() -> Dictionary:
	return _dossier_state.duplicate(true)

func get_dossier_overlay() -> Control:
	return _dossier_overlay

func get_dossier_coordinator() -> RefCounted:
	return _dossier_coordinator

func is_dossier_enabled() -> bool:
	return _dossier_enabled

func has_terminal_controls() -> bool:
	if _dossier_enabled:
		return (
			_dossier_back != null
			and _dossier_activate != null
			and _dossier_close != null
			and _dossier_back.custom_minimum_size.y >= 44.0
			and _dossier_activate.custom_minimum_size.y >= 44.0
			and _dossier_close.custom_minimum_size.y >= 44.0
		)
	return (
		_back_button != null
		and _activate_button != null
		and _back_button.custom_minimum_size.y >= 44.0
		and _activate_button.custom_minimum_size.y >= 44.0
	)

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
		if not _point_is_in_panel(position):
			_controller.call("close_menu")
		else:
			return false
	elif event.is_action_pressed(CommandsScript.CANCEL, false, true) or event.is_action_pressed(
		"ui_cancel", false, true
	):
		_controller.call("close_menu")
	elif _dossier_enabled and _is_compact_layout() and event.is_action_pressed(
		"ui_left", false, true
	):
		_cycle_dossier_tab(-1)
	elif _dossier_enabled and _is_compact_layout() and event.is_action_pressed(
		"ui_right", false, true
	):
		_cycle_dossier_tab(1)
	elif not _dossier_enabled and _is_compact_layout() and event.is_action_pressed(
		"ui_left", false, true
	):
		_set_active_view(VIEW_DETAILS)
	elif not _dossier_enabled and _is_compact_layout() and event.is_action_pressed(
		"ui_right", false, true
	):
		_set_active_view(VIEW_ACTIONS)
	elif _is_up(event):
		_controller.call("navigate_menu", -1)
	elif _is_down(event):
		_controller.call("navigate_menu", 1)
	elif _is_confirm(event):
		if _dossier_enabled and _is_compact_layout() and _active_dossier_tab != TAB_ACTIONS:
			_set_dossier_tab(TAB_ACTIONS)
		else:
			_activate_selected()
	else:
		handled = _is_modal_action(event)
	return handled

func _on_snapshot_opened(snapshot: Dictionary) -> void:
	if not MenuScript.validate(snapshot):
		return
	_snapshot = snapshot.duplicate(true)
	_detail_result.clear()
	_last_result_key = &""
	_active_view = VIEW_ACTIONS
	if _dossier_enabled:
		_active_dossier_tab = TAB_SUMMARY
		_dossier_panel.visible = true
		_panel.visible = false
		_dossier_coordinator.call(
			"set_snapshot", snapshot, _controller.call("get_selected_action_id") as StringName
		)
		_refresh_dossier()
	else:
		_panel.visible = true
	_veil.visible = true
	_apply_layout(get_viewport().get_visible_rect().size)
	if not _dossier_enabled:
		_refresh_snapshot()
		_refresh_details()
	_set_mobile_modal(true)

func _on_snapshot_refreshed(snapshot: Dictionary) -> void:
	if not MenuScript.validate(snapshot):
		return
	_snapshot = snapshot.duplicate(true)
	_detail_result.clear()
	if _dossier_enabled:
		_dossier_coordinator.call(
			"set_snapshot", snapshot, _controller.call("get_selected_action_id") as StringName
		)
		_refresh_dossier()
	else:
		_refresh_snapshot()
		_refresh_details()

func _on_snapshot_closed() -> void:
	_snapshot.clear()
	_detail_result.clear()
	_dossier_state.clear()
	_selected_action_id = &""
	_active_view = VIEW_ACTIONS
	_active_dossier_tab = TAB_SUMMARY
	_panel.visible = false
	if _dossier_enabled:
		_dossier_panel.visible = false
		_inspection_panel.visible = false
		_nearby_panel.visible = false
		_has_target_anchor = false
		_dossier_overlay.call("clear_draw_state")
	_veil.visible = false
	_refresh_details()
	_set_mobile_modal(false)

func _on_selection_changed(_index: int, action_id: StringName) -> void:
	_selected_action_id = action_id
	if _dossier_enabled:
		_dossier_coordinator.call("set_selection", action_id)
		_refresh_dossier()
	else:
		_refresh_selection()

func _on_execution_result(result: Dictionary) -> void:
	if _dossier_enabled:
		var observed: bool = bool(_dossier_coordinator.call("observe_result", result))
		if _is_compact_layout():
			_active_dossier_tab = TAB_SUMMARY
		if observed:
			_refresh_dossier()
		else:
			_apply_dossier_visibility()
		return
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

func _apply_layout(viewport_size: Vector2) -> void:
	if _panel == null:
		return
	if _dossier_enabled:
		_apply_dossier_layout(viewport_size)
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

func _handle_back() -> void:
	if _controller == null:
		return
	if _dossier_enabled:
		if _is_compact_layout() and _active_dossier_tab != TAB_ACTIONS:
			_set_dossier_tab(TAB_ACTIONS)
		else:
			_controller.call("close_menu")
		return
	if _is_compact_layout() and _active_view == VIEW_DETAILS:
		_set_active_view(VIEW_ACTIONS)
	else:
		_controller.call("close_menu")

func _is_compact_layout() -> bool:
	if _dossier_enabled and _layout.has(&"mode"):
		return _layout[&"mode"] not in [LAYOUT_WIDE_TERRAIN, LAYOUT_WIDE_OBJECT]
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var mobile: bool = _mobile_controls != null and bool(_mobile_controls.call("is_mobile_device"))
	return mobile or viewport.y > viewport.x or viewport.x < 700.0 or viewport.y < 500.0

func _on_locale_changed(_locale: StringName) -> void:
	var selected: StringName = _selected_action_id
	if is_open():
		if _dossier_enabled:
			_refresh_dossier()
		else:
			_refresh_snapshot()
			_refresh_details()
		_selected_action_id = selected
		_refresh_selection()

func set_dossier_nearby(rows: Array[Dictionary]) -> bool:
	if not _dossier_enabled or _dossier_coordinator == null:
		return false
	var changed: bool = bool(_dossier_coordinator.call("set_nearby", rows))
	if changed and is_open():
		_refresh_dossier()
	return changed

func update_sealed_target_anchor(anchor: Vector2, camera_generation: int) -> bool:
	if not _dossier_enabled or camera_generation < 0:
		return false
	if (
		_has_target_anchor
		and _cached_target_anchor.is_equal_approx(anchor)
		and _camera_generation == camera_generation
	):
		return false
	_cached_target_anchor = anchor
	_has_target_anchor = true
	_camera_generation = camera_generation
	_update_dossier_overlay()
	return true

func clear_sealed_target_anchor() -> void:
	_has_target_anchor = false
	if _dossier_overlay != null:
		_dossier_overlay.call("clear_draw_state")

func _refresh_dossier() -> void:
	if not _dossier_enabled or _dossier_coordinator == null or not MenuScript.validate(_snapshot):
		return
	var state: Dictionary = _dossier_coordinator.call("compose") as Dictionary
	if not DossierStateScript.validate(state):
		return
	_dossier_state = state
	_selected_action_id = state[&"selected_action_id"] as StringName
	_dossier_title.text = _dossier_target_title(state)
	_dossier_subtitle.text = _localized(
		state[&"subtitle_key"] as StringName, _humanize(_snapshot[&"target_subkind"])
	)
	var cell: Vector2i = state[&"target_cell"] as Vector2i
	_dossier_coordinates.text = LocalizationScript.t(
		&"interaction.dossier.coordinates", {"x": cell.x, "y": cell.y}
	)
	_dossier_thumbnail.texture = AssetCatalogScript.target_thumbnail(
		_snapshot[&"target_subkind"] as StringName,
		_snapshot[&"target_state"] as Dictionary,
	)
	_refresh_dossier_actions()
	_refresh_dossier_summary()
	_refresh_dossier_history()
	_refresh_dossier_preview()
	_refresh_dossier_nearby()
	_refresh_dossier_toast()
	_refresh_dossier_labels()
	_apply_dossier_visibility()
	_refresh_dossier_selection()
	_update_dossier_overlay()

func _refresh_dossier_actions() -> void:
	var options: Array = _snapshot[&"options"] as Array
	for index: int in _dossier_rows.size():
		var row: Button = _dossier_rows[index]
		row.visible = index < options.size()
		if not row.visible:
			continue
		var option: Dictionary = options[index] as Dictionary
		var descriptor: Dictionary = OperationCatalogScript.descriptor_for(
			option[&"operation"] as StringName, option[&"provider_id"] as StringName
		)
		var metadata: Dictionary = ActionPresentationScript.for_option(option, descriptor)
		var label_text: String = _localized(
			option[&"label_key"] as StringName, _fallback_action_label(option[&"action_id"])
		)
		var description: String = _localized(
			metadata.get(&"description_key", &"") as StringName, label_text
		)
		var reason: String = ""
		if not bool(option[&"enabled"]):
			reason = _localized(option[&"reason_key"] as StringName, _humanize(option[&"reason_key"]))
		var cost: String = _dossier_cost_text(option[&"cost_preview"] as Array)
		var accessible: String = LocalizationScript.t(
			&"interaction.dossier.action.accessible",
			{
				"title": label_text,
				"description": description,
				"state": LocalizationScript.t(
					&"interaction.dossier.action.enabled"
					if bool(option[&"enabled"])
					else &"interaction.dossier.action.disabled"
				),
				"detail": reason if not reason.is_empty() else cost,
			},
		)
		row.call(
			"set_content", label_text, description, cost, reason,
			AssetCatalogScript.action_icon(metadata.get(&"icon_id", &"") as StringName),
			bool(option[&"enabled"]), index == int(_controller.call("get_selected_menu_index")),
			accessible,
		)
		row.call("set_ui_scale", _ui_scale)
		row.disabled = false
		row.set_meta("option_enabled", option[&"enabled"])
		row.set_meta("action_id", option[&"action_id"])

func _refresh_dossier_summary() -> void:
	for section: VBoxContainer in _summary_sections:
		section.visible = false
	for row: Control in _summary_fact_rows:
		row.visible = false
	var sections: Array = _dossier_state[&"summary_sections"] as Array
	var row_index: int = 0
	for section_index: int in mini(sections.size(), _summary_sections.size()):
		var section_data: Dictionary = sections[section_index] as Dictionary
		var section: VBoxContainer = _summary_sections[section_index]
		section.visible = true
		_summary_section_titles[section_index].text = _localized(
			section_data[&"title_key"] as StringName, _humanize(section_data[&"section_id"])
		)
		for fact_data: Dictionary in section_data[&"rows"] as Array[Dictionary]:
			if row_index >= _summary_fact_rows.size():
				break
			var row: Control = _summary_fact_rows[row_index]
			if row.get_parent() != section:
				row.reparent(section)
			row.call("set_ui_scale", _ui_scale)
			row.call(
				"set_fact",
				_localized(
					fact_data[&"label_key"] as StringName,
					LocalizationScript.t(&"interaction.inspect.fact.unknown"),
				),
				_fact_value_text(fact_data),
				fact_data[&"value_kind"] as StringName,
			)
			row.visible = true
			row_index += 1
	var chips: Array = _dossier_state[&"chips"] as Array
	_chip_strip.visible = not chips.is_empty()
	for index: int in _chip_labels.size():
		var chip: Label = _chip_labels[index]
		chip.visible = index < chips.size()
		if chip.visible:
			var chip_data: Dictionary = chips[index] as Dictionary
			chip.text = LocalizationScript.t(
				&"interaction.dossier.chip",
				{
					"label": _localized(
						chip_data[&"label_key"] as StringName,
						LocalizationScript.t(&"interaction.inspect.fact.unknown"),
					),
					"value": _fact_value_text(chip_data),
				},
			)
			chip.accessibility_name = chip.text

func _refresh_dossier_history() -> void:
	var history: Array = _dossier_state[&"history"] as Array
	for index: int in _history_labels.size():
		var label: Label = _history_labels[index]
		label.visible = index < history.size() or index == 0 and history.is_empty()
		if not label.visible:
			continue
		if history.is_empty():
			label.text = LocalizationScript.t(&"interaction.history.session.empty")
			continue
		var record: Dictionary = history[index] as Dictionary
		var title: String = _localized(
			record[&"title_key"] as StringName, _humanize(record[&"action_id"])
		)
		var body: String = LocalizationScript.t(
			record[&"body_key"] as StringName,
			_localized_parameters(record[&"parameters"] as Dictionary),
		)
		if not bool(record[&"ok"]):
			body = "%s\n%s" % [
				body,
				_localized(record[&"reason_key"] as StringName, _humanize(record[&"reason_key"])),
			]
		label.text = LocalizationScript.t(
			&"interaction.history.session.entry",
			{"sequence": int(record[&"sequence"]), "title": title, "body": body},
		)
		label.accessibility_name = label.text.replace("\n", ", ")

func _refresh_dossier_nearby() -> void:
	var nearby: Array = _dossier_state[&"nearby"] as Array
	for index: int in _nearby_labels.size():
		var label: Label = _nearby_labels[index]
		label.visible = index < nearby.size()
		if not label.visible:
			continue
		var row: Dictionary = nearby[index] as Dictionary
		var direction_id: StringName = row[&"direction_id"] as StringName
		var direction_key := StringName(
			"interaction.dossier.direction.%s" % str(direction_id)
		)
		label.text = LocalizationScript.t(
			&"interaction.dossier.nearby.entry",
			{
				"title": _localized(row[&"title_key"] as StringName, _humanize(row[&"kind"])),
				"distance": int(row[&"tile_distance"]),
				"direction": _localized(direction_key, _humanize(direction_id)),
			},
		)
		label.accessibility_name = label.text

func _refresh_dossier_preview() -> void:
	var preview: Dictionary = _dossier_state[&"preview"] as Dictionary
	if preview.is_empty():
		_preview_title.text = LocalizationScript.t(&"interaction.preview.unavailable")
		_preview_body.text = ""
		return
	_preview_title.text = LocalizationScript.t(
		&"interaction.preview.title",
		{
			"action": _localized(
				preview[&"title_key"] as StringName, _humanize(preview[&"action_id"])
			)
		},
	)
	var parts: PackedStringArray = []
	parts.append(_localized(
		preview[&"description_key"] as StringName, _humanize(preview[&"operation"])
	))
	var costs: String = _dossier_cost_text(preview[&"costs"] as Array)
	if not costs.is_empty():
		parts.append(costs)
	if not bool(preview[&"enabled"]):
		parts.append(LocalizationScript.t(
			&"interaction.menu.disabled",
			{
				"reason": _localized(
					preview[&"reason_key"] as StringName,
					_humanize(preview[&"reason_key"]),
				)
			},
		))
	for effect: Dictionary in preview[&"effect_rows"] as Array[Dictionary]:
		parts.append(_fact_value_text(effect))
	_preview_body.text = "\n".join(parts)
	var inspection_section: Dictionary = _inspection_section()
	_inspection_title.text = (
		_localized(
			inspection_section.get(&"title_key", &"") as StringName,
			LocalizationScript.t(&"interaction.dossier.section.inspection.title"),
		)
		if not inspection_section.is_empty()
		else LocalizationScript
.t(&"interaction.dossier.inspection.empty")
	)
	_inspection_body.text = LocalizationScript.t(&"interaction.dossier.inspection.body")
	var facts: Array = inspection_section.get(&"rows", []) as Array
	for index: int in _inspection_fact_rows.size():
		var row: Control = _inspection_fact_rows[index]
		row.visible = index < facts.size()
		if not row.visible:
			continue
		var fact: Dictionary = facts[index] as Dictionary
		row.call("set_ui_scale", _ui_scale)
		row.call(
			"set_fact", _localized(fact[&"label_key"], "Field"),
			_fact_value_text(fact), fact[&"value_kind"]
		)

func _inspection_section() -> Dictionary:
	for section: Dictionary in _dossier_state.get(&"summary_sections", []) as Array[Dictionary]:
		if section[&"section_id"] == &"interaction.dossier.section.inspection":
			return section
	return {}

func _refresh_dossier_toast() -> void:
	var toast: Dictionary = _dossier_state[&"toast"] as Dictionary
	if toast.is_empty():
		return
	_toast_title.text = _localized(
		toast[&"title_key"], LocalizationScript.t(&"interaction.toast.result")
	)
	_toast_body.text = LocalizationScript.t(
		toast[&"body_key"],
		_localized_parameters(toast[&"parameters"] as Dictionary),
	)
	if toast[&"tone"] == &"failure":
		_toast_body.text += "\n" + _localized(toast[&"reason_key"], _humanize(toast[&"reason_key"]))
	_toast_panel.visible = true
	_toast_timer.start(float(toast[&"duration_msec"]) / 1000.0)

func _refresh_dossier_labels() -> void:
	_nearby_heading.text = LocalizationScript.t(&"interaction.dossier.nearby.title")
	for button: Button in [
		_summary_tab, _dossier_actions_tab, _history_tab,
		_dossier_back, _dossier_activate, _dossier_close,
	]:
		button.text = LocalizationScript.t(button.get_meta("label_key") as StringName)
	var heading: Label = _history_stack.get_child(0) as Label
	heading.text = LocalizationScript.t(heading.get_meta("label_key") as StringName)

func _refresh_dossier_selection() -> void:
	if _controller == null:
		return
	var selected: int = int(_controller.call("get_selected_menu_index"))
	for index: int in _dossier_rows.size():
		var row: Button = _dossier_rows[index]
		if not row.visible:
			continue
		row.call("set_selected", index == selected)
		if index == selected and (_active_dossier_tab == TAB_ACTIONS or not _is_compact_layout()):
			row.grab_focus()
			_action_scroll.ensure_control_visible(row)

func _on_dossier_row_pressed(index: int) -> void:
	if _controller == null or index < 0 or index >= _dossier_rows.size():
		return
	var selected: int = int(_controller.call("get_selected_menu_index"))
	if index != selected:
		_controller.call("select_menu_index", index)
		return
	if bool(_dossier_rows[index].get_meta("option_enabled", false)):
		_activate_selected()

func _set_dossier_tab(tab: StringName) -> void:
	if tab not in [TAB_SUMMARY, TAB_ACTIONS, TAB_HISTORY]:
		return
	_active_dossier_tab = tab
	_apply_dossier_visibility()
	if tab == TAB_ACTIONS:
		_refresh_dossier_selection()

func _cycle_dossier_tab(direction: int) -> void:
	var tabs: Array[StringName] = [TAB_SUMMARY, TAB_ACTIONS, TAB_HISTORY]
	var index: int = tabs.find(_active_dossier_tab)
	_set_dossier_tab(tabs[posmod(index + signi(direction), tabs.size())])

func _apply_dossier_visibility() -> void:
	if _dossier_panel == null:
		return
	var wide: bool = get_layout_mode() in [LAYOUT_WIDE_TERRAIN, LAYOUT_WIDE_OBJECT]
	_dossier_tabs.visible = not wide
	_summary_scroll.visible = wide or _active_dossier_tab == TAB_SUMMARY
	_action_scroll.visible = wide or _active_dossier_tab == TAB_ACTIONS
	_history_scroll.visible = not wide and _active_dossier_tab == TAB_HISTORY
	_summary_tab.button_pressed = _active_dossier_tab == TAB_SUMMARY
	_dossier_actions_tab.button_pressed = _active_dossier_tab == TAB_ACTIONS
	_history_tab.button_pressed = _active_dossier_tab == TAB_HISTORY

func _close_dossier() -> void:
	if _controller != null:
		_controller.call("close_menu")

func _hide_toast() -> void:
	_toast_panel.visible = false

func _dossier_cost_text(costs: Array) -> String:
	if costs.is_empty():
		return LocalizationScript.t(&"interaction.menu.no_cost")
	var pieces: PackedStringArray = []
	for cost: Dictionary in costs as Array[Dictionary]:
		var cost_id: StringName = cost[&"cost_id"] as StringName
		pieces.append(LocalizationScript.t(
			&"interaction.menu.cost_entry",
			{
				"amount": int(cost[&"amount"]),
				"name": _localized(cost_id, _humanize(cost_id)),
			},
		))
	return LocalizationScript.t(&"interaction.menu.cost", {"cost": " · ".join(pieces)})

func _apply_dossier_layout(viewport_size: Vector2) -> void:
	if _dossier_panel == null:
		return
	var mobile: bool = _mobile_controls != null and bool(_mobile_controls.call("is_mobile_device"))
	var profile: StringName = _dossier_state.get(&"profile", _profile_for_snapshot()) as StringName
	_layout = DossierLayoutScript.layout_for(
		viewport_size, SafeAreaScript.native_insets(viewport_size), _left_handed,
		_ui_scale, mobile, profile, (_snapshot.get(&"options", []) as Array).size()
	)
	if not validate_layout(_layout):
		return
	var popup: Rect2 = _layout[&"popup"] as Rect2
	_dossier_panel.position = popup.position
	_dossier_panel.size = popup.size
	var inspection: Rect2 = _layout[&"inspection"] as Rect2
	_inspection_panel.visible = is_open() and inspection.size.x > 0.0
	if _inspection_panel.visible:
		_inspection_panel.position = inspection.position
		_inspection_panel.size = inspection.size
	var toast: Rect2 = _layout[&"toast"] as Rect2
	_toast_panel.position = toast.position
	_toast_panel.size = toast.size
	var aperture: Rect2 = _layout[&"world_aperture"] as Rect2
	var nearby_count: int = (_dossier_state.get(&"nearby", []) as Array).size()
	var wide: bool = get_layout_mode() in [LAYOUT_WIDE_TERRAIN, LAYOUT_WIDE_OBJECT]
	_nearby_panel.visible = is_open() and wide and nearby_count > 0
	if _nearby_panel.visible:
		var nearby_width: float = minf(300.0 * _ui_scale, aperture.size.x - 12.0)
		var nearby_height: float = (42.0 + nearby_count * 34.0) * _ui_scale
		_nearby_panel.position = Vector2(
			aperture.end.x - nearby_width,
			minf(toast.end.y + 10.0, aperture.end.y - nearby_height),
		)
		_nearby_panel.size = Vector2(nearby_width, nearby_height)
	for row: Button in _dossier_rows:
		row.call("set_ui_scale", _ui_scale)
	for row: Control in _summary_fact_rows:
		row.call("set_ui_scale", _ui_scale)
	for row: Control in _inspection_fact_rows:
		row.call("set_ui_scale", _ui_scale)
	_apply_dossier_visibility()
	_update_dossier_overlay()
	if is_open():
		_set_mobile_modal(true)

func _profile_for_snapshot() -> StringName:
	var subkind: StringName = _snapshot.get(&"target_subkind", &"") as StringName
	return &"terrain" if subkind in [&"terrain", &"plot", &"crop", &"water"] else &"object"

func _dossier_target_title(state: Dictionary) -> String:
	var subkind: StringName = _snapshot[&"target_subkind"] as StringName
	var target_state: Dictionary = _snapshot[&"target_state"] as Dictionary
	if subkind == &"terrain" and target_state.get(&"surface_id") is StringName:
		var surface_id: StringName = target_state[&"surface_id"] as StringName
		return _localized(
			StringName("interaction.value.surface.%s" % str(surface_id)),
			_humanize(surface_id),
		)
	return _localized(state[&"title_key"] as StringName, _humanize(subkind))

func _update_dossier_overlay() -> void:
	if (
		_dossier_overlay == null or not is_open() or not _has_target_anchor
		or not MenuScript.validate(_snapshot) or not validate_layout(_layout)
	):
		return
	var mode: StringName = get_layout_mode()
	_dossier_overlay.call("set_draw_state", {
		&"visible": true,
		&"snapshot_id": _snapshot[&"snapshot_id"],
		&"target_cell": _snapshot[&"target_cell"],
		&"target_id": _snapshot[&"target_id"],
		&"target_screen_anchor": _cached_target_anchor,
		&"panel_rects": get_panel_bounds(),
		&"safe_bounds": _layout[&"safe_bounds"],
		&"viewport_size": _layout[&"viewport"],
		&"camera_generation": _camera_generation,
		&"show_connectors": mode in [LAYOUT_WIDE_TERRAIN, LAYOUT_WIDE_OBJECT],
		&"show_edge_marker": true,
		&"spotlight": mode in [LAYOUT_WIDE_TERRAIN, LAYOUT_WIDE_OBJECT],
	})

func _point_is_in_panel(position: Vector2) -> bool:
	for panel: Rect2 in get_panel_bounds():
		if panel.has_point(position):
			return true
	return false
