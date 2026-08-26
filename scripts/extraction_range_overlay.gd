extends Node2D

const CalendarScript: GDScript = preload("res://scripts/calendar_state.gd")
const CatalogScript: GDScript = preload("res://scripts/resource_deposit_catalog.gd")
const GatheringScript: GDScript = preload("res://scripts/gathering_state_service.gd")

var _grid_to_screen: Callable
var _farm_getter: Callable
var _world: RefCounted
var _site_id: StringName = &""
var _anchor: Vector2i = Vector2i.ZERO
var _extent: int = 0
var _records: Array[Dictionary] = []


func configure(grid_to_screen: Callable, farm_getter: Callable, world: RefCounted) -> bool:
	if not grid_to_screen.is_valid() or not farm_getter.is_valid() or world == null:
		return false
	_grid_to_screen = grid_to_screen
	_farm_getter = farm_getter
	_world = world
	return true


func toggle_site(instance_id: StringName) -> bool:
	if instance_id == _site_id:
		clear()
		return false
	_site_id = instance_id
	_refresh()
	return is_active()


func clear() -> void:
	_site_id = &""
	_extent = 0
	_records.clear()
	queue_redraw()


func refresh() -> void:
	if _site_id != &"":
		_refresh()


func is_active() -> bool:
	return _site_id != &"" and _extent > 0


func get_preview_records() -> Array[Dictionary]:
	return _records.duplicate(true)


func _refresh() -> void:
	_records.clear()
	var farm: Dictionary = _farm_getter.call() as Dictionary
	var building: Dictionary = _building(farm, _site_id)
	if building.is_empty() or building[&"state"] != "complete":
		clear()
		return
	var anchor: Vector2i = building[&"anchor"] as Vector2i
	var level: int = int(building[&"level"])
	var extent: int = CatalogScript.effective_range(level)
	_anchor = anchor
	_extent = extent
	var blueprint: StringName = StringName(str(building[&"blueprint_id"]))
	var seed: int = int(_world.call("_get_world_seed"))
	var mode: StringName = _world.call("_get_gameplay_mode") as StringName
	var day: int = CalendarScript.absolute_day(farm[&"calendar_weather"])
	for y: int in range(-extent, extent + 1):
		for x: int in range(-extent, extent + 1):
			var cell: Vector2i = anchor + Vector2i(x, y)
			var projected: Dictionary = CatalogScript.project_at(cell, seed, mode)
			if projected.is_empty() or not CatalogScript.compatible(projected, blueprint, level):
				continue
			var source: Dictionary = _world.call("_resource_source_at", cell) as Dictionary
			if source.is_empty():
				continue
			var state: Dictionary = GatheringScript.effective(farm, source, day)
			_records.append(
				{
					&"source_id": str(source[&"source_id"]), &"cell": cell,
					&"phase": str(state[&"phase"]),
					&"reserved_by": str(state[&"reserved_by"]),
					&"renewable": bool(source[&"renewable"]),
				}
			)
	_records.sort_custom(_record_precedes)
	queue_redraw()


func _building(farm: Dictionary, instance_id: StringName) -> Dictionary:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var section: Dictionary = homestead.get(&"construction", {}) as Dictionary
	for record: Dictionary in section.get(&"buildings", []) as Array[Dictionary]:
		if record[&"instance_id"] == str(instance_id):
			return record.duplicate(true)
	return {}


func _draw() -> void:
	if not is_active() or not _grid_to_screen.is_valid():
		return
	_draw_range(_anchor, _extent)
	for record: Dictionary in _records:
		_draw_source(record)


func _draw_range(anchor: Vector2i, extent: int) -> void:
	var cells: Array[Vector2i] = [
		anchor + Vector2i(-extent, -extent), anchor + Vector2i(extent, -extent),
		anchor + Vector2i(extent, extent), anchor + Vector2i(-extent, extent),
	]
	var points: PackedVector2Array = PackedVector2Array()
	for cell: Vector2i in cells:
		points.append(_grid_to_screen.call(cell) as Vector2)
	points.append(points[0])
	draw_polyline(points, Color(0.22, 0.95, 0.92, 0.76), 3.0, true)


func _draw_source(record: Dictionary) -> void:
	var center: Vector2 = _grid_to_screen.call(record[&"cell"] as Vector2i) as Vector2
	var color: Color = Color(0.18, 0.92, 0.48, 0.82)
	if not str(record[&"reserved_by"]).is_empty() and str(record[&"reserved_by"]) != str(_site_id):
		color = Color(0.96, 0.24, 0.28, 0.86)
	elif record[&"phase"] in ["depleted", "exhausted"]:
		color = Color(0.96, 0.62, 0.16, 0.86)
	elif bool(record[&"renewable"]):
		color = Color(0.36, 0.94, 0.42, 0.86)
	var diamond: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -18.0), center + Vector2(36.0, 0.0),
		center + Vector2(0.0, 18.0), center + Vector2(-36.0, 0.0),
		center + Vector2(0.0, -18.0),
	])
	draw_polyline(diamond, color, 4.0, true)


func _record_precedes(first: Dictionary, second: Dictionary) -> bool:
	return str(first[&"source_id"]) < str(second[&"source_id"])
