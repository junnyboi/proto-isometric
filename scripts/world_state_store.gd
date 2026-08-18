extends RefCounted

var _path: String = ""
var _last_error: String = ""


func configure(path: String) -> bool:
	_path = path
	_last_error = ""
	if path.is_empty():
		_last_error = "Save path is empty."
		return false
	return true


func exists(path: String = "") -> bool:
	return FileAccess.file_exists(_resolved(path))


func read_text(path: String = "", max_bytes: int = 2_097_152) -> String:
	_last_error = ""
	var target: String = _resolved(path)
	if target.is_empty() or not FileAccess.file_exists(target):
		return ""
	var file: FileAccess = FileAccess.open(target, FileAccess.READ)
	if file == null:
		_last_error = "Could not open save file: %s" % FileAccess.get_open_error()
		return ""
	var length: int = file.get_length()
	if length < 0 or length > max_bytes:
		_last_error = "Save file exceeds %d bytes." % max_bytes
		file.close()
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func write_text(path: String, text: String, max_bytes: int = 2_097_152) -> bool:
	_last_error = ""
	var target: String = _resolved(path)
	if target.is_empty():
		_last_error = "Save path is empty."
		return false
	if text.to_utf8_buffer().size() > max_bytes:
		_last_error = "Encoded save exceeds %d bytes." % max_bytes
		return false
	var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		_last_error = "Could not open save file for writing: %s" % FileAccess.get_open_error()
		return false
	file.store_string(text)
	file.flush()
	file.close()
	return true


func rename(source: String, target: String) -> bool:
	_last_error = ""
	var source_path: String = _resolved(source)
	var target_path: String = _resolved(target)
	if source_path.is_empty() or target_path.is_empty() or not FileAccess.file_exists(source_path):
		_last_error = "Save rename source is missing."
		return false
	var result: Error = DirAccess.rename_absolute(_absolute(source_path), _absolute(target_path))
	if result != OK:
		_last_error = "Could not rename save file: %s" % error_string(result)
		return false
	return true


func remove(path: String) -> bool:
	_last_error = ""
	var target: String = _resolved(path)
	if target.is_empty() or not FileAccess.file_exists(target):
		return true
	var result: Error = DirAccess.remove_absolute(_absolute(target))
	if result != OK:
		_last_error = "Could not remove save file: %s" % error_string(result)
		return false
	return true


func get_last_error() -> String:
	return _last_error


func get_path() -> String:
	return _path


func _resolved(path: String) -> String:
	return _path if path.is_empty() else path


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("user://") else path
