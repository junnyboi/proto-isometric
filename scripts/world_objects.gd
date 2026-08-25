extends Node2D

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")

const BiomeDestructiblesScript: GDScript = preload("res://scripts/biome_destructibles.gd")
const EncounterDirectorScript: GDScript = preload("res://scripts/encounter_director.gd")
const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const LavaContactScript: GDScript = preload("res://scripts/lava_contact.gd")
const OutpostEnergyScript: GDScript = preload("res://scripts/outpost_energy.gd")
const OutpostVisualsScript: GDScript = preload("res://scripts/outpost_visuals.gd")
const RunPickupsScript: GDScript = preload("res://scripts/run_pickups.gd")
const WoodlandVisualsScript: GDScript = preload("res://scripts/woodland_visuals.gd")

const TEAL: Color = Color("4eb6aa")
const AMBER: Color = Color("f5a62d")
const INK: Color = Color("11151a")
const SANCTUARY_FILL: Color = Color(0.16, 0.78, 0.72, 0.09)
const SANCTUARY_GLOW: Color = Color(0.30, 0.96, 0.88, 0.26)
const SANCTUARY_LINE: Color = Color(0.34, 1.0, 0.91, 0.88)
const SANCTUARY_SEGMENTS: int = 48
const OUTPOST_LABEL_MARGIN: Vector2 = Vector2(-39.0, -22.0)

var _destructible_rocks: Dictionary = {}
var _scrap: Dictionary = {}
var _outposts: Dictionary = {}
var _visible_cells: Array[Vector2i] = []
var _grid_to_screen: Callable
var _save_callback: Callable
var _tile_size: Vector2 = Vector2(90.0, 45.0)
var _sanctuary_radius: float = InfiniteWorldScript.SANCTUARY_RADIUS
var _world: RefCounted
var _lava_contact: RefCounted
var _damage_callback: Callable
var _redraw_request_count: int = 0
var _outpost_energy: Node2D


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
	_build_outpost_energy()
	invalidate_static_objects()


func bind_world(world: RefCounted, damage_callback: Callable) -> bool:
	if world == null:
		return false
	_world = world
	_lava_contact = LavaContactScript.new() as RefCounted
	_damage_callback = damage_callback
	invalidate_static_objects()
	return bool(_lava_contact.call("configure", world))


func advance_lava(position: Vector2, delta: float) -> void:
	if _lava_contact == null or not _damage_callback.is_valid():
		return
	var damage: int = int(_lava_contact.call("advance", position, delta))
	if damage > 0:
		_damage_callback.call(damage, &"lava")


func set_visible_cells(cells: Array[Vector2i]) -> void:
	_visible_cells = cells
	if _outpost_energy != null:
		_outpost_energy.call("set_visible_cells", cells)
	invalidate_static_objects()


func get_visible_cell_count() -> int:
	return _visible_cells.size()


func get_destructible_kind(cell: Vector2i) -> StringName:
	if _world == null:
		return BiomeDestructiblesScript.KIND_DESERT_ROCK
	var biome: StringName = _world.call("_biome_at", cell) as StringName
	return BiomeDestructiblesScript.kind_for(biome, cell)


func get_outpost_kind(cell: Vector2i) -> StringName:
	if _world != null and _world.has_method("_outpost_kind_at"):
		return _world.call("_outpost_kind_at", cell) as StringName
	return OutpostVisualsScript.kind_for(cell)


func get_outpost_texture_path(cell: Vector2i) -> String:
	var texture: Texture2D = OutpostVisualsScript.texture_for(get_outpost_kind(cell))
	return texture.resource_path if texture != null else ""


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
		if bool(_outposts[cell]) and cell in _visible_cells and _outpost_has_sanctuary(cell):
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


