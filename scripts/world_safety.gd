extends RefCounted

const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")


static func is_home_safe(position: Vector2) -> bool:
	return position.distance_to(Vector2(WoodlandClearingScript.CENTER)) <= (
		WoodlandClearingScript.BUFFER_RADIUS
	)


static func is_home_inner(position: Vector2) -> bool:
	return position.distance_to(Vector2(WoodlandClearingScript.CENTER)) <= (
		WoodlandClearingScript.INNER_RADIUS
	)


static func is_safe(position: Vector2, world: RefCounted = null) -> bool:
	var home_enabled: bool = false
	if world != null and world.has_method("_is_home_safe"):
		home_enabled = bool(world.call("_is_home_safe", position))
	if home_enabled and is_home_safe(position):
		return true
	return (
		world != null
		and world.has_method("_is_remote_sanctuary")
		and bool(world.call("_is_remote_sanctuary", position))
	)


static func allows_spawn(position: Vector2, world: RefCounted = null) -> bool:
	return not is_safe(position, world)


static func allows_pursuit(target: Vector2, world: RefCounted = null) -> bool:
	return not is_safe(target, world)


static func allows_projectile_target(target: Vector2, world: RefCounted = null) -> bool:
	return not is_safe(target, world)


static func allows_deep_event(cell: Vector2i, world: RefCounted = null) -> bool:
	return not is_safe(Vector2(cell), world)


static func allows_weather_damage(position: Vector2, world: RefCounted = null) -> bool:
	return not is_safe(position, world)


static func allows_hazard_damage(position: Vector2, world: RefCounted = null) -> bool:
	return not is_safe(position, world)


static func allows_lava_damage(position: Vector2, world: RefCounted = null) -> bool:
	return not is_safe(position, world)


static func allows_damage(position: Vector2, world: RefCounted = null) -> bool:
	return not is_safe(position, world)
