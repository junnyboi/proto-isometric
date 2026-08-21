extends CanvasLayer

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")

const DAMAGE_COLOR: Color = Color("ff6b3d")
const WARNING_COLOR: Color = Color("ffb12d")
const DAMAGE_FLASH_SECONDS: float = 0.34
const DAMAGE_CUE: AudioStream = preload("res://assets/audio/chassis_damage.wav")

var _overlay: ColorRect
var _border: ReferenceRect
var _damage_label: Label
var _shutdown_panel: ColorRect
var _shutdown_title: Label
var _shutdown_detail: Label
var _shutdown_instruction: Label
var _avatar: Node2D
var _flash_remaining: float = 0.0
var _shutdown_elapsed: float = 0.0
var _audio_trigger_count: int = 0
var _damage_event_count: int = 0
var _shutdown: bool = false
var _reduced_flash: bool = false
var _sfx_enabled: bool = true
var _last_damage_amount: int = 0
var _last_damage_source: StringName = &"hazard"
var _shutdown_source: StringName = &"hazard"


func _ready() -> void:
	layer = 4
	_build_damage_overlay()
	_build_shutdown_panel()
	add_to_group("localization_listeners")
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	call_deferred("_bind_accessibility")


func bind_avatar(avatar: Node2D) -> void:
	_avatar = avatar


func advance(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	_flash_remaining = maxf(_flash_remaining - step, 0.0)
	var ratio: float = _flash_remaining / DAMAGE_FLASH_SECONDS
	_overlay.color.a = ratio * 0.16
	_border.border_color.a = ratio * 0.82
	_damage_label.modulate.a = ratio
	if _avatar != null and not _shutdown:
		_avatar.modulate = Color.WHITE.lerp(DAMAGE_COLOR, ratio * 0.62)
	if _shutdown:
		_shutdown_elapsed += step
		var pulse: float = 0.82 + sin(_shutdown_elapsed * 4.2) * 0.18
		_shutdown_title.modulate = Color(1.0, pulse, pulse * 0.55, 1.0)


func show_damage(
	amount: int,
	source: StringName,
	lethal: bool = false,
	duration_scale: float = 1.0,
) -> void:
	_damage_event_count += 1
	var preference_scale: float = 0.45 if _reduced_flash else 1.0
	_flash_remaining = DAMAGE_FLASH_SECONDS * clampf(duration_scale, 0.25, 1.0) * preference_scale
	_overlay.color.a = 0.07 if _reduced_flash else 0.16
	_border.border_color.a = 0.38 if _reduced_flash else 0.82
	_damage_label.modulate.a = 1.0
	_last_damage_amount = amount
	_last_damage_source = source
	_damage_label.text = LocalizationScript.t(
		&"chassis.damage",
		{"damage": "%02d" % amount, "source": LocalizationScript.t("source.%s" % source)}
	)
	if _avatar != null:
		_avatar.modulate = DAMAGE_COLOR
	if not lethal:
		_play_cue(0.98 + float(_damage_event_count % 3) * 0.025)


func _bind_accessibility() -> void:
	var panel: Node = get_tree().get_first_node_in_group("accessibility_panel")
	if panel == null:
		return
	_apply_preferences(panel.call("get_preferences") as Dictionary)
	panel.connect("preferences_changed", _apply_preferences)


func _apply_preferences(snapshot: Dictionary) -> void:
	_reduced_flash = bool(snapshot.get(&"reduced_flash", false))
	_sfx_enabled = bool(snapshot.get(&"sfx_enabled", true))


func enter_shutdown(source: StringName) -> void:
	if _shutdown:
		return
	_shutdown = true
	_shutdown_elapsed = 0.0
	_shutdown_source = source
	_shutdown_panel.visible = true
	_shutdown_detail.text = LocalizationScript.t(
		&"chassis.shutdown_detail", {"source": LocalizationScript.t("source.%s" % source)}
	)
	if _avatar != null:
		_avatar.modulate = Color("6f554d")
		_avatar.rotation = -0.055
		_avatar.scale = Vector2(1.0, 0.94)
	_play_cue(0.74)


func is_shutdown_visible() -> bool:
	return _shutdown_panel.visible


func get_flash_alpha() -> float:
	return _overlay.color.a


func get_audio_trigger_count() -> int:
	return _audio_trigger_count


func get_damage_event_count() -> int:
	return _damage_event_count


func is_audio_ready() -> bool:
	return DAMAGE_CUE != null and get_node_or_null("/root/AudioService") != null


func prepare_for_shutdown() -> void:
	pass


func _build_damage_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "DamageFlash"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(DAMAGE_COLOR, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_border = ReferenceRect.new()
	_border.name = "DamageBorder"
	_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_border.offset_left = 13.0
	_border.offset_top = 13.0
	_border.offset_right = -13.0
	_border.offset_bottom = -13.0
	_border.border_width = 8.0
	_border.border_color = Color(DAMAGE_COLOR, 0.0)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_border)

	_damage_label = Label.new()
	_damage_label.name = "DamageLabel"
	_damage_label.position = Vector2(420.0, 616.0)
	_damage_label.size = Vector2(440.0, 46.0)
	_damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_damage_label.text = LocalizationScript.t(
		&"chassis.damage", {"damage": "00", "source": LocalizationScript.t(&"source.hazard")}
	)
	_damage_label.add_theme_font_size_override("font_size", 20)
	_damage_label.add_theme_color_override("font_color", Color.WHITE)
	_damage_label.modulate.a = 0.0
	_damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_label)


