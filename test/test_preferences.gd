extends RefCounted

const AccessibilityPanelScript: GDScript = preload("res://scripts/accessibility_panel.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")
const PATH: String = "user://walkers-wake-preferences.json"


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_clear()
	var preferences: RefCounted = PlayerPreferencesScript.new() as RefCounted
	var defaults: Dictionary = preferences.call("load_preferences") as Dictionary
	_add(cases, "preferences default camera shake on", bool(defaults[&"camera_shake"]))
	_add(cases, "preferences default reduced flash off", not bool(defaults[&"reduced_flash"]))
	_add(cases, "preferences default locale is English", defaults[&"locale"] == &"en")
	_add(
		cases,
		"preferences default camera zoom is one hundred percent",
		is_equal_approx(float(defaults[&"camera_zoom"]), 1.0)
	)
	_add(
		cases,
		"preferences reject unsafe UI scale",
		not bool(preferences.call("set_value", &"ui_scale", 1.5)),
	)
	_add(
		cases,
		"preferences reject unsupported locales",
		not bool(preferences.call("set_value", &"locale", "fr-FR")),
	)
	_add(
		cases,
		"preferences reject unsafe camera zoom",
		not bool(preferences.call("set_value", &"camera_zoom", 1.4))
	)
	preferences.call("set_value", &"ui_scale", 1.15)
	preferences.call("set_value", &"camera_shake", false)
	preferences.call("set_value", &"reduced_flash", true)
	preferences.call("set_value", &"haptics", false)
	preferences.call("set_value", &"left_handed", true)
	preferences.call("set_value", &"sfx_enabled", false)
	preferences.call("set_value", &"locale", "zh_CN")
	preferences.call("set_value", &"camera_zoom", 1.2)
	_add(cases, "preferences save atomically", bool(preferences.call("save_preferences")))
	var restored: RefCounted = PlayerPreferencesScript.new() as RefCounted
	var snapshot: Dictionary = restored.call("load_preferences") as Dictionary
	_add(
		cases,
		"preferences round-trip all accessibility fields",
		(
			is_equal_approx(float(snapshot[&"ui_scale"]), 1.15)
			and not bool(snapshot[&"camera_shake"])
			and bool(snapshot[&"reduced_flash"])
			and not bool(snapshot[&"haptics"])
			and bool(snapshot[&"left_handed"])
			and not bool(snapshot[&"sfx_enabled"])
			and snapshot[&"locale"] == &"zh-CN"
			and is_equal_approx(float(snapshot[&"camera_zoom"]), 1.2)
		),
	)
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.erase(&"camera_zoom")
	var legacy_preferences: RefCounted = PlayerPreferencesScript.new() as RefCounted
	_add(
		cases,
		"legacy preferences restore default camera zoom",
		(
			bool(legacy_preferences.call("restore_dictionary", legacy))
			and is_equal_approx(
				float((legacy_preferences.call("to_dictionary") as Dictionary)[&"camera_zoom"]), 1.0
			)
		)
	)
	var malformed: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	malformed.store_string("{malformed")
	malformed = null
	var recovered: Dictionary = (
		(PlayerPreferencesScript.new() as RefCounted).call("load_preferences") as Dictionary
	)
	_add(
		cases,
		"malformed preferences fail safely to defaults",
		(
			bool(recovered[&"camera_shake"])
			and not bool(recovered[&"reduced_flash"])
			and recovered[&"locale"] == &"en"
			and is_equal_approx(float(recovered[&"camera_zoom"]), 1.0)
		),
	)
	var panel: CanvasLayer = AccessibilityPanelScript.new() as CanvasLayer
	LocalizationScript.set_locale(&"en", false)
	panel.set("_preferences", PlayerPreferencesScript.new() as RefCounted)
	panel.call("_build_interface")
	panel.call("_refresh")
	var language: Button = panel.call("get_language_button") as Button
	_add(
		cases,
		"settings menu exposes the bilingual language toggle",
		(
			language != null
			and "EN / 简体中文" in language.text
			and "[EN]" in language.text
			and language.get_theme_font_size("font_size") == 18
		),
	)
	panel.call("_cycle_locale")
	var toggled: Dictionary = (
		(PlayerPreferencesScript.new() as RefCounted).call("load_preferences") as Dictionary
	)
	_add(
		cases,
		"settings toggle switches and persists Simplified Chinese",
		(
			LocalizationScript.get_locale() == &"zh-CN"
			and toggled[&"locale"] == &"zh-CN"
			and "[简体中文]" in language.text
		),
	)
	panel.free()
	LocalizationScript.set_locale(&"en", false)
	_clear()
	return cases


static func _clear() -> void:
	var directory: DirAccess = DirAccess.open("user://")
	if directory == null:
		return
	for path: String in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			directory.remove(path.get_file())


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
