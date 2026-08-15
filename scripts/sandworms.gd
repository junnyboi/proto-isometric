extends Node2D

signal damage_tick(amount: int, source: StringName)

const MAX_HEALTH: int = 4
const ATTACK_DAMAGE: int = 10
const DETECTION_RANGE: float = 8.0
const ATTACK_RANGE: float = 0.72
const MOVE_SPEED: float = 1.28
const ATTACK_COOLDOWN: float = 1.15
const EMERGE_SECONDS: float = 0.8
const DISPERSE_SECONDS: float = 1.25
const MAX_WORMS: int = 4
const SAND: Color = Color("d69a49")
const PALE_SAND: Color = Color("f0c77c")
const SHELL: Color = Color("7e3f2b")
const SHELL_DARK: Color = Color("351d19")
const HEALTH: Color = Color("e75d46")
const HEALTH_BACK: Color = Color("1a1110")

var _tile_size: Vector2 = Vector2(90.0, 45.0)
var _map_origin: Vector2 = Vector2(760.0, 70.0)
var _player_position: Vector2 = Vector2.ZERO
var _worms: Array[Dictionary] = []
var _next_id: int = 1
var _time: float = 0.0
var _spawn_timer: float = 7.0
var _auto_spawn: bool = true
var _outpost_linked: bool = false
var _last_attack_count: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 0x5A6D701


func configure(tile_size: Vector2, map_origin: Vector2) -> void:
	_tile_size = tile_size
	_map_origin = map_origin


func set_auto_spawn(enabled: bool) -> void:
	_auto_spawn = enabled


func set_player_position(position: Vector2) -> void:
	_player_position = position


func set_outpost_linked(linked: bool) -> void:
	if linked and not _outpost_linked:
		for worm: Dictionary in _worms:
			worm["state"] = &"dispersing"
			worm["disperse_time"] = 0.0
	_outpost_linked = linked


