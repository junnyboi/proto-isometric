extends RefCounted

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const EN_PATH: String = "res://data/locales/en.json"
const ZH_PATH: String = "res://data/locales/zh-CN.json"
const FONT_PATH: String = "res://assets/fonts/NotoSansCJKsc-ProtoIsometric.otf"


class LocaleObserver:
	extends Node
	var notifications: Array[StringName] = []

	func _on_locale_changed(locale: StringName) -> void:
		notifications.append(locale)


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var english: Dictionary = _catalog(EN_PATH)
	var chinese: Dictionary = _catalog(ZH_PATH)
	_add(cases, "English localization catalog parses", not english.is_empty())
	_add(cases, "Simplified Chinese localization catalog parses", not chinese.is_empty())
	_add(cases, "localization catalogs have exact key parity", _keys(english) == _keys(chinese))
	_add(
		cases,
		"localization catalogs preserve named placeholder parity",
		_placeholders_match(english, chinese),
	)
	_add(
		cases,
		"locale aliases normalize to supported identifiers",
		(
			LocalizationScript.normalize_locale("en-US") == &"en"
			and LocalizationScript.normalize_locale("zh_CN") == &"zh-CN"
			and LocalizationScript.normalize_locale("zh-Hans") == &"zh-CN"
			and LocalizationScript.normalize_locale("fr") == &""
		),
	)
	LocalizationScript.set_locale(&"zh-CN", false)
	_add(
		cases,
		"named placeholders render translated Simplified Chinese text",
		(
			LocalizationScript.t(&"status.scrap_collected", {"amount": 2, "total": "007"})
			== "拾取废料 +2 // 总计 007"
		),
	)
	_add(
		cases,
		"Lava enemy and hazard source have Simplified Chinese translations",
		LocalizationScript.t(&"enemy.cinder_crawler.name") == "烬火爬行兽"
		and LocalizationScript.t(&"source.lava") == "熔岩",
	)
	var missing_marker: String = LocalizationScript.t(&"missing.test.key")
	_add(cases, "unknown localization keys fail visibly", missing_marker == "⟦missing.test.key⟧")
	var observer: LocaleObserver = LocaleObserver.new()
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(observer)
	observer.add_to_group("localization_listeners")
	LocalizationScript.set_locale(&"en")
	LocalizationScript.set_locale(&"zh-CN")
	_add(
		cases,
		"locale changes notify reactive UI owners",
		observer.notifications == [&"en", &"zh-CN"],
	)
	observer.free()
	LocalizationScript.set_locale(&"en", false)
	_add(cases, "localized CJK runtime font loads", load(FONT_PATH) is FontFile)
	return cases


static func _catalog(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


static func _keys(catalog: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: Variant in catalog:
		result.append(str(key))
	result.sort()
	return result


static func _placeholders_match(english: Dictionary, chinese: Dictionary) -> bool:
	for key: Variant in english:
		if _placeholders(str(english[key])) != _placeholders(str(chinese.get(key, ""))):
			return false
	return true


static func _placeholders(text: String) -> Array[String]:
	var regex: RegEx = RegEx.new()
	if regex.compile("\\{([A-Za-z0-9_-]+)\\}") != OK:
		return []
	var result: Array[String] = []
	for match_result: RegExMatch in regex.search_all(text):
		var placeholder: String = match_result.get_string(1)
		if placeholder not in result:
			result.append(placeholder)
	result.sort()
	return result


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
