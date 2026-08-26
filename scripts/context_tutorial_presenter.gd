extends CanvasLayer

signal skip_requested
signal resume_requested
signal reset_requested
signal help_visibility_changed(visible: bool)

const BindingScript: GDScript = preload("res://scripts/context_binding_formatter.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const StateScript: GDScript = preload("res://scripts/context_tutorial_state.gd")
const ModalityScript: GDScript = preload("res://scripts/input_modality_tracker.gd")

const AMBER: Color = Color("f5a62d")
const TEAL: Color = Color("4eb6aa")
const INK: Color = Color("11171b")
const VIEWPORT_INSET: float = 12.0
const PROMPT_VISIBLE_SECONDS: float = 6.0

var _director: RefCounted
var _modality_tracker: RefCounted
var _mobile_controls: CanvasLayer
var _card: ColorRect
var _title: Label
var _body: Label
var _binding: Label
var _progress: Label
var _skip: Button
var _more_help: Button
var _veil: ColorRect
var _help_panel: ColorRect
var _help_title: Label
var _help_body: Label
var _resume: Button
var _reset: Button
var _close: Button
var _ui_scale: float = 1.0
var _left_handed: bool = false
var _focus_yielded: bool = false
var _help_open: bool = false
var _previous_focus: Control
var _displayed_lesson: int = -2
var _prompt_elapsed: float = 0.0
var _prompt_active: bool = false


func _ready() -> void:
	layer = 29
	name = "ContextTutorialPresenter"
	_build_card()
	_build_help()
	add_to_group("localization_listeners")
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	_refresh()


func bind(director: RefCounted, tracker: RefCounted, mobile: CanvasLayer = null) -> bool:
	if director == null or tracker == null:
		return false
	_director = director
	_modality_tracker = tracker
	_mobile_controls = mobile
	director.connect("state_changed", _on_state_changed)
	tracker.connect("modality_changed", _on_modality_changed)
	_refresh(true)
	return true


func apply_preferences(snapshot: Dictionary) -> void:
	_ui_scale = clampf(float(snapshot.get(&"ui_scale", 1.0)), 0.85, 1.25)
	_left_handed = bool(snapshot.get(&"left_handed", false))
	_apply_typography()
	_apply_layout()
	_refresh()


func set_focus_yielded(yielded: bool) -> void:
	_focus_yielded = yielded
	if yielded and _help_open:
		_close_help()
	_refresh_visibility()


func reveal_current_prompt() -> bool:
	var lesson: int = get_current_lesson()
	if lesson < 0:
		return false
	_displayed_lesson = lesson
	_prompt_elapsed = 0.0
	_prompt_active = true
	_refresh_visibility()
	return true


func is_help_modal_open() -> bool:
	return _help_open


func _is_prompt_visible() -> bool:
	return _card != null and _card.visible


func blocks_world_touch(point: Vector2) -> bool:
	if _help_open:
		return true
	return (
		_skip != null and _skip.visible and _skip.get_global_rect().has_point(point)
		or _more_help != null
		and _more_help.visible
		and _more_help.get_global_rect().has_point(point)
	)


func get_card_bounds() -> Rect2:
	return Rect2(_card.position, _card.size) if _card != null else Rect2()


func get_help_bounds() -> Rect2:
	return Rect2(_help_panel.position, _help_panel.size) if _help_panel != null else Rect2()


func get_current_lesson() -> int:
	return int(_director.call("get_current_lesson")) if _director != null else -1


func _process(delta: float) -> void:
	if (
		_prompt_active
		and not _focus_yielded
		and not _help_open
		and get_current_lesson() >= 0
	):
		_prompt_elapsed += maxf(delta, 0.0)
		if _prompt_elapsed >= PROMPT_VISIBLE_SECONDS:
			_prompt_active = false
			_refresh_visibility()


func _input(event: InputEvent) -> void:
	if _modality_tracker != null:
		_modality_tracker.call("observe_event", event)
	if not _help_open:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_help()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_focus_next"):
		_cycle_help_focus(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_focus_prev"):
		_cycle_help_focus(-1)
		get_viewport().set_input_as_handled()


func _on_state_changed(_snapshot: Dictionary) -> void:
	_refresh(true)


func _on_modality_changed(_modality: StringName) -> void:
	_refresh()


func _on_locale_changed(_locale: StringName) -> void:
	_refresh()


func _skip_training() -> void:
	skip_requested.emit()


func _resume_training() -> void:
	resume_requested.emit()
	_close_help()


func _reset_training() -> void:
	reset_requested.emit()
	_close_help()


func _open_help() -> void:
	if _help_open or _focus_yielded:
		return
	_help_open = true
	layer = 31
	_previous_focus = get_viewport().gui_get_focus_owner()
	if _mobile_controls != null:
		_mobile_controls.call("_set_modal_input_suppressed", true)
	_refresh()
	_close.grab_focus()
	help_visibility_changed.emit(true)


func _close_help() -> void:
	if not _help_open:
		return
	_help_open = false
	layer = 29
	if _mobile_controls != null:
		_mobile_controls.call("_set_modal_input_suppressed", false)
	if (
		_previous_focus != null
		and is_instance_valid(_previous_focus)
		and _previous_focus.is_visible_in_tree()
		and not _previous_focus.disabled
	):
		_previous_focus.grab_focus()
	_previous_focus = null
	_refresh()
	help_visibility_changed.emit(false)


func _refresh(reveal_new_lesson: bool = false) -> void:
	if _card == null:
		return
	var lesson: int = get_current_lesson()
	if reveal_new_lesson and lesson >= 0 and lesson != _displayed_lesson:
		_prompt_elapsed = 0.0
		_prompt_active = true
	_displayed_lesson = lesson
	var lesson_id: StringName = StateScript.lesson_id(lesson)
	if lesson_id != &"":
		_title.text = LocalizationScript.t("tutorial.lesson.%s.title" % lesson_id)
		_body.text = LocalizationScript.t("tutorial.lesson.%s.body" % lesson_id)
		var modality: StringName = (
			_modality_tracker.call("get_modality") as StringName
			if _modality_tracker != null
			else ModalityScript.KEYBOARD_MOUSE
		)
		_binding.text = BindingScript.format(lesson, modality)
		_progress.text = LocalizationScript.t(
			&"tutorial.progress", {"current": lesson + 1, "total": StateScript.LESSON_COUNT}
		)
	_skip.text = LocalizationScript.t(&"tutorial.action.skip")
	_more_help.text = LocalizationScript.t(&"tutorial.action.more_help")
	_resume.text = LocalizationScript.t(&"tutorial.action.resume")
	_reset.text = LocalizationScript.t(&"tutorial.action.reset")
	_close.text = LocalizationScript.t(&"tutorial.action.close")
	_help_title.text = LocalizationScript.t(&"tutorial.help.title")
	_help_body.text = LocalizationScript.t(&"tutorial.help.body")
	_apply_accessibility(lesson_id)
	_refresh_visibility()


func _refresh_visibility() -> void:
	var lesson: int = get_current_lesson()
	_card.visible = lesson >= 0 and _prompt_active and not _focus_yielded and not _help_open
	_veil.visible = _help_open
	_help_panel.visible = _help_open
	_sync_touch_exclusion()


func _apply_accessibility(lesson_id: StringName) -> void:
	var description: String = (
		LocalizationScript.t("tutorial.lesson.%s.a11y" % lesson_id)
		if lesson_id != &""
		else LocalizationScript.t(&"tutorial.help.title")
	)
	_card.tooltip_text = description
	_skip.accessibility_name = LocalizationScript.t(&"tutorial.action.skip")
	_more_help.accessibility_name = LocalizationScript.t(&"tutorial.action.more_help")
	_resume.accessibility_name = LocalizationScript.t(&"tutorial.action.resume")
	_reset.accessibility_name = LocalizationScript.t(&"tutorial.action.reset")
	_close.accessibility_name = LocalizationScript.t(&"tutorial.action.close")


func _apply_typography() -> void:
	_title.add_theme_font_size_override("font_size", roundi(20.0 * _ui_scale))
	_body.add_theme_font_size_override("font_size", roundi(15.0 * _ui_scale))
	_binding.add_theme_font_size_override("font_size", roundi(15.0 * _ui_scale))
	_progress.add_theme_font_size_override("font_size", roundi(13.0 * _ui_scale))
	_help_title.add_theme_font_size_override("font_size", roundi(26.0 * _ui_scale))
	_help_body.add_theme_font_size_override("font_size", roundi(17.0 * _ui_scale))
	for button: Button in [_skip, _more_help, _resume, _reset, _close]:
		button.add_theme_font_size_override("font_size", roundi(14.0 * _ui_scale))


func _cycle_help_focus(direction: int) -> void:
	var buttons: Array[Button] = [_resume, _reset, _close]
	var focused: Control = get_viewport().gui_get_focus_owner()
	var index: int = buttons.find(focused)
	buttons[posmod(index + direction, buttons.size())].grab_focus()


func _build_card() -> void:
	_card = ColorRect.new()
	_card.name = "ContextTutorialCard"
	_card.color = Color(0.025, 0.035, 0.04, 0.94)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_title = _label("Title", Vector2(16.0, 8.0), Vector2(360.0, 28.0), 20, AMBER)
	_body = _label("Body", Vector2(16.0, 36.0), Vector2(420.0, 42.0), 15, Color("e6eeee"))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_binding = _label("Binding", Vector2(16.0, 80.0), Vector2(240.0, 26.0), 15, TEAL)
	_progress = _label("Progress", Vector2(260.0, 80.0), Vector2(100.0, 26.0), 13, Color("a9b5b5"))
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card.add_child(_title)
	_card.add_child(_body)
	_card.add_child(_binding)
	_card.add_child(_progress)
	_skip = _button("Skip", _skip_training)
	_more_help = _button("MoreHelp", _open_help)
	_card.add_child(_skip)
	_card.add_child(_more_help)


func _build_help() -> void:
	_veil = ColorRect.new()
	_veil.name = "TutorialHelpVeil"
	_veil.color = Color(0.0, 0.0, 0.0, 0.68)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_veil)
	_help_panel = ColorRect.new()
	_help_panel.name = "TutorialHelpPanel"
	_help_panel.color = Color(0.025, 0.035, 0.04, 0.99)
	_help_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_help_panel)
	_help_title = _label("HelpTitle", Vector2(24.0, 20.0), Vector2(500.0, 40.0), 26, AMBER)
	_help_body = _label("HelpBody", Vector2(24.0, 72.0), Vector2(500.0, 230.0), 17, Color("e6eeee"))
	_help_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_panel.add_child(_help_title)
	_help_panel.add_child(_help_body)
	_resume = _button("Resume", _resume_training)
	_reset = _button("Reset", _reset_training)
	_close = _button("Close", _close_help)
	_help_panel.add_child(_resume)
	_help_panel.add_child(_reset)
	_help_panel.add_child(_close)
	_veil.visible = false
	_help_panel.visible = false


