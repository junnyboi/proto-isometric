extends Node2D

const DepthScript: GDScript = preload("res://scripts/diagonal_depth.gd")
const FARM_SOIL_TEXTURE: Texture2D = preload("res://assets/textures/terrain/farm_soil.png")

const RECORD_SOIL: StringName = &"soil"
const RECORD_CROP: StringName = &"crop"
const RECORD_FENCE: StringName = &"fence"
const RECORD_STRUCTURE: StringName = &"structure"
const RECORD_RESIDENT: StringName = &"resident"
const RECORD_LIVESTOCK: StringName = &"livestock"
const RECORD_TYPES: Array[StringName] = [
	RECORD_SOIL,
	RECORD_CROP,
	RECORD_FENCE,
	RECORD_STRUCTURE,
	RECORD_RESIDENT,
	RECORD_LIVESTOCK,
]

var _visible_chunks: Dictionary = {}
var _records_by_chunk: Dictionary = {}
var _dirty_cells: Dictionary = {}
var _visible_records: Array[Dictionary] = []
var _grid_to_screen: Callable
var _chunk_size: int = 8
var _redraw_request_count: int = 0


func configure(grid_to_screen: Callable, chunk_size: int = 8) -> bool:
	if not grid_to_screen.is_valid() or chunk_size <= 0:
		return false
	_grid_to_screen = grid_to_screen
	_chunk_size = chunk_size
	return true


func set_visible_chunks(chunks: Array[Vector2i]) -> void:
	var next: Dictionary = {}
	for chunk: Vector2i in chunks:
		next[chunk] = true
	if next == _visible_chunks:
		return
	_visible_chunks = next
	_rebuild_visible_records()
	_request_redraw()


func consume_indexes(indexes: Dictionary) -> bool:
	var normalized: Dictionary = {}
	for value: Variant in indexes:
		if not value is Vector2i or not indexes[value] is Array:
			return false
		var chunk: Vector2i = value as Vector2i
		var accepted: Array[Dictionary] = []
		for candidate: Variant in indexes[value] as Array:
			if not candidate is Dictionary or not _record_is_valid(candidate as Dictionary):
				return false
			accepted.append((candidate as Dictionary).duplicate(true))
		normalized[chunk] = accepted
	if normalized == _records_by_chunk:
		return true
	_records_by_chunk = normalized
	_rebuild_visible_records()
	_request_redraw()
	return true


func invalidate_cells(cells: Array[Vector2i]) -> void:
	var visible_dirty: bool = false
	for cell: Vector2i in cells:
		_dirty_cells[cell] = true
		visible_dirty = visible_dirty or _visible_chunks.has(_chunk_for(cell))
	if visible_dirty:
		_rebuild_visible_records()
		_request_redraw()


func get_visible_record_count() -> int:
	return _visible_records.size()


func get_redraw_request_count() -> int:
	return _redraw_request_count


func has_per_entity_nodes() -> bool:
	return get_child_count() > 0


func get_dirty_cell_count() -> int:
	return _dirty_cells.size()


func has_per_crop_nodes() -> bool:
	return get_child_count() > 0


func get_visible_records() -> Array[Dictionary]:
	return _visible_records.duplicate(true)


func _rebuild_visible_records() -> void:
	_visible_records.clear()
	var chunks: Array[Vector2i] = []
	for value: Variant in _visible_chunks:
		chunks.append(value as Vector2i)
	chunks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _chunk_less(a, b))
	for chunk: Vector2i in chunks:
		for record: Dictionary in _records_by_chunk.get(chunk, []) as Array[Dictionary]:
			_visible_records.append(record)
	_visible_records = DepthScript.stable_sort(_visible_records)
	_dirty_cells.clear()


func _record_is_valid(record: Dictionary) -> bool:
	return (
		record.has(&"cell")
		and record.has(&"type")
		and record[&"cell"] is Vector2i
		and record[&"type"] in RECORD_TYPES
		and (not record.has(&"texture") or record[&"texture"] is Texture2D)
	)


func _chunk_for(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(cell.x) / float(_chunk_size)),
		floori(float(cell.y) / float(_chunk_size)),
	)


func _chunk_less(first: Vector2i, second: Vector2i) -> bool:
	return first.y < second.y or (first.y == second.y and first.x < second.x)


func _request_redraw() -> void:
	_redraw_request_count += 1
	queue_redraw()


func _draw() -> void:
	if not _grid_to_screen.is_valid():
		return
	for record: Dictionary in _visible_records:
		var center: Vector2 = _grid_to_screen.call(record[&"cell"] as Vector2i) as Vector2
		var texture: Texture2D = record.get(&"texture", null) as Texture2D
		if record[&"type"] == RECORD_SOIL:
			_draw_soil_tile(center)
			continue
		if texture == null:
			continue
		var size: Vector2 = record.get(&"draw_size", Vector2(90.0, 90.0)) as Vector2
		var offset: Vector2 = record.get(&"draw_offset", Vector2.ZERO) as Vector2
		var destination: Rect2 = Rect2(center + offset - size * 0.5, size)
		if record.has(&"atlas_region"):
			draw_texture_rect_region(texture, destination, record[&"atlas_region"] as Rect2)
		else:
			draw_texture_rect(texture, destination, false)


func _draw_soil_tile(center: Vector2) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -22.5),
		center + Vector2(45.0, 0.0),
		center + Vector2(0.0, 22.5),
		center + Vector2(-45.0, 0.0),
	])
	var colors: PackedColorArray = PackedColorArray([
		Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE,
	])
	var uvs: PackedVector2Array = PackedVector2Array([
		Vector2(256.0, 0.0),
		Vector2(512.0, 256.0),
		Vector2(256.0, 512.0),
		Vector2(0.0, 256.0),
	])
	draw_polygon(points, colors, uvs, FARM_SOIL_TEXTURE)
