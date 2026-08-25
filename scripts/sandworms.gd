extends Node2D

signal damage_tick(amount: int, source: StringName)
signal defeated(worm_id: int, position: Vector2)
signal telegraph_started(kind: StringName, worm_id: int, attack_serial: int)
signal peaceful_defeated(creature_id: int, position: Vector2, cores: int, scrap: int)
const FaunaCombatScript: GDScript = preload("res://scripts/fauna_combat_catalog.gd")
const FaunaTelegraphAudioScript: GDScript = preload("res://scripts/fauna_telegraph_audio.gd")
const FaunaVisualsScript: GDScript = preload("res://scripts/fauna_visuals.gd")
const IronjawBossScript: GDScript = preload("res://scripts/ironjaw_boss.gd")
const KilnheartBossScript: GDScript = preload("res://scripts/kilnheart_boss.gd")
const MeleePressureScript: GDScript = preload("res://scripts/melee_pressure.gd")
const PeacefulHerdsScript: GDScript = preload("res://scripts/peaceful_herds.gd")
const SandwormVisualsScript: GDScript = preload("res://scripts/sandworm_visuals.gd")
const WorldSafetyScript: GDScript = preload("res://scripts/world_safety.gd")
const DEFAULT_PROFILE: Resource = preload("res://data/combat/sandworm_default.tres")
const MAX_HEALTH: int = 4
const ATTACK_DAMAGE: int = 10
const DETECTION_RANGE: float = 8.0
const ATTACK_RANGE: float = 0.72
const MOVE_SPEED: float = 1.28
const ATTACK_COOLDOWN: float = 1.15
const EMERGE_SECONDS: float = 0.8
const DISPERSE_SECONDS: float = 1.25
const MAX_WORMS: int = 4

const STATE_BURROW: StringName = &"burrow"
const STATE_INTERCEPT: StringName = &"intercept"
const STATE_EXPOSE: StringName = &"expose"
const STATE_DIVE: StringName = &"dive"
const STATE_SKIM: StringName = &"skim"
const STATE_WAKE_WARNING: StringName = &"wake_warning"
const STATE_WAKE_SWEEP: StringName = &"wake_sweep"
const STATE_STALK: StringName = &"stalk"
const STATE_POUNCE_WARNING: StringName = &"pounce_warning"
const STATE_POUNCE: StringName = &"pounce"
const STATE_BRACE: StringName = &"brace"
const STATE_SALVO_WARNING: StringName = &"salvo_warning"
const STATE_EMBER_SALVO: StringName = &"ember_salvo"
const STATE_RECOVER: StringName = &"recover"
const STATE_STAGGERED: StringName = &"staggered"
const STATE_DISPERSING: StringName = &"dispersing"
const STATE_DEFEATED: StringName = &"defeated"
const MISSING_POSITION: Vector2 = Vector2(-9999.0, -9999.0)
const SAND: Color = Color("d69a49")
const SKIMMER_KIND: StringName = &"mud_skimmer"
const RIME_KIND: StringName = &"rime_stalker"
const CINDER_KIND: StringName = &"cinder_crawler"
const WORM_KIND: StringName = &"sandworm"
const BOSS_KIND: StringName = &"ironjaw_apex"
const KILNHEART_KIND: StringName = &"kilnheart_colossus"

var _tile_size: Vector2 = Vector2(90.0, 45.0)
var _map_origin: Vector2 = Vector2(760.0, 70.0)
var _player_position: Vector2 = Vector2.ZERO
var _player_velocity: Vector2 = Vector2.ZERO
var _worms: Array[Dictionary] = []
var _next_id: int = 1
var _time: float = 0.0
var _spawn_timer: float = 7.0
var _auto_spawn: bool = true
var _outpost_linked: bool = false
var _last_attack_count: int = 0
var _profile: Resource = DEFAULT_PROFILE
var _world: RefCounted
var _active_biome: StringName = &"desert"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hovered_enemy_id: int = -1
var _telegraph_audio: Node
var _melee_pressure: Node2D
var _peaceful_herds: Node2D
var _defeated_peaceful_kinds: Dictionary = {}
var _boss_defeated: bool = false
var _kilnheart_defeated: bool = false

func _ready() -> void:
	_rng.seed = 0x5A6D701
	_telegraph_audio = FaunaTelegraphAudioScript.new() as Node
	_telegraph_audio.name = "FaunaTelegraphAudio"
	add_child(_telegraph_audio)
	telegraph_started.connect(_on_telegraph_started)

func _on_telegraph_started(kind: StringName, enemy_id: int, attack_serial: int) -> void:
	var worm: Dictionary = _find_worm(enemy_id)
	var position: Vector2 = (
		_grid_to_screen(worm[&"position"] as Vector2) if not worm.is_empty() else Vector2.ZERO
	)
	var pattern: StringName = worm.get(&"attack_pattern", &"") as StringName
	_telegraph_audio.call("play_warning", kind, enemy_id, attack_serial, position, pattern)

