extends RefCounted

const ClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")

const MIN_CELL: Vector2i = ClearingScript.CENTER - Vector2i(15, 15)
const MAX_CELL: Vector2i = ClearingScript.CENTER + Vector2i(15, 15)
const MAX_VISITS: int = 961
const MAX_NEIGHBOR_TESTS: int = 3_844
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
]


static func validate(
	blocked: Dictionary, start: Vector2i, required: Array[Vector2i]
) -> Dictionary:
	if not in_bounds(start) or blocked.has(start):
		return _result(false, 0, 0, required)
	var queue: Array[Vector2i] = [start]
	var cursor: int = 0
	var visited: Dictionary = {start: true}
	var neighbor_tests: int = 0
	while cursor < queue.size() and cursor < MAX_VISITS:
		var cell: Vector2i = queue[cursor]
		cursor += 1
		for direction: Vector2i in DIRECTIONS:
			neighbor_tests += 1
			var next: Vector2i = cell + direction
			if not in_bounds(next) or blocked.has(next) or visited.has(next):
				continue
			visited[next] = true
			queue.append(next)
	var unreachable: Array[Vector2i] = []
	var unique_required: Dictionary = {}
	for cell: Vector2i in required:
		unique_required[cell] = true
	for value: Variant in unique_required:
		var cell: Vector2i = value as Vector2i
		if not in_bounds(cell) or not visited.has(cell):
			unreachable.append(cell)
	unreachable.sort_custom(_cell_precedes)
	var bounded: bool = cursor <= MAX_VISITS and neighbor_tests <= MAX_NEIGHBOR_TESTS
	return _result(bounded and unreachable.is_empty(), cursor, neighbor_tests, unreachable)


static func required_gate_approaches() -> Array[Vector2i]:
	return [
		Vector2i(8, -2),
		Vector2i(20, 10),
		Vector2i(8, 22),
		Vector2i(-4, 10),
	]


static func in_bounds(cell: Vector2i) -> bool:
	return (
		cell.x >= MIN_CELL.x
		and cell.x <= MAX_CELL.x
		and cell.y >= MIN_CELL.y
		and cell.y <= MAX_CELL.y
	)


static func _result(
	ok: bool, visits: int, neighbor_tests: int, unreachable: Array[Vector2i]
) -> Dictionary:
	return {
		&"ok": ok,
		&"visits": visits,
		&"neighbor_tests": neighbor_tests,
		&"unreachable": unreachable.duplicate(),
	}


static func _cell_precedes(first: Vector2i, second: Vector2i) -> bool:
	return first.y < second.y or (first.y == second.y and first.x < second.x)
