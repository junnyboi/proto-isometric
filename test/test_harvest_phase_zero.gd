extends RefCounted

const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const RuntimeOwnershipScript: GDScript = preload("res://scripts/runtime_ownership.gd")

const LEGACY_ID_COUNT: int = 71
const LEGACY_ID_FINGERPRINT: int = 765_856_749


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_legacy_ids(cases)
	_test_ownership(cases)
	_test_neutral_farm(cases)
	_test_dual_modes(cases)
	_test_strict_rejections(cases)
	return cases


static func _test_legacy_ids(cases: Array[Dictionary]) -> void:
	var fingerprint: int = 0
	for identifier: StringName in RuntimeIdsScript.legacy_ids():
		for byte: int in String(identifier).to_utf8_buffer():
			fingerprint = int((fingerprint * 33 + byte) & 0x7FFFFFFF)
	_add_case(
		cases,
		"PH-01 legacy ID catalog is frozen without recycled identifiers",
		(
			RuntimeIdsScript.legacy_ids().size() == LEGACY_ID_COUNT
			and fingerprint == LEGACY_ID_FINGERPRINT
			and RuntimeIdsScript.LEGACY_REGISTRY_VERSION == 6
			and RuntimeIdsScript.REGISTRY_VERSION == 10
		),
	)


static func _test_ownership(cases: Array[Dictionary]) -> void:
	var contracts: Array[Dictionary] = [
		{
			&"domain": RuntimeIdsScript.DOMAIN_FARM,
			&"owner": RuntimeIdsScript.OWNER_FARM_STATE,
			&"scope": RuntimeOwnershipScript.SCOPE_FARM,
		},
		{
			&"domain": RuntimeIdsScript.DOMAIN_CALENDAR_WEATHER,
			&"owner": RuntimeIdsScript.OWNER_CALENDAR_WEATHER,
			&"scope": RuntimeOwnershipScript.SCOPE_CALENDAR_WEATHER,
		},
		{
			&"domain": RuntimeIdsScript.DOMAIN_INVENTORY_ECONOMY,
			&"owner": RuntimeIdsScript.OWNER_INVENTORY_ECONOMY,
			&"scope": RuntimeOwnershipScript.SCOPE_INVENTORY_ECONOMY,
		},
		{
			&"domain": RuntimeIdsScript.DOMAIN_HOMESTEAD_SETTLEMENT,
			&"owner": RuntimeIdsScript.OWNER_HOMESTEAD_SETTLEMENT,
			&"scope": RuntimeOwnershipScript.SCOPE_HOMESTEAD_SETTLEMENT,
			&"authoritative": true,
		},
		{
			&"domain": RuntimeIdsScript.DOMAIN_TOOLS_INTERACTIONS,
			&"owner": RuntimeIdsScript.OWNER_TOOL_INTERACTION,
			&"scope": RuntimeOwnershipScript.SCOPE_TOOLS_INTERACTIONS,
		},
		{
			&"domain": RuntimeIdsScript.DOMAIN_ECOLOGY,
			&"owner": RuntimeIdsScript.OWNER_ECOLOGY,
			&"scope": RuntimeOwnershipScript.SCOPE_ECOLOGY,
			&"authoritative": true,
		},
	]
	for expected: Dictionary in contracts:
		var domain_id: StringName = expected[&"domain"] as StringName
		var owner_id: StringName = expected[&"owner"] as StringName
		var contract: Dictionary = RuntimeOwnershipScript.contract_for(domain_id)
		var authoritative: bool = bool(expected.get(&"authoritative", false))
		_add_case(
			cases,
			"PH-01 owner and scope are explicit for %s" % domain_id,
			(
				RuntimeOwnershipScript.owner_for(domain_id) == owner_id
				and contract[&"state_scope"] == expected[&"scope"]
				and (
					contract[&"migration_state"]
				== (
					RuntimeOwnershipScript.MIGRATION_STABLE
					if authoritative
					else RuntimeOwnershipScript.MIGRATION_PLANNED
				)
				)
			),
		)
		_add_case(
			cases,
			"PH-01 cross-domain mutation is rejected for %s" % domain_id,
			(
				RuntimeOwnershipScript.can_target_mutation(domain_id, owner_id)
				and not RuntimeOwnershipScript.can_target_mutation(
					domain_id, RuntimeIdsScript.OWNER_SAVE_REPOSITORY
				)
				and RuntimeOwnershipScript.can_mutate(domain_id, owner_id) == authoritative
			),
		)


