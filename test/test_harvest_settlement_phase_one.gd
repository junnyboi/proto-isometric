extends RefCounted

const BrowserCapabilityScript: GDScript = preload(
	"res://scripts/browser_persistence_capability.gd"
)
const BudgetCatalogScript: GDScript = preload("res://scripts/persistence_budget_catalog.gd")
const FaultInjectorScript: GDScript = preload("res://scripts/persistence_fault_injector.gd")
const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const FishingCatalogScript: GDScript = preload("res://scripts/fishing_catalog.gd")
const ReceiptLedgerScript: GDScript = preload("res://scripts/exact_once_receipt_ledger.gd")
const SaveRepositoryScript: GDScript = preload("res://scripts/save_repository.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")
const StateHashScript: GDScript = preload("res://scripts/persistence_state_hash.gd")

const TEST_ROOT: String = "/tmp/protos-harvest-settlement-p1.json"


static func evaluate(
	world: RefCounted, run_snapshot: Dictionary, profile_snapshot: Dictionary
) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_clear_artifacts(TEST_ROOT)
	var repository: RefCounted = _repository(TEST_ROOT, world)
	var world_snapshot: Dictionary = world.call("make_snapshot") as Dictionary
	_add_case(cases, "P1 repository configures", repository != null)
	var repository_capability: Dictionary = repository.call("get_persistence_capability") as Dictionary
	_add_case(
		cases,
		"P1 repository exposes its validated persistence capability",
		BrowserCapabilityScript.validate(repository_capability) == repository_capability,
	)
	var first_saved: bool = bool(
		repository.call("save_state", world_snapshot, run_snapshot, profile_snapshot)
	)
	var base: Dictionary = repository.call("load_state") as Dictionary
	_add_case(
		cases,
		"P1 first commit produces canonical schema 5 revision 1",
		first_saved
		and int(base.get(&"save_format_version", 0)) == 5
		and int(((base[&"farm"] as Dictionary)[&"revisions"] as Dictionary)[&"result_revision"]) == 1
		and StateHashScript.result_hash_matches(base),
	)
	_test_schema_foundation(cases, world, base)
	_test_section_validators(cases)
	_test_receipts(cases)
	_test_hashes(cases, repository, base)
	_test_budgets(cases, repository, base)
	_test_fault_recovery(cases, world, run_snapshot, profile_snapshot)
	_test_recovery_ordering(cases, world, run_snapshot, profile_snapshot)
	_test_browser_capability(cases)
	_clear_artifacts(TEST_ROOT)
	return cases


