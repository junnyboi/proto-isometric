extends RefCounted

const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const MeleePressureScript: GDScript = preload("res://scripts/melee_pressure.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")

const BIOME_CASES: Array[Dictionary] = [
	{
		&"biome": &"desert",
		&"kind": &"glassback_scarab",
		&"name_key": &"enemy.glassback_scarab.name",
		&"damage": 2,
	},
	{
		&"biome": &"oasis",
		&"kind": &"mire_tick",
		&"name_key": &"enemy.mire_tick.name",
		&"damage": 2,
	},
	{
		&"biome": &"frozen",
		&"kind": &"rime_shardling",
		&"name_key": &"enemy.rime_shardling.name",
		&"damage": 2,
	},
	{
		&"biome": &"lava",
		&"kind": &"ember_skitter",
		&"name_key": &"enemy.ember_skitter.name",
		&"damage": 3,
	},
]


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var world: RefCounted = InfiniteWorldScript.new() as RefCounted
	world.call("configure", {}, {}, {}, {}, {}, {})
	_test_biome_roster(cases, world)
	_test_emergence_and_bounce(cases, world)
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
		"tiny-mob population is hard-capped at twelve",
		spawned == MeleePressureScript.MAX_MITES and int(pressure.call("get_count")) == 12,
	)
	var snapshots: Array[Dictionary] = pressure.call("get_combat_snapshots") as Array[Dictionary]
	_add(
		cases,
		"melee pack enters from multiple flanks",
		_covers_four_flanks(snapshots, Vector2(10.0, 20.0))
	)
	var damage_events: Array[Dictionary] = []
	pressure.connect(
		"damage_tick",
		func(amount: int, source: StringName) -> void:
			damage_events.append({&"amount": amount, &"source": source}),
	)
	var warning_seen: bool = false
	for _step: int in range(70):
		pressure.call("advance", 0.1)
		for snapshot: Dictionary in pressure.call("get_combat_snapshots") as Array[Dictionary]:
			warning_seen = warning_seen or snapshot[&"state"] == MeleePressureScript.STATE_WARNING
	_add(cases, "tiny mobs preserve a warning delay before contact damage", warning_seen)
	var damage_events_are_valid: bool = not damage_events.is_empty() and damage_events.size() <= 7
	for event: Dictionary in damage_events:
		damage_events_are_valid = (
			damage_events_are_valid
			and int(event[&"amount"]) == MeleePressureScript.ATTACK_DAMAGE
			and event[&"source"] == MeleePressureScript.GLASSBACK_SCARAB_KIND
		)
	_add(
		cases,
		"shared damage token prevents pack-size burst damage",
		damage_events_are_valid,
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
	_test_biome_transition(cases, world)
	_test_ember_damage_profile(cases, world)
	return cases


static func _test_biome_roster(cases: Array[Dictionary], world: RefCounted) -> void:
	for config: Dictionary in BIOME_CASES:
		var pressure: Node2D = MeleePressureScript.new() as Node2D
		pressure.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, world)
		pressure.call("_set_active_biome", config[&"biome"])
		pressure.call("set_player_position", Vector2(10.0, 20.0))
		pressure.call("spawn_pack", Vector2(10.0, 20.0), 1)
		var snapshots: Array[Dictionary] = (
			pressure.call("get_combat_snapshots") as Array[Dictionary]
		)
		var emerging_cell: Vector2i = Vector2i((snapshots[0][&"position"] as Vector2).round())
		var hidden_while_emerging: bool = (
			(pressure.call("get_hover_targets") as Array[Dictionary]).is_empty()
			and int(pressure.call("find_target", emerging_cell)) == -1
		)
		_finish_emergence(pressure)
		var hover_targets: Array[Dictionary] = pressure.call("get_hover_targets") as Array[Dictionary]
		var expected_kind: StringName = config[&"kind"] as StringName
		var texture: Texture2D = MeleePressureScript._texture_for(expected_kind)
		_add(
			cases,
			"%s selects its native tiny-mob kind" % String(config[&"biome"]),
			(
				pressure.call("_get_active_kind") == expected_kind
				and snapshots.size() == 1
				and snapshots[0][&"kind"] == expected_kind
				and hidden_while_emerging
			),
		)
		_add(
			cases,
			"%s tiny-mob sprite imports at 512 pixels" % String(expected_kind),
			texture != null and texture.get_size() == Vector2(512.0, 512.0),
		)
		_add(
			cases,
			"%s exposes localized identity and tuned damage" % String(expected_kind),
			(
				hover_targets.size() == 1
				and hover_targets[0][&"name_key"] == config[&"name_key"]
				and int(hover_targets[0][&"attack_damage"]) == int(config[&"damage"])
			),
		)
		pressure.free()


