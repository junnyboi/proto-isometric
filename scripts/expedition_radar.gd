extends Control

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const FrozenTundraScript: GDScript = preload("res://scripts/frozen_tundra.gd")
const LavaFieldsScript: GDScript = preload("res://scripts/lava_fields.gd")
const RADAR_FONT: Font = preload("res://assets/fonts/NotoSansCJKsc-ProtoIsometric.otf")

const AMBER: Color = Color("f5a62d")
const TEAL: Color = Color("4eb6aa")
const BONE: Color = Color("d8d0b5")
const ICE: Color = Color("63d5ee")
const LAVA: Color = Color("ff6b2c")
const RADAR_CENTER: Vector2 = Vector2(119.0, 80.0)
const RADAR_RADIUS: float = 58.0
const RADAR_SIZE: Vector2 = Vector2(238.0, 188.0)
const DIRECTION_NAMES: Array[StringName] = [&"E", &"SE", &"S", &"SW", &"W", &"NW", &"N", &"NE"]

var _coordinator: RefCounted
var _objectives: Array = []
var _player_cell: Vector2i = Vector2i.ZERO
var _completed_relays: int = 0
var _redraw_request_count: int = 0


func _ready() -> void:
	name = "ExpeditionRadar"
	size = RADAR_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("localization_listeners")
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func configure(coordinator: RefCounted) -> bool:
	_coordinator = coordinator
	if coordinator == null:
		_objectives.clear()
		return false
	_objectives = coordinator.call("get_run_value", &"relay_objectives") as Array
	return sync_state(
		coordinator.call("get_run_value", &"player_cell") as Vector2i,
		int(coordinator.call("get_run_value", &"completed_relays")),
		true,
	)


func sync_state(player_cell: Vector2i, completed_relays: int, force: bool = false) -> bool:
	var bounded_completed: int = clampi(completed_relays, 0, _objectives.size())
	if not force and player_cell == _player_cell and bounded_completed == _completed_relays:
		return false
	_player_cell = player_cell
	_completed_relays = bounded_completed
	_request_redraw()
	return true


func get_objective_count() -> int:
	return _objectives.size()


func get_redraw_request_count() -> int:
	return _redraw_request_count


func get_biome_marker_count() -> int:
	return 2


func get_biome_navigation(player: Vector2i, biome: StringName) -> Dictionary:
	return biome_navigation(player, biome)


static func biome_navigation(player: Vector2i, biome: StringName) -> Dictionary:
	var target: Vector2i = player
	var inside: bool = false
	if biome == FrozenTundraScript.BIOME_FROZEN:
		inside = FrozenTundraScript.contains(player)
		target.y = mini(player.y, FrozenTundraScript.FROZEN_ENTRY_Y)
	elif biome == LavaFieldsScript.BIOME_LAVA:
		inside = LavaFieldsScript.contains(player) and not FrozenTundraScript.contains(player)
		target.x = mini(player.x, LavaFieldsScript.LAVA_ENTRY_X)
		target.y = maxi(player.y, FrozenTundraScript.FROZEN_ENTRY_Y + 1)
	else:
		return {}
	var grid_delta: Vector2i = target - player
	var screen_delta: Vector2 = _project_grid_delta(grid_delta)
	return {
		&"biome": biome,
		&"target": target,
		&"inside": inside,
		&"distance": maxi(absi(grid_delta.x), absi(grid_delta.y)),
		&"direction": _direction_name(screen_delta),
		&"screen_delta": screen_delta,
	}


func _draw() -> void:
	if _coordinator == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.04, 0.9))
	draw_rect(Rect2(Vector2.ZERO, size), Color(TEAL, 0.42), false, 2.0)
	draw_circle(RADAR_CENTER, RADAR_RADIUS, Color(0.015, 0.025, 0.03, 0.72))
	draw_arc(RADAR_CENTER, RADAR_RADIUS, 0.0, TAU, 48, Color(TEAL, 0.34), 1.0)
	draw_circle(RADAR_CENTER, 4.5, BONE)
	_draw_objectives()
	_draw_biome_marker(FrozenTundraScript.BIOME_FROZEN, ICE, 154.0)
	_draw_biome_marker(LavaFieldsScript.BIOME_LAVA, LAVA, 174.0)
	draw_string(
		RADAR_FONT,
		Vector2(10.0, 20.0),
		LocalizationScript.t(&"radar.route", {"completed": _completed_relays}),
		HORIZONTAL_ALIGNMENT_LEFT,
		142.0,
		14,
		BONE,
	)