static func _test_schema_foundation(
	cases: Array[Dictionary], world: RefCounted, base: Dictionary
) -> void:
	var neutral: Dictionary = FarmSaveSchemaScript.make_neutral()
	_add_case(
		cases,
		"P1 neutral farm and homestead use additive version 2 sections",
		int(neutral[&"state_version"]) == 2
		and int((neutral[&"homestead"] as Dictionary)[&"state_version"]) == 2
		and not FarmSaveSchemaScript.validate(neutral).is_empty(),
	)
	var legacy_farm: Dictionary = _farm_v1(neutral)
	var migrated_once: Dictionary = FarmSaveSchemaScript.migrate_v1(legacy_farm)
	var migrated_twice: Dictionary = FarmSaveSchemaScript.migrate_v1(legacy_farm)
	_add_case(
		cases,
		"P1 farm and homestead v1 migrate purely and byte-stably to v2",
		not migrated_once.is_empty()
		and legacy_farm == _farm_v1(neutral)
		and FarmSaveSchemaScript.canonical_json(migrated_once)
		== FarmSaveSchemaScript.canonical_json(migrated_twice),
	)
	_add_case(
		cases,
		"P1 migration adds all settlement sections as neutral state",
		_sections_are_neutral(migrated_once),
	)
	var schema_four: Dictionary = base.duplicate(true)
	schema_four[&"save_format_version"] = 4
	schema_four[&"farm"] = _farm_v1(base[&"farm"] as Dictionary)
	var source_text: String = JSON.stringify(schema_four, "", true, true)
	var path: String = TEST_ROOT + ".schema4"
	_clear_artifacts(path)
	_write_text(path, source_text)
	var first_repo: RefCounted = _repository(path, world)
	var first: Dictionary = first_repo.call("load_state") as Dictionary
	var second_repo: RefCounted = _repository(path, world)
	var second: Dictionary = second_repo.call("load_state") as Dictionary
	_add_case(
		cases,
		"P1 schema 4 migrates once to byte-stable detached schema 5",
		not first.is_empty()
		and int(first[&"save_format_version"]) == 5
		and first_repo.call("get_status") == &"migrated"
		and JSON.stringify(first, "", true, true) == JSON.stringify(second, "", true, true)
		and _read_text(path) == source_text,
	)
	var schema_three: Dictionary = schema_four.duplicate(true)
	schema_three[&"save_format_version"] = 3
	schema_three.erase(&"farm")
	_write_text(path, JSON.stringify(schema_three, "", true, true))
	var third_repo: RefCounted = _repository(path, world)
	var third: Dictionary = third_repo.call("load_state") as Dictionary
	_add_case(
		cases,
		"P1 schema 3 migrates directly to schema 5 with legacy-neutral farm",
		not third.is_empty()
		and int(third[&"save_format_version"]) == 5
		and _sections_are_neutral(third[&"farm"] as Dictionary),
	)
	var unknown: Dictionary = base.duplicate(true)
	unknown[&"future"] = true
	_add_case(
		cases,
		"P1 exact schema-5 root rejects unknown keys",
		(_repository(TEST_ROOT + ".unknown", world).call("validate_envelope", unknown) as Dictionary)
		.is_empty(),
	)
	_clear_artifacts(path)