func advance(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	if step <= 0.0:
		return
	_time += step
	if _auto_spawn and not _outpost_linked:
		_advance_spawner(step)
	for index: int in range(_worms.size() - 1, -1, -1):
		var worm: Dictionary = _worms[index]
		worm["age"] = float(worm["age"]) + step
		worm["hit_flash"] = maxf(float(worm["hit_flash"]) - step, 0.0)
		worm["attack_time"] = maxf(float(worm["attack_time"]) - step, 0.0)
		if worm["state"] == &"dispersing":
			_advance_disperse(worm, step)
			if float(worm["disperse_time"]) >= DISPERSE_SECONDS:
				_worms.remove_at(index)
			continue
		_advance_worm(worm, step)
	queue_redraw()


func spawn_worm(position: Vector2, emerge_seconds: float = EMERGE_SECONDS) -> int:
	var worm_id: int = _next_id
	_next_id += 1
	(
		_worms
		. append(
			{
				"id": worm_id,
				"position": position,
				"direction": Vector2.DOWN,
				"health": MAX_HEALTH,
				"age": 0.0,
				"emerge": maxf(emerge_seconds, 0.0),
				"attack_time": 0.0,
				"hit_flash": 0.0,
				"state": &"burrowing",
				"disperse_time": 0.0,
			}
		)
	)
	queue_redraw()
	return worm_id


func clear_worms() -> void:
	_worms.clear()
	queue_redraw()


func get_worm_count() -> int:
	return _worms.size()


func get_health(worm_id: int) -> int:
	var worm: Dictionary = _find_worm(worm_id)
	return int(worm.get("health", 0))


func get_worm_position(worm_id: int) -> Vector2:
	var worm: Dictionary = _find_worm(worm_id)
	return worm.get("position", Vector2(-9999.0, -9999.0)) as Vector2


func get_state(worm_id: int) -> StringName:
	var worm: Dictionary = _find_worm(worm_id)
	return worm.get("state", &"missing") as StringName


func get_last_attack_count() -> int:
	return _last_attack_count


func find_target(target_cell: Vector2i) -> int:
	var target: Vector2 = Vector2(target_cell)
	var best_id: int = -1
	var best_distance: float = 0.86
	for worm: Dictionary in _worms:
		if worm["state"] == &"dispersing" or float(worm["age"]) < float(worm["emerge"]):
			continue
		var distance: float = (worm["position"] as Vector2).distance_to(target)
		if distance <= best_distance:
			best_distance = distance
			best_id = int(worm["id"])
	return best_id


func hit_worm(worm_id: int, damage: int = 1) -> bool:
	for index: int in range(_worms.size()):
		var worm: Dictionary = _worms[index]
		if int(worm["id"]) != worm_id or worm["state"] == &"dispersing":
			continue
		worm["health"] = maxi(int(worm["health"]) - maxi(damage, 0), 0)
		worm["hit_flash"] = 0.18
		if int(worm["health"]) <= 0:
			_worms.remove_at(index)
		queue_redraw()
		return true
	return false


func _advance_spawner(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0 or _worms.size() >= MAX_WORMS:
		return
	var angle: float = _rng.randf_range(0.0, TAU)
	var radius: float = _rng.randf_range(5.5, 8.5)
	spawn_worm(_player_position + Vector2(cos(angle), sin(angle)) * radius)
	_spawn_timer = _rng.randf_range(10.0, 16.0)


func _advance_worm(worm: Dictionary, delta: float) -> void:
	if float(worm["age"]) < float(worm["emerge"]):
		worm["state"] = &"burrowing"
		return
	var position: Vector2 = worm["position"] as Vector2
	var offset: Vector2 = _player_position - position
	var distance: float = offset.length()
	if distance > DETECTION_RANGE:
		worm["state"] = &"idle"
		return
	if distance > ATTACK_RANGE:
		worm["state"] = &"pursuing"
		worm["direction"] = offset.normalized()
		worm["position"] = position + (worm["direction"] as Vector2) * MOVE_SPEED * delta
		return
	worm["state"] = &"attacking"
	if float(worm["attack_time"]) <= 0.0:
		worm["attack_time"] = ATTACK_COOLDOWN
		_last_attack_count += 1
		damage_tick.emit(ATTACK_DAMAGE, &"sandworm")


func _advance_disperse(worm: Dictionary, delta: float) -> void:
	worm["disperse_time"] = float(worm["disperse_time"]) + delta
	var away: Vector2 = (worm["position"] as Vector2) - _player_position
	if away.is_zero_approx():
		away = Vector2.RIGHT
	worm["direction"] = away.normalized()
	worm["position"] = (worm["position"] as Vector2) + away.normalized() * MOVE_SPEED * 2.2 * delta


func _find_worm(worm_id: int) -> Dictionary:
	for worm: Dictionary in _worms:
		if int(worm["id"]) == worm_id:
			return worm
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
	for worm: Dictionary in _worms:
		_draw_worm(worm)


func _draw_worm(worm: Dictionary) -> void:
	var center: Vector2 = _grid_to_screen(worm["position"] as Vector2)
	var state: StringName = worm["state"] as StringName
	var alpha: float = 1.0
	if state == &"dispersing":
		alpha = 1.0 - clampf(float(worm["disperse_time"]) / DISPERSE_SECONDS, 0.0, 1.0)
	var emerge: float = clampf(float(worm["age"]) / maxf(float(worm["emerge"]), 0.001), 0.0, 1.0)
	_draw_sand_wake(center, worm, alpha)
	if emerge < 1.0:
		draw_arc(center, 18.0 + emerge * 19.0, 0.0, TAU, 28, Color(PALE_SAND, 0.45), 3.0)
		return
	var direction: Vector2 = worm["direction"] as Vector2
	var screen_direction: Vector2 = (
		(_grid_to_screen(direction) - _grid_to_screen(Vector2.ZERO)).normalized()
	)
	var side: Vector2 = screen_direction.orthogonal()
	var attack_lunge: float = (
		9.0 if state == &"attacking" and float(worm["attack_time"]) > 0.78 else 0.0
	)
	var head: Vector2 = center + screen_direction * attack_lunge + Vector2(0.0, -18.0)
	for segment: int in range(4, 0, -1):
		var phase: float = _time * 6.0 + float(segment) * 0.8
		var segment_center: Vector2 = (
			head - screen_direction * float(segment) * 17.0 + side * sin(phase) * 6.0
		)
		var shell: Color = SHELL.lightened(float(4 - segment) * 0.035)
		shell.a = alpha
		draw_circle(segment_center, 15.0 - float(segment) * 1.3, shell)
		draw_arc(segment_center, 11.0, PI, TAU, 12, Color(SHELL_DARK, alpha), 3.0)
	var head_color: Color = Color.WHITE if float(worm["hit_flash"]) > 0.0 else SHELL
	head_color.a = alpha
	draw_circle(head, 19.0, head_color)
	draw_arc(head, 20.0, 0.0, TAU, 24, Color(SHELL_DARK, alpha), 4.0)
	var mouth: Vector2 = head + screen_direction * 12.0
	draw_circle(mouth, 8.0, Color(SHELL_DARK, alpha))
	for tooth: int in range(3):
		var tooth_offset: float = float(tooth - 1) * 5.0
		draw_circle(mouth + side * tooth_offset, 1.7, Color(PALE_SAND, alpha))
	_draw_health_bar(head + Vector2(0.0, -35.0), int(worm["health"]), alpha)


func _draw_sand_wake(center: Vector2, worm: Dictionary, alpha: float) -> void:
	var direction: Vector2 = worm["direction"] as Vector2
	var screen_direction: Vector2 = (
		(_grid_to_screen(direction) - _grid_to_screen(Vector2.ZERO)).normalized()
	)
	for mote: int in range(18):
		var phase: float = float(mote) * 2.399 + _time * 4.5
		var trail: float = float(mote % 7) * 8.0
		var point: Vector2 = (
			center - screen_direction * trail + Vector2(cos(phase) * 18.0, sin(phase) * 7.0)
		)
		draw_circle(
			point, 2.0 + float(mote % 3), Color(SAND, (0.18 + float(mote % 4) * 0.07) * alpha)
		)


func _draw_health_bar(position: Vector2, health: int, alpha: float) -> void:
	var width: float = 58.0
	draw_rect(
		Rect2(position - Vector2(width * 0.5, 4.0), Vector2(width, 8.0)),
		Color(HEALTH_BACK, 0.88 * alpha)
	)
	var ratio: float = clampf(float(health) / float(MAX_HEALTH), 0.0, 1.0)
	draw_rect(
		Rect2(position - Vector2(width * 0.5 - 2.0, 2.0), Vector2((width - 4.0) * ratio, 4.0)),
		Color(HEALTH, alpha),
	)
