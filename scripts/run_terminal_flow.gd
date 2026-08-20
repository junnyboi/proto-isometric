extends CanvasLayer

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")

const RunSettlementScript: GDScript = preload("res://scripts/run_settlement.gd")
const ModifierServiceScript: GDScript = preload("res://scripts/modifier_service.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")
const CONFIRM_CUE: AudioStream = preload("res://assets/audio/ui_begin.wav")
const AMBER: Color = Color("f5a62d")
const TEAL: Color = Color("4eb6aa")
const SUMMARY_REVEAL_SECONDS: float = 0.24

var _coordinator: RefCounted
var _save_callback: Callable
var _restart_callback: Callable
var _panel: ColorRect
var _title: Label
var _details: Label
var _choice_buttons: Array[Button] = []
var _retry_button: Button
var _summary: Dictionary = {}
var _selected_modifier_id: StringName = &""
var _audio: AudioStreamPlayer
var _mobile_controls: CanvasLayer
var _summary_reveal_count: int = 0


func _ready() -> void:
	layer = 20
	_build_interface()
	add_to_group("localization_listeners")
	_audio = AudioStreamPlayer.new()
	_audio.stream = CONFIRM_CUE
	add_child(_audio)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func configure(
	coordinator: RefCounted,
	save_callback: Callable,
	restart_callback: Callable,
	mobile_controls: CanvasLayer = null
) -> bool:
	if coordinator == null or not save_callback.is_valid() or not restart_callback.is_valid():
		return false
	_coordinator = coordinator
	_save_callback = save_callback
	_restart_callback = restart_callback
	_mobile_controls = mobile_controls
	var existing: Dictionary = (
		coordinator.call("get_profile_value", &"last_run_summary") as Dictionary
	)
	if not existing.is_empty():
		_show_summary(existing)
	return true


func update_context(at_outpost: bool) -> void:
	if _coordinator == null or _panel.visible or not at_outpost:
		return
	if _coordinator.call("get_run_value", &"phase") == RuntimeIdsScript.RUN_PHASE_EXTRACTION_READY:
		var summary: Dictionary = RunSettlementScript.settle_success(_coordinator, _save_callback)
		if not summary.is_empty():
			_show_summary(summary)


func settle_failure() -> bool:
	if _coordinator == null:
		return false
	var summary: Dictionary = RunSettlementScript.settle_failure(_coordinator, _save_callback)
	if summary.is_empty():
		return false
	_show_summary(summary)
	return true


func is_summary_visible() -> bool:
	return _panel != null and _panel.visible


func get_summary() -> Dictionary:
	return _summary.duplicate(true)


func get_choice_buttons() -> Array[Button]:
	return _choice_buttons.duplicate()


func get_retry_button() -> Button:
	return _retry_button


func _show_summary(summary: Dictionary) -> void:
	_summary = summary.duplicate(true)
	_selected_modifier_id = &""
	_refresh_summary_text()
	_panel.visible = true
	_present_summary_reveal()
	if _mobile_controls != null:
		_mobile_controls.call("set_controls_enabled", false)
	_play_cue(1.04 if bool(summary.get(&"succeeded", false)) else 0.72)
	var offer: Array = _coordinator.call("get_profile_value", &"pending_modifier_offer") as Array
	if not offer.is_empty():
		_choice_buttons[0].grab_focus()
	else:
		_retry_button.grab_focus()


func _refresh_summary_text() -> void:
	if _summary.is_empty() or _coordinator == null:
		return
	var succeeded: bool = bool(_summary.get(&"succeeded", false))
	_title.text = LocalizationScript.t(
		&"terminal.success_title" if succeeded else &"terminal.failure_title"
	)
	_details.text = (
		LocalizationScript
		. t(
			&"terminal.details",
			{
				"relays": int(_summary.get(&"relays", 0)),
				"banked_scrap": "%03d" % int(_summary.get(&"banked_scrap", 0)),
				"banked_cores": "%03d" % int(_summary.get(&"banked_cores", 0)),
				"lost_scrap": "%03d" % int(_summary.get(&"lost_scrap", 0)),
				"lost_cores": "%03d" % int(_summary.get(&"lost_cores", 0)),
			}
		)
	)
	var offer: Array = _coordinator.call("get_profile_value", &"pending_modifier_offer") as Array
	for index: int in range(_choice_buttons.size()):
		var button: Button = _choice_buttons[index]
		button.visible = _selected_modifier_id == &"" and index < offer.size()
		if index >= offer.size():
			continue
		var modifier_id: StringName = StringName(str(offer[index]))
		var definition: Resource = ModifierServiceScript.definition(modifier_id)
		button.set_meta("modifier_id", modifier_id)
		button.text = (
			"%s\n%s"
			% [
				LocalizationScript.t(definition.get("title")),
				LocalizationScript.t(definition.get("description")),
			]
		)
	if _selected_modifier_id != &"":
		var selected_definition: Resource = ModifierServiceScript.definition(_selected_modifier_id)
		_retry_button.disabled = false
		_retry_button.text = LocalizationScript.t(
			&"terminal.deploy",
			{"condition": LocalizationScript.t(selected_definition.get("title"))}
		)
	else:
		_retry_button.disabled = not offer.is_empty()
		_retry_button.text = LocalizationScript.t(
			&"terminal.select_condition" if not offer.is_empty() else &"terminal.new_expedition"
		)


