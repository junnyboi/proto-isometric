extends RefCounted

const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")
const ConstructionCatalogScript: GDScript = preload(
	"res://scripts/construction_blueprint_catalog.gd"
)
const ConstructionLinksScript: GDScript = preload("res://scripts/construction_envelope_links.gd")
const ReceiptLedgerScript: GDScript = preload("res://scripts/exact_once_receipt_ledger.gd")
const ResourceDepositCatalogScript: GDScript = preload("res://scripts/resource_deposit_catalog.gd")
const StateHashScript: GDScript = preload("res://scripts/persistence_state_hash.gd")
const WorldLedgerScript: GDScript = preload("res://scripts/world_mutation_ledger.gd")

const MAX_CANONICAL_BYTES: int = 1_572_864
const ORDINARY_TARGET_BYTES: int = 262_144
const SECTION_BUDGETS: Dictionary = {
	"world": 600_000,
	"active_run": 96_000,
	"profile": 32_000,
	"farm_legacy": 420_000,
	"construction": 150_000,
	"gathering": 90_000,
	"workforce": 48_000,
	"logistics": 72_000,
	"fishing": 24_000,
	"orchard": 180_000,
	"tutorial": 4_096,
	"receipts": 180_000,
	"revisions": 1_024,
}


static func canonical_json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


static func canonical_bytes(value: Variant) -> int:
	return canonical_json(value).to_utf8_buffer().size()


static func preflight(envelope: Dictionary) -> Dictionary:
	var measured: Dictionary = measure_sections(envelope)
	if measured.is_empty():
		return {&"ok": false, &"bytes": 0, &"reason": &"malformed_envelope", &"sections": {}}
	var total: int = canonical_bytes(envelope)
	if total >= MAX_CANONICAL_BYTES:
		return {&"ok": false, &"bytes": total, &"reason": &"envelope_budget", &"sections": measured}
	for section_name: String in SECTION_BUDGETS:
		if int(measured[section_name]) > int(SECTION_BUDGETS[section_name]):
			return {
				&"ok": false,
				&"bytes": total,
				&"reason": StringName("section_budget:%s" % section_name),
				&"sections": measured,
			}
	return {&"ok": true, &"bytes": total, &"reason": &"", &"sections": measured}


static func measure_sections(envelope: Dictionary) -> Dictionary:
	if not envelope.has(&"world") or not envelope.has(&"farm"):
		return {}
	var farm: Dictionary = envelope[&"farm"] as Dictionary
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	for key: StringName in [
		&"construction", &"gathering", &"workforce", &"logistics", &"fishing", &"orchard",
		&"tutorial", &"receipts", &"revisions"
	]:
		if key in [&"construction", &"workforce"]:
			if not homestead.has(key):
				return {}
		elif not farm.has(key):
			return {}
	var farm_legacy: Dictionary = farm.duplicate(true)
	for key: StringName in [
		&"gathering", &"logistics", &"fishing", &"orchard", &"tutorial", &"receipts", &"revisions"
	]:
		farm_legacy.erase(key)
	var homestead_legacy: Dictionary = (farm_legacy[&"homestead"] as Dictionary).duplicate(true)
	homestead_legacy.erase(&"construction")
	homestead_legacy.erase(&"workforce")
	farm_legacy[&"homestead"] = homestead_legacy
	return {
		"world": canonical_bytes(envelope[&"world"]),
		"active_run": canonical_bytes(envelope.get(&"active_run")),
		"profile": canonical_bytes(envelope.get(&"profile")),
		"farm_legacy": canonical_bytes(farm_legacy),
		"construction": canonical_bytes(homestead[&"construction"]),
		"gathering": canonical_bytes(farm[&"gathering"]),
		"workforce": canonical_bytes(homestead[&"workforce"]),
		"logistics": canonical_bytes(farm[&"logistics"]),
		"fishing": canonical_bytes(farm[&"fishing"]),
		"orchard": canonical_bytes(farm[&"orchard"]),
		"tutorial": canonical_bytes(farm[&"tutorial"]),
		"receipts": canonical_bytes(farm[&"receipts"]),
		"revisions": canonical_bytes(farm[&"revisions"]),
	}


