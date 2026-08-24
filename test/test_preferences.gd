extends RefCounted

const AccessibilityPanelScript: GDScript = preload("res://scripts/accessibility_panel.gd")
const AudioServiceScript: GDScript = preload("res://scripts/audio_service.gd")
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
		"preferences default VFX intensity is one hundred percent",
		is_equal_approx(float(defaults[&"vfx_intensity"]), 1.0),
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
			and is_equal_approx(float(defaults[&"ambience_volume"]), 1.0)
			and is_equal_approx(float(defaults[&"music_volume"]), 1.0)
		),
	)
	_add(
		cases,
		"preferences default effects quality is full",
		defaults[&"effects_quality"] == &"full",
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
	_add(
		cases,
		"preferences reject unsupported effects quality",
		not bool(preferences.call("set_value", &"effects_quality", "cinematic")),
	)
	_add(
		cases,
		"preferences reject unsafe VFX intensity",
		not bool(preferences.call("set_value", &"vfx_intensity", 1.1)),
	)
	preferences.call("set_value", &"ui_scale", 1.15)
	preferences.call("set_value", &"camera_shake", false)
	preferences.call("set_value", &"reduced_flash", true)
	preferences.call("set_value", &"haptics", false)
	preferences.call("set_value", &"left_handed", true)
	preferences.call("set_value", &"sfx_enabled", false)
	preferences.call("set_value", &"master_volume", 0.8)
	preferences.call("set_value", &"sfx_volume", 0.65)
	preferences.call("set_value", &"ambience_volume", 0.55)
	preferences.call("set_value", &"music_volume", 0.45)
	preferences.call("set_value", &"locale", "zh_CN")
	preferences.call("set_value", &"camera_zoom", 1.17)
	preferences.call("set_value", &"effects_quality", &"reduced")
	preferences.call("set_value", &"vfx_intensity", 0.4)
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
			and is_equal_approx(float(snapshot[&"ambience_volume"]), 0.55)
			and is_equal_approx(float(snapshot[&"music_volume"]), 0.45)
			and snapshot[&"locale"] == &"zh-CN"
			and is_equal_approx(float(snapshot[&"camera_zoom"]), 1.17)
			and snapshot[&"effects_quality"] == &"reduced"
			and is_equal_approx(float(snapshot[&"vfx_intensity"]), 0.4)
		),
	)
	var legacy_runtime: Dictionary = snapshot.duplicate(true)
	legacy_runtime.erase(&"camera_zoom")
	legacy_runtime.erase(&"master_volume")
	legacy_runtime.erase(&"sfx_volume")
	legacy_runtime.erase(&"ambience_volume")
	legacy_runtime.erase(&"music_volume")
	legacy_runtime.erase(&"vfx_intensity")
	var legacy_preferences: RefCounted = PlayerPreferencesScript.new() as RefCounted
	_add(
		cases,
		"legacy preferences restore camera, audio, and VFX defaults",
		(
			bool(legacy_preferences.call("restore_dictionary", legacy_runtime))
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
				float(
					(legacy_preferences.call("to_dictionary") as Dictionary)[&"ambience_volume"]
				),
				1.0,
			)
			and is_equal_approx(
				float((legacy_preferences.call("to_dictionary") as Dictionary)[&"music_volume"]),
				1.0,
			)
			and is_equal_approx(
				float((legacy_preferences.call("to_dictionary") as Dictionary)[&"vfx_intensity"]),
				1.0,
			)
		)
	)
	var legacy_quality: Dictionary = snapshot.duplicate(true)
	legacy_quality.erase(&"effects_quality")
	var quality_preferences: RefCounted = PlayerPreferencesScript.new() as RefCounted
	_add(
		cases,
		"legacy preferences restore full effects quality",
		(
			bool(quality_preferences.call("restore_dictionary", legacy_quality))
			and (
				(quality_preferences.call("to_dictionary") as Dictionary)[&"effects_quality"]
				== &"full"
			)
		),
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
			and recovered[&"effects_quality"] == &"full"
			and is_equal_approx(float(recovered[&"vfx_intensity"]), 1.0)
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
	var vfx_slider: HSlider = panel.call("get_vfx_intensity_slider") as HSlider
	var master_slider: HSlider = panel.call("get_audio_volume_slider", &"master_volume") as HSlider
	var sfx_slider: HSlider = panel.call("get_audio_volume_slider", &"sfx_volume") as HSlider
	var music_slider: HSlider = panel.call("get_audio_volume_slider", &"music_volume") as HSlider
	var ambience_slider: HSlider = (
		panel.call("get_audio_volume_slider", &"ambience_volume") as HSlider
	)
	_add(
		cases,
		"settings exposes Master, SFX, Music, and Ambience mixer sliders",
		(
			master_slider != null
				and sfx_slider != null
				and music_slider != null
				and ambience_slider != null
				and master_slider.min_value == 0.0
				and master_slider.max_value == 100.0
				and master_slider.step == 5.0
				and sfx_slider.step == 5.0
				and music_slider.step == 5.0
				and ambience_slider.step == 5.0
				and "MASTER VOLUME" in master_slider.tooltip_text
				and "SFX VOLUME" in sfx_slider.tooltip_text
				and "MUSIC VOLUME" in music_slider.tooltip_text
				and "AMBIENCE VOLUME" in ambience_slider.tooltip_text
		),
	)
	var audio_service: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(
		"AudioService"
	)
	if audio_service != null:
		panel.connect("preferences_changed", Callable(audio_service, "apply_preferences"))
	panel.call("_set_audio_volume", 60.0, &"master_volume")
	panel.call("_set_audio_volume", 45.0, &"sfx_volume")
	panel.call("_set_audio_volume", 35.0, &"music_volume")
	panel.call("_set_audio_volume", 25.0, &"ambience_volume")
	var audio_saved: Dictionary = (
		(PlayerPreferencesScript.new() as RefCounted).call("load_preferences") as Dictionary
	)
	var master_bus: int = AudioServer.get_bus_index(AudioServiceScript.BUS_MASTER)
	var sfx_bus: int = AudioServer.get_bus_index(AudioServiceScript.BUS_SFX)
	var music_bus: int = AudioServer.get_bus_index(AudioServiceScript.BUS_MUSIC)
	var ambience_bus: int = AudioServer.get_bus_index(AudioServiceScript.BUS_AMBIENT)
	_add(
		cases,
		"Master, SFX, Music, and Ambience sliders persist and update live buses",
		(
			is_equal_approx(float(audio_saved[&"master_volume"]), 0.6)
				and bool(audio_saved[&"sfx_enabled"])
				and is_equal_approx(float(audio_saved[&"sfx_volume"]), 0.45)
				and is_equal_approx(float(audio_saved[&"music_volume"]), 0.35)
				and is_equal_approx(float(audio_saved[&"ambience_volume"]), 0.25)
				and is_equal_approx(master_slider.value, 60.0)
				and is_equal_approx(sfx_slider.value, 45.0)
				and is_equal_approx(music_slider.value, 35.0)
				and is_equal_approx(ambience_slider.value, 25.0)
				and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(master_bus)), 0.6)
				and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)), 0.45)
				and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music_bus)), 0.35)
				and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(ambience_bus)), 0.25)
		),
	)
	panel.call("_set_audio_volume", 0.0, &"sfx_volume")
	_add(
		cases,
		"SFX slider zero mutes the SFX bus and preserves legacy disable semantics",
		(
			not bool((panel.call("get_preferences") as Dictionary)[&"sfx_enabled"])
				and AudioServer.is_bus_mute(sfx_bus)
		),
	)
	panel.call("_set_audio_volume", 0.0, &"ambience_volume")
	_add(
		cases,
		"Ambience slider zero mutes the Ambient bus",
		AudioServer.is_bus_mute(ambience_bus),
	)
	panel.get("_preferences").call("set_value", &"left_handed", true)
	panel.call("_reset_audio_defaults")
	var reset_audio: Dictionary = panel.call("get_preferences") as Dictionary
	var reset_button: Button = panel.get("_buttons")[&"audio_defaults"] as Button
	_add(
		cases,
		"Reset Audio Defaults restores every mixer without changing accessibility choices",
		(
			bool(reset_audio[&"sfx_enabled"])
			and is_equal_approx(float(reset_audio[&"master_volume"]), 1.0)
			and is_equal_approx(float(reset_audio[&"sfx_volume"]), 1.0)
			and is_equal_approx(float(reset_audio[&"ambience_volume"]), 1.0)
			and is_equal_approx(float(reset_audio[&"music_volume"]), 1.0)
			and bool(reset_audio[&"left_handed"])
			and is_equal_approx(master_slider.value, 100.0)
			and is_equal_approx(sfx_slider.value, 100.0)
			and is_equal_approx(music_slider.value, 100.0)
			and is_equal_approx(ambience_slider.value, 100.0)
			and not AudioServer.is_bus_mute(sfx_bus)
			and not AudioServer.is_bus_mute(ambience_bus)
			and "RESET AUDIO DEFAULTS" in reset_button.text
		),
	)
	_add(
		cases,
		"settings menu exposes a ten-step VFX intensity slider",
		(
			vfx_slider != null
			and is_equal_approx(vfx_slider.min_value, 0.0)
			and is_equal_approx(vfx_slider.max_value, 100.0)
			and is_equal_approx(vfx_slider.step, 10.0)
			and is_equal_approx(vfx_slider.value, 100.0)
			and "VFX INTENSITY" in vfx_slider.tooltip_text
		),
	)
	var access_button: Button = panel.get("_access_button") as Button
	var access_panel: ColorRect = panel.get("_panel") as ColorRect
	access_panel.visible = true
	_add(
		cases,
		"accessibility controls own their touch regions",
		(
			bool(panel.call("blocks_world_touch", access_button.position + Vector2.ONE))
			and bool(panel.call("blocks_world_touch", access_panel.position + Vector2.ONE))
			and not bool(panel.call("blocks_world_touch", Vector2.ZERO))
		),
	)
	access_panel.visible = false
	panel.call("_set_vfx_intensity", 40.0)
	var vfx_saved: Dictionary = (
		(PlayerPreferencesScript.new() as RefCounted).call("load_preferences") as Dictionary
	)
	_add(
		cases,
		"VFX slider persists its normalized value",
		is_equal_approx(float(vfx_saved[&"vfx_intensity"]), 0.4),
	)
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
	var quality_button: Button = panel.get("_buttons")[&"effects_quality"] as Button
	panel.call("_cycle_effects_quality")
	_add(
		cases,
		"settings exposes a persistent reduced effects tier",
		(
			panel.call("get_preferences")[&"effects_quality"] == &"reduced"
			and "REDUCED" in quality_button.text
		),
	)
	panel.call("_set_audio_volume", 65.0, &"sfx_volume")
	_add(
		cases,
		"SFX slider restores live effects after a true-zero mute",
		(
			float(panel.call("get_preferences")[&"sfx_volume"]) == 0.65
				and bool(panel.call("get_preferences")[&"sfx_enabled"])
				and is_equal_approx(sfx_slider.value, 65.0)
				and not AudioServer.is_bus_mute(sfx_bus)
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
	if audio_service != null:
		(
			audio_service
			. call(
				"apply_preferences",
				{
					&"sfx_enabled": true,
					&"master_volume": 1.0,
					&"sfx_volume": 1.0,
					&"ambience_volume": 1.0,
					&"music_volume": 1.0,
				},
			)
		)
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
