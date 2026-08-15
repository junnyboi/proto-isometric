extends RefCounted

var _path: String = ""
var _last_error: String = ""


func configure(path: String) -> void:
	_path = path
	_last_error = ""


func save_snapshot(snapshot: Dictionary) -> bool:
	_last_error = ""
	if _path.is_empty():
		_last_error = "Save path is empty."
		return false
	var encoded: String = JSON.stringify(snapshot)
	if not JSON.parse_string(encoded) is Dictionary:
		_last_error = "Snapshot could not be encoded."
		return false

	var temporary_path: String = _path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		_last_error = "Could not open temporary save file: %s" % FileAccess.get_open_error()
		return false
	file.store_string(encoded)
	file.flush()
	file.close()

	var absolute_path: String = _absolute_path(_path)
	var absolute_temporary_path: String = _absolute_path(temporary_path)
	var backup_path: String = _path + ".bak"
	var absolute_backup_path: String = _absolute_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup_path)
	if FileAccess.file_exists(_path):
		var backup_error: Error = DirAccess.rename_absolute(absolute_path, absolute_backup_path)
		if backup_error != OK:
			_last_error = "Could not preserve existing save file: %s" % error_string(backup_error)
			DirAccess.remove_absolute(absolute_temporary_path)
			return false
	var rename_error: Error = DirAccess.rename_absolute(absolute_temporary_path, absolute_path)
	if rename_error != OK:
		_last_error = "Could not finalize save file: %s" % error_string(rename_error)
		DirAccess.remove_absolute(absolute_temporary_path)
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup_path, absolute_path)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup_path)
	return true


func load_snapshot() -> Dictionary:
	_last_error = ""
	if _path.is_empty():
		_last_error = "Save path is empty."
		return {}
	if not FileAccess.file_exists(_path):
		return {}
	var file: FileAccess = FileAccess.open(_path, FileAccess.READ)
	if file == null:
		_last_error = "Could not open save file: %s" % FileAccess.get_open_error()
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(text)
	if parse_error != OK or not parser.data is Dictionary:
		_last_error = "Save file is not valid JSON world state: %s" % parser.get_error_message()
		return {}
	return parser.data as Dictionary


func clear() -> bool:
	_last_error = ""
	if _path.is_empty():
		return true
	for candidate: String in [_path, _path + ".tmp", _path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var result: Error = DirAccess.remove_absolute(_absolute_path(candidate))
		if result != OK:
			_last_error = "Could not clear save file: %s" % error_string(result)
			return false
	return true


func get_last_error() -> String:
	return _last_error


func get_path() -> String:
	return _path


func _absolute_path(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("user://") else path
