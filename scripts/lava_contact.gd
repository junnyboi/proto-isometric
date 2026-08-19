extends RefCounted

const LavaFieldsScript: GDScript = preload("res://scripts/lava_fields.gd")

var _world: RefCounted
var _touching_lava: bool = false
var _tick_remaining: float = 0.0


func configure(world: RefCounted) -> bool:
	_world = world
	reset()
	return _world != null


func advance(position: Vector2, delta: float, shutdown: bool = false) -> int:
	if shutdown or _world == null:
		reset()
		return 0
	var cell: Vector2i = Vector2i(position.round())
	if _world.call("terrain_at", cell) != &"lava":
		reset()
		return 0
	if not _touching_lava:
		_touching_lava = true
		_tick_remaining = LavaFieldsScript.LAVA_TICK_SECONDS
		return LavaFieldsScript.LAVA_DAMAGE
	_tick_remaining -= maxf(delta, 0.0)
	var damage: int = 0
	var tick_limit: int = 4
	while _tick_remaining <= 0.000001 and tick_limit > 0:
		damage += LavaFieldsScript.LAVA_DAMAGE
		_tick_remaining += LavaFieldsScript.LAVA_TICK_SECONDS
		tick_limit -= 1
	if tick_limit == 0 and _tick_remaining <= 0.0:
		_tick_remaining = LavaFieldsScript.LAVA_TICK_SECONDS
	return damage


func reset() -> void:
	_touching_lava = false
	_tick_remaining = 0.0