static func _test_section_validators(cases: Array[Dictionary]) -> void:
	var construction: Dictionary = SectionsScript.neutral_construction()
	var gathering: Dictionary = SectionsScript.neutral_gathering()
	var workforce: Dictionary = SectionsScript.neutral_workforce()
	var logistics: Dictionary = SectionsScript.neutral_logistics()
	_add_case(
		cases,
		"P1 all neutral settlement sections validate with exact keys",
		not SectionsScript.validate_construction(construction).is_empty()
		and not SectionsScript.validate_gathering(gathering).is_empty()
		and not SectionsScript.validate_workforce(workforce).is_empty()
		and not SectionsScript.validate_logistics(logistics).is_empty()
		and not SectionsScript.validate_fishing(SectionsScript.neutral_fishing()).is_empty()
		and not SectionsScript.validate_orchard(SectionsScript.neutral_orchard()).is_empty()
		and not SectionsScript.validate_tutorial(SectionsScript.neutral_tutorial()).is_empty(),
	)
	var unknown: Dictionary = gathering.duplicate(true)
	unknown[&"unknown"] = true
	_add_case(
		cases,
		"P1 settlement sections reject unknown keys",
		SectionsScript.validate_gathering(unknown).is_empty(),
	)
	var buildings: Array[Dictionary] = [_building("building.a", Vector2i(0, 0))]
	construction[&"buildings"] = buildings
	var duplicate: Dictionary = construction.duplicate(true)
	(duplicate[&"buildings"] as Array).append(_building("building.a", Vector2i(2, 0)))
	_add_case(
		cases,
		"P1 construction rejects duplicate stable instance IDs",
		SectionsScript.validate_construction(duplicate).is_empty(),
	)
	var overlap: Dictionary = construction.duplicate(true)
	(overlap[&"buildings"] as Array).append(_building("building.b", Vector2i(0, 0)))
	_add_case(
		cases,
		"P1 construction rejects overlapping footprints",
		SectionsScript.validate_construction(overlap).is_empty(),
	)
	var orphan_gathering: Dictionary = SectionsScript.neutral_gathering()
	orphan_gathering[&"resource_deltas"] = [
		{
			&"source_id": "source.a",
			&"remaining_charges": 1,
			&"renewal_day": 0,
			&"reserved_by": "building.missing",
		}
	]
	_add_case(
		cases,
		"P1 farm-wide links reject orphan resource reservations",
		not SectionsScript.validate_links(construction, orphan_gathering, workforce, logistics),
	)
	var orphan_workforce: Dictionary = SectionsScript.neutral_workforce()
	orphan_workforce[&"settlers"] = [_settler("settler.a")]
	orphan_workforce[&"work_assignments"] = [
		{&"settler_id": "settler.a", &"site_id": "building.missing", &"slot": 0, &"shift": 0}
	]
	var checked_workforce: Dictionary = SectionsScript.validate_workforce(orphan_workforce)
	_add_case(
		cases,
		"P1 farm-wide links reject orphan work sites",
		not checked_workforce.is_empty()
		and not SectionsScript.validate_links(
			construction, gathering, checked_workforce, logistics
		),
	)
	var duplicate_bed: Dictionary = SectionsScript.neutral_workforce()
	duplicate_bed[&"settlers"] = [_settler("settler.a"), _settler("settler.b")]
	duplicate_bed[&"housing_assignments"] = [
		{&"settler_id": "settler.a", &"bed_id": "bed.a"},
		{&"settler_id": "settler.b", &"bed_id": "bed.a"},
	]
	_add_case(
		cases,
		"P1 workforce rejects duplicate beds",
		SectionsScript.validate_workforce(duplicate_bed).is_empty(),
	)
	var building_cap: Dictionary = SectionsScript.neutral_construction()
	(building_cap[&"buildings"] as Array).resize(SectionsScript.MAX_BUILDINGS + 1)
	var delta_cap: Dictionary = SectionsScript.neutral_gathering()
	(delta_cap[&"resource_deltas"] as Array).resize(SectionsScript.MAX_RESOURCE_DELTAS + 1)
	var tree_cap: Dictionary = SectionsScript.neutral_orchard()
	(tree_cap[&"trees"] as Array).resize(SectionsScript.MAX_TREES + 1)
	var job_cap: Dictionary = SectionsScript.neutral_logistics()
	(job_cap[&"jobs"] as Array).resize(SectionsScript.MAX_LOGISTICS_JOBS + 1)
	_add_case(
		cases,
		"P1 cap plus one rejects construction, gathering, orchard, and logistics",
		SectionsScript.validate_construction(building_cap).is_empty()
		and SectionsScript.validate_gathering(delta_cap).is_empty()
		and SectionsScript.validate_orchard(tree_cap).is_empty()
		and SectionsScript.validate_logistics(job_cap).is_empty(),
	)
	var recipe_cap: Dictionary = _building("building.a", Vector2i.ZERO)
	(recipe_cap[&"recipe_policies"] as Array).resize(SectionsScript.MAX_RECIPES_PER_BUILDING + 1)
	construction[&"buildings"] = [recipe_cap]
	_add_case(
		cases,
		"P1 recipes per building enforce the hard cap",
		SectionsScript.validate_construction(construction).is_empty(),
	)


