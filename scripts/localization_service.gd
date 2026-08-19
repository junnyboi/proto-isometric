extends Node

const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")
const DEFAULT_LOCALE: StringName = &"en"
const SUPPORTED_LOCALES: Array[StringName] = [&"en", &"zh-CN"]
const CATALOG_PATHS: Dictionary = {
	&"en": "res://data/locales/en.json",
	&"zh-CN": "res://data/locales/zh-CN.json",
}
const MAX_CATALOG_BYTES: int = 131_072

static var _catalogs: Dictionary = {}
static var _locale: StringName = DEFAULT_LOCALE
static var _missing_keys: Dictionary = {}


func _ready() -> void:
	_load_catalogs()
	var preferences: RefCounted = PlayerPreferencesScript.new() as RefCounted
	var snapshot: Dictionary = preferences.call("load_preferences") as Dictionary
	set_locale(snapshot.get(&"locale", DEFAULT_LOCALE), false)


static func t(key: Variant, placeholders: Dictionary = {}) -> String:
	_ensure_catalogs()
	var text_key: String = str(key)
	var selected: Dictionary = _catalogs.get(_locale, {}) as Dictionary
	var english: Dictionary = _catalogs.get(DEFAULT_LOCALE, {}) as Dictionary
	var value: Variant = selected.get(text_key, english.get(text_key))
	if not value is String:
		if not _missing_keys.has(text_key):
			_missing_keys[text_key] = true
			push_warning("Missing localization key: %s" % text_key)
		return "⟦%s⟧" % text_key
	return (value as String).format(placeholders)


static func set_locale(value: Variant, emit_change: bool = true) -> bool:
	var canonical: StringName = normalize_locale(value)
	if canonical == &"":
		return false
	_ensure_catalogs()
	if canonical == _locale:
		return true
	_locale = canonical
	if emit_change:
		_notify_locale_changed()
	return true


static func get_locale() -> StringName:
	return _locale


static func get_supported_locales() -> Array[StringName]:
	return SUPPORTED_LOCALES.duplicate()


static func has_key(locale: Variant, key: Variant) -> bool:
	_ensure_catalogs()
	var canonical: StringName = normalize_locale(locale)
	if canonical == &"":
		return false
	return (_catalogs.get(canonical, {}) as Dictionary).has(str(key))


static func get_catalog_keys(locale: Variant) -> Array[String]:
	_ensure_catalogs()
	var canonical: StringName = normalize_locale(locale)
	if canonical == &"":
		return []
	var result: Array[String] = []
	for key: Variant in _catalogs.get(canonical, {}) as Dictionary:
		result.append(str(key))
	result.sort()
	return result


static func normalize_locale(value: Variant) -> StringName:
	var normalized: String = str(value).strip_edges().replace("_", "-").to_lower()
	if normalized == "en" or normalized.begins_with("en-"):
		return &"en"
	if normalized in ["zh", "zh-cn", "zh-hans", "zh-hans-cn"]:
		return &"zh-CN"
	return &""


static func _notify_locale_changed() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree != null:
		scene_tree.call_group(&"localization_listeners", &"_on_locale_changed", _locale)


static func _ensure_catalogs() -> void:
	if _catalogs.is_empty():
		_load_catalogs()


static func _load_catalogs() -> void:
	_catalogs.clear()
	for locale: StringName in SUPPORTED_LOCALES:
		var catalog: Dictionary = _load_catalog(str(CATALOG_PATHS[locale]))
		if catalog.is_empty():
			push_error("I18n catalog failed to load: %s" % locale)
		_catalogs[locale] = catalog


static func _load_catalog(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > MAX_CATALOG_BYTES:
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {}
	var source: Dictionary = parser.data as Dictionary
	var catalog: Dictionary = {}
	for raw_key: Variant in source:
		var raw_value: Variant = source[raw_key]
		if not raw_key is String or not raw_value is String:
			return {}
		var key: String = raw_key as String
		if key.is_empty() or (raw_value as String).is_empty():
			return {}
		catalog[key] = raw_value
	return catalog
