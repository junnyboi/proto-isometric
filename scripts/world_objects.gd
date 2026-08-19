extends Node2D

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")

const EncounterDirectorScript: GDScript = preload("res://scripts/encounter_director.gd")
const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const LavaContactScript: GDScript = preload("res://scripts/lava_contact.gd")
const RunPickupsScript: GDScript = preload("res://scripts/run_pickups.gd")

const ROCK: Color = Color("934d35")
const TEAL: Color = Color("4eb6aa")
const AMBER: Color = Color("f5a62d")
const INK: Color = Color("11151a")
const SANCTUARY_FILL: Color = Color(0.16, 0.78, 0.72, 0.09)
const SANCTUARY_GLOW: Color = Color(0.30, 0.96, 0.88, 0.26)
const SANCTUARY_LINE: Color = Color(0.34, 1.0, 0.91, 0.88)
const SANCTUARY_SEGMENTS: int = 48

var _destructible_rocks: Dictionary = {}
var _scrap: Dictionary = {}
var _outposts: Dictionary = {}
var _visible_cells: Array[Vector2i] = []
var _grid_to_screen: Callable
var _save_callback: Callable
var _tile_size: Vector2 = Vector2(90.0, 45.0)
var _sanctuary_radius: float = InfiniteWorldScript.SANCTUARY_RADIUS
var _lava_contact: RefCounted
var _damage_callback: Callable
var _redraw_request_count: int = 0


func configure(
	destructible_rocks: Dictionary,
	scrap: Dictionary,
	outposts: Dictionary,
	grid_to_screen: Callable,
	save_callback: Callable = Callable(),
	tile_size: Vector2 = Vector2(90.0, 45.0),
	sanctuary_radius: float = InfiniteWorldScript.SANCTUARY_RADIUS,
) -> void:
	_destructible_rocks = destructible_rocks
	_scrap = scrap
	_outposts = outposts
	_grid_to_screen = grid_to_screen
	_save_callback = save_callback
	_tile_size = tile_size
	_sanctuary_radius = maxf(sanctuary_radius, 0.0)
	invalidate_static_objects()


func bind_world(world: RefCounted, damage_callback: Callable) -> bool:
	_lava_contact = LavaContactScript.new() as RefCounted
	_damage_callback = damage_callback
	return bool(_lava_contact.call("configure", world))


func advance_lava(position: Vector2, delta: float) -> void:
	if _lava_contact == null or not _damage_callback.is_valid():
		return
	var damage: int = int(_lava_contact.call("advance", position, delta))
	if damage > 0:
		_damage_callback.call(damage, &"lava")


func set_visible_cells(cells: Array[Vector2i]) -> void:
	_visible_cells = cells
	invalidate_static_objects()


func get_visible_cell_count() -> int:
	return _visible_cells.size()


func invalidate_static_objects() -> void:
	_redraw_request_count += 1
	queue_redraw()


func get_redraw_request_count() -> int:
	return _redraw_request_count


func get_sanctuary_radius() -> float:
	return _sanctuary_radius


func get_visible_sanctuary_count() -> int:
	var count: int = 0
	for value: Variant in _outposts:
		var cell: Vector2i = value as Vector2i
		if bool(_outposts[cell]) and cell in _visible_cells:
			count += 1
	return count


func get_sanctuary_boundary_points(outpost_cell: Vector2i) -> PackedVector2Array:
	var center: Vector2 = _grid_to_screen.call(outpost_cell) as Vector2
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(SANCTUARY_SEGMENTS):
		var angle: float = TAU * float(index) / float(SANCTUARY_SEGMENTS)
		var offset: Vector2 = Vector2.from_angle(angle) * _sanctuary_radius
		points.append(center + _project_grid_offset(offset))
	return points


func build_run_pickups(world: RefCounted, coordinator: RefCounted, worms: Node2D) -> Node2D:
	if has_node("RunPickups"):
		return get_node("RunPickups") as Node2D
	var pickups: Node2D = RunPickupsScript.new() as Node2D
	pickups.name = "RunPickups"
	pickups.z_index = 3
	if not bool(pickups.call("configure", world, _grid_to_screen, coordinator, _save_callback)):
		pickups.free()
		return null
	if not bool(pickups.call("bind_worms", worms)):
		pickups.free()
		return null
	add_child(pickups)
	return pickups


