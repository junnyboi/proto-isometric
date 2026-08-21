extends Node2D

const OutpostVisualsScript: GDScript = preload("res://scripts/outpost_visuals.gd")

const UPDATE_HZ: float = 12.0
const UPDATE_INTERVAL_SECONDS: float = 1.0 / UPDATE_HZ
const PULSE_PERIOD_SECONDS: float = 2.8
const TEAL: Color = Color("55f5e6")
const PALE_TEAL: Color = Color("c8fff8")
const AMBER: Color = Color("ffc253")
const QUALITY_STRENGTH: Dictionary = {
	&"full": 1.0,
	&"reduced": 0.72,
	&"minimal": 0.46,
}

var _outposts: Dictionary = {}
var _visible_cells: Array[Vector2i] = []
var _grid_to_screen: Callable
var _time: float = 0.0
var _update_accumulator: float = 0.0
var _vfx_intensity: float = 1.0
var _effects_quality: StringName = &"full"
var _redraw_request_count: int = 0


func _ready() -> void:
	call_deferred("_bind_accessibility")
	_sync_processing()


func configure(
	outposts: Dictionary,
	grid_to_screen: Callable,
) -> bool:
	if not grid_to_screen.is_valid():
		return false
	_outposts = outposts
	_grid_to_screen = grid_to_screen
	_sync_processing()
	_request_redraw()
	return true


func set_visible_cells(cells: Array[Vector2i]) -> void:
	_visible_cells = cells
	_sync_processing()
	_request_redraw()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if get_visible_beacon_count() <= 0 or get_effect_strength() <= 0.0:
		return
	var safe_delta: float = maxf(delta, 0.0)
	_time = fposmod(_time + safe_delta, PULSE_PERIOD_SECONDS * 32.0)
	_update_accumulator += safe_delta
	if _update_accumulator < UPDATE_INTERVAL_SECONDS:
		return
	_update_accumulator = fmod(_update_accumulator, UPDATE_INTERVAL_SECONDS)
	_request_redraw()


func get_visible_beacon_count() -> int:
	var count: int = 0
	for value: Variant in _outposts:
		var cell: Vector2i = value as Vector2i
		if bool(_outposts[cell]) and cell in _visible_cells:
			count += 1
	return count


func get_effect_strength() -> float:
	return _vfx_intensity * float(QUALITY_STRENGTH.get(_effects_quality, 1.0))


func get_redraw_request_count() -> int:
	return _redraw_request_count


func _get_animation_snapshot(cell: Vector2i) -> Dictionary:
	var phase: float = _phase_for(cell)
	return {
		&"anchor": _beacon_anchor(cell),
		&"pulse": 0.5 + 0.5 * sin(phase),
		&"sweep": fposmod(phase, TAU),
		&"strength": get_effect_strength(),
	}


func _apply_preferences(snapshot: Dictionary) -> void:
	_vfx_intensity = clampf(float(snapshot.get(&"vfx_intensity", 1.0)), 0.0, 1.0)
	var quality: StringName = StringName(snapshot.get(&"effects_quality", &"full"))
	_effects_quality = quality if QUALITY_STRENGTH.has(quality) else &"full"
	_update_accumulator = 0.0
	_sync_processing()
	_request_redraw()


func _bind_accessibility() -> void:
	var panel: Node = get_tree().get_first_node_in_group("accessibility_panel")
	if panel == null:
		return
	_apply_preferences(panel.call("get_preferences") as Dictionary)
	panel.connect("preferences_changed", _apply_preferences)


func _sync_processing() -> void:
	set_process(get_visible_beacon_count() > 0 and get_effect_strength() > 0.0)


func _request_redraw() -> void:
	_redraw_request_count += 1
	queue_redraw()


func _draw() -> void:
	var strength: float = get_effect_strength()
	if strength <= 0.0 or not _grid_to_screen.is_valid():
		return
	for value: Variant in _outposts:
		var cell: Vector2i = value as Vector2i
		if not bool(_outposts[cell]) or cell not in _visible_cells:
			continue
		_draw_beacon(cell, strength)


func _draw_beacon(cell: Vector2i, strength: float) -> void:
	var anchor: Vector2 = _beacon_anchor(cell)
	var phase: float = _phase_for(cell)
	var pulse: float = 0.5 + 0.5 * sin(phase)
	var sweep: float = fposmod(phase, TAU)
	var radius: float = 10.0 + pulse * 3.0
	var beam_height: float = 20.0 + pulse * 8.0
	var beam_color: Color = Color(TEAL, (0.16 + pulse * 0.09) * strength)
	var halo_color: Color = Color(TEAL, (0.055 + pulse * 0.035) * strength)
	var ring_color: Color = Color(PALE_TEAL, (0.42 + pulse * 0.18) * strength)
	draw_circle(anchor, radius + 8.0, halo_color)
	draw_circle(anchor, 4.4 + pulse * 1.2, Color(TEAL, 0.22 * strength))
	draw_line(anchor, anchor + Vector2(0.0, -beam_height), beam_color, 2.0, true)
	draw_line(
		anchor + Vector2(0.0, -beam_height),
		anchor + Vector2(0.0, -beam_height - 5.0),
		Color(PALE_TEAL, 0.11 * strength),
		1.0,
		true,
	)
	draw_arc(anchor, radius, sweep, sweep + PI * 1.32, 24, ring_color, 1.5, true)
	draw_circle(anchor, 1.8, Color(PALE_TEAL, 0.88 * strength))
	var glint_angle: float = -sweep * 0.62
	var glint: Vector2 = anchor + Vector2.from_angle(glint_angle) * (radius + 2.0)
	draw_circle(glint, 1.4, Color(AMBER, (0.48 + pulse * 0.24) * strength))


func _beacon_anchor(cell: Vector2i) -> Vector2:
	var center: Vector2 = _grid_to_screen.call(cell) as Vector2
	var kind: StringName = OutpostVisualsScript.kind_for(cell)
	return center + OutpostVisualsScript.beacon_offset_for(kind)


func _phase_for(cell: Vector2i) -> float:
	var cell_offset: float = float(posmod(cell.x * 17 + cell.y * 31, 19)) / 19.0 * TAU
	return _time * TAU / PULSE_PERIOD_SECONDS + cell_offset
