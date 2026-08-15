extends Node2D

const GRID_SIZE: Vector2i = Vector2i(9, 9)
const TILE_SIZE: Vector2 = Vector2(90.0, 45.0)
const MAP_ORIGIN: Vector2 = Vector2(760.0, 116.0)
const WALK_SPEED: float = 190.0
const RUN_MULTIPLIER: float = 1.5

const SAND: Color = Color("d79a45")
const SAND_LIGHT: Color = Color("e8b861")
const SALT: Color = Color("d8d0b5")
const ROCK: Color = Color("934d35")
const RUIN: Color = Color("39454a")
const TEAL: Color = Color("4eb6aa")
const AMBER: Color = Color("f5a62d")
const INK: Color = Color("11151a")
const GRID_LINE: Color = Color(0.18, 0.12, 0.08, 0.32)

var _terrain: Dictionary = {}
var _elevation: Dictionary = {}
var _blocked: Dictionary = {}
var _robot_grid: Vector2i = Vector2i(3, 6)
var _robot_visual_position: Vector2
var _last_screen_direction: Vector2i = Vector2i(1, 1)
var _facing: StringName = &"SE"
var _is_moving: bool = false
var _is_running: bool = false
var _status_label: Label


func _ready() -> void:
	_generate_desert()
	_robot_visual_position = grid_to_screen(_robot_grid)
	_build_interface()
	queue_redraw()
	print("[ISOMETRIC_MAP_READY]")


func _process(delta: float) -> void:
	var screen_direction: Vector2i = _read_screen_direction()
	if screen_direction == Vector2i.ZERO:
		if _is_moving:
			_is_moving = false
			_is_running = false
			_update_drive_status()
			queue_redraw()
		return
	move_screen_direction(screen_direction, delta, _is_run_pressed())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("24170f"))
	_draw_horizon()
	for diagonal: int in range(GRID_SIZE.x + GRID_SIZE.y - 1):
		for y: int in range(GRID_SIZE.y):
			var x: int = diagonal - y
			if x < 0 or x >= GRID_SIZE.x:
				continue
			_draw_tile(Vector2i(x, y))
	_draw_drive_vector()
	_draw_robot(_robot_visual_position)


func grid_to_screen(cell: Vector2i) -> Vector2:
	var elevation_pixels: float = float(_elevation.get(cell, 0)) * 10.0
	return (
		MAP_ORIGIN
		+ Vector2(
			float(cell.x - cell.y) * TILE_SIZE.x * 0.5,
			float(cell.x + cell.y) * TILE_SIZE.y * 0.5 - elevation_pixels,
		)
	)


func screen_to_grid(point: Vector2) -> Vector2i:
	var local: Vector2 = point - MAP_ORIGIN
	var grid_x: float = local.x / TILE_SIZE.x + local.y / TILE_SIZE.y
	var grid_y: float = local.y / TILE_SIZE.y - local.x / TILE_SIZE.x
	return Vector2i(roundi(grid_x), roundi(grid_y))


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE.x and cell.y < GRID_SIZE.y