func _build_outpost_energy() -> void:
	if _outpost_energy != null:
		return
	_outpost_energy = OutpostEnergyScript.new() as Node2D
	_outpost_energy.name = "OutpostEnergy"
	_outpost_energy.z_index = 2
	add_child(_outpost_energy)
	_outpost_energy.call(
		"configure",
		_outposts,
		_grid_to_screen,
		Callable(self, "_outpost_has_sanctuary"),
		Callable(self, "get_outpost_kind"),
	)
	_outpost_energy.call("set_visible_cells", _visible_cells)


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
		if (
			bool(_outposts[outpost_cell])
			and outpost_cell in _visible_cells
			and _outpost_has_sanctuary(outpost_cell)
		):
			_draw_sanctuary_boundary(outpost_cell)
	for cell: Vector2i in _visible_cells:
		_draw_cell_objects(cell)
	for value: Variant in _outposts:
		var outpost_cell: Vector2i = value as Vector2i
		if (
			bool(_outposts[outpost_cell])
			and outpost_cell in _visible_cells
			and _outpost_has_sanctuary(outpost_cell)
		):
			_draw_sanctuary_label(outpost_cell)


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


func _draw_sanctuary_label(outpost_cell: Vector2i) -> void:
	var center: Vector2 = _grid_to_screen.call(outpost_cell) as Vector2
	var kind: StringName = get_outpost_kind(outpost_cell)
	draw_string(
		ThemeDB.fallback_font,
		center + OutpostVisualsScript.draw_offset_for(kind) + OUTPOST_LABEL_MARGIN,
		LocalizationScript.t(&"world.safe_zone"),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		Color(0.74, 1.0, 0.95, 0.92),
	)


func _draw_cell_objects(cell: Vector2i) -> void:
	var center: Vector2 = _grid_to_screen.call(cell) as Vector2
	if _world != null and bool(_world.call("_is_pond", cell)):
		_draw_woodland_object(WoodlandVisualsScript.KIND_POND, center)
	if bool(_outposts.get(cell, false)):
		_draw_outpost(cell, center)
	var tree_kind: StringName = (
		_world.call("_tree_kind_at", cell) as StringName if _world != null else &""
	)
	if tree_kind != &"":
		_draw_woodland_object(tree_kind, center)
	elif bool(_destructible_rocks.get(cell, false)):
		_draw_destructible(cell, center)
	if int(_scrap.get(cell, 0)) > 0:
		_draw_scrap(center, int(_scrap[cell]))


func _draw_destructible(cell: Vector2i, center: Vector2) -> void:
	var kind: StringName = get_destructible_kind(cell)
	var texture: Texture2D = BiomeDestructiblesScript.texture_for(kind)
	var size: Vector2 = BiomeDestructiblesScript.display_size_for(kind)
	if texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var bottom_center: Vector2 = center + Vector2(0.0, 12.0)
	var rect: Rect2 = Rect2(bottom_center - Vector2(size.x * 0.5, size.y), size)
	draw_texture_rect(texture, rect, false)


func _draw_woodland_object(kind: StringName, center: Vector2) -> void:
	var texture: Texture2D = WoodlandVisualsScript.texture_for(kind)
	var size: Vector2 = WoodlandVisualsScript.display_size_for(kind)
	if texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var rect: Rect2 = Rect2(center + WoodlandVisualsScript.draw_offset_for(kind), size)
	draw_texture_rect(texture, rect, false)


func _draw_outpost(cell: Vector2i, center: Vector2) -> void:
	var kind: StringName = get_outpost_kind(cell)
	var texture: Texture2D = OutpostVisualsScript.texture_for(kind)
	var size: Vector2 = OutpostVisualsScript.display_size_for(kind)
	if texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var rect: Rect2 = Rect2(center + OutpostVisualsScript.draw_offset_for(kind), size)
	draw_texture_rect(texture, rect, false)


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


func _outpost_has_sanctuary(cell: Vector2i) -> bool:
	return (
		bool(_world.call("_is_sanctuary_outpost", cell))
		if _world != null and _world.has_method("_is_sanctuary_outpost")
		else true
	)
