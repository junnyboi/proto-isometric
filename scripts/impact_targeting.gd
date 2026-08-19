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


static func hit_worms(
	sandworms: Node2D,
	worm_ids: Array[int],
	impact_band: int,
	coordinator: RefCounted,
) -> Dictionary:
	var hits: int = 0
	var destroyed: int = 0
	var last_health: int = -1
	for worm_id: int in worm_ids:
		if sandworms == null or not bool(sandworms.call("hit_worm", worm_id, 1)):
			continue
		hits += 1
		last_health = int(sandworms.call("get_health", worm_id))
		if last_health <= 0:
			destroyed += 1
		elif impact_band >= 2:
			var bonus: float = ModuleEffectsScript.aftershock_stagger(coordinator)
			if bonus > 0.0:
				sandworms.call("stagger_worm", worm_id, bonus)
			else:
				sandworms.call("stagger_worm", worm_id)
	return {&"hits": hits, &"destroyed": destroyed, &"last_health": last_health}
