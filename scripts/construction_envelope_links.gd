extends RefCounted

const CatalogScript: GDScript = preload("res://scripts/construction_blueprint_catalog.gd")
const LedgerScript: GDScript = preload("res://scripts/world_mutation_ledger.gd")


static func validate(envelope: Dictionary) -> bool:
	if not envelope.has(&"world") or not envelope.has(&"farm"):
		return false
	var world: Dictionary = envelope[&"world"] as Dictionary
	var farm: Dictionary = envelope[&"farm"] as Dictionary
	var ledger: Dictionary = (
		LedgerScript.validate(world[&"mutation_ledger"])
		if world.has(&"mutation_ledger")
		else LedgerScript.from_legacy(world)
	)
	if ledger.is_empty():
		return false
	var buildings: Array[Dictionary] = _buildings(farm)
	var placements: Array[Dictionary] = []
	for record: Dictionary in ledger[&"placed"] as Array[Dictionary]:
		if StringName(str(record[&"kind"])) == CatalogScript.LEDGER_KIND:
			placements.append(record)
	if placements.size() != buildings.size():
		return false
	var used: Dictionary = {}
	for building: Dictionary in buildings:
		var matched: int = -1
		for index: int in placements.size():
			if used.has(index):
				continue
			if _record_matches(building, placements[index]):
				matched = index
				break
		if matched < 0:
			return false
		used[matched] = true
	return used.size() == placements.size()


static func ledger_record(building: Dictionary) -> Dictionary:
	var blueprint_id: StringName = StringName(str(building.get(&"blueprint_id", "")))
	var anchor_value: Variant = building.get(&"anchor")
	var orientation: int = int(building.get(&"orientation", -1))
	if str(blueprint_id).is_empty() or not anchor_value is Array:
		return {}
	var anchor: Array = anchor_value as Array
	if anchor.size() != 2 or orientation < 0 or orientation > 3:
		return {}
	var anchor_cell: Vector2i = Vector2i(int(anchor[0]), int(anchor[1]))
	var footprint: Array[Vector2i] = []
	for encoded: Array in building.get(&"footprint", []) as Array[Array]:
		footprint.append(
			Vector2i(int(encoded[0]), int(encoded[1])) - anchor_cell
		)
	return LedgerScript.make_placed(
		CatalogScript.LEDGER_KIND, anchor_cell, footprint
	)


static func changed_cells(before: Dictionary, after: Dictionary) -> Array[Vector2i]:
	var unique: Dictionary = {}
	for record: Dictionary in [before, after]:
		if record.is_empty():
			continue
		for encoded: Array in record.get(&"footprint", []) as Array[Array]:
			unique[Vector2i(int(encoded[0]), int(encoded[1]))] = true
	var result: Array[Vector2i] = []
	for value: Variant in unique:
		result.append(value as Vector2i)
	result.sort_custom(_cell_precedes)
	return result


static func _record_matches(building: Dictionary, placement: Dictionary) -> bool:
	var blueprint_id: StringName = StringName(str(building[&"blueprint_id"]))
	if (
		CatalogScript.definition(blueprint_id).is_empty()
		or int(building[&"level"]) < 1
		or int(building[&"level"]) > CatalogScript.MAX_LEVEL
	):
		return false
	var anchor: Array = building[&"anchor"] as Array
	var canonical: Array[Array] = CatalogScript.encoded_footprint(
			blueprint_id,
			Vector2i(int(anchor[0]), int(anchor[1])),
			int(building[&"orientation"]),
	)
	if building[&"footprint"] != canonical:
		return false
	var expected: Dictionary = ledger_record(building)
	return not expected.is_empty() and placement == expected


static func _buildings(farm: Dictionary) -> Array[Dictionary]:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var construction: Dictionary = homestead.get(&"construction", {}) as Dictionary
	return construction.get(&"buildings", []) as Array[Dictionary]


static func _cell_precedes(first: Vector2i, second: Vector2i) -> bool:
	return first.y < second.y or (first.y == second.y and first.x < second.x)
