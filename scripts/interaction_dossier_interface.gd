extends "res://scripts/harvest_interaction_legacy_presenter.gd"

const AssetCatalogScript: GDScript = preload(
	"res://scripts/interaction_dossier_asset_catalog.gd"
)
const ActionRowScript: GDScript = preload(
	"res://scripts/interaction_dossier_action_row.gd"
)
const FactRowScript: GDScript = preload(
	"res://scripts/interaction_dossier_fact_row.gd"
)
const DossierStateScript: GDScript = preload("res://scripts/interaction_dossier_state.gd")
const OverlayScript: GDScript = preload("res://scripts/interaction_target_link_overlay.gd")

const TAB_SUMMARY: StringName = &"summary"
const TAB_ACTIONS: StringName = &"actions"
const TAB_HISTORY: StringName = &"history"

var _dossier_panel: PanelContainer
var _inspection_panel: PanelContainer
var _nearby_panel: PanelContainer
var _dossier_overlay: Control
var _dossier_thumbnail: TextureRect
var _dossier_title: Label
var _dossier_subtitle: Label
var _dossier_coordinates: Label
var _dossier_tabs: HBoxContainer
var _summary_tab: Button
var _dossier_actions_tab: Button
var _history_tab: Button
var _summary_scroll: ScrollContainer
var _summary_stack: VBoxContainer
var _chip_strip: HBoxContainer
var _action_scroll: ScrollContainer
var _dossier_action_stack: VBoxContainer
var _history_scroll: ScrollContainer
var _history_stack: VBoxContainer
var _dossier_back: Button
var _dossier_activate: Button
var _dossier_close: Button
var _preview_title: Label
var _preview_body: Label
var _inspection_title: Label
var _inspection_body: Label
var _toast_panel: PanelContainer
var _toast_title: Label
var _toast_body: Label
var _toast_timer: Timer
var _dossier_rows: Array[Button] = []
var _summary_fact_rows: Array[Control] = []
var _inspection_fact_rows: Array[Control] = []
var _summary_sections: Array[VBoxContainer] = []
var _summary_section_titles: Array[Label] = []
var _chip_labels: Array[Label] = []
var _history_labels: Array[Label] = []
var _nearby_heading: Label
var _nearby_labels: Array[Label] = []

func _on_dossier_row_pressed(_index: int) -> void:
	pass

func _close_dossier() -> void:
	pass

func _hide_toast() -> void:
	pass

func _set_dossier_tab(_tab: StringName) -> void:
	pass

