extends CanvasLayer

const DAMAGE_COLOR: Color = Color("ff6b3d")
const WARNING_COLOR: Color = Color("ffb12d")
const DAMAGE_FLASH_SECONDS: float = 0.34

var _overlay: ColorRect
var _border: ReferenceRect
var _damage_label: Label
var _shutdown_panel: ColorRect
var _shutdown_title: Label
var _shutdown_detail: Label
var _audio_player: AudioStreamPlayer
var _avatar: Node2D
var _flash_remaining: float = 0.0
var _shutdown_elapsed: float = 0.0
var _audio_trigger_count: int = 0
var _damage_event_count: int = 0
var _shutdown: bool = false
var _reduced_flash: bool = false
var _sfx_enabled: bool = true


func _ready() -> void:
	layer = 4
	_build_damage_overlay()
	_build_shutdown_panel()
	_build_audio_player()
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
	_damage_label.text = "CHASSIS HIT  -%02d  //  %s" % [amount, String(source).to_upper()]
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
	_shutdown_panel.visible = true
	_shutdown_detail.text = (
		"CHASSIS 000 // %s EXPOSURE\nDRIVE AND IMPACT SYSTEMS OFFLINE" % String(source).to_upper()
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
	return _audio_player != null and _audio_player.stream != null


func prepare_for_shutdown() -> void:
	if _audio_player != null:
		_audio_player.stop()
		_audio_player.stream = null


func _build_damage_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "DamageFlash"
	_overlay.position = Vector2.ZERO
	_overlay.size = Vector2(1280.0, 720.0)
	_overlay.color = Color(DAMAGE_COLOR, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_border = ReferenceRect.new()
	_border.name = "DamageBorder"
	_border.position = Vector2(13.0, 13.0)
	_border.size = Vector2(1254.0, 694.0)
	_border.border_width = 8.0
	_border.border_color = Color(DAMAGE_COLOR, 0.0)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_border)

	_damage_label = Label.new()
	_damage_label.name = "DamageLabel"
	_damage_label.position = Vector2(420.0, 616.0)
	_damage_label.size = Vector2(440.0, 46.0)
	_damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_damage_label.text = "CHASSIS HIT"
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
	_shutdown_title.text = "CARDINAL // SHUTDOWN"
	_shutdown_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shutdown_title.add_theme_font_size_override("font_size", 30)
	_shutdown_title.add_theme_color_override("font_color", DAMAGE_COLOR)
	_shutdown_panel.add_child(_shutdown_title)

	_shutdown_detail = Label.new()
	_shutdown_detail.position = Vector2(34.0, 96.0)
	_shutdown_detail.size = Vector2(492.0, 74.0)
	_shutdown_detail.text = "CHASSIS 000\nDRIVE AND IMPACT SYSTEMS OFFLINE"
	_shutdown_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shutdown_detail.add_theme_font_size_override("font_size", 16)
	_shutdown_detail.add_theme_color_override("font_color", WARNING_COLOR)
	_shutdown_panel.add_child(_shutdown_detail)

	var instruction: Label = Label.new()
	instruction.position = Vector2(34.0, 184.0)
	instruction.size = Vector2(492.0, 28.0)
	instruction.text = "PRESS ESC TO RETURN TO TITLE"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_font_size_override("font_size", 13)
	instruction.add_theme_color_override("font_color", Color("d8d0b5"))
	_shutdown_panel.add_child(instruction)


func _build_audio_player() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "ChassisDamageAudio"
	_audio_player.stream = load("res://assets/audio/chassis_damage.wav") as AudioStream
	_audio_player.volume_db = -2.0
	add_child(_audio_player)


func _play_cue(pitch: float) -> void:
	if not _sfx_enabled or _audio_player == null or _audio_player.stream == null:
		return
	_audio_trigger_count += 1
	if DisplayServer.get_name() == "headless":
		return
	_audio_player.stop()
	_audio_player.pitch_scale = pitch
	_audio_player.play()
