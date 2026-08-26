extends RefCounted

const ApplicantLifecycleScript: GDScript = preload(
	"res://scripts/applicant_lifecycle_service.gd"
)
const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const ConstructionTransactionScript: GDScript = preload(
	"res://scripts/construction_transaction_service.gd"
)
const DepositGatheringOperationScript: GDScript = preload(
	"res://scripts/deposit_gathering_operation.gd"
)
const DayAdvanceServiceScript: GDScript = preload("res://scripts/day_advance_service.gd")
const DurableUpgradeServiceScript: GDScript = preload("res://scripts/durable_upgrade_service.gd")
const EcologyDirectorScript: GDScript = preload("res://scripts/ecology_director.gd")
const FarmCapabilityServiceScript: GDScript = preload("res://scripts/farm_capability_service.gd")
const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const ReceiptLedgerScript: GDScript = preload("res://scripts/exact_once_receipt_ledger.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const IronjawDesertArcScript: GDScript = preload("res://scripts/ironjaw_desert_arc.gd")
const LivestockServiceScript: GDScript = preload("res://scripts/livestock_service.gd")
const MachineServiceScript: GDScript = preload("res://scripts/machine_service.gd")
const LogisticsServiceScript: GDScript = preload("res://scripts/logistics_service.gd")
const ProductionPolicyScript: GDScript = preload(
	"res://scripts/production_policy_service.gd"
)
const ProfileStateScript: GDScript = preload("res://scripts/profile_state.gd")
const RelationshipServiceScript: GDScript = preload("res://scripts/relationship_service.gd")
const RunStateScript: GDScript = preload("res://scripts/run_state.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const WorldOperationScript: GDScript = preload("res://scripts/harvest_world_operation_adapter.gd")
const WorldMutationLedgerScript: GDScript = preload("res://scripts/world_mutation_ledger.gd")
const WorkforceScript: GDScript = preload("res://scripts/workforce_service.gd")

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
	allow_structural_source: bool = false,
) -> bool:
	if repository == null or world_validator == null:
		return false
	var validator: StringName = (
		&"validate_candidate_envelope" if allow_structural_source else &"validate_envelope"
	)
	var normalized: Dictionary = repository.call(validator, envelope) as Dictionary
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
	if bool(built.get(&"replayed", false)):
		var replayed: Dictionary = _result(true, source, &"")
		replayed[&"replayed"] = true
		return replayed
	return _commit_candidate(source, built[&"candidate"] as Dictionary)


func transact_exact_once(
	operation: StringName,
	arguments: Dictionary,
	token: String,
	payload: Dictionary,
	deterministic_result: Dictionary,
) -> Dictionary:
	var source: Dictionary = _envelope.duplicate(true)
	var ledger: Dictionary = (source[&"farm"] as Dictionary)[&"receipts"] as Dictionary
	var previous: Dictionary = ReceiptLedgerScript.lookup(ledger, token, payload)
	var status: StringName = previous[&"status"] as StringName
	if status == &"duplicate":
		return _receipt_result(true, source, &"", status, previous[&"result"], true)
	if status != &"missing":
		return _receipt_result(false, source, status, status, null, false)
	var built: Dictionary = _build(source, operation, arguments)
	if not bool(built.get(&"ok", false)):
		return _receipt_result(
			false,
			source,
			built.get(&"reason", &"rejected") as StringName,
			&"not_recorded",
			null,
			false,
		)
	var candidate: Dictionary = (built[&"candidate"] as Dictionary).duplicate(true)
	var farm: Dictionary = (candidate[&"farm"] as Dictionary).duplicate(true)
	var recorded: Dictionary = ReceiptLedgerScript.record(
		farm[&"receipts"], token, payload, deterministic_result
	)
	if not bool(recorded[&"ok"]):
		return _receipt_result(
			false,
			source,
		recorded[&"status"] as StringName,
		recorded[&"status"] as StringName,
		null,
		false,
		)
	farm[&"receipts"] = recorded[&"candidate"]
	candidate[&"farm"] = FarmSaveSchemaScript.validate(farm)
	if (candidate[&"farm"] as Dictionary).is_empty():
		return _receipt_result(false, source, &"invalid_receipt_candidate", &"invalid", null, false)
	var committed: Dictionary = _commit_candidate(source, candidate)
	return _receipt_result(
		bool(committed[&"ok"]),
		committed[&"candidate"],
		committed[&"reason"] as StringName,
		&"recorded" if bool(committed[&"ok"]) else &"not_recorded",
		deterministic_result if bool(committed[&"ok"]) else null,
		false,
	)


func _commit_candidate(source: Dictionary, candidate: Dictionary) -> Dictionary:
	var validator: StringName = (
		&"validate_candidate_envelope"
		if _repository.has_method("validate_candidate_envelope")
		else &"validate_envelope"
	)
	var validated: Dictionary = _repository.call(validator, candidate) as Dictionary
	if validated.is_empty():
		return _result(false, source, &"invalid_candidate")
	if not bool(
		(
			_repository
			. call(
			"save_state",
			validated[&"world"],
			validated[&"active_run"],
			validated[&"profile"],
			validated[&"farm"],
		)
		)
	):
		return _result(false, source, &"persistence_failed")
	var committed: Dictionary = _committed_after_save(validated)
	if _publish.is_valid() and not bool(_publish.call(committed.duplicate(true))):
		var rollback_candidate: Dictionary = _rollback_candidate(source, committed)
		var persisted_restored: bool = bool(
			(
				_repository
				. call(
				"save_state",
				rollback_candidate[&"world"],
				rollback_candidate[&"active_run"],
				rollback_candidate[&"profile"],
				rollback_candidate[&"farm"],
			)
		)
		)
		var restored: Dictionary = (
			_committed_after_save(source) if persisted_restored else source.duplicate(true)
		)
		var live_restored: bool = bool(_publish.call(restored.duplicate(true)))
		var rollback_reason: StringName = (
			&"publish_failed" if live_restored and persisted_restored else &"rollback_failed"
		)
		_envelope = restored if persisted_restored else source
		return _result(false, _envelope, rollback_reason)
	_envelope = committed
	return _result(true, _envelope, &"")


func _committed_after_save(fallback: Dictionary) -> Dictionary:
	if _repository.has_method("get_last_committed_envelope"):
		var committed: Dictionary = _repository.call("get_last_committed_envelope") as Dictionary
		if not committed.is_empty():
			return committed
	return fallback.duplicate(true)


func _rollback_candidate(source: Dictionary, committed: Dictionary) -> Dictionary:
	var candidate: Dictionary = source.duplicate(true)
	if not _repository.has_method("get_last_committed_envelope"):
		return candidate
	var committed_farm: Dictionary = committed.get(&"farm", {}) as Dictionary
	var revisions: Dictionary = committed_farm.get(&"revisions", {}) as Dictionary
	if not revisions.is_empty():
		(candidate[&"farm"] as Dictionary)[&"revisions"] = revisions.duplicate(true)
	return candidate


func _receipt_result(
	ok: bool,
	envelope: Dictionary,
	reason: StringName,
	status: StringName,
	receipt_result: Variant,
	replayed: bool,
) -> Dictionary:
	var result: Dictionary = _result(ok, envelope, reason)
	result[&"receipt_status"] = status
	result[&"receipt_result"] = (
		receipt_result.duplicate(true)
		if receipt_result is Array or receipt_result is Dictionary
		else receipt_result
	)
	result[&"replayed"] = replayed
	return result


func _build(source: Dictionary, operation: StringName, arguments: Dictionary) -> Dictionary:
	var candidate: Dictionary = source.duplicate(true)
	var farm: Dictionary = candidate[&"farm"] as Dictionary
	var mutation: Dictionary = {&"ok": false, &"candidate": farm, &"reason": &"unknown_operation"}
	if operation == DepositGatheringOperationScript.OPERATION or (
		operation in ConstructionTransactionScript.OPERATIONS
	):
		return _build_specialized(candidate, operation, arguments)
	match operation:
		&"harvest":
			mutation = FarmStateScript.harvest(farm, arguments[&"cell"] as Vector2i)
		&"transfer":
			mutation = (
				InventoryServiceScript
				. transfer(
				farm,
				arguments[&"source_id"] as StringName,
				arguments[&"destination_id"] as StringName,
				arguments[&"item_id"] as StringName,
				int(arguments[&"count"]),
			)
			)
		&"craft_start":
			mutation = MachineServiceScript.start(
				farm, arguments[&"machine_id"] as StringName, arguments[&"recipe_id"] as StringName
			)
		&"craft_claim":
			mutation = MachineServiceScript.claim(farm, arguments[&"machine_id"] as StringName)
		&"sleep":
			mutation = DayAdvanceServiceScript.build_candidate(
				farm,
				_world_seed,
					"",
					Callable(_world_validator, "_resource_source_at"),
					Callable(_world_validator, "_is_home_safe"),
				)
		&"upgrade":
			mutation = DurableUpgradeServiceScript.purchase(
				farm, arguments[&"upgrade_id"] as StringName
			)
		&"facility_repair":
			mutation = HomesteadServiceScript.repair(
				farm, arguments.get(&"facility_id", &"") as StringName
			)
		&"facility_power":
			mutation = HomesteadServiceScript.power(
				farm, arguments.get(&"facility_id", &"") as StringName
			)
		&"talk":
			mutation = RelationshipServiceScript.talk(
				farm, arguments.get(&"resident_id", &"") as StringName
			)
		&"gift":
			mutation = (
				RelationshipServiceScript
				. gift(
				farm,
				arguments.get(&"resident_id", &"") as StringName,
				arguments.get(&"item_id", &"") as StringName,
			)
			)
		&"request", &"request_complete":
			mutation = RelationshipServiceScript.complete_request(
				farm, arguments.get(&"request_id", &"") as StringName
			)
		&"animal_add":
			mutation = (
				LivestockServiceScript
				. add_animal(
				farm,
				arguments.get(&"animal_id", &"") as StringName,
				arguments.get(&"species_id", &"") as StringName,
				arguments.get(&"housing_id", &"") as StringName,
			)
			)
		&"animal_feed":
			mutation = LivestockServiceScript.feed(
				farm, arguments.get(&"animal_id", &"") as StringName
			)
		&"animal_pet":
			mutation = LivestockServiceScript.pet(
				farm, arguments.get(&"animal_id", &"") as StringName
			)
		&"animal_product":
			mutation = LivestockServiceScript.claim_product(
				farm, arguments.get(&"animal_id", &"") as StringName
			)
		&"ecology_deplete":
			mutation = EcologyDirectorScript.deplete(
				farm,
				arguments.get(&"habitat_id", &"") as StringName,
				int(arguments.get(&"count", 1)),
				int(arguments.get(&"absolute_day", 1))
			)
		&"herd_interact":
			mutation = EcologyDirectorScript.interact_herd(
				farm,
				arguments.get(&"habitat_id", &"") as StringName,
				int(arguments.get(&"absolute_day", 1))
			)
		&"capability_unlock":
			mutation = FarmCapabilityServiceScript.unlock(
				farm, arguments.get(&"capability", &"") as StringName
			)
		&"hazard_reward":
			mutation = FarmCapabilityServiceScript.claim_hazard_reward(
				farm,
				str(arguments.get(&"token", "")),
				arguments.get(&"item_id", &"") as StringName,
				int(arguments.get(&"count", 0))
			)
		&"ironjaw_first_clear":
			mutation = IronjawDesertArcScript.complete_first_clear(farm)
		&"applicant_decision":
			mutation = ApplicantLifecycleScript.decide(
				farm,
				arguments.get(&"decision", &"") as StringName,
				arguments.get(&"expected_applicant_id", &"") as StringName,
				int(arguments.get(&"expected_sequence", -1)),
			)
		&"workforce_assign":
			if not _revision_matches(farm, arguments):
				mutation = _mutation_rejected(farm, &"stale_workforce_revision")
			else:
				mutation = WorkforceScript.assign(
					farm,
					arguments.get(&"settler_id", &"") as StringName,
					arguments.get(&"site_id", &"") as StringName,
					int(arguments.get(&"slot", -1)),
					int(arguments.get(&"shift", -1)),
				)
		&"workforce_unassign":
			if not _revision_matches(farm, arguments):
				mutation = _mutation_rejected(farm, &"stale_workforce_revision")
			else:
				mutation = WorkforceScript.unassign(
					farm, arguments.get(&"settler_id", &"") as StringName
				)
		&"logistics_set_reserve":
			if not _revision_matches(farm, arguments):
				mutation = _mutation_rejected(farm, &"stale_logistics_revision")
			else:
				mutation = LogisticsServiceScript.set_reserve_floor(
					farm,
					arguments.get(&"item_id", &"") as StringName,
					int(arguments.get(&"floor", -1)),
				)
		&"production_set_policy":
			if not _revision_matches(farm, arguments):
				mutation = _mutation_rejected(farm, &"stale_production_revision")
			else:
				mutation = ProductionPolicyScript.set_policy(
					farm,
					arguments.get(&"site_id", &"") as StringName,
					arguments.get(&"recipe_id", &"") as StringName,
					bool(arguments.get(&"enabled", false)),
					int(arguments.get(&"priority", -1)),
					int(arguments.get(&"target_count", -1)),
				)
		&"logistics_force_transfer":
			mutation = LogisticsServiceScript.force_delivery(
				farm,
				arguments.get(&"job_id", &"") as StringName,
				str(arguments.get(&"operation_id", "")),
				int(arguments.get(&"expected_revision", -1)),
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
		&"world_clear_reward":
			return WorldOperationScript.build(candidate, arguments)
		&"placement":
			return _build_placement(candidate, arguments)
		&"expedition_return":
			return _build_expedition_return(candidate, arguments)
	if not bool(mutation.get(&"ok", false)):
		return {&"ok": false, &"candidate": source, &"reason": mutation[&"reason"]}
	candidate[&"farm"] = FarmSaveSchemaScript.validate(mutation[&"candidate"])
	return {
		&"ok": not (candidate[&"farm"] as Dictionary).is_empty(),
		&"candidate": candidate,
		&"replayed": bool(mutation.get(&"replayed", false)),
	}


func _build_specialized(
	candidate: Dictionary,
	operation: StringName,
	arguments: Dictionary,
) -> Dictionary:
	if operation == DepositGatheringOperationScript.OPERATION:
		return DepositGatheringOperationScript.build(
			candidate, arguments, _world_seed, _world_validator
		)
	return ConstructionTransactionScript.build(
		candidate, operation, arguments, _world_validator
	)


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
	adapted[&"mutation_ledger"] = (placed[&"candidate"] as Dictionary).duplicate(true)
	candidate[&"world"] = adapted
	return {&"ok": true, &"candidate": candidate}


func _build_expedition_return(candidate: Dictionary, arguments: Dictionary) -> Dictionary:
	var reason: StringName = _return_precondition(candidate)
	var run_before: Dictionary = candidate.get(&"active_run", {}) as Dictionary
	var profile: RefCounted = ProfileStateScript.new() as RefCounted
	var credited: Dictionary = {}
	if reason == &"" and not bool(profile.call("restore_dictionary", candidate[&"profile"])):
		reason = &"invalid_profile"
	if reason == &"" and _return_was_applied(profile, run_before):
		reason = &"return_already_applied"
	if reason == &"":
		credited = _credit_return(candidate[&"farm"], run_before)
		if credited.is_empty():
			reason = &"inventory_full"
	if reason == &"":
		credited = _credit_cargo(credited, arguments.get(&"cargo", []))
		if credited.is_empty():
			reason = &"invalid_or_full_cargo"
	var ruin_id: StringName = arguments.get(&"activate_ruin_id", &"") as StringName
	if reason == &"" and ruin_id != &"":
		var activated: Dictionary = _activate_remote_ruin(credited, ruin_id)
		if activated.is_empty():
			reason = &"invalid_remote_ruin"
		else:
			credited = activated
	var finalized: Dictionary = {}
	if reason == &"":
		finalized = _finalize_return(candidate, run_before, profile, credited)
		if finalized.is_empty():
			reason = &"return_finalize_failed"
	return {
		&"ok": reason == &"",
		&"candidate": finalized if reason == &"" else candidate,
		&"reason": reason,
	}


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


func _credit_cargo(farm: Dictionary, cargo: Variant) -> Dictionary:
	if not cargo is Array or (cargo as Array).size() > 32:
		return {}
	var candidate: Dictionary = farm.duplicate(true)
	var last_id: String = ""
	for raw: Variant in cargo as Array:
		var entry: Dictionary = raw as Dictionary if raw is Dictionary else {}
		if entry.keys() != [&"item_id", &"count"]:
			return {}
		var item_id: StringName = StringName(str(entry[&"item_id"]))
		var count: int = int(entry[&"count"])
		if String(item_id) <= last_id or count < 1 or count > 999:
			return {}
		var credited: Dictionary = InventoryServiceScript.credit_with_overflow(
			candidate, item_id, count
		)
		if not bool(credited[&"ok"]):
			return {}
		candidate = credited[&"candidate"] as Dictionary
		last_id = String(item_id)
	return candidate


func _activate_remote_ruin(farm: Dictionary, ruin_id: StringName) -> Dictionary:
	if not String(ruin_id).begins_with("ruin.remote."):
		return {}
	var activated: Dictionary = EcologyDirectorScript.add_token(
		farm, "ruin:%s:activated" % ruin_id
	)
	return activated[&"candidate"] as Dictionary if bool(activated[&"ok"]) else {}


func _revision_matches(farm: Dictionary, arguments: Dictionary) -> bool:
	var revisions: Dictionary = farm.get(&"revisions", {}) as Dictionary
	return int(arguments.get(&"expected_revision", -1)) == int(
		revisions.get(&"result_revision", -2)
	)


func _mutation_rejected(farm: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": false, &"candidate": farm.duplicate(true), &"reason": reason}


func _result(ok: bool, envelope: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": envelope.duplicate(true), &"reason": reason}
