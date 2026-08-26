extends RefCounted

const CHUNK_SIZE: int = 8
const MAX_RECORDS: int = 4_096
const MAX_FOOTPRINT_CELLS: int = 16
const MAX_COORDINATE: int = 1_000_000
const MAX_DELTA_VALUE: int = 999
const VALID_KINDS: Array[StringName] = [
	&"object.rock",
	&"object.tree",
	&"object.resource",
	&"object.flora",
	&"structure.workbench",
	&"structure.furnace",
	&"structure.storage",
	&"structure.settlement",
]


static func stable_id(kind: StringName, anchor: Vector2i) -> StringName:
	return StringName("%s:%d,%d" % [String(kind), anchor.x, anchor.y])


static func make_placed(
	kind: StringName, anchor: Vector2i, footprint: Array[Vector2i], value_delta: int = 0
) -> Dictionary:
	var encoded: Array[Array] = []
	for offset: Vector2i in footprint:
		encoded.append([offset.x, offset.y])
	return {
		&"stable_id": String(stable_id(kind, anchor)),
		&"kind": String(kind),
		&"anchor": [anchor.x, anchor.y],
		&"footprint": encoded,
		&"value_delta": value_delta,
	}


static func make_cleared(kind: StringName, anchor: Vector2i, value_delta: int = 0) -> Dictionary:
	return {
		&"stable_id": String(stable_id(kind, anchor)),
		&"kind": String(kind),
		&"anchor": [anchor.x, anchor.y],
		&"value_delta": value_delta,
	}


static func validate(ledger: Variant) -> Dictionary:
	if not ledger is Dictionary:
		return {}
	var value: Dictionary = ledger as Dictionary
	if not _exact_keys(value, [&"cleared", &"placed"]):
		return {}
	var cleared: Variant = _normalize_records(value[&"cleared"], false)
	var placed: Variant = _normalize_records(value[&"placed"], true)
	if cleared == null or placed == null:
		return {}
	var ids: Dictionary = {}
	var occupied: Dictionary = {}
	for record: Dictionary in cleared as Array[Dictionary]:
		ids[record[&"stable_id"]] = true
	for record: Dictionary in placed as Array[Dictionary]:
		if ids.has(record[&"stable_id"]):
			return {}
		ids[record[&"stable_id"]] = true
		var anchor: Array = record[&"anchor"] as Array
		for offset: Array in record[&"footprint"] as Array:
			var cell: Vector2i = Vector2i(
				int(anchor[0]) + int(offset[0]), int(anchor[1]) + int(offset[1])
			)
			var key: String = "%d,%d" % [cell.x, cell.y]
			if occupied.has(key):
				return {}
			occupied[key] = true
	return {&"cleared": cleared, &"placed": placed}


static func place(ledger: Dictionary, record: Dictionary) -> Dictionary:
	var source: Dictionary = validate(ledger)
	if source.is_empty():
		return _result(false, ledger, &"invalid_ledger")
	var candidate: Dictionary = source.duplicate(true)
	(candidate[&"placed"] as Array).append(record.duplicate(true))
	var normalized: Dictionary = validate(candidate)
	return (
		_result(false, source, &"duplicate_or_overlap")
		if normalized.is_empty()
		else _result(true, normalized, &"")
	)


static func remove_placed(ledger: Dictionary, stable_identifier: StringName) -> Dictionary:
	var source: Dictionary = validate(ledger)
	if source.is_empty():
		return _result(false, ledger, &"invalid_ledger")
	var candidate: Dictionary = source.duplicate(true)
	var records: Array = candidate[&"placed"] as Array
	for index: int in records.size():
		if str((records[index] as Dictionary)[&"stable_id"]) != str(stable_identifier):
			continue
		records.remove_at(index)
		candidate[&"placed"] = records
		return _result(true, validate(candidate), &"")
	return _result(false, source, &"placed_record_missing")