func is_walkable(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and not bool(_blocked.get(cell, false))


func move_screen_direction(screen_direction: Vector2i, delta: float, running: bool = false) -> bool:
	var normalized_direction: Vector2i = Vector2i(
		clampi(screen_direction.x, -1, 1), clampi(screen_direction.y, -1, 1)
	)
	if normalized_direction == Vector2i.ZERO:
		return false
	if not can_move_screen_direction(normalized_direction):
		_is_moving = false
		_is_running = false
		_update_status("VECTOR %s // BLOCKED" % direction_name(normalized_direction))
		return false

	_last_screen_direction = normalized_direction
	_facing = direction_name(normalized_direction)
	_is_moving = true
	_is_running = running
	var speed: float = WALK_SPEED * (RUN_MULTIPLIER if running else 1.0)
	var travel: Vector2 = Vector2(normalized_direction).normalized() * speed * delta
	_robot_visual_position += travel
	_robot_grid = screen_to_grid(_robot_visual_position)
	_update_drive_status()
	queue_redraw()
	return true


func can_move_screen_direction(screen_direction: Vector2i) -> bool:
	var delta: Vector2i = screen_direction_to_grid_delta(screen_direction)
	if delta == Vector2i.ZERO:
		return false
	var target: Vector2i = _robot_grid + delta
	if not is_walkable(target):
		return false
	if delta.x != 0 and delta.y != 0:
		return (
			is_walkable(_robot_grid + Vector2i(delta.x, 0))
			and is_walkable(_robot_grid + Vector2i(0, delta.y))
		)
	return true


func screen_direction_to_grid_delta(screen_direction: Vector2i) -> Vector2i:
	var direction: Vector2i = Vector2i(
		clampi(screen_direction.x, -1, 1), clampi(screen_direction.y, -1, 1)
	)
	var directions: Dictionary = {
		Vector2i(0, -1): Vector2i(-1, -1),
		Vector2i(1, -1): Vector2i(0, -1),
		Vector2i(1, 0): Vector2i(1, -1),
		Vector2i(1, 1): Vector2i(1, 0),
		Vector2i(0, 1): Vector2i(1, 1),
		Vector2i(-1, 1): Vector2i(0, 1),
		Vector2i(-1, 0): Vector2i(-1, 1),
		Vector2i(-1, -1): Vector2i(-1, 0),
	}
	return directions.get(direction, Vector2i.ZERO) as Vector2i


func direction_name(screen_direction: Vector2i) -> StringName:
	var names: Dictionary = {
		Vector2i(0, -1): &"N",
		Vector2i(1, -1): &"NE",
		Vector2i(1, 0): &"E",
		Vector2i(1, 1): &"SE",
		Vector2i(0, 1): &"S",
		Vector2i(-1, 1): &"SW",
		Vector2i(-1, 0): &"W",
		Vector2i(-1, -1): &"NW",
	}
	return names.get(screen_direction, &"IDLE") as StringName


func get_robot_grid() -> Vector2i:
	return _robot_grid


func place_robot(cell: Vector2i) -> bool:
	if not is_walkable(cell):
		return false
	_robot_grid = cell
	_robot_visual_position = grid_to_screen(cell)
	_is_moving = false
	_is_running = false
	_update_drive_status()
	queue_redraw()
	return true


func get_robot_position() -> Vector2:
	return _robot_visual_position


func get_facing() -> StringName:
	return _facing


func is_robot_moving() -> bool:
	return _is_moving


func get_grid_size() -> Vector2i:
	return GRID_SIZE


func _generate_desert() -> void:
	var blockers: Array[Vector2i] = [
		Vector2i(1, 2),
		Vector2i(2, 2),
		Vector2i(2, 3),
		Vector2i(6, 4),
		Vector2i(6, 5),
		Vector2i(7, 5),
		Vector2i(4, 7),
	]
	for cell: Vector2i in blockers:
		_blocked[cell] = true

	for y: int in range(GRID_SIZE.y):
		for x: int in range(GRID_SIZE.x):
			var cell: Vector2i = Vector2i(x, y)
			var value: int = posmod(x * 19 + y * 31 + x * y * 7, 100)
			var terrain_id: StringName = &"sand"
			if bool(_blocked.get(cell, false)):
				terrain_id = &"rock"
			elif value < 12:
				terrain_id = &"salt"
			elif value < 20:
				terrain_id = &"ruin"
			_terrain[cell] = terrain_id
			_elevation[cell] = 2 if terrain_id == &"rock" else (1 if terrain_id == &"ruin" else 0)


func _read_screen_direction() -> Vector2i:
	var horizontal: int = 0
	var vertical: int = 0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		horizontal -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		horizontal += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		vertical -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		vertical += 1
	return Vector2i(horizontal, vertical)


func _is_run_pressed() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)


func _draw_horizon() -> void:
	for band: int in range(9):
		var color: Color = Color("6f3925").lerp(Color("24170f"), float(band) / 8.0)
		draw_rect(Rect2(0.0, float(band) * 42.0, 1280.0, 44.0), color)
	draw_colored_polygon(
		PackedVector2Array(
			[
				Vector2(0.0, 265.0),
				Vector2(180.0, 190.0),
				Vector2(360.0, 240.0),
				Vector2(520.0, 180.0),
				Vector2(740.0, 255.0),
				Vector2(960.0, 195.0),
				Vector2(1280.0, 270.0),
				Vector2(1280.0, 390.0),
				Vector2(0.0, 390.0),
			]
		),
		Color("4b271d"),
	)


func _draw_tile(cell: Vector2i) -> void:
	var center: Vector2 = grid_to_screen(cell)
	var half: Vector2 = TILE_SIZE * 0.5
	var height: float = float(_elevation.get(cell, 0)) * 10.0
	var points: PackedVector2Array = PackedVector2Array(
		[
			center + Vector2(0.0, -half.y),
			center + Vector2(half.x, 0.0),
			center + Vector2(0.0, half.y),
			center + Vector2(-half.x, 0.0),
		]
	)
	var terrain_id: StringName = _terrain.get(cell, &"sand") as StringName
	var color: Color = SAND if (cell.x + cell.y) % 2 == 0 else SAND_LIGHT
	if terrain_id == &"salt":
		color = SALT
	elif terrain_id == &"rock":
		color = ROCK
	elif terrain_id == &"ruin":
		color = RUIN

	if height > 0.0:
		draw_colored_polygon(
			PackedVector2Array(
				[
					points[1],
					points[1] + Vector2(0.0, height),
					points[2] + Vector2(0.0, height),
					points[2]
				]
			),
			color.darkened(0.38),
		)
		draw_colored_polygon(
			PackedVector2Array(
				[
					points[2],
					points[2] + Vector2(0.0, height),
					points[3] + Vector2(0.0, height),
					points[3]
				]
			),
			color.darkened(0.52),
		)

	draw_colored_polygon(points, color)
	for edge: int in range(4):
		draw_line(points[edge], points[(edge + 1) % 4], GRID_LINE, 1.2)

	if terrain_id == &"ruin":
		draw_circle(center, 6.0, TEAL.darkened(0.15))
		draw_arc(center, 13.0, 0.0, TAU, 20, TEAL, 2.0)


