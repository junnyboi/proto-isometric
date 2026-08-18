extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const STARTER_RELAY: Vector2i = Vector2i(12, 6)
const SEARCH_LIMIT: int = 256
const MIN_SEPARATION: float = 18.0
const TARGET_RADII: Array[int] = [30, 48]


static func generate(seed: int, world: RefCounted) -> Array[Dictionary]:
	if world == null:
		return []
	var objectives: Array[Dictionary] = [
		{&"objective_id": RuntimeIdsScript.OBJECTIVE_STARTER_RELAY, &"cell": STARTER_RELAY}
	]
	var ids: Array[StringName] = [
		RuntimeIdsScript.OBJECTIVE_RELAY_TWO,
		RuntimeIdsScript.OBJECTIVE_RELAY_THREE,
	]
	for index: int in range(ids.size()):
		var cell: Vector2i = _find_candidate(seed, index, world, objectives)
		if cell == Vector2i(1_000_001, 1_000_001):
			return []
		objectives.append({&"objective_id": ids[index], &"cell": cell})
	return objectives


static func _find_candidate(
	seed: int,
	index: int,
	world: RefCounted,
	chosen: Array[Dictionary],
) -> Vector2i:
	var base_angle: float = float(posmod(seed * 37 + index * 131, 360)) * PI / 180.0
	for attempt: int in range(SEARCH_LIMIT):
		var angle: float = base_angle + float(attempt) * 2.399963
		var radius: float = float(TARGET_RADII[index] + attempt / 32)
		var cell: Vector2i = (
			STARTER_RELAY + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius))
		)
		if not bool(world.call("_relay_candidate_is_valid", cell)):
			continue
		var separated: bool = true
		for objective: Dictionary in chosen:
			if Vector2(cell).distance_to(Vector2(objective[&"cell"])) < MIN_SEPARATION:
				separated = false
				break
		if separated:
			return cell
	return Vector2i(1_000_001, 1_000_001)