static func _test_receipts(cases: Array[Dictionary]) -> void:
	var ledger: Dictionary = ReceiptLedgerScript.make_neutral()
	var payload: Dictionary = {&"cell": [8, 10], &"operation": "collect"}
	var result: Dictionary = {&"status": "collected", &"amount": 1}
	var first: Dictionary = ReceiptLedgerScript.record(ledger, "quick:collect:001", payload, result)
	var duplicate: Dictionary = ReceiptLedgerScript.record(
		first[&"candidate"], "quick:collect:001", payload, {&"status": "wrong"}
	)
	_add_case(
		cases,
		"P1 exact-once duplicate returns the first deterministic result",
		bool(first[&"ok"])
		and first[&"status"] == &"recorded"
		and bool(duplicate[&"ok"])
		and duplicate[&"status"] == &"duplicate"
		and duplicate[&"result"] == result,
	)
	var conflict: Dictionary = ReceiptLedgerScript.record(
		first[&"candidate"], "quick:collect:001", {&"cell": [9, 10]}, result
	)
	_add_case(
		cases,
		"P1 exact-once receipt rejects conflicting payload reuse",
		not bool(conflict[&"ok"]) and conflict[&"status"] == &"conflict",
	)
	_add_case(
		cases,
		"P1 receipt token grammar rejects unknown namespaces and empty segments",
		ReceiptLedgerScript.fingerprint(payload).length() == 64
		and (ReceiptLedgerScript.lookup(ledger, "unknown:001", payload)[&"status"] == &"invalid")
		and (ReceiptLedgerScript.lookup(ledger, "quick::001", payload)[&"status"] == &"invalid"),
	)
	var forward: Dictionary = ReceiptLedgerScript.make_neutral()
	var reverse: Dictionary = ReceiptLedgerScript.make_neutral()
	for index: int in 8:
		forward = ReceiptLedgerScript.record(
			forward, "day:test:%02d" % index, {&"index": index}, {&"index": index}
		)[&"candidate"]
	for index: int in range(7, -1, -1):
		reverse = ReceiptLedgerScript.record(
			reverse, "day:test:%02d" % index, {&"index": index}, {&"index": index}
		)[&"candidate"]
	_add_case(
		cases,
		"P1 receipt serialization stays canonical under bounded history retention",
		ReceiptLedgerScript.validate(forward) == forward
		and ReceiptLedgerScript.validate(reverse) == reverse
		and (forward[&"entries"] as Array).size()
		== int(ReceiptLedgerScript.NAMESPACE_LIMITS["day"])
		and (reverse[&"entries"] as Array).size()
		== int(ReceiptLedgerScript.NAMESPACE_LIMITS["day"]),
	)
	var full: Dictionary = ReceiptLedgerScript.make_neutral()
	for index: int in ReceiptLedgerScript.MAX_RECEIPTS:
		full = ReceiptLedgerScript.record(
			full, "shift:cap:%03d" % index, {&"index": index}, {&"index": index}
		)[&"candidate"]
	var over: Dictionary = ReceiptLedgerScript.record(
		full, "shift:cap:overflow", {&"index": 999}, {&"index": 999}
	)
	_add_case(
		cases,
		"P1 receipt ledger retains its namespace quota and replays the newest token",
		(full[&"entries"] as Array).size()
		== int(ReceiptLedgerScript.NAMESPACE_LIMITS["shift"])
		and bool(over[&"ok"])
		and over[&"status"] == &"recorded"
		and ReceiptLedgerScript.lookup(
			over[&"candidate"], "shift:cap:overflow", {&"index": 999}
		)[&"status"] == &"duplicate",
	)
	var unknown: Dictionary = full.duplicate(true)
	unknown[&"unknown"] = true
	_add_case(
		cases,
		"P1 receipt ledger rejects unknown keys",
		ReceiptLedgerScript.validate(unknown).is_empty(),
	)


static func _test_hashes(
	cases: Array[Dictionary], repository: RefCounted, base: Dictionary
) -> void:
	var changed_metadata: Dictionary = base.duplicate(true)
	(changed_metadata[&"metadata"] as Dictionary)[&"saved_at_unix"] += 1
	_add_case(
		cases,
		"P1 gameplay state hash excludes volatile envelope metadata",
		StateHashScript.state_hash(base) == StateHashScript.state_hash(changed_metadata),
	)
	var candidate_farm: Dictionary = (base[&"farm"] as Dictionary).duplicate(true)
	(candidate_farm[&"tutorial"] as Dictionary)[&"suppressed"] = true
	var saved: bool = bool(repository.call("save_candidate_envelope", base, candidate_farm))
	var second: Dictionary = repository.call("load_state") as Dictionary
	var revisions: Dictionary = (second[&"farm"] as Dictionary)[&"revisions"] as Dictionary
	_add_case(
		cases,
		"P1 committed revisions advance exactly once with source and result hashes",
		saved
		and int(revisions[&"source_revision"]) == 1
		and int(revisions[&"result_revision"]) == 2
		and revisions[&"source_hash"] == StateHashScript.state_hash(base)
		and StateHashScript.result_hash_matches(second),
	)
	var tampered: Dictionary = second.duplicate(true)
	(tampered[&"farm"] as Dictionary)[&"tutorial"][&"suppressed"] = false
	_add_case(
		cases,
		"P1 result hashes reject gameplay-state tampering",
		not StateHashScript.result_hash_matches(tampered)
		and (repository.call("validate_envelope", tampered) as Dictionary).is_empty(),
	)


