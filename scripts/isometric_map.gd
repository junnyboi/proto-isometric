extends Node2D

const CardinalAvatarScript: GDScript = preload("res://scripts/cardinal_avatar.gd")
const DesertAtmosphereScript: GDScript = preload("res://scripts/desert_atmosphere.gd")
const DesertHazardsScript: GDScript = preload("res://scripts/desert_hazards.gd")
const FieldHudScript: GDScript = preload("res://scripts/field_hud.gd")
const ImpactEffectsScript: GDScript = preload("res://scripts/impact_effects.gd")
const WorldStateStoreScript: GDScript = preload("res://scripts/world_state_store.gd")
const HEAT_HAZE_SHADER: Shader = preload("res://shaders/heat_haze.gdshader")
const SAND_TEXTURE: Texture2D = preload("res://assets/textures/terrain/desert_sand.png")
const SALT_TEXTURE: Texture2D = preload("res://assets/textures/terrain/salt_crust.png")
const ROCK_TEXTURE: Texture2D = preload("res://assets/textures/terrain/iron_rock.png")
const RUIN_TEXTURE: Texture2D = preload("res://assets/textures/terrain/ancient_ruin.png")

const GRID_SIZE: Vector2i = Vector2i(18, 18)
const TILE_SIZE: Vector2 = Vector2(90.0, 45.0)
const MAP_ORIGIN: Vector2 = Vector2(760.0, 70.0)
const START_CELL: Vector2i = Vector2i(8, 10)
const SAVE_SCHEMA: int = 1
const DEFAULT_SAVE_PATH: String = "user://walkers-wake-world.json"
const INVALID_CELL: Vector2i = Vector2i(-9999, -9999)
const WALK_SPEED: float = 150.0
const RUN_MULTIPLIER: float = 1.5
const ACCELERATION: float = 310.0
const DECELERATION: float = 390.0
const CAMERA_RESPONSE: float = 4.8
const CAMERA_LOOK_AHEAD_SECONDS: float = 0.32
const CAMERA_MAX_LEAD: float = 82.0
const TERRAIN_TEXTURE_PERIOD_CELLS: float = 4.0
const TERRAIN_UV_VARIATION: float = 0.035
const MAX_CHASSIS: int = 100
const REPAIR_COST: int = 5
const REPAIR_AMOUNT: int = 35

const SAND: Color = Color("d79a45")
const SAND_LIGHT: Color = Color("e8b861")
const SALT: Color = Color("d8d0b5")
const ROCK: Color = Color("934d35")
const RUIN: Color = Color("39454a")
const TEAL: Color = Color("4eb6aa")
const AMBER: Color = Color("f5a62d")
const INK: Color = Color("11151a")
const GRID_LINE: Color = Color(0.18, 0.12, 0.08, 0.32)

@export var save_path: String = DEFAULT_SAVE_PATH

var _terrain: Dictionary = {}
var _elevation: Dictionary = {}
var _blocked: Dictionary = {}
var _destructible_rocks: Dictionary = {}
var _scrap: Dictionary = {}
var _outposts: Dictionary = {}
var _scrap_count: int = 0
var _chassis: int = MAX_CHASSIS
var _terrain_textures: Dictionary = {
	&"sand": SAND_TEXTURE,
	&"salt": SALT_TEXTURE,
	&"rock": ROCK_TEXTURE,
	&"ruin": RUIN_TEXTURE,
}

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
var _pending_impact_cell: Vector2i = INVALID_CELL
var _pending_impact_breaks_rock: bool = false

var _avatar: Node2D
var _atmosphere: Node2D
var _camera: Camera2D
var _effects: Node2D
var _hazards: Node2D
var _hud: CanvasLayer
var _state_store: RefCounted


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_generate_desert()
	_build_state_store(save_path)
	_load_world_state()
	_robot_visual_position = grid_to_screen(_robot_grid)
	_build_avatar()
	_build_camera()
	_build_impact_effects()
	_build_atmosphere()
	_build_hazards()
	_build_interface()
	_build_heat_haze()
	_collect_scrap_at(_robot_grid)
	_refresh_outpost_interface()
	_sync_avatar()
	queue_redraw()
	print("[ISOMETRIC_MAP_READY]")


