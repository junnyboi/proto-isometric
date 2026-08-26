extends RefCounted

const ApplicantScript: GDScript = preload("res://scripts/applicant_lifecycle_service.gd")
const BlueprintScript: GDScript = preload("res://scripts/construction_blueprint_catalog.gd")
const DayAdvanceScript: GDScript = preload("res://scripts/day_advance_service.gd")
const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const InventoryScript: GDScript = preload("res://scripts/inventory_service.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const ReceiptLedgerScript: GDScript = preload("res://scripts/exact_once_receipt_ledger.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")
const SettlerCatalogScript: GDScript = preload("res://scripts/settler_catalog.gd")
const StateHashScript: GDScript = preload("res://scripts/persistence_state_hash.gd")
const WellbeingScript: GDScript = preload("res://scripts/wellbeing_service.gd")
const WorkforceScript: GDScript = preload("res://scripts/workforce_service.gd")

const SEED: int = 902_010
const SITE_ID: StringName = &"building.p9.salvage"


static func evaluate_contracts() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var legacy: Dictionary = SectionsScript.neutral_workforce()
	legacy.erase(&"departed_settler_ids")
	var migrated: Dictionary = SectionsScript.validate_workforce(legacy)
	_add(
		cases,
		"P9 pre-wellbeing workforce migrates neutral departure history canonically",
		not migrated.is_empty()
		and (migrated[&"departed_settler_ids"] as Array).is_empty(),
	)
	var legacy_settler: Dictionary = {
		&"settler_id": str(SettlerCatalogScript.AMARA_VOSS),
		&"status": "active", &"morale": 80, &"injured_until_day": 0,
	}
	var normalized: Dictionary = _normalize_single_settler(legacy_settler)
	var state: Dictionary = (
		(normalized[&"settlers"] as Array)[0] if not normalized.is_empty() else {}
	)
	_add(
		cases,
		"P9 legacy settler records gain neutral notice and reason fields",
		not normalized.is_empty() and int(state[&"notice_day"]) == 0
		and (state[&"last_reason_ids"] as Array).is_empty(),
	)
	var invalid_reasons: Dictionary = legacy_settler.duplicate(true)
	invalid_reasons[&"notice_day"] = 0
	invalid_reasons[&"last_reason_ids"] = ["cruelty.unbounded"]
	var overlap: Dictionary = SectionsScript.neutral_workforce()
	overlap[&"settlers"] = [legacy_settler]
	overlap[&"departed_settler_ids"] = [str(SettlerCatalogScript.AMARA_VOSS)]
	_add(
		cases,
		"P9 schema rejects unknown reasons and active departed identity overlap",
		_normalize_single_settler(invalid_reasons).is_empty()
		and SectionsScript.validate_workforce(overlap).is_empty(),
	)
	var every_reason_valid: bool = true
	for reason_id: StringName in WellbeingScript.REASON_DEFINITIONS:
		every_reason_valid = every_reason_valid and not WellbeingScript.reason_definition(
			reason_id
		).is_empty()
	_add(
		cases,
		"P9 humane reason catalog is finite explainable and deterministic",
		every_reason_valid and WellbeingScript.REASON_DEFINITIONS.size() == 16,
	)
	var source: String = FileAccess.get_file_as_string("res://scripts/wellbeing_service.gd")
	_add(
		cases,
		"P9 wellbeing authority contains no death or instant eviction path",
		not source.contains("death") and not source.contains("killed")
		and not source.contains("evict"),
	)
	_add(
		cases,
		"P9 wellbeing localization has exact en zh-CN parity",
		_locale_keys("res://data/locales/en.json") == _locale_keys(
			"res://data/locales/zh-CN.json"
		),
	)
	return cases


static func evaluate(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = evaluate_contracts()
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var transactions: RefCounted = bridge.call("get_transaction_boundary") as RefCounted
	var settlement: RefCounted = bridge.call("get_settlement_runtime") as RefCounted
	var base: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	_pre_p9_hash_case(cases, transactions)
	var supported: Dictionary = _with_settlers(
		base,
		[SettlerCatalogScript.AMARA_VOSS, SettlerCatalogScript.TOMAS_REED],
		80,
		2,
	)
	var supported_result: Dictionary = WellbeingScript.advance(supported, SEED, 20)
	var supported_state: Dictionary = _settler(
		supported_result[&"candidate"], SettlerCatalogScript.AMARA_VOSS
	)
	_add(
		cases,
		"P9 fair food shelter rest safety and belonging raise bounded morale",
		supported_result[&"ok"] and int(supported_state[&"morale"]) > 80
		and int(supported_state[&"morale"]) <= 100
		and InventoryScript.count_all(
			supported_result[&"candidate"], WellbeingScript.FOOD_ID
		) == 0,
	)
	var replay: Dictionary = WellbeingScript.advance(supported_result[&"candidate"], SEED, 20)
	var conflict_source: Dictionary = supported_result[&"candidate"] as Dictionary
	var conflict: Dictionary = WellbeingScript.advance(conflict_source, SEED + 1, 20)
	_add(
		cases,
		"P9 daily wellbeing receipt replays once and conflicts without mutation",
		replay[&"ok"] and replay[&"replayed"]
		and replay[&"candidate"] == supported_result[&"candidate"]
		and not conflict[&"ok"] and conflict[&"reason"] == &"wellbeing_receipt_conflict"
		and conflict[&"candidate"] == conflict_source,
	)
	var hardship: Dictionary = _with_settlers(
		base, [SettlerCatalogScript.AMARA_VOSS], 30, 0
	)
	var notice: Dictionary = WellbeingScript.advance(hardship, SEED, 100)
	var notice_state: Dictionary = _settler(notice[&"candidate"], SettlerCatalogScript.AMARA_VOSS)
	var day_one: Dictionary = WellbeingScript.advance(notice[&"candidate"], SEED, 101)
	var departed: Dictionary = WellbeingScript.advance(day_one[&"candidate"], SEED, 102)
	var departed_workforce: Dictionary = _workforce(departed[&"candidate"])
	_add(
		cases,
		"P9 low morale opens a concrete two-day remedy window before voluntary departure",
		notice[&"ok"] and str(notice_state[&"status"]) == "notice"
		and int(notice_state[&"notice_day"]) == 100
		and not (day_one[&"summaries"] as Array)[0][&"departed"]
		and (departed_workforce[&"settlers"] as Array).is_empty()
		and str(SettlerCatalogScript.AMARA_VOSS) in (
			departed_workforce[&"departed_settler_ids"] as Array
		)
		and (departed_workforce[&"housing_assignments"] as Array).is_empty(),
	)
	var remedy: Dictionary = _with_settlers(
		base,
		[SettlerCatalogScript.AMARA_VOSS, SettlerCatalogScript.TOMAS_REED],
		35,
		4,
	)
	_set_notice(remedy, SettlerCatalogScript.AMARA_VOSS, 99)
	var remedied: Dictionary = WellbeingScript.advance(remedy, SEED, 100)
	var remedied_state: Dictionary = _settler(
		remedied[&"candidate"], SettlerCatalogScript.AMARA_VOSS
	)
	_add(
		cases,
		"P9 concrete remedy cancels notice without deleting or punishing the settler",
		remedied[&"ok"] and int(remedied_state[&"notice_day"]) == 0
		and str(remedied_state[&"status"]) == "active"
		and int(remedied_state[&"morale"]) >= WellbeingScript.REMEDY_THRESHOLD,
	)
	var injury_day: int = _injury_day(SettlerCatalogScript.TOMAS_REED)
	var work_farm: Dictionary = _with_productive_shift(
		_with_settlers(base, [SettlerCatalogScript.TOMAS_REED], 80, 3),
		SettlerCatalogScript.TOMAS_REED,
		injury_day,
		false,
	)
	var injured: Dictionary = WellbeingScript.advance(work_farm, SEED, injury_day)
	var injured_state: Dictionary = _settler(
		injured[&"candidate"], SettlerCatalogScript.TOMAS_REED
	)
	var recovery_one: Dictionary = WellbeingScript.advance(
		injured[&"candidate"], SEED, injury_day + 1
	)
	var recovery_two: Dictionary = WellbeingScript.advance(
		recovery_one[&"candidate"], SEED, injury_day + 2
	)
	_add(
		cases,
		"P9 deterministic injury is nonfatal suspends work and recovers on the exact day",
		injured[&"ok"] and str(injured_state[&"status"]) == "recovering"
		and int(injured_state[&"injured_until_day"]) == injury_day + 2
		and not WorkforceScript.availability(
			injured[&"candidate"], SettlerCatalogScript.TOMAS_REED
		)[&"available"]
		and str(_settler(
			recovery_one[&"candidate"], SettlerCatalogScript.TOMAS_REED
		)[&"status"]) == "recovering"
		and str(_settler(
			recovery_two[&"candidate"], SettlerCatalogScript.TOMAS_REED
		)[&"status"]) == "active",
	)
	var clinic_farm: Dictionary = _with_productive_shift(
		_with_clinic(_with_settlers(
			base, [SettlerCatalogScript.TOMAS_REED], 80, 2
		)),
		SettlerCatalogScript.TOMAS_REED,
		injury_day,
		false,
	)
	var clinic_injury: Dictionary = WellbeingScript.advance(clinic_farm, SEED, injury_day)
	var clinic_state: Dictionary = _settler(
		clinic_injury[&"candidate"], SettlerCatalogScript.TOMAS_REED
	)
	_add(
		cases,
		"P9 repaired powered clinic shortens deterministic recovery without changing worth",
		clinic_injury[&"ok"]
		and int(clinic_state[&"injured_until_day"]) == injury_day + 1,
	)
	var unsafe_farm: Dictionary = _with_productive_shift(
		_with_settlers(base, [SettlerCatalogScript.TOMAS_REED], 80, 1),
		SettlerCatalogScript.TOMAS_REED,
		1,
		true,
	)
	var safety_stop: Dictionary = DayAdvanceScript.build_candidate(
		unsafe_farm,
		SEED,
		str(unsafe_farm[&"calendar_weather"][&"day_token"]),
		Callable(),
		func(_position: Vector2) -> bool: return false,
	)
	var safety_summary: Dictionary = (safety_stop[&"wellbeing_summary"] as Array)[0]
	var safety_report: Dictionary = _shift_report(
		safety_stop[&"candidate"], SettlerCatalogScript.TOMAS_REED
	)
	_add(
		cases,
		"P9 authoritative safety stop and worker voice create no morale or reward penalty",
		safety_stop[&"ok"] and int(safety_summary[&"morale"]) >= 80
		and str(WellbeingScript.SAFETY_STOP) in (safety_summary[&"reasons"] as Array)
		and str(WellbeingScript.VOICE_HEARD) in (safety_summary[&"reasons"] as Array)
		and str(safety_report[&"reason"]) == "site_unsafe"
		and not bool(safety_summary[&"injured"]),
	)
	var eligible: Dictionary = _with_productive_shift(
		_with_settlers(base, [SettlerCatalogScript.TOMAS_REED], 80, 1),
		SettlerCatalogScript.TOMAS_REED,
		1,
		false,
	)
	_set_recovering(eligible, SettlerCatalogScript.TOMAS_REED, 1)
	var eligible_day: Dictionary = DayAdvanceScript.build_candidate(
		eligible,
		SEED,
		str(eligible[&"calendar_weather"][&"day_token"]),
		func(_cell: Vector2i) -> Dictionary: return {},
		func(_position: Vector2) -> bool: return true,
	)
	var eligible_report: Dictionary = _shift_report(
		eligible_day[&"candidate"], SettlerCatalogScript.TOMAS_REED
	)
	_add(
		cases,
		"P9 completed recovery is eligible on the exact advertised work day",
		eligible_day[&"ok"] and str(eligible_report[&"reason"]) != "worker_recovering"
		and str(_settler(
			eligible_day[&"candidate"], SettlerCatalogScript.TOMAS_REED
		)[&"status"]) == "active",
	)
	var concern: Dictionary = WellbeingScript.concern_for(
		notice[&"candidate"], SettlerCatalogScript.AMARA_VOSS
	)
	_add(
		cases,
		"P9 exposes at most one stable concern with concrete localized remedies",
		not concern.is_empty() and str(concern[&"reason_id"]) == str(
			WellbeingScript.FOOD_SHORTAGE
		)
		and WellbeingScript.remedies_for(WellbeingScript.FOOD_SHORTAGE) == [
			&"stock_field_rations"
		]
		and (_workforce(notice[&"candidate"])[&"concerns"] as Array).size() == 1,
	)
	var all_departed: Dictionary = _all_authored_departed(base)
	var no_reoffer: Dictionary = ApplicantScript.advance_dawn(all_departed, SEED, 7)
	_add(
		cases,
		"P9 departed people are never recycled into later applicant offers",
		no_reoffer[&"ok"] and ApplicantScript.current_offer(
			no_reoffer[&"candidate"]
		).is_empty(),
	)
	var soak: Dictionary = hardship
	var soak_ok: bool = true
	for offset: int in 3_650:
		var advanced: Dictionary = WellbeingScript.advance(soak, SEED, 1_000 + offset)
		if not bool(advanced[&"ok"]):
			soak_ok = false
			break
		soak = advanced[&"candidate"] as Dictionary
	var soak_workforce: Dictionary = _workforce(soak)
	_add(
		cases,
		"P9 ten-year hardship soak stays bounded humane and schema-valid",
		soak_ok and (soak_workforce[&"settlers"] as Array).is_empty()
		and (soak_workforce[&"departed_settler_ids"] as Array).size() == 1
		and _receipt_count(soak, WellbeingScript.RECEIPT_PREFIX) <= 4
		and not FarmSchemaScript.validate(soak).is_empty(),
	)
	var final_candidate: Dictionary = notice[&"candidate"] as Dictionary
	var committed: Dictionary = _commit_farm(transactions, farm_runtime, final_candidate)
	var day_result: Dictionary = farm_runtime.call("transact", &"sleep", {}) as Dictionary
	var final_farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var snapshot: Dictionary = settlement.call("snapshot") as Dictionary
	var roster: Array = snapshot[&"roster"] as Array
	_add(
		cases,
		"P9 atomic sleep publishes wellbeing summaries and truthful roster state",
		committed[&"ok"] and day_result[&"ok"]
		and not (day_result[&"wellbeing_summary"] as Array).is_empty()
		and roster.size() == 1 and not (roster[0][&"concern"] as Dictionary).is_empty()
		and int(roster[0][&"notice_deadline"]) == 102,
	)
	runtime.get_viewport().size = Vector2i(1280, 720)
	_add(
		cases,
		"P9 final wellbeing state remains schema and hash valid",
		not FarmSchemaScript.validate(final_farm).is_empty()
		and StateHashScript.result_hash_matches(transactions.call("get_snapshot")),
	)
	return cases


static func evaluate_responsive(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var settlement: RefCounted = bridge.call("get_settlement_runtime") as RefCounted
	var snapshot: Dictionary = settlement.call("snapshot") as Dictionary
	var modal: Node2D = bridge.call("get_settlement_modal_controller") as Node2D
	var opened: bool = bool(modal.call("open", &"roster"))
	var presenter: CanvasLayer = modal.call("get_presenter") as CanvasLayer
	var list: ItemList = presenter.get("_roster_list") as ItemList
	var detail: Label = presenter.get("_wellbeing_detail") as Label
	var layouts_visible: bool = opened
	for viewport: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
		runtime.get_viewport().size = viewport
		for locale: StringName in [&"en", &"zh-CN"]:
			LocalizationScript.set_locale(locale, false)
			presenter.call("update_snapshot", snapshot)
			presenter.call("_apply_layout")
			for _frame: int in 4:
				await runtime.get_tree().process_frame
			var layout: Dictionary = presenter.call("layout_snapshot") as Dictionary
			var panel: Rect2 = layout[&"panel"] as Rect2
			var detail_bounds: Rect2 = layout[&"wellbeing_detail"] as Rect2
			var row: String = list.get_item_text(0) if list.item_count > 0 else ""
			layouts_visible = layouts_visible and (
				panel.position.x >= 0.0 and panel.position.y >= 0.0
				and panel.end.x <= float(viewport.x) and panel.end.y <= float(viewport.y)
				and detail_bounds.position.x >= panel.position.x
				and detail_bounds.position.y >= panel.position.y
				and detail_bounds.end.x <= panel.end.x and detail_bounds.end.y <= panel.end.y
				and int(layout[&"wellbeing_detail_lines"]) >= 2
				and float(layout[&"minimum_touch_target"]) >= 44.0
				and row.contains(LocalizationScript.t(
					&"settlement.wellbeing.morale", {&"value": 14}
				))
				and detail.text.contains(LocalizationScript.t(
					&"settlement.wellbeing.reason.food.shortage"
				))
				and detail.text.contains(LocalizationScript.t(
					&"settlement.wellbeing.remedy.stock_field_rations"
				))
				and detail.text.contains(LocalizationScript.t(
					&"settlement.wellbeing.notice_deadline", {&"day": 102}
				))
			)
	LocalizationScript.set_locale(&"en", false)
	modal.call("close")
	runtime.get_viewport().size = Vector2i(1280, 720)
	_add(
		cases,
		"P9 roster fully bounds morale concern remedy and notice in mobile locales",
		layouts_visible,
	)
	return cases


static func evaluate_reloaded(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var settlement: RefCounted = bridge.call("get_settlement_runtime") as RefCounted
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var snapshot: Dictionary = settlement.call("snapshot") as Dictionary
	var roster: Array = snapshot[&"roster"] as Array
	_add(
		cases,
		"P9 cold reload preserves morale notice concern reasons receipt and roster truth",
		roster.size() == 1 and int(roster[0][&"state"][&"notice_day"]) == 100
		and not (roster[0][&"concern"] as Dictionary).is_empty()
		and _receipt_count(farm, WellbeingScript.RECEIPT_PREFIX) >= 2
		and not FarmSchemaScript.validate(farm).is_empty(),
	)
	return cases


static func _normalize_single_settler(settler: Dictionary) -> Dictionary:
	var workforce: Dictionary = SectionsScript.neutral_workforce()
	workforce[&"settlers"] = [settler]
	workforce[&"housing_assignments"] = [
		{&"settler_id": str(settler[&"settler_id"]), &"bed_id": "bed.home.0"}
	]
	return SectionsScript.validate_workforce(workforce)


static func _with_settlers(
	farm: Dictionary, ids: Array[StringName], morale: int, rations: int
) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	var workforce: Dictionary = SectionsScript.neutral_workforce()
	for index: int in ids.size():
		workforce[&"settlers"].append(
			{
				&"settler_id": str(ids[index]), &"status": "active", &"morale": morale,
				&"injured_until_day": 0, &"notice_day": 0, &"last_reason_ids": [],
			}
		)
		workforce[&"housing_assignments"].append(
			{&"settler_id": str(ids[index]), &"bed_id": "bed.home.%d" % index}
		)
	homestead[&"workforce"] = SectionsScript.validate_workforce(workforce)
	candidate[&"homestead"] = homestead
	if rations > 0:
		var credited: Dictionary = InventoryScript.credit_with_overflow(
			candidate, WellbeingScript.FOOD_ID, rations
		)
		if not bool(credited[&"ok"]):
			return {}
		candidate = credited[&"candidate"] as Dictionary
	return FarmSchemaScript.validate(candidate)


static func _with_productive_shift(
	farm: Dictionary, settler_id: StringName, absolute_day: int, unsafe: bool
) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	var construction: Dictionary = homestead[&"construction"] as Dictionary
	construction[&"buildings"] = [
		{
			&"instance_id": str(SITE_ID),
			&"blueprint_id": str(BlueprintScript.SALVAGE_CAMP),
			&"anchor": [40, 40], &"orientation": 0, &"level": 1, &"state": "complete",
			&"footprint": [[40, 40]], &"local_stacks": [], &"local_input_stacks": [],
			&"recipe_policies": [], &"production_orders": [],
		}
	]
	homestead[&"construction"] = SectionsScript.validate_construction(construction)
	var workforce: Dictionary = homestead[&"workforce"] as Dictionary
	workforce[&"work_assignments"] = [
		{&"settler_id": str(settler_id), &"site_id": str(SITE_ID), &"slot": 0, &"shift": 0}
	]
	workforce[&"shift_reports"] = [
		{
			&"report_id": "report.p9.%d" % absolute_day,
			&"site_id": str(SITE_ID), &"settler_id": str(settler_id),
			&"slot": 0, &"shift": 0, &"absolute_day": absolute_day,
			&"status": "idle" if unsafe else "productive",
			&"reason": "site_unsafe" if unsafe else "",
			&"source_id": "" if unsafe else "source.p9.salvage",
			&"item_id": "" if unsafe else "item.material.scrap",
			&"count": 0 if unsafe else 1,
		}
	]
	homestead[&"workforce"] = SectionsScript.validate_workforce(workforce)
	candidate[&"homestead"] = homestead
	return FarmSchemaScript.validate(candidate)


static func _with_clinic(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	for facility: Dictionary in homestead[&"facilities"] as Array[Dictionary]:
		if str(facility[&"facility_id"]) == "facility.clinic_kitchen":
			facility[&"repaired"] = true
			facility[&"powered"] = true
			facility[&"repair_token"] = "repair:facility.clinic_kitchen"
			facility[&"power_token"] = "power:facility.clinic_kitchen"
	for ruin: Dictionary in homestead[&"ruins"] as Array[Dictionary]:
		if str(ruin[&"facility_id"]) == "facility.clinic_kitchen":
			ruin[&"repaired"] = true
			ruin[&"powered"] = true
	for resident: Dictionary in homestead[&"residents"] as Array[Dictionary]:
		if str(resident[&"resident_id"]) == "resident.mira":
			resident[&"arrived"] = true
			resident[&"arrival_day"] = 3
	candidate[&"homestead"] = homestead
	return candidate


static func _all_authored_departed(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	var workforce: Dictionary = SectionsScript.neutral_workforce()
	var departed: Array[String] = []
	for settler_id: StringName in SettlerCatalogScript.ids():
		departed.append(str(settler_id))
	workforce[&"departed_settler_ids"] = departed
	homestead[&"workforce"] = SectionsScript.validate_workforce(workforce)
	candidate[&"homestead"] = homestead
	return FarmSchemaScript.validate(candidate)


static func _set_notice(farm: Dictionary, settler_id: StringName, day: int) -> void:
	var workforce: Dictionary = _workforce(farm)
	for settler: Dictionary in workforce[&"settlers"] as Array[Dictionary]:
		if str(settler[&"settler_id"]) == str(settler_id):
			settler[&"notice_day"] = day
			settler[&"status"] = "notice"
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	homestead[&"workforce"] = SectionsScript.validate_workforce(workforce)
	farm[&"homestead"] = homestead


static func _set_recovering(
	farm: Dictionary, settler_id: StringName, injured_until_day: int
) -> void:
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	var workforce: Dictionary = homestead[&"workforce"] as Dictionary
	for settler: Dictionary in workforce[&"settlers"] as Array[Dictionary]:
		if str(settler[&"settler_id"]) == str(settler_id):
			settler[&"status"] = "recovering"
			settler[&"injured_until_day"] = injured_until_day
	homestead[&"workforce"] = SectionsScript.validate_workforce(workforce)
	farm[&"homestead"] = homestead


static func _shift_report(farm: Dictionary, settler_id: StringName) -> Dictionary:
	for report: Dictionary in _workforce(farm)[&"shift_reports"] as Array[Dictionary]:
		if str(report[&"settler_id"]) == str(settler_id):
			return report.duplicate(true)
	return {}


static func _injury_day(settler_id: StringName) -> int:
	for absolute_day: int in range(10, 2_000):
		if WellbeingScript.injury_occurs(SEED, absolute_day, settler_id):
			return absolute_day
	return -1


static func _pre_p9_hash_case(cases: Array[Dictionary], transactions: RefCounted) -> void:
	var legacy: Dictionary = (transactions.call("get_snapshot") as Dictionary).duplicate(true)
	var farm: Dictionary = legacy[&"farm"] as Dictionary
	var workforce: Dictionary = (farm[&"homestead"] as Dictionary)[&"workforce"]
	workforce.erase(&"departed_settler_ids")
	for settler: Dictionary in workforce[&"settlers"] as Array[Dictionary]:
		settler.erase(&"notice_day")
		settler.erase(&"last_reason_ids")
	var revisions: Dictionary = farm[&"revisions"] as Dictionary
	if int(revisions[&"result_revision"]) == 0:
		legacy = StateHashScript.apply_initial(legacy)
	else:
		revisions[&"result_hash"] = StateHashScript.state_hash(legacy)
		farm[&"revisions"] = revisions
		legacy[&"farm"] = farm
	var repository: RefCounted = transactions.get("_repository") as RefCounted
	var migrated: Dictionary = repository.call("validate_envelope", legacy) as Dictionary
	var tampered: Dictionary = legacy.duplicate(true)
	(tampered[&"farm"] as Dictionary)[&"tutorial"][&"suppressed"] = true
	_add(
		cases,
		"P9 genuine pre-P9 hashed save migrates once while tampering still fails",
		not migrated.is_empty() and StateHashScript.result_hash_matches(migrated)
		and (repository.call("validate_envelope", tampered) as Dictionary).is_empty(),
	)


static func _commit_farm(
	transactions: RefCounted, farm_runtime: RefCounted, farm: Dictionary
) -> Dictionary:
	var committed: Dictionary = transactions.call(
		"transact", &"farm_candidate", {&"farm": farm}
	) as Dictionary
	if bool(committed[&"ok"]):
		farm_runtime.call("sync_committed", committed[&"candidate"][&"farm"])
	return committed


static func _settler(farm: Dictionary, settler_id: StringName) -> Dictionary:
	for settler: Dictionary in _workforce(farm).get(&"settlers", []) as Array[Dictionary]:
		if str(settler[&"settler_id"]) == str(settler_id):
			return settler.duplicate(true)
	return {}


static func _workforce(farm: Dictionary) -> Dictionary:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	return (homestead.get(&"workforce", {}) as Dictionary).duplicate(true)


static func _receipt_count(farm: Dictionary, prefix: String) -> int:
	var count: int = 0
	for entry: Dictionary in farm[&"receipts"][&"entries"] as Array[Dictionary]:
		if str(entry[&"token"]).begins_with(prefix):
			count += 1
	return count


static func _locale_keys(path: String) -> Array[String]:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var result: Array[String] = []
	if parsed is Dictionary:
		for key: Variant in (parsed as Dictionary).keys():
			result.append(str(key))
	result.sort()
	return result


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
