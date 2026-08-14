extends Node2D

const VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)
const BG_DEEP: Color = Color(0.027, 0.039, 0.071, 1.0)
const BG_MID: Color = Color(0.047, 0.067, 0.118, 1.0)
const GRID_LINE: Color = Color(0.20, 0.38, 0.46, 0.22)
const AMBER: Color = Color(0.95, 0.64, 0.20, 1.0)
const AMBER_SOFT: Color = Color(0.95, 0.64, 0.20, 0.18)
const INK: Color = Color(0.04, 0.055, 0.09, 0.96)
const TEXT: Color = Color(0.90, 0.94, 0.92, 1.0)
const MUTED: Color = Color(0.52, 0.66, 0.68, 1.0)

var _title_panel: Control
var _staging_panel: Control
var _title_label: Label
var _begin_button: Button
var _audio_player: AudioStreamPlayer
var _field_visible: bool = false
var _audio_trigger_count: int = 0


func _ready() -> void:
	get_viewport().size = VIEWPORT_SIZE
	_build_interface()
	queue_redraw()
	print("[PROTO_ISOMETRIC_READY]")


func _unhandled_input(event: InputEvent) -> void:
	if _begin_button.visible and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_begin_pressed()


func _draw() -> void:
	var viewport_size: Vector2 = Vector2(VIEWPORT_SIZE)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), BG_DEEP)
	for band_index: int in range(12):
		var band_y: float = float(band_index) * 60.0
		var blend: float = float(band_index) / 11.0
		var band_color: Color = BG_MID.lerp(BG_DEEP, blend)
		draw_rect(Rect2(0.0, band_y, viewport_size.x, 62.0), band_color)
	for scan_y: int in range(0, VIEWPORT_SIZE.y, 6):
		draw_line(
			Vector2(0.0, float(scan_y)),
			Vector2(viewport_size.x, float(scan_y)),
			Color(1.0, 1.0, 1.0, 0.012),
			1.0
		)
	_draw_isometric_field()
	_draw_interface_accents()


func _draw_isometric_field() -> void:
	var origin: Vector2 = Vector2(905.0, 170.0)
	var half_tile: Vector2 = Vector2(38.0, 19.0)
	for diagonal: int in range(17):
		for row: int in range(9):
			var column: int = diagonal - row
			if column < 0 or column >= 9:
				continue
			var center: Vector2 = (
				origin
				+ Vector2(float(column - row) * half_tile.x, float(column + row) * half_tile.y)
			)
			var elevation: float = float((row * 3 + column * 5) % 4) * 5.0
			if _field_visible and (row + column) % 5 == 0:
				elevation += 12.0
			var tint_step: float = float((row + column) % 4) * 0.025
			var tile_color: Color = Color(
				0.10 + tint_step, 0.22 + tint_step, 0.25 + tint_step, 0.92
			)
			if (row + column) % 6 == 0:
				tile_color = Color(0.28, 0.22, 0.12, 0.96)
			_draw_iso_tile(center, half_tile, elevation, tile_color)


func _draw_iso_tile(
	center: Vector2, half_tile: Vector2, elevation: float, tile_color: Color
) -> void:
	var base_points: PackedVector2Array = PackedVector2Array(
		[
			center + Vector2(0.0, -half_tile.y),
			center + Vector2(half_tile.x, 0.0),
			center + Vector2(0.0, half_tile.y),
			center + Vector2(-half_tile.x, 0.0),
		]
	)
	var top_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in base_points:
		top_points.append(point - Vector2(0.0, elevation))
	if elevation > 0.0:
		draw_colored_polygon(
			PackedVector2Array([top_points[1], base_points[1], base_points[2], top_points[2]]),
			tile_color.darkened(0.36)
		)
		draw_colored_polygon(
			PackedVector2Array([top_points[2], base_points[2], base_points[3], top_points[3]]),
			tile_color.darkened(0.50)
		)
	draw_colored_polygon(top_points, tile_color)
	for edge_index: int in range(4):
		draw_line(top_points[edge_index], top_points[(edge_index + 1) % 4], GRID_LINE, 1.0)


func _draw_interface_accents() -> void:
	draw_line(Vector2(88.0, 78.0), Vector2(388.0, 78.0), AMBER, 3.0)
	draw_line(Vector2(88.0, 78.0), Vector2(88.0, 114.0), AMBER, 3.0)
	draw_circle(Vector2(1115.0, 111.0), 4.0, AMBER)
	draw_circle(Vector2(1140.0, 111.0), 2.0, MUTED)
	draw_line(Vector2(1090.0, 111.0), Vector2(970.0, 111.0), AMBER_SOFT, 2.0)
	if _field_visible:
		draw_arc(Vector2(905.0, 440.0), 104.0, 0.0, TAU, 64, AMBER_SOFT, 3.0)
		draw_arc(Vector2(905.0, 440.0), 72.0, 0.0, TAU, 64, Color(0.32, 0.72, 0.68, 0.25), 2.0)


