extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const DEFINITIONS: Array[Resource] = [
	preload("res://data/modules/ram_plating.tres"),
	preload("res://data/modules/aftershock.tres"),
	preload("res://data/modules/storm_seal.tres"),
]

var _coordinator: RefCounted
var _save_callback: Callable


func configure(coordinator: RefCounted, save_callback: Callable) -> bool:
	if coordinator == null or not save_callback.is_valid():
		return false
	for definition: Resource in DEFINITIONS:
		if not bool(definition.call("validate")):
			return false
	_coordinator = coordinator
	_save_callback = save_callback
	return true


func catalog_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition: Resource in DEFINITIONS:
		result.append(definition.call("snapshot") as Dictionary)
	return result


func purchase(module_id: StringName, linked: bool, failed: bool) -> bool:
	var definition: Resource = _definition(module_id)
	if not _eligible(definition, linked, failed):
		return false
	var run_before: Dictionary = _coordinator.call("get_run_snapshot") as Dictionary
	var profile_before: Dictionary = _coordinator.call("get_profile_snapshot") as Dictionary
	var core_cost: int = int(definition.get("core_cost"))
	var scrap_cost: int = int(definition.get("scrap_cost"))
	var mutated: bool = (
		bool(_coordinator.call("set_run_value", &"worm_cores", _cores() - core_cost))
		and bool(_coordinator.call("set_run_value", &"scrap", _scrap() - scrap_cost))
		and bool(_coordinator.call("_add_run_module", module_id))
		and bool(_coordinator.call("set_run_value", &"refit_purchase_used", true))
		and bool(_coordinator.call("apply_run_event", RuntimeIdsScript.EVENT_MODULE_PURCHASED))
	)
	if mutated and bool(_save_callback.call()):
		return true
	_coordinator.call("restore_state_snapshots", run_before, profile_before)
	return false


func can_purchase(module_id: StringName, linked: bool, failed: bool) -> bool:
	return _eligible(_definition(module_id), linked, failed)


func _eligible(definition: Resource, linked: bool, failed: bool) -> bool:
	return (
		_coordinator != null
		and definition != null
		and linked
		and not failed
		and not bool(_coordinator.call("get_run_value", &"refit_purchase_used"))
		and not bool(_coordinator.call("_has_run_module", definition.get("module_id")))
		and _cores() >= int(definition.get("core_cost"))
		and _scrap() >= int(definition.get("scrap_cost"))
	)


func _definition(module_id: StringName) -> Resource:
	for definition: Resource in DEFINITIONS:
		if definition.get("module_id") == module_id:
			return definition
	return null


func _cores() -> int:
	return int(_coordinator.call("get_run_value", &"worm_cores")) if _coordinator != null else 0


func _scrap() -> int:
	return int(_coordinator.call("get_run_value", &"scrap")) if _coordinator != null else 0
