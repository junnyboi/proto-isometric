extends Node2D

const CardinalAvatarScript: GDScript = preload("res://scripts/cardinal_avatar.gd")

const GRID_SIZE: Vector2i = Vector2i(18, 18)
const TILE_SIZE: Vector2 = Vector2(90.0, 45.0)
const MAP_ORIGIN: Vector2 = Vector2(760.0, 70.0)
const START_CELL: Vector2i = Vector2i(8, 10)

const WALK_SPEED: float = 150.0
const RUN_MULTIPLIER: float = 1.5
const ACCELERATION: float = 310.0
const DECELERATION: float = 390.0
const CAMERA_RESPONSE: float = 4.8
const CAMERA_LOOK_AHEAD_SECONDS: float = 0.32
const CAMERA_MAX_LEAD: float = 82.0

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
var _destructible_rocks: Dictionary = {}
var _scrap: Dictionary = {}
var _scrap_count: int = 0

var _robot_grid: Vector2i = START_CELL
var _robot_visual_position: Vector2
var _velocity: Vector2 = Vector2.ZERO
var _last_screen_direction: Vector2i = Vector2i(1, 1)
var _facing: StringName = &"SE"
var _is_moving: bool = false
var _is_running: bool = false
var _impact_flash: float = 0.0
var _status_hold_time: float = 0.0
var _attack_was_pressed: bool = false

var _avatar: Node2D
var _camera: Camera2D
var _status_label: Label
var _interaction_label: Label


func _ready() -> void:
	_generate_desert()
	_robot_visual_position = grid_to_screen(_robot_grid)
	_build_avatar()
	_build_camera()
	_build_interface()
	_collect_scrap_at(_robot_grid)
	_sync_avatar()
	queue_redraw()
	print("[ISOMETRIC_MAP_READY]")


func _process(delta: float) -> void:
	var screen_direction: Vector2i = _read_screen_direction()
	var attack_pressed: bool = _is_attack_pressed()
	if attack_pressed and not _attack_was_pressed:
		attack()
	_attack_was_pressed = attack_pressed
	update_drive(screen_direction, delta, _is_run_pressed())
	_update_camera_follow(delta)
	_impact_flash = maxf(_impact_flash - delta, 0.0)
	_status_hold_time = maxf(_status_hold_time - delta, 0.0)
	_sync_avatar()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func _draw() -> void:
	_draw_world_backdrop()
	for diagonal: int in range(GRID_SIZE.x + GRID_SIZE.y - 1):
		for y: int in range(GRID_SIZE.y):
			var x: int = diagonal - y
			if x < 0 or x >= GRID_SIZE.x:
				continue
			_draw_tile(Vector2i(x, y))
	_draw_drive_vector()
	if _impact_flash > 0.0:
		draw_arc(_robot_visual_position, 74.0, 0.0, TAU, 40, AMBER, 5.0 * _impact_flash / 0.22)


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


func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE.x and cell.y < GRID_SIZE.y


func is_walkable(cell: Vector2i) -> bool:
	return _is_in_bounds(cell) and not bool(_blocked.get(cell, false))


func update_drive(screen_direction: Vector2i, delta: float, running: bool = false) -> bool:
	var step_delta: float = minf(maxf(delta, 0.0), 0.05)
	var normalized_direction: Vector2i = Vector2i(
		clampi(screen_direction.x, -1, 1), clampi(screen_direction.y, -1, 1)
	)
	var has_input: bool = normalized_direction != Vector2i.ZERO
	_is_running = running and has_input

	if has_input:
		_last_screen_direction = normalized_direction
		_facing = _direction_name(normalized_direction)
		if not _can_move_screen_direction(normalized_direction):
			_velocity = Vector2.ZERO
			_is_moving = false
			_update_status("VECTOR %s // BLOCKED // SCRAP %03d" % [_facing, _scrap_count])
			_sync_avatar()
			return false
		var maximum_speed: float = WALK_SPEED * (RUN_MULTIPLIER if running else 1.0)
		var desired_velocity: Vector2 = Vector2(normalized_direction).normalized() * maximum_speed
		_velocity = _velocity.move_toward(desired_velocity, ACCELERATION * step_delta)
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, DECELERATION * step_delta)

	if _velocity.length() < 0.05:
		_velocity = Vector2.ZERO
	_is_moving = not _velocity.is_zero_approx()
	var moved: bool = _move_velocity(step_delta)
	_update_drive_status()
	_sync_avatar()
	return moved


