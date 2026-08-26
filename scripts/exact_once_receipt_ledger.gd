extends RefCounted

const STATE_VERSION: int = 1
const MAX_RECEIPTS: int = 128
const MAX_TOKEN_LENGTH: int = 128
const MAX_PAYLOAD_BYTES: int = 4_096
const MAX_RESULT_BYTES: int = 1_024
const TOKEN_NAMESPACES: Array[String] = [
	"quick",
	"construction",
	"deposit",
	"applicant",
	"assignment",
	"shift",
	"transfer",
	"production",
	"wellbeing",
	"tree",
	"fish",
	"day",
	"machine",
	"ecology",
]
const NAMESPACE_LIMITS: Dictionary = {
	"quick": 4,
	"construction": 6,
	"deposit": 6,
	"applicant": 4,
	"assignment": 6,
	"shift": 40,
	"transfer": 16,
	"production": 16,
	"wellbeing": 4,
	"tree": 4,
	"fish": 4,
	"day": 4,
	"machine": 6,
	"ecology": 4,
}


static func make_neutral() -> Dictionary:
	return {&"state_version": STATE_VERSION, &"entries": []}


static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var ledger: Dictionary = value as Dictionary
	if not _exact_keys(ledger, [&"state_version", &"entries"]):
		return {}
	if _integer(ledger[&"state_version"], STATE_VERSION, STATE_VERSION) == null:
		return {}
	var raw_entries: Variant = ledger[&"entries"]
	if not raw_entries is Array or (raw_entries as Array).size() > MAX_RECEIPTS:
		return {}
	var entries: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_entry: Variant in raw_entries as Array:
		var entry: Dictionary = raw_entry as Dictionary if raw_entry is Dictionary else {}
		if not _exact_keys(entry, [&"token", &"payload_fingerprint", &"result"]):
			return {}
		var token: String = str(entry[&"token"])
		var fingerprint_value: String = str(entry[&"payload_fingerprint"])
		var result: Variant = entry[&"result"]
		if (
			not _valid_token(token)
			or seen.has(token)
			or not _valid_fingerprint(fingerprint_value)
			or not _bounded_json(result)
			or _canonical_bytes(result) > MAX_RESULT_BYTES
		):
			return {}
		seen[token] = true
		entries.append(
			{
				&"token": token,
				&"payload_fingerprint": fingerprint_value,
				&"result": result.duplicate(true) if result is Array or result is Dictionary else result,
			}
		)
	entries.sort_custom(_entry_precedes)
	return {&"state_version": STATE_VERSION, &"entries": entries}


static func fingerprint(payload: Variant) -> String:
	if not _bounded_json(payload) or _canonical_bytes(payload) > MAX_PAYLOAD_BYTES:
		return ""
	var encoded: String = JSON.stringify(payload, "", true, true)
	return encoded.sha256_text()


static func lookup(ledger: Variant, token: String, payload: Variant) -> Dictionary:
	var normalized: Dictionary = validate(ledger)
	var payload_hash: String = fingerprint(payload)
	if normalized.is_empty() or not _valid_token(token) or payload_hash.is_empty():
		return {&"status": &"invalid", &"result": null}
	for entry: Dictionary in normalized[&"entries"] as Array[Dictionary]:
		if entry[&"token"] != token:
			continue
		if entry[&"payload_fingerprint"] != payload_hash:
			return {&"status": &"conflict", &"result": null}
		var result: Variant = entry[&"result"]
		return {
			&"status": &"duplicate",
			&"result": result.duplicate(true) if result is Array or result is Dictionary else result,
		}
	return {&"status": &"missing", &"result": null}


