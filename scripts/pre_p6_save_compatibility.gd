extends RefCounted

const StateHashScript: GDScript = preload("res://scripts/persistence_state_hash.gd")

const LEGACY_WORKFORCE_KEYS: Array[StringName] = [
	&"state_version",
	&"settlers",
	&"housing_assignments",
	&"work_assignments",
	&"concerns",
]
const PRE_P7_WORKFORCE_KEYS: Array[StringName] = [
	&"state_version",
	&"settlers",
	&"housing_assignments",
	&"work_assignments",
	&"concerns",
	&"applicant_lifecycle",
]
const CURRENT_WORKFORCE_KEYS: Array[StringName] = [
	&"state_version",
	&"settlers",
	&"housing_assignments",
	&"work_assignments",
	&"concerns",
	&"applicant_lifecycle",
	&"shift_reports",
]
const PRE_P8_BUILDING_KEYS: Array[StringName] = [
	&"instance_id", &"blueprint_id", &"anchor", &"orientation", &"level", &"state",
	&"footprint", &"local_stacks", &"recipe_policies",
]
const PRE_P8_LOGISTICS_KEYS: Array[StringName] = [&"state_version", &"jobs"]


static func raw_hash_is_valid(envelope: Dictionary, verify_result_hash: bool) -> bool:
	if not verify_result_hash:
		return false
	var farm: Dictionary = envelope.get(&"farm", {}) as Dictionary
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var workforce: Dictionary = homestead.get(&"workforce", {}) as Dictionary
	var legacy_workforce: bool = (
		not _exact_keys(workforce, LEGACY_WORKFORCE_KEYS)
		and not _exact_keys(workforce, PRE_P7_WORKFORCE_KEYS)
	)
	if not legacy_workforce:
		return StateHashScript.result_hash_matches(envelope)
	var logistics: Dictionary = farm.get(&"logistics", {}) as Dictionary
	if (
		not _exact_keys(workforce, CURRENT_WORKFORCE_KEYS)
		or not _exact_keys(logistics, PRE_P8_LOGISTICS_KEYS)
		or not _pre_p8_buildings(homestead)
	):
		return false
	return StateHashScript.result_hash_matches(envelope)


static func _pre_p8_buildings(homestead: Dictionary) -> bool:
	var construction: Dictionary = homestead.get(&"construction", {}) as Dictionary
	var buildings: Variant = construction.get(&"buildings")
	if not buildings is Array:
		return false
	for building: Variant in buildings as Array:
		if not building is Dictionary or not _exact_keys(building, PRE_P8_BUILDING_KEYS):
			return false
	return true


static func _exact_keys(value: Dictionary, expected: Array[StringName]) -> bool:
	if value.size() != expected.size():
		return false
	for key: StringName in expected:
		if not value.has(key):
			return false
	return true
