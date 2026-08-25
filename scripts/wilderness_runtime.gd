extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const EcologyDirectorScript: GDScript = preload("res://scripts/ecology_director.gd")

var _sandworms: Node2D
var _farm_runtime: RefCounted
var _world_seed: int = 0
var _active_habitat_ids: Array[StringName] = []
var _last_biome: StringName = &""


func configure(sandworms: Node2D, farm_runtime: RefCounted, world_seed: int) -> bool:
	if sandworms == null or farm_runtime == null:
		return false
	_sandworms = sandworms
	_farm_runtime = farm_runtime
	_world_seed = world_seed
	_sandworms.call("set_auto_spawn", false)
	var herds: Node2D = _sandworms.call("_get_peaceful_herds") as Node2D
	if herds != null:
		herds.call("set_auto_spawn", false)
	return true


func sync(player_cell: Vector2i, biome: StringName) -> void:
	if _sandworms == null or _farm_runtime == null:
		return
	if biome != _last_biome:
		_sandworms.call("clear_worms")
		var old_herds: Node2D = _sandworms.call("_get_peaceful_herds") as Node2D
		if old_herds != null:
			old_herds.call("clear")
		_active_habitat_ids.clear()
		_last_biome = biome
	var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
	var calendar: Dictionary = farm.get(&"calendar_weather", {}) as Dictionary
	var absolute_day: int = CalendarStateScript.absolute_day(calendar)
	var minute: int = int(calendar.get(&"minute_of_day", 0))
	for habitat: Dictionary in EcologyDirectorScript.population_snapshot(
		farm, _world_seed, absolute_day, minute
	):
		if habitat[&"biome"] != biome or not bool(habitat[&"active"]):
			continue
		var habitat_id: StringName = habitat[&"habitat_id"] as StringName
		var anchor: Vector2i = habitat[&"anchor"] as Vector2i
		if player_cell.distance_to(anchor) > float(int(habitat[&"leash"]) + 8):
			continue
		if habitat_id in _active_habitat_ids:
			continue
		_materialize(habitat)
		_active_habitat_ids.append(habitat_id)
	_active_habitat_ids.sort_custom(
		func(a: StringName, b: StringName) -> bool: return String(a) < String(b)
	)


func get_active_habitats() -> Array[StringName]:
	return _active_habitat_ids.duplicate()


func _materialize(habitat: Dictionary) -> void:
	var anchor: Vector2 = Vector2(habitat[&"anchor"] as Vector2i)
	var population: int = int(habitat[&"population"])
	match habitat[&"category"] as StringName:
		EcologyDirectorScript.LARGE:
			_sandworms.call("spawn_worm", anchor, 0.35)
		EcologyDirectorScript.NEST:
			_sandworms.call("_spawn_melee_pack", anchor, population)
		EcologyDirectorScript.HERD:
			var herds: Node2D = _sandworms.call("_get_peaceful_herds") as Node2D
			if herds != null:
				herds.call("spawn_herd", anchor, population, habitat[&"biome"] as StringName)
