extends Node2D

signal damage_tick(amount: int, source: StringName)

const TORNADO_FORMATION_SECONDS: float = 3.0
const TORNADO_LIFETIME_SECONDS: float = 20.0
const TORNADO_DAMAGE_PER_SECOND: float = 6.0
const SANDSTORM_DAMAGE_PER_SECOND: float = 3.0
const TORNADO_SPEED: float = 3.2
const SANDSTORM_SPEED: float = 0.62
const TORNADO_FADE_SECONDS: float = 2.0
const DUST: Color = Color("c78038")
const PALE_DUST: Color = Color("efc477")
const DARK_DUST: Color = Color("744124")

var _grid_size: Vector2i = Vector2i(18, 18)
var _tile_size: Vector2 = Vector2(90.0, 45.0)
var _map_origin: Vector2 = Vector2(760.0, 70.0)
var _player_position: Vector2 = Vector2.ZERO
var _hazards: Array[Dictionary] = []
var _next_id: int = 1
var _time: float = 0.0
var _auto_spawn: bool = true
var _tornado_timer: float = 6.0
var _sandstorm_timer: float = 12.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 0xCA7D1A1


func configure(grid_size: Vector2i, tile_size: Vector2, map_origin: Vector2) -> void:
	_grid_size = grid_size
	_tile_size = tile_size
	_map_origin = map_origin


func set_auto_spawn(enabled: bool) -> void:
	_auto_spawn = enabled


func set_player_cell(cell: Vector2i) -> void:
	_player_position = Vector2(cell)


func set_player_position(position: Vector2) -> void:
	_player_position = position