static func simultaneous_maximum(base_envelope: Dictionary) -> Dictionary:
	var envelope: Dictionary = base_envelope.duplicate(true)
	var farm: Dictionary = envelope[&"farm"] as Dictionary
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	var buildings: Array[Dictionary] = []
	var blueprint_ids: Array[StringName] = ConstructionCatalogScript.ids()
	for index: int in SectionsScript.MAX_BUILDINGS:
		var blueprint_id: StringName = blueprint_ids[index % blueprint_ids.size()]
		var anchor: Vector2i = Vector2i(index * 20, index * 20)
		var orientation: int = index % 4
		var footprint: Array[Array] = ConstructionCatalogScript.encoded_footprint(
			blueprint_id, anchor, orientation
		)
		var stacks: Array[Dictionary] = []
		for stack_index: int in SectionsScript.MAX_LOCAL_STACKS:
			stacks.append({&"item_id": "item.maximum.%02d" % stack_index, &"count": 999_999})
		var recipes: Array[Dictionary] = []
		for recipe_index: int in SectionsScript.MAX_RECIPES_PER_BUILDING:
			recipes.append(
				{
					&"recipe_id": "recipe.maximum.%02d" % recipe_index,
					&"enabled": true,
					&"priority": 9,
					&"target_count": 999_999,
				}
			)
		buildings.append(
			{
				&"instance_id": "building.maximum.%03d" % index,
				&"blueprint_id": str(blueprint_id),
				&"anchor": [anchor.x, anchor.y],
				&"orientation": orientation,
				&"level": ConstructionCatalogScript.MAX_LEVEL,
				&"state": "complete",
				&"footprint": footprint,
				&"local_stacks": stacks,
				&"recipe_policies": recipes,
			}
		)
	homestead[&"construction"] = {&"state_version": 1, &"buildings": buildings}
	homestead[&"workforce"] = _maximum_workforce()
	farm[&"homestead"] = homestead
	farm[&"gathering"] = {&"state_version": 1, &"resource_deltas": _maximum_deltas()}
	farm[&"logistics"] = {&"state_version": 1, &"jobs": _maximum_jobs()}
	farm[&"fishing"] = {&"state_version": 1, &"spots": _maximum_spots()}
	farm[&"orchard"] = {&"state_version": 1, &"trees": _maximum_trees()}
	farm[&"tutorial"] = {
		&"state_version": 1, &"completion_mask": (1 << SectionsScript.MAX_TUTORIAL_LESSONS) - 1,
		&"suppressed": true
	}
	farm[&"receipts"] = _maximum_receipts()
	farm[&"revisions"] = _maximum_revisions()
	envelope[&"farm"] = farm
	envelope[&"world"] = _maximum_world(envelope[&"world"], buildings)
	var revisions: Dictionary = farm[&"revisions"] as Dictionary
	revisions[&"result_hash"] = StateHashScript.state_hash(envelope)
	(envelope[&"farm"] as Dictionary)[&"revisions"] = revisions
	return envelope


static func _maximum_world(world_value: Variant, buildings: Array[Dictionary]) -> Dictionary:
	var world: Dictionary = (world_value as Dictionary).duplicate(true)
	var ledger: Dictionary = (
		WorldLedgerScript.validate(world[&"mutation_ledger"])
		if world.has(&"mutation_ledger")
		else WorldLedgerScript.from_legacy(world)
	)
	for building: Dictionary in buildings:
		var placed: Dictionary = WorldLedgerScript.place(
			ledger, ConstructionLinksScript.ledger_record(building)
		)
		if not bool(placed[&"ok"]):
			return {}
		ledger = placed[&"candidate"] as Dictionary
	var adapted: Dictionary = WorldLedgerScript.legacy_arrays_exact(world, ledger)
	if adapted.is_empty():
		return {}
	adapted[&"mutation_ledger"] = ledger
	return adapted


