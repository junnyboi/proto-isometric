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
	_add(
		cases,
		"preferences default feedback intensity is full",
		(
			float(defaults[&"camera_shake_intensity"]) == 1.0
			and float(defaults[&"haptic_intensity"]) == 1.0
		),
	)
	_add(cases, "preferences default reduced flash off", not bool(defaults[&"reduced_flash"]))
	_add(cases, "preferences default locale is English", defaults[&"locale"] == &"en")
	var legacy: Dictionary = defaults.duplicate(true)
	legacy.erase(&"camera_shake_intensity")
	legacy.erase(&"haptic_intensity")
	legacy[&"camera_shake"] = false
	legacy[&"haptics"] = true
	var migrated: RefCounted = PlayerPreferencesScript.new() as RefCounted
	var migrated_ok: bool = bool(migrated.call("restore_dictionary", legacy))
	var migrated_snapshot: Dictionary = migrated.call("to_dictionary") as Dictionary
	_add(
		cases,
		"legacy boolean feedback settings migrate to graded intensity",
		(
			migrated_ok
			and float(migrated_snapshot[&"camera_shake_intensity"]) == 0.0
			and float(migrated_snapshot[&"haptic_intensity"]) == 1.0
		),
	)
	_add(
		cases,
		"preferences default camera zoom is one hundred percent",
		is_equal_approx(float(defaults[&"camera_zoom"]), 1.0)
	)
	_add(
		cases,
		"preferences default all audio buses to full gain",
		(
			is_equal_approx(float(defaults[&"master_volume"]), 1.0)
			and is_equal_approx(float(defaults[&"sfx_volume"]), 1.0)
			and is_equal_approx(float(defaults[&"music_volume"]), 1.0)
		),
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
		not bool(preferences.call("set_value", &"camera_zoom", 1.4)),
	)
	_add(
		cases,
		"preferences reject unsafe feedback intensity",
		not bool(preferences.call("set_value", &"camera_shake_intensity", 1.5)),
	)
	_add(
		cases,
		"preferences reject unsafe audio gain",
		not bool(preferences.call("set_value", &"sfx_volume", 1.4)),
	)
	preferences.call("set_value", &"ui_scale", 1.15)
	preferences.call("set_value", &"camera_shake", false)
	preferences.call("set_value", &"reduced_flash", true)
	preferences.call("set_value", &"haptics", false)
	preferences.call("set_value", &"left_handed", true)
	preferences.call("set_value", &"sfx_enabled", false)
	preferences.call("set_value", &"master_volume", 0.8)
	preferences.call("set_value", &"sfx_volume", 0.65)
	preferences.call("set_value", &"music_volume", 0.45)
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
			and is_equal_approx(float(snapshot[&"master_volume"]), 0.8)
			and is_equal_approx(float(snapshot[&"sfx_volume"]), 0.65)
			and is_equal_approx(float(snapshot[&"music_volume"]), 0.45)
			and snapshot[&"locale"] == &"zh-CN"
			and is_equal_approx(float(snapshot[&"camera_zoom"]), 1.2)
		),
	)
	var legacy_audio: Dictionary = snapshot.duplicate(true)
	legacy_audio.erase(&"camera_zoom")
	legacy_audio.erase(&"master_volume")
	legacy_audio.erase(&"sfx_volume")
	legacy_audio.erase(&"music_volume")
	var legacy_preferences: RefCounted = PlayerPreferencesScript.new() as RefCounted
	_add(
		cases,
		"legacy preferences restore camera and audio defaults",
		(
			bool(legacy_preferences.call("restore_dictionary", legacy_audio))
			and is_equal_approx(
				float((legacy_preferences.call("to_dictionary") as Dictionary)[&"camera_zoom"]), 1.0
			)
			and is_equal_approx(
				float((legacy_preferences.call("to_dictionary") as Dictionary)[&"master_volume"]),
				1.0,
			)
			and is_equal_approx(
				float((legacy_preferences.call("to_dictionary") as Dictionary)[&"sfx_volume"]),
				1.0,
			)
			and is_equal_approx(
				float((legacy_preferences.call("to_dictionary") as Dictionary)[&"music_volume"]),
				1.0,
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
	var graded: RefCounted = PlayerPreferencesScript.new() as RefCounted
	graded.call("set_value", &"camera_shake_intensity", 0.5)
	graded.call("set_value", &"haptic_intensity", 0.5)
	var graded_snapshot: Dictionary = graded.call("to_dictionary") as Dictionary
	_add(
		cases,
		"graded feedback intensity preserves legacy boolean compatibility",
		(
			bool(graded_snapshot[&"camera_shake"])
			and bool(graded_snapshot[&"haptics"])
			and float(graded_snapshot[&"camera_shake_intensity"]) == 0.5
			and float(graded_snapshot[&"haptic_intensity"]) == 0.5
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
	var camera_button: Button = panel.get("_buttons")[&"camera_shake"] as Button
	panel.call("_cycle_intensity", &"camera_shake_intensity")
	_add(
		cases,
		"settings camera intensity cycles from full to off",
		(
			float(panel.call("get_preferences")[&"camera_shake_intensity"]) == 0.0
			and "OFF" in camera_button.text
		),
	)
	panel.call("_cycle_intensity", &"camera_shake_intensity")
	_add(
		cases,
		"settings camera intensity exposes a low tier",
		(
			float(panel.call("get_preferences")[&"camera_shake_intensity"]) == 0.5
			and "LOW" in camera_button.text
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
