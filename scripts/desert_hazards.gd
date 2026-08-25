extends Node2D

signal damage_tick(amount: int, source: StringName)
signal deep_event_started(kind: StringName, biome: StringName, cell: Vector2i)
signal deep_event_stabilized(event_id: int, token: String, item_id: StringName, count: int)

const HazardOpportunityScript: GDScript = preload("res://scripts/hazard_opportunity_catalog.gd")
const WorldSafetyScript: GDScript = preload("res://scripts/world_safety.gd")

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
const DEEP_EVENT_COOLDOWN_SECONDS: float = 6.5
const DEEP_CELL_MODULUS: int = 20
const DEEP_CELL_SLOTS: int = 9
const DEEP_TRIGGER_CHANCE: float = 0.55
const MAX_DEEP_EVENTS: int = 2
const DEEP_EVENT_PROFILES: Dictionary = {
	&"desert":
	{
		&"kind": &"quicksand_collapse",
		&"damage": 5,
		&"telegraph": 1.4,
		&"lifetime": 2.2,
		&"radius": 0.92,
	},
	&"oasis":
	{
		&"kind": &"bog_gas_bloom",
		&"damage": 4,
		&"telegraph": 1.8,
		&"lifetime": 2.8,
		&"radius": 1.15,
	},
	&"frozen":
	{
		&"kind": &"ice_shear",
		&"damage": 6,
		&"telegraph": 1.1,
		&"lifetime": 1.9,
		&"radius": 1.05,
	},
	&"lava":
	{
		&"kind": &"magma_vent",
		&"damage": 8,
		&"telegraph": 1.3,
		&"lifetime": 2.3,
		&"radius": 0.88,
	},
}

var _spawn_half_extents: Vector2i = Vector2i(14, 11)
var _tile_size: Vector2 = Vector2(90.0, 45.0)
var _map_origin: Vector2 = Vector2(760.0, 70.0)
var _player_position: Vector2 = Vector2.ZERO
var _world_center: Vector2i = Vector2i.ZERO
var _world: RefCounted
var _hazards: Array[Dictionary] = []
var _deep_events: Array[Dictionary] = []
var _last_player_cell: Vector2i = Vector2i(-9999, -9999)
var _deep_event_cooldown: float = 0.0
var _deep_events_enabled: bool = true
var _next_id: int = 1
var _time: float = 0.0
var _auto_spawn: bool = true
var _tornado_timer: float = 6.0
var _sandstorm_timer: float = 12.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _event_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _prepared_capabilities: Array[StringName] = []


func _ready() -> void:
	add_to_group("weather_audio_source")
	_rng.seed = 0xCA7D1A1
	_event_rng.seed = 0xD33F71E


func configure(
	tile_size: Vector2,
	map_origin: Vector2,
	spawn_half_extents: Vector2i,
	world: RefCounted = null,
) -> void:
	_tile_size = tile_size
	_map_origin = map_origin
	_spawn_half_extents = spawn_half_extents
	_world = world


func set_auto_spawn(enabled: bool) -> void:
	_auto_spawn = enabled


func set_deep_events_enabled(enabled: bool) -> void:
	_deep_events_enabled = enabled


func set_event_random_seed(seed_value: int) -> void:
	_event_rng.seed = seed_value


func reset_deep_event_cooldown() -> void:
	_deep_event_cooldown = 0.0


func _set_prepared_capabilities(capabilities: Array[StringName]) -> void:
	_prepared_capabilities = capabilities.duplicate()
	_prepared_capabilities.sort_custom(
		func(a: StringName, b: StringName) -> bool: return String(a) < String(b)
	)


func stabilize_deep_event(event_id: int) -> bool:
	for index: int in _deep_events.size():
		var event: Dictionary = _deep_events[index]
		if int(event[&"id"]) != event_id:
			continue
		var kind: StringName = event[&"kind"] as StringName
		var opportunity: Dictionary = HazardOpportunityScript.definition(kind)
		var prepared: bool = opportunity[&"preparation"] in _prepared_capabilities
		if not HazardOpportunityScript.can_stabilize(kind, float(event[&"age"]), prepared):
			return false
		_deep_events.remove_at(index)
		var cell: Vector2i = event[&"cell"] as Vector2i
		var token: String = "hazard:%s:%d,%d" % [kind, cell.x, cell.y]
		deep_event_stabilized.emit(
			event_id,
			token,
			opportunity[&"reward_item_id"] as StringName,
			int(opportunity[&"reward_count"])
		)
		return true
	return false