func _build_shutdown_panel() -> void:
	_shutdown_panel = ColorRect.new()
	_shutdown_panel.name = "ShutdownPanel"
	_shutdown_panel.position = Vector2(360.0, 244.0)
	_shutdown_panel.size = Vector2(560.0, 232.0)
	_shutdown_panel.color = Color(0.03, 0.02, 0.02, 0.93)
	_shutdown_panel.visible = false
	_shutdown_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shutdown_panel)

	_shutdown_title = Label.new()
	_shutdown_title.position = Vector2(34.0, 24.0)
	_shutdown_title.size = Vector2(492.0, 62.0)
	_shutdown_title.text = LocalizationScript.t(&"chassis.shutdown_title")
	_shutdown_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shutdown_title.add_theme_font_size_override("font_size", 30)
	_shutdown_title.add_theme_color_override("font_color", DAMAGE_COLOR)
	_shutdown_panel.add_child(_shutdown_title)

	_shutdown_detail = Label.new()
	_shutdown_detail.position = Vector2(34.0, 96.0)
	_shutdown_detail.size = Vector2(492.0, 74.0)
	_shutdown_detail.text = LocalizationScript.t(&"chassis.shutdown_generic")
	_shutdown_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shutdown_detail.add_theme_font_size_override("font_size", 16)
	_shutdown_detail.add_theme_color_override("font_color", WARNING_COLOR)
	_shutdown_panel.add_child(_shutdown_detail)

	_shutdown_instruction = Label.new()
	_shutdown_instruction.position = Vector2(34.0, 184.0)
	_shutdown_instruction.size = Vector2(492.0, 28.0)
	_shutdown_instruction.text = LocalizationScript.t(&"chassis.return_title")
	_shutdown_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shutdown_instruction.add_theme_font_size_override("font_size", 13)
	_shutdown_instruction.add_theme_color_override("font_color", Color("d8d0b5"))
	_shutdown_panel.add_child(_shutdown_instruction)


func _play_cue(pitch: float) -> void:
	if not _sfx_enabled or DAMAGE_CUE == null:
		return
	_audio_trigger_count += 1
	var service: Node = get_node_or_null("/root/AudioService")
	if service != null:
		var priority: int = 3 if pitch < 0.8 else 2
		service.call(
			"play_global",
			DAMAGE_CUE,
			AudioServiceScript.BUS_WALKER,
			pitch,
			-2.0,
			priority,
		)


func _apply_layout() -> void:
	if _shutdown_panel == null:
		return
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var panel_scale: float = minf(1.0, minf(viewport.x / 600.0, viewport.y / 280.0))
	_shutdown_panel.scale = Vector2.ONE * panel_scale
	_shutdown_panel.position = (viewport - _shutdown_panel.size * panel_scale) * 0.5
	_damage_label.position = Vector2((viewport.x - _damage_label.size.x) * 0.5, viewport.y - 104.0)


func _on_locale_changed(_locale: StringName) -> void:
	if _shutdown_title == null:
		return
	_shutdown_title.text = LocalizationScript.t(&"chassis.shutdown_title")
	_shutdown_instruction.text = LocalizationScript.t(&"chassis.return_title")
	_shutdown_detail.text = (
		LocalizationScript.t(
			&"chassis.shutdown_detail",
			{"source": LocalizationScript.t("source.%s" % _shutdown_source)}
		)
		if _shutdown
		else LocalizationScript.t(&"chassis.shutdown_generic")
	)
	if _last_damage_amount > 0:
		_damage_label.text = (
			LocalizationScript
			. t(
				&"chassis.damage",
				{
					"damage": "%02d" % _last_damage_amount,
					"source": LocalizationScript.t("source.%s" % _last_damage_source),
				}
			)
		)
