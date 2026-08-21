extends Node

const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")

const GLOBAL_VOICE_COUNT: int = 6
const SPATIAL_VOICE_COUNT: int = 12
const SPATIAL_MAX_DISTANCE: float = 1440.0
const MIN_LINEAR_VOLUME: float = 0.0001
const BUS_MASTER: StringName = &"Master"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"
const BUS_WALKER: StringName = &"Walker"
const BUS_COMBAT: StringName = &"Combat"
const BUS_ENEMY: StringName = &"Enemy"
const BUS_WORLD: StringName = &"World"
const BUS_AMBIENT: StringName = &"Ambient"
const BUS_MUSIC: StringName = &"Music"
const BUS_HIERARCHY: Dictionary = {
	BUS_MASTER: &"",
	BUS_SFX: BUS_MASTER,
	BUS_UI: BUS_SFX,
	BUS_WALKER: BUS_SFX,
	BUS_COMBAT: BUS_SFX,
	BUS_ENEMY: BUS_SFX,
	BUS_WORLD: BUS_SFX,
	BUS_AMBIENT: BUS_MASTER,
	BUS_MUSIC: BUS_MASTER,
}

var _global_voices: Array[AudioStreamPlayer] = []
var _spatial_voices: Array[AudioStreamPlayer2D] = []
var _global_priorities: Array[int] = []
var _spatial_priorities: Array[int] = []
var _global_serials: Array[int] = []
var _spatial_serials: Array[int] = []
var _bound_panel: Node
var _next_serial: int = 1
var _sfx_enabled: bool = true
var _global_requests: int = 0
var _spatial_requests: int = 0
var _accepted_count: int = 0
var _culled_count: int = 0
var _stolen_count: int = 0
var _last_bus: StringName = &""
var _last_position: Vector2 = Vector2.ZERO
var _last_stream_path: String = ""


func _ready() -> void:
	_ensure_bus_hierarchy()
	_create_voice_pools()
	var preferences: RefCounted = PlayerPreferencesScript.new() as RefCounted
	apply_preferences(preferences.call("load_preferences") as Dictionary)


func _process(_delta: float) -> void:
	if not is_instance_valid(_bound_panel):
		_bind_accessibility()


func play_global(
	stream: AudioStream,
	bus: StringName = BUS_SFX,
	pitch: float = 1.0,
	volume_db: float = 0.0,
	priority: int = 1,
) -> bool:
	_global_requests += 1
	if not _accepts(stream, bus):
		_culled_count += 1
		return false
	_remember_request(stream, bus, Vector2.ZERO)
	if DisplayServer.get_name() == "headless":
		_accepted_count += 1
		return true
	var index: int = _select_global_voice(clampi(priority, 0, 3))
	if index < 0:
		_culled_count += 1
		return false
	var player: AudioStreamPlayer = _global_voices[index]
	player.stream = stream
	player.bus = bus
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.volume_db = clampf(volume_db, -48.0, 6.0)
	player.play()
	_stamp_voice(_global_priorities, _global_serials, index, priority)
	_accepted_count += 1
	return true


func play_spatial(
	stream: AudioStream,
	position: Vector2,
	bus: StringName = BUS_WORLD,
	pitch: float = 1.0,
	volume_db: float = 0.0,
	priority: int = 1,
	max_distance: float = SPATIAL_MAX_DISTANCE,
) -> bool:
	_spatial_requests += 1
	if not _accepts(stream, bus):
		_culled_count += 1
		return false
	_remember_request(stream, bus, position)
	if DisplayServer.get_name() == "headless":
		_accepted_count += 1
		return true
	var index: int = _select_spatial_voice(clampi(priority, 0, 3))
	if index < 0:
		_culled_count += 1
		return false
	var player: AudioStreamPlayer2D = _spatial_voices[index]
	player.stream = stream
	player.position = position
	player.bus = bus
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.volume_db = clampf(volume_db, -48.0, 6.0)
	player.max_distance = maxf(max_distance, 64.0)
	player.play()
	_stamp_voice(_spatial_priorities, _spatial_serials, index, priority)
	_accepted_count += 1
	return true


func apply_preferences(snapshot: Dictionary) -> void:
	set_sfx_enabled(bool(snapshot.get(&"sfx_enabled", true)))
	_set_bus_linear(BUS_MASTER, float(snapshot.get(&"master_volume", 1.0)))
	_set_bus_linear(BUS_SFX, float(snapshot.get(&"sfx_volume", 1.0)))
	_set_bus_linear(BUS_MUSIC, float(snapshot.get(&"music_volume", 1.0)))


func set_sfx_enabled(enabled: bool) -> void:
	_sfx_enabled = enabled
	var sfx_index: int = AudioServer.get_bus_index(BUS_SFX)
	if sfx_index >= 0:
		AudioServer.set_bus_mute(sfx_index, not _sfx_enabled)
	if not _sfx_enabled:
		stop_sfx()


func stop_sfx() -> void:
	for player: AudioStreamPlayer in _global_voices:
		if player.bus != BUS_MUSIC and player.bus != BUS_AMBIENT:
			player.stop()
	for player: AudioStreamPlayer2D in _spatial_voices:
		player.stop()


