extends RefCounted

const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const SCHEMA_THREE: int = 3
const SCHEMA_FOUR: int = 4
const TARGET_SCHEMA: int = 5
const MAX_SEQUENCE: int = 9_007_199_254_740_991


static func migrate_schema_three(
	raw: Dictionary,
	normalize_metadata: Callable,
	normalize_world: Callable,
	normalize_run: Callable,
	normalize_profile: Callable,
) -> Dictionary:
	var keys: Array[StringName] = [
		&"save_format_version", &"metadata", &"world", &"active_run", &"profile"
	]
	if not _exact_keys(raw, keys) or _version(raw) != SCHEMA_THREE:
		return {}
	var parts: Dictionary = _normalize_legacy(
		raw, normalize_metadata, normalize_world, normalize_run, normalize_profile
	)
	if parts.is_empty():
		return {}
	parts[&"save_format_version"] = TARGET_SCHEMA
	parts[&"farm"] = FarmSaveSchemaScript.make_neutral(
		RuntimeIdsScript.MODE_LEGACY_EXPEDITION, true
	)
	return parts


static func migrate_schema_four(
	raw: Dictionary,
	normalize_metadata: Callable,
	normalize_world: Callable,
	normalize_run: Callable,
	normalize_profile: Callable,
) -> Dictionary:
	var keys: Array[StringName] = [
		&"save_format_version", &"metadata", &"world", &"active_run", &"profile", &"farm"
	]
	if not _exact_keys(raw, keys) or _version(raw) != SCHEMA_FOUR:
		return {}
	var parts: Dictionary = _normalize_legacy(
		raw, normalize_metadata, normalize_world, normalize_run, normalize_profile
	)
	if parts.is_empty():
		return {}
	var farm: Dictionary = FarmSaveSchemaScript.migrate_v1(raw[&"farm"])
	if farm.is_empty():
		return {}
	parts[&"save_format_version"] = TARGET_SCHEMA
	parts[&"farm"] = farm
	return parts


static func _normalize_legacy(
	raw: Dictionary,
	normalize_metadata: Callable,
	normalize_world: Callable,
	normalize_run: Callable,
	normalize_profile: Callable,
) -> Dictionary:
	var metadata: Dictionary = normalize_metadata.call(raw.get(&"metadata")) as Dictionary
	var active_run: Variant = normalize_run.call(raw.get(&"active_run"))
	var profile: Dictionary = normalize_profile.call(raw.get(&"profile")) as Dictionary
	if metadata.is_empty() or (active_run is bool and not bool(active_run)) or profile.is_empty():
		return {}
	var robot_cell: Vector2i = Vector2i(1_000_001, 1_000_001)
	if active_run is Dictionary:
		var cell: Array = (active_run as Dictionary)[&"player_cell"] as Array
		robot_cell = Vector2i(int(cell[0]), int(cell[1]))
	var world: Dictionary = normalize_world.call(raw.get(&"world"), robot_cell) as Dictionary
	if world.is_empty():
		return {}
	return {
		&"metadata": metadata,
		&"world": world,
		&"active_run": active_run,
		&"profile": profile,
	}


static func _version(raw: Dictionary) -> int:
	var value: Variant = raw.get(&"save_format_version")
	if not value is int and not value is float:
		return -1
	var number: float = float(value)
	if not is_finite(number) or floor(number) != number or number > MAX_SEQUENCE:
		return -1
	return int(number)


static func _exact_keys(value: Dictionary, expected: Array[StringName]) -> bool:
	if value.size() != expected.size():
		return false
	for key: StringName in expected:
		if not value.has(key):
			return false
	return true
