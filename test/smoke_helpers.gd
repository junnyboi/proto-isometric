extends RefCounted


static func advance_worm_to_expose(worms: Node2D, worm_id: int) -> void:
	worms.call("advance", 0.001)
	var snapshot: Dictionary = worms.call("get_combat_snapshot", worm_id) as Dictionary
	worms.call("advance", float(snapshot[&"state_remaining"]))


static func clear_test_save(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path.get_base_dir())
	if directory == null:
		return
	var prefix: String = path.get_file()
	for file_name: String in directory.get_files():
		if file_name == prefix or file_name.begins_with(prefix + "."):
			directory.remove(file_name)


static func read_test_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}
