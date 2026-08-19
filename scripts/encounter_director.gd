extends Node

const RunModifierEffectsScript: GDScript = preload("res://scripts/run_modifier_effects.gd")

const PROFILES: Array[Resource] = [
	preload("res://data/alerts/alert_i.tres"),
	preload("res://data/alerts/alert_ii.tres"),
	preload("res://data/alerts/alert_iii.tres"),
]
const INVALID_POSITION: Vector2 = Vector2(-9999.0, -9999.0)
const AMBIENT_WORM_INITIAL_SECONDS: float = 3.0
const AMBIENT_WORM_INTERVAL_MIN: float = 8.0
const AMBIENT_WORM_INTERVAL_MAX: float = 12.0
const INITIAL_WORM_SOFT_CAP: int = 1
const AMBIENT_WORM_SOFT_CAP: int = 4
const AMBIENT_TORNADO_INITIAL_SECONDS: float = 4.0
const AMBIENT_TORNADO_INTERVAL_MIN: float = 5.0
const AMBIENT_TORNADO_INTERVAL_MAX: float = 8.0
const AMBIENT_TORNADO_SOFT_CAP: int = 6
const AMBIENT_SANDSTORM_INITIAL_SECONDS: float = 8.0
const AMBIENT_SANDSTORM_INTERVAL_MIN: float = 10.0
const AMBIENT_SANDSTORM_INTERVAL_MAX: float = 14.0
const AMBIENT_SANDSTORM_SOFT_CAP: int = 2

var _coordinator: RefCounted
var _world: RefCounted
var _worms: Node2D
var _hazards: Node2D
var _armed_alert: int = 0
var _spawned_alert: int = 0
var _rearm_remaining: float = 0.0
var _sanctuary: bool = false
var _ambient_enabled: bool = true
var _ambient_worm_remaining: float = AMBIENT_WORM_INITIAL_SECONDS
var _ambient_tornado_remaining: float = AMBIENT_TORNADO_INITIAL_SECONDS
var _ambient_sandstorm_remaining: float = AMBIENT_SANDSTORM_INITIAL_SECONDS
var _active_biome: StringName = &"desert"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 0xA6B1E47


func configure(
	coordinator: RefCounted,
	world: RefCounted,
	worms: Node2D,
	hazards: Node2D,
) -> bool:
	if coordinator == null or world == null or worms == null or hazards == null:
		return false
	for profile: Resource in PROFILES:
		if not bool(profile.call("validate")):
			return false
	_rng.seed = 0xA6B1E47
	_coordinator = coordinator
	_world = world
	_worms = worms
	_hazards = hazards
	_worms.call("set_auto_spawn", false)
	_hazards.call("set_auto_spawn", false)
	_sync_alert()
	return true


func set_ambient_enabled(enabled: bool) -> void:
	_ambient_enabled = enabled


func _process(delta: float) -> void:
	if _coordinator == null:
		return
	var step: float = maxf(delta, 0.0)
	var player: Vector2 = Vector2(_coordinator.call("get_run_value", &"player_cell"))
	_sync_biome(player)
	var sanctuary_now: bool = bool(_world.call("_is_in_sanctuary", player))
	if sanctuary_now and not _sanctuary:
		_worms.call("disperse_all")
		_reset_ambient_grace()
	_sanctuary = sanctuary_now
	_sync_alert()
	if _ambient_enabled and not _sanctuary:
		_advance_ambient(step, player)
	if _armed_alert <= 0 or _spawned_alert >= _armed_alert or _sanctuary:
		return
	_rearm_remaining = maxf(_rearm_remaining - step, 0.0)
	if _rearm_remaining <= 0.0:
		_spawn_composition(_armed_alert, player)
		_spawned_alert = _armed_alert


func get_alert_level() -> int:
	return (
		int(_coordinator.call("get_run_value", &"completed_relays")) if _coordinator != null else 0
	)


func is_sanctuary_active() -> bool:
	return _sanctuary


func get_spawned_alert() -> int:
	return _spawned_alert


func get_worm_soft_cap() -> int:
	if _coordinator == null or not bool(_coordinator.call("get_run_value", &"first_worm_defeated")):
		return INITIAL_WORM_SOFT_CAP
	return AMBIENT_WORM_SOFT_CAP


