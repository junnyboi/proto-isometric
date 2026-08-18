extends Node

const PROFILES: Array[Resource] = [
	preload("res://data/alerts/alert_i.tres"),
	preload("res://data/alerts/alert_ii.tres"),
	preload("res://data/alerts/alert_iii.tres"),
]
const INVALID_POSITION: Vector2 = Vector2(-9999.0, -9999.0)

var _coordinator: RefCounted
var _world: RefCounted
var _worms: Node2D
var _hazards: Node2D
var _armed_alert: int = 0
var _spawned_alert: int = 0
var _rearm_remaining: float = 0.0
var _sanctuary: bool = false


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
	_coordinator = coordinator
	_world = world
	_worms = worms
	_hazards = hazards
	_worms.call("set_auto_spawn", false)
	_hazards.call("set_auto_spawn", false)
	_sync_alert()
	return true


func _process(delta: float) -> void:
	if _coordinator == null:
		return
	var player: Vector2 = Vector2(_coordinator.call("get_run_value", &"player_cell"))
	var sanctuary_now: bool = bool(_world.call("_is_in_sanctuary", player))
	if sanctuary_now and not _sanctuary:
		_worms.call("disperse_all")
	_sanctuary = sanctuary_now
	_sync_alert()
	if _armed_alert <= 0 or _spawned_alert >= _armed_alert or _sanctuary:
		return
	_rearm_remaining = maxf(_rearm_remaining - maxf(delta, 0.0), 0.0)
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


func _sync_alert() -> void:
	var alert: int = clampi(get_alert_level(), 0, 3)
	if alert == _armed_alert:
		return
	_armed_alert = alert
	_rearm_remaining = float(PROFILES[alert - 1].get("rearm_seconds")) if alert > 0 else 0.0


func _spawn_composition(alert: int, player: Vector2) -> void:
	var profile: Resource = PROFILES[alert - 1]
	if int(profile.get("worm_count")) > 0:
		_worms.call("spawn_worm", player + Vector2(5.0, -2.0), 0.8)
	for index: int in range(int(profile.get("tornado_count"))):
		var offset: Vector2i = Vector2i(-5 + index * 10, -4 if index == 0 else 5)
		_hazards.call("spawn_tornado", Vector2i(player.round()) + offset)
	if int(profile.get("broad_storm_count")) > 0:
		_hazards.call(
			"spawn_sandstorm", Vector2i(player.round()) + Vector2i(-16, -1), Vector2i.RIGHT
		)
