extends Node2D

signal damage_tick(amount: int, source: StringName)

const GLASSBACK_SCARAB_KIND: StringName = &"glassback_scarab"
const MIRE_TICK_KIND: StringName = &"mire_tick"
const RIME_SHARDLING_KIND: StringName = &"rime_shardling"
const EMBER_SKITTER_KIND: StringName = &"ember_skitter"
# Compatibility alias for systems that use the desert swarm kind as the ID-range sentinel.
const KIND: StringName = GLASSBACK_SCARAB_KIND
const ID_BASE: int = 900_000
const MAX_MITES: int = 12
const MAX_HEALTH: int = 1
const ATTACK_DAMAGE: int = 2
const ATTACK_RANGE: float = 0.92
const MOVE_SPEED: float = 1.46
const WARNING_SECONDS: float = 0.44
const RECOVER_SECONDS: float = 0.58
const DISPERSE_SECONDS: float = 1.1
const SHARED_DAMAGE_COOLDOWN: float = 0.62
const PERSONAL_ATTACK_COOLDOWN: float = 1.15
const SPAWN_RADIUS: float = 5.4
const ORBIT_RADIUS: float = 0.82
const SEPARATION_RADIUS: float = 0.68
const EMERGE_SECONDS: float = 0.72
const EMERGE_DEPTH: float = 18.0
const BOUNCE_HEIGHT: float = 3.0
const BOUNCE_RATE: float = 8.6
const STATE_EMERGE: StringName = &"swarm_emerge"
const STATE_ADVANCE: StringName = &"swarm_advance"
const STATE_WARNING: StringName = &"swarm_warning"
const STATE_RECOVER: StringName = &"swarm_recover"
const STATE_DISPERSING: StringName = &"dispersing"
const MISSING_POSITION: Vector2 = Vector2(-9999.0, -9999.0)
const MOB_DRAW_SIZE: Vector2 = Vector2(54.0, 54.0)

const GLASSBACK_SCARAB_TEXTURE: Texture2D = preload(
	"res://assets/enemies/tiny_mobs/glassback_scarab.png"
)
const MIRE_TICK_TEXTURE: Texture2D = preload("res://assets/enemies/tiny_mobs/mire_tick.png")
const RIME_SHARDLING_TEXTURE: Texture2D = preload(
	"res://assets/enemies/tiny_mobs/rime_shardling.png"
)
const EMBER_SKITTER_TEXTURE: Texture2D = preload(
	"res://assets/enemies/tiny_mobs/ember_skitter.png"
)

const BIOME_KINDS: Dictionary = {
	&"desert": GLASSBACK_SCARAB_KIND,
	&"oasis": MIRE_TICK_KIND,
	&"frozen": RIME_SHARDLING_KIND,
	&"lava": EMBER_SKITTER_KIND,
}
const NAME_KEYS: Dictionary = {
	GLASSBACK_SCARAB_KIND: &"enemy.glassback_scarab.name",
	MIRE_TICK_KIND: &"enemy.mire_tick.name",
	RIME_SHARDLING_KIND: &"enemy.rime_shardling.name",
	EMBER_SKITTER_KIND: &"enemy.ember_skitter.name",
}
const TEXTURES: Dictionary = {
	GLASSBACK_SCARAB_KIND: GLASSBACK_SCARAB_TEXTURE,
	MIRE_TICK_KIND: MIRE_TICK_TEXTURE,
	RIME_SHARDLING_KIND: RIME_SHARDLING_TEXTURE,
	EMBER_SKITTER_KIND: EMBER_SKITTER_TEXTURE,
}
const MOB_PROFILES: Dictionary = {
	GLASSBACK_SCARAB_KIND: {
		&"move_speed": 1.46,
		&"orbit_radius": 0.82,
		&"warning_seconds": 0.44,
		&"recover_seconds": 0.58,
		&"attack_damage": 2,
	},
	MIRE_TICK_KIND: {
		&"move_speed": 1.30,
		&"orbit_radius": 0.74,
		&"warning_seconds": 0.52,
		&"recover_seconds": 0.54,
		&"attack_damage": 2,
	},
	RIME_SHARDLING_KIND: {
		&"move_speed": 1.62,
		&"orbit_radius": 0.94,
		&"warning_seconds": 0.46,
		&"recover_seconds": 0.68,
		&"attack_damage": 2,
	},
	EMBER_SKITTER_KIND: {
		&"move_speed": 1.34,
		&"orbit_radius": 0.84,
		&"warning_seconds": 0.58,
		&"recover_seconds": 0.72,
		&"attack_damage": 3,
	},
}

