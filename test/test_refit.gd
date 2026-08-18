extends RefCounted

const RefitServiceScript: GDScript = preload("res://scripts/refit_service.gd")
const ModuleEffectsScript: GDScript = preload("res://scripts/module_effects.gd")
const RunCoordinatorScript: GDScript = preload("res://scripts/run_coordinator.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_catalog(cases)
	_test_purchase(cases)
	_test_rollback(cases)
	_test_effects(cases)
	return cases


static func _test_catalog(cases: Array[Dictionary]) -> void:
	var service: RefCounted = RefitServiceScript.new() as RefCounted
	var coordinator: RefCounted = _coordinator()
	_add_case(
		cases,
		"Refit service configures",
		service.call("configure", coordinator, func() -> bool: return true)
	)
	var catalog: Array[Dictionary] = service.call("catalog_snapshot") as Array[Dictionary]
	_add_case(cases, "Refit catalog has three validated modules", catalog.size() == 3)
	var ids: Array[StringName] = []
	for item: Dictionary in catalog:
		ids.append(item[&"module_id"] as StringName)
	_add_case(
		cases,
		"Refit catalog IDs are unique",
		ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2]
	)


static func _test_purchase(cases: Array[Dictionary]) -> void:
	var coordinator: RefCounted = _coordinator()
	coordinator.call("set_run_value", &"scrap", 2)
	coordinator.call("set_run_value", &"worm_cores", 1)
	var saves: Array[int] = [0]
	var service: RefCounted = RefitServiceScript.new() as RefCounted
	service.call(
		"configure",
		coordinator,
		func() -> bool:
			saves[0] += 1
			return true
	)
	_add_case(
		cases,
		"linked affordable Refit commits",
		bool(service.call("purchase", RuntimeIdsScript.MODULE_RAM_PLATING, true, false)),
	)
	_add_case(cases, "Refit purchase saves exactly once", saves[0] == 1)
	_add_case(
		cases,
		"Refit purchase deducts exact wallets",
		(
			int(coordinator.call("get_run_value", &"scrap")) == 0
			and int(coordinator.call("get_run_value", &"worm_cores")) == 0
		),
	)
	_add_case(
		cases,
		"Refit installs selected module",
		coordinator.call("_has_run_module", RuntimeIdsScript.MODULE_RAM_PLATING)
	)
	_add_case(
		cases,
		"Refit consumes one-run allowance",
		coordinator.call("get_run_value", &"refit_purchase_used")
	)
	_add_case(
		cases,
		"second Refit rejects without another save",
		(
			not bool(service.call("purchase", RuntimeIdsScript.MODULE_AFTERSHOCK, true, false))
			and saves[0] == 1
		),
	)


static func _test_rollback(cases: Array[Dictionary]) -> void:
	var coordinator: RefCounted = _coordinator()
	coordinator.call("set_run_value", &"scrap", 2)
	coordinator.call("set_run_value", &"worm_cores", 1)
	var service: RefCounted = RefitServiceScript.new() as RefCounted
	service.call("configure", coordinator, func() -> bool: return false)
	_add_case(
		cases,
		"failed Refit save rejects",
		not bool(service.call("purchase", RuntimeIdsScript.MODULE_AFTERSHOCK, true, false)),
	)
	_add_case(
		cases,
		"failed Refit save rolls back all state",
		(
			int(coordinator.call("get_run_value", &"scrap")) == 2
			and int(coordinator.call("get_run_value", &"worm_cores")) == 1
			and not bool(coordinator.call("_has_run_module", RuntimeIdsScript.MODULE_AFTERSHOCK))
			and not bool(coordinator.call("get_run_value", &"refit_purchase_used"))
		),
	)
	_add_case(
		cases,
		"off-outpost Refit cannot mutate",
		not bool(service.call("purchase", RuntimeIdsScript.MODULE_STORM_SEAL, false, false)),
	)


static func _test_effects(cases: Array[Dictionary]) -> void:
	var coordinator: RefCounted = _coordinator()
	_add_case(
		cases,
		"neutral Ram Plating is inactive",
		not ModuleEffectsScript.can_ram(coordinator, true, 1.0)
	)
	coordinator.call("_add_run_module", RuntimeIdsScript.MODULE_RAM_PLATING)
	_add_case(
		cases,
		"Ram Plating requires run intent and full Impact",
		(
			ModuleEffectsScript.can_ram(coordinator, true, 0.8)
			and not ModuleEffectsScript.can_ram(coordinator, false, 1.0)
		)
	)
	var storm: RefCounted = _coordinator()
	storm.call("_add_run_module", RuntimeIdsScript.MODULE_STORM_SEAL)
	_add_case(
		cases,
		"Storm Seal halves running weather damage",
		ModuleEffectsScript.mitigate_damage(storm, 6, &"tornado", true) == 3
	)
	_add_case(
		cases,
		"Storm Seal leaves idle and worm damage exact",
		(
			ModuleEffectsScript.mitigate_damage(storm, 6, &"tornado", false) == 6
			and ModuleEffectsScript.mitigate_damage(storm, 10, &"sandworm", true) == 10
		)
	)
	var shock: RefCounted = _coordinator()
	shock.call("_add_run_module", RuntimeIdsScript.MODULE_AFTERSHOCK)
	_add_case(
		cases,
		"Aftershock exposes only its capped stagger value",
		is_equal_approx(ModuleEffectsScript.aftershock_stagger(shock), 1.4)
	)


static func _coordinator() -> RefCounted:
	var coordinator: RefCounted = RunCoordinatorScript.new() as RefCounted
	coordinator.call("configure_default")
	return coordinator


static func _add_case(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
