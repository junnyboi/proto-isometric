class_name WorldNearbyInterestIndex
extends RefCounted

const CHUNK_SIZE: int = 8
const MAX_RADIUS: int = 24
const MAX_CANDIDATES: int = 128
const MAX_RESULTS: int = 4
const RECORD_KEYS: Array[StringName] = [
	&"interest_id",
	&"kind",
	&"title_key",
	&"cell",
	&"source_revision",
	&"available",
]
const RESULT_KEYS: Array[StringName] = [
	&"interest_id",
	&"kind",
	&"title_key",
	&"cell",
	&"source_revision",
	&"available",
	&"tile_distance",
	&"direction_id",
]

var _records: Dictionary = {}
var _buckets: Dictionary = {}
var _source_revision: int = -1
var _revision: int = 0
var _build_count: int = 0
var _query_count: int = 0
var _last_candidate_count: int = 0
var _cached_query_key: Array = []
var _cached_query_result: Array[Dictionary] = []


func rebuild(records: Array, source_revision: int) -> bool:
	if source_revision < 0:
		return false
	if source_revision == _source_revision:
		return false
	var canonical: Dictionary = {}
	for value: Variant in records:
		if not validate_record(value):
			return false
		var record: Dictionary = value as Dictionary
		if int(record[&"source_revision"]) != source_revision:
			return false
		var interest_id: StringName = record[&"interest_id"] as StringName
		if canonical.has(interest_id):
			return false
		canonical[interest_id] = record.duplicate(true)
	_records = canonical
	_source_revision = source_revision
	_rebuild_buckets()
	_cached_query_key.clear()
	_cached_query_result.clear()
	_revision += 1
	_build_count += 1
	return true


func replace_records(records: Array, source_revision: int) -> bool:
	return rebuild(records, source_revision)


func clear(source_revision: int) -> bool:
	return rebuild([], source_revision)


func query(
	origin: Vector2i,
	radius: int = MAX_RADIUS,
	excluded_interest_id: StringName = &"",
	result_limit: int = MAX_RESULTS,
) -> Array[Dictionary]:
	var bounded_radius: int = clampi(radius, 0, MAX_RADIUS)
	var bounded_limit: int = clampi(result_limit, 0, MAX_RESULTS)
	var query_key: Array = [
		_revision, origin, bounded_radius, excluded_interest_id, bounded_limit,
	]
	if query_key == _cached_query_key:
		return _cached_query_result.duplicate(true)
	_query_count += 1
	_last_candidate_count = 0
	if bounded_limit == 0 or _records.is_empty():
		_cached_query_key = query_key
		_cached_query_result = []
		return []
	var minimum: Vector2i = origin - Vector2i(bounded_radius, bounded_radius)
	var maximum: Vector2i = origin + Vector2i(bounded_radius, bounded_radius)
	var first_chunk: Vector2i = chunk_for_cell(minimum)
	var last_chunk: Vector2i = chunk_for_cell(maximum)
	var matches: Array[Dictionary] = []
	var stop: bool = false
	for chunk_y: int in range(first_chunk.y, last_chunk.y + 1):
		for chunk_x: int in range(first_chunk.x, last_chunk.x + 1):
			var bucket: Array = _buckets.get(Vector2i(chunk_x, chunk_y), []) as Array
			for interest_id_value: Variant in bucket:
				if _last_candidate_count >= MAX_CANDIDATES:
					stop = true
					break
				_last_candidate_count += 1
				var interest_id: StringName = interest_id_value as StringName
				if interest_id == excluded_interest_id:
					continue
				var record: Dictionary = _records[interest_id] as Dictionary
				if not bool(record[&"available"]):
					continue
				var cell: Vector2i = record[&"cell"] as Vector2i
				var distance: int = absi(cell.x - origin.x) + absi(cell.y - origin.y)
				if distance > bounded_radius:
					continue
				var result: Dictionary = record.duplicate(true)
				result[&"tile_distance"] = distance
				result[&"direction_id"] = direction_id_for(cell - origin)
				matches.append(result)
			if stop:
				break
		if stop:
			break
	matches.sort_custom(_result_less)
	if matches.size() > bounded_limit:
		matches.resize(bounded_limit)
	_cached_query_key = query_key
	_cached_query_result = matches.duplicate(true)
	return matches.duplicate(true)