static func _test_budgets(
	cases: Array[Dictionary], repository: RefCounted, base: Dictionary
) -> void:
	var ordinary: Dictionary = BudgetCatalogScript.preflight(base)
	var maximum: Dictionary = BudgetCatalogScript.simultaneous_maximum(base)
	var validated: Dictionary = repository.call("validate_envelope", maximum) as Dictionary
	var preflight: Dictionary = BudgetCatalogScript.preflight(maximum)
	_add_case(
		cases,
		"P1 ordinary save remains below the 256 KiB target",
		bool(ordinary[&"ok"])
		and int(ordinary[&"bytes"]) < BudgetCatalogScript.ORDINARY_TARGET_BYTES,
	)
	_add_case(
		cases,
		"P1 simultaneous documented maximum is validator-valid and below 1.5 MiB",
		not validated.is_empty()
		and bool(preflight[&"ok"])
		and int(preflight[&"bytes"]) < BudgetCatalogScript.MAX_CANONICAL_BYTES,
	)
	_add_case(
		cases,
		"P1 every measured maximum section stays within its declared budget",
		_sections_fit(preflight[&"sections"] as Dictionary),
	)
	var farm: Dictionary = maximum[&"farm"] as Dictionary
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	_add_case(
		cases,
		"P1 maximum generator fills every documented bounded collection",
		(farm[&"plots"] as Array).size() == FarmSaveSchemaScript.MAX_PLOTS
		and ((homestead[&"construction"] as Dictionary)[&"buildings"] as Array).size()
		== SectionsScript.MAX_BUILDINGS
		and ((homestead[&"workforce"] as Dictionary)[&"settlers"] as Array).size()
		== SectionsScript.MAX_SETTLERS
		and ((farm[&"gathering"] as Dictionary)[&"resource_deltas"] as Array).size()
		== SectionsScript.MAX_RESOURCE_DELTAS
		and ((farm[&"logistics"] as Dictionary)[&"jobs"] as Array).size()
		== SectionsScript.MAX_LOGISTICS_JOBS
		and ((farm[&"fishing"] as Dictionary)[&"spots"] as Array).size()
		== FishingCatalogScript.SPOT_IDS.size()
		and ((farm[&"orchard"] as Dictionary)[&"trees"] as Array).size()
		== SectionsScript.MAX_TREES
		and ((farm[&"receipts"] as Dictionary)[&"entries"] as Array).size()
		== ReceiptLedgerScript.MAX_RECEIPTS,
	)
	print(
		"[P1_MAX_ENVELOPE] bytes=%d limit=%d ordinary=%d"
		% [preflight[&"bytes"], BudgetCatalogScript.MAX_CANONICAL_BYTES, ordinary[&"bytes"]]
	)