func build_encounter_director(
	world: RefCounted,
	coordinator: RefCounted,
	worms: Node2D,
	hazards: Node2D,
) -> Node:
	if has_node("EncounterDirector"):
		return get_node("EncounterDirector")
	var director: Node = EncounterDirectorScript.new() as Node
	director.name = "EncounterDirector"
	if not bool(director.call("configure", coordinator, world, worms, hazards)):
		director.free()
		return null
	add_child(director)
	return director


func _draw() -> void:
	if not _grid_to_screen.is_valid():
		return
	for value: Variant in _outposts:
		var outpost_cell: Vector2i = value as Vector2i
		if bool(_outposts[outpost_cell]) and outpost_cell in _visible_cells:
			_draw_sanctuary_boundary(outpost_cell)
	for cell: Vector2i in _visible_cells:
		_draw_cell_objects(cell)


func _draw_sanctuary_boundary(outpost_cell: Vector2i) -> void:
	var points: PackedVector2Array = get_sanctuary_boundary_points(outpost_cell)
	if points.size() < 3:
		return
	draw_colored_polygon(points, SANCTUARY_FILL)
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(INK, 0.72), 8.0, true)
	draw_polyline(closed, SANCTUARY_GLOW, 6.0, true)
	draw_polyline(closed, SANCTUARY_LINE, 2.5, true)
	for index: int in range(0, SANCTUARY_SEGMENTS, 6):
		var next: int = (index + 1) % SANCTUARY_SEGMENTS
		var outward: Vector2 = (points[index] - points[next]).orthogonal().normalized()
		if outward.dot(points[index] - (_grid_to_screen.call(outpost_cell) as Vector2)) < 0.0:
			outward = -outward
		draw_line(points[index] - outward * 5.0, points[index] + outward * 7.0, SANCTUARY_LINE, 3.0)
	var center: Vector2 = _grid_to_screen.call(outpost_cell) as Vector2
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-39.0, -54.0),
		LocalizationScript.t(&"world.safe_zone"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		Color(0.74, 1.0, 0.95, 0.92),
	)


func _draw_cell_objects(cell: Vector2i) -> void:
	var center: Vector2 = _grid_to_screen.call(cell) as Vector2
	if bool(_outposts.get(cell, false)):
		_draw_outpost(center)
	if bool(_destructible_rocks.get(cell, false)):
		_draw_rock(center)
	if int(_scrap.get(cell, 0)) > 0:
		_draw_scrap(center, int(_scrap[cell]))


func _draw_rock(center: Vector2) -> void:
	draw_circle(center + Vector2(-12.0, -5.0), 15.0, ROCK.darkened(0.08))
	draw_circle(center + Vector2(7.0, -9.0), 19.0, ROCK.lightened(0.06))
	draw_circle(center + Vector2(18.0, 2.0), 12.0, ROCK.darkened(0.18))
	draw_line(center + Vector2(0.0, -24.0), center + Vector2(-5.0, 4.0), INK, 3.0)
	draw_line(center + Vector2(-5.0, 4.0), center + Vector2(9.0, 12.0), INK, 3.0)


func _draw_outpost(center: Vector2) -> void:
	draw_arc(center, 20.0, 0.0, TAU, 24, AMBER, 3.0)
	draw_arc(center, 28.0, 0.0, TAU, 32, TEAL, 2.0)
	for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_line(center + direction * 21.0, center + direction * 29.0, AMBER, 4.0)


func _draw_scrap(center: Vector2, amount: int) -> void:
	for index: int in range(mini(amount + 1, 4)):
		var offset: Vector2 = Vector2(float(index - 1) * 9.0, float(index % 2) * 7.0 - 5.0)
		draw_circle(center + offset, 7.0, TEAL.darkened(0.35))
		draw_arc(center + offset, 8.0, 0.0, TAU, 12, TEAL, 2.0)
		draw_circle(center + offset, 2.0, AMBER)


func _project_grid_offset(offset: Vector2) -> Vector2:
	return Vector2(
		(offset.x - offset.y) * _tile_size.x * 0.5,
		(offset.x + offset.y) * _tile_size.y * 0.5,
	)