func _build_interface() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "UILayer"
	add_child(layer)

	var ui_root: Control = Control.new()
	ui_root.name = "UIRoot"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(ui_root)

	_title_panel = Control.new()
	_title_panel.name = "TitlePanel"
	_title_panel.position = Vector2(88.0, 120.0)
	_title_panel.size = Vector2(540.0, 490.0)
	ui_root.add_child(_title_panel)

	var eyebrow: Label = Label.new()
	eyebrow.name = "Eyebrow"
	eyebrow.text = "MGS // INITIAL DEPLOYMENT"
	eyebrow.position = Vector2(0.0, 0.0)
	eyebrow.size = Vector2(520.0, 48.0)
	eyebrow.add_theme_color_override("font_color", AMBER)
	_title_panel.add_child(eyebrow)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "PROTO\nISOMETRIC"
	_title_label.position = Vector2(-4.0, 54.0)
	_title_label.size = Vector2(540.0, 190.0)
	_title_label.add_theme_font_size_override("font_size", 72)
	_title_label.add_theme_color_override("font_color", TEXT)
	_title_label.add_theme_constant_override("line_spacing", -12)
	_title_panel.add_child(_title_label)

	var subtitle: Label = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "A TACTICAL SYSTEM IS TAKING SHAPE."
	subtitle.position = Vector2(0.0, 264.0)
	subtitle.size = Vector2(540.0, 48.0)
	subtitle.add_theme_color_override("font_color", MUTED)
	_title_panel.add_child(subtitle)

	_begin_button = Button.new()
	_begin_button.name = "BeginButton"
	_begin_button.text = "BEGIN  >"
	_begin_button.position = Vector2(0.0, 350.0)
	_begin_button.size = Vector2(300.0, 76.0)
	_begin_button.focus_mode = Control.FOCUS_ALL
	_begin_button.add_theme_color_override("font_color", INK)
	_begin_button.add_theme_color_override("font_hover_color", INK)
	_begin_button.add_theme_color_override("font_pressed_color", TEXT)
	_begin_button.add_theme_stylebox_override("normal", _make_button_style(AMBER, 0.0))
	_begin_button.add_theme_stylebox_override(
		"hover", _make_button_style(Color(1.0, 0.74, 0.34, 1.0), 2.0)
	)
	_begin_button.add_theme_stylebox_override(
		"pressed", _make_button_style(Color(0.34, 0.22, 0.10, 1.0), 0.0)
	)
	_begin_button.pressed.connect(_on_begin_pressed)
	_title_panel.add_child(_begin_button)
	_begin_button.grab_focus()

	_staging_panel = Control.new()
	_staging_panel.name = "StagingPanel"
	_staging_panel.position = Vector2(88.0, 124.0)
	_staging_panel.size = Vector2(520.0, 470.0)
	_staging_panel.visible = false
	ui_root.add_child(_staging_panel)

	var staging_title: Label = Label.new()
	staging_title.name = "StagingTitle"
	staging_title.text = "STAGING FIELD"
	staging_title.position = Vector2(0.0, 36.0)
	staging_title.size = Vector2(520.0, 96.0)
	staging_title.add_theme_font_size_override("font_size", 56)
	staging_title.add_theme_color_override("font_color", TEXT)
	_staging_panel.add_child(staging_title)

	var staging_status: Label = Label.new()
	staging_status.name = "StagingStatus"
	staging_status.text = "GRID ONLINE\nNO UNITS DEPLOYED\nAWAITING NEXT BUILD ORDER"
	staging_status.position = Vector2(0.0, 160.0)
	staging_status.size = Vector2(520.0, 170.0)
	staging_status.add_theme_color_override("font_color", MUTED)
	staging_status.add_theme_constant_override("line_spacing", 8)
	_staging_panel.add_child(staging_status)

	var status_bar: Label = Label.new()
	status_bar.name = "StatusBar"
	status_bar.text = "BUILD 0001   //   GODOT 4.7.1   //   WEB READY"
	status_bar.position = Vector2(88.0, 652.0)
	status_bar.size = Vector2(1100.0, 48.0)
	status_bar.add_theme_color_override("font_color", MUTED)
	ui_root.add_child(status_bar)

	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "BeginAudio"
	_audio_player.stream = load("res://assets/audio/ui_begin.wav") as AudioStream
	_audio_player.volume_db = -5.0
	add_child(_audio_player)


func _make_button_style(color: Color, border_width: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.border_width_left = int(border_width)
	style.border_width_top = int(border_width)
	style.border_width_right = int(border_width)
	style.border_width_bottom = int(border_width)
	style.border_color = TEXT
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	return style


func _on_begin_pressed() -> void:
	if _field_visible:
		return
	_field_visible = true
	_trigger_begin_audio()
	print("[PROTO_ISOMETRIC_BEGIN]")
	get_tree().change_scene_to_file("res://scenes/isometric_map.tscn")


func is_title_visible() -> bool:
	return _title_panel.visible


func is_staging_visible() -> bool:
	return _staging_panel.visible and _field_visible


func get_begin_button() -> Button:
	return _begin_button


func get_title_label() -> Label:
	return _title_label


func is_audio_ready() -> bool:
	return _audio_player != null and _audio_player.stream != null


func get_audio_trigger_count() -> int:
	return _audio_trigger_count


func prepare_for_shutdown() -> void:
	if _audio_player != null:
		_audio_player.stop()
		_audio_player.stream = null


func _trigger_begin_audio() -> void:
	_audio_trigger_count += 1
	if _audio_player.stream != null and DisplayServer.get_name() != "headless":
		_audio_player.play()
