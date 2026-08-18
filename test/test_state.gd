extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const RunStateScript: GDScript = preload("res://scripts/run_state.gd")
const ProfileStateScript: GDScript = preload("res://scripts/profile_state.gd")


static func evaluate(coordinator: RefCounted) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_run_round_trip(cases)
	_test_profile_round_trip(cases)
	_test_lifecycle_and_idempotency(cases)
	_test_live_coordinator_round_trip(cases, coordinator)
	return cases


static func _test_run_round_trip(cases: Array[Dictionary]) -> void:
	var source: RefCounted = RunStateScript.new() as RefCounted
	_add_case(
		cases,
		"RunState configures typed defaults",
		bool(source.call("configure", &"run.test.7", 17, 100, Vector2i(8, 10), &"SE")),
	)
	_add_case(
		cases,
		"RunState enters hunt once",
		bool(source.call("transition_to", RuntimeIdsScript.RUN_PHASE_HUNT)),
	)
	source.call("set_value", &"player_cell", Vector2i(19, -4))
	source.call("set_value", &"facing", &"NW")
	source.call("set_value", &"scrap", 23)
	source.call("set_value", &"starter_relay_completed", true)
	source.call("set_value", &"chassis", 0)
	source.call("set_value", &"shutdown", true)
	source.call("apply_event", RuntimeIdsScript.EVENT_RELAY_COMPLETED)
	source.call("add_module", RuntimeIdsScript.MODULE_AFTERSHOCK)
	var snapshot: Dictionary = source.call("to_dictionary") as Dictionary
	var restored: RefCounted = RunStateScript.new() as RefCounted
	_add_case(
		cases,
		"RunState restores a valid snapshot",
		bool(restored.call("restore_dictionary", snapshot))
	)
	_add_case(
		cases,
		"RunState round-trip preserves player and facing",
		(
			restored.call("get_value", &"player_cell") == Vector2i(19, -4)
			and restored.call("get_value", &"facing") == &"NW"
		),
	)
	_add_case(
		cases,
		"RunState round-trip preserves chassis and shutdown",
		(
			int(restored.call("get_value", &"chassis")) == 0
			and bool(restored.call("get_value", &"shutdown"))
		),
	)
	_add_case(
		cases,
		"RunState round-trip preserves scrap and starter relay",
		(
			int(restored.call("get_value", &"scrap")) == 23
			and bool(restored.call("get_value", &"starter_relay_completed"))
		),
	)
	_add_case(
		cases,
		"RunState round-trip preserves active modules",
		(
			bool(restored.call("has_module", RuntimeIdsScript.MODULE_WORN_PLATES))
			and bool(restored.call("has_module", RuntimeIdsScript.MODULE_AFTERSHOCK))
		),
	)
	var legacy_schema_three: Dictionary = snapshot.duplicate(true)
	legacy_schema_three.erase(&"active_module_ids")
	var legacy_restored: RefCounted = RunStateScript.new() as RefCounted
	_add_case(
		cases,
		"legacy schema-three runs default to Worn Plates",
		(
			bool(legacy_restored.call("restore_dictionary", legacy_schema_three))
			and bool(legacy_restored.call("has_module", RuntimeIdsScript.MODULE_WORN_PLATES))
		),
	)
	var malformed: Dictionary = snapshot.duplicate(true)
	malformed[&"active_module_ids"] = ["module.unknown"]
	_add_case(
		cases,
		"RunState rejects malformed restore without mutation",
		(
			not bool(restored.call("restore_dictionary", malformed))
			and bool(restored.call("has_module", RuntimeIdsScript.MODULE_AFTERSHOCK))
		),
	)