func _on_choice_pressed(button: Button) -> void:
	var modifier_id: StringName = button.get_meta("modifier_id", RuntimeIdsScript.MODIFIER_NEUTRAL)
	if not RunSettlementScript.select_modifier(_coordinator, modifier_id, _save_callback):
		return
	_selected_modifier_id = modifier_id
	_refresh_summary_text()
	_retry_button.grab_focus()
	_play_cue(1.16)


func _on_retry_pressed() -> void:
	if RunSettlementScript.launch_next(_coordinator, _save_callback):
		_play_cue(0.92)
		_panel.visible = false
		if _mobile_controls != null:
			_mobile_controls.call("set_controls_enabled", true)
		_restart_callback.call()


func _on_locale_changed(_locale: StringName) -> void:
	if _panel != null and _panel.visible:
		_refresh_summary_text()


func get_presentation_metrics() -> Dictionary:
	return {&"summary_reveals": _summary_reveal_count, &"duration": SUMMARY_REVEAL_SECONDS}


func _present_summary_reveal() -> void:
	if not _panel.is_inside_tree():
		return
	_summary_reveal_count += 1
	_title.modulate.a = 0.0
	_title.scale = Vector2(0.97, 0.97)
	_details.modulate.a = 0.0
	for button: Button in _choice_buttons:
		button.modulate.a = 0.0
	_retry_button.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title, "modulate:a", 1.0, 0.16)
	tween.tween_property(_title, "scale", Vector2.ONE, 0.18)
	tween.tween_property(_details, "modulate:a", 1.0, 0.2).set_delay(0.03)
	for index: int in range(_choice_buttons.size()):
		tween.tween_property(_choice_buttons[index], "modulate:a", 1.0, 0.16).set_delay(
			0.05 + float(index) * 0.03
		)
	tween.tween_property(_retry_button, "modulate:a", 1.0, 0.16).set_delay(0.08)


func _build_interface() -> void:
	_panel = ColorRect.new()
	_panel.name = "RunSummary"
	_panel.position = Vector2(315.0, 105.0)
	_panel.size = Vector2(650.0, 510.0)
	_panel.color = Color(0.025, 0.035, 0.04, 0.96)
	_panel.visible = false
	add_child(_panel)
	_title = _label(
		LocalizationScript.t(&"terminal.success_title"),
		Vector2(36.0, 28.0),
		Vector2(580.0, 55.0),
		34,
		AMBER
	)
	_panel.add_child(_title)
	_details = _label("", Vector2(38.0, 98.0), Vector2(570.0, 118.0), 19, TEAL)
	_panel.add_child(_details)
	for index: int in range(2):
		var button: Button = Button.new()
		button.position = Vector2(38.0 + float(index) * 288.0, 238.0)
		button.size = Vector2(270.0, 125.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_choice_pressed.bind(button))
		_panel.add_child(button)
		_choice_buttons.append(button)
	_retry_button = Button.new()
	_retry_button.name = "RetryButton"
	_retry_button.position = Vector2(185.0, 400.0)
	_retry_button.size = Vector2(280.0, 68.0)
	_retry_button.text = LocalizationScript.t(&"terminal.new_expedition")
	_retry_button.pressed.connect(_on_retry_pressed)
	_panel.add_child(_retry_button)


func _label(text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _play_cue(pitch: float) -> void:
	var preferences: Dictionary = (
		(PlayerPreferencesScript.new() as RefCounted).call("load_preferences") as Dictionary
	)
	if (
		bool(preferences.get(&"sfx_enabled", true))
		and _audio != null
		and DisplayServer.get_name() != "headless"
	):
		_audio.pitch_scale = pitch
		_audio.play()


func _apply_layout() -> void:
	if _panel == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var scale_factor: float = minf(1.0, minf(viewport_size.x / 700.0, viewport_size.y / 560.0))
	_panel.scale = Vector2.ONE * scale_factor
	_panel.position = (viewport_size - _panel.size * scale_factor) * 0.5