func _draw_objectives() -> void:
	for index: int in range(_objectives.size()):
		var cell_value: Array = (_objectives[index] as Dictionary)[&"cell"] as Array
		var grid_delta: Vector2i = Vector2i(
			roundi(float(cell_value[0])) - _player_cell.x,
			roundi(float(cell_value[1])) - _player_cell.y,
		)
		var point: Vector2 = (
			RADAR_CENTER + _project_grid_delta(grid_delta).limit_length(RADAR_RADIUS - 5.0)
		)
		var color: Color = TEAL if index < _completed_relays else AMBER
		draw_line(RADAR_CENTER, point, Color(color, 0.18), 1.0)
		draw_circle(point, 5.0 if index == _completed_relays else 3.5, color)


func _draw_biome_marker(biome: StringName, color: Color, row_y: float) -> void:
	var navigation: Dictionary = biome_navigation(_player_cell, biome)
	var screen_delta: Vector2 = navigation[&"screen_delta"] as Vector2
	var point: Vector2 = RADAR_CENTER
	if not bool(navigation[&"inside"]):
		point += screen_delta.normalized() * (RADAR_RADIUS - 3.0)
		_draw_arrow(point, screen_delta.angle(), color)
	else:
		draw_circle(point, 8.0, Color(color, 0.34), false, 2.0)
	var biome_key: StringName = (
		&"radar.biome.tundra" if biome == FrozenTundraScript.BIOME_FROZEN else &"radar.biome.lava"
	)
	var text: String = (
		LocalizationScript
		. t(
			&"radar.biome_here" if bool(navigation[&"inside"]) else &"radar.biome_direction",
			{
				"name": LocalizationScript.t(biome_key),
				"direction": LocalizationScript.t("direction.%s" % navigation[&"direction"]),
				"distance": navigation[&"distance"],
			},
		)
	)
	draw_circle(Vector2(11.0, row_y - 4.0), 3.5, color)
	draw_string(RADAR_FONT, Vector2(20.0, row_y), text, HORIZONTAL_ALIGNMENT_LEFT, 210.0, 12, color)


func _draw_arrow(point: Vector2, angle: float, color: Color) -> void:
	var forward: Vector2 = Vector2.from_angle(angle)
	var side: Vector2 = forward.orthogonal()
	var points: PackedVector2Array = PackedVector2Array(
		[
			point + forward * 8.0,
			point - forward * 5.0 + side * 5.0,
			point - forward * 5.0 - side * 5.0,
		]
	)
	draw_colored_polygon(points, color)


static func _project_grid_delta(delta: Vector2i) -> Vector2:
	return Vector2(float(delta.x - delta.y), float(delta.x + delta.y) * 0.5)


static func _direction_name(screen_delta: Vector2) -> StringName:
	if screen_delta.is_zero_approx():
		return &"IDLE"
	var index: int = posmod(roundi(screen_delta.angle() / (PI / 4.0)), 8)
	return DIRECTION_NAMES[index]


static func layout_for(viewport: Vector2) -> Dictionary:
	var portrait: bool = viewport.y > viewport.x
	var short_landscape: bool = not portrait and viewport.y < 500.0
	var scale_value: float = minf(1.0, viewport.x / (560.0 if portrait else 1280.0))
	var layout_position: Vector2
	if short_landscape:
		layout_position = Vector2((viewport.x - RADAR_SIZE.x * scale_value) * 0.5, 18.0)
	elif portrait:
		layout_position = Vector2(viewport.x - RADAR_SIZE.x * scale_value - 18.0, viewport.y * 0.59)
	else:
		layout_position = Vector2(viewport.x - RADAR_SIZE.x * scale_value - 18.0, 298.0)
	return {
		&"position": layout_position,
		&"scale": scale_value,
		&"rect": Rect2(layout_position, RADAR_SIZE * scale_value),
	}


func _on_locale_changed(_locale: StringName) -> void:
	_request_redraw()


func _apply_layout() -> void:
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var layout: Dictionary = layout_for(viewport)
	scale = Vector2.ONE * float(layout[&"scale"])
	position = layout[&"position"] as Vector2


func _request_redraw() -> void:
	_redraw_request_count += 1
	queue_redraw()
