extends RefCounted

const MAX_DEPTH: int = 5
const MAX_DICTIONARY_KEYS: int = 24
const MAX_ARRAY_VALUES: int = 32
const MAX_TEXT_LENGTH: int = 256


static func canonical_dictionary(value: Variant, depth: int = 0) -> Dictionary:
	if not value is Dictionary or depth > MAX_DEPTH:
		return {}
	var source: Dictionary = value as Dictionary
	if source.size() > MAX_DICTIONARY_KEYS:
		return {}
	var names: Array[String] = []
	var by_name: Dictionary = {}
	for raw_key: Variant in source:
		if not raw_key is StringName or str(raw_key).is_empty():
			return {}
		var name: String = str(raw_key)
		if name.length() > MAX_TEXT_LENGTH or by_name.has(name):
			return {}
		names.append(name)
		by_name[name] = raw_key
	names.sort()
	var result: Dictionary = {}
	for name: String in names:
		var normalized: Variant = canonical_value(source[by_name[name]], depth + 1)
		if normalized == null and source[by_name[name]] != null:
			return {}
		result[StringName(name)] = normalized
	return result


static func canonical_array(value: Variant, depth: int = 0) -> Array:
	if not value is Array or depth > MAX_DEPTH:
		return []
	var source: Array = value as Array
	if source.size() > MAX_ARRAY_VALUES:
		return []
	var result: Array = []
	for raw_value: Variant in source:
		var normalized: Variant = canonical_value(raw_value, depth + 1)
		if normalized == null and raw_value != null:
			return []
		result.append(normalized)
	return result


static func canonical_value(value: Variant, depth: int = 0) -> Variant:
	if depth > MAX_DEPTH:
		return null
	if value == null or value is bool or value is int or value is float or value is Vector2i:
		return value
	if value is StringName:
		return value if str(value).length() <= MAX_TEXT_LENGTH else null
	if value is String:
		return value if (value as String).length() <= MAX_TEXT_LENGTH else null
	if value is Dictionary:
		var source_dictionary: Dictionary = value as Dictionary
		var dictionary: Dictionary = canonical_dictionary(source_dictionary, depth)
		return dictionary if not dictionary.is_empty() or source_dictionary.is_empty() else null
	if value is Array:
		var source_array: Array = value as Array
		var array: Array = canonical_array(source_array, depth)
		return array if not array.is_empty() or source_array.is_empty() else null
	return null


static func text(value: Variant) -> String:
	if value == null:
		return "n"
	if value is bool:
		return "b:%s" % ["1" if value else "0"]
	if value is int:
		return "i:%d" % int(value)
	if value is float:
		return "f:%s" % String.num(float(value), 12)
	if value is StringName:
		return "sn:%s" % _escape(str(value))
	if value is String:
		return "s:%s" % _escape(value as String)
	if value is Vector2i:
		var cell: Vector2i = value as Vector2i
		return "v:%d,%d" % [cell.x, cell.y]
	if value is Array:
		var values: Array[String] = []
		for entry: Variant in value as Array:
			values.append(text(entry))
		return "a:[%s]" % ",".join(values)
	if value is Dictionary:
		var values: Array[String] = []
		for key: Variant in value as Dictionary:
			values.append("%s=%s" % [text(key), text((value as Dictionary)[key])])
		return "d:{%s}" % ",".join(values)
	return "invalid"


static func digest(value: Variant) -> String:
	return text(value).sha256_text()


static func _escape(value: String) -> String:
	return value.replace("\\", "\\\\").replace(":", "\\:").replace(",", "\\,")
