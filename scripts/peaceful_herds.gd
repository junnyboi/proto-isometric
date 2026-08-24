extends Node2D

signal defeated(creature_id: int, position: Vector2, cores: int, scrap: int)

const DUNE_GRAZER_TEXTURE: Texture2D = preload("res://assets/fauna/dune_grazer.png")
const REEDBACK_TEXTURE: Texture2D = preload("res://assets/fauna/reedback.png")
const RIMEHORN_TEXTURE: Texture2D = preload("res://assets/fauna/rimehorn.png")
const EMBER_RAM_TEXTURE: Texture2D = preload("res://assets/fauna/ember_ram.png")

const SPECIES_BY_BIOME: Dictionary = {
	&"desert": &"dune_grazer",
	&"oasis": &"reedback",
	&"frozen": &"rimehorn",
	&"lava": &"ember_ram",
}
const TEXTURES: Dictionary = {
	&"dune_grazer": DUNE_GRAZER_TEXTURE,
	&"reedback": REEDBACK_TEXTURE,
	&"rimehorn": RIMEHORN_TEXTURE,
	&"ember_ram": EMBER_RAM_TEXTURE,
}
const DISPLAY_SIZES: Dictionary = {
	&"dune_grazer": Vector2(104.0, 104.0),
	&"reedback": Vector2(112.0, 112.0),
	&"rimehorn": Vector2(112.0, 112.0),
	&"ember_ram": Vector2(108.0, 108.0),
}
const LOOT_PROFILES: Dictionary = {
	&"dune_grazer": {&"scrap_chance": 0.70, &"core_chance": 0.03},
	&"reedback": {&"scrap_chance": 0.78, &"core_chance": 0.04},
	&"rimehorn": {&"scrap_chance": 0.84, &"core_chance": 0.06},
	&"ember_ram": {&"scrap_chance": 0.90, &"core_chance": 0.08},
}
const HERD_COUNT: int = 2
const MEMBERS_PER_HERD: int = 4
const MAX_CREATURES: int = HERD_COUNT * MEMBERS_PER_HERD
const MOVE_SPEED: float = 0.58
const FLEE_SPEED: float = 1.04
const AVOID_RADIUS: float = 4.8
const FLEE_RADIUS: float = 2.8
const COHESION_WEIGHT: float = 0.48
const SEPARATION_WEIGHT: float = 0.92
const AVOID_WEIGHT: float = 2.4
const WANDER_WEIGHT: float = 0.34
const SEPARATION_RADIUS: float = 1.25
const BOUNCE_HEIGHT: float = 5.0
const BOUNCE_RATE: float = 4.4
const TARGET_RADIUS: float = 0.82
const SPAWN_MIN_RADIUS: float = 6.0
const SPAWN_MAX_RADIUS: float = 10.0
const CREATURE_ID_BASE: int = 100_000
const CREATURE_HIT_POINTS: int = 1

var _tile_size: Vector2 = Vector2(90.0, 45.0)
var _map_origin: Vector2 = Vector2(760.0, 70.0)
var _world: RefCounted
var _drop_callback: Callable
var _player_position: Vector2 = Vector2.ZERO
var _active_biome: StringName = &"desert"
var _creatures: Array[Dictionary] = []
var _next_creature_id: int = CREATURE_ID_BASE
var _next_herd_id: int = 1
var _time: float = 0.0
var _auto_spawn: bool = true
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _loot_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 0x48E2D91
	_loot_rng.seed = 0x10A7B4E


func configure(
	tile_size: Vector2,
	map_origin: Vector2,
	world: RefCounted,
	drop_callback: Callable = Callable(),
) -> bool:
	if (
		world == null
		or not world.has_method("is_walkable")
		or not world.has_method("_biome_at")
	):
		return false
	_tile_size = tile_size
	_map_origin = map_origin
	_world = world
	_drop_callback = drop_callback
	return true


func set_auto_spawn(enabled: bool) -> void:
	_auto_spawn = enabled


func set_loot_random_seed(seed_value: int) -> void:
	_loot_rng.seed = seed_value


func set_player_position(position: Vector2) -> void:
	_player_position = position
	var biome: StringName = _world.call("_biome_at", Vector2i(position.round())) as StringName
	set_active_biome(biome)
	if _auto_spawn and _creatures.is_empty():
		_spawn_biome_herds()


func set_active_biome(biome: StringName) -> void:
	if biome == _active_biome:
		return
	_active_biome = biome
	clear()


func advance(delta: float) -> void:
	var step: float = minf(maxf(delta, 0.0), 0.1)
	if step <= 0.0:
		return
	_time += step
	if _auto_spawn and _creatures.is_empty():
		_spawn_biome_herds()
	var centers: Dictionary = _herd_centers()
	for creature: Dictionary in _creatures:
		_advance_creature(creature, centers, step)
	queue_redraw()


func clear() -> void:
	_creatures.clear()
	queue_redraw()


