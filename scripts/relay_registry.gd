extends Node2D

signal link_started(relay_cell: Vector2i)
signal completed(relay_cell: Vector2i)

const ExpeditionLayoutScript: GDScript = preload("res://scripts/expedition_layout.gd")
const RelayContestScript: GDScript = preload("res://scripts/relay_contest.gd")
const RunModifierEffectsScript: GDScript = preload("res://scripts/run_modifier_effects.gd")
const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")
const TEAL: Color = Color("4eb6aa")
const RELAY_SCRAP_REWARD: int = 2
const RELAY_CUE: AudioStream = preload("res://assets/audio/ui_begin.wav")

var _coordinator: RefCounted
var _objectives: Array[Dictionary] = []
var _contest: Node2D
var _tile_size: Vector2 = Vector2(90.0, 45.0)
var _map_origin: Vector2 = Vector2(760.0, 70.0)
var _player_position: Vector2 = Vector2.ZERO
var _audio: AudioStreamPlayer


func _ready() -> void:
	_audio = AudioStreamPlayer.new()
	_audio.stream = RELAY_CUE
	add_child(_audio)


func configure(
	coordinator: RefCounted,
	world: RefCounted,
	tile_size: Vector2,
	map_origin: Vector2,
) -> bool:
	if coordinator == null or world == null:
		return false
	_coordinator = coordinator
	_tile_size = tile_size
	_map_origin = map_origin
	_objectives = coordinator.call("_get_relay_objectives") as Array[Dictionary]
	if _objectives.is_empty():
		var seed: int = int(coordinator.call("get_run_value", &"seed"))
		var modifier: StringName = (
			coordinator.call("get_run_value", &"active_modifier_id") as StringName
		)
		var generated: Array[Dictionary] = ExpeditionLayoutScript.generate(seed, world, modifier)
		if (
			generated.size() != 3
			or not bool(coordinator.call("_configure_relay_objectives", generated))
		):
			return false
		_objectives = generated
	_rebuild_contest()
	queue_redraw()
	return true


func set_player_position(position: Vector2) -> void:
	_player_position = position
	if _contest != null:
		_contest.call("set_player_position", position)


func advance(delta: float) -> void:
	if _contest != null:
		_contest.call("advance", delta)


func get_state() -> StringName:
	return _contest.call("get_state") as StringName if _contest != null else &"completed"


func get_progress() -> float:
	return float(_contest.call("get_progress")) if _contest != null else 1.0


func is_completed() -> bool:
	return get_completed_count() > 0


func get_relay_cell() -> Vector2i:
	if _contest != null:
		return _contest.call("get_relay_cell") as Vector2i
	return Vector2i(-9999, -9999)


func get_signal_hint() -> String:
	return (
		str(_contest.call("get_signal_hint"))
		if _contest != null
		else "EXTRACTION READY // RETURN TO OUTPOST"
	)


func get_completed_count() -> int:
	return (
		int(_coordinator.call("get_run_value", &"completed_relays")) if _coordinator != null else 0
	)


func get_total_count() -> int:
	return _objectives.size()


func get_objectives() -> Array[Dictionary]:
	return _objectives.duplicate(true)


func _rebuild_contest() -> void:
	if _contest != null:
		_contest.queue_free()
		_contest = null
	var index: int = get_completed_count()
	if index >= _objectives.size():
		return
	var cell_value: Array = _objectives[index][&"cell"] as Array
	_contest = RelayContestScript.new() as Node2D
	_contest.name = "ActiveRelayContest"
	_contest.call(
		"configure", Vector2i(int(cell_value[0]), int(cell_value[1])), _tile_size, _map_origin
	)
	_contest.call("set_player_position", _player_position)
	_contest.connect("link_started", func(cell: Vector2i) -> void: link_started.emit(cell))
	_contest.connect("completed", _on_contest_completed)
	add_child(_contest)


func _on_contest_completed(cell: Vector2i) -> void:
	var index: int = get_completed_count()
	if index >= _objectives.size():
		return
	var objective_id: StringName = StringName(str(_objectives[index][&"objective_id"]))
	if not bool(_coordinator.call("_complete_next_relay", objective_id)):
		return
	var modifier: StringName = (
		_coordinator.call("get_run_value", &"active_modifier_id") as StringName
	)
	var reward: int = RunModifierEffectsScript.relay_scrap(RELAY_SCRAP_REWARD, modifier)
	_coordinator.call(
		"set_run_value", &"scrap", int(_coordinator.call("get_run_value", &"scrap")) + reward
	)
	var preferences: Dictionary = (
		(PlayerPreferencesScript.new() as RefCounted).call("load_preferences") as Dictionary
	)
	if bool(preferences.get(&"sfx_enabled", true)) and DisplayServer.get_name() != "headless":
		_audio.pitch_scale = 0.96 + float(index) * 0.09
		_audio.play()
	completed.emit(cell)
	_rebuild_contest()
	queue_redraw()


func _draw() -> void:
	var completed_count: int = get_completed_count()
	for index: int in range(mini(completed_count, _objectives.size())):
		var cell_value: Array = _objectives[index][&"cell"] as Array
		var cell: Vector2 = Vector2(float(cell_value[0]), float(cell_value[1]))
		var center: Vector2 = (
			_map_origin
			+ Vector2(
				(cell.x - cell.y) * _tile_size.x * 0.5,
				(cell.x + cell.y) * _tile_size.y * 0.5,
			)
		)
		draw_arc(center, 46.0, 0.0, TAU, 32, TEAL, 4.0)