func configure(
	tile_size: Vector2,
	map_origin: Vector2,
	profile: Resource = DEFAULT_PROFILE,
	world: RefCounted = null,
) -> bool:
	if profile == null:
		profile = DEFAULT_PROFILE
	if profile == null or not profile.has_method("validate") or not bool(profile.call("validate")):
		return false
	_tile_size = tile_size
	_map_origin = map_origin
	_profile = profile
	_world = world
	if _world != null and _melee_pressure == null:
		_melee_pressure = MeleePressureScript.new() as Node2D
		_melee_pressure.name = "MeleePressure"
		_melee_pressure.call(
			"configure", _tile_size, _map_origin, _world, _telegraph_audio
		)
		_melee_pressure.connect("damage_tick", damage_tick.emit)
		add_child(_melee_pressure)
	if _world != null and _peaceful_herds == null:
		_peaceful_herds = PeacefulHerdsScript.new() as Node2D
		_peaceful_herds.name = "PeacefulHerds"
		_peaceful_herds.z_index = -1
		_peaceful_herds.call("configure", _tile_size, _map_origin, _world)
		_peaceful_herds.connect("defeated", Callable(self, "_on_peaceful_defeated"))
		add_child(_peaceful_herds)
	return true

func set_auto_spawn(enabled: bool) -> void:
	_auto_spawn = enabled

func _set_active_biome(biome: StringName) -> void:
	if biome != _active_biome:
		clear_worms()
		_active_biome = biome
		if _melee_pressure != null:
			_melee_pressure.call("_set_active_biome", biome)
		if _peaceful_herds != null:
			_peaceful_herds.call("set_active_biome", biome)

func set_player_position(position: Vector2, velocity: Vector2 = Vector2.ZERO) -> void:
	_sync_biome(position)
	_player_position = position
	_player_velocity = velocity
	if _melee_pressure != null:
		_melee_pressure.call("set_player_position", position)
	if _peaceful_herds != null:
		_peaceful_herds.call("set_player_position", position)

func set_outpost_linked(linked: bool) -> void:
	if _world != null:
		linked = bool(_world.call("_is_in_sanctuary", _player_position))
	if linked and not _outpost_linked:
		disperse_all()
	_outpost_linked = linked
	if _melee_pressure != null:
		_melee_pressure.call("set_sanctuary_active", linked)

func disperse_all() -> void:
	for worm: Dictionary in _worms:
		_set_state(worm, STATE_DISPERSING, _p_float(&"disperse_seconds"))
	if _melee_pressure != null:
		_melee_pressure.call("disperse_all")
	queue_redraw()

