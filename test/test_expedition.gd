extends RefCounted

const EncounterDirectorScript: GDScript = preload("res://scripts/encounter_director.gd")
const ExpeditionLayoutScript: GDScript = preload("res://scripts/expedition_layout.gd")
const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const RunCoordinatorScript: GDScript = preload("res://scripts/run_coordinator.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const DesertHazardsScript: GDScript = preload("res://scripts/desert_hazards.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var world: RefCounted = InfiniteWorldScript.new() as RefCounted
	world.call("configure", {}, {}, {}, {}, {}, {})
	var before: int = int(world.call("get_loaded_chunk_count"))
	var first: Array[Dictionary] = ExpeditionLayoutScript.generate(0, world)
	var second: Array[Dictionary] = ExpeditionLayoutScript.generate(0, world)
	_add(
		cases,
		"expedition places exactly three deterministic relays",
		first.size() == 3 and first == second
	)
	_add(
		cases,
		"layout search loads no candidate chunks",
		int(world.call("get_loaded_chunk_count")) == before
	)
	_add(cases, "relay objectives are separated and terrain-valid", _layout_is_valid(first, world))
	_add(cases, "64-seed relay layout sweep is deterministic and terrain-valid", _seed_sweep(world))

	var coordinator: RefCounted = RunCoordinatorScript.new() as RefCounted
	coordinator.call("configure_default")
	_add(
		cases,
		"typed run accepts one immutable relay layout",
		bool(coordinator.call("_configure_relay_objectives", first))
	)
	_add(
		cases,
		"typed run rejects layout replacement",
		not bool(coordinator.call("_configure_relay_objectives", second))
	)
	_add(
		cases,
		"relay credit rejects out-of-order objective",
		not bool(coordinator.call("_complete_next_relay", RuntimeIdsScript.OBJECTIVE_RELAY_TWO))
	)
	_add(
		cases,
		"relay one credits Alert I",
		(
			bool(coordinator.call("_complete_next_relay", RuntimeIdsScript.OBJECTIVE_STARTER_RELAY))
			and int(coordinator.call("get_run_value", &"completed_relays")) == 1
		)
	)

	var worms: Node2D = SandwormsScript.new() as Node2D
	worms.call("configure", Vector2(90.0, 45.0), Vector2.ZERO)
	var hazards: Node2D = DesertHazardsScript.new() as Node2D
	hazards.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, Vector2i(14, 11))
	var director: Node = EncounterDirectorScript.new() as Node
	_add(
		cases,
		"Alert director validates all three profiles",
		bool(director.call("configure", coordinator, world, worms, hazards))
	)
	director.call("set_ambient_enabled", false)
	director.call("_process", 4.1)
	_add(
		cases,
		"Alert I deploys exactly one hunter",
		int(worms.call("get_worm_count")) == 1 and int(hazards.call("get_hazard_count")) == 0
	)
	director.call("_process", 20.0)
	_add(cases, "Alert I composition cannot duplicate", int(worms.call("get_worm_count")) == 1)
	worms.call("clear_worms")
	coordinator.call("_complete_next_relay", RuntimeIdsScript.OBJECTIVE_RELAY_TWO)
	director.call("_process", 4.1)
	_add(
		cases,
		"Alert II deploys hunter plus two tornadoes",
		(
			int(worms.call("get_worm_count")) == 1
			and int(hazards.call("get_hazard_count", &"tornado")) == 2
		)
	)
	worms.call("clear_worms")
	hazards.call("clear_hazards")
	coordinator.call("set_run_value", &"player_cell", Vector2i(8, 4))
	coordinator.call("_complete_next_relay", RuntimeIdsScript.OBJECTIVE_RELAY_THREE)
	_add(
		cases,
		"three ordered relays unlock extraction phase",
		coordinator.call("get_run_value", &"phase") == RuntimeIdsScript.RUN_PHASE_EXTRACTION_READY,
	)
	director.call("_process", 4.1)
	_add(
		cases,
		"outpost sanctuary suppresses Alert III spawn",
		int(worms.call("get_worm_count")) == 0 and int(hazards.call("get_hazard_count")) == 0
	)
	coordinator.call("set_run_value", &"player_cell", Vector2i(22, 22))
	director.call("_process", 4.1)
	_add(
		cases,
		"Alert III deploys hunter plus broad storm after sanctuary",
		(
			int(worms.call("get_worm_count")) == 1
			and int(hazards.call("get_hazard_count", &"sandstorm")) == 1
		)
	)
	worms.free()
	hazards.free()
	director.free()
	_test_ambient_pressure(cases, world)
	return cases