var _tile_size: Vector2 = Vector2(90.0, 45.0)
var _map_origin: Vector2 = Vector2(760.0, 70.0)
var _world: RefCounted
var _player_position: Vector2 = Vector2.ZERO
var _mites: Array[Dictionary] = []
var _next_id: int = ID_BASE
var _time: float = 0.0
var _shared_damage_remaining: float = 0.0
var _sanctuary_active: bool = false
var _active_biome: StringName = &"desert"
var _active_kind: StringName = GLASSBACK_SCARAB_KIND
var _hovered_id: int = -1
var _last_attack_count: int = 0
var _total_spawned: int = 0


func configure(tile_size: Vector2, map_origin: Vector2, world: RefCounted) -> bool:
	if world == null or not world.has_method("is_walkable"):
		return false
	_tile_size = tile_size
	_map_origin = map_origin
	_world = world
	return true


static func _kind_for_biome(biome: StringName) -> StringName:
	return BIOME_KINDS.get(biome, GLASSBACK_SCARAB_KIND) as StringName


static func _name_key(kind: StringName) -> StringName:
	return NAME_KEYS.get(kind, NAME_KEYS[GLASSBACK_SCARAB_KIND]) as StringName


static func _texture_for(kind: StringName) -> Texture2D:
	return TEXTURES.get(kind, GLASSBACK_SCARAB_TEXTURE) as Texture2D


static func _emergence_progress(remaining: float) -> float:
	var linear: float = 1.0 - clampf(remaining / EMERGE_SECONDS, 0.0, 1.0)
	return smoothstep(0.0, 1.0, linear)


static func _bounce_offset(time: float, phase: float, state: StringName) -> float:
	if state not in [STATE_ADVANCE, STATE_RECOVER, STATE_DISPERSING]:
		return 0.0
	return absf(sin(time * BOUNCE_RATE + phase)) * BOUNCE_HEIGHT


func _set_active_biome(biome: StringName) -> void:
	_active_biome = biome if BIOME_KINDS.has(biome) else &"desert"
	_active_kind = _kind_for_biome(_active_biome)


func _get_active_kind() -> StringName:
	return _active_kind


func set_player_position(position: Vector2) -> void:
	_player_position = position


func set_sanctuary_active(active: bool) -> void:
	if active and not _sanctuary_active:
		disperse_all()
	_sanctuary_active = active


func spawn_pack(center: Vector2, count: int) -> int:
	if _world == null or _sanctuary_active or count <= 0:
		return 0
	var added: int = 0
	var bounded: int = mini(count, MAX_MITES - _mites.size())
	for member: int in range(bounded):
		var angle: float = TAU * float(member) / float(maxi(bounded, 1))
		var origin: Vector2 = center + Vector2.from_angle(angle) * SPAWN_RADIUS
		var position: Vector2 = _find_walkable(origin)
		if position == MISSING_POSITION:
			continue
		var mite_id: int = _next_id
		_next_id += 1
		(
			_mites
			. append(
				{
					&"id": mite_id,
					&"kind": _active_kind,
					&"position": position,
					&"direction": (center - position).normalized(),
					&"state": STATE_EMERGE,
					&"state_remaining": EMERGE_SECONDS,
					&"state_duration": EMERGE_SECONDS,
					&"phase": angle,
					&"committed_target": center,
					&"attack_serial": 0,
					&"attack_cooldown": 0.25 + float(member) * 0.11,
				}
			)
		)
		added += 1
	_total_spawned += added
	queue_redraw()
	return added


func advance(delta: float) -> void:
	var step: float = minf(maxf(delta, 0.0), 0.1)
	if step <= 0.0:
		return
	_time += step
	_shared_damage_remaining = maxf(_shared_damage_remaining - step, 0.0)
	for index: int in range(_mites.size() - 1, -1, -1):
		var mite: Dictionary = _mites[index]
		mite[&"attack_cooldown"] = maxf(float(mite[&"attack_cooldown"]) - step, 0.0)
		_advance_mite(mite, step)
		if mite[&"state"] == STATE_DISPERSING and float(mite[&"state_remaining"]) <= 0.0:
			_mites.remove_at(index)
	queue_redraw()


