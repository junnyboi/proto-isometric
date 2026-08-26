extends RefCounted

const PATH: String = "user://walkers-wake-preferences.json"
const MAX_BYTES: int = 4096
const VALID_EFFECTS_QUALITY: Array[StringName] = [&"full", &"reduced", &"minimal"]
const AUDIO_DEFAULTS: Dictionary = {
	&"sfx_enabled": true,
	&"master_volume": 1.0,
	&"sfx_volume": 1.0,
	&"ambience_volume": 1.0,
	&"music_volume": 1.0,
}

var _ui_scale: float = 1.0
var _camera_shake: bool = true
var _camera_shake_intensity: float = 1.0
var _reduced_flash: bool = false
var _haptics: bool = true
var _haptic_intensity: float = 1.0
var _left_handed: bool = false
var _sfx_enabled: bool = true
var _master_volume: float = 1.0
var _sfx_volume: float = 1.0
var _ambience_volume: float = 1.0
var _music_volume: float = 1.0
var _locale: StringName = &"en"
var _camera_zoom: float = 1.0
var _effects_quality: StringName = &"full"
var _vfx_intensity: float = 1.0


func load_preferences() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return to_dictionary()
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return to_dictionary()
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) == OK and parser.data is Dictionary:
		restore_dictionary(parser.data as Dictionary)
	return to_dictionary()


func save_preferences() -> bool:
	var serialized: String = JSON.stringify(to_dictionary())
	if serialized.to_utf8_buffer().size() > MAX_BYTES:
		return false
	var temporary: String = PATH + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(serialized)
	file.flush()
	file = null
	var directory: DirAccess = DirAccess.open("user://")
	if directory == null:
		return false
	if FileAccess.file_exists(PATH):
		directory.remove(PATH.get_file())
	return directory.rename(temporary.get_file(), PATH.get_file()) == OK


func reset_audio_defaults() -> bool:
	for key: StringName in AUDIO_DEFAULTS:
		if not set_value(key, AUDIO_DEFAULTS[key]):
			return false
	return true


func set_value(key: StringName, value: Variant) -> bool:
	var valid: bool = true
	match key:
		&"ui_scale":
			valid = value is float and is_finite(value) and value >= 0.85 and value <= 1.25
			if valid:
				_ui_scale = snappedf(value, 0.05)
		&"camera_shake":
			valid = value is bool
			if valid:
				_camera_shake = value
				_camera_shake_intensity = 1.0 if value else 0.0
		&"camera_shake_intensity":
			valid = _valid_intensity(value)
			if valid:
				_camera_shake_intensity = snappedf(value, 0.5)
				_camera_shake = _camera_shake_intensity > 0.0
		&"reduced_flash":
			valid = value is bool
			if valid:
				_reduced_flash = value
		&"haptics":
			valid = value is bool
			if valid:
				_haptics = value
				_haptic_intensity = 1.0 if value else 0.0
		&"haptic_intensity":
			valid = _valid_intensity(value)
			if valid:
				_haptic_intensity = snappedf(value, 0.5)
				_haptics = _haptic_intensity > 0.0
		&"left_handed":
			valid = value is bool
			if valid:
				_left_handed = value
		&"sfx_enabled":
			valid = value is bool
			if valid:
				_sfx_enabled = value
		&"master_volume":
			valid = _valid_volume(value)
			if valid:
				_master_volume = snappedf(value, 0.05)
		&"sfx_volume":
			valid = _valid_volume(value)
			if valid:
				_sfx_volume = snappedf(value, 0.05)
		&"ambience_volume":
			valid = _valid_volume(value)
			if valid:
				_ambience_volume = snappedf(value, 0.05)
		&"music_volume":
			valid = _valid_volume(value)
			if valid:
				_music_volume = snappedf(value, 0.05)
		&"locale":
			var locale: StringName = normalize_locale(value)
			valid = locale != &""
			if valid:
				_locale = locale
		&"camera_zoom":
			valid = value is float and is_finite(value) and value >= 0.7 and value <= 1.3
			if valid:
				_camera_zoom = snappedf(value, 0.01)
		&"effects_quality":
			var quality: StringName = normalize_effects_quality(value)
			valid = quality != &""
			if valid:
				_effects_quality = quality
		&"vfx_intensity":
			valid = _valid_intensity(value)
			if valid:
				_vfx_intensity = snappedf(value, 0.1)
		_:
			valid = false
	return valid


