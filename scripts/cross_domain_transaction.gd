extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const DayAdvanceServiceScript: GDScript = preload("res://scripts/day_advance_service.gd")
const DurableUpgradeServiceScript: GDScript = preload("res://scripts/durable_upgrade_service.gd")
const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const MachineServiceScript: GDScript = preload("res://scripts/machine_service.gd")
const ProfileStateScript: GDScript = preload("res://scripts/profile_state.gd")
const RunStateScript: GDScript = preload("res://scripts/run_state.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const WorldMutationLedgerScript: GDScript = preload("res://scripts/world_mutation_ledger.gd")

var _envelope: Dictionary = {}
var _repository: RefCounted
var _world_validator: RefCounted
var _publish: Callable
var _world_seed: int = CalendarStateScript.DEFAULT_WORLD_SEED


func configure(
	envelope: Dictionary,
	repository: RefCounted,
	world_validator: RefCounted,
	publish: Callable = Callable(),
	world_seed: int = CalendarStateScript.DEFAULT_WORLD_SEED,
) -> bool:
	if repository == null or world_validator == null:
		return false
	var normalized: Dictionary = repository.call("validate_envelope", envelope) as Dictionary
	if normalized.is_empty():
		return false
	_envelope = normalized
	_repository = repository
	_world_validator = world_validator
	_publish = publish
	_world_seed = world_seed
	return true


func get_snapshot() -> Dictionary:
	return _envelope.duplicate(true)


func transact(operation: StringName, arguments: Dictionary = {}) -> Dictionary:
	var source: Dictionary = _envelope.duplicate(true)
	var built: Dictionary = _build(source, operation, arguments)
	if not bool(built.get(&"ok", false)):
		return _result(false, source, built.get(&"reason", &"rejected") as StringName)
	var candidate: Dictionary = built[&"candidate"] as Dictionary
	var validated: Dictionary = _repository.call("validate_envelope", candidate) as Dictionary
	if validated.is_empty():
		return _result(false, source, &"invalid_candidate")
	if not bool(
		_repository.call(
			"save_state",
			validated[&"world"],
			validated[&"active_run"],
			validated[&"profile"],
			validated[&"farm"],
		)
	):
		return _result(false, source, &"persistence_failed")
	if _publish.is_valid() and not bool(_publish.call(validated.duplicate(true))):
		var live_restored: bool = bool(_publish.call(source.duplicate(true)))
		var persisted_restored: bool = bool(
			_repository.call(
				"save_state",
				source[&"world"],
				source[&"active_run"],
				source[&"profile"],
				source[&"farm"],
			)
		)
		var rollback_reason: StringName = (
			&"publish_failed" if live_restored and persisted_restored else &"rollback_failed"
		)
		return _result(false, source, rollback_reason)
	_envelope = validated
	return _result(true, _envelope, &"")


func _build(source: Dictionary, operation: StringName, arguments: Dictionary) -> Dictionary:
	var candidate: Dictionary = source.duplicate(true)
	var farm: Dictionary = candidate[&"farm"] as Dictionary
	var mutation: Dictionary = {&"ok": false, &"candidate": farm, &"reason": &"unknown_operation"}
	match operation:
		&"harvest":
			mutation = FarmStateScript.harvest(farm, arguments[&"cell"] as Vector2i)
		&"transfer":
			mutation = InventoryServiceScript.transfer(
				farm,
				arguments[&"source_id"] as StringName,
				arguments[&"destination_id"] as StringName,
				arguments[&"item_id"] as StringName,
				int(arguments[&"count"]),
			)
		&"craft_start":
			mutation = MachineServiceScript.start(
				farm, arguments[&"machine_id"] as StringName, arguments[&"recipe_id"] as StringName
			)
		&"craft_claim":
			mutation = MachineServiceScript.claim(farm, arguments[&"machine_id"] as StringName)
		&"sleep":
			mutation = DayAdvanceServiceScript.build_candidate(farm, _world_seed)
		&"upgrade":
			mutation = DurableUpgradeServiceScript.purchase(
				farm, arguments[&"upgrade_id"] as StringName
			)
		&"farm_candidate":
			var normalized_farm: Dictionary = FarmSaveSchemaScript.validate(
				arguments.get(&"farm", {})
			)
			mutation = {
				&"ok": not normalized_farm.is_empty(),
				&"candidate": normalized_farm,
				&"reason": &"invalid_farm_candidate",
			}
		&"placement":
			return _build_placement(candidate, arguments)
		&"expedition_return":
			return _build_expedition_return(candidate)
	if not bool(mutation.get(&"ok", false)):
		return {&"ok": false, &"candidate": source, &"reason": mutation[&"reason"]}
	candidate[&"farm"] = FarmSaveSchemaScript.validate(mutation[&"candidate"])
	return {&"ok": not (candidate[&"farm"] as Dictionary).is_empty(), &"candidate": candidate}


func _build_placement(candidate: Dictionary, arguments: Dictionary) -> Dictionary:
	var world: Dictionary = candidate[&"world"] as Dictionary
	var ledger: Dictionary = (
		WorldMutationLedgerScript.validate(world[&"mutation_ledger"])
		if world.has(&"mutation_ledger")
		else WorldMutationLedgerScript.from_legacy(world)
	)
	var record: Dictionary = arguments[&"record"] as Dictionary
	var placed: Dictionary = WorldMutationLedgerScript.place(ledger, record)
	if not bool(placed[&"ok"]):
		return {&"ok": false, &"candidate": candidate, &"reason": placed[&"reason"]}
	var adapted: Dictionary = WorldMutationLedgerScript.legacy_arrays_exact(
		world, placed[&"candidate"] as Dictionary
	)
	if adapted.is_empty():
		return {&"ok": false, &"candidate": candidate, &"reason": &"invalid_placement"}
	candidate[&"world"] = adapted
	return {&"ok": true, &"candidate": candidate}


func _build_expedition_return(candidate: Dictionary) -> Dictionary:
	var reason: StringName = _return_precondition(candidate)
	if reason != &"":
		return {&"ok": false, &"candidate": candidate, &"reason": reason}
	var run_before: Dictionary = candidate[&"active_run"] as Dictionary
	var profile: RefCounted = ProfileStateScript.new() as RefCounted
	if not bool(profile.call("restore_dictionary", candidate[&"profile"])):
		return {&"ok": false, &"candidate": candidate, &"reason": &"invalid_profile"}
	if _return_was_applied(profile, run_before):
		return {&"ok": false, &"candidate": candidate, &"reason": &"return_already_applied"}
	var credited: Dictionary = _credit_return(candidate[&"farm"], run_before)
	if credited.is_empty():
		return {&"ok": false, &"candidate": candidate, &"reason": &"inventory_full"}
	var finalized: Dictionary = _finalize_return(candidate, run_before, profile, credited)
	if finalized.is_empty():
		return {&"ok": false, &"candidate": candidate, &"reason": &"return_finalize_failed"}
	return {&"ok": true, &"candidate": finalized}


func _finalize_return(
	candidate: Dictionary, run_before: Dictionary, profile: RefCounted, credited: Dictionary
) -> Dictionary:
	var summary: Dictionary = {
		&"run_id": str(run_before[&"run_id"]),
		&"succeeded": true,
		&"farm_return": true,
		&"banked_scrap": int(run_before[&"unbanked_scrap"]),
		&"banked_cores": int(run_before[&"worm_cores"]),
	}
	if not bool(profile.call("record_result", true, summary)):
		return {}
	var run_state: RefCounted = RunStateScript.new() as RefCounted
	var run_after: Dictionary = run_before.duplicate(true)
	run_after[&"phase"] = String(RuntimeIdsScript.RUN_PHASE_SUCCEEDED)
	if not bool(run_state.call("restore_dictionary", run_after)):
		return {}
	var result: Dictionary = candidate.duplicate(true)
	result[&"active_run"] = run_state.call("to_dictionary") as Dictionary
	result[&"profile"] = profile.call("to_dictionary") as Dictionary
	result[&"farm"] = credited
	return result


func _return_precondition(candidate: Dictionary) -> StringName:
	if not candidate[&"active_run"] is Dictionary:
		return &"missing_run"
	var run: Dictionary = candidate[&"active_run"] as Dictionary
	if StringName(run[&"phase"]) != RuntimeIdsScript.RUN_PHASE_EXTRACTION_READY:
		return &"run_not_returnable"
	return &""


func _return_was_applied(profile: RefCounted, run: Dictionary) -> bool:
	var previous: Dictionary = profile.call("get_value", &"last_run_summary") as Dictionary
	return str(previous.get(&"run_id", "")) == str(run[&"run_id"])


func _credit_return(farm_value: Variant, run: Dictionary) -> Dictionary:
	var credited: Dictionary = (farm_value as Dictionary).duplicate(true)
	for reward: Dictionary in [
		{&"item_id": &"item.material.scrap", &"count": int(run[&"unbanked_scrap"])},
		{&"item_id": &"item.monster.worm_core", &"count": int(run[&"worm_cores"])},
	]:
		if int(reward[&"count"]) <= 0:
			continue
		var result: Dictionary = InventoryServiceScript.credit_with_overflow(
			credited, reward[&"item_id"] as StringName, int(reward[&"count"])
		)
		if not bool(result[&"ok"]):
			return {}
		credited = result[&"candidate"] as Dictionary
	return credited


func _result(ok: bool, envelope: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": envelope.duplicate(true), &"reason": reason}