static func record(
	ledger: Variant, token: String, payload: Variant, deterministic_result: Variant
) -> Dictionary:
	var checked: Dictionary = lookup(ledger, token, payload)
	var status: StringName = checked[&"status"] as StringName
	if status == &"duplicate":
		return {
			&"ok": true,
			&"status": status,
			&"candidate": validate(ledger),
			&"result": checked[&"result"],
		}
	if status != &"missing":
		return _record_failure(validate(ledger), status)
	var normalized: Dictionary = validate(ledger)
	if (normalized[&"entries"] as Array).size() >= MAX_RECEIPTS:
		normalized = prepare_for_record(normalized, token)
		if normalized.is_empty():
			return _record_failure(validate(ledger), &"invalid")
	if (normalized[&"entries"] as Array).size() >= MAX_RECEIPTS:
		return _record_failure(normalized, &"ledger_full")
	if not _bounded_json(deterministic_result):
		return _record_failure(normalized, &"invalid_result")
	if _canonical_bytes(deterministic_result) > MAX_RESULT_BYTES:
		return _record_failure(normalized, &"invalid_result")
	var entries: Array = (normalized[&"entries"] as Array).duplicate(true)
	entries.append(
		{
			&"token": token,
			&"payload_fingerprint": fingerprint(payload),
			&"result": (
				deterministic_result.duplicate(true)
				if deterministic_result is Array or deterministic_result is Dictionary
				else deterministic_result
			),
		}
	)
	var candidate: Dictionary = validate(
		{&"state_version": STATE_VERSION, &"entries": entries}
	)
	candidate = _compact_namespaces(candidate, "", false, token)
	return {
		&"ok": not candidate.is_empty(),
		&"status": &"recorded",
		&"candidate": candidate,
		&"result": deterministic_result,
	}


static func namespace_of(token: String) -> StringName:
	var separator: int = token.find(":")
	return &"" if separator <= 0 else StringName(token.left(separator))


static func retain_prefix(ledger: Variant, prefix: String, limit: int) -> Dictionary:
	var normalized: Dictionary = validate(ledger)
	if normalized.is_empty() or prefix.is_empty() or limit < 0 or limit > MAX_RECEIPTS:
		return {}
	var matching: Array[Dictionary] = []
	var retained: Array[Dictionary] = []
	for entry: Dictionary in normalized[&"entries"] as Array[Dictionary]:
		if str(entry[&"token"]).begins_with(prefix):
			matching.append(entry.duplicate(true))
		else:
			retained.append(entry.duplicate(true))
	matching.sort_custom(_natural_entry_precedes)
	var start: int = maxi(matching.size() - limit, 0)
	for index: int in range(start, matching.size()):
		retained.append(matching[index])
	return validate({&"state_version": STATE_VERSION, &"entries": retained})


static func prepare_for_record(ledger: Variant, incoming_token: String) -> Dictionary:
	var normalized: Dictionary = validate(ledger)
	var incoming_namespace: String = str(namespace_of(incoming_token))
	if normalized.is_empty() or incoming_namespace not in NAMESPACE_LIMITS:
		return {}
	return _compact_namespaces(normalized, incoming_namespace, true)


static func _compact_namespaces(
	ledger: Dictionary,
	incoming_namespace: String,
	reserve_slot: bool,
	protected_token: String = "",
) -> Dictionary:
	var grouped: Dictionary = {}
	for category: String in TOKEN_NAMESPACES:
		grouped[category] = []
	for entry: Dictionary in ledger[&"entries"] as Array[Dictionary]:
		(grouped[str(namespace_of(str(entry[&"token"]))) ] as Array).append(
			entry.duplicate(true)
		)
	var retained: Array[Dictionary] = []
	for category: String in TOKEN_NAMESPACES:
		var entries: Array = grouped[category] as Array
		entries.sort_custom(_natural_entry_precedes)
		var limit: int = int(NAMESPACE_LIMITS[category])
		if reserve_slot and category == incoming_namespace:
			limit -= 1
		limit = maxi(limit, 0)
		var protected: Dictionary = {}
		for entry: Dictionary in entries as Array[Dictionary]:
			if str(entry[&"token"]) == protected_token:
				protected = entry.duplicate(true)
				break
		var unprotected_limit: int = limit - (0 if protected.is_empty() else 1)
		var kept: int = 0
		for index: int in range(entries.size() - 1, -1, -1):
			var entry: Dictionary = entries[index] as Dictionary
			if str(entry[&"token"]) == protected_token or kept >= unprotected_limit:
				continue
			retained.append(entry.duplicate(true))
			kept += 1
		if not protected.is_empty() and limit > 0:
			retained.append(protected)
	return validate({&"state_version": STATE_VERSION, &"entries": retained})