static func _test_fault_recovery(
	cases: Array[Dictionary],
	world: RefCounted,
	run_snapshot: Dictionary,
	profile_snapshot: Dictionary,
) -> void:
	for phase: StringName in FaultInjectorScript.PHASES:
		var path: String = TEST_ROOT + ".fault." + String(phase)
		_clear_artifacts(path)
		var repository: RefCounted = _repository(path, world)
		var first_saved: bool = bool(
			repository.call(
				"save_state", world.call("make_snapshot"), run_snapshot, profile_snapshot
			)
		)
		var source: Dictionary = repository.call("load_state") as Dictionary
		var source_farm: Dictionary = (source[&"farm"] as Dictionary).duplicate(true)
		var candidate_farm: Dictionary = source_farm.duplicate(true)
		(candidate_farm[&"tutorial"] as Dictionary)[&"suppressed"] = true
		var injector: RefCounted = FaultInjectorScript.new() as RefCounted
		injector.call("arm", phase)
		repository.call("set_fault_injector", injector)
		var saved: bool = bool(repository.call("save_candidate_envelope", source, candidate_farm))
		var memory: Dictionary = repository.call("get_last_committed_envelope") as Dictionary
		var reopened: RefCounted = _repository(path, world)
		var recovered: Dictionary = reopened.call("load_state") as Dictionary
		var complete: bool = _is_complete_source_or_candidate(recovered)
		_add_case(
			cases,
			"P1 %s fault restarts to complete source or candidate" % phase,
			first_saved
			and not saved
			and bool(injector.call("was_triggered"))
			and complete,
		)
		_add_case(
			cases,
			"P1 %s fault does not publish failed state in memory" % phase,
			int(repository.call("get_write_sequence")) == 1
			and not bool(((memory[&"farm"] as Dictionary)[&"tutorial"] as Dictionary)[&"suppressed"]),
		)
		_clear_artifacts(path)


static func _test_browser_capability(cases: Array[Dictionary]) -> void:
	var native: Dictionary = BrowserCapabilityScript.from_signals(false, true, true)
	var blocked: Dictionary = BrowserCapabilityScript.from_signals(true, false, false)
	var volatile: Dictionary = BrowserCapabilityScript.from_signals(true, true, false)
	var persistent: Dictionary = BrowserCapabilityScript.from_signals(true, true, true)
	_add_case(
		cases,
		"P1 browser capability distinguishes native, blocked, volatile, and persistent storage",
		BrowserCapabilityScript.validate(native) == native
		and BrowserCapabilityScript.validate(blocked) == blocked
		and BrowserCapabilityScript.validate(volatile) == volatile
		and BrowserCapabilityScript.validate(persistent) == persistent,
	)
	var dishonest: Dictionary = persistent.duplicate(true)
	dishonest[&"persistent_guaranteed"] = false
	_add_case(
		cases,
		"P1 browser capability rejects dishonest guarantee combinations",
		BrowserCapabilityScript.validate(dishonest).is_empty(),
	)


static func _test_recovery_ordering(
	cases: Array[Dictionary],
	world: RefCounted,
	run_snapshot: Dictionary,
	profile_snapshot: Dictionary,
) -> void:
	var path: String = TEST_ROOT + ".sequence-order"
	_clear_artifacts(path)
	var repository: RefCounted = _repository(path, world)
	var first_saved: bool = bool(
		repository.call("save_state", world.call("make_snapshot"), run_snapshot, profile_snapshot)
	)
	var source: Dictionary = repository.call("load_state") as Dictionary
	var farm: Dictionary = (source.get(&"farm", {}) as Dictionary).duplicate(true)
	if not farm.is_empty():
		(farm[&"tutorial"] as Dictionary)[&"suppressed"] = true
	var second_saved: bool = bool(repository.call("save_candidate_envelope", source, farm))
	var backup_path: String = path + ".bak"
	var parser: JSON = JSON.new()
	var backup_text: String = _read_text(backup_path)
	var parsed: bool = parser.parse(backup_text) == OK and parser.data is Dictionary
	if parsed:
		((parser.data as Dictionary)[&"metadata"] as Dictionary)[&"write_sequence"] = 999_999
		_write_text(backup_path, JSON.stringify(parser.data, "", true, true))
	var reopened: RefCounted = _repository(path, world)
	var recovered: Dictionary = reopened.call("load_state") as Dictionary
	var recovered_farm: Dictionary = recovered.get(&"farm", {}) as Dictionary
	var revisions: Dictionary = recovered_farm.get(&"revisions", {}) as Dictionary
	_add_case(
		cases,
		"P1 recovery orders valid candidates by hash-bound gameplay revision",
		first_saved
		and second_saved
		and parsed
		and reopened.call("get_selected_source") == path
		and int(revisions.get(&"result_revision", 0)) == 2
		and bool((recovered_farm.get(&"tutorial", {}) as Dictionary).get(&"suppressed", false)),
	)
	_clear_artifacts(path)


