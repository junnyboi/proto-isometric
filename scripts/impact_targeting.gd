extends RefCounted

const ModuleEffectsScript: GDScript = preload("res://scripts/module_effects.gd")


static func scan(
	cells: Array[Vector2i],
	sandworms: Node2D,
	destructible_rocks: Dictionary,
) -> Dictionary:
	var rock_cells: Array[Vector2i] = []
	var worm_ids: Array[int] = []
	var target_cell: Vector2i = cells[0] if not cells.is_empty() else Vector2i.ZERO
	var target_found: bool = false
	for cell: Vector2i in cells:
		var worm_id: int = int(sandworms.call("find_target", cell)) if sandworms != null else -1
		if worm_id >= 0 and worm_id not in worm_ids:
			worm_ids.append(worm_id)
		if bool(destructible_rocks.get(cell, false)):
			rock_cells.append(cell)
		if not target_found and (worm_id >= 0 or bool(destructible_rocks.get(cell, false))):
			target_cell = cell
			target_found = true
	return {&"rock_cells": rock_cells, &"worm_ids": worm_ids, &"target_cell": target_cell}


static func break_props(
	world_objects: Node2D, rock_cells: Array[Vector2i], break_callback: Callable
) -> Array[Dictionary]:
	var broken: Array[Dictionary] = []
	for cell: Vector2i in rock_cells:
		var kind: StringName = world_objects.call("get_destructible_kind", cell) as StringName
		if bool(break_callback.call(cell)):
			broken.append({&"cell": cell, &"kind": kind})
	return broken


static func hit_worms(
	sandworms: Node2D,
	worm_ids: Array[int],
	impact_band: int,
	coordinator: RefCounted,
	source_position: Vector2 = Vector2.ZERO,
) -> Dictionary:
	var hits: int = 0
	var destroyed: int = 0
	var last_health: int = -1
	var targets: Array[Dictionary] = []
	for worm_id: int in worm_ids:
		if sandworms == null:
			continue
		var before: Dictionary = sandworms.call("get_combat_snapshot", worm_id) as Dictionary
		if before.is_empty() or not bool(sandworms.call("hit_worm", worm_id, 1)):
			continue
		hits += 1
		last_health = int(sandworms.call("get_health", worm_id))
		var after: Dictionary = sandworms.call("get_combat_snapshot", worm_id) as Dictionary
		var position: Vector2 = before.get(&"position", source_position) as Vector2
		(
			targets
			. append(
				{
					&"target_id": worm_id,
					&"kind": before.get(&"kind", &"sandworm"),
					&"position": position,
					&"direction": (position - source_position).normalized(),
					&"health_before": int(before.get(&"health", -1)),
					&"health_after": last_health,
					&"state_before": before.get(&"state", &"missing"),
					&"state_after": after.get(&"state", &"missing"),
					&"accepted": true,
					&"defeated": last_health <= 0,
				}
			)
		)
		if last_health <= 0:
			destroyed += 1
		elif impact_band >= 2:
			var bonus: float = ModuleEffectsScript.aftershock_stagger(coordinator)
			if bonus > 0.0:
				sandworms.call("stagger_worm", worm_id, bonus)
			else:
				sandworms.call("stagger_worm", worm_id)
	return {
		&"hits": hits,
		&"destroyed": destroyed,
		&"last_health": last_health,
		&"targets": targets,
	}
