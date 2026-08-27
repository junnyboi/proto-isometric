extends RefCounted

const ReceiptLedgerScript: GDScript = preload("res://scripts/exact_once_receipt_ledger.gd")
const StateHashScript: GDScript = preload("res://scripts/persistence_state_hash.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const FishingCatalogScript: GDScript = preload("res://scripts/fishing_catalog.gd")
const FarmOccupancyScript: GDScript = preload("res://scripts/farm_occupancy_service.gd")
const OrchardCatalogScript: GDScript = preload("res://scripts/orchard_catalog.gd")
const RecipeCatalogScript: GDScript = preload("res://scripts/recipe_catalog.gd")
const BlueprintCatalogScript: GDScript = preload(
	"res://scripts/construction_blueprint_catalog.gd"
)

const STATE_VERSION: int = 1
const MAX_BUILDINGS: int = 64
const MAX_FOOTPRINT_CELLS: int = 16
const MAX_RESOURCE_DELTAS: int = 256
const MAX_SETTLERS: int = 24
const MAX_HOUSING_ASSIGNMENTS: int = 24
const MAX_WORK_ASSIGNMENTS: int = 24
const MAX_CONCERNS: int = 24
const MAX_SHIFT_REPORTS: int = 88
const MAX_DEPARTED_SETTLERS: int = 24
const MAX_WELLBEING_REASONS: int = 8
const MAX_LOGISTICS_JOBS: int = 128
const MAX_RESERVE_RULES: int = 64
const MAX_FISHING_SPOTS: int = 64
const MAX_TREES: int = FarmOccupancyScript.ORCHARD_CAPACITY
const MAX_ORCHARD_DAY: int = 9_999 * 4 * 14
const MAX_TUTORIAL_LESSONS: int = 16
const MAX_LOCAL_STACKS: int = 12
const MAX_RECIPES_PER_BUILDING: int = 8
const MAX_PRODUCTION_ORDERS: int = 8
const MAX_COORDINATE: int = 1_000_000
const MAX_NUMBER: int = 1_000_000_000

# Ownership split: homestead owns construction/workforce because they describe buildings and people.
# Farm retains the retired tutorial slot only so schema-5 saves remain loadable without data loss.
static func neutral_construction() -> Dictionary:
	return {&"state_version": STATE_VERSION, &"buildings": []}


static func neutral_gathering() -> Dictionary:
	return {&"state_version": STATE_VERSION, &"resource_deltas": []}


static func neutral_workforce() -> Dictionary:
	return {
		&"state_version": STATE_VERSION,
		&"settlers": [],
		&"housing_assignments": [],
		&"work_assignments": [],
		&"concerns": [],
		&"applicant_lifecycle": neutral_applicant_lifecycle(),
		&"shift_reports": [],
		&"departed_settler_ids": [],
	}


static func neutral_applicant_lifecycle() -> Dictionary:
	return {
		&"current_applicant_id": "",
		&"offered_day": 0,
		&"expires_day": 0,
		&"deferred_until_day": 0,
		&"next_offer_day": 7,
		&"sequence": 0,
		&"deferrals": 0,
	}


static func neutral_logistics() -> Dictionary:
	return {&"state_version": STATE_VERSION, &"jobs": [], &"reserve_rules": []}


static func neutral_fishing() -> Dictionary:
	return {&"state_version": STATE_VERSION, &"spots": []}


static func neutral_orchard() -> Dictionary:
	return {&"state_version": STATE_VERSION, &"trees": []}


static func neutral_tutorial() -> Dictionary:
	# Compatibility-only: no runtime system reads or mutates this retired section.
	return {&"state_version": STATE_VERSION, &"completion_mask": 0, &"suppressed": false}


static func validate_construction(value: Variant) -> Dictionary:
	var section: Dictionary = _section(value, [&"state_version", &"buildings"])
	if section.is_empty():
		return {}
	var records: Variant = _records(
		section[&"buildings"], MAX_BUILDINGS, _building, &"instance_id"
	)
	if records == null or not _building_footprints_are_unique(records as Array):
		return {}
	return {&"state_version": STATE_VERSION, &"buildings": records}


static func validate_gathering(value: Variant) -> Dictionary:
	var section: Dictionary = _section(value, [&"state_version", &"resource_deltas"])
	if section.is_empty():
		return {}
	var records: Variant = _records(
		section[&"resource_deltas"], MAX_RESOURCE_DELTAS, _delta, &"source_id"
	)
	return {} if records == null else {&"state_version": STATE_VERSION, &"resource_deltas": records}


static func validate_workforce(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var canonical: Dictionary = (value as Dictionary).duplicate(true)
	var legacy_keys: Array[StringName] = [
		&"state_version", &"settlers", &"housing_assignments", &"work_assignments", &"concerns"
	]
	if _exact_keys(canonical, legacy_keys):
		canonical[&"applicant_lifecycle"] = neutral_applicant_lifecycle()
	var pre_p7_keys: Array[StringName] = legacy_keys.duplicate()
	pre_p7_keys.append(&"applicant_lifecycle")
	if _exact_keys(canonical, pre_p7_keys):
		canonical[&"shift_reports"] = []
	var pre_p9_keys: Array[StringName] = [
		&"state_version", &"settlers", &"housing_assignments", &"work_assignments",
		&"concerns", &"applicant_lifecycle", &"shift_reports",
	]
	if _exact_keys(canonical, pre_p9_keys):
		canonical[&"departed_settler_ids"] = []
	var keys: Array[StringName] = [
		&"state_version", &"settlers", &"housing_assignments", &"work_assignments", &"concerns",
		&"applicant_lifecycle", &"shift_reports", &"departed_settler_ids",
	]
	var section: Dictionary = _section(canonical, keys)
	if section.is_empty():
		return {}
	var settlers: Variant = _records(
		section[&"settlers"], MAX_SETTLERS, _settler, &"settler_id"
	)
	var housing: Variant = _records(
		section[&"housing_assignments"], MAX_HOUSING_ASSIGNMENTS, _housing, &"settler_id"
	)
	var work: Variant = _records(
		section[&"work_assignments"], MAX_WORK_ASSIGNMENTS, _work, &"settler_id"
	)
	var concerns: Variant = _records(
		section[&"concerns"], MAX_CONCERNS, _concern, &"concern_id"
	)
	var lifecycle: Dictionary = _applicant_lifecycle(section[&"applicant_lifecycle"])
	var reports: Variant = _records(
		section[&"shift_reports"], MAX_SHIFT_REPORTS, _shift_report, &"report_id"
	)
	var departed: Variant = _identifier_list(
		section[&"departed_settler_ids"], MAX_DEPARTED_SETTLERS, "settler."
	)
	if (
		settlers == null or housing == null or work == null or concerns == null
		or lifecycle.is_empty() or reports == null or departed == null
	):
		return {}
	if not _workforce_links_are_valid(settlers, housing, work, concerns, reports, departed):
		return {}
	return {
		&"state_version": STATE_VERSION,
		&"settlers": settlers,
		&"housing_assignments": housing,
		&"work_assignments": work,
		&"concerns": concerns,
		&"applicant_lifecycle": lifecycle,
		&"shift_reports": reports,
		&"departed_settler_ids": departed,
	}


static func validate_logistics(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var canonical: Dictionary = (value as Dictionary).duplicate(true)
	if _exact_keys(canonical, [&"state_version", &"jobs"]):
		canonical[&"reserve_rules"] = []
	var section: Dictionary = _section(
		canonical, [&"state_version", &"jobs", &"reserve_rules"]
	)
	if section.is_empty():
		return {}
	var records: Variant = _records(section[&"jobs"], MAX_LOGISTICS_JOBS, _job, &"job_id")
	var rules: Variant = _records(
		section[&"reserve_rules"], MAX_RESERVE_RULES, _reserve_rule, &"item_id"
	)
	if records == null or rules == null:
		return {}
	return {
		&"state_version": STATE_VERSION,
		&"jobs": records,
		&"reserve_rules": rules,
	}


static func validate_fishing(value: Variant) -> Dictionary:
	var section: Dictionary = _section(value, [&"state_version", &"spots"])
	if section.is_empty():
		return {}
	var records: Variant = _records(section[&"spots"], MAX_FISHING_SPOTS, _spot, &"spot_id")
	return {} if records == null else {&"state_version": STATE_VERSION, &"spots": records}


static func validate_orchard(value: Variant) -> Dictionary:
	var section: Dictionary = _section(value, [&"state_version", &"trees"])
	if section.is_empty():
		return {}
	var records: Variant = _records(section[&"trees"], MAX_TREES, _tree, &"tree_id")
	if records == null or not _record_cells_are_unique(records as Array, &"cell"):
		return {}
	return {&"state_version": STATE_VERSION, &"trees": records}


static func validate_tutorial(value: Variant) -> Dictionary:
	var keys: Array[StringName] = [&"state_version", &"completion_mask", &"suppressed"]
	var section: Dictionary = _section(value, keys)
	if section.is_empty():
		return {}
	var mask: Variant = _integer(section[&"completion_mask"], 0, (1 << MAX_TUTORIAL_LESSONS) - 1)
	if mask == null or not section[&"suppressed"] is bool:
		return {}
	return {
		&"state_version": STATE_VERSION,
		&"completion_mask": int(mask),
		&"suppressed": bool(section[&"suppressed"]),
	}


static func validate_receipts(value: Variant) -> Dictionary:
	return ReceiptLedgerScript.validate(value)


static func validate_revisions(value: Variant) -> Dictionary:
	return StateHashScript.validate_revisions(value)


static func validate_links(
	construction: Dictionary,
	gathering: Dictionary,
	workforce: Dictionary,
	logistics: Dictionary,
) -> bool:
	var building_ids: Dictionary = {}
	for building: Dictionary in construction.get(&"buildings", []) as Array[Dictionary]:
		building_ids[str(building[&"instance_id"])] = building
	for delta: Dictionary in gathering.get(&"resource_deltas", []) as Array[Dictionary]:
		var reserved_by: String = str(delta[&"reserved_by"])
		if not reserved_by.is_empty() and not building_ids.has(reserved_by):
			return false
	for assignment: Dictionary in workforce.get(&"work_assignments", []) as Array[Dictionary]:
		var assignment_site: String = str(assignment[&"site_id"])
		if (
			not building_ids.has(assignment_site)
			or not _work_site_slot_is_valid(
				building_ids[assignment_site] as Dictionary, int(assignment[&"slot"])
			)
		):
			return false
	for report: Dictionary in workforce.get(&"shift_reports", []) as Array[Dictionary]:
		var report_site: String = str(report[&"site_id"])
		if (
			not building_ids.has(report_site)
			or str((building_ids[report_site] as Dictionary)[&"state"]) != "complete"
		):
			return false
		if (
			int(report[&"slot"]) >= 0
			and not _work_site_slot_is_valid(
				building_ids[report_site] as Dictionary, int(report[&"slot"])
			)
		):
			return false
	for job: Dictionary in logistics.get(&"jobs", []) as Array[Dictionary]:
		var source_id: String = str(job[&"source_id"])
		var destination_id: String = str(job[&"destination_id"])
		if (
			not building_ids.has(source_id)
			or not building_ids.has(destination_id)
			or not _logistics_link_is_valid(
				building_ids[source_id] as Dictionary,
				building_ids[destination_id] as Dictionary,
			)
		):
			return false
	return true


static func validate_orchard_links(
	construction: Dictionary,
	orchard: Dictionary,
	plots: Array,
	machines: Array,
	home: Dictionary,
	facilities: Array,
) -> bool:
	var farm: Dictionary = {
		&"plots": plots,
		&"machines": machines,
		&"homestead": {
			&"home": home,
			&"facilities": facilities,
			&"construction": construction,
		},
		&"orchard": orchard,
	}
	var occupied: Dictionary = {}
	for tree: Dictionary in orchard.get(&"trees", []) as Array[Dictionary]:
		var raw_tree: Array = tree[&"cell"] as Array
		var cell: Vector2i = Vector2i(int(raw_tree[0]), int(raw_tree[1]))
		if occupied.has(cell) or FarmOccupancyScript.orchard_reason(farm, cell, false) != &"":
			return false
		occupied[cell] = true
	return true


static func _logistics_link_is_valid(source: Dictionary, destination: Dictionary) -> bool:
	if str(source[&"state"]) != "complete" or str(destination[&"state"]) != "complete":
		return false
	var source_blueprint: String = str(source[&"blueprint_id"])
	var destination_blueprint: String = str(destination[&"blueprint_id"])
	if destination_blueprint == "blueprint.fabricator_annex":
		return source_blueprint == "blueprint.field_warehouse"
	if destination_blueprint != "blueprint.field_warehouse":
		return false
	return source_blueprint in [
		"blueprint.salvage_camp",
		"blueprint.survey_drill",
		"blueprint.coppice_station",
		"blueprint.fabricator_annex",
		"blueprint.fishing_platform",
	]


static func _work_site_slot_is_valid(building: Dictionary, slot: int) -> bool:
	if str(building[&"state"]) != "complete":
		return false
	var blueprint_id: StringName = StringName(str(building[&"blueprint_id"]))
	var slots: Array[StringName] = BlueprintCatalogScript.work_slot_types(blueprint_id)
	return slot >= 0 and slot < slots.size()


static func _building(value: Dictionary) -> Dictionary:
	var canonical: Dictionary = value.duplicate(true)
	var legacy_keys: Array[StringName] = [
		&"instance_id", &"blueprint_id", &"anchor", &"orientation", &"level", &"state",
		&"footprint", &"local_stacks", &"recipe_policies"
	]
	if _exact_keys(canonical, legacy_keys):
		canonical[&"local_input_stacks"] = []
		canonical[&"production_orders"] = []
	var keys: Array[StringName] = [
		&"instance_id", &"blueprint_id", &"anchor", &"orientation", &"level", &"state",
		&"footprint", &"local_stacks", &"local_input_stacks", &"recipe_policies",
		&"production_orders"
	]
	if not _exact_keys(canonical, keys):
		return {}
	var anchor: Variant = _cell(canonical[&"anchor"])
	var footprint: Variant = _cells(canonical[&"footprint"], MAX_FOOTPRINT_CELLS)
	var stacks: Variant = _stacks(canonical[&"local_stacks"])
	var inputs: Variant = _stacks(canonical[&"local_input_stacks"])
	var recipes: Variant = _recipes(canonical[&"recipe_policies"])
	var orders: Variant = _records(
		canonical[&"production_orders"], MAX_PRODUCTION_ORDERS, _production_order, &"order_id"
	)
	var orientation: Variant = _integer(canonical[&"orientation"], 0, 3)
	var level: Variant = _integer(canonical[&"level"], 1, 99)
	if (
			anchor == null
			or footprint == null
			or stacks == null
			or inputs == null
			or recipes == null
			or orders == null
			or orientation == null
			or level == null
			or anchor not in (footprint as Array)
		or not _identifier(canonical[&"instance_id"])
		or not _identifier(canonical[&"blueprint_id"])
		or str(canonical[&"state"]) not in ["blueprint", "constructing", "complete"]
	):
		return {}
	if (
		str(canonical[&"blueprint_id"]) != "blueprint.fabricator_annex"
		and (
			not (inputs as Array).is_empty()
			or not (recipes as Array).is_empty()
			or not (orders as Array).is_empty()
		)
	):
		return {}
	return {
		&"instance_id": str(canonical[&"instance_id"]),
		&"blueprint_id": str(canonical[&"blueprint_id"]),
		&"anchor": anchor,
		&"orientation": int(orientation),
		&"level": int(level),
		&"state": str(canonical[&"state"]),
		&"footprint": footprint,
		&"local_stacks": stacks,
		&"local_input_stacks": inputs,
		&"recipe_policies": recipes,
		&"production_orders": orders,
	}


static func _delta(value: Dictionary) -> Dictionary:
	var keys: Array[StringName] = [&"source_id", &"remaining_charges", &"renewal_day", &"reserved_by"]
	if not _exact_keys(value, keys):
		return {}
	var charges: Variant = _integer(value[&"remaining_charges"], 0, MAX_NUMBER)
	var day: Variant = _integer(value[&"renewal_day"], 0, MAX_NUMBER)
	if charges == null or day == null or not _identifier(value[&"source_id"]):
		return {}
	if not str(value[&"reserved_by"]).is_empty() and not _identifier(value[&"reserved_by"]):
		return {}
	return {
		&"source_id": str(value[&"source_id"]),
		&"remaining_charges": int(charges),
		&"renewal_day": int(day),
		&"reserved_by": str(value[&"reserved_by"]),
	}


static func _settler(value: Dictionary) -> Dictionary:
	var canonical: Dictionary = value.duplicate(true)
	var legacy_keys: Array[StringName] = [
		&"settler_id", &"status", &"morale", &"injured_until_day",
	]
	if _exact_keys(canonical, legacy_keys):
		canonical[&"notice_day"] = 0
		canonical[&"last_reason_ids"] = []
	var keys: Array[StringName] = [
		&"settler_id", &"status", &"morale", &"injured_until_day",
		&"notice_day", &"last_reason_ids",
	]
	if not _exact_keys(canonical, keys) or not _identifier(canonical[&"settler_id"]):
		return {}
	var morale: Variant = _integer(canonical[&"morale"], 0, 100)
	var injured_day: Variant = _integer(canonical[&"injured_until_day"], 0, MAX_NUMBER)
	var notice_day: Variant = _integer(canonical[&"notice_day"], 0, MAX_NUMBER)
	var reasons: Variant = _identifier_list(
		canonical[&"last_reason_ids"], MAX_WELLBEING_REASONS, "wellbeing."
	)
	var statuses: Array[String] = ["active", "recovering", "notice"]
	var status: String = str(canonical[&"status"])
	if (
		morale == null or injured_day == null or notice_day == null or reasons == null
		or status not in statuses
		or status == "notice" and int(notice_day) == 0
	):
		return {}
	return {
		&"settler_id": str(canonical[&"settler_id"]),
		&"status": status,
		&"morale": int(morale),
		&"injured_until_day": int(injured_day),
		&"notice_day": int(notice_day),
		&"last_reason_ids": reasons,
	}


static func _housing(value: Dictionary) -> Dictionary:
	return _pair_record(value, &"settler_id", &"bed_id")


static func _work(value: Dictionary) -> Dictionary:
	var keys: Array[StringName] = [&"settler_id", &"site_id", &"slot", &"shift"]
	if not _exact_keys(value, keys):
		return {}
	var slot: Variant = _integer(value[&"slot"], 0, 31)
	var shift: Variant = _integer(value[&"shift"], 0, 1)
	if slot == null or shift == null or not _identifier(value[&"settler_id"]):
		return {}
	if not _identifier(value[&"site_id"]):
		return {}
	return {
		&"settler_id": str(value[&"settler_id"]),
		&"site_id": str(value[&"site_id"]),
		&"slot": int(slot),
		&"shift": int(shift),
	}


static func _shift_report(value: Dictionary) -> Dictionary:
	var keys: Array[StringName] = [
		&"report_id", &"site_id", &"settler_id", &"slot", &"shift", &"absolute_day",
		&"status", &"reason", &"source_id", &"item_id", &"count",
	]
	if not _exact_keys(value, keys):
		return {}
	var slot: Variant = _integer(value[&"slot"], -1, 31)
	var shift: Variant = _integer(value[&"shift"], -1, 1)
	var day: Variant = _integer(value[&"absolute_day"], 1, MAX_NUMBER)
	var count: Variant = _integer(value[&"count"], 0, MAX_NUMBER)
	if (
		slot == null or shift == null or day == null or count == null
		or not _identifier(value[&"report_id"]) or not _identifier(value[&"site_id"])
		or str(value[&"status"]) not in ["productive", "idle"]
	):
		return {}
	var settler_id: String = str(value[&"settler_id"])
	var reason: String = str(value[&"reason"])
	var source_id: String = str(value[&"source_id"])
	var item_id: String = str(value[&"item_id"])
	var productive: bool = str(value[&"status"]) == "productive"
	if productive:
		if (
			settler_id.is_empty() or not _identifier(settler_id) or int(slot) < 0
			or int(shift) < 0 or not reason.is_empty() or not _identifier(source_id)
			or StringName(item_id) not in ItemCatalogScript.ids() or int(count) < 1
			or int(count) > ItemCatalogScript.stack_limit(StringName(item_id))
		):
			return {}
	else:
		if reason.is_empty() or not _identifier(reason) or int(count) != 0:
			return {}
		if not source_id.is_empty() or not item_id.is_empty():
			return {}
		if settler_id.is_empty() != (int(slot) == -1 and int(shift) == -1):
			return {}
		if not settler_id.is_empty() and not _identifier(settler_id):
			return {}
	return {
		&"report_id": str(value[&"report_id"]), &"site_id": str(value[&"site_id"]),
		&"settler_id": settler_id, &"slot": int(slot), &"shift": int(shift),
		&"absolute_day": int(day), &"status": str(value[&"status"]), &"reason": reason,
		&"source_id": source_id, &"item_id": item_id, &"count": int(count),
	}


static func _concern(value: Dictionary) -> Dictionary:
	var keys: Array[StringName] = [&"concern_id", &"settler_id", &"reason_id", &"opened_day"]
	if not _exact_keys(value, keys):
		return {}
	var day: Variant = _integer(value[&"opened_day"], 1, MAX_NUMBER)
	if day == null:
		return {}
	for key: StringName in [&"concern_id", &"settler_id", &"reason_id"]:
		if not _identifier(value[key]):
			return {}
	return {
		&"concern_id": str(value[&"concern_id"]),
		&"settler_id": str(value[&"settler_id"]),
		&"reason_id": str(value[&"reason_id"]),
		&"opened_day": int(day),
	}


static func _applicant_lifecycle(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var lifecycle: Dictionary = value as Dictionary
	var keys: Array[StringName] = [
		&"current_applicant_id", &"offered_day", &"expires_day", &"deferred_until_day",
		&"next_offer_day", &"sequence", &"deferrals",
	]
	if not _exact_keys(lifecycle, keys):
		return {}
	var offered: Variant = _integer(lifecycle[&"offered_day"], 0, MAX_NUMBER)
	var expires: Variant = _integer(lifecycle[&"expires_day"], 0, MAX_NUMBER)
	var deferred: Variant = _integer(lifecycle[&"deferred_until_day"], 0, MAX_NUMBER)
	var next_offer: Variant = _integer(lifecycle[&"next_offer_day"], 1, MAX_NUMBER)
	var sequence: Variant = _integer(lifecycle[&"sequence"], 0, MAX_NUMBER)
	var deferrals: Variant = _integer(lifecycle[&"deferrals"], 0, 2)
	if (
		offered == null or expires == null or deferred == null or next_offer == null
		or sequence == null or deferrals == null
	):
		return {}
	var applicant_id: String = str(lifecycle[&"current_applicant_id"])
	if applicant_id.is_empty():
		if int(offered) != 0 or int(expires) != 0 or int(deferred) != 0 or int(deferrals) != 0:
			return {}
	elif (
		not _identifier(applicant_id) or not applicant_id.begins_with("settler.")
		or int(offered) < 1 or int(expires) <= int(offered)
		or int(deferred) > 0 and (int(deferred) <= int(offered) or int(deferred) >= int(expires))
	):
		return {}
	return {
		&"current_applicant_id": applicant_id,
		&"offered_day": int(offered),
		&"expires_day": int(expires),
		&"deferred_until_day": int(deferred),
		&"next_offer_day": int(next_offer),
		&"sequence": int(sequence),
		&"deferrals": int(deferrals),
	}


static func _job(value: Dictionary) -> Dictionary:
	var keys: Array[StringName] = [
		&"job_id", &"source_id", &"destination_id", &"item_id", &"count", &"priority", &"age"
	]
	if not _exact_keys(value, keys):
		return {}
	for key: StringName in [&"job_id", &"source_id", &"destination_id", &"item_id"]:
		if not _identifier(value[key]):
			return {}
	if (
		str(value[&"source_id"]) == str(value[&"destination_id"])
		or StringName(str(value[&"item_id"])) not in ItemCatalogScript.ids()
	):
		return {}
	var count: Variant = _integer(value[&"count"], 1, MAX_NUMBER)
	var priority: Variant = _integer(value[&"priority"], 0, 9)
	var age: Variant = _integer(value[&"age"], 0, MAX_NUMBER)
	if count == null or priority == null or age == null:
		return {}
	return {
		&"job_id": str(value[&"job_id"]),
		&"source_id": str(value[&"source_id"]),
		&"destination_id": str(value[&"destination_id"]),
		&"item_id": str(value[&"item_id"]),
		&"count": int(count),
		&"priority": int(priority),
		&"age": int(age),
	}


static func _reserve_rule(value: Dictionary) -> Dictionary:
	if not _exact_keys(value, [&"item_id", &"floor"]):
		return {}
	var item_id: StringName = StringName(str(value[&"item_id"]))
	var floor: Variant = _integer(value[&"floor"], 0, MAX_NUMBER)
	if item_id not in ItemCatalogScript.ids() or floor == null:
		return {}
	return {&"item_id": str(item_id), &"floor": int(floor)}


static func _spot(value: Dictionary) -> Dictionary:
	var keys: Array[StringName] = [&"spot_id", &"cast_sequence", &"remaining_catches", &"renewal_day"]
	if not _exact_keys(value, keys) or not _identifier(value[&"spot_id"]):
		return {}
	var spot_id: StringName = StringName(str(value[&"spot_id"]))
	var definition: Dictionary = FishingCatalogScript.spot(spot_id)
	if definition.is_empty():
		return {}
	var sequence: Variant = _integer(value[&"cast_sequence"], 0, MAX_NUMBER)
	var catches: Variant = _integer(
		value[&"remaining_catches"], 0, int(definition[&"capacity"])
	)
	var day: Variant = _integer(value[&"renewal_day"], 1, MAX_NUMBER)
	if sequence == null or catches == null or day == null:
		return {}
	return {
		&"spot_id": str(spot_id),
		&"cast_sequence": int(sequence),
		&"remaining_catches": int(catches),
		&"renewal_day": int(day),
	}


static func _tree(value: Dictionary) -> Dictionary:
	var keys: Array[StringName] = [
		&"tree_id", &"species_id", &"cell", &"planted_day", &"growth_points", &"harvest_sequence"
	]
	if not _exact_keys(value, keys):
		return {}
	var cell: Variant = _cell(value[&"cell"])
	if cell == null or not _identifier(value[&"tree_id"]) or not _identifier(value[&"species_id"]):
		return {}
	if StringName(str(value[&"species_id"])) not in OrchardCatalogScript.SPECIES_IDS:
		return {}
	var planted: Variant = _integer(value[&"planted_day"], 1, MAX_ORCHARD_DAY)
	var species: Dictionary = OrchardCatalogScript.definition(
		StringName(str(value[&"species_id"]))
	)
	var mature_points: int = int((species[&"growth_thresholds"] as Array)[3])
	var growth: Variant = _integer(value[&"growth_points"], 0, mature_points)
	var sequence: Variant = _integer(value[&"harvest_sequence"], 0, MAX_ORCHARD_DAY)
	if planted == null or growth == null or sequence == null:
		return {}
	return {
		&"tree_id": str(value[&"tree_id"]),
		&"species_id": str(value[&"species_id"]),
		&"cell": cell,
		&"planted_day": int(planted),
		&"growth_points": int(growth),
		&"harvest_sequence": int(sequence),
	}


static func _pair_record(value: Dictionary, first: StringName, second: StringName) -> Dictionary:
	if not _exact_keys(value, [first, second]):
		return {}
	if not _identifier(value[first]) or not _identifier(value[second]):
		return {}
	return {first: str(value[first]), second: str(value[second])}


static func _records(
	value: Variant, maximum: int, normalizer: Callable, identity_key: StringName
) -> Variant:
	if not value is Array or (value as Array).size() > maximum:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw: Variant in value as Array:
		var record: Dictionary = raw as Dictionary if raw is Dictionary else {}
		var normalized: Dictionary = normalizer.call(record) as Dictionary
		if normalized.is_empty():
			return null
		var stable: String = str(normalized[identity_key])
		if seen.has(stable):
			return null
		seen[stable] = true
		result.append(normalized)
	result.sort_custom(_record_precedes.bind(identity_key))
	return result


static func _stacks(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_LOCAL_STACKS:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw: Variant in value as Array:
		var stack: Dictionary = raw as Dictionary if raw is Dictionary else {}
		if not _exact_keys(stack, [&"item_id", &"count"]) or not _identifier(stack.get(&"item_id")):
			return null
		var item_name: StringName = StringName(str(stack.get(&"item_id", "")))
		if item_name not in ItemCatalogScript.ids():
			return null
		var count: Variant = _integer(
			stack.get(&"count"), 1, ItemCatalogScript.stack_limit(item_name)
		)
		var item_id: String = str(stack[&"item_id"])
		if count == null or seen.has(item_id):
			return null
		seen[item_id] = true
		result.append({&"item_id": item_id, &"count": int(count)})
	result.sort_custom(_record_precedes.bind(&"item_id"))
	return result


static func _recipes(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_RECIPES_PER_BUILDING:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw: Variant in value as Array:
		var recipe: Dictionary = raw as Dictionary if raw is Dictionary else {}
		if not _exact_keys(recipe, [&"recipe_id", &"enabled", &"priority", &"target_count"]):
			return null
		var recipe_id: String = str(recipe.get(&"recipe_id"))
		var priority: Variant = _integer(recipe.get(&"priority"), 0, 9)
		var target: Variant = _integer(recipe.get(&"target_count"), 0, MAX_NUMBER)
		if (
			not _identifier(recipe_id)
			or StringName(recipe_id) not in RecipeCatalogScript.ids()
			or seen.has(recipe_id)
			or not recipe.get(&"enabled") is bool
			or priority == null
			or target == null
		):
			return null
		seen[recipe_id] = true
		result.append(
			{
				&"recipe_id": recipe_id,
				&"enabled": bool(recipe[&"enabled"]),
				&"priority": int(priority),
				&"target_count": int(target),
			}
		)
	result.sort_custom(_record_precedes.bind(&"recipe_id"))
	return result


static func _production_order(value: Dictionary) -> Dictionary:
	var keys: Array[StringName] = [
		&"order_id", &"recipe_id", &"start_day", &"complete_day", &"operation_token"
	]
	if not _exact_keys(value, keys):
		return {}
	var start_day: Variant = _integer(value[&"start_day"], 1, MAX_NUMBER)
	var complete_day: Variant = _integer(value[&"complete_day"], 1, MAX_NUMBER)
	if (
		start_day == null or complete_day == null or int(complete_day) < int(start_day)
		or not _identifier(value[&"order_id"])
		or StringName(str(value[&"recipe_id"])) not in RecipeCatalogScript.ids()
		or not _identifier(value[&"operation_token"])
	):
		return {}
	return {
		&"order_id": str(value[&"order_id"]),
		&"recipe_id": str(value[&"recipe_id"]),
		&"start_day": int(start_day),
		&"complete_day": int(complete_day),
		&"operation_token": str(value[&"operation_token"]),
	}


static func _building_footprints_are_unique(buildings: Array) -> bool:
	var occupied: Dictionary = {}
	for building: Dictionary in buildings:
		for cell: Array in building[&"footprint"] as Array:
			var key: String = _cell_key(cell)
			if occupied.has(key):
				return false
			occupied[key] = true
	return true


static func _workforce_links_are_valid(
	settlers: Array,
	housing: Array,
	work: Array,
	concerns: Array,
	reports: Array,
	departed: Array,
) -> bool:
	var settler_ids: Dictionary = {}
	for settler: Dictionary in settlers:
		settler_ids[str(settler[&"settler_id"])] = true
	for settler_id: String in departed:
		if settler_ids.has(settler_id):
			return false
	var beds: Dictionary = {}
	for assignment: Dictionary in housing:
		if (
			not settler_ids.has(str(assignment[&"settler_id"]))
			or beds.has(str(assignment[&"bed_id"]))
		):
			return false
		beds[str(assignment[&"bed_id"])] = true
	var slots: Dictionary = {}
	for assignment: Dictionary in work:
		if not settler_ids.has(str(assignment[&"settler_id"])):
			return false
		var slot_key: String = "%s:%d:%d" % [
			assignment[&"site_id"], assignment[&"slot"], assignment[&"shift"]
		]
		if slots.has(slot_key):
			return false
		slots[slot_key] = true
	var concerned_settlers: Dictionary = {}
	for concern: Dictionary in concerns:
		var settler_id: String = str(concern[&"settler_id"])
		if not settler_ids.has(settler_id) or concerned_settlers.has(settler_id):
			return false
		concerned_settlers[settler_id] = true
	for report: Dictionary in reports:
		var report_settler: String = str(report[&"settler_id"])
		var report_site: String = str(report[&"site_id"])
		if report_settler.is_empty():
			for assignment: Dictionary in work:
				if str(assignment[&"site_id"]) == report_site:
					return false
			continue
		if not settler_ids.has(report_settler):
			return false
		var linked: bool = false
		for assignment: Dictionary in work:
			if (
				str(assignment[&"settler_id"]) == report_settler
				and str(assignment[&"site_id"]) == report_site
				and int(assignment[&"slot"]) == int(report[&"slot"])
				and int(assignment[&"shift"]) == int(report[&"shift"])
			):
				linked = true
				break
		if not linked:
			return false
	return true


static func _record_cells_are_unique(records: Array, cell_key: StringName) -> bool:
	var occupied: Dictionary = {}
	for record: Dictionary in records:
		var key: String = _cell_key(record[cell_key] as Array)
		if occupied.has(key):
			return false
		occupied[key] = true
	return true


static func _cell_key(cell: Array) -> String:
	return "%d,%d" % [int(cell[0]), int(cell[1])]


static func _identifier_list(value: Variant, maximum: int, prefix: String) -> Variant:
	if not value is Array or (value as Array).size() > maximum:
		return null
	var result: Array[String] = []
	var seen: Dictionary = {}
	for raw: Variant in value as Array:
		var identifier: String = str(raw)
		if not _identifier(identifier) or not identifier.begins_with(prefix) or seen.has(identifier):
			return null
		seen[identifier] = true
		result.append(identifier)
	result.sort()
	return result


static func _cells(value: Variant, maximum: int) -> Variant:
	if not value is Array or (value as Array).is_empty() or (value as Array).size() > maximum:
		return null
	var result: Array[Array] = []
	var seen: Dictionary = {}
	for raw: Variant in value as Array:
		var normalized: Variant = _cell(raw)
		if normalized == null:
			return null
		var key: String = "%d,%d" % [int(normalized[0]), int(normalized[1])]
		if seen.has(key):
			return null
		seen[key] = true
		result.append(normalized as Array)
	result.sort_custom(_cell_precedes)
	return result


static func _cell(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() != 2:
		return null
	var x: Variant = _integer(value[0], -MAX_COORDINATE, MAX_COORDINATE)
	var y: Variant = _integer(value[1], -MAX_COORDINATE, MAX_COORDINATE)
	return null if x == null or y == null else [int(x), int(y)]


static func _section(value: Variant, keys: Array[StringName]) -> Dictionary:
	if not value is Dictionary:
		return {}
	var section: Dictionary = value as Dictionary
	if not _exact_keys(section, keys):
		return {}
	return section if _integer(section[&"state_version"], STATE_VERSION, STATE_VERSION) != null else {}


static func _identifier(value: Variant) -> bool:
	if not value is String and not value is StringName:
		return false
	var text: String = str(value)
	if text.is_empty() or text.length() > 96 or text.begins_with(".") or text.ends_with("."):
		return false
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		var lower: bool = code >= 97 and code <= 122
		var digit: bool = code >= 48 and code <= 57
		if not lower and not digit and code not in [45, 46, 58, 95]:
			return false
	return true


static func _integer(value: Variant, minimum: int, maximum: int) -> Variant:
	if not value is int and not value is float:
		return null
	var number: float = float(value)
	if not is_finite(number) or floor(number) != number:
		return null
	return int(number) if number >= minimum and number <= maximum else null


static func _record_precedes(
	first: Dictionary, second: Dictionary, identity_key: StringName
) -> bool:
	return str(first[identity_key]) < str(second[identity_key])


static func _cell_precedes(first: Array, second: Array) -> bool:
	return first[1] < second[1] or (first[1] == second[1] and first[0] < second[0])


static func _exact_keys(value: Dictionary, expected: Array[StringName]) -> bool:
	if value.size() != expected.size():
		return false
	for key: StringName in expected:
		if not value.has(key):
			return false
	return true