func _process(delta: float) -> void:
	var screen_direction: Vector2i = _read_screen_direction()
	var attack_pressed: bool = _is_attack_pressed()
	if attack_pressed and not _attack_was_pressed:
		attack()
	_attack_was_pressed = attack_pressed
	var drive_direction: Vector2i = (
		Vector2i.ZERO if _pending_impact_cell != INVALID_CELL else screen_direction
	)
	update_drive(drive_direction, delta, _is_run_pressed())
	_update_camera_follow(delta)
	_impact_flash = maxf(_impact_flash - delta, 0.0)
	_status_hold_time = maxf(_status_hold_time - delta, 0.0)
	if _effects != null:
		_effects.call("advance", delta)
	if _atmosphere != null:
		_atmosphere.call("advance", delta)
	if _hazards != null:
		_hazards.call("set_player_cell", _robot_grid)
		_hazards.call("advance", delta)
	_refresh_outpost_interface()
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
		draw_arc(_robot_visual_position, 74.0, 0.0, TAU, 40, AMBER, 5.0 * _impact_flash / 0.36)


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
	if _pending_impact_cell != INVALID_CELL:
		normalized_direction = Vector2i.ZERO
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
	if _avatar == null or _pending_impact_cell != INVALID_CELL:
		return false
	_velocity = Vector2.ZERO
	var screen_direction: Vector2i = _facing_to_screen_direction(_facing)
	var target: Vector2i = _robot_grid + _screen_direction_to_grid_delta(screen_direction)
	_pending_impact_cell = target
	_pending_impact_breaks_rock = bool(_destructible_rocks.get(target, false))
	_status_hold_time = 0.7
	_update_status("IMPACT // WINDUP // SCRAP %03d" % _scrap_count)
	_avatar.call("play_attack")
	return _pending_impact_breaks_rock


func _on_avatar_impact_frame() -> void:
	if _pending_impact_cell == INVALID_CELL:
		return
	var target: Vector2i = _pending_impact_cell
	var breaks_rock: bool = _pending_impact_breaks_rock
	_pending_impact_cell = INVALID_CELL
	_pending_impact_breaks_rock = false
	_impact_flash = 0.36
	_status_hold_time = 0.7
	if breaks_rock and _break_rock(target):
		if _effects != null:
			_effects.call("emit_rock_impact", grid_to_screen(target), target)
		_save_world_state()
		_update_status("IMPACT // ROCK SALVAGED // SCRAP %03d" % _scrap_count)
		return
	_update_status("IMPACT // CLEAR // SCRAP %03d" % _scrap_count)


func place_destructible_rock(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell) or cell == _robot_grid:
		return false
	_blocked[cell] = true
	_destructible_rocks[cell] = true
	_terrain[cell] = &"rock"
	_elevation[cell] = 2
	_save_world_state()
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


func _get_chassis() -> int:
	return _chassis


func _apply_chassis_damage(amount: int, source: StringName = &"hazard") -> int:
	var damage: int = mini(maxi(amount, 0), _chassis)
	if damage <= 0:
		return 0
	_chassis -= damage
	_status_hold_time = 0.7
	_update_status(
		(
			"%s CONTACT -%02d // CHASSIS %03d/%03d"
			% [String(source).to_upper(), damage, _chassis, MAX_CHASSIS]
		)
	)
	_refresh_outpost_interface()
	_save_world_state()
	return damage


func _is_at_outpost() -> bool:
	return bool(_outposts.get(_robot_grid, false))


func _repair_chassis() -> bool:
	if not _is_at_outpost() or _scrap_count < REPAIR_COST or _chassis >= MAX_CHASSIS:
		return false
	_scrap_count -= REPAIR_COST
	_chassis = mini(_chassis + REPAIR_AMOUNT, MAX_CHASSIS)
	_status_hold_time = 1.0
	_update_status("OUTPOST REPAIR // CHASSIS %03d // SCRAP %03d" % [_chassis, _scrap_count])
	_refresh_outpost_interface()
	_save_world_state()
	return true


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
	if _hazards != null:
		_hazards.call("set_player_cell", cell)
	_refresh_outpost_interface()
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


func _get_atmosphere() -> Node2D:
	return _atmosphere


func _get_hazards() -> Node2D:
	return _hazards


func _get_outpost_interface() -> Control:
	return _hud.call("get_outpost_interface") as Control if _hud != null else null


