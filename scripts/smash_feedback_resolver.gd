extends RefCounted

const BiomeDestructiblesScript: GDScript = preload("res://scripts/biome_destructibles.gd")
const FeedbackEventScript: GDScript = preload("res://scripts/feedback_event.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")


static func present(
	router: Node,
	worm_result: Dictionary,
	broken_props: Array[Dictionary],
	impact_band: int,
	source_grid: Vector2,
	fallback_cell: Vector2i,
	grid_to_screen: Callable,
) -> int:
	if router == null or not grid_to_screen.is_valid():
		return 0
	var submitted: int = 0
	for target: Dictionary in worm_result.get(&"targets", []) as Array[Dictionary]:
		if not bool(target.get(&"accepted", false)):
			continue
		var target_grid: Vector2 = target.get(&"position", source_grid) as Vector2
		var event_id: StringName = RuntimeIdsScript.EVENT_SMASH_HIT
		if bool(target.get(&"defeated", false)):
			event_id = RuntimeIdsScript.EVENT_SMASH_DEFEAT
		elif impact_band >= 2:
			event_id = RuntimeIdsScript.EVENT_SMASH_HEAVY_HIT
		var event: Dictionary = (
			FeedbackEventScript
			. create(
				event_id,
				grid_to_screen.call(Vector2i(target_grid.round())) as Vector2,
				target_grid - source_grid,
				impact_band,
				&"armored_fauna",
				int(target.get(&"target_id", -1)),
				target,
			)
		)
		submitted += 1 if bool(router.call("submit", event)) else 0
	for prop: Dictionary in broken_props:
		var cell: Vector2i = prop.get(&"cell", fallback_cell) as Vector2i
		var kind: StringName = prop.get(&"kind", BiomeDestructiblesScript.KIND_DESERT_ROCK)
		var event: Dictionary = (
			FeedbackEventScript
			. create(
				RuntimeIdsScript.EVENT_SMASH_BREAK,
				grid_to_screen.call(cell) as Vector2,
				Vector2(cell) - source_grid,
				impact_band,
				BiomeDestructiblesScript.material_family_for(kind),
				-1,
				prop,
			)
		)
		submitted += 1 if bool(router.call("submit", event)) else 0
	if submitted == 0:
		var miss: Dictionary = (
			FeedbackEventScript
			. create(
				RuntimeIdsScript.EVENT_SMASH_WHIFF,
				grid_to_screen.call(fallback_cell) as Vector2,
				Vector2(fallback_cell) - source_grid,
				impact_band,
				&"air",
			)
		)
		submitted += 1 if bool(router.call("submit", miss)) else 0
	return submitted