func _advance_ambient(delta: float, player: Vector2) -> void:
	_ambient_worm_remaining -= delta
	if _ambient_worm_remaining <= 0.0:
		if int(_worms.call("get_worm_count")) < get_worm_soft_cap():
			_spawn_ambient_worm(player)
		_ambient_worm_remaining = _rng.randf_range(
			AMBIENT_WORM_INTERVAL_MIN, AMBIENT_WORM_INTERVAL_MAX
		)
	if _active_biome != &"desert":
		return
	_ambient_tornado_remaining -= delta
	if _ambient_tornado_remaining <= 0.0:
		if int(_hazards.call("get_hazard_count", &"tornado")) < AMBIENT_TORNADO_SOFT_CAP:
			_spawn_ambient_tornado(player)
		_ambient_tornado_remaining = _rng.randf_range(
			AMBIENT_TORNADO_INTERVAL_MIN, AMBIENT_TORNADO_INTERVAL_MAX
		)
	_ambient_sandstorm_remaining -= delta
	if _ambient_sandstorm_remaining <= 0.0:
		if int(_hazards.call("get_hazard_count", &"sandstorm")) < AMBIENT_SANDSTORM_SOFT_CAP:
			_spawn_ambient_sandstorm(player)
		_ambient_sandstorm_remaining = _rng.randf_range(
			AMBIENT_SANDSTORM_INTERVAL_MIN, AMBIENT_SANDSTORM_INTERVAL_MAX
		)


func _reset_ambient_grace() -> void:
	_ambient_worm_remaining = AMBIENT_WORM_INITIAL_SECONDS
	_ambient_tornado_remaining = AMBIENT_TORNADO_INITIAL_SECONDS
	_ambient_sandstorm_remaining = AMBIENT_SANDSTORM_INITIAL_SECONDS


func _spawn_ambient_worm(player: Vector2) -> void:
	var angle: float = _rng.randf_range(0.0, TAU)
	var radius: float = _rng.randf_range(5.25, 7.25)
	_worms.call("spawn_worm", player + Vector2.from_angle(angle) * radius)


func _spawn_ambient_tornado(player: Vector2) -> void:
	var angle: float = _rng.randf_range(0.0, TAU)
	var radius: float = _rng.randf_range(3.5, 7.0)
	_hazards.call("spawn_tornado", Vector2i((player + Vector2.from_angle(angle) * radius).round()))


func _spawn_ambient_sandstorm(player: Vector2) -> void:
	var center: Vector2i = Vector2i(player.round())
	var lateral: int = _rng.randi_range(-2, 0)
	match _rng.randi_range(0, 3):
		0:
			_hazards.call("spawn_sandstorm", center + Vector2i(-12, lateral), Vector2i.RIGHT)
		1:
			_hazards.call("spawn_sandstorm", center + Vector2i(12, lateral), Vector2i.LEFT)
		2:
			_hazards.call("spawn_sandstorm", center + Vector2i(lateral, -12), Vector2i.DOWN)
		_:
			_hazards.call("spawn_sandstorm", center + Vector2i(lateral, 12), Vector2i.UP)


func _sync_alert() -> void:
	var alert: int = clampi(get_alert_level(), 0, 3)
	if alert == _armed_alert:
		return
	_armed_alert = alert
	var modifier: StringName = (
		_coordinator.call("get_run_value", &"active_modifier_id") as StringName
	)
	_rearm_remaining = (
		RunModifierEffectsScript.storm_interval(
			float(PROFILES[alert - 1].get("rearm_seconds")), modifier
		)
		if alert > 0
		else 0.0
	)


func _spawn_composition(alert: int, player: Vector2) -> void:
	var profile: Resource = PROFILES[alert - 1]
	var modifier: StringName = (
		_coordinator.call("get_run_value", &"active_modifier_id") as StringName
	)
	if _active_biome == &"oasis":
		var skimmer_count: int = (
			RunModifierEffectsScript.worm_count(int(profile.get("worm_count")), modifier)
			+ int(profile.get("tornado_count"))
			+ int(profile.get("broad_storm_count"))
		)
		for index: int in range(skimmer_count):
			if int(_worms.call("get_worm_count")) >= get_worm_soft_cap():
				break
			_worms.call("spawn_worm", player + Vector2(4.0 + index * 1.5, -2.0), 0.45)
		return
	for index: int in range(
		RunModifierEffectsScript.worm_count(int(profile.get("worm_count")), modifier)
	):
		if int(_worms.call("get_worm_count")) >= get_worm_soft_cap():
			break
		_worms.call("spawn_worm", player + Vector2(5.0 + index * 2.0, -2.0), 0.8)
	for index: int in range(int(profile.get("tornado_count"))):
		var offset: Vector2i = Vector2i(-5 + index * 10, -4 if index == 0 else 5)
		_hazards.call("spawn_tornado", Vector2i(player.round()) + offset)
	if int(profile.get("broad_storm_count")) > 0:
		_hazards.call(
			"spawn_sandstorm", Vector2i(player.round()) + Vector2i(-16, -1), Vector2i.RIGHT
		)


func _sync_biome(player: Vector2) -> void:
	var biome: StringName = _world.call("_biome_at", Vector2i(player.round())) as StringName
	if biome == _active_biome:
		return
	_active_biome = biome
	_worms.call("_set_active_biome", biome)
	if biome != &"desert":
		_hazards.call("clear_hazards")
	_reset_ambient_grace()
