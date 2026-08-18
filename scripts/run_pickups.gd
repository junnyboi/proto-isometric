extends Node2D

signal drop_placed(drop_id: StringName, cell: Vector2i)

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
const DARK: Color = Color("162328")

var _world: RefCounted
var _grid_to_screen: Callable
var _coordinator: RefCounted
var _drops: Array[Dictionary] = []
var _handled_worm_ids: Dictionary = {}
var _next_drop_sequence: int = 1
var _pulse_time: float = 0.0


func configure(world: RefCounted, grid_to_screen: Callable, coordinator: RefCounted = null) -> bool:
	if world == null or not world.has_method("is_walkable") or not grid_to_screen.is_valid():
		return false
	_world = world
	_grid_to_screen = grid_to_screen
	_coordinator = coordinator
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
	queue_redraw()


func clear() -> void:
	_drops.clear()
	_handled_worm_ids.clear()
	_next_drop_sequence = 1
	queue_redraw()


func get_drop_count() -> int:
	return _drops.size()


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
	var cell: Vector2i = _find_drop_cell(Vector2i(roundi(position.x), roundi(position.y)))
	if not bool(_world.call("is_walkable", cell)):
		return
	var drop_id: StringName = StringName("drop.worm.%06d" % _next_drop_sequence)
	_next_drop_sequence += 1
	(
		_drops
		. append(
			{
				&"drop_id": drop_id,
				&"source_worm_id": worm_id,
				&"cell": cell,
				&"cores": CORE_PER_WORM,
				&"scrap": SCRAP_PER_WORM,
			}
		)
	)
	if _coordinator != null:
		_coordinator.call("record_event", &"event.worm.defeated", {&"drop_id": drop_id})
	drop_placed.emit(drop_id, cell)
	queue_redraw()


func _find_drop_cell(origin: Vector2i) -> Vector2i:
	for offset: Vector2i in SEARCH_OFFSETS:
		var candidate: Vector2i = origin + offset
		if bool(_world.call("is_walkable", candidate)) and not _drop_occupies(candidate):
			return candidate
	return origin


func _drop_occupies(cell: Vector2i) -> bool:
	for drop: Dictionary in _drops:
		if drop[&"cell"] == cell:
			return true
	return false


func _draw() -> void:
	if not _grid_to_screen.is_valid():
		return
	var pulse: float = 0.5 + 0.5 * sin(_pulse_time * 4.0)
	for drop: Dictionary in _drops:
		var center: Vector2 = _grid_to_screen.call(drop[&"cell"]) as Vector2
		draw_circle(center, 20.0 + pulse * 3.0, Color(TEAL, 0.12 + pulse * 0.12))
		var core: PackedVector2Array = PackedVector2Array(
			[
				center + Vector2(0.0, -15.0),
				center + Vector2(12.0, 0.0),
				center + Vector2(0.0, 15.0),
				center + Vector2(-12.0, 0.0),
			]
		)
		draw_colored_polygon(core, DARK)
		draw_polyline(PackedVector2Array([core[0], core[1], core[2], core[3], core[0]]), TEAL, 3.0)
		draw_circle(center, 4.0 + pulse * 1.5, AMBER)
		draw_circle(center + Vector2(17.0, 8.0), 4.0, Color(AMBER, 0.78))
		draw_circle(center + Vector2(23.0, 4.0), 3.0, Color(AMBER, 0.58))