static func _maximum_deltas() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for index: int in SectionsScript.MAX_RESOURCE_DELTAS:
		var kind: StringName = (
			ResourceDepositCatalogScript.SALVAGE
			if index % 2 == 0
			else ResourceDepositCatalogScript.MINERAL
		)
		var cell: Vector2i = Vector2i(
			-72 + index % 145, -72 + floori(float(index) / 145.0)
		)
		records.append(
			{
				&"source_id": str(
					ResourceDepositCatalogScript.canonical_source_id(kind, cell)
				),
				&"remaining_charges": 0,
					&"renewal_day": 0,
					&"reserved_by": "building.maximum.%03d" % (index % SectionsScript.MAX_BUILDINGS),
				}
			)
	records.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"source_id"]) < str(b[&"source_id"])
	)
	return records


static func _maximum_workforce() -> Dictionary:
	var settlers: Array[Dictionary] = []
	var housing: Array[Dictionary] = []
	var work: Array[Dictionary] = []
	var concerns: Array[Dictionary] = []
	for index: int in SectionsScript.MAX_SETTLERS:
		var settler_id: String = "settler.maximum.%02d" % index
		settlers.append(
			{&"settler_id": settler_id, &"status": "notice", &"morale": 100,
			&"injured_until_day": 999_999}
		)
		housing.append({&"settler_id": settler_id, &"bed_id": "bed.maximum.%02d" % index})
		work.append(
			{&"settler_id": settler_id, &"site_id": "building.maximum.%03d" % index,
			&"slot": 31, &"shift": index % 2}
		)
		concerns.append(
			{&"concern_id": "concern.maximum.%02d" % index, &"settler_id": settler_id,
			&"reason_id": "reason.maximum.%02d" % index, &"opened_day": 999_999}
		)
	return {
		&"state_version": 1, &"settlers": settlers, &"housing_assignments": housing,
		&"work_assignments": work, &"concerns": concerns,
		&"applicant_lifecycle": {
			&"current_applicant_id": "settler.maximum.applicant",
			&"offered_day": 999_996,
			&"expires_day": 999_999,
			&"deferred_until_day": 999_997,
			&"next_offer_day": 1_000_000,
			&"sequence": 999_999,
			&"deferrals": 2,
		},
	}


static func _maximum_jobs() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for index: int in SectionsScript.MAX_LOGISTICS_JOBS:
		records.append(
			{
				&"job_id": "job.maximum.%03d" % index,
				&"source_id": "building.maximum.%03d" % (index % SectionsScript.MAX_BUILDINGS),
				&"destination_id": "building.maximum.%03d" % ((index + 1) % SectionsScript.MAX_BUILDINGS),
				&"item_id": "item.maximum.%03d" % index,
				&"count": 999_999,
				&"priority": 9,
				&"age": 999_999,
			}
		)
	return records


static func _maximum_spots() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for index: int in SectionsScript.MAX_FISHING_SPOTS:
		records.append(
			{&"spot_id": "fish.spot.maximum.%03d" % index, &"cast_sequence": 999_999,
			&"remaining_catches": 999_999, &"renewal_day": 999_999}
		)
	return records


static func _maximum_trees() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for index: int in SectionsScript.MAX_TREES:
		records.append(
			{
				&"tree_id": "tree.maximum.%03d" % index,
				&"species_id": "tree.species.maximum",
				&"cell": [index % 64, index / 64],
				&"planted_day": 999_999,
				&"growth_points": 999_999,
				&"harvest_sequence": 999_999,
			}
		)
	return records


static func _maximum_receipts() -> Dictionary:
	var ledger: Dictionary = ReceiptLedgerScript.make_neutral()
	for index: int in ReceiptLedgerScript.MAX_RECEIPTS:
		var recorded: Dictionary = ReceiptLedgerScript.record(
			ledger,
			"production:maximum:%03d" % index,
			{&"operation": "maximum", &"sequence": index},
			{&"status": "complete", &"amount": 999_999, &"sequence": index},
		)
		ledger = recorded[&"candidate"] as Dictionary
	return ledger


static func _maximum_revisions() -> Dictionary:
	return {
		&"state_version": 1,
		&"source_revision": 9_007_199_254_740_990,
		&"result_revision": 9_007_199_254_740_991,
		&"source_hash": "f".repeat(64),
		&"result_hash": "",
	}