static func _test_ambient_pressure(cases: Array[Dictionary], world: RefCounted) -> void:
	var coordinator: RefCounted = RunCoordinatorScript.new() as RefCounted
	coordinator.call("configure_default")
	coordinator.call("set_run_value", &"player_cell", Vector2i(22, 22))
	var worms: Node2D = SandwormsScript.new() as Node2D
	worms.call("configure", Vector2(90.0, 45.0), Vector2.ZERO)
	var hazards: Node2D = DesertHazardsScript.new() as Node2D
	hazards.call("configure", Vector2(90.0, 45.0), Vector2.ZERO, Vector2i(14, 11))
	var director: Node = EncounterDirectorScript.new() as Node
	_add(
		cases,
		"ambient director configures independently of relay alerts",
		bool(director.call("configure", coordinator, world, worms, hazards)),
	)
	_add(
		cases,
		"normal departure quotas remain doubled",
		(
			EncounterDirectorScript.INITIAL_WORM_SOFT_CAP == 1
			and int(director.call("get_worm_soft_cap")) == 1
			and EncounterDirectorScript.AMBIENT_WORM_SOFT_CAP == 4
			and EncounterDirectorScript.AMBIENT_TORNADO_SOFT_CAP == 6
			and EncounterDirectorScript.AMBIENT_SANDSTORM_SOFT_CAP == 2
		),
	)
	director.call("_process", 2.9)
	_add(
		cases,
		"ambient threats preserve a short departure grace period",
		int(worms.call("get_worm_count")) == 0 and int(hazards.call("get_hazard_count")) == 0,
	)
	director.call("_process", 0.2)
	_add(
		cases, "ambient hunter arrives within four seconds", int(worms.call("get_worm_count")) == 1
	)
	coordinator.call("set_run_value", &"starter_relay_completed", true)
	director.call("_process", 4.1)
	_add(
		cases,
		"initial relay alert cannot add a second worm",
		int(worms.call("get_worm_count")) == 1,
	)
	director.call("_process", 1.0)
	_add(
		cases,
		"ambient tornado arrives within five seconds",
		int(hazards.call("get_hazard_count", &"tornado")) == 1,
	)
	director.call("_process", 4.0)
	_add(
		cases,
		"ambient broad storm arrives within nine seconds",
		int(hazards.call("get_hazard_count", &"sandstorm")) == 1,
	)
	for _interval: int in range(6):
		director.call("_process", 14.0)
	_add(
		cases,
		"worm population stays at one before the first defeat",
		(
			int(worms.call("get_worm_count")) == EncounterDirectorScript.INITIAL_WORM_SOFT_CAP
			and (
				int(hazards.call("get_hazard_count", &"tornado"))
				== EncounterDirectorScript.AMBIENT_TORNADO_SOFT_CAP
			)
			and (
				int(hazards.call("get_hazard_count", &"sandstorm"))
				== EncounterDirectorScript.AMBIENT_SANDSTORM_SOFT_CAP
			)
		),
	)
	coordinator.call("set_run_value", &"first_worm_defeated", true)
	for _interval: int in range(3):
		director.call("_process", 14.0)
	_add(
		cases,
		"first worm defeat restores the normal population quota",
		(
			int(director.call("get_worm_soft_cap")) == EncounterDirectorScript.AMBIENT_WORM_SOFT_CAP
			and int(worms.call("get_worm_count")) == EncounterDirectorScript.AMBIENT_WORM_SOFT_CAP
		),
	)
	worms.call("clear_worms")
	hazards.call("clear_hazards")
	coordinator.call("set_run_value", &"player_cell", Vector2i(8, 4))
	director.call("_process", 100.0)
	_add(
		cases,
		"outpost sanctuary suppresses ambient threats",
		int(worms.call("get_worm_count")) == 0 and int(hazards.call("get_hazard_count")) == 0,
	)
	coordinator.call("set_run_value", &"player_cell", Vector2i(22, 22))
	director.call("_process", 2.9)
	_add(
		cases,
		"leaving sanctuary restores the departure grace period",
		int(worms.call("get_worm_count")) == 0 and int(hazards.call("get_hazard_count")) == 0,
	)
	worms.free()
	hazards.free()
	director.free()


static func _layout_is_valid(objectives: Array[Dictionary], world: RefCounted) -> bool:
	for index: int in range(objectives.size()):
		var cell: Vector2i = objectives[index][&"cell"] as Vector2i
		if not bool(world.call("_relay_candidate_is_valid", cell)):
			return false
		for other: int in range(index):
			if Vector2(cell).distance_to(Vector2(objectives[other][&"cell"])) < 18.0:
				return false
	return true


static func _seed_sweep(world: RefCounted) -> bool:
	var before: int = int(world.call("get_loaded_chunk_count"))
	for seed: int in range(64):
		for modifier: StringName in [
			RuntimeIdsScript.MODIFIER_NEUTRAL, RuntimeIdsScript.MODIFIER_DEAD_GRID
		]:
			var first: Array[Dictionary] = ExpeditionLayoutScript.generate(seed, world, modifier)
			var second: Array[Dictionary] = ExpeditionLayoutScript.generate(seed, world, modifier)
			if first != second or first.size() != 3 or not _layout_is_valid(first, world):
				return false
	return int(world.call("get_loaded_chunk_count")) == before


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