static func _farm_v1(source: Dictionary) -> Dictionary:
	var legacy: Dictionary = source.duplicate(true)
	legacy[&"state_version"] = 1
	for key: StringName in [
		&"gathering", &"logistics", &"fishing", &"orchard", &"tutorial", &"receipts", &"revisions"
	]:
		legacy.erase(key)
	var homestead: Dictionary = (legacy[&"homestead"] as Dictionary).duplicate(true)
	homestead[&"state_version"] = 1
	homestead.erase(&"construction")
	homestead.erase(&"workforce")
	legacy[&"homestead"] = homestead
	return legacy


static func _sections_are_neutral(farm: Dictionary) -> bool:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	return (
		farm.get(&"gathering") == SectionsScript.neutral_gathering()
		and farm.get(&"logistics") == SectionsScript.neutral_logistics()
		and farm.get(&"fishing") == SectionsScript.neutral_fishing()
		and farm.get(&"orchard") == SectionsScript.neutral_orchard()
		and farm.get(&"tutorial") == SectionsScript.neutral_tutorial()
		and homestead.get(&"construction") == SectionsScript.neutral_construction()
		and homestead.get(&"workforce") == SectionsScript.neutral_workforce()
	)


static func _building(instance_id: String, anchor: Vector2i) -> Dictionary:
	return {
		&"instance_id": instance_id,
		&"blueprint_id": "blueprint.test",
		&"anchor": [anchor.x, anchor.y],
		&"orientation": 0,
		&"level": 1,
		&"state": "complete",
		&"footprint": [[anchor.x, anchor.y]],
		&"local_stacks": [],
		&"recipe_policies": [],
	}


static func _settler(settler_id: String) -> Dictionary:
	return {
		&"settler_id": settler_id,
		&"status": "active",
		&"morale": 100,
		&"injured_until_day": 0,
	}


static func _sections_fit(measured: Dictionary) -> bool:
	for section_name: String in BudgetCatalogScript.SECTION_BUDGETS:
		if int(measured.get(section_name, -1)) > int(BudgetCatalogScript.SECTION_BUDGETS[section_name]):
			return false
	return true


static func _is_complete_source_or_candidate(envelope: Dictionary) -> bool:
	if envelope.is_empty() or not StateHashScript.result_hash_matches(envelope):
		return false
	var metadata: Dictionary = envelope[&"metadata"] as Dictionary
	var farm: Dictionary = envelope[&"farm"] as Dictionary
	var revisions: Dictionary = farm[&"revisions"] as Dictionary
	var suppressed: bool = bool((farm[&"tutorial"] as Dictionary)[&"suppressed"])
	if suppressed:
		return int(metadata[&"write_sequence"]) == 2 and int(revisions[&"result_revision"]) == 2
	return int(metadata[&"write_sequence"]) == 1 and int(revisions[&"result_revision"]) == 1


static func _repository(path: String, world: RefCounted) -> RefCounted:
	var repository: RefCounted = SaveRepositoryScript.new() as RefCounted
	return repository if bool(repository.call("configure", path, world, "p1-test")) else null


static func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


static func _write_text(path: String, value: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(value)
	file.close()


static func _clear_artifacts(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path.get_base_dir())
	if directory == null:
		return
	var prefix: String = path.get_file()
	for file_name: String in directory.get_files():
		if file_name == prefix or file_name.begins_with(prefix + "."):
			directory.remove(file_name)


static func _add_case(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