func get_camera_position() -> Vector2:
	return _camera.position if _camera != null else Vector2.ZERO


func get_camera_target() -> Vector2:
	var lead: Vector2 = (_velocity * CAMERA_LOOK_AHEAD_SECONDS).limit_length(CAMERA_MAX_LEAD)
	return _robot_visual_position + lead


func get_status_text() -> String:
	return str(_hud.call("get_status_text")) if _hud != null else ""


func _exit_tree() -> void:
	_save_world_state()


func _build_state_store(path: String) -> void:
	_state_store = WorldStateStoreScript.new() as RefCounted
	_state_store.call("configure", path)


func _load_world_state() -> bool:
	if _state_store == null:
		return false
	var snapshot: Dictionary = _state_store.call("load_snapshot") as Dictionary
	if snapshot.is_empty():
		var load_error: String = str(_state_store.call("get_last_error"))
		if not load_error.is_empty():
			push_warning("Ignoring world save: %s" % load_error)
		return false
	if not _is_valid_snapshot(snapshot):
		push_warning("Ignoring incompatible or malformed world save.")
		return false
	_apply_snapshot(snapshot)
	return true


func _save_world_state() -> bool:
	if _state_store == null:
		return false
	var saved: bool = bool(_state_store.call("save_snapshot", _make_snapshot()))
	if not saved:
		push_warning("World save failed: %s" % str(_state_store.call("get_last_error")))
	return saved


func _make_snapshot() -> Dictionary:
	var rocks: Array[Array] = []
	for cell: Variant in _destructible_rocks:
		var rock_cell: Vector2i = cell as Vector2i
		rocks.append([rock_cell.x, rock_cell.y])
	rocks.sort_custom(
		func(a: Array, b: Array) -> bool: return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0])
	)

	var scrap_entries: Array[Dictionary] = []
	for cell: Variant in _scrap:
		var scrap_cell: Vector2i = cell as Vector2i
		scrap_entries.append(
			{"cell": [scrap_cell.x, scrap_cell.y], "amount": int(_scrap[scrap_cell])}
		)
	scrap_entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_cell: Array = a["cell"] as Array
			var b_cell: Array = b["cell"] as Array
			return a_cell[1] < b_cell[1] or (a_cell[1] == b_cell[1] and a_cell[0] < b_cell[0])
	)
	return {
		"schema": SAVE_SCHEMA,
		"grid_size": [GRID_SIZE.x, GRID_SIZE.y],
		"rocks": rocks,
		"scrap": scrap_entries,
		"scrap_total": _scrap_count,
		"chassis": _chassis,
		"robot_cell": [_robot_grid.x, _robot_grid.y],
		"facing": String(_facing),
	}


func _is_valid_snapshot(snapshot: Dictionary) -> bool:
	var robot_cell: Vector2i = _decode_cell(snapshot.get("robot_cell", []))
	var facing_value: StringName = StringName(str(snapshot.get("facing", "")))
	var rock_values: Variant = snapshot.get("rocks", null)
	var scrap_values: Variant = snapshot.get("scrap", null)
	return (
		int(snapshot.get("schema", -1)) == SAVE_SCHEMA
		and _grid_matches(snapshot.get("grid_size", []))
		and int(snapshot.get("scrap_total", -1)) >= 0
		and int(snapshot.get("chassis", MAX_CHASSIS)) >= 0
		and int(snapshot.get("chassis", MAX_CHASSIS)) <= MAX_CHASSIS
		and robot_cell != INVALID_CELL
		and facing_value in [&"N", &"NE", &"E", &"SE", &"S", &"SW", &"W", &"NW"]
		and rock_values is Array
		and scrap_values is Array
		and _rock_snapshot_is_valid(rock_values as Array, robot_cell)
		and _scrap_snapshot_is_valid(scrap_values as Array, rock_values as Array)
	)


func _grid_matches(value: Variant) -> bool:
	if not value is Array or (value as Array).size() != 2:
		return false
	var grid: Array = value as Array
	if (
		(not grid[0] is int and not grid[0] is float)
		or (not grid[1] is int and not grid[1] is float)
	):
		return false
	return int(grid[0]) == GRID_SIZE.x and int(grid[1]) == GRID_SIZE.y