static func _record_failure(ledger: Dictionary, status: StringName) -> Dictionary:
	return {&"ok": false, &"status": status, &"candidate": ledger, &"result": null}


static func _valid_token(token: String) -> bool:
	if token.is_empty() or token.length() > MAX_TOKEN_LENGTH:
		return false
	var token_namespace: StringName = namespace_of(token)
	var parts: PackedStringArray = token.split(":")
	if (
		String(token_namespace) not in TOKEN_NAMESPACES
		or parts.size() < 2
		or token.ends_with(":")
		or "::" in token
	):
		return false
	for index: int in token.length():
		var code: int = token.unicode_at(index)
		var lower: bool = code >= 97 and code <= 122
		var digit: bool = code >= 48 and code <= 57
		if not lower and not digit and code not in [45, 46, 58, 95]:
			return false
	return true


static func _valid_fingerprint(value: String) -> bool:
	if value.length() != 64:
		return false
	for index: int in value.length():
		var code: int = value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


static func _bounded_json(value: Variant, depth: int = 0) -> bool:
	if depth > 5:
		return false
	if value == null or value is bool or value is int:
		return true
	if value is float:
		return is_finite(float(value))
	if value is String or value is StringName:
		return str(value).length() <= 256
	if value is Array:
		if (value as Array).size() > 32:
			return false
		for child: Variant in value as Array:
			if not _bounded_json(child, depth + 1):
				return false
		return true
	if value is Dictionary:
		if (value as Dictionary).size() > 16:
			return false
		var normalized_keys: Dictionary = {}
		for key: Variant in value:
			if (
				(not key is String and not key is StringName)
				or str(key).is_empty()
				or str(key).length() > 64
				or normalized_keys.has(str(key))
				or not _bounded_json((value as Dictionary)[key], depth + 1)
			):
				return false
			normalized_keys[str(key)] = true
		return true
	return false


static func _canonical_bytes(value: Variant) -> int:
	return JSON.stringify(value, "", true, true).to_utf8_buffer().size()


static func _integer(value: Variant, minimum: int, maximum: int) -> Variant:
	if not value is int and not value is float:
		return null
	var number: float = float(value)
	if not is_finite(number) or floor(number) != number:
		return null
	return int(number) if number >= minimum and number <= maximum else null


static func _entry_precedes(first: Dictionary, second: Dictionary) -> bool:
	return str(first[&"token"]) < str(second[&"token"])


static func _natural_entry_precedes(first: Dictionary, second: Dictionary) -> bool:
	var first_token: String = str(first[&"token"])
	var second_token: String = str(second[&"token"])
	var first_numbers: Array[int] = _token_numbers(first_token)
	var second_numbers: Array[int] = _token_numbers(second_token)
	for index: int in mini(first_numbers.size(), second_numbers.size()):
		if first_numbers[index] != second_numbers[index]:
			return first_numbers[index] < second_numbers[index]
	if first_numbers.size() != second_numbers.size():
		return first_numbers.size() < second_numbers.size()
	return first_token < second_token


static func _token_numbers(token: String) -> Array[int]:
	var result: Array[int] = []
	var digits: String = ""
	for index: int in token.length():
		var code: int = token.unicode_at(index)
		if code >= 48 and code <= 57:
			digits += char(code)
		elif not digits.is_empty():
			result.append(int(digits))
			digits = ""
	if not digits.is_empty():
		result.append(int(digits))
	return result


static func _exact_keys(value: Dictionary, expected: Array[StringName]) -> bool:
	if value.size() != expected.size():
		return false
	for key: StringName in expected:
		if not value.has(key):
			return false
	return true