func disperse_all() -> void:
	for mite: Dictionary in _mites:
		_set_state(mite, STATE_DISPERSING, DISPERSE_SECONDS)
	queue_redraw()


func clear() -> void:
	_mites.clear()
	_hovered_id = -1
	queue_redraw()


func get_count() -> int:
	return _mites.size()


func get_last_attack_count() -> int:
	return _last_attack_count


func get_total_spawned() -> int:
	return _total_spawned


func get_health(mite_id: int) -> int:
	return 1 if not _find_mite(mite_id).is_empty() else 0


func get_mite_position(mite_id: int) -> Vector2:
	return _find_mite(mite_id).get(&"position", MISSING_POSITION) as Vector2


func get_mite_kind(mite_id: int) -> StringName:
	return _find_mite(mite_id).get(&"kind", GLASSBACK_SCARAB_KIND) as StringName


func get_state(mite_id: int) -> StringName:
	return _find_mite(mite_id).get(&"state", &"missing") as StringName


func find_target(target_cell: Vector2i) -> int:
	var target: Vector2 = Vector2(target_cell)
	var best_id: int = -1
	var best_distance: float = 0.86
	for mite: Dictionary in _mites:
		if mite[&"state"] in [STATE_EMERGE, STATE_DISPERSING]:
			continue
		var distance: float = (mite[&"position"] as Vector2).distance_to(target)
		if distance <= best_distance:
			best_distance = distance
			best_id = int(mite[&"id"])
	return best_id


func hit_mite(mite_id: int, damage: int = 1) -> bool:
	if damage <= 0:
		return false
	for index: int in range(_mites.size()):
		if (
			int(_mites[index][&"id"]) != mite_id
			or _mites[index][&"state"] in [STATE_EMERGE, STATE_DISPERSING]
		):
			continue
		_mites.remove_at(index)
		if _hovered_id == mite_id:
			_hovered_id = -1
		queue_redraw()
		return true
	return false


func set_hovered(mite_id: int) -> void:
	if mite_id == _hovered_id:
		return
	_hovered_id = mite_id
	queue_redraw()


func get_combat_snapshot(mite_id: int) -> Dictionary:
	var mite: Dictionary = _find_mite(mite_id)
	if mite.is_empty():
		return {}
	return {
		&"id": int(mite[&"id"]),
		&"kind": mite.get(&"kind", GLASSBACK_SCARAB_KIND),
		&"state": mite[&"state"],
		&"position": mite[&"position"],
		&"direction": mite[&"direction"],
		&"health": MAX_HEALTH,
		&"state_remaining": float(mite[&"state_remaining"]),
		&"state_duration": float(mite[&"state_duration"]),
		&"committed_target": mite[&"committed_target"],
		&"attack_origin": mite[&"position"],
		&"attack_serial": int(mite[&"attack_serial"]),
		&"attack_pattern": &"melee_pounce",
	}


func get_combat_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for mite: Dictionary in _mites:
		snapshots.append(get_combat_snapshot(int(mite[&"id"])))
	return snapshots


func get_hover_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for mite: Dictionary in _mites:
		if mite[&"state"] in [STATE_EMERGE, STATE_DISPERSING]:
			continue
		var kind: StringName = mite.get(&"kind", GLASSBACK_SCARAB_KIND) as StringName
		(
			targets
			. append(
				{
					&"id": int(mite[&"id"]),
					&"kind": kind,
					&"name_key": _name_key(kind),
					&"state": mite[&"state"],
					&"screen_position":
					_grid_to_screen(mite[&"position"] as Vector2) + Vector2(0.0, -18.0),
					&"hover_radius": 34.0,
					&"health": MAX_HEALTH,
					&"max_health": MAX_HEALTH,
					&"attack_damage": _profile_int(kind, &"attack_damage", ATTACK_DAMAGE),
					&"attack_range": ATTACK_RANGE,
				}
			)
		)
	return targets