func get_metrics() -> Dictionary:
	return {
		&"global_requests": _global_requests,
		&"spatial_requests": _spatial_requests,
		&"accepted": _accepted_count,
		&"culled": _culled_count,
		&"stolen": _stolen_count,
		&"global_active": _active_global_count(),
		&"spatial_active": _active_spatial_count(),
		&"global_capacity": GLOBAL_VOICE_COUNT,
		&"spatial_capacity": SPATIAL_VOICE_COUNT,
		&"sfx_enabled": _sfx_enabled,
		&"last_bus": _last_bus,
		&"last_position": _last_position,
		&"last_stream_path": _last_stream_path,
	}


func get_bus_layout_status() -> Dictionary:
	var sends: Dictionary = {}
	for bus: StringName in BUS_HIERARCHY:
		var index: int = AudioServer.get_bus_index(bus)
		if index < 0:
			return {&"valid": false, &"missing": bus, &"sends": sends}
		sends[bus] = AudioServer.get_bus_send(index)
	return {&"valid": true, &"missing": &"", &"sends": sends}


func get_voice_layout() -> Dictionary:
	var globals: Array[Dictionary] = []
	for player: AudioStreamPlayer in _global_voices:
		globals.append({&"name": player.name, &"bus": player.bus, &"positional": false})
	var spatials: Array[Dictionary] = []
	for player: AudioStreamPlayer2D in _spatial_voices:
		spatials.append(
			{
				&"name": player.name,
				&"bus": player.bus,
				&"positional": true,
				&"max_distance": player.max_distance,
			}
		)
	return {&"global": globals, &"spatial": spatials}


func _ensure_bus_hierarchy() -> void:
	for bus: StringName in BUS_HIERARCHY:
		var index: int = AudioServer.get_bus_index(bus)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(index, bus)
		var send: StringName = BUS_HIERARCHY[bus] as StringName
		if bus != BUS_MASTER:
			AudioServer.set_bus_send(index, send)


func _create_voice_pools() -> void:
	if not _global_voices.is_empty() or not _spatial_voices.is_empty():
		return
	for index: int in range(GLOBAL_VOICE_COUNT):
		var global: AudioStreamPlayer = AudioStreamPlayer.new()
		global.name = "GlobalVoice%02d" % index
		global.bus = BUS_SFX
		add_child(global)
		_global_voices.append(global)
		_global_priorities.append(0)
		_global_serials.append(0)
	for index: int in range(SPATIAL_VOICE_COUNT):
		var spatial: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		spatial.name = "SpatialVoice%02d" % index
		spatial.bus = BUS_WORLD
		spatial.max_distance = SPATIAL_MAX_DISTANCE
		spatial.attenuation = 1.0
		add_child(spatial)
		_spatial_voices.append(spatial)
		_spatial_priorities.append(0)
		_spatial_serials.append(0)


func _accepts(stream: AudioStream, bus: StringName) -> bool:
	if stream == null or AudioServer.get_bus_index(bus) < 0:
		return false
	return _sfx_enabled or bus == BUS_MUSIC or bus == BUS_AMBIENT


func _select_global_voice(priority: int) -> int:
	for index: int in range(_global_voices.size()):
		if not _global_voices[index].playing:
			return index
	return _steal_voice(_global_voices, _global_priorities, _global_serials, priority)


func _select_spatial_voice(priority: int) -> int:
	for index: int in range(_spatial_voices.size()):
		if not _spatial_voices[index].playing:
			return index
	return _steal_voice(_spatial_voices, _spatial_priorities, _spatial_serials, priority)


func _steal_voice(
	players: Array,
	priorities: Array[int],
	serials: Array[int],
	incoming_priority: int,
) -> int:
	var selected: int = -1
	for index: int in range(players.size()):
		if priorities[index] > incoming_priority:
			continue
		if (
			selected < 0
			or priorities[index] < priorities[selected]
			or (
				priorities[index] == priorities[selected]
				and serials[index] < serials[selected]
			)
		):
			selected = index
	if selected >= 0:
		(players[selected] as Node).call("stop")
		_stolen_count += 1
	return selected


func _stamp_voice(
	priorities: Array[int], serials: Array[int], index: int, priority: int
) -> void:
	priorities[index] = clampi(priority, 0, 3)
	serials[index] = _next_serial
	_next_serial += 1


func _remember_request(stream: AudioStream, bus: StringName, position: Vector2) -> void:
	_last_stream_path = stream.resource_path
	_last_bus = bus
	_last_position = position


func _set_bus_linear(bus: StringName, value: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index >= 0:
		var normalized: float = clampf(value, 0.0, 1.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(normalized, MIN_LINEAR_VOLUME)))
		if bus != BUS_SFX:
			AudioServer.set_bus_mute(index, normalized <= 0.0)


func _bind_accessibility() -> void:
	var panel: Node = get_tree().get_first_node_in_group("accessibility_panel")
	if panel == null or panel == _bound_panel:
		return
	_bound_panel = panel
	apply_preferences(panel.call("get_preferences") as Dictionary)
	var callback: Callable = Callable(self, "apply_preferences")
	if not panel.is_connected("preferences_changed", callback):
		panel.connect("preferences_changed", callback)


func _active_global_count() -> int:
	var active: int = 0
	for player: AudioStreamPlayer in _global_voices:
		active += 1 if player.playing else 0
	return active


func _active_spatial_count() -> int:
	var active: int = 0
	for player: AudioStreamPlayer2D in _spatial_voices:
		active += 1 if player.playing else 0
	return active
