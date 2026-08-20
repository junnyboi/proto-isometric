extends RefCounted

const PATH: String = "user://walkers-wake-preferences.json"
const MAX_BYTES: int = 4096

var _ui_scale: float = 1.0
var _camera_shake: bool = true
var _camera_shake_intensity: float = 1.0
var _reduced_flash: bool = false
var _haptics: bool = true
var _haptic_intensity: float = 1.0
var _onboarding_seen: bool = false
var _left_handed: bool = false
var _sfx_enabled: bool = true
var _locale: StringName = &"en"
var _camera_zoom: float = 1.0


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
	var temporary: String = PATH + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dictionary()))
	file.flush()
	file = null
	var directory: DirAccess = DirAccess.open("user://")
	if directory == null:
		return false
	if FileAccess.file_exists(PATH):
		directory.remove(PATH.get_file())
	return directory.rename(temporary.get_file(), PATH.get_file()) == OK


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
		&"onboarding_seen":
			valid = value is bool
			if valid:
				_onboarding_seen = value
		&"left_handed":
			valid = value is bool
			if valid:
				_left_handed = value
		&"sfx_enabled":
			valid = value is bool
			if valid:
				_sfx_enabled = value
		&"locale":
			var locale: StringName = normalize_locale(value)
			valid = locale != &""
			if valid:
				_locale = locale
		&"camera_zoom":
			valid = value is float and is_finite(value) and value >= 0.7 and value <= 1.3
			if valid:
				_camera_zoom = snappedf(value, 0.1)
		_:
			valid = false
	return valid


func restore_dictionary(snapshot: Dictionary) -> bool:
	if snapshot.size() < 4 or snapshot.size() > 11:
		return false
	var scale: Variant = snapshot.get(&"ui_scale")
	var shake: Variant = snapshot.get(&"camera_shake")
	var shake_intensity: Variant = snapshot.get(&"camera_shake_intensity", 1.0 if shake else 0.0)
	var flash: Variant = snapshot.get(&"reduced_flash")
	var haptics: Variant = snapshot.get(&"haptics")
	var haptic_intensity: Variant = snapshot.get(&"haptic_intensity", 1.0 if haptics else 0.0)
	var onboarding: Variant = snapshot.get(&"onboarding_seen", false)
	var left_handed: Variant = snapshot.get(&"left_handed", false)
	var sfx_enabled: Variant = snapshot.get(&"sfx_enabled", true)
	var locale: Variant = snapshot.get(&"locale", "en")
	var camera_zoom: Variant = snapshot.get(&"camera_zoom", 1.0)
	if (
		not scale is float
		or not shake is bool
		or not _valid_intensity(shake_intensity)
		or not flash is bool
		or not haptics is bool
		or not _valid_intensity(haptic_intensity)
		or not onboarding is bool
		or not left_handed is bool
		or not sfx_enabled is bool
		or not (locale is String or locale is StringName)
		or not camera_zoom is float
	):
		return false
	var before: Dictionary = to_dictionary()
	if (
		not set_value(&"ui_scale", scale)
		or not set_value(&"camera_shake_intensity", shake_intensity)
		or not set_value(&"reduced_flash", flash)
		or not set_value(&"haptic_intensity", haptic_intensity)
		or not set_value(&"onboarding_seen", onboarding)
		or not set_value(&"left_handed", left_handed)
		or not set_value(&"sfx_enabled", sfx_enabled)
		or not set_value(&"locale", locale)
		or not set_value(&"camera_zoom", camera_zoom)
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
		&"onboarding_seen": _onboarding_seen,
		&"left_handed": _left_handed,
		&"sfx_enabled": _sfx_enabled,
		&"locale": _locale,
		&"camera_zoom": _camera_zoom,
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
	_onboarding_seen = bool(snapshot.get(&"onboarding_seen", false))
	_left_handed = bool(snapshot.get(&"left_handed", false))
	_sfx_enabled = bool(snapshot.get(&"sfx_enabled", true))
	_locale = normalize_locale(snapshot.get(&"locale", "en"))
	_camera_zoom = float(snapshot.get(&"camera_zoom", 1.0))
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