func _build_dossier_interface() -> void:
	_dossier_overlay = OverlayScript.new() as Control
	_dossier_overlay.name = "SealedTargetLinkOverlay"
	_dossier_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_dossier_overlay)
	_dossier_panel = PanelContainer.new()
	_dossier_panel.name = "DossierPanel"
	_dossier_panel.visible = false
	_dossier_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_dossier_panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(_dossier_panel)
	var shell: VBoxContainer = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 6)
	_dossier_panel.add_child(shell)
	var handle: Label = _label(14, TEAL)
	handle.name = "SheetGrabHandle"
	handle.text = "━━━━"
	handle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	handle.accessibility_name = LocalizationScript.t(&"interaction.dossier.handle")
	shell.add_child(handle)
	var header: HBoxContainer = HBoxContainer.new()
	header.name = "DossierIdentityHeader"
	header.add_theme_constant_override("separation", 10)
	shell.add_child(header)
	_dossier_thumbnail = TextureRect.new()
	_dossier_thumbnail.name = "TargetPortrait"
	_dossier_thumbnail.custom_minimum_size = Vector2(92.0, 92.0)
	_dossier_thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dossier_thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dossier_thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_dossier_thumbnail)
	var identity: VBoxContainer = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 2)
	header.add_child(identity)
	_dossier_subtitle = _label(11, AMBER)
	identity.add_child(_dossier_subtitle)
	_dossier_title = _label(25, TEXT)
	_dossier_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(_dossier_title)
	_dossier_coordinates = _label(12, TEAL)
	identity.add_child(_dossier_coordinates)
	_dossier_tabs = HBoxContainer.new()
	_dossier_tabs.name = "DossierTabs"
	_dossier_tabs.add_theme_constant_override("separation", 6)
	shell.add_child(_dossier_tabs)
	_summary_tab = _dossier_tab_button("SummaryTab", &"interaction.dossier.tab.summary", TAB_SUMMARY)
	_dossier_actions_tab = _dossier_tab_button(
		"ActionsTab", &"interaction.dossier.tab.actions", TAB_ACTIONS
	)
	_history_tab = _dossier_tab_button("HistoryTab", &"interaction.dossier.tab.history", TAB_HISTORY)
	_summary_scroll = _new_scroll("DossierSummaryScroll")
	shell.add_child(_summary_scroll)
	_summary_stack = VBoxContainer.new()
	_summary_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_stack.add_theme_constant_override("separation", 5)
	_summary_scroll.add_child(_summary_stack)
	_chip_strip = HBoxContainer.new()
	_chip_strip.add_theme_constant_override("separation", 4)
	_summary_stack.add_child(_chip_strip)
	for index: int in DossierStateScript.MAX_CHIPS:
		var chip: Label = _label(11, TEXT)
		chip.name = "TruthChip%02d" % index
		chip.visible = false
		chip.add_theme_stylebox_override("normal", _chip_style())
		_chip_strip.add_child(chip)
		_chip_labels.append(chip)
	for section_index: int in DossierStateScript.MAX_SECTIONS:
		var section: VBoxContainer = VBoxContainer.new()
		section.name = "SummarySection%02d" % section_index
		section.visible = false
		section.add_theme_constant_override("separation", 3)
		_summary_stack.add_child(section)
		var section_title: Label = _label(13, AMBER)
		section.add_child(section_title)
		_summary_sections.append(section)
		_summary_section_titles.append(section_title)
	for index: int in DossierStateScript.MAX_SUMMARY_ROWS:
		var fact: Control = FactRowScript.new() as Control
		fact.name = "SummaryFact%02d" % index
		_summary_sections[0].add_child(fact)
		_summary_fact_rows.append(fact)
	_action_scroll = _new_scroll("DossierActionScroll")
	shell.add_child(_action_scroll)
	_dossier_action_stack = VBoxContainer.new()
	_dossier_action_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dossier_action_stack.add_theme_constant_override("separation", 5)
	_action_scroll.add_child(_dossier_action_stack)
	for index: int in OptionScript.MAX_OPTIONS:
		var row: Button = ActionRowScript.new() as Button
		row.name = "DossierAction%02d" % index
		row.pressed.connect(_on_dossier_row_pressed.bind(index))
		_dossier_action_stack.add_child(row)
		_dossier_rows.append(row)
	_history_scroll = _new_scroll("DossierHistoryScroll")
	shell.add_child(_history_scroll)
	_history_stack = VBoxContainer.new()
	_history_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_stack.add_theme_constant_override("separation", 5)
	_history_scroll.add_child(_history_stack)
	var history_heading: Label = _label(14, AMBER)
	history_heading.text = LocalizationScript.t(&"interaction.history.session.title")
	history_heading.set_meta("label_key", &"interaction.history.session.title")
	_history_stack.add_child(history_heading)
	for index: int in DossierStateScript.MAX_HISTORY:
		var history: Label = _label(12, TEXT)
		history.name = "SessionHistory%02d" % index
		history.visible = false
		history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		history.custom_minimum_size.y = 44.0
		_history_stack.add_child(history)
		_history_labels.append(history)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.name = "DossierFooter"
	footer.add_theme_constant_override("separation", 6)
	shell.add_child(footer)
	_dossier_back = _terminal_button("DossierBack", &"interaction.menu.back")
	_dossier_back.pressed.connect(_handle_back)
	footer.add_child(_dossier_back)
	_dossier_activate = _terminal_button("DossierActivate", &"interaction.menu.activate")
	_dossier_activate.pressed.connect(_activate_selected)
	footer.add_child(_dossier_activate)
	_dossier_close = _terminal_button("DossierClose", &"interaction.dossier.close")
	_dossier_close.pressed.connect(_close_dossier)
	footer.add_child(_dossier_close)
	_build_inspection_panel()
	_build_nearby_panel()
	_build_toast()