func set_player_cell(cell: Vector2i) -> void:
	_player_position = Vector2(cell)
	_handle_player_cell_entry(cell)
	if cell != Vector2i(-9999, -9999):
		_world_center = cell


func set_player_position(position: Vector2) -> void:
	_player_position = position
	var rounded: Vector2i = Vector2i(position.round())
	_handle_player_cell_entry(rounded)
	if position != Vector2(-9999.0, -9999.0):
		_world_center = rounded


func advance(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	if step <= 0.0:
		return
	_time += step
	_deep_event_cooldown = maxf(_deep_event_cooldown - step, 0.0)
	if _auto_spawn:
		_advance_spawners(step)
	_advance_deep_events(step)
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
	if not WorldSafetyScript.allows_spawn(Vector2(cell), _world):
		return -1
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
	if (
		normalized == Vector2i.ZERO
		or (normalized.x != 0 and normalized.y != 0)
		or not WorldSafetyScript.allows_spawn(Vector2(origin), _world)
	):
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
	_deep_events.clear()
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


func get_deep_event_count(kind: StringName = &"") -> int:
	if kind == &"":
		return _deep_events.size()
	var count: int = 0
	for event: Dictionary in _deep_events:
		if event[&"kind"] == kind:
			count += 1
	return count


func get_deep_event_snapshots() -> Array[Dictionary]:
	return _deep_events.duplicate(true)


static func is_deep_biome_cell(biome: StringName, cell: Vector2i) -> bool:
	match biome:
		&"desert":
			return absi(cell.x) >= 24 or cell.y >= 26
		&"oasis":
			return cell.x >= 32
		&"frozen":
			return cell.y <= -22
		&"lava":
			return cell.x <= -22
	return false


static func is_deep_event_candidate(cell: Vector2i) -> bool:
	return posmod(_deep_cell_hash(cell, 0xD33F71E), DEEP_CELL_MODULUS) < DEEP_CELL_SLOTS


static func profile_for_biome(biome: StringName) -> Dictionary:
	return (DEEP_EVENT_PROFILES.get(biome, {}) as Dictionary).duplicate(true)


func force_deep_event(biome: StringName, cell: Vector2i) -> int:
	var profile: Dictionary = profile_for_biome(biome)
	if profile.is_empty() or not WorldSafetyScript.allows_deep_event(cell, _world):
		return -1
	return _spawn_deep_event(biome, cell, profile)


func _handle_player_cell_entry(cell: Vector2i) -> void:
	if cell == _last_player_cell:
		return
	_last_player_cell = cell
	if (
		cell == Vector2i(-9999, -9999)
		or not _deep_events_enabled
		or _deep_event_cooldown > 0.0
		or _deep_events.size() >= MAX_DEEP_EVENTS
		or _world == null
		or not _world.has_method("_biome_at")
	):
		return
	var biome: StringName = _world.call("_biome_at", cell) as StringName
	if not is_deep_biome_cell(biome, cell) or not is_deep_event_candidate(cell):
		return
	if (
		_world.has_method("_is_in_sanctuary")
		and bool(_world.call("_is_in_sanctuary", Vector2(cell)))
	):
		return
	if (
		not WorldSafetyScript.allows_deep_event(cell, _world)
		or _event_rng.randf() > DEEP_TRIGGER_CHANCE
	):
		return
	var profile: Dictionary = profile_for_biome(biome)
	if not profile.is_empty():
		_spawn_deep_event(biome, cell, profile)


func _spawn_deep_event(biome: StringName, cell: Vector2i, profile: Dictionary) -> int:
	if (
		_deep_events.size() >= MAX_DEEP_EVENTS
		or not WorldSafetyScript.allows_deep_event(cell, _world)
	):
		return -1
	var event_id: int = _take_id()
	var kind: StringName = profile[&"kind"] as StringName
	(
		_deep_events
		. append(
		{
			&"id": event_id,
			&"kind": kind,
			&"biome": biome,
			&"cell": cell,
			&"age": 0.0,
			&"damage": int(profile[&"damage"]),
			&"telegraph": float(profile[&"telegraph"]),
			&"lifetime": float(profile[&"lifetime"]),
			&"radius": float(profile[&"radius"]),
			&"resolved": false,
		}
	)
	)
	_deep_event_cooldown = DEEP_EVENT_COOLDOWN_SECONDS
	deep_event_started.emit(kind, biome, cell)
	queue_redraw()
	return event_id


func _advance_deep_events(delta: float) -> void:
	for index: int in range(_deep_events.size() - 1, -1, -1):
		var event: Dictionary = _deep_events[index]
		event[&"age"] = float(event[&"age"]) + delta
		if not bool(event[&"resolved"]) and float(event[&"age"]) >= float(event[&"telegraph"]):
			event[&"resolved"] = true
			var distance: float = _player_position.distance_to(Vector2(event[&"cell"]))
			if (
				distance <= float(event[&"radius"])
				and WorldSafetyScript.allows_hazard_damage(_player_position, _world)
			):
				var kind: StringName = event[&"kind"] as StringName
				var opportunity: Dictionary = HazardOpportunityScript.definition(kind)
				var prepared: bool = opportunity[&"preparation"] in _prepared_capabilities
				damage_tick.emit(
					HazardOpportunityScript.mitigated_damage(kind, int(event[&"damage"]), prepared),
					kind
				)
		if float(event[&"age"]) >= float(event[&"lifetime"]):
			_deep_events.remove_at(index)


static func _deep_cell_hash(cell: Vector2i, salt: int) -> int:
	var value: int = cell.x * 73856093 ^ cell.y * 19349663 ^ salt * 83492791
	value = (value ^ (value >> 13)) * 1274126177
	return value ^ (value >> 16)


func _advance_spawners(delta: float) -> void:
	_tornado_timer -= delta
	while _tornado_timer <= 0.0:
		spawn_tornado(
			Vector2i(
				(
					_rng
					. randi_range(
						_world_center.x - _spawn_half_extents.x,
						_world_center.x + _spawn_half_extents.x,
					)
				),
				(
					_rng
					. randi_range(
						_world_center.y - _spawn_half_extents.y,
						_world_center.y + _spawn_half_extents.y,
					)
				),
			)
		)
		_tornado_timer += _rng.randf_range(5.0, 8.5)
	_sandstorm_timer -= delta
	while _sandstorm_timer <= 0.0:
		_spawn_edge_sandstorm()
		_sandstorm_timer += _rng.randf_range(14.0, 21.0)


func _spawn_edge_sandstorm() -> void:
	match _rng.randi_range(0, 3):
		0:
			spawn_sandstorm(
				Vector2i(
					_world_center.x - _spawn_half_extents.x - 3,
					(
						_rng
						. randi_range(
							_world_center.y - _spawn_half_extents.y,
							_world_center.y + _spawn_half_extents.y - 1,
						)
					),
				),
				Vector2i.RIGHT,
			)
		1:
			spawn_sandstorm(
				Vector2i(
					_world_center.x + _spawn_half_extents.x + 1,
					(
						_rng
						. randi_range(
							_world_center.y - _spawn_half_extents.y,
							_world_center.y + _spawn_half_extents.y - 1,
						)
					),
				),
				Vector2i.LEFT,
			)
		2:
			spawn_sandstorm(
				Vector2i(
					(
						_rng
						. randi_range(
							_world_center.x - _spawn_half_extents.x,
							_world_center.x + _spawn_half_extents.x - 1,
						)
					),
					_world_center.y - _spawn_half_extents.y - 3,
				),
				Vector2i.DOWN,
			)
		_:
			spawn_sandstorm(
				Vector2i(
					(
						_rng
						. randi_range(
							_world_center.x - _spawn_half_extents.x,
							_world_center.x + _spawn_half_extents.x - 1,
						)
					),
					_world_center.y + _spawn_half_extents.y + 1,
				),
				Vector2i.UP,
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
	hazard["position"] = position
	if not WorldSafetyScript.allows_spawn(position, _world):
		hazard["expired"] = true


func _advance_sandstorm(hazard: Dictionary, delta: float) -> void:
	hazard["position"] = (
		(hazard["position"] as Vector2)
		+ (hazard["direction"] as Vector2) * float(hazard["speed"]) * delta
	)
	if _sandstorm_is_outside(hazard) or _sandstorm_intersects_safety(hazard):
		hazard["expired"] = true


func _sandstorm_intersects_safety(hazard: Dictionary) -> bool:
	for cell: Vector2i in _sandstorm_cells(hazard):
		if not WorldSafetyScript.allows_spawn(Vector2(cell), _world):
			return true
	return false


func _apply_contact_damage(hazard: Dictionary, delta: float) -> void:
	if not WorldSafetyScript.allows_weather_damage(_player_position, _world):
		hazard["contact_time"] = 0.0
		hazard["contacting"] = false
		return
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
		(direction.x > 0.0 and position.x > float(_world_center.x + _spawn_half_extents.x + 4))
		or (direction.x < 0.0 and position.x < float(_world_center.x - _spawn_half_extents.x - 4))
		or (direction.y > 0.0 and position.y > float(_world_center.y + _spawn_half_extents.y + 4))
		or (direction.y < 0.0 and position.y < float(_world_center.y - _spawn_half_extents.y - 4))
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
	for event: Dictionary in _deep_events:
		_draw_deep_event(event)


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


func _draw_deep_event(event: Dictionary) -> void:
	var center: Vector2 = _grid_to_screen(Vector2(event[&"cell"]))
	var age: float = float(event[&"age"])
	var telegraph: float = float(event[&"telegraph"])
	var progress: float = clampf(age / maxf(telegraph, 0.001), 0.0, 1.0)
	var fade: float = clampf((float(event[&"lifetime"]) - age) / 0.55, 0.0, 1.0)
	var pulse: float = 0.5 + sin(_time * 9.0) * 0.12
	match event[&"kind"] as StringName:
		&"quicksand_collapse":
			_draw_ellipse_shape(
				center + Vector2(0.0, 7.0),
				Vector2(43.0, 18.0) * progress,
				Color(0.18, 0.09, 0.03, 0.72 * fade),
			)
			for ring: int in range(3):
				var radii: Vector2 = Vector2(22.0 + ring * 11.0, 8.0 + ring * 5.0) * progress
				_draw_ellipse_outline(
					center + Vector2(0.0, 7.0),
					radii,
					Color(0.92, 0.57, 0.20, (0.65 - ring * 0.12) * fade),
				)
		&"bog_gas_bloom":
			_draw_ellipse_shape(
				center, Vector2(42.0, 20.0) * progress, Color(0.25, 0.52, 0.25, 0.28 * fade)
			)
			for bubble: int in range(8):
				var angle: float = TAU * float(bubble) / 8.0 + _time * 0.25
				var offset: Vector2 = Vector2(cos(angle) * 33.0, sin(angle) * 13.0)
				draw_circle(
					center + offset * progress,
					3.0 + float(bubble % 3),
					Color(0.62, 0.90, 0.45, pulse * fade),
				)
		&"ice_shear":
			var ice_color: Color = Color(0.55, 0.91, 1.0, 0.78 * fade)
			for ray: int in range(8):
				var angle: float = TAU * float(ray) / 8.0 + 0.19
				var length: float = (24.0 + float(ray % 3) * 9.0) * progress
				var endpoint: Vector2 = center + Vector2.from_angle(angle) * length
				draw_line(center, endpoint, ice_color, 2.0 + float(ray % 2))
				draw_line(
					endpoint,
					endpoint + Vector2.from_angle(angle + 0.7) * 9.0 * progress,
					ice_color,
					1.5
				)
		&"magma_vent":
			draw_circle(
				center + Vector2(0.0, 5.0), 25.0 * progress, Color(0.35, 0.04, 0.01, 0.55 * fade)
			)
			draw_arc(
				center + Vector2(0.0, 5.0),
				31.0 * progress,
				0.0,
				TAU,
				28,
				Color(1.0, 0.38, 0.05, 0.86 * fade),
				4.0,
			)
			for ember: int in range(10):
				var angle: float = TAU * float(ember) / 10.0 + _time * 0.45
				var offset: Vector2 = Vector2(cos(angle) * 34.0, sin(angle) * 16.0 - 8.0 * progress)
				draw_circle(
					center + offset * progress,
					2.0 + float(ember % 2),
					Color(1.0, 0.72, 0.16, pulse * fade),
				)


func _draw_ellipse_outline(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(25):
		var angle: float = TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(points, color, 2.0)


func _draw_ellipse_shape(center: Vector2, radii: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
