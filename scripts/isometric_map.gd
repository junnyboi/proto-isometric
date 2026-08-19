extends Node2D

const CardinalAvatarScript: GDScript = preload("res://scripts/cardinal_avatar.gd")
const ChassisFeedbackScript: GDScript = preload("res://scripts/chassis_feedback.gd")
const DesertAtmosphereScript: GDScript = preload("res://scripts/desert_atmosphere.gd")
const DesertHazardsScript: GDScript = preload("res://scripts/desert_hazards.gd")
const FieldHudScript: GDScript = preload("res://scripts/field_hud.gd")
const FieldUIBuilderScript: GDScript = preload("res://scripts/field_ui_builder.gd")
const ImpactChargeScript: GDScript = preload("res://scripts/impact_charge.gd")
const ImpactEffectsScript: GDScript = preload("res://scripts/impact_effects.gd")
const ImpactTargetingScript: GDScript = preload("res://scripts/impact_targeting.gd")
const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const IsometricControlsScript: GDScript = preload("res://scripts/isometric_controls.gd")
const MobileControlsScript: GDScript = preload("res://scripts/mobile_controls.gd")
const ModuleEffectsScript: GDScript = preload("res://scripts/module_effects.gd")
const RelayContestScript: GDScript = preload("res://scripts/relay_registry.gd")
const ResponsiveCameraScript: GDScript = preload("res://scripts/responsive_camera.gd")
const ResourceMagnetScript: GDScript = preload("res://scripts/resource_magnet.gd")
const RunCoordinatorScript: GDScript = preload("res://scripts/run_coordinator.gd")
const RunModifierEffectsScript: GDScript = preload("res://scripts/run_modifier_effects.gd")
const RunTerminalFlowScript: GDScript = preload("res://scripts/run_terminal_flow.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const SaveRepositoryScript: GDScript = preload("res://scripts/save_repository.gd")
const TerrainHazeScript: GDScript = preload("res://scripts/terrain_haze.gd")
const TerrainRendererScript: GDScript = preload("res://scripts/terrain_renderer.gd")
const SurfaceDriveScript: GDScript = preload("res://scripts/surface_drive.gd")
const WormTelegraphScript: GDScript = preload("res://scripts/worm_telegraph.gd")
const WorldObjectsScript: GDScript = preload("res://scripts/world_objects.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const TILE_SIZE: Vector2 = Vector2(90.0, 45.0)
const MAP_ORIGIN: Vector2 = Vector2(760.0, 70.0)
const START_CELL: Vector2i = Vector2i(8, 10)
const SAVE_SCHEMA: int = SaveRepositoryScript.FORMAT_VERSION
const DEFAULT_SAVE_PATH: String = "user://walkers-wake-world.json"
const INVALID_CELL: Vector2i = Vector2i(-9999, -9999)
const WALK_SPEED: float = 150.0
const RUN_MULTIPLIER: float = 1.5
const ACCELERATION: float = 310.0
const DECELERATION: float = 390.0
const CAMERA_RESPONSE: float = 4.8
const CAMERA_LOOK_AHEAD_SECONDS: float = 0.32
const CAMERA_MAX_LEAD: float = 82.0
const MAX_CHASSIS: int = 100
const REPAIR_COST: int = 5
const REPAIR_AMOUNT: int = 35
const RESOURCE_MAGNET_RADIUS_CELLS: int = 2
const TEAL: Color = Color("4eb6aa")
const AMBER: Color = Color("f5a62d")
@export var save_path: String = DEFAULT_SAVE_PATH
var _terrain: Dictionary = {}
var _elevation: Dictionary = {}
var _blocked: Dictionary = {}
var _destructible_rocks: Dictionary = {}
var _scrap: Dictionary = {}
var _outposts: Dictionary = {}
var _scrap_count: int:
	get:
		return int(_run_value(&"scrap", 0))
	set(value):
		_set_run_value(&"scrap", value)
var _chassis: int:
	get:
		return int(_run_value(&"chassis", MAX_CHASSIS))
	set(value):
		_set_run_value(&"chassis", value)
var _terrain_textures: Dictionary = TerrainRendererScript.TEXTURES
var _robot_grid: Vector2i:
	get:
		return _run_value(&"player_cell", START_CELL) as Vector2i
	set(value):
		_set_run_value(&"player_cell", value)
var _robot_visual_position: Vector2
var _velocity: Vector2 = Vector2.ZERO
var _last_screen_direction: Vector2i = Vector2i(1, 1)
var _facing: StringName:
	get:
		return _run_value(&"facing", &"SE") as StringName
	set(value):
		_set_run_value(&"facing", value)
var _is_moving: bool = false
var _is_running: bool = false
var _impact_flash: float = 0.0
var _status_hold_time: float = 0.0
var _context_event: String = "HEAVY FRAME ONLINE"
var _attack_was_pressed: bool = false
var _pending_impact_cell: Vector2i = INVALID_CELL
var _pending_impact_band: int = 0
var _pending_impact_cells: Array[Vector2i] = []
var _pending_impact_rock_cells: Array[Vector2i] = []
var _pending_impact_worm_ids: Array[int] = []
var _shutdown: bool:
	get:
		return bool(_run_value(&"shutdown", false))
	set(value):
		_set_run_value(&"shutdown", value)
var _avatar: Node2D
var _atmosphere: Node2D
var _camera: Camera2D
var _chassis_feedback: CanvasLayer
var _effects: Node2D
var _effects_layer: CanvasLayer
var _hazards: Node2D
var _hud: CanvasLayer
var _impact_charge: Node2D
var _mobile_controls: CanvasLayer
var _object_layer: CanvasLayer
var _relay_contest: Node2D
var _run_coordinator: RefCounted
var _terminal_flow: CanvasLayer
var _sandworms: Node2D
var _state_store: RefCounted
var _terrain_haze: Node2D
var _terrain_renderer: RefCounted
var _visible_cells: Array[Vector2i] = []
var _worm_telegraph: Node2D
var _world: RefCounted
var _world_objects: Node2D


func _ready() -> void:
	var web: bool = OS.has_feature("web")
	if web: JavaScriptBridge.eval("document.body.dataset.godotScene='field-building';", true)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_run_coordinator = RunCoordinatorScript.new() as RefCounted
	if not bool(_run_coordinator.call("configure_default", START_CELL, &"SE")):
		push_error("WW-02 typed state contracts failed validation.")
	_build_world_stream()
	_build_save_repository(save_path)
	_load_world_state()
	_stream_world()
	_robot_visual_position = grid_to_screen(_robot_grid)
	_build_camera()
	_build_world_layers()
	_build_avatar()
	_build_impact_effects()
	_build_impact_charge()
	_build_atmosphere()
	_build_hazards()
	_build_sandworms()
	_build_relay_contest()
	_build_mobile_controls()
	_build_interface()
	_build_chassis_feedback()
	_build_heat_haze()
	if _shutdown:
		_apply_shutdown_presentation(&"persistent_damage")
		_terminal_flow.call("settle_failure")
	call_deferred("_collect_scrap_near", _robot_grid, 0)
	_refresh_outpost_interface()
	_sync_avatar()
	queue_redraw()
	_run_coordinator.call("record_event", RuntimeIdsScript.EVENT_FIELD_READY)
	if web: JavaScriptBridge.eval("document.body.dataset.godotScene='field-ready';", true)
	print("[ISOMETRIC_MAP_READY]")


func _process(delta: float) -> void:
	var terminal: bool = _terminal_flow != null and bool(_terminal_flow.call("is_summary_visible"))
	var screen_direction: Vector2i = (
		Vector2i.ZERO if terminal else IsometricControlsScript.read_screen_direction()
	)
	var attack_pressed: bool = not terminal and IsometricControlsScript.is_attack_pressed()
	if attack_pressed and not _attack_was_pressed:
		attack()
	_attack_was_pressed = attack_pressed
	var drive_direction: Vector2i = (
		Vector2i.ZERO if _pending_impact_cell != INVALID_CELL else screen_direction
	)
	if _mobile_controls != null and bool(_mobile_controls.call("is_joystick_visible")):
		var mobile_drive: Vector2 = _mobile_controls.call("get_drive_vector") as Vector2
		var mobile_run: bool = bool(_mobile_controls.call("is_run_intended"))
		_update_drive_vector(mobile_drive, delta, mobile_run)
	else:
		update_drive(drive_direction, delta, IsometricControlsScript.is_run_pressed())
	_update_camera_follow(delta)
	_impact_flash = maxf(_impact_flash - delta, 0.0)
	_status_hold_time = maxf(_status_hold_time - delta, 0.0)
	if _effects != null:
		_effects.call("advance", delta)
	if _impact_charge != null:
		_impact_charge.call("advance", delta)
	if _chassis_feedback != null:
		_chassis_feedback.call("advance", delta)
	if _atmosphere != null:
		_atmosphere.call("advance", delta)
	var offset: Vector2 = _robot_visual_position - grid_to_screen(_robot_grid)
	var fractional: Vector2 = Vector2(
		offset.x / TILE_SIZE.x + offset.y / TILE_SIZE.y,
		offset.y / TILE_SIZE.y - offset.x / TILE_SIZE.x,
	)
	var player_grid_position: Vector2 = (
		Vector2(INVALID_CELL) if _shutdown else Vector2(_robot_grid) + fractional
	)
	_world_objects.call("advance_lava", player_grid_position, delta)
	var player_grid_velocity: Vector2 = Vector2(
		_velocity.x / TILE_SIZE.x + _velocity.y / TILE_SIZE.y,
		_velocity.y / TILE_SIZE.y - _velocity.x / TILE_SIZE.x,
	)
	if _hazards != null:
		(
			_hazards
			. call(
				"set_player_position",
				player_grid_position,
			)
		)
		_hazards.call("advance", delta)
		if _sandworms != null:
			_sandworms.call("set_player_position", player_grid_position, player_grid_velocity)
			_sandworms.call("set_outpost_linked", not _shutdown and _is_at_outpost())
			_sandworms.call("advance", delta)
			_worm_telegraph.call("sync_combat_snapshots", _sandworms.call("get_combat_snapshots"))
			_worm_telegraph.call("advance", delta)
	if _relay_contest != null:
		_relay_contest.call("set_player_position", player_grid_position)
		_relay_contest.call("advance", delta)
	if _world_objects != null:
		_world_objects.queue_redraw()
	if _terminal_flow != null:
		_terminal_flow.call("update_context", not _shutdown and _is_at_outpost())
	_refresh_outpost_interface()
	_sync_avatar()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func _draw() -> void:
	_draw_world_backdrop()
	for cell: Vector2i in _visible_cells:
		_draw_tile(cell)
	_draw_drive_vector()
	if _impact_flash > 0.0:
		draw_arc(_robot_visual_position, 74.0, 0.0, TAU, 40, AMBER, 5.0 * _impact_flash / 0.36)


func grid_to_screen(cell: Vector2i) -> Vector2:
	return _terrain_renderer.call("grid_to_screen", cell) as Vector2


func screen_to_grid(point: Vector2) -> Vector2i:
	var local: Vector2 = point - MAP_ORIGIN
	var grid_x: float = local.x / TILE_SIZE.x + local.y / TILE_SIZE.y
	var grid_y: float = local.y / TILE_SIZE.y - local.x / TILE_SIZE.x
	return Vector2i(roundi(grid_x), roundi(grid_y))


func is_walkable(cell: Vector2i) -> bool:
	return _world != null and bool(_world.call("is_walkable", cell))


func update_drive(screen_direction: Vector2i, delta: float, running: bool = false) -> bool:
	return _update_drive_vector(Vector2(screen_direction), delta, running)


func _update_drive_vector(screen_direction: Vector2, delta: float, running: bool = false) -> bool:
	if _shutdown:
		_velocity = Vector2.ZERO
		_is_moving = false
		_is_running = false
		return false
	var step_delta: float = minf(maxf(delta, 0.0), 0.05)
	var analog_direction: Vector2 = screen_direction.limit_length(1.0)
	var quantized_direction: Vector2i = Vector2i(
		0 if absf(analog_direction.x) < 0.28 else (1 if analog_direction.x > 0.0 else -1),
		0 if absf(analog_direction.y) < 0.28 else (1 if analog_direction.y > 0.0 else -1),
	)
	if _pending_impact_cell != INVALID_CELL:
		analog_direction = Vector2.ZERO
		quantized_direction = Vector2i.ZERO
	var has_input: bool = analog_direction.length() >= 0.05 and quantized_direction != Vector2i.ZERO
	_is_running = running and has_input
	var desired_velocity: Vector2 = Vector2.ZERO

	if has_input:
		_last_screen_direction = quantized_direction
		_facing = IsometricControlsScript.direction_name(quantized_direction)
		if not _can_move_screen_direction(quantized_direction):
			if not ModuleEffectsScript.try_ram(self, quantized_direction):
				_velocity = Vector2.ZERO
				_is_moving = false
				_update_status("VECTOR %s // BLOCKED // SCRAP %03d" % [_facing, _scrap_count])
				_sync_avatar()
				return false
		var maximum_speed: float = (
			WALK_SPEED * analog_direction.length() * (RUN_MULTIPLIER if running else 1.0)
		)
		desired_velocity = analog_direction.normalized() * maximum_speed
	var surface: StringName = _world.call("terrain_at", _robot_grid) as StringName
	_velocity = (
		SurfaceDriveScript
		. advance(
			_velocity,
			desired_velocity,
			WALK_SPEED * (RUN_MULTIPLIER if _is_running else 1.0),
			surface,
			step_delta,
		)
	)
	_is_moving = not _velocity.is_zero_approx()
	var moved: bool = _move_velocity(step_delta)
	if _impact_charge != null:
		_impact_charge.call("advance_drive", get_speed_ratio(), _is_running, step_delta)
	_update_drive_status()
	_sync_avatar()
	return moved


func _can_move_screen_direction(screen_direction: Vector2i) -> bool:
	var delta: Vector2i = IsometricControlsScript.screen_to_grid_delta(screen_direction)
	if delta == Vector2i.ZERO:
		return false
	return _can_transition(_robot_grid, _robot_grid + delta)


func attack() -> bool:
	if _shutdown or _avatar == null or _pending_impact_cell != INVALID_CELL:
		return false
	_velocity = Vector2.ZERO
	var screen_direction: Vector2i = IsometricControlsScript.facing_to_screen_direction(_facing)
	_pending_impact_band = int(_impact_charge.call("get_band")) if _impact_charge != null else 0
	var footprint: Array[Vector2i] = (
		_impact_charge.call("attack_footprint", _robot_grid, screen_direction, _pending_impact_band)
		if _impact_charge != null
		else [_robot_grid + IsometricControlsScript.screen_to_grid_delta(screen_direction)]
	)
	var targets: Dictionary = ImpactTargetingScript.scan(footprint, _sandworms, _destructible_rocks)
	_pending_impact_rock_cells = targets[&"rock_cells"] as Array[Vector2i]
	_pending_impact_worm_ids = targets[&"worm_ids"] as Array[int]
	_pending_impact_cells = footprint
	_pending_impact_cell = targets[&"target_cell"] as Vector2i
	_status_hold_time = 0.7
	var band_name: StringName = (
		_impact_charge.call("get_band_name", _pending_impact_band)
		if _impact_charge != null
		else &"CONTACT"
	)
	_update_status("IMPACT // %s WINDUP // SCRAP %03d" % [band_name, _scrap_count])
	_avatar.call("play_attack")
	return not _pending_impact_rock_cells.is_empty() or not _pending_impact_worm_ids.is_empty()


func _on_avatar_impact_frame() -> void:
	if _pending_impact_cell == INVALID_CELL:
		return
	var target: Vector2i = _pending_impact_cell
	var impact_band: int = _pending_impact_band
	var footprint: Array[Vector2i] = _pending_impact_cells.duplicate()
	var rock_cells: Array[Vector2i] = _pending_impact_rock_cells.duplicate()
	var worm_ids: Array[int] = _pending_impact_worm_ids.duplicate()
	_pending_impact_cell = INVALID_CELL
	_pending_impact_band = 0
	_pending_impact_cells.clear()
	_pending_impact_rock_cells.clear()
	_pending_impact_worm_ids.clear()
	_impact_flash = 0.36
	_status_hold_time = 0.7
	if footprint.is_empty():
		footprint = [target]
	if _impact_charge != null:
		_impact_charge.call("consume_attack")
		if impact_band > 0:
			var positions: Array[Vector2] = []
			for cell: Vector2i in footprint:
				positions.append(grid_to_screen(cell))
			_impact_charge.call("show_aftershock", positions, impact_band)
	if impact_band > 0 and _effects != null:
		_effects.call("emit_aftershock", grid_to_screen(target), target, impact_band)
	var worm_result: Dictionary = ImpactTargetingScript.hit_worms(
		_sandworms, worm_ids, impact_band, _run_coordinator
	)
	var worm_hits: int = int(worm_result[&"hits"])
	var worms_destroyed: int = int(worm_result[&"destroyed"])
	var last_worm_health: int = int(worm_result[&"last_health"])
	var rocks_broken: int = 0
	for rock_cell: Vector2i in rock_cells:
		if not _break_rock(rock_cell):
			continue
		rocks_broken += 1
		if _effects != null:
			_effects.call("emit_rock_impact", grid_to_screen(rock_cell), rock_cell)
	if rocks_broken > 0 and _collect_scrap_near(_robot_grid) <= 0:
		_save_world_state()
	if worm_hits > 0:
		var result: String = "DESTROYED" if worms_destroyed > 0 else "HIT"
		var health_text: String = "" if worm_hits > 1 else " // HP %d/4" % last_worm_health
		var enemy_label: String = str(_sandworms.call("_get_enemy_label", worm_ids[0]))
		var band_name: StringName = _impact_charge.call("get_band_name", impact_band)
		_update_status(
			"%s // %s %s x%d%s" % [band_name, enemy_label, result, worm_hits, health_text]
		)
		return
	if rocks_broken > 0:
		_update_status("IMPACT // ROCK SALVAGED x%d // SCRAP %03d" % [rocks_broken, _scrap_count])
		return
	_update_status("IMPACT // CLEAR // SCRAP %03d" % _scrap_count)


func place_destructible_rock(cell: Vector2i) -> bool:
	if _world == null or not bool(_world.call("place_rock", cell, _robot_grid)):
		return false
	_refresh_haze_mask()
	_save_world_state()
	queue_redraw()
	return true


func _break_rock(cell: Vector2i) -> bool:
	if _world == null or not bool(_world.call("break_rock", cell)):
		return false
	_refresh_haze_mask()
	queue_redraw()
	return true


func _place_scrap(cell: Vector2i, amount: int = 1) -> bool:
	if _world == null or not bool(_world.call("place_scrap", cell, amount)):
		return false
	queue_redraw()
	return true


func has_destructible_rock(cell: Vector2i) -> bool:
	return bool(_destructible_rocks.get(cell, false))


func has_scrap(cell: Vector2i) -> bool:
	return int(_scrap.get(cell, 0)) > 0


func get_scrap_count() -> int:
	return _scrap_count


func _get_chassis() -> int:
	return _chassis


func _apply_chassis_damage(amount: int, source: StringName = &"hazard") -> int:
	var adjusted: int = ModuleEffectsScript.mitigate_damage(
		_run_coordinator, amount, source, _is_running
	)
	var damage: int = mini(adjusted, _chassis)
	if damage <= 0:
		return 0
	_chassis -= damage
	var lethal: bool = _chassis <= 0
	if _effects != null:
		_effects.call("emit_chassis_damage", _robot_visual_position, damage)
	if _chassis_feedback != null:
		_chassis_feedback.call(
			"show_damage", damage, source, lethal, 0.6 if adjusted < amount else 1.0
		)
	_status_hold_time = 0.7
	_update_status(
		(
			"%s CONTACT -%02d // CHASSIS %03d/%03d"
			% [String(source).to_upper(), damage, _chassis, MAX_CHASSIS]
		)
	)
	_refresh_outpost_interface()
	if lethal:
		_enter_shutdown(source)
	_save_world_state()
	return damage


func _enter_shutdown(source: StringName) -> void:
	if _shutdown:
		return
	_shutdown = true
	_apply_shutdown_presentation(source)
	_save_world_state()
	_terminal_flow.call("settle_failure")


func _apply_shutdown_presentation(source: StringName) -> void:
	_velocity = Vector2.ZERO
	_is_moving = false
	_is_running = false
	_pending_impact_cell = INVALID_CELL
	_pending_impact_band = 0
	_pending_impact_cells.clear()
	_pending_impact_rock_cells.clear()
	_pending_impact_worm_ids.clear()
	if _mobile_controls != null:
		_mobile_controls.call("set_controls_enabled", false)
	_status_hold_time = INF
	if _hazards != null:
		_hazards.call("set_player_cell", INVALID_CELL)
	if _chassis_feedback != null:
		_chassis_feedback.call("enter_shutdown", source)
	_update_status("CARDINAL SHUTDOWN // CHASSIS 000 // ESC: RETURN")
	_refresh_outpost_interface()


func _is_at_outpost() -> bool:
	return bool(_outposts.get(_robot_grid, false))


func _repair_chassis() -> bool:
	var cost: int = RunModifierEffectsScript.repair_cost(
		REPAIR_COST, _run_value(&"active_modifier_id", &"modifier.neutral")
	)
	if _shutdown or not _is_at_outpost() or _scrap_count < cost or _chassis >= MAX_CHASSIS:
		return false
	var scrap_before: int = _scrap_count
	var chassis_before: int = _chassis
	_scrap_count -= cost
	_chassis = mini(_chassis + REPAIR_AMOUNT, MAX_CHASSIS)
	if not _save_world_state():
		_scrap_count = scrap_before
		_chassis = chassis_before
		return false
	_status_hold_time = 1.0
	_update_status("OUTPOST REPAIR // CHASSIS %03d // SCRAP %03d" % [_chassis, _scrap_count])
	_refresh_outpost_interface()
	return true


func get_robot_grid() -> Vector2i:
	return _robot_grid


func place_robot(cell: Vector2i) -> bool:
	if _shutdown or not is_walkable(cell):
		return false
	_robot_grid = cell
	_robot_visual_position = grid_to_screen(cell)
	_velocity = Vector2.ZERO
	_is_moving = false
	_is_running = false
	_stream_world()
	_collect_scrap_near(cell)
	if _hazards != null:
		_hazards.call("set_player_cell", cell)
	if _sandworms != null:
		_sandworms.call("set_player_position", Vector2(cell))
		_sandworms.call("set_outpost_linked", _is_at_outpost())
	if _relay_contest != null:
		_relay_contest.call("set_player_position", Vector2(cell))
	_refresh_outpost_interface()
	_update_drive_status()
	_sync_avatar()
	queue_redraw()
	return true


func get_robot_position() -> Vector2:
	return _robot_visual_position


func get_velocity() -> Vector2:
	return _velocity


func get_speed_ratio() -> float:
	return _velocity.length() / WALK_SPEED


func _get_impact_charge() -> float:
	return float(_impact_charge.call("get_charge")) if _impact_charge != null else 0.0


func _set_impact_charge(value: float) -> void:
	if _impact_charge != null:
		_impact_charge.call("set_charge", value)
	_refresh_outpost_interface()


func _get_completed_relays() -> int:
	return int(_run_value(&"completed_relays", 0))


func _get_relay_cell() -> Vector2i:
	var relay: Node2D = _relay_contest
	return relay.call("get_relay_cell") as Vector2i if relay != null else INVALID_CELL


func get_facing() -> StringName:
	return _facing


func get_grid_size() -> Vector2i:
	return InfiniteWorldScript.PLAYABLE_SIZE


func get_avatar() -> Node2D:
	return _avatar


func get_camera_position() -> Vector2:
	return _camera.position if _camera != null else Vector2.ZERO


func get_camera_target() -> Vector2:
	var lead: Vector2 = (_velocity * CAMERA_LOOK_AHEAD_SECONDS).limit_length(CAMERA_MAX_LEAD)
	return _robot_visual_position + lead


func get_status_text() -> String:
	return str(_hud.call("get_status_text")) if _hud != null else ""


func _exit_tree() -> void:
	if _chassis_feedback != null:
		_chassis_feedback.call("prepare_for_shutdown")
	_save_world_state()


func _build_save_repository(path: String) -> void:
	_state_store = SaveRepositoryScript.new() as RefCounted
	var build_id: String = str(
		ProjectSettings.get_setting("application/config/version", "development")
	)
	if not bool(_state_store.call("configure", path, _world, build_id)):
		push_error("WW-03 save repository failed configuration.")


func _load_world_state() -> bool:
	if _state_store == null:
		return false
	var envelope: Dictionary = _state_store.call("load_state") as Dictionary
	if envelope.is_empty():
		return false
	if not bool(
		_run_coordinator.call(
			"restore_persisted_state", envelope[&"active_run"], envelope[&"profile"]
		)
	):
		push_error("Validated save state could not be applied.")
		return false
	if not bool(_world.call("is_valid_cell", _robot_grid)):
		_robot_grid = START_CELL
	var world_snapshot: Dictionary = (envelope[&"world"] as Dictionary).duplicate(true)
	world_snapshot[&"schema"] = 2
	_world.call("apply_snapshot", world_snapshot)
	return true


func _save_world_state() -> bool:
	if _state_store == null:
		return false
	if bool(_state_store.call("is_write_blocked")):
		return false
	var saved: bool = bool(
		(
			_state_store
			. call(
				"save_state",
				_world.call("make_snapshot"),
				_run_coordinator.call("get_run_snapshot"),
				_run_coordinator.call("get_profile_snapshot"),
			)
		)
	)
	if not saved:
		push_warning("World save failed: %s" % str(_state_store.call("get_last_error")))
	return saved


func _update_camera_follow(delta: float) -> void:
	if _camera == null:
		return
	var blend: float = 1.0 - exp(-CAMERA_RESPONSE * maxf(delta, 0.0))
	_camera.position = _camera.position.lerp(get_camera_target(), blend)


func _move_velocity(delta: float) -> bool:
	if _velocity.is_zero_approx() or delta <= 0.0:
		return false
	var candidate: Vector2 = _robot_visual_position + _velocity * delta
	var candidate_grid: Vector2i = screen_to_grid(candidate)
	if candidate_grid != _robot_grid and not _can_transition(_robot_grid, candidate_grid):
		_velocity = Vector2.ZERO
		_is_moving = false
		_impact_flash = 0.12
		return false
	_robot_visual_position = candidate
	if candidate_grid != _robot_grid:
		_robot_grid = candidate_grid
		_stream_world()
		_collect_scrap_near(_robot_grid)
	return true


func _can_transition(from: Vector2i, target: Vector2i) -> bool:
	if not is_walkable(target):
		return false
	var delta: Vector2i = target - from
	if absi(delta.x) > 1 or absi(delta.y) > 1:
		return false
	if delta.x != 0 and delta.y != 0:
		return is_walkable(from + Vector2i(delta.x, 0)) and is_walkable(from + Vector2i(0, delta.y))
	return true


func _collect_scrap_near(cell: Vector2i, radius_cells: int = RESOURCE_MAGNET_RADIUS_CELLS) -> int:
	if _shutdown:
		return 0
	var total: int = ResourceMagnetScript.collect_and_emit(
		_world,
		_effects,
		Callable(self, "grid_to_screen"),
		_robot_visual_position,
		cell,
		radius_cells,
	)
	if total <= 0:
		return 0
	_scrap_count += total
	_status_hold_time = 0.9
	_refresh_outpost_interface()
	_save_world_state()
	_update_status("RESOURCE MAGNET +%d // TOTAL %03d" % [total, _scrap_count])
	queue_redraw()
	return total


func _build_world_stream() -> void:
	_world = InfiniteWorldScript.new() as RefCounted
	_terrain_renderer = TerrainRendererScript.new() as RefCounted
	_terrain_renderer.call(
		"configure", _terrain, _elevation, _terrain_textures, TILE_SIZE, MAP_ORIGIN
	)
	(
		_world
		. call(
			"configure",
			_terrain,
			_elevation,
			_blocked,
			_destructible_rocks,
			_scrap,
			_outposts,
		)
	)


func _stream_world() -> void:
	if _world == null:
		return
	_world.call("stream_around", _robot_grid)
	_visible_cells = _world.call("visible_cells", _robot_grid) as Array[Vector2i]
	if _world_objects != null:
		_world_objects.call("set_visible_cells", _visible_cells)
	if _terrain_haze != null:
		_terrain_haze.call("set_visible_cells", _visible_cells)
	_refresh_haze_mask()
	queue_redraw()


func _run_value(key: StringName, fallback: Variant) -> Variant:
	if _run_coordinator == null:
		return fallback
	var value: Variant = _run_coordinator.call("get_run_value", key)
	return fallback if value == null else value


func _set_run_value(key: StringName, value: Variant) -> void:
	if _run_coordinator != null:
		_run_coordinator.call("set_run_value", key, value)


func _build_world_layers() -> void:
	_object_layer = CanvasLayer.new()
	_object_layer.name = "WorldObjectLayer"
	_object_layer.layer = 2
	_object_layer.follow_viewport_enabled = true
	add_child(_object_layer)
	_effects_layer = CanvasLayer.new()
	_effects_layer.name = "WorldEffectsLayer"
	_effects_layer.layer = 3
	_effects_layer.follow_viewport_enabled = true
	add_child(_effects_layer)
	_world_objects = WorldObjectsScript.new() as Node2D
	_world_objects.name = "WorldObjects"
	_object_layer.add_child(_world_objects)
	(
		_world_objects
		. call(
			"configure",
			_destructible_rocks,
			_scrap,
			_outposts,
			Callable(self, "grid_to_screen"),
			Callable(self, "_save_world_state"),
		)
	)
	_world_objects.call("bind_world", _world, Callable(self, "_on_hazard_damage"))
	_world_objects.call("set_visible_cells", _visible_cells)


func _build_avatar() -> void:
	_avatar = CardinalAvatarScript.new() as Node2D
	_avatar.name = "CardinalAvatar"
	_avatar.position = _robot_visual_position
	_avatar.z_index = 20
	_avatar.connect("impact_frame", Callable(self, "_on_avatar_impact_frame"))
	_object_layer.add_child(_avatar)


func _build_camera() -> void:
	_camera = ResponsiveCameraScript.new() as Camera2D
	_camera.name = "FollowCamera"
	_camera.position = _robot_visual_position
	_camera.enabled = true
	_camera.ignore_rotation = true
	add_child(_camera)


func _build_impact_effects() -> void:
	_effects = ImpactEffectsScript.new() as Node2D
	_effects.name = "ImpactEffects"
	_effects.z_index = 30
	_effects.call("bind_camera", _camera)
	_effects_layer.add_child(_effects)


func _build_impact_charge() -> void:
	_impact_charge = ImpactChargeScript.new() as Node2D
	_impact_charge.name = "ImpactCharge"
	_impact_charge.z_index = 19
	_impact_charge.call("set_visual_position", _robot_visual_position)
	_object_layer.add_child(_impact_charge)


func _build_chassis_feedback() -> void:
	_chassis_feedback = ChassisFeedbackScript.new() as CanvasLayer
	_chassis_feedback.name = "ChassisFeedback"
	add_child(_chassis_feedback)
	_chassis_feedback.call("bind_avatar", _avatar)


func _build_atmosphere() -> void:
	_atmosphere = DesertAtmosphereScript.new() as Node2D
	_atmosphere.name = "DesertAtmosphere"
	_atmosphere.z_index = 50
	add_child(_atmosphere)


func _build_hazards() -> void:
	_hazards = DesertHazardsScript.new() as Node2D
	_hazards.name = "DesertHazards"
	_hazards.z_index = 40
	_hazards.call("configure", TILE_SIZE, MAP_ORIGIN, _world.call("get_cull_radius"))
	_hazards.call("set_player_cell", _robot_grid)
	_hazards.connect("damage_tick", Callable(self, "_on_hazard_damage"))
	_effects_layer.add_child(_hazards)


func _on_hazard_damage(amount: int, source: StringName) -> void:
	_apply_chassis_damage(amount, source)


func _build_sandworms() -> void:
	_sandworms = SandwormsScript.new() as Node2D
	_sandworms.name = "Sandworms"
	_sandworms.z_index = 18
	_sandworms.call("configure", TILE_SIZE, MAP_ORIGIN, null, _world)
	_sandworms.call("set_player_position", Vector2(_robot_grid))
	_sandworms.call("set_outpost_linked", _is_at_outpost())
	_sandworms.connect("damage_tick", Callable(self, "_on_hazard_damage"))
	_object_layer.add_child(_sandworms)
	_world_objects.call("build_run_pickups", _world, _run_coordinator, _sandworms)
	_world_objects.call("build_encounter_director", _world, _run_coordinator, _sandworms, _hazards)
	_worm_telegraph = WormTelegraphScript.new() as Node2D
	_worm_telegraph.name = "WormTelegraph"
	_worm_telegraph.z_index = 16
	_worm_telegraph.call("configure", TILE_SIZE, MAP_ORIGIN)
	_object_layer.add_child(_worm_telegraph)


func _build_relay_contest() -> void:
	_relay_contest = RelayContestScript.new() as Node2D
	_relay_contest.name = "RelayContest"
	_relay_contest.z_index = 17
	_relay_contest.call("configure", _run_coordinator, _world, TILE_SIZE, MAP_ORIGIN)
	_relay_contest.call("set_player_position", Vector2(_robot_grid))
	_relay_contest.connect("link_started", Callable(self, "_on_relay_link_started"))
	_relay_contest.connect("completed", Callable(self, "_on_relay_completed"))
	_object_layer.add_child(_relay_contest)


func _on_relay_link_started(relay_cell: Vector2i) -> void:
	_status_hold_time = 1.0
	_update_status("RELAY CONTEST // SIGNAL LOCK %d,%d" % [relay_cell.x, relay_cell.y])


func _on_relay_completed(_relay_cell: Vector2i) -> void:
	_run_coordinator.call("apply_run_event", RuntimeIdsScript.EVENT_RELAY_COMPLETED)
	if _sandworms != null:
		_sandworms.call("disperse_all")
	_status_hold_time = 1.4
	_update_status("RELAY LINKED // ALERT %d // NEXT SIGNAL" % _get_completed_relays())
	_save_world_state()


func _build_heat_haze() -> void:
	_terrain_haze = TerrainHazeScript.new() as Node2D
	_terrain_haze.name = "TerrainHaze"
	_terrain_haze.call("configure", _terrain, TILE_SIZE, MAP_ORIGIN)
	add_child(_terrain_haze)
	_terrain_haze.call("set_visible_cells", _visible_cells)


func _refresh_haze_mask() -> void:
	if _terrain_haze != null:
		_terrain_haze.call("refresh_mask")


func _sync_avatar() -> void:
	if _avatar == null:
		return
	_avatar.position = _robot_visual_position
	_avatar.call("set_motion", _facing, _is_moving, get_speed_ratio())
	if _impact_charge != null:
		_impact_charge.call("set_visual_position", _robot_visual_position)


func _draw_world_backdrop() -> void:
	var backdrop_origin: Vector2 = _robot_visual_position - Vector2(2000.0, 1500.0)
	draw_rect(Rect2(backdrop_origin, Vector2(4000.0, 3000.0)), Color("24170f"))


func _draw_tile(cell: Vector2i) -> void:
	_terrain_renderer.call("draw_tile", self, cell)


func _draw_drive_vector() -> void:
	var vector: Vector2 = Vector2(_last_screen_direction).normalized()
	var start: Vector2 = _robot_visual_position + Vector2(0.0, 15.0)
	var finish: Vector2 = start + vector * (36.0 + minf(_velocity.length() * 0.12, 30.0))
	draw_line(start, finish, TEAL, 4.0)
	draw_circle(finish, 5.0, AMBER if _is_running else TEAL)


func _build_interface() -> void:
	_hud = FieldHudScript.new() as CanvasLayer
	_hud.name = "FieldHUD"
	_hud.connect("repair_requested", Callable(self, "_repair_chassis"))
	_hud.call("configure_refit", _run_coordinator, Callable(self, "_save_world_state"))
	add_child(_hud)
	_terminal_flow = RunTerminalFlowScript.new() as CanvasLayer
	add_child(_terminal_flow)
	_terminal_flow.call(
		"configure",
		_run_coordinator,
		Callable(self, "_save_world_state"),
		func() -> void: get_tree().reload_current_scene(),
		_mobile_controls
	)


func _build_mobile_controls() -> void:
	_mobile_controls = MobileControlsScript.new() as CanvasLayer
	_mobile_controls.name = "MobileControls"
	_mobile_controls.connect("smash_pressed", Callable(self, "attack"))
	add_child(_mobile_controls)


func _refresh_outpost_interface() -> void:
	if _hud == null or _relay_contest == null:
		return
	var state: RefCounted = (
		FieldUIBuilderScript
		. build(
			_run_coordinator,
			_relay_contest,
			_impact_charge,
			_mobile_controls,
			_chassis,
			MAX_CHASSIS,
			_scrap_count,
			_context_event,
			_shutdown,
			_is_at_outpost(),
			_facing,
			get_speed_ratio(),
			_robot_grid,
		)
	)
	if state != null:
		_hud.call("apply_state", state)


func _update_drive_status() -> void:
	if _status_hold_time > 0.0:
		return
	_update_status("DRIVE %s // SPEED %03d%%" % [_facing, roundi(get_speed_ratio() * 100.0)])


func _update_status(text: String) -> void:
	_context_event = text.left(96)
	_refresh_outpost_interface()