func _build_inspection_panel() -> void:
	_inspection_panel = PanelContainer.new()
	_inspection_panel.name = "InspectionPanel"
	_inspection_panel.visible = false
	_inspection_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_inspection_panel.add_theme_stylebox_override("panel", _detail_style())
	_root.add_child(_inspection_panel)
	var shell: VBoxContainer = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 7)
	_inspection_panel.add_child(shell)
	_preview_title = _label(17, AMBER)
	shell.add_child(_preview_title)
	_preview_body = _label(12, TEXT)
	_preview_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shell.add_child(_preview_body)
	var divider: HSeparator = HSeparator.new()
	shell.add_child(divider)
	_inspection_title = _label(15, TEAL)
	shell.add_child(_inspection_title)
	_inspection_body = _label(12, MUTED)
	_inspection_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shell.add_child(_inspection_body)
	var scroll: ScrollContainer = _new_scroll("InspectionFactScroll")
	shell.add_child(scroll)
	var facts: VBoxContainer = VBoxContainer.new()
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.add_theme_constant_override("separation", 3)
	scroll.add_child(facts)
	for index: int in ExecutionResultScript.MAX_FACTS:
		var row: Control = FactRowScript.new() as Control
		row.name = "InspectionFact%02d" % index
		facts.add_child(row)
		_inspection_fact_rows.append(row)

func _build_nearby_panel() -> void:
	_nearby_panel = PanelContainer.new()
	_nearby_panel.name = "NearbyInterestPanel"
	_nearby_panel.visible = false
	_nearby_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nearby_panel.add_theme_stylebox_override("panel", _detail_style())
	_root.add_child(_nearby_panel)
	var shell: VBoxContainer = VBoxContainer.new()
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_theme_constant_override("separation", 5)
	_nearby_panel.add_child(shell)
	_nearby_heading = _label(13, AMBER)
	_nearby_heading.text = LocalizationScript.t(&"interaction.dossier.nearby.title")
	shell.add_child(_nearby_heading)
	for index: int in DossierStateScript.MAX_NEARBY:
		var label: Label = _label(12, TEXT)
		label.name = "NearbyInterest%02d" % index
		label.visible = false
		label.custom_minimum_size.y = 32.0
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		shell.add_child(label)
		_nearby_labels.append(label)

func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "DossierResultToast"
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_theme_stylebox_override("panel", _detail_style())
	_root.add_child(_toast_panel)
	var shell: VBoxContainer = VBoxContainer.new()
	_toast_panel.add_child(shell)
	_toast_title = _label(15, AMBER)
	shell.add_child(_toast_title)
	_toast_body = _label(12, TEXT)
	_toast_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shell.add_child(_toast_body)
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(_hide_toast)
	_root.add_child(_toast_timer)

func _dossier_tab_button(
	control_name: String, label_key: StringName, tab: StringName
) -> Button:
	var button: Button = _terminal_button(control_name, label_key)
	button.toggle_mode = true
	button.pressed.connect(_set_dossier_tab.bind(tab))
	_dossier_tabs.add_child(button)
	return button

func _new_scroll(control_name: String) -> ScrollContainer:
	var result: ScrollContainer = ScrollContainer.new()
	result.name = control_name
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	return result

func _chip_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(TEAL, 0.18)
	style.border_color = Color(TEAL, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style