func query_nearby(
	origin: Vector2i,
	radius: int = MAX_RADIUS,
	excluded_interest_id: StringName = &"",
	result_limit: int = MAX_RESULTS,
) -> Array[Dictionary]:
	return query(origin, radius, excluded_interest_id, result_limit)


func get_revision() -> int:
	return _revision


func get_source_revision() -> int:
	return _source_revision


func get_build_count() -> int:
	return _build_count


func get_query_count() -> int:
	return _query_count


func get_last_candidate_count() -> int:
	return _last_candidate_count


func get_record_count() -> int:
	return _records.size()


func get_bucket_count() -> int:
	return _buckets.size()


static func validate_record(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var record: Dictionary = value as Dictionary
	if record.keys() != RECORD_KEYS:
		return false
	if (
		not record[&"interest_id"] is StringName
		or not record[&"kind"] is StringName
		or not record[&"title_key"] is StringName
		or not record[&"cell"] is Vector2i
		or not record[&"source_revision"] is int
		or not record[&"available"] is bool
	):
		return false
	return (
		not str(record[&"interest_id"]).is_empty()
		and str(record[&"interest_id"]).length() <= 128
		and not str(record[&"kind"]).is_empty()
		and str(record[&"kind"]).length() <= 128
		and not str(record[&"title_key"]).is_empty()
		and str(record[&"title_key"]).length() <= 128
		and int(record[&"source_revision"]) >= 0
	)


static func validate_result(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var result: Dictionary = value as Dictionary
	if result.keys() != RESULT_KEYS:
		return false
	var record: Dictionary = {}
	for key: StringName in RECORD_KEYS:
		record[key] = result[key]
	return (
		validate_record(record)
		and result[&"tile_distance"] is int
		and int(result[&"tile_distance"]) >= 0
		and int(result[&"tile_distance"]) <= MAX_RADIUS
		and result[&"direction_id"] is StringName
		and result[&"direction_id"] in [
			&"here", &"north", &"north_east", &"east", &"south_east",
			&"south", &"south_west", &"west", &"north_west",
		]
	)


static func chunk_for_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(cell.x) / float(CHUNK_SIZE)),
		floori(float(cell.y) / float(CHUNK_SIZE)),
	)


static func direction_id_for(delta: Vector2i) -> StringName:
	if delta == Vector2i.ZERO:
		return &"here"
	var vertical: String = "north" if delta.y < 0 else "south" if delta.y > 0 else ""
	var horizontal: String = "west" if delta.x < 0 else "east" if delta.x > 0 else ""
	if vertical.is_empty():
		return StringName(horizontal)
	if horizontal.is_empty():
		return StringName(vertical)
	return StringName("%s_%s" % [vertical, horizontal])


func _rebuild_buckets() -> void:
	_buckets.clear()
	var ids: Array = _records.keys()
	ids.sort_custom(func(first: Variant, second: Variant) -> bool: return str(first) < str(second))
	for interest_id_value: Variant in ids:
		var interest_id: StringName = interest_id_value as StringName
		var record: Dictionary = _records[interest_id] as Dictionary
		var chunk: Vector2i = chunk_for_cell(record[&"cell"] as Vector2i)
		var bucket: Array = _buckets.get(chunk, []) as Array
		bucket.append(interest_id)
		_buckets[chunk] = bucket


func _result_less(first: Dictionary, second: Dictionary) -> bool:
	var first_distance: int = int(first[&"tile_distance"])
	var second_distance: int = int(second[&"tile_distance"])
	if first_distance != second_distance:
		return first_distance < second_distance
	return str(first[&"interest_id"]) < str(second[&"interest_id"])
