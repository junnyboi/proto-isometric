extends RefCounted

const MAX_REVISION: int = 9_007_199_254_740_991
const HASH_LENGTH: int = 64


static func make_neutral_revisions() -> Dictionary:
	return {
		&"state_version": 1,
		&"source_revision": 0,
		&"result_revision": 0,
		&"source_hash": "",
		&"result_hash": "",
	}


static func validate_revisions(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var revisions: Dictionary = value as Dictionary
	if not _exact_keys(
		revisions,
		[&"state_version", &"source_revision", &"result_revision", &"source_hash", &"result_hash"],
	):
		return {}
	var version: Variant = _integer(revisions[&"state_version"], 1, 1)
	var source: Variant = _integer(revisions[&"source_revision"], 0, MAX_REVISION)
	var result: Variant = _integer(revisions[&"result_revision"], 0, MAX_REVISION)
	var source_hash: String = str(revisions[&"source_hash"])
	var result_hash: String = str(revisions[&"result_hash"])
	if version == null or source == null or result == null:
		return {}
	if int(result) == 0:
		if int(source) != 0 or not source_hash.is_empty() or not result_hash.is_empty():
			return {}
	elif (
		int(result) != int(source) + 1
		or not _valid_hash(source_hash)
		or not _valid_hash(result_hash)
	):
		return {}
	return {
		&"state_version": 1,
		&"source_revision": int(source),
		&"result_revision": int(result),
		&"source_hash": source_hash,
		&"result_hash": result_hash,
	}


# Hashes cover stable gameplay state only; envelope metadata is deliberately excluded.
static func state_hash(envelope: Dictionary) -> String:
	for key: StringName in [&"world", &"active_run", &"profile", &"farm"]:
		if not envelope.has(key):
			return ""
	var payload: Dictionary = {
		&"world": envelope[&"world"].duplicate(true),
		&"active_run": (
			envelope[&"active_run"].duplicate(true)
			if envelope[&"active_run"] is Dictionary
			else envelope[&"active_run"]
		),
		&"profile": envelope[&"profile"].duplicate(true),
		&"farm": envelope[&"farm"].duplicate(true),
	}
	var farm: Dictionary = payload[&"farm"] as Dictionary
	if not farm.has(&"revisions") or not farm[&"revisions"] is Dictionary:
		return ""
	var revisions: Dictionary = (farm[&"revisions"] as Dictionary).duplicate(true)
	revisions[&"source_hash"] = ""
	revisions[&"result_hash"] = ""
	farm[&"revisions"] = revisions
	payload[&"farm"] = farm
	return JSON.stringify(_canonical_json_value(payload), "", true, true).sha256_text()


static func apply_initial(candidate: Dictionary) -> Dictionary:
	var farm: Dictionary = candidate.get(&"farm", {}) as Dictionary
	var revisions: Dictionary = validate_revisions(farm.get(&"revisions"))
	if revisions != make_neutral_revisions():
		return {}
	var result: Dictionary = candidate.duplicate(true)
	var next_revisions: Dictionary = make_neutral_revisions()
	next_revisions[&"result_revision"] = 1
	next_revisions[&"source_hash"] = state_hash(candidate)
	(result[&"farm"] as Dictionary)[&"revisions"] = next_revisions
	next_revisions[&"result_hash"] = state_hash(result)
	(result[&"farm"] as Dictionary)[&"revisions"] = next_revisions
	return result


static func apply_next(source: Dictionary, candidate: Dictionary) -> Dictionary:
	var source_farm: Dictionary = source.get(&"farm", {}) as Dictionary
	var candidate_farm: Dictionary = candidate.get(&"farm", {}) as Dictionary
	var source_revisions: Dictionary = validate_revisions(source_farm.get(&"revisions"))
	var candidate_revisions: Dictionary = validate_revisions(candidate_farm.get(&"revisions"))
	if source_revisions.is_empty() or candidate_revisions.is_empty():
		return {}
	if source_revisions != candidate_revisions:
		return {}
	var source_revision: int = int(source_revisions[&"result_revision"])
	if source_revision >= MAX_REVISION:
		return {}
	var result: Dictionary = candidate.duplicate(true)
	var revisions: Dictionary = make_neutral_revisions()
	revisions[&"source_revision"] = source_revision
	revisions[&"result_revision"] = source_revision + 1
	revisions[&"source_hash"] = state_hash(source)
	(result[&"farm"] as Dictionary)[&"revisions"] = revisions
	revisions[&"result_hash"] = state_hash(result)
	(result[&"farm"] as Dictionary)[&"revisions"] = revisions
	return result


static func result_hash_matches(envelope: Dictionary) -> bool:
	var farm: Dictionary = envelope.get(&"farm", {}) as Dictionary
	var revisions: Dictionary = validate_revisions(farm.get(&"revisions"))
	if revisions.is_empty():
		return false
	if int(revisions[&"result_revision"]) == 0:
		return true
	return str(revisions[&"result_hash"]) == state_hash(envelope)


static func _valid_hash(value: String) -> bool:
	if value.length() != HASH_LENGTH:
		return false
	for index: int in value.length():
		var code: int = value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


static func _canonical_json_value(value: Variant) -> Variant:
	if value is float:
		var number: float = float(value)
		return int(number) if is_finite(number) and floor(number) == number else number
	if value is Array:
		var values: Array = []
		for child: Variant in value as Array:
			values.append(_canonical_json_value(child))
		return values
	if value is Dictionary:
		var values: Dictionary = {}
		for key: Variant in value as Dictionary:
			values[str(key)] = _canonical_json_value((value as Dictionary)[key])
		return values
	return str(value) if value is StringName else value


static func _integer(value: Variant, minimum: int, maximum: int) -> Variant:
	if not value is int and not value is float:
		return null
	var number: float = float(value)
	if not is_finite(number) or floor(number) != number:
		return null
	return int(number) if number >= minimum and number <= maximum else null


static func _exact_keys(value: Dictionary, expected: Array[StringName]) -> bool:
	if value.size() != expected.size():
		return false
	for key: StringName in expected:
		if not value.has(key):
			return false
	return true
