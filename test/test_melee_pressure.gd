extends RefCounted

const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const MeleePressureScript: GDScript = preload("res://scripts/melee_pressure.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var world: RefCounted = InfiniteWorldScript.new() as RefCounted
	world.call("configure", {}, {}, {}, {}, {}, {})
	var pressure: Node2D = MeleePressureScript.new() as Node2D
	_add(
		cases,
		"melee pressure validates a walkable world",
		bool(pressure.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, world))
	)
	pressure.call("set_player_position", Vector2(10.0, 20.0))
	var spawned: int = int(pressure.call("spawn_pack", Vector2(10.0, 20.0), 99))
	_add(
		cases,
		"Razor Mite population is hard-capped at twelve",
		spawned == MeleePressureScript.MAX_MITES and int(pressure.call("get_count")) == 12,
	)
	var snapshots: Array[Dictionary] = pressure.call("get_combat_snapshots") as Array[Dictionary]
	_add(
		cases,
		"melee pack enters from multiple flanks",
		_covers_four_flanks(snapshots, Vector2(10.0, 20.0))
	)
	var damage_events: Array[int] = []
	pressure.connect(
		"damage_tick",
		func(amount: int, _source: StringName) -> void: damage_events.append(amount),
	)
	var warning_seen: bool = false
	for _step: int in range(70):
		pressure.call("advance", 0.1)
		for snapshot: Dictionary in pressure.call("get_combat_snapshots") as Array[Dictionary]:
			warning_seen = warning_seen or snapshot[&"state"] == MeleePressureScript.STATE_WARNING
	_add(cases, "Razor Mites telegraph before contact damage", warning_seen)
	_add(
		cases,
		"shared damage token prevents pack-size burst damage",
		(
			not damage_events.is_empty()
			and damage_events.size() <= 7
			and damage_events.all(
				func(amount: int) -> bool: return amount == MeleePressureScript.ATTACK_DAMAGE
			)
		),
	)
	pressure.call("set_sanctuary_active", true)
	for _step: int in range(12):
		pressure.call("advance", 0.1)
	_add(cases, "sanctuary disperses the complete melee pack", int(pressure.call("get_count")) == 0)
	_add(
		cases,
		"sanctuary blocks replacement packs",
		int(pressure.call("spawn_pack", Vector2(10.0, 20.0), 4)) == 0,
	)
	pressure.free()
	_test_sanctuary_damage_guard(cases, world)
	_test_shared_targeting(cases, world)
	return cases


static func _test_sanctuary_damage_guard(cases: Array[Dictionary], world: RefCounted) -> void:
	var pressure: Node2D = MeleePressureScript.new() as Node2D
	pressure.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, world)
	pressure.call("set_player_position", Vector2(10.0, 20.0))
	pressure.call("spawn_pack", Vector2(10.0, 20.0), 1)
	var mites: Array = pressure.get("_mites") as Array
	var mite: Dictionary = mites[0] as Dictionary
	mite[&"position"] = Vector2(10.0, 20.0)
	pressure.call("_set_state", mite, MeleePressureScript.STATE_WARNING, 0.01)
	var hits: Array[int] = []
	pressure.connect("damage_tick", func(_amount: int, _source: StringName) -> void: hits.append(1))
	pressure.set("_sanctuary_active", true)
	pressure.call("advance", 0.02)
	_add(cases, "committed Razor Mite attack cannot damage inside sanctuary", hits.is_empty())
	pressure.free()


static func _test_shared_targeting(cases: Array[Dictionary], world: RefCounted) -> void:
	var enemies: Node2D = SandwormsScript.new() as Node2D
	enemies.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, null, world)
	enemies.call("set_player_position", Vector2(20.0, 20.0))
	_add(
		cases,
		"shared enemy owner spawns a four-member melee pack",
		int(enemies.call("_spawn_melee_pack", Vector2(20.0, 20.0), 4)) == 4,
	)
	var pressure: Node2D = enemies.call("_get_melee_pressure") as Node2D
	var first: Dictionary = (pressure.call("get_combat_snapshots") as Array[Dictionary])[0]
	var target_cell: Vector2i = Vector2i((first[&"position"] as Vector2).round())
	var target_id: int = int(enemies.call("find_target", target_cell))
	_add(cases, "Smash targeting acquires Razor Mites", target_id >= MeleePressureScript.ID_BASE)
	_add(
		cases,
		"one accepted impact destroys melee fodder",
		(
			bool(enemies.call("hit_worm", target_id, 1))
			and int(enemies.call("get_health", target_id)) == 0
		),
	)
	enemies.free()


static func _covers_four_flanks(snapshots: Array[Dictionary], center: Vector2) -> bool:
	var quadrants: Dictionary = {}
	for snapshot: Dictionary in snapshots:
		var offset: Vector2 = (snapshot[&"position"] as Vector2) - center
		quadrants[Vector2i(1 if offset.x >= 0.0 else -1, 1 if offset.y >= 0.0 else -1)] = true
	return quadrants.size() == 4


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
