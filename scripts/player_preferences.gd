extends RefCounted

const PATH: String = "user://walkers-wake-preferences.json"
const MAX_BYTES: int = 4096

var _ui_scale: float = 1.0
var _camera_shake: bool = true
var _reduced_flash: bool = false
var _haptics: bool = true
var _onboarding_seen: bool = false
var _left_handed: bool = false
var _sfx_enabled: bool = true


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
		&"reduced_flash":
			valid = value is bool
			if valid:
				_reduced_flash = value
		&"haptics":
			valid = value is bool
			if valid:
				_haptics = value
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
		_:
			valid = false
	return valid


func restore_dictionary(snapshot: Dictionary) -> bool:
	if snapshot.size() < 4 or snapshot.size() > 7:
		return false
	var scale: Variant = snapshot.get(&"ui_scale")
	var shake: Variant = snapshot.get(&"camera_shake")
	var flash: Variant = snapshot.get(&"reduced_flash")
	var haptics: Variant = snapshot.get(&"haptics")
	var onboarding: Variant = snapshot.get(&"onboarding_seen", false)
	var left_handed: Variant = snapshot.get(&"left_handed", false)
	var sfx_enabled: Variant = snapshot.get(&"sfx_enabled", true)
	if (
		not scale is float
		or not shake is bool
		or not flash is bool
		or not haptics is bool
		or not onboarding is bool
		or not left_handed is bool
		or not sfx_enabled is bool
	):
		return false
	var before: Dictionary = to_dictionary()
	if (
		not set_value(&"ui_scale", scale)
		or not set_value(&"camera_shake", shake)
		or not set_value(&"reduced_flash", flash)
		or not set_value(&"haptics", haptics)
		or not set_value(&"onboarding_seen", onboarding)
		or not set_value(&"left_handed", left_handed)
		or not set_value(&"sfx_enabled", sfx_enabled)
	):
		_apply(before)
		return false
	return true


func to_dictionary() -> Dictionary:
	return {
		&"ui_scale": _ui_scale,
		&"camera_shake": _camera_shake,
		&"reduced_flash": _reduced_flash,
		&"haptics": _haptics,
		&"onboarding_seen": _onboarding_seen,
		&"left_handed": _left_handed,
		&"sfx_enabled": _sfx_enabled,
	}


func _apply(snapshot: Dictionary) -> void:
	_ui_scale = float(snapshot[&"ui_scale"])
	_camera_shake = bool(snapshot[&"camera_shake"])
	_reduced_flash = bool(snapshot[&"reduced_flash"])
	_haptics = bool(snapshot[&"haptics"])
	_onboarding_seen = bool(snapshot.get(&"onboarding_seen", false))
	_left_handed = bool(snapshot.get(&"left_handed", false))
	_sfx_enabled = bool(snapshot.get(&"sfx_enabled", true))