static func replace_placed(
	ledger: Dictionary, stable_identifier: StringName, record: Dictionary
) -> Dictionary:
	var removed: Dictionary = remove_placed(ledger, stable_identifier)
	if not bool(removed[&"ok"]):
		return removed
	var placed: Dictionary = place(removed[&"candidate"], record)
	return (
		placed
		if bool(placed[&"ok"])
		else _result(false, validate(ledger), placed[&"reason"] as StringName)
	)


static func placed_record(ledger: Dictionary, stable_identifier: StringName) -> Dictionary:
	var source: Dictionary = validate(ledger)
	if source.is_empty():
		return {}
	for record: Dictionary in source[&"placed"] as Array[Dictionary]:
		if str(record[&"stable_id"]) == str(stable_identifier):
			return record.duplicate(true)
	return {}


static func clear(ledger: Dictionary, record: Dictionary) -> Dictionary:
	var source: Dictionary = validate(ledger)
	if source.is_empty():
		return _result(false, ledger, &"invalid_ledger")
	var candidate: Dictionary = source.duplicate(true)
	(candidate[&"cleared"] as Array).append(record.duplicate(true))
	var normalized: Dictionary = validate(candidate)
	return (
		_result(false, source, &"duplicate_or_overlap")
		if normalized.is_empty()
		else _result(true, normalized, &"")
	)


static func is_cleared(ledger: Dictionary, kind: StringName, anchor: Vector2i) -> bool:
	var normalized: Dictionary = validate(ledger)
	if normalized.is_empty() or kind not in VALID_KINDS:
		return false
	var identifier: String = String(stable_id(kind, anchor))
	for record: Dictionary in normalized[&"cleared"] as Array[Dictionary]:
		if str(record[&"stable_id"]) == identifier:
			return true
	return false


static func build_chunk_indexes(ledger: Dictionary) -> Dictionary:
	var normalized: Dictionary = validate(ledger)
	var indexes: Dictionary = {}
	if normalized.is_empty():
		return indexes
	for collection: StringName in [&"cleared", &"placed"]:
		for record: Dictionary in normalized[collection] as Array[Dictionary]:
			var anchor: Array = record[&"anchor"] as Array
			var chunk: Vector2i = _chunk(Vector2i(int(anchor[0]), int(anchor[1])))
			if not indexes.has(chunk):
				indexes[chunk] = []
			(indexes[chunk] as Array).append(record.duplicate(true))
	for records: Variant in indexes.values():
		(records as Array).sort_custom(_record_less)
	return indexes


static func from_legacy(world: Dictionary) -> Dictionary:
	var cleared: Array[Dictionary] = []
	var placed: Array[Dictionary] = []
	for raw_cell: Variant in world.get(&"destroyed_rocks", []) as Array:
		var cell: Vector2i = Vector2i(int(raw_cell[0]), int(raw_cell[1]))
		cleared.append(make_cleared(&"object.rock", cell))
	for raw_cell: Variant in world.get(&"placed_rocks", []) as Array:
		var cell: Vector2i = Vector2i(int(raw_cell[0]), int(raw_cell[1]))
		placed.append(make_placed(&"object.rock", cell, [Vector2i.ZERO]))
	return validate({&"cleared": cleared, &"placed": placed})


static func legacy_arrays_exact(world: Dictionary, ledger: Dictionary) -> Dictionary:
	var normalized: Dictionary = validate(ledger)
	if normalized.is_empty():
		return {}
	var adapted: Dictionary = world.duplicate(true)
	var destroyed: Array[Array] = []
	var placed_rocks: Array[Array] = []
	for record: Dictionary in normalized[&"cleared"] as Array[Dictionary]:
		if record[&"kind"] == "object.rock":
			destroyed.append((record[&"anchor"] as Array).duplicate())
	for record: Dictionary in normalized[&"placed"] as Array[Dictionary]:
		if record[&"kind"] == "object.rock":
			placed_rocks.append((record[&"anchor"] as Array).duplicate())
	adapted[&"destroyed_rocks"] = destroyed
	adapted[&"placed_rocks"] = placed_rocks
	return adapted


