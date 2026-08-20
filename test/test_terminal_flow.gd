extends RefCounted

const RunCoordinatorScript: GDScript = preload("res://scripts/run_coordinator.gd")
const RunModifierEffectsScript: GDScript = preload("res://scripts/run_modifier_effects.gd")
const RunSettlementScript: GDScript = preload("res://scripts/run_settlement.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const OasisWetlandsScript: GDScript = preload("res://scripts/oasis_wetlands.gd")


class SaveGate:
	extends RefCounted
	var succeed: bool = true
	var calls: int = 0

	func save() -> bool:
		calls += 1
		return succeed


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_success(cases)
	_test_failure(cases)
	_test_rollback(cases)
	_test_effects(cases)
	_test_ten_run_soak(cases)
	return cases


static func _test_success(cases: Array[Dictionary]) -> void:
	var coordinator: RefCounted = RunCoordinatorScript.new() as RefCounted
	coordinator.call("configure_default")
	var gate: SaveGate = SaveGate.new()
	_configure_three_relays(coordinator)
	coordinator.call("set_run_value", &"scrap", 11)
	coordinator.call("set_run_value", &"worm_cores", 4)
	var summary: Dictionary = RunSettlementScript.settle_success(
		coordinator, Callable(gate, "save")
	)
	_add(
		cases, "success settles once after three relays", not summary.is_empty() and gate.calls == 1
	)
	_add(
		cases,
		"success banks run rewards and persists a two-choice offer",
		(
			int(coordinator.call("get_profile_value", &"banked_scrap")) == 11
			and int(coordinator.call("get_profile_value", &"banked_cores")) == 4
			and (
				(coordinator.call("get_profile_value", &"pending_modifier_offer") as Array).size()
				== 2
			)
		),
	)
	_add(
		cases,
		"duplicate success settlement is rejected",
		(
			RunSettlementScript.settle_success(coordinator, Callable(gate, "save")).is_empty()
			and gate.calls == 1
		),
	)
	var offer: Array = coordinator.call("get_profile_value", &"pending_modifier_offer") as Array
	var selected: StringName = StringName(str(offer[0]))
	_add(
		cases,
		"modifier choice saves before relaunch",
		RunSettlementScript.select_modifier(coordinator, selected, Callable(gate, "save")),
	)
	_add(
		cases,
		"relaunch promotes exactly one selected modifier",
		(
			RunSettlementScript.launch_next(coordinator, Callable(gate, "save"))
			and coordinator.call("get_run_value", &"active_modifier_id") == selected
			and coordinator.call("get_run_value", &"phase") == RuntimeIdsScript.RUN_PHASE_HUNT
			and (
				(coordinator.call("get_profile_value", &"last_run_summary") as Dictionary)
				. is_empty()
			)
		),
	)
	_add(
		cases,
		"every new expedition deploys Walker in desert",
		(
			OasisWetlandsScript.biome_at(
				coordinator.call("get_run_value", &"player_cell") as Vector2i
			)
			== &"desert"
		),
	)


static func _test_failure(cases: Array[Dictionary]) -> void:
	var coordinator: RefCounted = RunCoordinatorScript.new() as RefCounted
	coordinator.call("configure_default")
	var gate: SaveGate = SaveGate.new()
	coordinator.call("set_run_value", &"scrap", 5)
	coordinator.call("set_run_value", &"worm_cores", 2)
	coordinator.call("set_run_value", &"chassis", 0)
	coordinator.call("set_run_value", &"shutdown", true)
	var summary: Dictionary = RunSettlementScript.settle_failure(
		coordinator, Callable(gate, "save")
	)
	_add(
		cases,
		"failure loses all Cores and half-rounded-down scrap",
		(
			int(summary.get(&"banked_scrap")) == 2
			and int(summary.get(&"lost_scrap")) == 3
			and int(summary.get(&"lost_cores")) == 2
			and int(coordinator.call("get_profile_value", &"banked_cores")) == 0
		),
	)
	_add(
		cases,
		"failure retry needs no modifier choice",
		(
			(coordinator.call("get_profile_value", &"pending_modifier_offer") as Array).is_empty()
			and RunSettlementScript.launch_next(coordinator, Callable(gate, "save"))
			and (
				coordinator.call("get_run_value", &"active_modifier_id")
				== RuntimeIdsScript.MODIFIER_NEUTRAL
			)
		),
	)


static func _test_rollback(cases: Array[Dictionary]) -> void:
	var coordinator: RefCounted = RunCoordinatorScript.new() as RefCounted
	coordinator.call("configure_default")
	var gate: SaveGate = SaveGate.new()
	gate.succeed = false
	_configure_three_relays(coordinator)
	var before: Dictionary = coordinator.call("get_profile_snapshot") as Dictionary
	_add(
		cases,
		"failed settlement save rolls run and profile back",
		(
			RunSettlementScript.settle_success(coordinator, Callable(gate, "save")).is_empty()
			and (
				coordinator.call("get_run_value", &"phase")
				== RuntimeIdsScript.RUN_PHASE_EXTRACTION_READY
			)
			and coordinator.call("get_profile_snapshot") == before
		),
	)


static func _test_effects(cases: Array[Dictionary]) -> void:
	_add(
		cases,
		"Hot Front changes storm timing and relay scrap only",
		(
			(
				RunModifierEffectsScript.storm_interval(10.0, RuntimeIdsScript.MODIFIER_HOT_FRONT)
				< 10.0
			)
			and RunModifierEffectsScript.relay_scrap(2, RuntimeIdsScript.MODIFIER_HOT_FRONT) == 4
		),
	)
	_add(
		cases,
		"Brood Ground adds bounded pressure and deterministic bonus Core",
		(
			RunModifierEffectsScript.worm_count(1, RuntimeIdsScript.MODIFIER_BROOD_GROUND) == 2
			and (
				RunModifierEffectsScript.core_reward(1, 2, RuntimeIdsScript.MODIFIER_BROOD_GROUND)
				== 2
			)
			and (
				RunModifierEffectsScript.core_reward(1, 3, RuntimeIdsScript.MODIFIER_BROOD_GROUND)
				== 1
			)
		),
	)
	_add(
		cases,
		"Dead Grid changes spacing and repair cost only",
		(
			RunModifierEffectsScript.relay_spacing(RuntimeIdsScript.MODIFIER_DEAD_GRID) == 8.0
			and RunModifierEffectsScript.repair_cost(5, RuntimeIdsScript.MODIFIER_DEAD_GRID) == 3
		),
	)


static func _test_ten_run_soak(cases: Array[Dictionary]) -> void:
	var coordinator: RefCounted = RunCoordinatorScript.new() as RefCounted
	coordinator.call("configure_default")
	var gate: SaveGate = SaveGate.new()
	var valid: bool = true
	for run_index: int in range(10):
		coordinator.call("set_run_value", &"scrap", run_index + 2)
		if run_index % 2 == 0:
			_configure_three_relays(coordinator)
			valid = (
				valid
				and not (
					RunSettlementScript
					. settle_success(coordinator, Callable(gate, "save"))
					. is_empty()
				)
			)
			var offer: Array = (
				coordinator.call("get_profile_value", &"pending_modifier_offer") as Array
			)
			valid = valid and offer.size() == 2
			valid = (
				valid
				and RunSettlementScript.select_modifier(
					coordinator, StringName(str(offer[0])), Callable(gate, "save")
				)
			)
		else:
			coordinator.call("set_run_value", &"chassis", 0)
			coordinator.call("set_run_value", &"shutdown", true)
			valid = (
				valid
				and not (
					RunSettlementScript
					. settle_failure(coordinator, Callable(gate, "save"))
					. is_empty()
				)
			)
		valid = valid and RunSettlementScript.launch_next(coordinator, Callable(gate, "save"))
		valid = (
			valid and coordinator.call("get_run_value", &"phase") == RuntimeIdsScript.RUN_PHASE_HUNT
		)
	_add(cases, "ten mixed runs leave no duplicate settlement or stale terminal state", valid)


static func _configure_three_relays(coordinator: RefCounted) -> void:
	var objectives: Array[Dictionary] = [
		{&"objective_id": RuntimeIdsScript.OBJECTIVE_STARTER_RELAY, &"cell": [12, 6]},
		{&"objective_id": RuntimeIdsScript.OBJECTIVE_RELAY_TWO, &"cell": [40, 8]},
		{&"objective_id": RuntimeIdsScript.OBJECTIVE_RELAY_THREE, &"cell": [70, 10]},
	]
	coordinator.call("_configure_relay_objectives", objectives)
	for objective: Dictionary in objectives:
		coordinator.call("_complete_next_relay", objective[&"objective_id"])


static func _add(cases: Array[Dictionary], name: String, passed: bool) -> void:
	cases.append({&"label": name, &"passed": passed})
