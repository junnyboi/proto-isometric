extends Node2D

const RunPickupsScript: GDScript = preload("res://scripts/run_pickups.gd")

const ROCK: Color = Color("934d35")
const TEAL: Color = Color("4eb6aa")
const AMBER: Color = Color("f5a62d")
const INK: Color = Color("11151a")

var _destructible_rocks: Dictionary = {}
var _scrap: Dictionary = {}
var _outposts: Dictionary = {}
var _visible_cells: Array[Vector2i] = []
var _grid_to_screen: Callable
var _save_callback: Callable


func configure(
	destructible_rocks: Dictionary,
	scrap: Dictionary,
	outposts: Dictionary,
	grid_to_screen: Callable,
	save_callback: Callable = Callable(),
) -> void:
	_destructible_rocks = destructible_rocks
	_scrap = scrap
	_outposts = outposts
	_grid_to_screen = grid_to_screen
	_save_callback = save_callback
	queue_redraw()


func set_visible_cells(cells: Array[Vector2i]) -> void:
	_visible_cells = cells
	queue_redraw()


func get_visible_cell_count() -> int:
	return _visible_cells.size()


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


func _draw() -> void:
	if not _grid_to_screen.is_valid():
		return
	for cell: Vector2i in _visible_cells:
		_draw_cell_objects(cell)


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
