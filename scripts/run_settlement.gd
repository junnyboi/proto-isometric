extends RefCounted

const ModifierServiceScript: GDScript = preload("res://scripts/modifier_service.gd")
const ProfileStateScript: GDScript = preload("res://scripts/profile_state.gd")
const RunStateScript: GDScript = preload("res://scripts/run_state.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const FAILURE_SCRAP_KEEP_NUMERATOR: int = 1
const FAILURE_SCRAP_KEEP_DENOMINATOR: int = 2


static func settle_success(coordinator: RefCounted, save_callback: Callable) -> Dictionary:
	if coordinator == null or not save_callback.is_valid():
		return {}
	var run: Dictionary = coordinator.call("get_run_snapshot") as Dictionary
	if (
		StringName(str(run.get(&"phase"))) != RuntimeIdsScript.RUN_PHASE_EXTRACTION_READY
		or (run.get(&"completed_objective_ids", []) as Array).size() != 3
	):
		return {}
	return _settle(coordinator, save_callback, true, run)


static func settle_failure(coordinator: RefCounted, save_callback: Callable) -> Dictionary:
	if coordinator == null or not save_callback.is_valid():
		return {}
	var run: Dictionary = coordinator.call("get_run_snapshot") as Dictionary
	if (
		StringName(str(run.get(&"phase"))) != RuntimeIdsScript.RUN_PHASE_FAILED
		or not bool(run.get(&"shutdown", false))
	):
		return {}
	return _settle(coordinator, save_callback, false, run)


static func select_modifier(
	coordinator: RefCounted, modifier_id: StringName, save_callback: Callable
) -> bool:
	return ModifierServiceScript.select(coordinator, modifier_id, save_callback)


static func launch_next(coordinator: RefCounted, save_callback: Callable) -> bool:
	if coordinator == null or not save_callback.is_valid():
		return false
	var run_before: Dictionary = coordinator.call("get_run_snapshot") as Dictionary
	var profile_before: Dictionary = coordinator.call("get_profile_snapshot") as Dictionary
	if (profile_before.get(&"pending_modifier_offer", []) as Array).size() > 0:
		return false
	var profile: RefCounted = ProfileStateScript.new() as RefCounted
	if not bool(profile.call("restore_dictionary", profile_before)):
		return false
	var active_modifier: StringName = profile.call("_consume_next_modifier") as StringName
	var sequence: int = (
		int(profile.call("get_value", &"success_count"))
		+ int(profile.call("get_value", &"failure_count"))
		+ 1
	)
	var run: RefCounted = RunStateScript.new() as RefCounted
	if (
		not bool(
			(
				run
				. call(
					"configure",
					StringName("run.%08d" % sequence),
					int(run_before.get(&"seed", 0)) + 1,
					int(run_before.get(&"max_chassis", 100)),
					Vector2i(8, 10),
					&"SE",
				)
			)
		)
		or not bool(run.call("set_value", &"active_modifier_id", active_modifier))
		or not bool(run.call("transition_to", RuntimeIdsScript.RUN_PHASE_HUNT))
		or not bool(
			(
				coordinator
				. call(
					"restore_state_snapshots",
					run.call("to_dictionary") as Dictionary,
					profile.call("to_dictionary") as Dictionary,
				)
			)
		)
	):
		return false
	if bool(save_callback.call()):
		return true
	coordinator.call("restore_state_snapshots", run_before, profile_before)
	return false


static func _settle(
	coordinator: RefCounted, save_callback: Callable, succeeded: bool, run_before: Dictionary
) -> Dictionary:
	var profile_before: Dictionary = coordinator.call("get_profile_snapshot") as Dictionary
	var profile: RefCounted = ProfileStateScript.new() as RefCounted
	if not bool(profile.call("restore_dictionary", profile_before)):
		return {}
	var scrap: int = int(run_before.get(&"unbanked_scrap", 0))
	var cores: int = int(run_before.get(&"worm_cores", 0))
	var banked_scrap: int = (
		scrap
		if succeeded
		else floori(float(scrap * FAILURE_SCRAP_KEEP_NUMERATOR) / FAILURE_SCRAP_KEEP_DENOMINATOR)
	)
	var banked_cores: int = cores if succeeded else 0
	var summary: Dictionary = {
		&"run_id": str(run_before.get(&"run_id", "")),
		&"succeeded": succeeded,
		&"relays": (run_before.get(&"completed_objective_ids", []) as Array).size(),
		&"banked_scrap": banked_scrap,
		&"banked_cores": banked_cores,
		&"lost_scrap": scrap - banked_scrap,
		&"lost_cores": cores - banked_cores,
		&"modifier": str(run_before.get(&"active_modifier_id", RuntimeIdsScript.MODIFIER_NEUTRAL)),
	}
	if not _prepare_profile(profile, run_before, summary, succeeded, banked_scrap, banked_cores):
		return {}
	var run_after: Dictionary = run_before.duplicate(true)
	if succeeded:
		run_after[&"phase"] = String(RuntimeIdsScript.RUN_PHASE_SUCCEEDED)
	if not bool(
		coordinator.call(
			"restore_state_snapshots", run_after, profile.call("to_dictionary") as Dictionary
		)
	):
		return {}
	if bool(save_callback.call()):
		(
			coordinator
			. call(
				"record_event",
				(
					RuntimeIdsScript.EVENT_RUN_EXTRACTED
					if succeeded
					else RuntimeIdsScript.EVENT_RUN_FAILED
				),
			)
		)
		return summary
	coordinator.call("restore_state_snapshots", run_before, profile_before)
	return {}


static func _prepare_profile(
	profile: RefCounted,
	run: Dictionary,
	summary: Dictionary,
	succeeded: bool,
	banked_scrap: int,
	banked_cores: int,
) -> bool:
	var previous: Dictionary = profile.call("get_value", &"last_run_summary") as Dictionary
	if str(previous.get(&"run_id", "")) == str(run.get(&"run_id", "")):
		return false
	if not bool(profile.call("bank", 3 if succeeded else 0, banked_scrap, banked_cores)):
		return false
	if not bool(profile.call("record_result", succeeded, summary)):
		return false
	if not succeeded:
		return true
	var offer: Array[StringName] = ModifierServiceScript.deterministic_offer(
		int(run.get(&"seed", 0)), int(profile.call("get_value", &"success_count"))
	)
	return bool(profile.call("set_modifier_offer", offer))
