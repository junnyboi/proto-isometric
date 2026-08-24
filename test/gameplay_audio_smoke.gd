extends RefCounted

const BiomeMusicScript: GDScript = preload("res://scripts/biome_music.gd")
const BiomeSoundscapeScript: GDScript = preload("res://scripts/biome_soundscape.gd")
const MISSING_CELL: Vector2i = Vector2i(999, 999)


static func evaluate(tree: SceneTree, map: Node, world: RefCounted) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var router: Node = map.get("_feedback_router") as Node
	var music: Node = router.get("_music") as Node
	var soundscape: Node = router.get("_soundscape") as Node
	var biome_cases: Array[Dictionary] = [
		{&"label": "Desert", &"surface": &"sand", &"seed": Vector2i(8, 8)},
		{&"label": "Wetlands", &"surface": &"mud", &"seed": Vector2i(23, 10)},
		{&"label": "Frozen Tundra", &"surface": &"snow", &"seed": Vector2i(0, -12)},
		{&"label": "Lava Fields", &"surface": &"volcanic", &"seed": Vector2i(-12, 0)},
	]
	for index: int in range(biome_cases.size()):
		var test_case: Dictionary = biome_cases[index]
		var surface: StringName = test_case[&"surface"] as StringName
		var label: String = str(test_case[&"label"])
		var cell: Vector2i = _find_walkable_surface_cell(
			map,
			world,
			test_case[&"seed"] as Vector2i,
			surface,
		)
		_add(cases, "gameplay finds %s audio cell" % label, cell != MISSING_CELL)
		if cell == MISSING_CELL:
			continue
		_add(
			cases,
			"gameplay enters %s audio region" % label,
			bool(map.call("place_robot", cell)),
		)
		await tree.process_frame
		await tree.process_frame
		var metrics: Dictionary = router.call("get_metrics") as Dictionary
		var music_metrics: Dictionary = metrics[&"music"] as Dictionary
		var ambience_metrics: Dictionary = metrics[&"soundscape"] as Dictionary
		_add(
			cases,
			"%s gameplay selects matching BGM and ambience" % label,
			(
				music_metrics[&"biome"] == BiomeMusicScript.normalize_biome(surface)
				and music_metrics[&"stream_path"] == BiomeMusicScript.stream_path_for(surface)
				and ambience_metrics[&"biome"]
				== BiomeSoundscapeScript.normalize_biome(surface)
			),
		)
		if index > 0:
			_add(
				cases,
				"%s border starts dynamic audio crossfades" % label,
				bool(music_metrics[&"crossfading"])
				and bool(ambience_metrics[&"crossfading"]),
			)
		music.call("_process", BiomeMusicScript.CROSSFADE_SECONDS)
		soundscape.call("_process", BiomeSoundscapeScript.CROSSFADE_SECONDS)
		metrics = router.call("get_metrics") as Dictionary
		music_metrics = metrics[&"music"] as Dictionary
		ambience_metrics = metrics[&"soundscape"] as Dictionary
		_add(
			cases,
			"%s gameplay audio crossfade completes" % label,
			(
				not bool(music_metrics[&"crossfading"])
				and not bool(ambience_metrics[&"crossfading"])
				and music_metrics[&"stream_path"] == BiomeMusicScript.stream_path_for(surface)
			),
		)
	var safe_cell: Vector2i = _find_walkable_surface_cell(
		map,
		world,
		Vector2i(8, 8),
		&"sand",
	)
	if safe_cell != MISSING_CELL:
		map.call("place_robot", safe_cell)
		map.call("_process", 0.0)
		await tree.process_frame
	return cases


static func _find_walkable_surface_cell(
	map: Node,
	world: RefCounted,
	seed: Vector2i,
	surface: StringName,
) -> Vector2i:
	for radius: int in range(9):
		for y: int in range(seed.y - radius, seed.y + radius + 1):
			for x: int in range(seed.x - radius, seed.x + radius + 1):
				if radius > 0 and maxi(absi(x - seed.x), absi(y - seed.y)) != radius:
					continue
				var cell: Vector2i = Vector2i(x, y)
				var terrain: StringName = world.call("terrain_at", cell) as StringName
				if (
					BiomeMusicScript.normalize_biome(terrain)
					== BiomeMusicScript.normalize_biome(surface)
					and bool(map.call("is_walkable", cell))
				):
					return cell
	return MISSING_CELL


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