func _advance_mite(mite: Dictionary, delta: float) -> void:
	var state: StringName = mite[&"state"] as StringName
	var kind: StringName = mite.get(&"kind", GLASSBACK_SCARAB_KIND) as StringName
	if state == STATE_EMERGE:
		mite[&"state_remaining"] = float(mite[&"state_remaining"]) - delta
		if float(mite[&"state_remaining"]) <= 0.0:
			_set_state(mite, STATE_ADVANCE, 0.0)
		return
	if state == STATE_ADVANCE:
		_advance_encirclement(mite, delta)
		if (
			(mite[&"position"] as Vector2).distance_to(_player_position) <= ATTACK_RANGE
			and float(mite[&"attack_cooldown"]) <= 0.0
		):
			mite[&"committed_target"] = _player_position
			mite[&"attack_serial"] = int(mite[&"attack_serial"]) + 1
			_set_state(
				mite,
				STATE_WARNING,
				_profile_float(kind, &"warning_seconds", WARNING_SECONDS),
			)
		return
	if state == STATE_WARNING:
		mite[&"state_remaining"] = float(mite[&"state_remaining"]) - delta
		if float(mite[&"state_remaining"]) <= 0.0:
			_resolve_attack(mite)
			_set_state(
				mite,
				STATE_RECOVER,
				_profile_float(kind, &"recover_seconds", RECOVER_SECONDS),
			)
		return
	if state == STATE_RECOVER:
		mite[&"state_remaining"] = float(mite[&"state_remaining"]) - delta
		_advance_recovery(mite, delta)
		if float(mite[&"state_remaining"]) <= 0.0:
			mite[&"attack_cooldown"] = PERSONAL_ATTACK_COOLDOWN
			_set_state(mite, STATE_ADVANCE, 0.0)
		return
	if state == STATE_DISPERSING:
		mite[&"state_remaining"] = float(mite[&"state_remaining"]) - delta
		var away: Vector2 = (mite[&"position"] as Vector2) - _player_position
		away = Vector2.RIGHT if away.is_zero_approx() else away.normalized()
		mite[&"direction"] = away
		mite[&"position"] = (
			(mite[&"position"] as Vector2)
			+ away * _profile_float(kind, &"move_speed", MOVE_SPEED) * 2.0 * delta
		)


func _advance_encirclement(mite: Dictionary, delta: float) -> void:
	var position: Vector2 = mite[&"position"] as Vector2
	var kind: StringName = mite.get(&"kind", GLASSBACK_SCARAB_KIND) as StringName
	var phase: float = float(mite[&"phase"]) + _time * 0.34
	var orbit_radius: float = _profile_float(kind, &"orbit_radius", ORBIT_RADIUS)
	var slot: Vector2 = _player_position + Vector2.from_angle(phase) * orbit_radius
	var to_slot: Vector2 = slot - position
	var to_player: Vector2 = _player_position - position
	var steering: Vector2 = to_slot.normalized() + _separation_for(mite) * 0.82
	if to_player.length() > 2.4:
		steering = to_player.normalized() * 1.35 + _separation_for(mite) * 0.45
	if steering.is_zero_approx():
		return
	var direction: Vector2 = steering.normalized()
	var move_speed: float = _profile_float(kind, &"move_speed", MOVE_SPEED)
	var candidate: Vector2 = position + direction * move_speed * delta
	if _position_is_valid(candidate):
		mite[&"position"] = candidate
		mite[&"direction"] = direction


func _advance_recovery(mite: Dictionary, delta: float) -> void:
	var position: Vector2 = mite[&"position"] as Vector2
	var kind: StringName = mite.get(&"kind", GLASSBACK_SCARAB_KIND) as StringName
	var away: Vector2 = position - _player_position
	if away.length() >= 1.2:
		return
	away = Vector2.RIGHT if away.is_zero_approx() else away.normalized()
	var move_speed: float = _profile_float(kind, &"move_speed", MOVE_SPEED)
	var candidate: Vector2 = position + away * move_speed * 0.58 * delta
	if _position_is_valid(candidate):
		mite[&"position"] = candidate
		mite[&"direction"] = away


