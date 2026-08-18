extends Node2D

signal drop_placed(drop_id: StringName, cell: Vector2i)
signal drop_collected(cores: int, scrap: int)

const RunModifierEffectsScript: GDScript = preload("res://scripts/run_modifier_effects.gd")
const CORE_TEXTURE: Texture2D = preload("res://assets/vfx/pickups/worm_core.png")
const CORE_PER_WORM: int = 1
const SCRAP_PER_WORM: int = 2
const MAX_ACTIVE_DROPS: int = 64
const SEARCH_OFFSETS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
	Vector2i(0, -2),
	Vector2i(2, 0),
	Vector2i(0, 2),
	Vector2i(-2, 0),
]
const TEAL: Color = Color("4eb6aa")
const AMBER: Color = Color("f5a62d")

var _world: RefCounted
var _grid_to_screen: Callable
var _coordinator: RefCounted
var _save_callback: Callable
var _drops: Array[Dictionary] = []
var _handled_worm_ids: Dictionary = {}
var _next_drop_sequence: int = 1
var _pulse_time: float = 0.0
var _visible_drop_count: int = 0


func configure(
	world: RefCounted,
	grid_to_screen: Callable,
	coordinator: RefCounted = null,
	save_callback: Callable = Callable(),
) -> bool:
	if world == null or not world.has_method("is_walkable") or not grid_to_screen.is_valid():
		return false
	_world = world
	_grid_to_screen = grid_to_screen
	_coordinator = coordinator
	_save_callback = save_callback
	_sync_drops()
	return true


func bind_worms(worms: Node2D) -> bool:
	if worms == null or not worms.has_signal("defeated"):
		return false
	var callback: Callable = Callable(self, "_on_worm_defeated")
	if not worms.is_connected("defeated", callback):
		worms.connect("defeated", callback)
	return true


func _process(delta: float) -> void:
	_pulse_time += maxf(delta, 0.0)
	_collect_player_cell()
	queue_redraw()


func clear() -> void:
	_drops.clear()
	_handled_worm_ids.clear()
	_next_drop_sequence = 1
	queue_redraw()


func get_drop_count() -> int:
	return _drops.size()


func get_visible_drop_count() -> int:
	return _visible_drop_count


func get_total_cores() -> int:
	var total: int = 0
	for drop: Dictionary in _drops:
		total += int(drop[&"cores"])
	return total


func get_total_scrap() -> int:
	var total: int = 0
	for drop: Dictionary in _drops:
		total += int(drop[&"scrap"])
	return total


func get_snapshot() -> Array[Dictionary]:
	return _drops.duplicate(true)


func _on_worm_defeated(worm_id: int, position: Vector2) -> void:
	if _handled_worm_ids.has(worm_id) or _drops.size() >= MAX_ACTIVE_DROPS:
		return
	_handled_worm_ids[worm_id] = true
	var player_cell: Vector2i = _get_player_cell()
	var cell: Vector2i = _find_drop_cell(
		Vector2i(roundi(position.x), roundi(position.y)), player_cell
	)
	if not bool(_world.call("is_walkable", cell)) or cell == player_cell:
		return
	var drop: Dictionary = _place_drop(cell, worm_id)
	if drop.is_empty():
		return
	_sync_drops()
	_commit_save()
	drop_placed.emit(StringName(str(drop[&"drop_id"])), cell)
	queue_redraw()


func _place_drop(cell: Vector2i, worm_id: int) -> Dictionary:
	if _coordinator != null:
		var modifier: StringName = (
			_coordinator.call("get_run_value", &"active_modifier_id") as StringName
		)
		var cores: int = RunModifierEffectsScript.core_reward(CORE_PER_WORM, worm_id, modifier)
		return (
			_coordinator.call("_place_run_drop", cell, cores, SCRAP_PER_WORM, worm_id) as Dictionary
		)
	var drop: Dictionary = {
		&"drop_id": "drop.worm.%06d" % _next_drop_sequence,
		&"source_worm_id": worm_id,
		&"cell": [cell.x, cell.y],
		&"cores": CORE_PER_WORM,
		&"scrap": SCRAP_PER_WORM,
	}
	_next_drop_sequence += 1
	_drops.append(drop)
	return drop.duplicate(true)


func _collect_player_cell() -> void:
	if _coordinator == null:
		return
	var cell: Vector2i = _get_player_cell()
	var collected: Dictionary = _coordinator.call("_collect_run_drop", cell) as Dictionary
	if collected.is_empty():
		return
	_sync_drops()
	_commit_save()
	drop_collected.emit(int(collected[&"cores"]), int(collected[&"scrap"]))


func _sync_drops() -> void:
	if _coordinator != null:
		_drops = _coordinator.call("_get_run_drops") as Array[Dictionary]


func _get_player_cell() -> Vector2i:
	if _coordinator == null:
		return Vector2i(1_000_001, 1_000_001)
	var cell: Variant = _coordinator.call("get_run_value", &"player_cell")
	return cell as Vector2i if cell is Vector2i else Vector2i(1_000_001, 1_000_001)


func _commit_save() -> void:
	if _save_callback.is_valid():
		_save_callback.call()


func _find_drop_cell(origin: Vector2i, player_cell: Vector2i) -> Vector2i:
	for offset: Vector2i in SEARCH_OFFSETS:
		var candidate: Vector2i = origin + offset
		if candidate == player_cell:
			continue
		if bool(_world.call("is_walkable", candidate)) and not _drop_occupies(candidate):
			return candidate
	return origin


func _drop_occupies(cell: Vector2i) -> bool:
	for drop: Dictionary in _drops:
		if _drop_cell(drop) == cell:
			return true
	return false


func _drop_cell(drop: Dictionary) -> Vector2i:
	var value: Variant = drop.get(&"cell", [])
	if not value is Array or (value as Array).size() != 2:
		return Vector2i(1_000_001, 1_000_001)
	return Vector2i(int(value[0]), int(value[1]))


func _draw() -> void:
	if not _grid_to_screen.is_valid():
		return
	_visible_drop_count = 0
	var pulse: float = 0.5 + 0.5 * sin(_pulse_time * 4.0)
	for drop: Dictionary in _drops:
		var cell: Vector2i = _drop_cell(drop)
		if _world.has_method("is_cell_loaded") and not bool(_world.call("is_cell_loaded", cell)):
			continue
		_visible_drop_count += 1
		var center: Vector2 = _grid_to_screen.call(cell) as Vector2
		draw_circle(center, 22.0 + pulse * 3.0, Color(TEAL, 0.12 + pulse * 0.12))
		draw_texture_rect(
			CORE_TEXTURE,
			Rect2(center - Vector2(28.0, 32.0), Vector2(56.0, 56.0)),
			false,
			Color(1.0, 1.0, 1.0, 0.88 + pulse * 0.12),
		)
		draw_circle(center + Vector2(22.0, 10.0), 3.0, Color(AMBER, 0.72))
