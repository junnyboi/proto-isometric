extends RefCounted

const ImpactChargeScript: GDScript = preload("res://scripts/impact_charge.gd")
const ImpactTargetingScript: GDScript = preload("res://scripts/impact_targeting.gd")


class FakeSandworms:
	extends Node2D
	var targets: Dictionary = {}
	var health: Dictionary = {}

	func find_target(cell: Vector2i) -> int:
		return int(targets.get(cell, -1))

	func hit_worm(worm_id: int, damage: int = 1) -> bool:
		if not health.has(worm_id) or damage <= 0:
			return false
		health[worm_id] = maxi(int(health[worm_id]) - damage, 0)
		return true

	func get_health(worm_id: int) -> int:
		return int(health.get(worm_id, -1))

	func stagger_worm(_worm_id: int, _seconds: float = -1.0) -> bool:
		return true


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var impact_charge: Node2D = ImpactChargeScript.new() as Node2D
	var origin: Vector2i = Vector2i(6, 6)
	var arc: Array[Vector2i] = impact_charge.call(
		"attack_footprint", origin, Vector2i.RIGHT, 0
	) as Array[Vector2i]
	_add(
		cases,
		"contact attack covers a two-cell 150-degree forward arc",
		ImpactChargeScript.ATTACK_ARC_DEGREES == 150.0
		and ImpactChargeScript.ATTACK_ARC_RADIUS_CELLS == 2
		and arc.size() == 6
		and Vector2i(6, 5) in arc
		and Vector2i(7, 5) in arc
		and Vector2i(7, 6) in arc
		and Vector2i(6, 4) in arc
		and Vector2i(8, 4) in arc
		and Vector2i(8, 6) in arc,
	)
	_add(
		cases,
		"extended forward attack arc excludes rear cells",
		Vector2i(5, 7) not in arc and Vector2i(4, 8) not in arc,
	)
	var worms: FakeSandworms = FakeSandworms.new()
	worms.targets = {
		Vector2i(6, 5): 11,
		Vector2i(7, 5): 12,
		Vector2i(7, 6): 13,
		Vector2i(5, 7): 14,
		Vector2i(6, 4): 15,
		Vector2i(8, 4): 16,
		Vector2i(8, 6): 17,
	}
	worms.health = {11: 4, 12: 4, 13: 4, 14: 4, 15: 4, 16: 4, 17: 4}
	var targets: Dictionary = ImpactTargetingScript.scan(
		arc, worms, {Vector2i(7, 6): true}
	)
	var worm_ids: Array[int] = targets[&"worm_ids"] as Array[int]
	_add(
		cases,
		"AOE scanner acquires every forward target once",
		worm_ids.size() == 6
		and 11 in worm_ids
		and 12 in worm_ids
		and 13 in worm_ids
		and 15 in worm_ids
		and 16 in worm_ids
		and 17 in worm_ids
		and (targets[&"rock_cells"] as Array).size() == 1,
	)
	var result: Dictionary = ImpactTargetingScript.hit_worms(worms, worm_ids, 0, null)
	_add(
		cases,
		"one AOE strike damages all forward targets",
		int(result[&"hits"]) == 6
		and int(worms.health[11]) == 3
		and int(worms.health[12]) == 3
		and int(worms.health[13]) == 3
		and int(worms.health[15]) == 3
		and int(worms.health[16]) == 3
		and int(worms.health[17]) == 3,
	)
	_add(cases, "AOE strike leaves rear targets intact", int(worms.health[14]) == 4)
	impact_charge.free()
	worms.free()
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