func _label(
	label_name: String, position: Vector2, size: Vector2, font_size: int, color: Color
) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(button_name: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(callback)
	return button


func _apply_layout() -> void:
	if _card == null:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var layout: Dictionary = layout_for(viewport, _ui_scale, _left_handed)
	var card: Rect2 = layout[&"card"] as Rect2
	_card.position = card.position
	_card.size = card.size
	_layout_card(card.size)
	_veil.position = Vector2.ZERO
	_veil.size = viewport
	var help: Rect2 = layout[&"help"] as Rect2
	_help_panel.position = help.position
	_help_panel.size = help.size
	_layout_help(help.size)
	_sync_touch_exclusion()


func _sync_touch_exclusion() -> void:
	if _mobile_controls == null:
		return
	var actions: Rect2 = Rect2()
	if _card.visible:
		var top_left: Vector2 = _card.position + _skip.position
		var bottom_right: Vector2 = _card.position + _more_help.position + _more_help.size
		actions = Rect2(top_left, bottom_right - top_left)
	_mobile_controls.call("_set_tutorial_touch_exclusion", actions, actions.has_area())


func _layout_card(size: Vector2) -> void:
	var actions_width: float = minf(202.0 * _ui_scale, size.x * 0.38)
	var content_width: float = size.x - actions_width - 28.0
	_title.size.x = content_width
	_body.size.x = content_width
	_binding.size.x = content_width * 0.68
	_progress.position.x = 16.0 + content_width * 0.68
	_progress.size.x = content_width * 0.32
	var button_height: float = 40.0 * _ui_scale
	var button_x: float = size.x - actions_width - 12.0
	_skip.position = Vector2(button_x, 12.0)
	_skip.size = Vector2(actions_width, button_height)
	_more_help.position = Vector2(button_x, 18.0 + button_height)
	_more_help.size = Vector2(actions_width, button_height)


func _layout_help(size: Vector2) -> void:
	var margin: float = 24.0
	_help_title.size.x = size.x - margin * 2.0
	_help_body.size = Vector2(size.x - margin * 2.0, maxf(size.y - 184.0, 120.0))
	var gap: float = 10.0
	var button_height: float = 44.0 * _ui_scale
	var button_width: float = (size.x - margin * 2.0 - gap * 2.0) / 3.0
	var y: float = size.y - button_height - 22.0
	for index: int in 3:
		var button: Button = [_resume, _reset, _close][index] as Button
		button.position = Vector2(margin + (button_width + gap) * index, y)
		button.size = Vector2(button_width, button_height)


static func layout_for(viewport: Vector2, ui_scale: float, left_handed: bool) -> Dictionary:
	var safe: Rect2 = Rect2(
		Vector2(VIEWPORT_INSET, VIEWPORT_INSET),
		Vector2(maxf(viewport.x - VIEWPORT_INSET * 2.0, 1.0), maxf(viewport.y - 24.0, 1.0)),
	)
	var portrait: bool = viewport.y > viewport.x
	var compact_landscape: bool = not portrait and viewport.y <= 420.0
	var desired_width: float = 360.0 if compact_landscape else (480.0 if portrait else 650.0)
	var card_width: float = minf(safe.size.x, desired_width)
	var desired_height: float = (
		116.0 if compact_landscape else (130.0 if portrait else 116.0 * ui_scale)
	)
	var card_height: float = minf(safe.size.y, desired_height)
	var card_x: float = safe.position.x + (safe.size.x - card_width) * 0.5
	var card_y: float = safe.end.y - card_height - VIEWPORT_INSET
	if compact_landscape:
		card_y = safe.position.y + 8.0
	elif portrait:
		card_y = safe.position.y + (safe.size.y - card_height) * (0.53 if left_handed else 0.55)
	var help_width: float = minf(safe.size.x, 620.0 * ui_scale)
	var help_height: float = minf(safe.size.y, 500.0 * ui_scale)
	return {
		&"safe": safe,
		&"card": Rect2(Vector2(card_x, card_y), Vector2(card_width, card_height)),
		&"help": Rect2(
			safe.position + (safe.size - Vector2(help_width, help_height)) * 0.5,
			Vector2(help_width, help_height),
		),
	}
