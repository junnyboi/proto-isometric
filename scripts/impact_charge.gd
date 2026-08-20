extends Node2D

signal band_crossed(band: int)

const IsometricControlsScript: GDScript = preload("res://scripts/isometric_controls.gd")

const LOW_BAND_MAX: float = 0.4
const MID_BAND_MAX: float = 0.8
const CHARGE_SPEED_THRESHOLD: float = 0.55
const WALK_GAIN_PER_SECOND: float = 0.16
const RUN_GAIN_PER_SECOND: float = 0.25
const IDLE_DECAY_PER_SECOND: float = 0.045
const WORN_PLATES_GAIN_MULTIPLIER: float = 1.15
const ATTACK_ARC_DEGREES: float = 150.0
const ATTACK_ARC_RADIUS_CELLS: int = 2
const AMBER: Color = Color("f5a62d")
const TEAL: Color = Color("4eb6aa")
const SCREEN_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
]

var _charge: float = 0.0
var _band: int = 0
var _visual_position: Vector2 = Vector2.ZERO
var _aftershock_cells: Array[Vector2] = []
var _aftershock_time: float = 0.0
var _aftershock_band: int = 0
var _gain_multiplier: float = WORN_PLATES_GAIN_MULTIPLIER


func advance_drive(speed_ratio: float, running: bool, delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	if speed_ratio >= CHARGE_SPEED_THRESHOLD:
		var gain: float = (
			(RUN_GAIN_PER_SECOND if running else WALK_GAIN_PER_SECOND) * _gain_multiplier
		)
		set_charge(_charge + gain * step)
	elif speed_ratio <= 0.08:
		set_charge(_charge - IDLE_DECAY_PER_SECOND * step)


func advance(delta: float) -> void:
	_aftershock_time = maxf(_aftershock_time - maxf(delta, 0.0), 0.0)
	if _aftershock_time <= 0.0:
		_aftershock_cells.clear()
	queue_redraw()


func set_charge(value: float) -> void:
	var previous_band: int = _band
	_charge = clampf(value, 0.0, 1.0)
	_band = charge_band(_charge)
	if _band > previous_band:
		for crossed_band: int in range(previous_band + 1, _band + 1):
			band_crossed.emit(crossed_band)
	queue_redraw()


func get_charge() -> float:
	return _charge


func set_gain_multiplier(value: float) -> bool:
	if not is_finite(value) or value < 1.0 or value > 2.0:
		return false
	_gain_multiplier = value
	return true


func get_gain_multiplier() -> float:
	return _gain_multiplier


func get_band() -> int:
	return _band


func consume_attack() -> int:
	var consumed_band: int = _band
	set_charge(0.0)
	return consumed_band


func set_visual_position(value: Vector2) -> void:
	_visual_position = value


func show_aftershock(cell_positions: Array[Vector2], band: int) -> void:
	_aftershock_cells = cell_positions.duplicate()
	_aftershock_band = clampi(band, 0, 2)
	_aftershock_time = 0.34 if _aftershock_band >= 2 else 0.24
	queue_redraw()


func footprint(origin: Vector2i, screen_direction: Vector2i, band: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var center_delta: Vector2i = IsometricControlsScript.screen_to_grid_delta(screen_direction)
	if center_delta == Vector2i.ZERO:
		return result
	result.append(origin + center_delta)
	if band == 1:
		result.append(origin + center_delta * 2)
	elif band >= 2:
		var direction_index: int = SCREEN_DIRECTIONS.find(screen_direction)
		if direction_index >= 0:
			for offset: int in [-1, 1]:
				var flank_screen: Vector2i = SCREEN_DIRECTIONS[posmod(direction_index + offset, 8)]
				result.append(origin + IsometricControlsScript.screen_to_grid_delta(flank_screen))
	return result


func attack_footprint(
	origin: Vector2i,
	screen_direction: Vector2i,
	band: int,
) -> Array[Vector2i]:
	var result: Array[Vector2i] = footprint(origin, screen_direction, band)
	var direction_index: int = SCREEN_DIRECTIONS.find(screen_direction)
	if direction_index < 0:
		return result
	var half_arc: float = ATTACK_ARC_DEGREES * 0.5
	var direction_step: float = 360.0 / float(SCREEN_DIRECTIONS.size())
	for offset: int in range(-SCREEN_DIRECTIONS.size() / 2, SCREEN_DIRECTIONS.size() / 2 + 1):
		if absf(float(offset) * direction_step) > half_arc:
			continue
		var arc_direction: Vector2i = SCREEN_DIRECTIONS[posmod(direction_index + offset, 8)]
		var arc_delta: Vector2i = IsometricControlsScript.screen_to_grid_delta(arc_direction)
		for distance: int in range(1, ATTACK_ARC_RADIUS_CELLS + 1):
			var cell: Vector2i = origin + arc_delta * distance
			if cell not in result:
				result.append(cell)
	return result


func get_band_name(band: int = _band) -> StringName:
	if band >= 2:
		return &"impact.band.aftershock"
	if band == 1:
		return &"impact.band.shock_line"
	return &"impact.band.contact"


static func charge_band(value: float) -> int:
	if value >= MID_BAND_MAX:
		return 2
	if value >= LOW_BAND_MAX:
		return 1
	return 0


func _draw() -> void:
	if _charge >= LOW_BAND_MAX:
		var intensity: float = inverse_lerp(LOW_BAND_MAX, 1.0, _charge)
		var glow: Color = AMBER
		glow.a = 0.28 + intensity * 0.42
		draw_arc(_visual_position, 49.0 + intensity * 7.0, -PI * 0.85, PI * 0.1, 20, glow, 3.0)
		draw_arc(_visual_position, 49.0 + intensity * 7.0, PI * 0.15, PI * 1.1, 20, glow, 3.0)
	if _aftershock_time <= 0.0:
		return
	var ratio: float = clampf(
		_aftershock_time / (0.34 if _aftershock_band >= 2 else 0.24), 0.0, 1.0
	)
	for cell_position: Vector2 in _aftershock_cells:
		var color: Color = AMBER if _aftershock_band >= 2 else TEAL
		color.a = ratio * 0.78
		draw_arc(cell_position, 25.0 + (1.0 - ratio) * 38.0, 0.0, TAU, 24, color, 5.0 * ratio)
