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


static func raw_hash_is_valid(envelope: Dictionary, verify_result_hash: bool) -> bool:
	if not verify_result_hash:
		return false
	var farm: Dictionary = envelope.get(&"farm", {}) as Dictionary
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var workforce: Dictionary = homestead.get(&"workforce", {}) as Dictionary
	if (
		not _exact_keys(workforce, LEGACY_WORKFORCE_KEYS)
		and not _exact_keys(workforce, PRE_P7_WORKFORCE_KEYS)
	):
		return false
	return StateHashScript.result_hash_matches(envelope)


static func _exact_keys(value: Dictionary, expected: Array[StringName]) -> bool:
	if value.size() != expected.size():
		return false
	for key: StringName in expected:
		if not value.has(key):
			return false
	return true