static func _test_emergence_and_bounce(cases: Array[Dictionary], world: RefCounted) -> void:
	var pressure: Node2D = MeleePressureScript.new() as Node2D
	pressure.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, world)
	pressure.call("set_player_position", Vector2(10.0, 20.0))
	pressure.call("spawn_pack", Vector2(10.0, 20.0), 1)
	var snapshot: Dictionary = (pressure.call("get_combat_snapshots") as Array[Dictionary])[0]
	_add(
		cases,
		"new tiny mobs begin in a noninteractive emergence state",
		(
			snapshot[&"state"] == MeleePressureScript.STATE_EMERGE
			and (pressure.call("get_hover_targets") as Array[Dictionary]).is_empty()
		),
	)
	var start: float = MeleePressureScript._emergence_progress(MeleePressureScript.EMERGE_SECONDS)
	var middle: float = MeleePressureScript._emergence_progress(
		MeleePressureScript.EMERGE_SECONDS * 0.5
	)
	var finish: float = MeleePressureScript._emergence_progress(0.0)
	_add(
		cases,
		"burrow emergence fades smoothly from hidden to visible",
		is_zero_approx(start) and middle > start and middle < finish and is_equal_approx(finish, 1.0),
	)
	var idle_bounce: float = MeleePressureScript._bounce_offset(
		0.2, 0.0, MeleePressureScript.STATE_EMERGE
	)
	var moving_bounce: float = MeleePressureScript._bounce_offset(
		PI / (2.0 * MeleePressureScript.BOUNCE_RATE),
		0.0,
		MeleePressureScript.STATE_ADVANCE,
	)
	_add(
		cases,
		"tiny-mob bounce is subtle and limited to locomotion",
		(
			is_zero_approx(idle_bounce)
			and moving_bounce > 0.0
			and moving_bounce <= MeleePressureScript.BOUNCE_HEIGHT
		),
	)
	_finish_emergence(pressure)
	_add(
		cases,
		"emergence transitions into active movement",
		pressure.call("get_state", int(snapshot[&"id"])) == MeleePressureScript.STATE_ADVANCE,
	)
	pressure.free()


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
	_add(cases, "committed tiny-mob attack cannot damage inside sanctuary", hits.is_empty())
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
	_finish_emergence(pressure)
	var first: Dictionary = (pressure.call("get_combat_snapshots") as Array[Dictionary])[0]
	var target_cell: Vector2i = Vector2i((first[&"position"] as Vector2).round())
	var target_id: int = int(enemies.call("find_target", target_cell))
	_add(cases, "Smash targeting acquires tiny mobs", target_id >= MeleePressureScript.ID_BASE)
	_add(
		cases,
		"one accepted impact destroys melee fodder",
		(
			bool(enemies.call("hit_worm", target_id, 1))
			and int(enemies.call("get_health", target_id)) == 0
		),
	)
	enemies.free()


static func _test_biome_transition(cases: Array[Dictionary], world: RefCounted) -> void:
	var enemies: Node2D = SandwormsScript.new() as Node2D
	enemies.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, null, world)
	enemies.call("_set_active_biome", &"oasis")
	enemies.call("_spawn_melee_pack", Vector2(20.0, 20.0), 1)
	var pressure: Node2D = enemies.call("_get_melee_pressure") as Node2D
	var wetland: Dictionary = (pressure.call("get_combat_snapshots") as Array[Dictionary])[0]
	enemies.call("_set_active_biome", &"frozen")
	var cleared: bool = int(pressure.call("get_count")) == 0
	enemies.call("_spawn_melee_pack", Vector2(20.0, 20.0), 1)
	var frozen: Dictionary = (pressure.call("get_combat_snapshots") as Array[Dictionary])[0]
	_add(
		cases,
		"biome transition clears old mobs and switches native kind",
		(
			wetland[&"kind"] == MeleePressureScript.MIRE_TICK_KIND
			and cleared
			and frozen[&"kind"] == MeleePressureScript.RIME_SHARDLING_KIND
		),
	)
	enemies.free()


static func _test_ember_damage_profile(cases: Array[Dictionary], world: RefCounted) -> void:
	var pressure: Node2D = MeleePressureScript.new() as Node2D
	pressure.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, world)
	pressure.call("_set_active_biome", &"lava")
	pressure.call("set_player_position", Vector2(10.0, 20.0))
	pressure.call("spawn_pack", Vector2(10.0, 20.0), 1)
	var mite: Dictionary = (pressure.get("_mites") as Array)[0] as Dictionary
	mite[&"position"] = Vector2(10.0, 20.0)
	pressure.call("_set_state", mite, MeleePressureScript.STATE_WARNING, 0.01)
	var events: Array[Dictionary] = []
	pressure.connect(
		"damage_tick",
		func(amount: int, source: StringName) -> void:
			events.append({&"amount": amount, &"source": source}),
	)
	pressure.call("advance", 0.02)
	_add(
		cases,
		"Ember Skitter emits its heavier biome-specific contact damage",
		(
			events.size() == 1
			and int(events[0][&"amount"]) == 3
			and events[0][&"source"] == MeleePressureScript.EMBER_SKITTER_KIND
		),
	)
	pressure.free()


static func _finish_emergence(pressure: Node2D) -> void:
	for _step: int in range(ceili(MeleePressureScript.EMERGE_SECONDS / 0.1) + 1):
		pressure.call("advance", 0.1)


static func _covers_four_flanks(snapshots: Array[Dictionary], center: Vector2) -> bool:
	var quadrants: Dictionary = {}
	for snapshot: Dictionary in snapshots:
		var offset: Vector2 = (snapshot[&"position"] as Vector2) - center
		quadrants[Vector2i(1 if offset.x >= 0.0 else -1, 1 if offset.y >= 0.0 else -1)] = true
	return quadrants.size() == 4


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