static func _normalize_records(value: Variant, placed: bool) -> Variant:
	if not value is Array or (value as Array).size() > MAX_RECORDS:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_record: Variant in value as Array:
		var record: Dictionary = raw_record as Dictionary if raw_record is Dictionary else {}
		var expected: Array[StringName] = [&"stable_id", &"kind", &"anchor", &"value_delta"]
		if placed:
			expected.insert(3, &"footprint")
		if not _exact_keys(record, expected):
			return null
		var kind: StringName = StringName(str(record[&"kind"]))
		var anchor: Variant = _normalize_cell(record[&"anchor"])
		var delta: Variant = _integer(record[&"value_delta"], -MAX_DELTA_VALUE, MAX_DELTA_VALUE)
		var identifier: String = str(record[&"stable_id"])
		if (
			kind not in VALID_KINDS
			or anchor == null
			or delta == null
			or identifier != String(stable_id(kind, Vector2i(int(anchor[0]), int(anchor[1]))))
			or seen.has(identifier)
		):
			return null
		seen[identifier] = true
		var normalized: Dictionary = {
			&"stable_id": identifier,
			&"kind": String(kind),
			&"anchor": anchor,
			&"value_delta": int(delta),
		}
		if placed:
			var footprint: Variant = _normalize_footprint(record[&"footprint"])
			if footprint == null:
				return null
			normalized[&"footprint"] = footprint
		result.append(normalized)
	result.sort_custom(_record_less)
	return result


static func _normalize_footprint(value: Variant) -> Variant:
	if (
		not value is Array
		or (value as Array).is_empty()
		or (value as Array).size() > MAX_FOOTPRINT_CELLS
	):
		return null
	var result: Array[Array] = []
	var seen: Dictionary = {}
	for raw_cell: Variant in value as Array:
		var cell: Variant = _normalize_cell(raw_cell, -8, 8)
		if cell == null:
			return null
		var key: String = "%d,%d" % [int(cell[0]), int(cell[1])]
		if seen.has(key):
			return null
		seen[key] = true
		result.append(cell as Array)
	result.sort_custom(_cell_less)
	return result


static func _normalize_cell(
	value: Variant, minimum: int = -MAX_COORDINATE, maximum: int = MAX_COORDINATE
) -> Variant:
	if not value is Array or (value as Array).size() != 2:
		return null
	var x: Variant = _integer(value[0], minimum, maximum)
	var y: Variant = _integer(value[1], minimum, maximum)
	return null if x == null or y == null else [int(x), int(y)]


static func _integer(value: Variant, minimum: int, maximum: int) -> Variant:
	if not value is int and not value is float:
		return null
	var number: float = float(value)
	return (
		null
		if not is_finite(number) or number != floor(number) or number < minimum or number > maximum
		else int(number)
	)


static func _chunk(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(cell.x) / float(CHUNK_SIZE)), floori(float(cell.y) / float(CHUNK_SIZE))
	)


static func _record_less(first: Dictionary, second: Dictionary) -> bool:
	var first_anchor: Array = first[&"anchor"] as Array
	var second_anchor: Array = second[&"anchor"] as Array
	var first_chunk: Vector2i = _chunk(Vector2i(int(first_anchor[0]), int(first_anchor[1])))
	var second_chunk: Vector2i = _chunk(Vector2i(int(second_anchor[0]), int(second_anchor[1])))
	if first_chunk != second_chunk:
		return first_chunk.y < second_chunk.y or (
			first_chunk.y == second_chunk.y and first_chunk.x < second_chunk.x
		)
	return str(first[&"stable_id"]) < str(second[&"stable_id"])


static func _cell_less(first: Array, second: Array) -> bool:
	return first[1] < second[1] or (first[1] == second[1] and first[0] < second[0])


static func _exact_keys(value: Dictionary, expected: Array[StringName]) -> bool:
	if value.size() != expected.size():
		return false
	for key: StringName in expected:
		if not value.has(key):
			return false
	return true


static func _result(ok: bool, ledger: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": ledger.duplicate(true), &"reason": reason}