func _rock_snapshot_is_valid(values: Array, robot_cell: Vector2i) -> bool:
	var rock_cells: Dictionary = {}
	for value: Variant in values:
		var cell: Vector2i = _decode_cell(value)
		if cell == INVALID_CELL or rock_cells.has(cell):
			return false
		rock_cells[cell] = true
	return not rock_cells.has(robot_cell)


func _scrap_snapshot_is_valid(values: Array, rock_values: Array) -> bool:
	var rock_cells: Dictionary = {}
	for value: Variant in rock_values:
		rock_cells[_decode_cell(value)] = true
	var scrap_cells: Dictionary = {}
	for value: Variant in values:
		if not value is Dictionary:
			return false
		var entry: Dictionary = value as Dictionary
		var cell: Vector2i = _decode_cell(entry.get("cell", []))
		var amount: int = int(entry.get("amount", 0))
		if (
			cell == INVALID_CELL
			or rock_cells.has(cell)
			or scrap_cells.has(cell)
			or amount <= 0
			or amount > 999
		):
			return false
		scrap_cells[cell] = true
	return true


func _apply_snapshot(snapshot: Dictionary) -> void:
	_blocked.clear()
	_destructible_rocks.clear()
	_scrap.clear()
	for value: Variant in snapshot["rocks"] as Array:
		var cell: Vector2i = _decode_cell(value)
		_blocked[cell] = true
		_destructible_rocks[cell] = true
	for y: int in range(GRID_SIZE.y):
		for x: int in range(GRID_SIZE.x):
			var cell: Vector2i = Vector2i(x, y)
			if bool(_destructible_rocks.get(cell, false)):
				_terrain[cell] = &"rock"
				_elevation[cell] = 2
			elif _terrain.get(cell, &"sand") == &"rock":
				_terrain[cell] = &"sand"
				_elevation[cell] = 0
	for value: Variant in snapshot["scrap"] as Array:
		var entry: Dictionary = value as Dictionary
		_scrap[_decode_cell(entry["cell"])] = int(entry["amount"])
	_scrap_count = int(snapshot["scrap_total"])
	_chassis = int(snapshot.get("chassis", MAX_CHASSIS))
	_robot_grid = _decode_cell(snapshot["robot_cell"])
	_facing = StringName(str(snapshot["facing"]))


func _decode_cell(value: Variant) -> Vector2i:
	if not value is Array or (value as Array).size() != 2:
		return INVALID_CELL
	var coordinates: Array = value as Array
	if (
		(not coordinates[0] is int and not coordinates[0] is float)
		or (not coordinates[1] is int and not coordinates[1] is float)
	):
		return INVALID_CELL
	var cell: Vector2i = Vector2i(int(coordinates[0]), int(coordinates[1]))
	return cell if _is_in_bounds(cell) else INVALID_CELL


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
	if _effects != null:
		_effects.call("emit_scrap_pickup", grid_to_screen(cell), amount)
	_refresh_outpost_interface()
	_save_world_state()
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

	for cell: Vector2i in [Vector2i(1, 10), Vector2i(8, 4), Vector2i(15, 8)]:
		_outposts[cell] = true
		_terrain[cell] = &"ruin"
		_elevation[cell] = 1
		_blocked.erase(cell)
		_destructible_rocks.erase(cell)

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
	_avatar.connect("impact_frame", Callable(self, "_on_avatar_impact_frame"))
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


func _build_impact_effects() -> void:
	_effects = ImpactEffectsScript.new() as Node2D
	_effects.name = "ImpactEffects"
	_effects.z_index = 30
	_effects.call("bind_camera", _camera)
	add_child(_effects)


func _build_atmosphere() -> void:
	_atmosphere = DesertAtmosphereScript.new() as Node2D
	_atmosphere.name = "DesertAtmosphere"
	_atmosphere.z_index = 50
	add_child(_atmosphere)


func _build_hazards() -> void:
	_hazards = DesertHazardsScript.new() as Node2D
	_hazards.name = "DesertHazards"
	_hazards.z_index = 40
	_hazards.call("configure", GRID_SIZE, TILE_SIZE, MAP_ORIGIN)
	_hazards.call("set_player_cell", _robot_grid)
	_hazards.connect("damage_tick", Callable(self, "_on_hazard_damage"))
	add_child(_hazards)


func _on_hazard_damage(amount: int, source: StringName) -> void:
	_apply_chassis_damage(amount, source)