func spawn_herd(center: Vector2, count: int, biome: StringName = &"") -> int:
	var target_biome: StringName = _active_biome if biome == &"" else biome
	var kind: StringName = species_for_biome(target_biome)
	if kind == &"" or count <= 0 or _creatures.size() >= MAX_CREATURES:
		return -1
	var herd_id: int = _next_herd_id
	_next_herd_id += 1
	var bounded_count: int = mini(count, MAX_CREATURES - _creatures.size())
	for member: int in range(bounded_count):
		var angle: float = TAU * float(member) / float(maxi(bounded_count, 1))
		var offset: Vector2 = Vector2.from_angle(angle) * (1.2 + float(member % 2) * 0.35)
		var position: Vector2 = _find_walkable(center + offset, target_biome)
		if position.x < -9000.0:
			continue
		var heading: Vector2 = Vector2.from_angle(angle + PI * 0.37)
		_creatures.append(
			{
				&"id": _next_creature_id,
				&"herd_id": herd_id,
				&"kind": kind,
				&"biome": target_biome,
				&"position": position,
				&"velocity": heading * MOVE_SPEED,
				&"direction": heading,
				&"phase": float(member) * 0.83 + float(herd_id) * 0.41,
				&"health": CREATURE_HIT_POINTS,
				&"max_health": CREATURE_HIT_POINTS,
			}
		)
		_next_creature_id += 1
	queue_redraw()
	return herd_id


func get_creature_count() -> int:
	return _creatures.size()


func get_snapshot(creature_id: int) -> Dictionary:
	var creature: Dictionary = _find_creature(creature_id)
	return creature.duplicate(true)


func get_creature_position(creature_id: int) -> Vector2:
	var creature: Dictionary = _find_creature(creature_id)
	return creature.get(&"position", Vector2(-9999.0, -9999.0)) as Vector2


func get_snapshots() -> Array[Dictionary]:
	return _creatures.duplicate(true)


func find_target(cell: Vector2i) -> int:
	var target: Vector2 = Vector2(cell)
	var best_id: int = -1
	var best_distance: float = TARGET_RADIUS
	for creature: Dictionary in _creatures:
		var distance: float = (creature[&"position"] as Vector2).distance_to(target)
		if distance <= best_distance:
			best_distance = distance
			best_id = int(creature[&"id"])
	return best_id


func hit_creature(creature_id: int, damage: int = 1) -> bool:
	if damage <= 0:
		return false
	for index: int in range(_creatures.size()):
		var creature: Dictionary = _creatures[index]
		if int(creature[&"id"]) != creature_id:
			continue
		creature[&"health"] = maxi(int(creature.get(&"health", CREATURE_HIT_POINTS)) - damage, 0)
		if int(creature[&"health"]) > 0:
			_creatures[index] = creature
			return true
		var position: Vector2 = creature[&"position"] as Vector2
		var loot: Dictionary = _roll_resources(creature[&"kind"] as StringName)
		var cores: int = int(loot[&"cores"])
		var scrap: int = int(loot[&"scrap"])
		_creatures.remove_at(index)
		if _drop_callback.is_valid():
			_drop_callback.call(position, cores, scrap)
		defeated.emit(creature_id, position, cores, scrap)
		queue_redraw()
		return true
	return false


static func species_for_biome(biome: StringName) -> StringName:
	return SPECIES_BY_BIOME.get(biome, &"") as StringName


static func texture_for(kind: StringName) -> Texture2D:
	return TEXTURES.get(kind) as Texture2D


static func resource_amount(kind: StringName) -> int:
	return 1 if LOOT_PROFILES.has(kind) else 0


static func loot_profile(kind: StringName) -> Dictionary:
	return (LOOT_PROFILES.get(kind, {}) as Dictionary).duplicate(true)


func _roll_resources(kind: StringName) -> Dictionary:
	var profile: Dictionary = loot_profile(kind)
	if profile.is_empty():
		return {&"cores": 0, &"scrap": 0}
	return {
		&"cores": 1 if _loot_rng.randf() < float(profile[&"core_chance"]) else 0,
		&"scrap": 1 if _loot_rng.randf() < float(profile[&"scrap_chance"]) else 0,
	}


static func name_key(kind: StringName) -> StringName:
	return StringName("fauna.%s.name" % String(kind))


static func facing_left(direction: Vector2) -> bool:
	return direction.x - direction.y < 0.0


static func bounce_offset(time: float, phase: float) -> float:
	return absf(sin(time * BOUNCE_RATE + phase)) * BOUNCE_HEIGHT


func _spawn_biome_herds() -> void:
	for herd_index: int in range(HERD_COUNT):
		var open_field_angle: float = PI * (0.195 + float(herd_index) * 0.11)
		var angle: float = open_field_angle + _rng.randf_range(-0.06, 0.06)
		var radius: float = _rng.randf_range(SPAWN_MIN_RADIUS, 7.2)
		var center: Vector2 = _player_position + Vector2.from_angle(angle) * radius
		center = _find_walkable(center, _active_biome)
		if center.x < -9000.0:
			continue
		spawn_herd(center, MEMBERS_PER_HERD, _active_biome)


