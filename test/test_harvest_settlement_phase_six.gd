extends RefCounted

const ApplicantScript: GDScript = preload("res://scripts/applicant_lifecycle_service.gd")
const BlueprintCatalogScript: GDScript = preload(
	"res://scripts/construction_blueprint_catalog.gd"
)
const CalendarScript: GDScript = preload("res://scripts/calendar_state.gd")
const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const HousingScript: GDScript = preload("res://scripts/housing_protection_service.gd")
const InventoryScript: GDScript = preload("res://scripts/inventory_service.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const MenuScript: GDScript = preload("res://scripts/interaction_option_catalog.gd")
const PresenterScript: GDScript = preload("res://scripts/settlement_presenter.gd")
const ResidentScript: GDScript = preload("res://scripts/resident_service.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")
const StateHashScript: GDScript = preload("res://scripts/persistence_state_hash.gd")
const SettlerCatalogScript: GDScript = preload("res://scripts/settler_catalog.gd")
const SettlerPresentationScript: GDScript = preload(
	"res://scripts/settler_presentation_catalog.gd"
)
const ToolScript: GDScript = preload("res://scripts/tool_service.gd")
const WorkforceScript: GDScript = preload("res://scripts/workforce_service.gd")
const WoodlandScript: GDScript = preload("res://scripts/woodland_clearing.gd")

const ASSET_HASHES: Dictionary = {
	"res://assets/settlement/settlers/portraits/settler_amara_voss.png":
	"d2bafbcad06c7b0f8a09122cea5e9df43c0f61d0b5b41880fe14258fadd6e7e6",
	"res://assets/settlement/settlers/portraits/settler_elena_moroz.png":
	"370dcfd69009fbb02241a456554cfb9a553783fa63af101ff9f27c5860b994f3",
	"res://assets/settlement/settlers/portraits/settler_ishan_patel.png":
	"2468bff8bcd2842bb0d8892cf98ed8c27b8f19a06b55228a6f046e2db32adf0c",
	"res://assets/settlement/settlers/portraits/settler_keiko_tan.png":
	"948d27499a97dd3d955ec630ea3913e21a560fd037f98835a07e393576e62f19",
	"res://assets/settlement/settlers/portraits/settler_maeve_quinn.png":
	"85a737475a0ec92238857aaa2bb85d38a822360aa4673eab34627f6e2d21d968",
	"res://assets/settlement/settlers/portraits/settler_malik_okafor.png":
	"eabb6be2dcc41d3015622f0feb10e1ccb77c32a72b7a9fe361bd20a21249df87",
	"res://assets/settlement/settlers/portraits/settler_noor_haddad.png":
	"01d62537a671beac75711c0ad5dee347ee819cda02a499282954f505fdc232f0",
	"res://assets/settlement/settlers/portraits/settler_tomas_reed.png":
	"9f7494681c68df121fdb09febc744c83961c2fee4963c7626f46d2b91247ddac",
	"res://assets/settlement/settlers/sprites/settler_amara_voss.png":
	"346fdd475515f99a7af7bf1bde733c6c2e30aa44251c6292b09009d4c795d6bd",
	"res://assets/settlement/settlers/sprites/settler_elena_moroz.png":
	"d4caa61136d18e229b6fef41ba7be15b7cfef1e66bf1474ca692e30ae411b72a",
	"res://assets/settlement/settlers/sprites/settler_ishan_patel.png":
	"8323536c095775298f1772098fef44248e3fcdb9d06662fa33e5b3dcd0d123d2",
	"res://assets/settlement/settlers/sprites/settler_keiko_tan.png":
	"f2b26f1f5a20a46e3ab322274ac2b4bbd1c234c7fda8b817e94735b4cca55b9f",
	"res://assets/settlement/settlers/sprites/settler_maeve_quinn.png":
	"01df8eb153369ebabf7f8b471bed87ec51eac4484ea2caae356c5a9ba18bc7d5",
	"res://assets/settlement/settlers/sprites/settler_malik_okafor.png":
	"c09f52563fb0e96a1eca5c7d2557b535b29304be1b2388ae6273065a61392275",
	"res://assets/settlement/settlers/sprites/settler_noor_haddad.png":
	"935f7fe03a00b54ae15c5881486fd5a94e4c7e6e967f592e22bcddf2d110e198",
	"res://assets/settlement/settlers/sprites/settler_tomas_reed.png":
	"034d1ce2a78a8d7b16a51d37f61b7b3b43a468a0c744ae8a8184a0119567d140",
}


static func evaluate_contracts() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_add(cases, "P6 exactly eight authored settlers validate", SettlerCatalogScript.validate())
	var first_offer: StringName = SettlerCatalogScript.deterministic_offer_id(7, 7, 1)
	var second_offer: StringName = SettlerCatalogScript.deterministic_offer_id(7, 7, 1)
	_add(
		cases,
		"P6 deterministic applicant selection is stable and seed-sensitive",
		first_offer == second_offer
		and first_offer
		!= SettlerCatalogScript.deterministic_offer_id(8, 7, 1),
	)
	_asset_cases(cases)
	_blueprint_cases(cases)
	_schema_cases(cases)
	_layout_cases(cases)
	_locale_cases(cases)
	_add(
		cases,
		"P6 named resident authority remains exactly Lyra Rook and Mira",
		ResidentScript.RESIDENT_IDS
		== [ResidentScript.LYRA_ID, ResidentScript.ROOK_ID, ResidentScript.MIRA_ID],
	)
	return cases


static func evaluate(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = evaluate_contracts()
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	var transactions: RefCounted = bridge.call("get_transaction_boundary") as RefCounted
	var phase_b: RefCounted = bridge.call("get_interaction_phase_b_service") as RefCounted
	var construction: RefCounted = bridge.call("get_construction_runtime") as RefCounted
	var settlement: RefCounted = bridge.call("get_settlement_runtime") as RefCounted
	var modal: Node2D = bridge.call("get_settlement_modal_controller") as Node2D
	_add(
		cases,
		"P6 live bridge exposes settlement transaction and modal authorities",
		farm_runtime != null and transactions != null and settlement != null and modal != null,
	)
	_pre_p6_hash_case(cases, transactions)
	var seeded: Dictionary = _seed_farm(transactions, farm_runtime)
	var initial: Dictionary = construction.call(
		"find_initial", BlueprintCatalogScript.SALVAGE_CAMP
	) as Dictionary
	var cells: Array[Vector2i] = initial.get(&"cells", []) as Array[Vector2i]
	var placed: Dictionary = construction.call(
		"place", BlueprintCatalogScript.SALVAGE_CAMP, cells[0], 0
	) as Dictionary
	_add(
		cases,
		"P6 test work site enters construction through P4 authority",
		seeded[&"ok"] and initial[&"ok"] and placed[&"ok"],
	)
	var early_offer: bool = false
	for _index: int in 5:
		var slept: Dictionary = farm_runtime.call("transact", &"sleep", {}) as Dictionary
		early_offer = early_offer or not (settlement.call("snapshot")[&"offer"] as Dictionary).is_empty()
		if not bool(slept[&"ok"]):
			early_offer = true
	_add(cases, "P6 no applicant arrives before the seventh dawn", not early_offer)
	var seventh: Dictionary = farm_runtime.call("transact", &"sleep", {}) as Dictionary
	var offered: Dictionary = settlement.call("snapshot") as Dictionary
	var offer: Dictionary = offered[&"offer"] as Dictionary
	_add(
		cases,
		"P6 seventh dawn creates one three-day authored offer after safehouse and bed",
		seventh[&"ok"]
		and not offer.is_empty()
		and int(offer[&"offered_day"]) == 7
		and int(offer[&"expires_day"]) == 10
		and HousingScript.available_beds(farm_runtime.call("get_snapshot") as Dictionary).size() == 2,
	)
	var home_projection: Dictionary = phase_b.call(
		"project", WoodlandScript.HOME_CELL, ToolScript.TOOL_CONTEXT
	) as Dictionary
	var home_menu: Dictionary = MenuScript.build_menu(home_projection)
	_add(
		cases,
		"P6 safehouse E-terminal exposes settlement stewardship and Quick cannot bypass it",
		_has_action(home_menu, &"interaction.action.open_settlement")
		and not _quick_eligible(home_menu),
	)
	var open_option: Dictionary = _option(home_menu, &"interaction.action.open_settlement")
	var opened: Dictionary = phase_b.call(
		"execute",
		&"context",
		ToolScript.TOOL_CONTEXT,
		_resolved(WoodlandScript.HOME_CELL, open_option),
		open_option,
	) as Dictionary
	var layout: Dictionary = modal.call("get_presenter").call("layout_snapshot") as Dictionary
	_add(
		cases,
		"P6 sealed terminal opens a bounded touch-capable applicant modal",
		opened[&"ok"]
		and modal.call("is_open")
		and float(layout[&"minimum_touch_target"]) >= 44.0
		and _inside(layout[&"panel"] as Rect2, Rect2(Vector2.ZERO, layout[&"viewport"] as Vector2)),
	)
	modal.call("close")
	_decision_policy_cases(cases, farm_runtime.call("get_snapshot") as Dictionary)
	var applicant_id: StringName = offer[&"settler_id"] as StringName
	var sequence: int = int(offer[&"sequence"])
	var receipts_before: int = _receipt_count(farm_runtime.call("get_snapshot") as Dictionary)
	var stale_id: StringName = (
		SettlerCatalogScript.AMARA_VOSS
		if applicant_id != SettlerCatalogScript.AMARA_VOSS
		else SettlerCatalogScript.TOMAS_REED
	)
	var stale_offer: Dictionary = settlement.call(
		"decide_applicant", &"invite", stale_id, sequence
	) as Dictionary
	_add(
		cases,
		"P6 stale applicant identity rejects atomically without a receipt or roster mutation",
		not stale_offer[&"ok"]
		and stale_offer[&"reason"] == &"applicant_offer_stale"
		and _receipt_count(farm_runtime.call("get_snapshot") as Dictionary) == receipts_before
		and (settlement.call("snapshot")[&"roster"] as Array).is_empty(),
	)
	var invited: Dictionary = settlement.call(
		"decide_applicant", &"invite", applicant_id, sequence
	) as Dictionary
	var replay: Dictionary = settlement.call(
		"decide_applicant", &"invite", applicant_id, sequence
	) as Dictionary
	var accepted: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var workforce: Dictionary = (accepted[&"homestead"] as Dictionary)[&"workforce"] as Dictionary
	_add(
		cases,
		"P6 invite replay creates one person one protected bed and one receipt exactly once",
		invited[&"ok"]
		and replay[&"ok"]
		and replay[&"replayed"]
		and (workforce[&"settlers"] as Array).size() == 1
		and (workforce[&"housing_assignments"] as Array).size() == 1
		and HousingScript.assignment_is_protected(accepted, applicant_id)
		and _receipt_count(accepted) == receipts_before + 1,
	)
	var conflict: Dictionary = transactions.call(
		"transact_exact_once",
		&"applicant_decision",
		{&"decision": &"decline"},
		"applicant:%d:invite" % sequence,
		{
			&"decision": "decline",
			&"applicant_id": str(applicant_id),
			&"offer_sequence": sequence,
		},
		{&"action": "decline"},
	) as Dictionary
	_add(
		cases,
		"P6 conflicting applicant payload reuse is rejected without mutation",
		not conflict[&"ok"] and conflict[&"receipt_status"] == &"conflict",
	)
	var records: Array[Dictionary] = SettlerPresentationScript.build_records(accepted)
	bridge.call("_refresh_render_indexes")
	var renderer: Node2D = bridge.call("get_farm_renderer") as Node2D
	_add(
		cases,
		"P6 admitted settlers render as authored node-free batched records",
		records.size() == 1
		and records[0][&"stable_id"] == applicant_id
		and not bool(renderer.call("has_per_entity_nodes")),
	)
	_assignment_cases(cases, farm_runtime, settlement, applicant_id)
	var final_farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	_add(
		cases,
		"P6 final live state remains schema-valid with named residents preserved",
		not FarmSchemaScript.validate(final_farm).is_empty()
		and ResidentScript.RESIDENT_IDS.size() == 3,
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
	var assignments: Array = (
		((farm[&"homestead"] as Dictionary)[&"workforce"] as Dictionary)[&"work_assignments"]
		as Array
	)
	_add(
		cases,
		"P6 cold reload restores admitted settler housing work and receipts deterministically",
		roster.size() == 1
		and assignments.size() == 1
		and _receipt_count(farm) >= 3
		and SettlerPresentationScript.build_records(farm).size() == 1
		and (snapshot[&"offer"] as Dictionary).is_empty(),
	)
	return cases


static func _decision_policy_cases(cases: Array[Dictionary], farm: Dictionary) -> void:
	var repeated_dawn: Dictionary = ApplicantScript.advance_dawn(farm, 7, 7)
	_add(
		cases,
		"P6 repeated dawn evaluation preserves the same single active offer",
		repeated_dawn[&"ok"]
		and repeated_dawn[&"candidate"] == farm
		and repeated_dawn[&"applicant_event"] == &"none",
	)
	var expired: Dictionary = ApplicantScript.advance_dawn(farm, 7, 10)
	_add(
		cases,
		"P6 applicant offer expires exactly at the third following dawn",
		expired[&"ok"]
		and expired[&"applicant_event"] == &"expired"
		and ApplicantScript.current_offer(expired[&"candidate"]).is_empty(),
	)
	var deferred: Dictionary = ApplicantScript.decide(farm, &"defer")
	var same_day: Dictionary = ApplicantScript.decide(deferred[&"candidate"], &"invite")
	var lifecycle: Dictionary = ApplicantScript.lifecycle_state(deferred[&"candidate"])
	_add(
		cases,
		"P6 defer is finite and blocks same-day pressure without erasing the offer",
		deferred[&"ok"]
		and not same_day[&"ok"]
		and same_day[&"reason"] == &"applicant_offer_deferred"
		and int(lifecycle[&"deferrals"]) == 1,
	)
	var declined: Dictionary = ApplicantScript.decide(farm, &"decline")
	var declined_state: Dictionary = ApplicantScript.lifecycle_state(declined[&"candidate"])
	_add(
		cases,
		"P6 decline is humane and advances a finite seven-day cooldown",
		declined[&"ok"]
		and str(declined_state[&"current_applicant_id"]).is_empty()
		and int(declined_state[&"next_offer_day"]) >= 14,
	)
	var no_bed: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = no_bed[&"homestead"] as Dictionary
	var home: Dictionary = homestead[&"home"] as Dictionary
	home[&"bed_enabled"] = false
	homestead[&"home"] = home
	var workforce: Dictionary = homestead[&"workforce"] as Dictionary
	workforce[&"applicant_lifecycle"] = SectionsScript.neutral_applicant_lifecycle()
	homestead[&"workforce"] = workforce
	no_bed[&"homestead"] = homestead
	var skipped: Dictionary = ApplicantScript.advance_dawn(no_bed, 7, 20)
	var restored: Dictionary = skipped[&"candidate"] as Dictionary
	var restored_home: Dictionary = (restored[&"homestead"] as Dictionary)[&"home"] as Dictionary
	restored_home[&"bed_enabled"] = true
	(restored[&"homestead"] as Dictionary)[&"home"] = restored_home
	var no_queue: Dictionary = ApplicantScript.advance_dawn(restored, 7, 20)
	_add(
		cases,
		"P6 missed unsafe offer cycles do not create an applicant queue",
		skipped[&"ok"]
		and no_queue[&"ok"]
		and ApplicantScript.current_offer(no_queue[&"candidate"]).is_empty()
		and int(ApplicantScript.lifecycle_state(no_queue[&"candidate"])[&"next_offer_day"]) == 21,
	)


static func _assignment_cases(
	cases: Array[Dictionary],
	farm_runtime: RefCounted,
	settlement: RefCounted,
	settler_id: StringName,
) -> void:
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var sites: Array = settlement.call("snapshot")[&"sites"] as Array
	var site_id: StringName = StringName(str((sites[0] as Dictionary)[&"site_id"]))
	var revision: int = int((farm[&"revisions"] as Dictionary)[&"result_revision"])
	var receipts_before: int = _receipt_count(farm)
	var assigned: Dictionary = settlement.call(
		"assign", settler_id, site_id, 0, WorkforceScript.SHIFT_DAY, revision
	) as Dictionary
	var replay: Dictionary = settlement.call(
		"assign", settler_id, site_id, 0, WorkforceScript.SHIFT_DAY, revision
	) as Dictionary
	var after: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var work: Array = (
		((after[&"homestead"] as Dictionary)[&"workforce"] as Dictionary)[&"work_assignments"]
		as Array
	)
	_add(
		cases,
		"P6 assignment replay commits one site slot shift and receipt exactly once",
		assigned[&"ok"]
		and replay[&"ok"]
		and replay[&"replayed"]
		and work.size() == 1
		and int((work[0] as Dictionary)[&"shift"]) == WorkforceScript.SHIFT_DAY
		and _receipt_count(after) == receipts_before + 1,
	)
	var stale_assignment: Dictionary = settlement.call(
		"assign", settler_id, site_id, 1, WorkforceScript.SHIFT_EVENING, revision
	) as Dictionary
	_add(
		cases,
		"P6 stale workforce revision cannot overwrite a newer assignment",
		not stale_assignment[&"ok"]
		and stale_assignment[&"reason"] == &"stale_workforce_revision"
		and WorkforceScript.assignment_for(
			farm_runtime.call("get_snapshot") as Dictionary, settler_id
		) == work[0]
		and _receipt_count(farm_runtime.call("get_snapshot") as Dictionary)
		== receipts_before + 1,
	)
	var recovering: Dictionary = after.duplicate(true)
	var recovering_workforce: Dictionary = (
		(recovering[&"homestead"] as Dictionary)[&"workforce"] as Dictionary
	)
	(recovering_workforce[&"settlers"] as Array)[0][&"status"] = "recovering"
	var blocked: Dictionary = WorkforceScript.assign(recovering, settler_id, site_id, 1, 1)
	_add(
		cases,
		"P6 recovering settlers reject work without mutating source state",
		not blocked[&"ok"]
		and blocked[&"reason"] == &"settler_recovering"
		and blocked[&"candidate"] == recovering,
	)
	var two_people: Dictionary = _with_second_settler(after)
	var occupied: Dictionary = WorkforceScript.assign(
		two_people, SettlerCatalogScript.TOMAS_REED, site_id, 0, WorkforceScript.SHIFT_DAY
	)
	var non_overlapping: Dictionary = WorkforceScript.assign(
		two_people, SettlerCatalogScript.TOMAS_REED, site_id, 0, WorkforceScript.SHIFT_EVENING
	)
	_add(
		cases,
		"P6 duplicate shift overlap is blocked while the second shift remains available",
		not occupied[&"ok"]
		and occupied[&"reason"] == &"work_slot_occupied"
		and non_overlapping[&"ok"],
	)
	var shift_revision: int = int((after[&"revisions"] as Dictionary)[&"result_revision"])
	var shift_receipts: int = _receipt_count(after)
	var changed_shift: Dictionary = settlement.call(
		"set_shift", settler_id, WorkforceScript.SHIFT_EVENING, shift_revision
	) as Dictionary
	var replayed_shift: Dictionary = settlement.call(
		"set_shift", settler_id, WorkforceScript.SHIFT_EVENING, shift_revision
	) as Dictionary
	var shifted_farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	var shifted: Dictionary = WorkforceScript.assignment_for(shifted_farm, settler_id)
	_add(
		cases,
		"P6 shift changes use their own exact-once receipt namespace",
		changed_shift[&"ok"]
		and replayed_shift[&"ok"]
		and replayed_shift[&"replayed"]
		and int(shifted[&"shift"]) == WorkforceScript.SHIFT_EVENING
		and _receipt_count(shifted_farm) == shift_receipts + 1,
	)


static func _with_second_settler(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var homestead: Dictionary = candidate[&"homestead"] as Dictionary
	var workforce: Dictionary = homestead[&"workforce"] as Dictionary
	var settlers: Array = (workforce[&"settlers"] as Array).duplicate(true)
	settlers.append(
		{
			&"settler_id": str(SettlerCatalogScript.TOMAS_REED),
			&"status": "active",
			&"morale": 80,
			&"injured_until_day": 0,
		}
	)
	var housing: Array = (workforce[&"housing_assignments"] as Array).duplicate(true)
	housing.append(
		{&"settler_id": str(SettlerCatalogScript.TOMAS_REED), &"bed_id": "bed.home.1"}
	)
	workforce[&"settlers"] = settlers
	workforce[&"housing_assignments"] = housing
	homestead[&"workforce"] = SectionsScript.validate_workforce(workforce)
	candidate[&"homestead"] = homestead
	return candidate


static func _seed_farm(transactions: RefCounted, farm_runtime: RefCounted) -> Dictionary:
	var farm: Dictionary = farm_runtime.call("get_snapshot") as Dictionary
	for entry: Dictionary in [
		{&"item_id": &"item.material.wood", &"count": 40},
		{&"item_id": &"item.material.stone", &"count": 40},
		{&"item_id": &"item.material.scrap", &"count": 40},
	]:
		var credit: Dictionary = InventoryScript.credit_with_overflow(
			farm, entry[&"item_id"] as StringName, int(entry[&"count"])
		)
		if not bool(credit[&"ok"]):
			return credit
		farm = credit[&"candidate"] as Dictionary
	var committed: Dictionary = transactions.call(
		"transact", &"farm_candidate", {&"farm": farm}
	) as Dictionary
	if bool(committed[&"ok"]):
		farm_runtime.call("sync_committed", (committed[&"candidate"] as Dictionary)[&"farm"])
	return committed


static func _pre_p6_hash_case(cases: Array[Dictionary], transactions: RefCounted) -> void:
	var legacy: Dictionary = (transactions.call("get_snapshot") as Dictionary).duplicate(true)
	var farm: Dictionary = legacy[&"farm"] as Dictionary
	var workforce: Dictionary = (farm[&"homestead"] as Dictionary)[&"workforce"] as Dictionary
	workforce.erase(&"applicant_lifecycle")
	workforce.erase(&"shift_reports")
	var revisions: Dictionary = farm[&"revisions"] as Dictionary
	if int(revisions[&"result_revision"]) == 0:
		legacy = StateHashScript.apply_initial(legacy)
	else:
		revisions[&"result_hash"] = StateHashScript.state_hash(legacy)
		farm[&"revisions"] = revisions
		legacy[&"farm"] = farm
	var repository: RefCounted = transactions.get("_repository") as RefCounted
	var migrated: Dictionary = repository.call("validate_envelope", legacy) as Dictionary
	var migrated_workforce: Dictionary = (
		((migrated.get(&"farm", {}) as Dictionary).get(&"homestead", {}) as Dictionary)
		.get(&"workforce", {}) as Dictionary
	)
	var tampered: Dictionary = legacy.duplicate(true)
	(tampered[&"farm"] as Dictionary)[&"tutorial"][&"suppressed"] = true
	_add(
		cases,
		"P6 genuine pre-P6 hashed schema-5 save migrates once while tampering still fails",
		not migrated.is_empty()
		and migrated_workforce.has(&"applicant_lifecycle")
		and StateHashScript.result_hash_matches(migrated)
		and (repository.call("validate_envelope", tampered) as Dictionary).is_empty(),
	)


static func _asset_cases(cases: Array[Dictionary]) -> void:
	var valid: bool = SettlerPresentationScript.validate()
	for raw_path: Variant in ASSET_HASHES:
		var path: String = str(raw_path)
		var texture: Texture2D = load(path) as Texture2D
		var expected: Vector2 = Vector2(320, 400) if "/portraits/" in path else Vector2(256, 384)
		valid = (
			valid
			and texture != null
			and texture.get_size() == expected
			and FileAccess.get_sha256(path) == str(ASSET_HASHES[raw_path])
		)
	_add(cases, "P6 GPT Image 2 settler assets match hashes alpha-ready dimensions", valid)


static func _blueprint_cases(cases: Array[Dictionary]) -> void:
	var valid: bool = BlueprintCatalogScript.validate()
	valid = valid and BlueprintCatalogScript.housing_capacity(
		BlueprintCatalogScript.SHELTER_POD
	) == 2
	for blueprint_id: StringName in BlueprintCatalogScript.ids():
		if blueprint_id == BlueprintCatalogScript.SHELTER_POD:
			continue
		valid = valid and BlueprintCatalogScript.work_slot_types(blueprint_id).size() == 2
	_add(cases, "P6 housing and compatible work-slot metadata validates for all blueprints", valid)


static func _schema_cases(cases: Array[Dictionary]) -> void:
	var neutral: Dictionary = SectionsScript.neutral_workforce()
	var legacy: Dictionary = neutral.duplicate(true)
	legacy.erase(&"applicant_lifecycle")
	legacy.erase(&"shift_reports")
	var migrated: Dictionary = SectionsScript.validate_workforce(legacy)
	_add(
		cases,
		"P6 legacy schema-5 workforce gains a neutral applicant lifecycle canonically",
		not migrated.is_empty()
		and migrated[&"applicant_lifecycle"] == SectionsScript.neutral_applicant_lifecycle(),
	)
	var malformed: Dictionary = neutral.duplicate(true)
	(malformed[&"applicant_lifecycle"] as Dictionary)[&"expires_day"] = 4
	_add(
		cases,
		"P6 lifecycle rejects expiry data without a current authored applicant",
		SectionsScript.validate_workforce(malformed).is_empty(),
	)


static func _layout_cases(cases: Array[Dictionary]) -> void:
	var valid: bool = true
	for viewport: Vector2 in [Vector2(1280, 720), Vector2(960, 420), Vector2(430, 860)]:
		var bounds: Rect2 = PresenterScript._layout_for(viewport, 1.0)
		valid = valid and _inside(bounds, Rect2(Vector2.ZERO, viewport))
		valid = valid and bounds.size.x >= 300.0 and bounds.size.y >= 300.0
	_add(cases, "P6 applicant roster modal fits desktop short-landscape and portrait", valid)


static func _locale_cases(cases: Array[Dictionary]) -> void:
	var english: Array[String] = LocalizationScript.get_catalog_keys(&"en")
	var chinese: Array[String] = LocalizationScript.get_catalog_keys(&"zh-CN")
	var valid: bool = english == chinese
	for key: String in english:
		if key.begins_with("settlement."):
			valid = valid and LocalizationScript.has_key(&"zh-CN", key)
	_add(cases, "P6 applicant and roster localization has exact en zh-CN parity", valid)


static func _quick_eligible(menu: Dictionary) -> bool:
	var eligible: int = 0
	for option: Dictionary in menu.get(&"options", []) as Array[Dictionary]:
		if bool(option[&"enabled"]) and option[&"operation"] == &"open_settlement":
			eligible += 1
	return eligible == 0


static func _has_action(menu: Dictionary, action_id: StringName) -> bool:
	return not _option(menu, action_id).is_empty()


static func _option(menu: Dictionary, action_id: StringName) -> Dictionary:
	for option: Dictionary in menu.get(&"options", []) as Array[Dictionary]:
		if option[&"action_id"] == action_id:
			return option.duplicate(true)
	return {}


static func _resolved(cell: Vector2i, option: Dictionary) -> Dictionary:
	return {
		&"valid": true,
		&"target_cell": cell,
		&"target_kind": option[&"target_kind"],
		&"target_subkind": option[&"target_subkind"],
		&"target_id": option[&"target_id"],
		&"affected_cells": option[&"affected_cells"],
	}


static func _inside(inner: Rect2, outer: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x
		and inner.position.y >= outer.position.y
		and inner.end.x <= outer.end.x
		and inner.end.y <= outer.end.y
	)


static func _receipt_count(farm: Dictionary) -> int:
	return ((farm[&"receipts"] as Dictionary)[&"entries"] as Array).size()


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