func restore_dictionary(snapshot: Dictionary) -> bool:
	if snapshot.size() < 4 or snapshot.size() > 17:
		return false
	var scale: Variant = snapshot.get(&"ui_scale")
	var shake: Variant = snapshot.get(&"camera_shake")
	var shake_intensity: Variant = snapshot.get(&"camera_shake_intensity", 1.0 if shake else 0.0)
	var flash: Variant = snapshot.get(&"reduced_flash")
	var haptics: Variant = snapshot.get(&"haptics")
	var haptic_intensity: Variant = snapshot.get(&"haptic_intensity", 1.0 if haptics else 0.0)
	var left_handed: Variant = snapshot.get(&"left_handed", false)
	var sfx_enabled: Variant = snapshot.get(&"sfx_enabled", true)
	var master_volume: Variant = snapshot.get(&"master_volume", 1.0)
	var sfx_volume: Variant = snapshot.get(&"sfx_volume", 1.0)
	var ambience_volume: Variant = snapshot.get(&"ambience_volume", 1.0)
	var music_volume: Variant = snapshot.get(&"music_volume", 1.0)
	var locale: Variant = snapshot.get(&"locale", "en")
	var camera_zoom: Variant = snapshot.get(&"camera_zoom", 1.0)
	var effects_quality: Variant = snapshot.get(&"effects_quality", "full")
	var vfx_intensity: Variant = snapshot.get(&"vfx_intensity", 1.0)
	if (
		not scale is float
		or not shake is bool
		or not _valid_intensity(shake_intensity)
		or not flash is bool
		or not haptics is bool
		or not _valid_intensity(haptic_intensity)
		or not left_handed is bool
		or not sfx_enabled is bool
		or not master_volume is float
		or not sfx_volume is float
		or not ambience_volume is float
		or not music_volume is float
		or not (locale is String or locale is StringName)
		or not camera_zoom is float
		or not (effects_quality is String or effects_quality is StringName)
		or not _valid_intensity(vfx_intensity)
	):
		return false
	var before: Dictionary = to_dictionary()
	if (
		not set_value(&"ui_scale", scale)
		or not set_value(&"camera_shake_intensity", shake_intensity)
		or not set_value(&"reduced_flash", flash)
		or not set_value(&"haptic_intensity", haptic_intensity)
		or not set_value(&"left_handed", left_handed)
		or not set_value(&"sfx_enabled", sfx_enabled)
		or not set_value(&"master_volume", master_volume)
		or not set_value(&"sfx_volume", sfx_volume)
		or not set_value(&"ambience_volume", ambience_volume)
		or not set_value(&"music_volume", music_volume)
		or not set_value(&"locale", locale)
		or not set_value(&"camera_zoom", camera_zoom)
		or not set_value(&"effects_quality", effects_quality)
		or not set_value(&"vfx_intensity", vfx_intensity)
	):
		_apply(before)
		return false
	return true


func to_dictionary() -> Dictionary:
	return {
		&"ui_scale": _ui_scale,
		&"camera_shake": _camera_shake,
		&"camera_shake_intensity": _camera_shake_intensity,
		&"reduced_flash": _reduced_flash,
		&"haptics": _haptics,
		&"haptic_intensity": _haptic_intensity,
		&"left_handed": _left_handed,
		&"sfx_enabled": _sfx_enabled,
		&"master_volume": _master_volume,
		&"sfx_volume": _sfx_volume,
		&"ambience_volume": _ambience_volume,
		&"music_volume": _music_volume,
		&"locale": _locale,
		&"camera_zoom": _camera_zoom,
		&"effects_quality": _effects_quality,
		&"vfx_intensity": _vfx_intensity,
	}


func _apply(snapshot: Dictionary) -> void:
	_ui_scale = float(snapshot[&"ui_scale"])
	_camera_shake = bool(snapshot[&"camera_shake"])
	_camera_shake_intensity = float(
		snapshot.get(&"camera_shake_intensity", 1.0 if _camera_shake else 0.0)
	)
	_reduced_flash = bool(snapshot[&"reduced_flash"])
	_haptics = bool(snapshot[&"haptics"])
	_haptic_intensity = float(snapshot.get(&"haptic_intensity", 1.0 if _haptics else 0.0))
	_left_handed = bool(snapshot.get(&"left_handed", false))
	_sfx_enabled = bool(snapshot.get(&"sfx_enabled", true))
	_master_volume = float(snapshot.get(&"master_volume", 1.0))
	_sfx_volume = float(snapshot.get(&"sfx_volume", 1.0))
	_ambience_volume = float(snapshot.get(&"ambience_volume", 1.0))
	_music_volume = float(snapshot.get(&"music_volume", 1.0))
	_locale = normalize_locale(snapshot.get(&"locale", "en"))
	_camera_zoom = float(snapshot.get(&"camera_zoom", 1.0))
	_effects_quality = normalize_effects_quality(snapshot.get(&"effects_quality", "full"))
	if _effects_quality == &"":
		_effects_quality = &"full"
	_vfx_intensity = float(snapshot.get(&"vfx_intensity", 1.0))
	if _locale == &"":
		_locale = &"en"


static func _valid_intensity(value: Variant) -> bool:
	return value is float and is_finite(value) and value >= 0.0 and value <= 1.0


static func normalize_locale(value: Variant) -> StringName:
	var normalized: String = str(value).strip_edges().replace("_", "-").to_lower()
	if normalized == "en" or normalized.begins_with("en-"):
		return &"en"
	if normalized in ["zh", "zh-cn", "zh-hans", "zh-hans-cn"]:
		return &"zh-CN"
	return &""


static func _valid_volume(value: Variant) -> bool:
	return value is float and is_finite(value) and value >= 0.0 and value <= 1.0


static func normalize_effects_quality(value: Variant) -> StringName:
	var normalized: StringName = StringName(str(value).strip_edges().to_lower())
	return normalized if normalized in VALID_EFFECTS_QUALITY else &""