func _can_move_screen_direction(screen_direction: Vector2i) -> bool:
	var delta: Vector2i = _screen_direction_to_grid_delta(screen_direction)
	if delta == Vector2i.ZERO:
		return false
	return _can_transition(_robot_grid, _robot_grid + delta)


func _screen_direction_to_grid_delta(screen_direction: Vector2i) -> Vector2i:
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


func _direction_name(screen_direction: Vector2i) -> StringName:
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


func _facing_to_screen_direction(facing: StringName) -> Vector2i:
	var directions: Dictionary = {
		&"N": Vector2i(0, -1),
		&"NE": Vector2i(1, -1),
		&"E": Vector2i(1, 0),
		&"SE": Vector2i(1, 1),
		&"S": Vector2i(0, 1),
		&"SW": Vector2i(-1, 1),
		&"W": Vector2i(-1, 0),
		&"NW": Vector2i(-1, -1),
	}
	return directions.get(facing, Vector2i.ZERO) as Vector2i


func attack() -> bool:
	if _avatar != null:
		_avatar.call("play_attack")
	_velocity = _velocity.move_toward(Vector2.ZERO, DECELERATION * 0.08)
	var screen_direction: Vector2i = _facing_to_screen_direction(_facing)
	var target: Vector2i = _robot_grid + _screen_direction_to_grid_delta(screen_direction)
	_impact_flash = 0.36
	_status_hold_time = 0.7
	if bool(_destructible_rocks.get(target, false)):
		_break_rock(target)
		_update_status("IMPACT // ROCK SALVAGED // SCRAP %03d" % _scrap_count)
		return true
	_update_status("IMPACT // CLEAR // SCRAP %03d" % _scrap_count)
	return false


func place_destructible_rock(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell) or cell == _robot_grid:
		return false
	_blocked[cell] = true
	_destructible_rocks[cell] = true
	_terrain[cell] = &"rock"
	_elevation[cell] = 2
	queue_redraw()
	return true


func _break_rock(cell: Vector2i) -> bool:
	if not bool(_destructible_rocks.get(cell, false)):
		return false
	_destructible_rocks.erase(cell)
	_blocked.erase(cell)
	_terrain[cell] = &"sand"
	_elevation[cell] = 0
	_scrap[cell] = int(_scrap.get(cell, 0)) + 2
	queue_redraw()
	return true


func _place_scrap(cell: Vector2i, amount: int = 1) -> bool:
	if not is_walkable(cell) or amount <= 0:
		return false
	_scrap[cell] = int(_scrap.get(cell, 0)) + amount
	queue_redraw()
	return true


func has_destructible_rock(cell: Vector2i) -> bool:
	return bool(_destructible_rocks.get(cell, false))


func has_scrap(cell: Vector2i) -> bool:
	return int(_scrap.get(cell, 0)) > 0


func get_scrap_count() -> int:
	return _scrap_count


func get_robot_grid() -> Vector2i:
	return _robot_grid


func place_robot(cell: Vector2i) -> bool:
	if not is_walkable(cell):
		return false
	_robot_grid = cell
	_robot_visual_position = grid_to_screen(cell)
	_velocity = Vector2.ZERO
	_is_moving = false
	_is_running = false
	_collect_scrap_at(cell)
	_update_drive_status()
	_sync_avatar()
	queue_redraw()
	return true


func get_robot_position() -> Vector2:
	return _robot_visual_position


func get_velocity() -> Vector2:
	return _velocity


func get_speed_ratio() -> float:
	return _velocity.length() / WALK_SPEED


func get_facing() -> StringName:
	return _facing


func get_grid_size() -> Vector2i:
	return GRID_SIZE


func get_avatar() -> Node2D:
	return _avatar


func get_camera_position() -> Vector2:
	return _camera.position if _camera != null else Vector2.ZERO


func get_camera_target() -> Vector2:
	var lead: Vector2 = (_velocity * CAMERA_LOOK_AHEAD_SECONDS).limit_length(CAMERA_MAX_LEAD)
	return _robot_visual_position + lead


func get_status_text() -> String:
	return _status_label.text if _status_label != null else ""