func _draw_drive_vector() -> void:
	var vector: Vector2 = Vector2(_last_screen_direction).normalized()
	var start: Vector2 = _robot_visual_position + Vector2(0.0, 12.0)
	var finish: Vector2 = start + vector * 42.0
	draw_line(start, finish, TEAL, 4.0)
	draw_circle(finish, 5.0, AMBER if _is_running else TEAL)


func _draw_robot(position: Vector2) -> void:
	var bob: float = sin(Time.get_ticks_msec() * 0.008) * 2.0 if _is_moving else 0.0
	var body: Vector2 = position + Vector2(0.0, -78.0 + bob)
	draw_set_transform(Vector2.ZERO)
	_draw_flat_ellipse(
		position + Vector2(0.0, 4.0), Vector2(54.0, 18.0), Color(0.08, 0.05, 0.03, 0.34)
	)
	draw_line(body + Vector2(-28.0, 34.0), position + Vector2(-24.0, -2.0), Color("b8ae93"), 14.0)
	draw_line(body + Vector2(28.0, 34.0), position + Vector2(24.0, -2.0), Color("8f8878"), 14.0)
	draw_line(body + Vector2(-25.0, 42.0), position + Vector2(-35.0, 2.0), INK, 4.0)
	draw_line(body + Vector2(25.0, 42.0), position + Vector2(35.0, 2.0), INK, 4.0)
	var shell: PackedVector2Array = PackedVector2Array(
		[
			body + Vector2(-58.0, 8.0),
			body + Vector2(-38.0, -28.0),
			body + Vector2(30.0, -34.0),
			body + Vector2(58.0, -8.0),
			body + Vector2(48.0, 34.0),
			body + Vector2(-42.0, 38.0),
		]
	)
	draw_colored_polygon(shell, Color("d6cbb0"))
	draw_polyline(PackedVector2Array(Array(shell) + [shell[0]]), INK, 4.0)
	draw_rect(Rect2(body + Vector2(-30.0, -38.0), Vector2(48.0, 10.0)), Color("23877f"))
	draw_line(body + Vector2(-50.0, -2.0), body + Vector2(52.0, 20.0), Color("6a4931"), 5.0)
	draw_circle(body + Vector2(34.0, -4.0), 9.0, INK)
	draw_circle(body + Vector2(36.0, -5.0), 4.0, AMBER)


func _draw_flat_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)


func _build_interface() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: ColorRect = ColorRect.new()
	panel.position = Vector2(28.0, 28.0)
	panel.size = Vector2(380.0, 224.0)
	panel.color = Color(0.04, 0.055, 0.06, 0.88)
	layer.add_child(panel)

	var title: Label = Label.new()
	title.position = Vector2(24.0, 20.0)
	title.size = Vector2(330.0, 48.0)
	title.text = "WALKER'S WAKE"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", AMBER)
	panel.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.position = Vector2(25.0, 72.0)
	subtitle.size = Vector2(330.0, 54.0)
	subtitle.text = "THE DESERT MOVES.\nSO DOES HOME."
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color("d8d0b5"))
	panel.add_child(subtitle)

	_status_label = Label.new()
	_status_label.position = Vector2(25.0, 138.0)
	_status_label.size = Vector2(330.0, 32.0)
	_status_label.text = "VECTOR SE // DRIVE 0.0 // 3,6"
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", TEAL)
	panel.add_child(_status_label)

	var help: Label = Label.new()
	help.position = Vector2(25.0, 178.0)
	help.size = Vector2(330.0, 28.0)
	help.text = "WASD/ARROWS: 8D MOVE   SHIFT: RUN   ESC: RETURN"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color("9f9787"))
	panel.add_child(help)


func _update_drive_status() -> void:
	var drive: float = RUN_MULTIPLIER if _is_running else (1.0 if _is_moving else 0.0)
	_update_status(
		"VECTOR %s // DRIVE %.1f // %d,%d" % [_facing, drive, _robot_grid.x, _robot_grid.y]
	)


func _update_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