func advance(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	if step <= 0.0:
		return
	_time += step
	if _auto_spawn:
		_advance_spawners(step)
	for index: int in range(_hazards.size() - 1, -1, -1):
		var hazard: Dictionary = _hazards[index]
		hazard["age"] = float(hazard["age"]) + step
		if hazard["kind"] == &"tornado":
			_advance_tornado(hazard, step)
		else:
			_advance_sandstorm(hazard, step)
		if bool(hazard.get("expired", false)):
			_hazards.remove_at(index)
			continue
		_apply_contact_damage(hazard, step)
	queue_redraw()


func spawn_tornado(
	cell: Vector2i,
	formation_seconds: float = TORNADO_FORMATION_SECONDS,
	lifetime_seconds: float = TORNADO_LIFETIME_SECONDS,
	speed: float = TORNADO_SPEED,
) -> int:
	var hazard_id: int = _take_id()
	(
		_hazards
		. append(
			{
				"id": hazard_id,
				"kind": &"tornado",
				"position": Vector2(cell),
				"direction": _random_tornado_direction(),
				"age": 0.0,
				"formation": maxf(formation_seconds, 0.0),
				"lifetime": maxf(lifetime_seconds, 0.1),
				"speed": maxf(speed, 0.0),
				"turn_timer": 0.28,
				"contact_time": 0.0,
				"contacting": false,
				"expired": false,
			}
		)
	)
	queue_redraw()
	return hazard_id


func spawn_sandstorm(
	origin: Vector2i,
	direction: Vector2i,
	speed: float = SANDSTORM_SPEED,
) -> int:
	var normalized: Vector2i = Vector2i(signi(direction.x), signi(direction.y))
	if normalized == Vector2i.ZERO or (normalized.x != 0 and normalized.y != 0):
		return -1
	var hazard_id: int = _take_id()
	(
		_hazards
		. append(
			{
				"id": hazard_id,
				"kind": &"sandstorm",
				"position": Vector2(origin),
				"direction": Vector2(normalized),
				"age": 0.0,
				"speed": maxf(speed, 0.0),
				"contact_time": 0.0,
				"contacting": false,
				"expired": false,
			}
		)
	)
	queue_redraw()
	return hazard_id


func clear_hazards() -> void:
	_hazards.clear()
	queue_redraw()


func get_hazard_count(kind: StringName = &"") -> int:
	if kind == &"":
		return _hazards.size()
	var count: int = 0
	for hazard: Dictionary in _hazards:
		if hazard["kind"] == kind:
			count += 1
	return count


func get_tornado_state(hazard_id: int) -> StringName:
	var hazard: Dictionary = _find_hazard(hazard_id)
	if hazard.is_empty() or hazard["kind"] != &"tornado":
		return &"missing"
	return &"forming" if float(hazard["age"]) < float(hazard["formation"]) else &"active"


func get_tornado_cell(hazard_id: int) -> Vector2i:
	var hazard: Dictionary = _find_hazard(hazard_id)
	if hazard.is_empty():
		return Vector2i(-9999, -9999)
	return Vector2i((hazard["position"] as Vector2).round())


func get_tornado_position(hazard_id: int) -> Vector2:
	var hazard: Dictionary = _find_hazard(hazard_id)
	return hazard["position"] as Vector2 if not hazard.is_empty() else Vector2(-9999.0, -9999.0)


func get_sandstorm_footprint(hazard_id: int) -> Array[Vector2i]:
	var hazard: Dictionary = _find_hazard(hazard_id)
	if hazard.is_empty() or hazard["kind"] != &"sandstorm":
		return []
	return _sandstorm_cells(hazard)


func _advance_spawners(delta: float) -> void:
	_tornado_timer -= delta
	while _tornado_timer <= 0.0:
		spawn_tornado(
			Vector2i(_rng.randi_range(0, _grid_size.x - 1), _rng.randi_range(0, _grid_size.y - 1))
		)
		_tornado_timer += _rng.randf_range(5.0, 8.5)
	_sandstorm_timer -= delta
	while _sandstorm_timer <= 0.0:
		_spawn_edge_sandstorm()
		_sandstorm_timer += _rng.randf_range(14.0, 21.0)


func _spawn_edge_sandstorm() -> void:
	match _rng.randi_range(0, 3):
		0:
			spawn_sandstorm(Vector2i(-3, _rng.randi_range(0, _grid_size.y - 2)), Vector2i.RIGHT)
		1:
			spawn_sandstorm(
				Vector2i(_grid_size.x, _rng.randi_range(0, _grid_size.y - 2)), Vector2i.LEFT
			)
		2:
			spawn_sandstorm(Vector2i(_rng.randi_range(0, _grid_size.x - 2), -3), Vector2i.DOWN)
		_:
			spawn_sandstorm(
				Vector2i(_rng.randi_range(0, _grid_size.x - 2), _grid_size.y), Vector2i.UP
			)


func _advance_tornado(hazard: Dictionary, delta: float) -> void:
	var active_age: float = float(hazard["age"]) - float(hazard["formation"])
	if active_age < 0.0:
		return
	if active_age >= float(hazard["lifetime"]):
		hazard["expired"] = true
		return
	hazard["turn_timer"] = float(hazard["turn_timer"]) - delta
	if float(hazard["turn_timer"]) <= 0.0:
		hazard["direction"] = _random_tornado_direction()
		hazard["turn_timer"] = _rng.randf_range(0.18, 0.42)
	var position: Vector2 = hazard["position"] as Vector2
	position += (hazard["direction"] as Vector2) * float(hazard["speed"]) * delta
	if position.x < 0.0 or position.x > float(_grid_size.x - 1):
		hazard["direction"] = Vector2(
			-(hazard["direction"] as Vector2).x, (hazard["direction"] as Vector2).y
		)
	if position.y < 0.0 or position.y > float(_grid_size.y - 1):
		hazard["direction"] = Vector2(
			(hazard["direction"] as Vector2).x, -(hazard["direction"] as Vector2).y
		)
	position.x = clampf(position.x, 0.0, float(_grid_size.x - 1))
	position.y = clampf(position.y, 0.0, float(_grid_size.y - 1))
	hazard["position"] = position


func _advance_sandstorm(hazard: Dictionary, delta: float) -> void:
	hazard["position"] = (
		(hazard["position"] as Vector2)
		+ (hazard["direction"] as Vector2) * float(hazard["speed"]) * delta
	)
	if _sandstorm_is_outside(hazard):
		hazard["expired"] = true


func _apply_contact_damage(hazard: Dictionary, delta: float) -> void:
	var source: StringName = hazard["kind"] as StringName
	var overlapping: bool = (
		_tornado_overlaps_player(hazard)
		if source == &"tornado"
		else _sandstorm_overlaps_player(hazard)
	)
	if not overlapping:
		hazard["contact_time"] = 0.0
		hazard["contacting"] = false
		return
	var damage: int = int(
		TORNADO_DAMAGE_PER_SECOND if source == &"tornado" else SANDSTORM_DAMAGE_PER_SECOND
	)
	if not bool(hazard["contacting"]):
		hazard["contacting"] = true
		hazard["contact_time"] = 0.0
		damage_tick.emit(damage, source)
		return
	hazard["contact_time"] = float(hazard["contact_time"]) + delta
	while float(hazard["contact_time"]) >= 1.0:
		hazard["contact_time"] = float(hazard["contact_time"]) - 1.0
		damage_tick.emit(damage, source)


func _tornado_overlaps_player(hazard: Dictionary) -> bool:
	if get_tornado_state(int(hazard["id"])) != &"active":
		return false
	var offset: Vector2 = _player_position - (hazard["position"] as Vector2)
	return absf(offset.x) <= 0.58 and absf(offset.y) <= 0.58


func _sandstorm_overlaps_player(hazard: Dictionary) -> bool:
	var position: Vector2 = hazard["position"] as Vector2
	var size: Vector2 = Vector2(_sandstorm_size(hazard))
	return (
		_player_position.x >= position.x - 0.5
		and _player_position.y >= position.y - 0.5
		and _player_position.x < position.x + size.x - 0.5
		and _player_position.y < position.y + size.y - 0.5
	)


func _sandstorm_cells(hazard: Dictionary) -> Array[Vector2i]:
	var size: Vector2i = _sandstorm_size(hazard)
	var top_left: Vector2i = Vector2i((hazard["position"] as Vector2).round())
	var cells: Array[Vector2i] = []
	for y: int in range(size.y):
		for x: int in range(size.x):
			cells.append(top_left + Vector2i(x, y))
	return cells


func _sandstorm_size(hazard: Dictionary) -> Vector2i:
	var direction: Vector2 = hazard["direction"] as Vector2
	return Vector2i(2, 3) if not is_zero_approx(direction.x) else Vector2i(3, 2)


func _sandstorm_is_outside(hazard: Dictionary) -> bool:
	var position: Vector2 = hazard["position"] as Vector2
	var direction: Vector2 = hazard["direction"] as Vector2
	return (
		(direction.x > 0.0 and position.x > float(_grid_size.x + 3))
		or (direction.x < 0.0 and position.x < -4.0)
		or (direction.y > 0.0 and position.y > float(_grid_size.y + 3))
		or (direction.y < 0.0 and position.y < -4.0)
	)


func _random_tornado_direction() -> Vector2:
	var directions: Array[Vector2] = [
		Vector2.UP,
		Vector2(1.0, -1.0).normalized(),
		Vector2.RIGHT,
		Vector2(1.0, 1.0).normalized(),
		Vector2.DOWN,
		Vector2(-1.0, 1.0).normalized(),
		Vector2.LEFT,
		Vector2(-1.0, -1.0).normalized(),
	]
	return directions[_rng.randi_range(0, directions.size() - 1)]


func _take_id() -> int:
	var hazard_id: int = _next_id
	_next_id += 1
	return hazard_id


func _find_hazard(hazard_id: int) -> Dictionary:
	for hazard: Dictionary in _hazards:
		if int(hazard["id"]) == hazard_id:
			return hazard
	return {}


func _grid_to_screen(position: Vector2) -> Vector2:
	return (
		_map_origin
		+ Vector2(
			(position.x - position.y) * _tile_size.x * 0.5,
			(position.x + position.y) * _tile_size.y * 0.5,
		)
	)


func _draw() -> void:
	for hazard: Dictionary in _hazards:
		if hazard["kind"] == &"tornado":
			_draw_tornado(hazard)
		else:
			_draw_sandstorm(hazard)


func _draw_tornado(hazard: Dictionary) -> void:
	var center: Vector2 = _grid_to_screen(hazard["position"] as Vector2)
	var formation: float = float(hazard["formation"])
	var progress: float = clampf(float(hazard["age"]) / maxf(formation, 0.001), 0.0, 1.0)
	var active: bool = float(hazard["age"]) >= formation
	var active_age: float = maxf(float(hazard["age"]) - formation, 0.0)
	var fade: float = clampf(
		(float(hazard["lifetime"]) - active_age) / TORNADO_FADE_SECONDS, 0.0, 1.0
	)
	var density: int = 26 if not active else 76
	var radius: float = 17.0 + progress * 24.0
	_draw_ellipse_shape(
		center + Vector2(0.0, 12.0),
		Vector2(35.0, 12.0),
		Color(0.2, 0.11, 0.06, 0.35 * fade),
	)
	for index: int in range(density):
		var layer: float = float(index % 12) / 11.0
		var angle: float = float(index) * 2.399 + _time * (2.0 + progress * 8.0)
		var ring: float = radius * (0.28 + 0.72 * layer)
		var point: Vector2 = (
			center + Vector2(cos(angle) * ring, sin(angle) * ring * 0.42 - layer * 58.0 * progress)
		)
		var color: Color = DUST.lerp(PALE_DUST, layer)
		color.a = (0.22 + progress * 0.48) * fade
		draw_circle(point, 2.0 + layer * 3.0, color)
	var ring_color: Color = PALE_DUST
	ring_color.a = (0.18 if not active else 0.55) * fade
	draw_arc(center, radius, 0.0, TAU, 32, ring_color, 2.0 if not active else 4.0)


func _draw_sandstorm(hazard: Dictionary) -> void:
	var cells: Array[Vector2i] = _sandstorm_cells(hazard)
	var direction: Vector2 = hazard["direction"] as Vector2
	for cell: Vector2i in cells:
		var center: Vector2 = _grid_to_screen(Vector2(cell))
		var half: Vector2 = _tile_size * 0.5
		draw_colored_polygon(
			PackedVector2Array(
				[
					center + Vector2(0.0, -half.y),
					center + Vector2(half.x, 0.0),
					center + Vector2(0.0, half.y),
					center + Vector2(-half.x, 0.0),
				]
			),
			Color(0.72, 0.38, 0.15, 0.18),
		)
	var top_left: Vector2 = hazard["position"] as Vector2
	var size: Vector2 = Vector2(_sandstorm_size(hazard))
	var screen_direction: Vector2 = (
		(_grid_to_screen(direction) - _grid_to_screen(Vector2.ZERO)).normalized()
	)
	for index: int in range(112):
		var u: float = fmod(float(index) * 0.6180339 + _time * 0.21, 1.0)
		var v: float = fmod(float(index) * 0.4142135 + sin(_time + float(index)) * 0.05, 1.0)
		var point: Vector2 = _grid_to_screen(top_left + Vector2(u * size.x, v * size.y))
		var color: Color = DARK_DUST.lerp(PALE_DUST, fmod(float(index) * 0.17, 1.0))
		color.a = 0.22 + fmod(float(index) * 0.09, 0.34)
		var length: float = 18.0 + fmod(float(index) * 7.0, 38.0)
		draw_line(point, point + screen_direction * length, color, 2.0 + fmod(float(index), 4.0))


func _draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