func _snap_camera_to_robot() -> void:
	if _camera != null:
		_camera.position = _robot_visual_position


func _update_camera_follow(delta: float) -> void:
	if _camera == null:
		return
	var blend: float = 1.0 - exp(-CAMERA_RESPONSE * maxf(delta, 0.0))
	_camera.position = _camera.position.lerp(get_camera_target(), blend)


func _move_velocity(delta: float) -> bool:
	if _velocity.is_zero_approx() or delta <= 0.0:
		return false
	var candidate: Vector2 = _robot_visual_position + _velocity * delta
	var candidate_grid: Vector2i = screen_to_grid(candidate)
	if candidate_grid != _robot_grid and not _can_transition(_robot_grid, candidate_grid):
		_velocity = Vector2.ZERO
		_is_moving = false
		_impact_flash = 0.12
		return false
	_robot_visual_position = candidate
	if candidate_grid != _robot_grid:
		_robot_grid = candidate_grid
		_collect_scrap_at(_robot_grid)
	return true


func _can_transition(from: Vector2i, target: Vector2i) -> bool:
	if not is_walkable(target):
		return false
	var delta: Vector2i = target - from
	if absi(delta.x) > 1 or absi(delta.y) > 1:
		return false
	if delta.x != 0 and delta.y != 0:
		return is_walkable(from + Vector2i(delta.x, 0)) and is_walkable(from + Vector2i(0, delta.y))
	return true


func _collect_scrap_at(cell: Vector2i) -> int:
	var amount: int = int(_scrap.get(cell, 0))
	if amount <= 0:
		return 0
	_scrap.erase(cell)
	_scrap_count += amount
	_status_hold_time = 0.9
	_update_status("SCRAP COLLECTED +%d // TOTAL %03d" % [amount, _scrap_count])
	queue_redraw()
	return amount


func _generate_desert() -> void:
	var rocks: Array[Vector2i] = [
		Vector2i(2, 3),
		Vector2i(3, 3),
		Vector2i(4, 4),
		Vector2i(12, 2),
		Vector2i(13, 3),
		Vector2i(14, 4),
		Vector2i(5, 12),
		Vector2i(6, 13),
		Vector2i(11, 12),
		Vector2i(12, 12),
		Vector2i(13, 11),
		Vector2i(15, 14),
		Vector2i(3, 15),
	]
	for cell: Vector2i in rocks:
		_blocked[cell] = true
		_destructible_rocks[cell] = true

	for y: int in range(GRID_SIZE.y):
		for x: int in range(GRID_SIZE.x):
			var cell: Vector2i = Vector2i(x, y)
			var value: int = posmod(x * 19 + y * 31 + x * y * 7, 100)
			var terrain_id: StringName = &"sand"
			if bool(_blocked.get(cell, false)):
				terrain_id = &"rock"
			elif value < 11:
				terrain_id = &"salt"
			elif value < 18:
				terrain_id = &"ruin"
			_terrain[cell] = terrain_id
			_elevation[cell] = 2 if terrain_id == &"rock" else (1 if terrain_id == &"ruin" else 0)

	_place_scrap(Vector2i(9, 9), 1)
	_place_scrap(Vector2i(10, 7), 2)
	_place_scrap(Vector2i(7, 13), 1)
	_place_scrap(Vector2i(14, 8), 2)


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


func _is_attack_pressed() -> bool:
	return (
		Input.is_key_pressed(KEY_SPACE)
		or Input.is_physical_key_pressed(KEY_J)
		or Input.is_physical_key_pressed(KEY_K)
	)


func _build_avatar() -> void:
	_avatar = CardinalAvatarScript.new() as Node2D
	_avatar.name = "CardinalAvatar"
	_avatar.position = _robot_visual_position
	_avatar.z_index = 20
	add_child(_avatar)


func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "FollowCamera"
	_camera.position = _robot_visual_position
	_camera.enabled = true
	_camera.ignore_rotation = true
	_camera.limit_left = -900
	_camera.limit_right = 2500
	_camera.limit_top = -600
	_camera.limit_bottom = 1600
	add_child(_camera)


func _sync_avatar() -> void:
	if _avatar == null:
		return
	_avatar.position = _robot_visual_position
	_avatar.call("set_motion", _facing, _is_moving, get_speed_ratio())