func _advance_creature(creature: Dictionary, centers: Dictionary, delta: float) -> void:
	var position: Vector2 = creature[&"position"] as Vector2
	var velocity: Vector2 = creature[&"velocity"] as Vector2
	var herd_center: Vector2 = centers.get(creature[&"herd_id"], position) as Vector2
	var cohesion: Vector2 = (herd_center - position).limit_length(1.0)
	var separation: Vector2 = _separation_for(creature)
	var to_player: Vector2 = position - _player_position
	var distance: float = to_player.length()
	var avoidance: Vector2 = Vector2.ZERO
	if distance < AVOID_RADIUS:
		var away: Vector2 = Vector2.RIGHT if to_player.is_zero_approx() else to_player.normalized()
		avoidance = away * (1.0 - distance / AVOID_RADIUS)
	var phase: float = float(creature[&"phase"])
	var wander: Vector2 = Vector2.from_angle(_time * 0.37 + phase * 2.13)
	var steering: Vector2 = (
		cohesion * COHESION_WEIGHT
		+ separation * SEPARATION_WEIGHT
		+ avoidance * AVOID_WEIGHT
		+ wander * WANDER_WEIGHT
	)
	if steering.is_zero_approx():
		steering = creature[&"direction"] as Vector2
	var speed: float = FLEE_SPEED if distance < FLEE_RADIUS else MOVE_SPEED
	var desired: Vector2 = steering.normalized() * speed
	velocity = velocity.lerp(desired, minf(delta * 2.6, 1.0))
	var candidate: Vector2 = position + velocity * delta
	var biome: StringName = creature[&"biome"] as StringName
	if not _position_is_valid(candidate, biome):
		velocity = -velocity.rotated(0.47 + phase * 0.03)
		candidate = position + velocity * delta
		if not _position_is_valid(candidate, biome):
			candidate = position
	creature[&"position"] = candidate
	creature[&"velocity"] = velocity
	if not velocity.is_zero_approx():
		creature[&"direction"] = velocity.normalized()


func _separation_for(creature: Dictionary) -> Vector2:
	var position: Vector2 = creature[&"position"] as Vector2
	var total: Vector2 = Vector2.ZERO
	for neighbor: Dictionary in _creatures:
		if int(neighbor[&"id"]) == int(creature[&"id"]):
			continue
		var away: Vector2 = position - (neighbor[&"position"] as Vector2)
		var distance: float = away.length()
		if distance <= 0.001 or distance >= SEPARATION_RADIUS:
			continue
		total += away.normalized() * (1.0 - distance / SEPARATION_RADIUS)
	return total.limit_length(1.0)


func _herd_centers() -> Dictionary:
	var totals: Dictionary = {}
	var counts: Dictionary = {}
	for creature: Dictionary in _creatures:
		var herd_id: int = int(creature[&"herd_id"])
		totals[herd_id] = (totals.get(herd_id, Vector2.ZERO) as Vector2) + (
			creature[&"position"] as Vector2
		)
		counts[herd_id] = int(counts.get(herd_id, 0)) + 1
	for herd_id: Variant in totals:
		totals[herd_id] = (totals[herd_id] as Vector2) / float(counts[herd_id])
	return totals


func _find_walkable(origin: Vector2, biome: StringName) -> Vector2:
	for radius: int in range(0, 7):
		for index: int in range(maxi(radius * 8, 1)):
			var angle: float = TAU * float(index) / float(maxi(radius * 8, 1))
			var candidate: Vector2 = origin + Vector2.from_angle(angle) * float(radius)
			if _position_is_valid(candidate, biome):
				return candidate
	return Vector2(-9999.0, -9999.0)


func _position_is_valid(position: Vector2, biome: StringName) -> bool:
	var cell: Vector2i = Vector2i(position.round())
	return (
		bool(_world.call("is_walkable", cell))
		and _world.call("_biome_at", cell) == biome
		and (
			not _world.has_method("_is_in_sanctuary")
			or not bool(_world.call("_is_in_sanctuary", position))
		)
	)


func _find_creature(creature_id: int) -> Dictionary:
	for creature: Dictionary in _creatures:
		if int(creature[&"id"]) == creature_id:
			return creature
	return {}


func _grid_to_screen(position: Vector2) -> Vector2:
	return _map_origin + Vector2(
		(position.x - position.y) * _tile_size.x * 0.5,
		(position.x + position.y) * _tile_size.y * 0.5,
	)


func _draw() -> void:
	for creature: Dictionary in _creatures:
		_draw_creature(creature)


func _draw_creature(creature: Dictionary) -> void:
	var kind: StringName = creature[&"kind"] as StringName
	var texture: Texture2D = TEXTURES.get(kind) as Texture2D
	if texture == null:
		return
	var center: Vector2 = _grid_to_screen(creature[&"position"] as Vector2)
	center.y -= bounce_offset(_time, float(creature[&"phase"]))
	var size: Vector2 = DISPLAY_SIZES.get(kind, Vector2(108.0, 108.0)) as Vector2
	var scale_x: float = -1.0 if facing_left(creature[&"direction"] as Vector2) else 1.0
	draw_set_transform(center, 0.0, Vector2(scale_x, 1.0))
	draw_texture_rect(texture, Rect2(-size * Vector2(0.5, 0.72), size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