func _build_heat_haze() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "HeatHazeLayer"
	layer.layer = 1
	add_child(layer)
	var haze: ColorRect = ColorRect.new()
	haze.name = "HeatHaze"
	haze.position = Vector2.ZERO
	haze.size = Vector2(1280.0, 720.0)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = HEAT_HAZE_SHADER
	haze.material = material
	layer.add_child(haze)


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
	var terrain_texture: Texture2D = _terrain_textures.get(terrain_id) as Texture2D
	if terrain_texture != null:
		draw_polygon(
			points,
			_terrain_tints(cell),
			_terrain_uvs(cell),
			terrain_texture,
		)
	for edge: int in range(4):
		draw_line(points[edge], points[(edge + 1) % 4], GRID_LINE, 1.2)

	if terrain_id == &"ruin":
		draw_circle(center, 6.0, TEAL.darkened(0.15))
		draw_arc(center, 13.0, 0.0, TAU, 20, TEAL, 2.0)
	if bool(_outposts.get(cell, false)):
		_draw_outpost(center)
	if bool(_destructible_rocks.get(cell, false)):
		_draw_rock(center)
	if int(_scrap.get(cell, 0)) > 0:
		_draw_scrap(center, int(_scrap[cell]))


func _terrain_uvs(cell: Vector2i) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in _terrain_grid_vertices(cell):
		var warp: Vector2 = (
			Vector2(
				sin(point.x * 0.31 + point.y * 0.17),
				cos(point.y * 0.27 - point.x * 0.13),
			)
			* TERRAIN_UV_VARIATION
		)
		result.append(point / TERRAIN_TEXTURE_PERIOD_CELLS + warp)
	return result


func _terrain_tints(cell: Vector2i) -> PackedColorArray:
	var result: PackedColorArray = PackedColorArray()
	for point: Vector2 in _terrain_grid_vertices(cell):
		var wave: float = (
			(sin(point.x * 0.39) + cos(point.y * 0.33) + sin((point.x + point.y) * 0.16)) / 3.0
		)
		var brightness: float = 0.96 + wave * 0.055
		result.append(Color(brightness * 1.025, brightness, brightness * 0.96, 1.0))
	return result


func _terrain_grid_vertices(cell: Vector2i) -> Array[Vector2]:
	var center: Vector2 = Vector2(cell)
	return [
		center + Vector2(-0.5, -0.5),
		center + Vector2(0.5, -0.5),
		center + Vector2(0.5, 0.5),
		center + Vector2(-0.5, 0.5),
	]


func _draw_rock(center: Vector2) -> void:
	draw_circle(center + Vector2(-12.0, -5.0), 15.0, ROCK.darkened(0.08))
	draw_circle(center + Vector2(7.0, -9.0), 19.0, ROCK.lightened(0.06))
	draw_circle(center + Vector2(18.0, 2.0), 12.0, ROCK.darkened(0.18))
	draw_line(center + Vector2(0.0, -24.0), center + Vector2(-5.0, 4.0), INK, 3.0)
	draw_line(center + Vector2(-5.0, 4.0), center + Vector2(9.0, 12.0), INK, 3.0)


func _draw_outpost(center: Vector2) -> void:
	draw_arc(center, 20.0, 0.0, TAU, 24, AMBER, 3.0)
	draw_arc(center, 28.0, 0.0, TAU, 32, TEAL, 2.0)
	for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_line(center + direction * 21.0, center + direction * 29.0, AMBER, 4.0)


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
	_hud = FieldHudScript.new() as CanvasLayer
	_hud.name = "FieldHUD"
	_hud.connect("repair_requested", Callable(self, "_repair_chassis"))
	add_child(_hud)


func _refresh_outpost_interface() -> void:
	if _hud != null:
		_hud.call("set_outpost_state", _is_at_outpost(), _scrap_count, _chassis, MAX_CHASSIS)


func _update_drive_status() -> void:
	if _status_hold_time > 0.0:
		return
	_update_status(
		(
			"VECTOR %s // DRIVE %.2f // %d,%d // CH %03d // SCRAP %03d"
			% [_facing, get_speed_ratio(), _robot_grid.x, _robot_grid.y, _chassis, _scrap_count]
		)
	)


func _update_status(text: String) -> void:
	if _hud != null:
		_hud.call("set_status", text)