func _draw_world_backdrop() -> void:
	draw_rect(Rect2(-1000.0, -800.0, 3800.0, 2800.0), Color("24170f"))
	for band: int in range(12):
		var color: Color = Color("6f3925").lerp(Color("24170f"), float(band) / 11.0)
		draw_rect(Rect2(-1000.0, -600.0 + float(band) * 105.0, 3800.0, 108.0), color)


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
					points[2],
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
					points[3],
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
	if bool(_destructible_rocks.get(cell, false)):
		_draw_rock(center)
	if int(_scrap.get(cell, 0)) > 0:
		_draw_scrap(center, int(_scrap[cell]))


func _draw_rock(center: Vector2) -> void:
	draw_circle(center + Vector2(-12.0, -5.0), 15.0, ROCK.darkened(0.08))
	draw_circle(center + Vector2(7.0, -9.0), 19.0, ROCK.lightened(0.06))
	draw_circle(center + Vector2(18.0, 2.0), 12.0, ROCK.darkened(0.18))
	draw_line(center + Vector2(0.0, -24.0), center + Vector2(-5.0, 4.0), INK, 3.0)
	draw_line(center + Vector2(-5.0, 4.0), center + Vector2(9.0, 12.0), INK, 3.0)


func _draw_scrap(center: Vector2, amount: int) -> void:
	for index: int in range(mini(amount + 1, 4)):
		var offset: Vector2 = Vector2(float(index - 1) * 9.0, float(index % 2) * 7.0 - 5.0)
		draw_circle(center + offset, 7.0, TEAL.darkened(0.35))
		draw_arc(center + offset, 8.0, 0.0, TAU, 12, TEAL, 2.0)
		draw_circle(center + offset, 2.0, AMBER)


func _draw_drive_vector() -> void:
	var vector: Vector2 = Vector2(_last_screen_direction).normalized()
	var start: Vector2 = _robot_visual_position + Vector2(0.0, 15.0)
	var finish: Vector2 = start + vector * (36.0 + minf(_velocity.length() * 0.12, 30.0))
	draw_line(start, finish, TEAL, 4.0)
	draw_circle(finish, 5.0, AMBER if _is_running else TEAL)


func _build_interface() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: ColorRect = ColorRect.new()
	panel.position = Vector2(28.0, 28.0)
	panel.size = Vector2(430.0, 246.0)
	panel.color = Color(0.04, 0.055, 0.06, 0.9)
	layer.add_child(panel)

	var title: Label = Label.new()
	title.position = Vector2(24.0, 18.0)
	title.size = Vector2(380.0, 48.0)
	title.text = "CARDINAL // FIELD DRIVE"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", AMBER)
	panel.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.position = Vector2(25.0, 66.0)
	subtitle.size = Vector2(380.0, 54.0)
	subtitle.text = "HEAVY FRAME ONLINE\nCLEAR ROCK. RECOVER SCRAP."
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("d8d0b5"))
	panel.add_child(subtitle)

	_status_label = Label.new()
	_status_label.position = Vector2(25.0, 128.0)
	_status_label.size = Vector2(380.0, 32.0)
	_status_label.text = "VECTOR SE // DRIVE 0.00 // SCRAP 000"
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", TEAL)
	panel.add_child(_status_label)

	_interaction_label = Label.new()
	_interaction_label.position = Vector2(25.0, 162.0)
	_interaction_label.size = Vector2(380.0, 26.0)
	_interaction_label.text = "SPACE / J / K: IMPACT STRIKE"
	_interaction_label.add_theme_font_size_override("font_size", 14)
	_interaction_label.add_theme_color_override("font_color", AMBER)
	panel.add_child(_interaction_label)

	var help: Label = Label.new()
	help.position = Vector2(25.0, 202.0)
	help.size = Vector2(390.0, 24.0)
	help.text = "WASD/ARROWS: 8D   SHIFT: RUN   ESC: RETURN"
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color("9f9787"))
	panel.add_child(help)


func _update_drive_status() -> void:
	if _status_hold_time > 0.0:
		return
	_update_status(
		(
			"VECTOR %s // DRIVE %.2f // %d,%d // SCRAP %03d"
			% [_facing, get_speed_ratio(), _robot_grid.x, _robot_grid.y, _scrap_count]
		)
	)


func _update_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