static func _test_profile_round_trip(cases: Array[Dictionary]) -> void:
	var source: RefCounted = ProfileStateScript.new() as RefCounted
	source.call("bank", 3, 12)
	source.call("record_result", true, {&"result": "success", &"scrap": 12})
	(
		source
		. call(
			"set_modifier_offer",
			[RuntimeIdsScript.MODIFIER_HOT_FRONT, RuntimeIdsScript.MODIFIER_DEAD_GRID],
		)
	)
	var snapshot: Dictionary = source.call("to_dictionary") as Dictionary
	var restored: RefCounted = ProfileStateScript.new() as RefCounted
	_add_case(
		cases,
		"ProfileState restores a valid snapshot",
		bool(restored.call("restore_dictionary", snapshot)),
	)
	_add_case(
		cases,
		"ProfileState round-trip preserves bank and record",
		(
			int(restored.call("get_value", &"banked_relay_data")) == 3
			and int(restored.call("get_value", &"banked_scrap")) == 12
			and int(restored.call("get_value", &"success_count")) == 1
		),
	)
	var offer: Array[StringName] = (
		restored.call("get_value", &"pending_modifier_offer") as Array[StringName]
	)
	offer.clear()
	_add_case(
		cases,
		"ProfileState projections are detached",
		(restored.call("get_value", &"pending_modifier_offer") as Array[StringName]).size() == 2,
	)
	var malformed: Dictionary = snapshot.duplicate(true)
	malformed[&"banked_scrap"] = "12"
	_add_case(
		cases,
		"ProfileState rejects malformed restore without mutation",
		(
			not bool(restored.call("restore_dictionary", malformed))
			and int(restored.call("get_value", &"banked_scrap")) == 12
		),
	)


static func _test_lifecycle_and_idempotency(cases: Array[Dictionary]) -> void:
	var state: RefCounted = RunStateScript.new() as RefCounted
	var invalid_state: RefCounted = RunStateScript.new() as RefCounted
	_add_case(
		cases,
		"malformed run ID is rejected",
		not bool(invalid_state.call("configure", &"RUN INVALID", 3, 100, Vector2i.ZERO, &"SE")),
	)
	state.call("configure", &"run.test.transitions", 3, 100, Vector2i.ZERO, &"SE")
	_add_case(
		cases,
		"illegal bootstrap transition is rejected",
		not bool(state.call("transition_to", RuntimeIdsScript.RUN_PHASE_SUCCEEDED)),
	)
	state.call("transition_to", RuntimeIdsScript.RUN_PHASE_HUNT)
	_add_case(
		cases,
		"duplicate lifecycle transition is rejected",
		not bool(state.call("transition_to", RuntimeIdsScript.RUN_PHASE_HUNT)),
	)
	_add_case(
		cases,
		"semantic event applies once",
		bool(state.call("apply_event", RuntimeIdsScript.EVENT_SCRAP_COLLECTED)),
	)
	_add_case(
		cases,
		"duplicate semantic event is rejected",
		not bool(state.call("apply_event", RuntimeIdsScript.EVENT_SCRAP_COLLECTED)),
	)
	_add_case(
		cases,
		"starter relay completion cannot revert",
		(
			bool(state.call("set_value", &"starter_relay_completed", true))
			and not bool(state.call("set_value", &"starter_relay_completed", false))
		),
	)


static func _test_live_coordinator_round_trip(
	cases: Array[Dictionary], coordinator: RefCounted
) -> void:
	_add_case(cases, "typed live coordinator exists", coordinator != null)
	if coordinator == null:
		return
	_add_case(
		cases,
		"live run starts with Worn Plates exactly once",
		(
			bool(coordinator.call("_has_run_module", RuntimeIdsScript.MODULE_WORN_PLATES))
			and not bool(coordinator.call("_add_run_module", RuntimeIdsScript.MODULE_WORN_PLATES))
		),
	)
	var run_snapshot: Dictionary = coordinator.call("get_run_snapshot") as Dictionary
	var profile_snapshot: Dictionary = coordinator.call("get_profile_snapshot") as Dictionary
	_add_case(
		cases,
		"live coordinator exposes typed RunState",
		(
			run_snapshot[&"player_cell"] == [8, 10]
			and int(run_snapshot[&"chassis"]) == 100
			and int(run_snapshot[&"unbanked_scrap"]) == 0
		),
	)
	_add_case(
		cases,
		"live coordinator exposes typed ProfileState",
		(
			int(profile_snapshot[&"banked_relay_data"]) == 0
			and int(profile_snapshot[&"banked_scrap"]) == 0
		),
	)
	_add_case(
		cases,
		"coordinator restores detached typed state atomically",
		bool(coordinator.call("restore_state_snapshots", run_snapshot, profile_snapshot)),
	)
	run_snapshot[&"chassis"] = 0
	_add_case(
		cases,
		"coordinator snapshots cannot mutate live state",
		int(coordinator.call("get_run_value", &"chassis")) == 100,
	)


static func _add_case(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