static func _test_neutral_farm(cases: Array[Dictionary]) -> void:
	var neutral: Dictionary = FarmSaveSchemaScript.make_neutral()
	var original: Dictionary = neutral.duplicate(true)
	var validated: Dictionary = FarmSaveSchemaScript.validate(neutral)
	_add_case(
		cases,
		"PH-02 neutral farm validates with stable exact top-level keys",
		(
			validated.keys()
			== [
				&"state_version",
				&"mode",
				&"calendar_weather",
				&"plots",
				&"inventories",
				&"economy",
				&"placed_entities",
				&"machines",
				&"homestead",
				&"tools",
					&"ecology",
					&"migration_tokens",
					&"day_tokens",
					&"gathering",
					&"logistics",
					&"fishing",
					&"orchard",
					&"tutorial",
					&"receipts",
					&"revisions",
				]
			),
	)
	_add_case(cases, "PH-02 farm validation is detached", neutral == original)
	(validated[&"calendar_weather"] as Dictionary)[&"year"] = 2
	_add_case(
		cases,
		"PH-02 validated farm cannot mutate its source",
		int((neutral[&"calendar_weather"] as Dictionary)[&"year"]) == 1,
	)
	var first: String = FarmSaveSchemaScript.canonical_json(neutral)
	var reordered: Dictionary = {}
	var keys: Array = neutral.keys()
	keys.reverse()
	for key: Variant in keys:
		reordered[key] = neutral[key]
	_add_case(
		cases,
		"PH-02 farm canonical serialization is deterministic",
		not first.is_empty() and first == FarmSaveSchemaScript.canonical_json(reordered),
	)


static func _test_dual_modes(cases: Array[Dictionary]) -> void:
	var fresh: Dictionary = FarmSaveSchemaScript.make_neutral(RuntimeIdsScript.MODE_FRESH_FARM)
	var legacy: Dictionary = FarmSaveSchemaScript.make_neutral(
		RuntimeIdsScript.MODE_LEGACY_EXPEDITION, true
	)
	_add_case(
		cases,
		"PH-03 fresh-farm mode has a neutral clearing boot seam",
		(
			FarmSaveSchemaScript.mode_of(fresh) == RuntimeIdsScript.MODE_FRESH_FARM
			and (fresh[&"migration_tokens"] as Array).is_empty()
		),
	)
	_add_case(
		cases,
		"PH-03 legacy-expedition mode retains its compatibility token",
		(
			FarmSaveSchemaScript.mode_of(legacy) == RuntimeIdsScript.MODE_LEGACY_EXPEDITION
			and legacy[&"migration_tokens"] == [String(RuntimeIdsScript.MIGRATION_FARM_V3_TO_V4)]
		),
	)


static func _test_strict_rejections(cases: Array[Dictionary]) -> void:
	var neutral: Dictionary = FarmSaveSchemaScript.make_neutral()
	var unknown: Dictionary = neutral.duplicate(true)
	unknown[&"future_field"] = true
	_add_case(
		cases,
		"PH-02 farm rejects unknown fields",
		FarmSaveSchemaScript.validate(unknown).is_empty(),
	)
	var malformed: Dictionary = neutral.duplicate(true)
	malformed[&"mode"] = "gameplay_mode.unknown"
	_add_case(
		cases,
		"PH-02 farm rejects unknown gameplay modes",
		FarmSaveSchemaScript.validate(malformed).is_empty(),
	)
	var oversized: Dictionary = neutral.duplicate(true)
	var plots: Array = []
	plots.resize(FarmSaveSchemaScript.MAX_PLOTS + 1)
	oversized[&"plots"] = plots
	_add_case(
		cases,
		"PH-02 farm enforces hard collection bounds before records exist",
		FarmSaveSchemaScript.validate(oversized).is_empty(),
	)
	var non_neutral: Dictionary = neutral.duplicate(true)
	non_neutral[&"plots"] = [{&"cell": [8, 10]}]
	_add_case(
		cases,
		"PH-02 skeleton rejects future farm records until their schema is approved",
		FarmSaveSchemaScript.validate(non_neutral).is_empty(),
	)
	var out_of_range: Dictionary = neutral.duplicate(true)
	(out_of_range[&"calendar_weather"] as Dictionary)[&"year"] = 10_000
	_add_case(
		cases,
		"PH-02 farm enforces hard scalar bounds",
		FarmSaveSchemaScript.validate(out_of_range).is_empty(),
	)


static func _add_case(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