func advance(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	if step <= 0.0:
		return
	_time += step
	if _auto_spawn and not _outpost_linked:
		_advance_spawner(step)
	for index: int in range(_worms.size() - 1, -1, -1):
		var worm: Dictionary = _worms[index]
		worm[&"age"] = float(worm[&"age"]) + step
		worm[&"hit_flash"] = maxf(float(worm[&"hit_flash"]) - step, 0.0)
		worm[&"feedback_time"] = maxf(float(worm[&"feedback_time"]) - step, 0.0)
		_advance_worm(worm, step)
		if _state_expired(worm) and worm[&"state"] in [STATE_DISPERSING, STATE_DEFEATED]:
			_worms.remove_at(index)
	if _peaceful_herds != null:
		_peaceful_herds.call("advance", step)
	if _melee_pressure != null:
		_melee_pressure.call("advance", step)
	queue_redraw()

func spawn_worm(position: Vector2, emerge_seconds: float = -1.0) -> int:
	if (
		_worms.size() >= _p_int(&"max_worms")
		or not WorldSafetyScript.allows_spawn(position, _world)
	):
		return -1
	var worm_id: int = _next_id
	_next_id += 1
	var kind: StringName = WORM_KIND
	if _active_biome == &"oasis":
		kind = SKIMMER_KIND
	elif _active_biome == &"frozen":
		kind = RIME_KIND
	elif _active_biome == &"lava":
		kind = CINDER_KIND
	var default_emerge: float = FaunaCombatScript.emerge_seconds(
		kind, _p_float(&"spawn_burrow_seconds")
	)
	var spawn_seconds: float = default_emerge if emerge_seconds < 0.0 else emerge_seconds
	var worm: Dictionary = FaunaCombatScript.make_entity(
		worm_id, kind, position, _p_int(&"max_health"), maxf(spawn_seconds, 0.0)
	)
	worm[&"resume_state"] = worm[&"state"]
	worm[&"resume_remaining"] = 0.0
	_worms.append(worm)
	queue_redraw()
	return worm_id

func _spawn_boss(position: Vector2, emerge_seconds: float = 1.0) -> int:
	if _boss_defeated or not WorldSafetyScript.allows_spawn(position, _world):
		return -1
	var living_id: int = _get_boss_id()
	if living_id >= 0:
		return living_id
	var worm_id: int = _next_id
	_next_id += 1
	_worms.append(IronjawBossScript.make_entity(worm_id, position, maxf(emerge_seconds, 0.0)))
	queue_redraw()
	return worm_id

func _spawn_kilnheart(position: Vector2, emerge_seconds: float = 0.9) -> int:
	if _kilnheart_defeated or not WorldSafetyScript.allows_spawn(position, _world):
		return -1
	var living_id: int = _get_kilnheart_id()
	if living_id >= 0:
		return living_id
	var enemy_id: int = _next_id
	_next_id += 1
	_worms.append(KilnheartBossScript.make_entity(enemy_id, position, emerge_seconds))
	queue_redraw()
	return enemy_id

func _get_kilnheart_id() -> int:
	for worm: Dictionary in _worms:
		if worm.get(&"kind", WORM_KIND) == KILNHEART_KIND:
			return int(worm[&"id"])
	return -1

func _is_kilnheart_defeated() -> bool:
	return _kilnheart_defeated

func _get_boss_id() -> int:
	for worm: Dictionary in _worms:
		if worm.get(&"kind", WORM_KIND) == BOSS_KIND:
			return int(worm[&"id"])
	return -1

func _is_boss_defeated() -> bool:
	return _boss_defeated

func clear_worms() -> void:
	_worms.clear()
	if _melee_pressure != null:
		_melee_pressure.call("clear")
	_hovered_enemy_id = -1
	queue_redraw()

func get_worm_count() -> int:
	return _worms.size()

func _spawn_melee_pack(center: Vector2, count: int) -> int:
	return int(_melee_pressure.call("spawn_pack", center, count)) if _melee_pressure != null else 0

func _get_melee_count() -> int:
	return int(_melee_pressure.call("get_count")) if _melee_pressure != null else 0


func _get_melee_pressure() -> Node2D:
	return _melee_pressure


func _get_peaceful_count() -> int:
	return int(_peaceful_herds.call("get_creature_count")) if _peaceful_herds != null else 0


func _get_peaceful_herds() -> Node2D:
	return _peaceful_herds


func get_health(worm_id: int) -> int:
	if worm_id >= MeleePressureScript.ID_BASE:
		return int(_melee_pressure.call("get_health", worm_id))
	if worm_id >= PeacefulHerdsScript.CREATURE_ID_BASE:
		return (
			1
			if (
				_peaceful_herds != null
				and not (_peaceful_herds.call("get_snapshot", worm_id) as Dictionary).is_empty()
			)
			else 0
		)
	var worm: Dictionary = _find_worm(worm_id)
	return int(worm.get(&"health", 0))


func get_worm_position(worm_id: int) -> Vector2:
	if worm_id >= MeleePressureScript.ID_BASE:
		return _melee_pressure.call("get_mite_position", worm_id) as Vector2
	var worm: Dictionary = _find_worm(worm_id)
	return worm.get(&"position", MISSING_POSITION) as Vector2


func _get_enemy_kind(worm_id: int) -> StringName:
	if worm_id >= MeleePressureScript.ID_BASE:
		return _melee_pressure.call("get_mite_kind", worm_id) as StringName
	if worm_id >= PeacefulHerdsScript.CREATURE_ID_BASE:
		var snapshot: Dictionary = _peaceful_herds.call("get_snapshot", worm_id) as Dictionary
		return (
			snapshot.get(&"kind", _defeated_peaceful_kinds.get(worm_id, &"dune_grazer"))
			as StringName
		)
	var worm: Dictionary = _find_worm(worm_id)
	return worm.get(&"kind", WORM_KIND) as StringName


func _get_enemy_label(worm_id: int) -> StringName:
	var kind: StringName = _get_enemy_kind(worm_id)
	var label: StringName = &"enemy.sandworm.name"
	if worm_id >= MeleePressureScript.ID_BASE:
		label = MeleePressureScript._name_key(kind)
	elif worm_id >= PeacefulHerdsScript.CREATURE_ID_BASE:
		label = PeacefulHerdsScript.name_key(kind)
	elif kind == SKIMMER_KIND:
		label = &"enemy.mud_skimmer.name"
	elif kind == RIME_KIND:
		label = &"enemy.rime_stalker.name"
	elif kind == CINDER_KIND:
		label = &"enemy.cinder_crawler.name"
	elif kind == BOSS_KIND:
		label = &"enemy.ironjaw_apex.name"
	elif kind == KILNHEART_KIND:
		label = &"enemy.kilnheart_colossus.name"
	return label


func _get_active_biome() -> StringName:
	return _active_biome


func get_state(worm_id: int) -> StringName:
	if worm_id >= MeleePressureScript.ID_BASE:
		return _melee_pressure.call("get_state", worm_id) as StringName
	var worm: Dictionary = _find_worm(worm_id)
	return worm.get(&"state", &"missing") as StringName


func get_last_attack_count() -> int:
	return _last_attack_count


func _set_hovered_enemy(worm_id: int) -> void:
	if worm_id == _hovered_enemy_id:
		return
	_hovered_enemy_id = worm_id
	if _melee_pressure != null:
		_melee_pressure.call("set_hovered", worm_id)
	queue_redraw()


func _get_hovered_enemy() -> int:
	return _hovered_enemy_id


func _get_character_hover_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for worm: Dictionary in _worms:
		var state: StringName = worm[&"state"] as StringName
		if state in [STATE_DISPERSING, STATE_DEFEATED]:
			continue
		var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
		var center: Vector2 = _grid_to_screen(worm[&"position"] as Vector2)
		(
			targets
			. append(
				{
					&"id": int(worm[&"id"]),
					&"kind": kind,
					&"name_key": _get_enemy_label(int(worm[&"id"])),
					&"state": state,
					&"screen_position": center + Vector2(0.0, -24.0),
					&"hover_radius": 56.0,
					&"health": int(worm[&"health"]),
					&"max_health": int(worm.get(&"max_health", _p_int(&"max_health"))),
					&"attack_damage": (
						KilnheartBossScript.current_damage(worm)
						if kind == KILNHEART_KIND
						else FaunaCombatScript.damage(kind, _profile)
					),
					&"attack_range": (
						KilnheartBossScript.current_range(worm)
						if kind == KILNHEART_KIND
						else FaunaCombatScript.attack_range(kind, _profile)
					),
				}
			)
		)
	if _melee_pressure != null:
		targets.append_array(_melee_pressure.call("get_hover_targets"))
	return targets


func _on_peaceful_defeated(id: int, position: Vector2, cores: int, scrap: int) -> void:
	peaceful_defeated.emit(id, position, cores, scrap)


func get_combat_snapshot(worm_id: int) -> Dictionary:
	if worm_id >= MeleePressureScript.ID_BASE:
		return _melee_pressure.call("get_combat_snapshot", worm_id) as Dictionary
	var worm: Dictionary = _find_worm(worm_id)
	if worm.is_empty():
		return {}
	return {
		&"id": int(worm[&"id"]),
		&"kind": worm.get(&"kind", WORM_KIND),
		&"state": worm[&"state"],
		&"position": worm[&"position"],
		&"direction": worm[&"direction"],
		&"health": int(worm[&"health"]),
		&"max_health": int(worm.get(&"max_health", _p_int(&"max_health"))),
		&"armor_stage": int(worm.get(&"armor_stage", 0)),
		&"is_boss": bool(worm.get(&"is_boss", false)),
		&"state_elapsed": float(worm[&"state_elapsed"]),
		&"state_remaining": float(worm[&"state_remaining"]),
		&"state_duration": float(worm[&"state_duration"]),
		&"attack_origin": worm[&"intercept_start"],
		&"committed_target": worm[&"committed_target"],
		&"attack_serial": int(worm[&"attack_serial"]),
		&"resolved_attack_serial": int(worm[&"resolved_attack_serial"]),
		&"attack_pattern": worm[&"attack_pattern"],
		&"strike_targets": (worm[&"strike_targets"] as Array).duplicate(),
		&"strike_pulses": int(worm[&"strike_pulses"]),
		&"resolved_pulses": int(worm[&"resolved_pulses"]),
	}


func get_combat_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for worm: Dictionary in _worms:
		snapshots.append(get_combat_snapshot(int(worm[&"id"])))
	if _melee_pressure != null:
		snapshots.append_array(_melee_pressure.call("get_combat_snapshots"))
	return snapshots


func find_target(target_cell: Vector2i) -> int:
	var target: Vector2 = Vector2(target_cell)
	var best_id: int = -1
	var best_distance: float = 0.86
	for worm: Dictionary in _worms:
		if worm[&"state"] in [STATE_DISPERSING, STATE_DEFEATED]:
			continue
		var distance: float = (worm[&"position"] as Vector2).distance_to(target)
		if distance <= best_distance:
			best_distance = distance
			best_id = int(worm[&"id"])
	if best_id >= 0:
		return best_id
	if _melee_pressure != null:
		best_id = int(_melee_pressure.call("find_target", target_cell))
		if best_id >= 0:
			return best_id
	if _peaceful_herds == null:
		return -1
	return int(_peaceful_herds.call("find_target", target_cell))


func hit_worm(worm_id: int, damage: int = 1) -> bool:
	if worm_id >= MeleePressureScript.ID_BASE:
		return bool(_melee_pressure.call("hit_mite", worm_id, damage))
	if worm_id >= PeacefulHerdsScript.CREATURE_ID_BASE:
		var snapshot: Dictionary = _peaceful_herds.call("get_snapshot", worm_id) as Dictionary
		var accepted: bool = bool(_peaceful_herds.call("hit_creature", worm_id, damage))
		if accepted:
			_defeated_peaceful_kinds[worm_id] = snapshot.get(&"kind", &"dune_grazer")
		return accepted
	var worm: Dictionary = _find_worm(worm_id)
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	var state: StringName = worm.get(&"state", &"missing") as StringName
	var vulnerable: bool = FaunaCombatScript.vulnerable(kind, state)
	if kind == BOSS_KIND:
		vulnerable = state == STATE_EXPOSE
	elif kind == KILNHEART_KIND:
		vulnerable = KilnheartBossScript.vulnerable(state)
	if worm.is_empty() or not vulnerable or damage <= 0:
		return false
	var boss_damage: Dictionary = {}
	if kind == BOSS_KIND:
		boss_damage = IronjawBossScript.apply_damage(worm, damage)
	elif kind == KILNHEART_KIND:
		boss_damage = KilnheartBossScript.apply_damage(worm, damage)
	else:
		worm[&"health"] = maxi(int(worm[&"health"]) - damage, 0)
	worm[&"hit_flash"] = 0.18
	if int(worm[&"health"]) <= 0:
		_boss_defeated = _boss_defeated or kind == BOSS_KIND
		_kilnheart_defeated = _kilnheart_defeated or kind == KILNHEART_KIND
		if not bool(worm[&"reward_emitted"]):
			worm[&"reward_emitted"] = true
			defeated.emit(int(worm[&"id"]), worm[&"position"] as Vector2)
		var defeated_seconds: float = (
			1.2 if kind == KILNHEART_KIND else _entity_state_duration(worm, STATE_DEFEATED)
		)
		_set_state(worm, STATE_DEFEATED, defeated_seconds)
	elif kind == KILNHEART_KIND and bool(boss_damage.get(&"phase_changed", false)):
		KilnheartBossScript.stagger(worm, 0.65)
	elif bool(boss_damage.get(&"armor_broke", false)):
		worm[&"resolved_attack_serial"] = int(worm[&"attack_serial"])
		worm[&"resolved_pulses"] = int(worm[&"strike_pulses"])
		worm[&"resume_state"] = STATE_BURROW
		worm[&"resume_remaining"] = _entity_state_duration(worm, STATE_BURROW)
		_set_state(
			worm,
			STATE_STAGGERED,
			IronjawBossScript.break_stagger_seconds(int(worm[&"armor_stage"])),
		)
	queue_redraw()
	return true


func present_hit_feedback(
	worm_id: int, direction: Vector2, strength: int, hold_seconds: float
) -> bool:
	var worm: Dictionary = _find_worm(worm_id)
	if worm.is_empty():
		return false
	worm[&"feedback_direction"] = (
		Vector2.RIGHT if direction.is_zero_approx() else direction.normalized()
	)
	worm[&"feedback_duration"] = maxf(0.1, hold_seconds + 0.08)
	worm[&"feedback_time"] = float(worm[&"feedback_duration"])
	worm[&"feedback_strength"] = clampi(strength, 0, 2)
	queue_redraw()
	return true


func get_feedback_offset(worm_id: int) -> Vector2:
	return FaunaVisualsScript.feedback_offset(_tile_size, _find_worm(worm_id))


func stagger_worm(worm_id: int, seconds: float = -1.0) -> bool:
	var worm: Dictionary = _find_worm(worm_id)
	if worm.is_empty() or worm[&"state"] in [STATE_DISPERSING, STATE_DEFEATED]:
		return false
	var requested: float = _p_float(&"stagger_seconds") if seconds < 0.0 else maxf(seconds, 0.0)
	if worm.get(&"kind", WORM_KIND) == KILNHEART_KIND:
		var accepted: bool = KilnheartBossScript.stagger(worm, requested)
		worm[&"hit_flash"] = 0.28 if accepted else float(worm[&"hit_flash"])
		queue_redraw()
		return accepted
	var maximum: float = (
		IronjawBossScript.max_stagger_seconds(int(worm.get(&"armor_stage", 0)))
		if worm.get(&"kind", WORM_KIND) == BOSS_KIND
		else _p_float(&"maximum_stagger_seconds")
	)
	var bounded: float = minf(requested, maximum)
	if worm[&"state"] == STATE_STAGGERED:
		worm[&"state_remaining"] = minf(maxf(float(worm[&"state_remaining"]), bounded), maximum)
		worm[&"state_duration"] = maxf(
			float(worm[&"state_duration"]), float(worm[&"state_remaining"])
		)
	else:
		worm[&"resume_state"] = worm[&"state"]
		worm[&"resume_remaining"] = float(worm[&"state_remaining"])
		_set_state(worm, STATE_STAGGERED, bounded)
	worm[&"hit_flash"] = 0.28
	queue_redraw()
	return true


func _advance_spawner(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0 or _worms.size() >= _p_int(&"max_worms"):
		return
	var angle: float = _rng.randf_range(0.0, TAU)
	var radius: float = _rng.randf_range(5.5, 8.5)
	spawn_worm(_player_position + Vector2(cos(angle), sin(angle)) * radius)
	_spawn_timer = _rng.randf_range(10.0, 16.0)


func _advance_worm(worm: Dictionary, delta: float) -> void:
	if (
		not WorldSafetyScript.allows_pursuit(_player_position, _world)
		and worm[&"state"] not in [STATE_DISPERSING, STATE_DEFEATED]
	):
		_set_state(worm, STATE_DISPERSING, _p_float(&"disperse_seconds"))
	if worm.get(&"kind", WORM_KIND) == KILNHEART_KIND:
		var result: Dictionary = KilnheartBossScript.advance(
			worm, delta, _player_position, _player_velocity, _outpost_linked
		)
		if bool(result[&"telegraph"]):
			telegraph_started.emit(KILNHEART_KIND, int(worm[&"id"]), int(worm[&"attack_serial"]))
		if (
			_telegraph_audio != null
			and bool(result[&"movement"])
			and float(worm[&"move_audio_remaining"]) <= 0.0
		):
			worm[&"move_audio_serial"] = int(worm[&"move_audio_serial"]) + 1
			_telegraph_audio.call(
				"play_movement", KILNHEART_KIND, int(worm[&"id"]),
				int(worm[&"move_audio_serial"]), _grid_to_screen(worm[&"position"] as Vector2)
			)
			worm[&"move_audio_remaining"] = 0.62
		for event: Dictionary in result[&"damage_events"] as Array:
			if not WorldSafetyScript.allows_damage(_player_position, _world):
				continue
			_last_attack_count += 1
			damage_tick.emit(int(event[&"amount"]), event[&"source"] as StringName)
		return
	var remaining: float = delta
	var transitions: int = 0
	var emitted_attack: bool = false
	while remaining > 0.00001 and transitions < _p_int(&"maximum_transitions_per_advance"):
		var state: StringName = worm[&"state"] as StringName
		var state_remaining: float = maxf(float(worm[&"state_remaining"]), 0.0)
		var consumed: float = minf(remaining, state_remaining)
		var elapsed_before: float = float(worm[&"state_elapsed"])
		_advance_state_motion(worm, state, consumed)
		worm[&"state_elapsed"] = elapsed_before + consumed
		worm[&"state_remaining"] = state_remaining - consumed
		if state == STATE_EMBER_SALVO and not emitted_attack:
			emitted_attack = _resolve_salvo_pulses(worm, elapsed_before, elapsed_before + consumed)
		if (
			worm.get(&"kind", WORM_KIND) == BOSS_KIND
			and worm.get(&"attack_pattern", &"") == IronjawBossScript.PATTERN_RINGQUAKE
			and state == STATE_EXPOSE
			and not emitted_attack
		):
			emitted_attack = IronjawBossScript.resolve_ring_pulses(
				worm, elapsed_before, elapsed_before + consumed, _player_position, _outpost_linked
			)
			if emitted_attack and WorldSafetyScript.allows_damage(_player_position, _world):
				_last_attack_count += 1
				damage_tick.emit(IronjawBossScript.ATTACK_DAMAGE, BOSS_KIND)
		remaining -= consumed
		if not _state_expired(worm) or state in [STATE_DISPERSING, STATE_DEFEATED]:
			break
		var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
		if FaunaCombatScript.tracking_state(kind, state) and not _player_detected(worm):
			_set_state(worm, state, _state_duration(kind, state))
			break
		emitted_attack = _transition_state(worm, not emitted_attack) or emitted_attack
		transitions += 1


func _advance_state_motion(worm: Dictionary, state: StringName, delta: float) -> void:
	if delta <= 0.0:
		return
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	if state in [STATE_INTERCEPT, STATE_WAKE_SWEEP, STATE_POUNCE]:
		var duration: float = maxf(float(worm[&"state_duration"]), 0.001)
		var progress: float = clampf((float(worm[&"state_elapsed"]) + delta) / duration, 0.0, 1.0)
		worm[&"position"] = (worm[&"intercept_start"] as Vector2).lerp(
			worm[&"committed_target"] as Vector2, progress
		)
	elif FaunaCombatScript.tracking_state(kind, state) and not _is_burrow_kind(kind):
		if WorldSafetyScript.allows_pursuit(_player_position, _world):
			_advance_surface_tracking(worm, delta)
		else:
			_set_state(worm, STATE_DISPERSING, _p_float(&"disperse_seconds"))
	elif state == STATE_DISPERSING:
		var away: Vector2 = (worm[&"position"] as Vector2) - _player_position
		if away.is_zero_approx():
			away = Vector2.RIGHT
		var disperse_speed: float = (
			_p_float(&"burrow_speed")
			if _is_burrow_kind(kind)
			else FaunaCombatScript.value(kind, &"move_speed", _p_float(&"burrow_speed"))
		)
		worm[&"direction"] = away.normalized()
		worm[&"position"] = (
			(worm[&"position"] as Vector2) + away.normalized() * disperse_speed * 2.2 * delta
		)


func _transition_state(worm: Dictionary, may_attack: bool) -> bool:
	var state: StringName = worm[&"state"] as StringName
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	if not _is_burrow_kind(kind):
		return _transition_native_state(worm, state, may_attack)
	if state == STATE_BURROW:
		_commit_intercept(worm)
		return false
	if state == STATE_INTERCEPT:
		var expose_offset: float = (
			IronjawBossScript.expose_offset(int(worm.get(&"armor_stage", 0)))
			if kind == BOSS_KIND
			else _p_float(&"expose_offset")
		)
		worm[&"position"] = (
			(worm[&"committed_target"] as Vector2) - (worm[&"direction"] as Vector2) * expose_offset
		)
		_set_state(worm, STATE_EXPOSE, _entity_state_duration(worm, STATE_EXPOSE))
		var ringquake: bool = (
			kind == BOSS_KIND
			and worm.get(&"attack_pattern", &"") == IronjawBossScript.PATTERN_RINGQUAKE
		)
		return _resolve_attack(worm) if may_attack and not ringquake else false
	if state == STATE_EXPOSE:
		_set_state(worm, STATE_DIVE, _entity_state_duration(worm, STATE_DIVE))
		return false
	if state == STATE_DIVE:
		_set_state(worm, STATE_BURROW, _entity_state_duration(worm, STATE_BURROW))
		return false
	if state == STATE_STAGGERED:
		_resume_after_stagger(worm)
	return false


func _transition_native_state(worm: Dictionary, state: StringName, may_attack: bool) -> bool:
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	if state == FaunaCombatScript.initial_state(kind):
		_commit_native_warning(worm)
		return false
	if state == FaunaCombatScript.warning_state(kind):
		_begin_native_attack(worm)
		return false
	if state == FaunaCombatScript.attack_state(kind):
		var attacked: bool = false
		if kind != CINDER_KIND and may_attack:
			attacked = _resolve_attack(worm)
		_set_state(worm, STATE_RECOVER, _state_duration(kind, STATE_RECOVER))
		return attacked
	if state == STATE_RECOVER:
		var initial: StringName = FaunaCombatScript.initial_state(kind)
		_set_state(worm, initial, _state_duration(kind, initial))
		return false
	if state == STATE_STAGGERED:
		_resume_after_stagger(worm)
	return false


func _commit_intercept(worm: Dictionary) -> void:
	if not WorldSafetyScript.allows_pursuit(_player_position, _world):
		_set_state(worm, STATE_DISPERSING, _p_float(&"disperse_seconds"))
		return
	if worm.get(&"kind", WORM_KIND) == BOSS_KIND:
		IronjawBossScript.commit_attack(worm, _player_position, _player_velocity)
		_set_state(worm, STATE_INTERCEPT, _entity_state_duration(worm, STATE_INTERCEPT))
		telegraph_started.emit(BOSS_KIND, int(worm[&"id"]), int(worm[&"attack_serial"]))
		return
	var position: Vector2 = worm[&"position"] as Vector2
	var raw_lead: Vector2 = _player_velocity * _p_float(&"maximum_lead_seconds")
	var lead: Vector2 = raw_lead.limit_length(_p_float(&"maximum_lead_distance"))
	var target: Vector2 = _player_position + lead
	var direction: Vector2 = target - position
	worm[&"direction"] = Vector2.DOWN if direction.is_zero_approx() else direction.normalized()
	worm[&"intercept_start"] = position
	worm[&"committed_target"] = target
	worm[&"attack_serial"] = int(worm[&"attack_serial"]) + 1
	_set_state(worm, STATE_INTERCEPT, _p_float(&"intercept_seconds"))
	telegraph_started.emit(WORM_KIND, int(worm[&"id"]), int(worm[&"attack_serial"]))


func _commit_native_warning(worm: Dictionary) -> void:
	if not WorldSafetyScript.allows_pursuit(_player_position, _world):
		_set_state(worm, STATE_DISPERSING, _p_float(&"disperse_seconds"))
		return
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	var position: Vector2 = worm[&"position"] as Vector2
	var lead_seconds: float = FaunaCombatScript.value(kind, &"lead_seconds")
	var lead_distance: float = FaunaCombatScript.value(kind, &"lead_distance")
	var target: Vector2 = (
		_player_position + (_player_velocity * lead_seconds).limit_length(lead_distance)
	)
	var direction: Vector2 = target - position
	direction = Vector2.DOWN if direction.is_zero_approx() else direction.normalized()
	if kind == SKIMMER_KIND:
		target += direction * FaunaCombatScript.value(kind, &"overshoot")
	worm[&"direction"] = direction
	worm[&"intercept_start"] = position
	worm[&"committed_target"] = target
	worm[&"attack_serial"] = int(worm[&"attack_serial"]) + 1
	worm[&"resolved_pulses"] = 0
	worm[&"strike_targets"] = (
		FaunaCombatScript.salvo_targets(target, direction) if kind == CINDER_KIND else [target]
	)
	worm[&"strike_pulses"] = 3 if kind == CINDER_KIND else 1
	var warning_state: StringName = FaunaCombatScript.warning_state(kind)
	_set_state(worm, warning_state, _state_duration(kind, warning_state))
	telegraph_started.emit(kind, int(worm[&"id"]), int(worm[&"attack_serial"]))


func _begin_native_attack(worm: Dictionary) -> void:
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	worm[&"intercept_start"] = worm[&"position"]
	var attack_state: StringName = FaunaCombatScript.attack_state(kind)
	_set_state(worm, attack_state, _state_duration(kind, attack_state))


func _resolve_attack(worm: Dictionary) -> bool:
	var attack_serial: int = int(worm[&"attack_serial"])
	if attack_serial <= int(worm[&"resolved_attack_serial"]):
		return false
	worm[&"resolved_attack_serial"] = attack_serial
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	if kind == BOSS_KIND:
		if (
			not WorldSafetyScript.allows_damage(_player_position, _world)
			or _outpost_linked
			or not IronjawBossScript.committed_attack_hits(worm, _player_position)
		):
			return false
		_last_attack_count += 1
		damage_tick.emit(IronjawBossScript.ATTACK_DAMAGE, BOSS_KIND)
		return true
	var attack_distance: float = (worm[&"position"] as Vector2).distance_to(_player_position)
	if kind == SKIMMER_KIND:
		attack_distance = FaunaCombatScript.distance_to_segment(
			_player_position,
			worm[&"intercept_start"] as Vector2,
			worm[&"committed_target"] as Vector2,
		)
	if (
		not WorldSafetyScript.allows_damage(_player_position, _world)
		or _outpost_linked
		or attack_distance > FaunaCombatScript.attack_range(kind, _profile)
	):
		return false
	_last_attack_count += 1
	damage_tick.emit(FaunaCombatScript.damage(kind, _profile), kind)
	return true


func _resolve_salvo_pulses(worm: Dictionary, elapsed_before: float, elapsed_after: float) -> bool:
	if _outpost_linked or not WorldSafetyScript.allows_projectile_target(_player_position, _world):
		worm[&"resolved_pulses"] = int(worm[&"strike_pulses"])
	var duration: float = maxf(float(worm[&"state_duration"]), 0.001)
	var before: int = mini(floori(elapsed_before / duration * 3.0), 3)
	var after: int = mini(floori((elapsed_after + 0.00001) / duration * 3.0), 3)
	var emitted: bool = false
	var targets: Array = worm[&"strike_targets"] as Array
	for pulse: int in range(maxi(before, int(worm[&"resolved_pulses"])), after):
		worm[&"resolved_pulses"] = pulse + 1
		if _outpost_linked or pulse >= targets.size() or emitted:
			continue
		if (
			(targets[pulse] as Vector2).distance_to(_player_position)
			> FaunaCombatScript.attack_range(CINDER_KIND, _profile)
		):
			continue
		_last_attack_count += 1
		damage_tick.emit(FaunaCombatScript.damage(CINDER_KIND, _profile), CINDER_KIND)
		emitted = true
	return emitted


func _resume_after_stagger(worm: Dictionary) -> void:
	var resume_state: StringName = worm[&"resume_state"] as StringName
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	if (
		kind == BOSS_KIND
		and resume_state not in [STATE_BURROW, STATE_INTERCEPT, STATE_EXPOSE, STATE_DIVE]
	):
		resume_state = STATE_BURROW
	elif kind != BOSS_KIND and not FaunaCombatScript.legal_primary_state(kind, resume_state):
		resume_state = FaunaCombatScript.initial_state(kind)
	var remaining: float = maxf(float(worm[&"resume_remaining"]), 0.05)
	_set_state(worm, resume_state, remaining)


func _advance_surface_tracking(worm: Dictionary, delta: float) -> void:
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	var position: Vector2 = worm[&"position"] as Vector2
	var to_player: Vector2 = _player_position - position
	if to_player.is_zero_approx():
		return
	var direction: Vector2 = to_player.normalized()
	if kind == SKIMMER_KIND:
		var side: float = -1.0 if int(worm[&"id"]) % 2 == 0 else 1.0
		direction = (direction * 0.42 + direction.orthogonal() * side * 0.58).normalized()
	worm[&"direction"] = direction
	var speed: float = FaunaCombatScript.value(kind, &"move_speed")
	var step: float = minf(speed * delta, maxf(to_player.length() - 1.35, 0.0))
	worm[&"position"] = position + direction * step


func _state_duration(kind: StringName, state: StringName) -> float:
	return FaunaCombatScript.state_duration(kind, state, _profile)


func _entity_state_duration(worm: Dictionary, state: StringName) -> float:
	if worm.get(&"kind", WORM_KIND) == BOSS_KIND:
		return IronjawBossScript.state_duration(state, int(worm.get(&"armor_stage", 0)))
	return _state_duration(worm.get(&"kind", WORM_KIND) as StringName, state)


func _is_burrow_kind(kind: StringName) -> bool:
	return kind in [WORM_KIND, BOSS_KIND]


func _set_state(worm: Dictionary, state: StringName, duration: float) -> void:
	worm[&"state"] = state
	worm[&"state_elapsed"] = 0.0
	worm[&"state_remaining"] = maxf(duration, 0.0)
	worm[&"state_duration"] = maxf(duration, 0.0)


func _state_expired(worm: Dictionary) -> bool:
	return float(worm[&"state_remaining"]) <= 0.00001


func _player_detected(worm: Dictionary) -> bool:
	return (
		(worm[&"position"] as Vector2).distance_to(_player_position) <= _p_float(&"detection_range")
	)


func _find_worm(worm_id: int) -> Dictionary:
	for worm: Dictionary in _worms:
		if int(worm[&"id"]) == worm_id:
			return worm
	return {}


func _sync_biome(position: Vector2) -> void:
	if _world == null:
		return
	var next_biome: StringName = _world.call("_biome_at", Vector2i(position.round())) as StringName
	_set_active_biome(next_biome)


func _p_float(property: StringName) -> float:
	return float(_profile.get(property))


func _p_int(property: StringName) -> int:
	return int(_profile.get(property))


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
	var offset: Vector2 = FaunaVisualsScript.feedback_offset(_tile_size, worm)
	var center: Vector2 = _grid_to_screen(worm[&"position"] as Vector2) + offset
	var state: StringName = worm[&"state"] as StringName
	var progress: float = _state_progress(worm)
	var alpha: float = 1.0
	if state in [STATE_DISPERSING, STATE_DEFEATED]:
		alpha = 1.0 - progress
	var kind: StringName = worm.get(&"kind", WORM_KIND) as StringName
	center.y -= FaunaCombatScript.bounce_offset(_time, int(worm[&"id"]), kind, state)
	if (
		FaunaVisualsScript
		. draw_enemy(
			self,
			center,
			worm,
			state,
			progress,
			alpha,
			_time,
			_hovered_enemy_id,
			_p_int(&"max_health"),
		)
	):
		return
	SandwormVisualsScript.draw_sand_wake(
		self, center, worm[&"direction"] as Vector2, _time, alpha
	)
	if SandwormVisualsScript.draw_burrow_transition(self, center, worm, progress, alpha):
		return
	_draw_exposed_body(center, worm, alpha)


func _draw_exposed_body(center: Vector2, worm: Dictionary, alpha: float) -> void:
	(
		SandwormVisualsScript
		. draw_exposed_body(
			self,
			center,
			worm[&"direction"] as Vector2,
			_time,
			int(worm[&"id"]),
			worm[&"state"] as StringName,
			int(worm[&"health"]),
			int(worm.get(&"max_health", _p_int(&"max_health"))),
			alpha,
			int(worm[&"id"]) == _hovered_enemy_id,
			float(worm[&"hit_flash"]) > 0.0,
			bool(worm.get(&"is_boss", false)),
			int(worm.get(&"armor_stage", 0)),
		)
	)


func _state_progress(worm: Dictionary) -> float:
	var duration: float = maxf(float(worm[&"state_duration"]), 0.001)
	return clampf(float(worm[&"state_elapsed"]) / duration, 0.0, 1.0)
