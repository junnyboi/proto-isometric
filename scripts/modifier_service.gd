extends RefCounted

const ProfileStateScript: GDScript = preload("res://scripts/profile_state.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const ELIGIBLE: Array[StringName] = [
	RuntimeIdsScript.MODIFIER_HOT_FRONT,
	RuntimeIdsScript.MODIFIER_BROOD_GROUND,
	RuntimeIdsScript.MODIFIER_DEAD_GRID,
]


static func deterministic_offer(seed: int, success_count: int) -> Array[StringName]:
	var start: int = posmod(seed * 31 + success_count * 17, ELIGIBLE.size())
	return [ELIGIBLE[start], ELIGIBLE[(start + 1) % ELIGIBLE.size()]]


static func select(
	coordinator: RefCounted, modifier_id: StringName, save_callback: Callable
) -> bool:
	if coordinator == null or not save_callback.is_valid():
		return false
	var run_before: Dictionary = coordinator.call("get_run_snapshot") as Dictionary
	var profile_before: Dictionary = coordinator.call("get_profile_snapshot") as Dictionary
	var profile: RefCounted = ProfileStateScript.new() as RefCounted
	if (
		not bool(profile.call("restore_dictionary", profile_before))
		or not bool(profile.call("select_next_modifier", modifier_id))
		or not bool(
			coordinator.call(
				"restore_state_snapshots", run_before, profile.call("to_dictionary") as Dictionary
			)
		)
	):
		return false
	if bool(save_callback.call()):
		coordinator.call("record_event", RuntimeIdsScript.EVENT_MODIFIER_SELECTED)
		return true
	coordinator.call("restore_state_snapshots", run_before, profile_before)
	return false


static func definition(modifier_id: StringName) -> Resource:
	var definitions: Dictionary = {
		RuntimeIdsScript.MODIFIER_HOT_FRONT: preload("res://data/run_modifiers/hot_front.tres"),
		RuntimeIdsScript.MODIFIER_BROOD_GROUND:
		preload("res://data/run_modifiers/brood_ground.tres"),
		RuntimeIdsScript.MODIFIER_DEAD_GRID: preload("res://data/run_modifiers/dead_grid.tres"),
	}
	return definitions.get(modifier_id) as Resource
