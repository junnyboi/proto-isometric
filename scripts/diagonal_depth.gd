extends RefCounted

const KIND_TREE: StringName = &"tree"
const KIND_CROP: StringName = &"crop"
const KIND_RESIDENT: StringName = &"resident"
const KIND_STRUCTURE: StringName = &"structure"
const KIND_WALKER: StringName = &"walker"
const SUPPORTED_KINDS: Array[StringName] = [
	KIND_TREE,
	KIND_CROP,
	KIND_RESIDENT,
	KIND_STRUCTURE,
	KIND_WALKER,
]


static func bucket_for(cell: Vector2i) -> int:
	return cell.x + cell.y


static func one_cell_footprint(trunk_cell: Vector2i) -> Array[Vector2i]:
	return [trunk_cell]


static func footprint_for(
	kind: StringName, anchor: Vector2i, size: Vector2i = Vector2i.ONE
) -> Array[Vector2i]:
	if kind in [KIND_TREE, KIND_CROP, KIND_RESIDENT, KIND_WALKER]:
		return one_cell_footprint(anchor)
	var result: Array[Vector2i] = []
	var extent: Vector2i = Vector2i(maxi(size.x, 1), maxi(size.y, 1))
	for y: int in range(extent.y):
		for x: int in range(extent.x):
			result.append(anchor + Vector2i(x, y))
	return result


static func stable_sort(records: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = records.duplicate(true)
	result.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool: return _record_less(first, second)
	)
	return result


static func depth_key(record: Dictionary) -> Array:
	var anchor: Vector2i = record.get(&"anchor", record.get(&"cell", Vector2i.ZERO)) as Vector2i
	var kind: StringName = record.get(&"kind", record.get(&"type", KIND_STRUCTURE)) as StringName
	if kind not in SUPPORTED_KINDS:
		kind = KIND_STRUCTURE
	var footprint: Array[Vector2i] = footprint_for(
		kind,
		anchor,
		record.get(&"size", Vector2i.ONE) as Vector2i,
	)
	var backmost: Vector2i = anchor
	for cell: Vector2i in footprint:
		if bucket_for(cell) > bucket_for(backmost):
			backmost = cell
		elif bucket_for(cell) == bucket_for(backmost) and cell.y > backmost.y:
			backmost = cell
	return [bucket_for(backmost), backmost.y, backmost.x, str(record.get(&"stable_id", ""))]


static func _record_less(first: Dictionary, second: Dictionary) -> bool:
	var first_key: Array = depth_key(first)
	var second_key: Array = depth_key(second)
	for index: int in range(first_key.size()):
		if first_key[index] == second_key[index]:
			continue
		return first_key[index] < second_key[index]
	return false