func _resolve_attack(mite: Dictionary) -> void:
	if (
		_sanctuary_active
		or _shared_damage_remaining > 0.0
		or (mite[&"position"] as Vector2).distance_to(_player_position) > ATTACK_RANGE
	):
		return
	_shared_damage_remaining = SHARED_DAMAGE_COOLDOWN
	_last_attack_count += 1
	var kind: StringName = mite.get(&"kind", GLASSBACK_SCARAB_KIND) as StringName
	damage_tick.emit(_profile_int(kind, &"attack_damage", ATTACK_DAMAGE), kind)


func _profile_float(kind: StringName, property: StringName, fallback: float) -> float:
	var profile: Dictionary = MOB_PROFILES.get(kind, MOB_PROFILES[GLASSBACK_SCARAB_KIND])
	return float(profile.get(property, fallback))


func _profile_int(kind: StringName, property: StringName, fallback: int) -> int:
	var profile: Dictionary = MOB_PROFILES.get(kind, MOB_PROFILES[GLASSBACK_SCARAB_KIND])
	return int(profile.get(property, fallback))


func _set_state(mite: Dictionary, state: StringName, duration: float) -> void:
	mite[&"state"] = state
	mite[&"state_remaining"] = maxf(duration, 0.0)
	mite[&"state_duration"] = maxf(duration, 0.0)


func _separation_for(mite: Dictionary) -> Vector2:
	var position: Vector2 = mite[&"position"] as Vector2
	var total: Vector2 = Vector2.ZERO
	for neighbor: Dictionary in _mites:
		if int(neighbor[&"id"]) == int(mite[&"id"]):
			continue
		var away: Vector2 = position - (neighbor[&"position"] as Vector2)
		var distance: float = away.length()
		if distance <= 0.001 or distance >= SEPARATION_RADIUS:
			continue
		total += away.normalized() * (1.0 - distance / SEPARATION_RADIUS)
	return total.limit_length(1.0)


func _find_walkable(origin: Vector2) -> Vector2:
	for radius: int in range(5):
		for index: int in range(maxi(radius * 8, 1)):
			var angle: float = TAU * float(index) / float(maxi(radius * 8, 1))
			var candidate: Vector2 = origin + Vector2.from_angle(angle) * float(radius)
			if _position_is_valid(candidate):
				return candidate
	return MISSING_POSITION


func _position_is_valid(position: Vector2) -> bool:
	return (
		bool(_world.call("is_walkable", Vector2i(position.round())))
		and (
			not _world.has_method("_is_in_sanctuary")
			or not bool(_world.call("_is_in_sanctuary", position))
		)
	)


func _find_mite(mite_id: int) -> Dictionary:
	for mite: Dictionary in _mites:
		if int(mite[&"id"]) == mite_id:
			return mite
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
	for mite: Dictionary in _mites:
		_draw_mite(mite)


func _draw_mite(mite: Dictionary) -> void:
	var center: Vector2 = _grid_to_screen(mite[&"position"] as Vector2)
	var direction: Vector2 = mite[&"direction"] as Vector2
	var screen_direction: Vector2 = (
		(_grid_to_screen(direction) - _grid_to_screen(Vector2.ZERO)).normalized()
	)
	var state: StringName = mite[&"state"] as StringName
	var emergence: float = (
		_emergence_progress(float(mite[&"state_remaining"])) if state == STATE_EMERGE else 1.0
	)
	var alpha: float = emergence
	if state == STATE_DISPERSING:
		alpha = clampf(float(mite[&"state_remaining"]) / DISPERSE_SECONDS, 0.0, 1.0)
	center.y += (1.0 - emergence) * EMERGE_DEPTH
	center.y -= _bounce_offset(_time, float(mite[&"phase"]), state)
	var kind: StringName = mite.get(&"kind", GLASSBACK_SCARAB_KIND) as StringName
	var texture: Texture2D = _texture_for(kind)
	var tint: Color = Color("ffd27a") if int(mite[&"id"]) == _hovered_id else Color.WHITE
	tint.a = alpha
	var scale_x: float = -1.0 if screen_direction.x < -0.05 else 1.0
	var scale_y: float = lerpf(0.62, 1.0, emergence)
	draw_set_transform(center, 0.0, Vector2(scale_x, scale_y))
	draw_texture_rect(
		texture,
		Rect2(-MOB_DRAW_SIZE * Vector2(0.5, 0.68), MOB_DRAW_SIZE),
		false,
		tint,
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
