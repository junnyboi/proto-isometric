extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const IsometricControlsScript: GDScript = preload("res://scripts/isometric_controls.gd")
const RAM_CHARGE_THRESHOLD: float = 0.8
const AFTERSHOCK_STAGGER_SECONDS: float = 1.4
const STORM_SEAL_DAMAGE_MULTIPLIER: float = 0.5


static func has_module(coordinator: RefCounted, module_id: StringName) -> bool:
	return coordinator != null and bool(coordinator.call("_has_run_module", module_id))


static func can_ram(coordinator: RefCounted, running: bool, charge: float) -> bool:
	return (
		running
		and charge >= RAM_CHARGE_THRESHOLD
		and has_module(coordinator, RuntimeIdsScript.MODULE_RAM_PLATING)
	)


static func aftershock_stagger(coordinator: RefCounted) -> float:
	return (
		AFTERSHOCK_STAGGER_SECONDS
		if has_module(coordinator, RuntimeIdsScript.MODULE_AFTERSHOCK)
		else 0.0
	)


static func mitigate_damage(
	coordinator: RefCounted,
	amount: int,
	source: StringName,
	running: bool,
) -> int:
	var damage: int = maxi(amount, 0)
	if (
		running
		and source in [&"tornado", &"sandstorm"]
		and has_module(coordinator, RuntimeIdsScript.MODULE_STORM_SEAL)
	):
		damage = maxi(ceili(float(damage) * STORM_SEAL_DAMAGE_MULTIPLIER), 1)
	return damage


static func try_ram(map: Node, screen_direction: Vector2i) -> bool:
	var impact: Node2D = map.get("_impact_charge") as Node2D
	var coordinator: RefCounted = map.get("_run_coordinator") as RefCounted
	if (
		impact == null
		or not can_ram(coordinator, map.get("_is_running"), impact.call("get_charge"))
	):
		return false
	var origin: Vector2i = map.get("_robot_grid") as Vector2i
	var delta: Vector2i = IsometricControlsScript.screen_to_grid_delta(screen_direction)
	var target: Vector2i = origin + delta
	var rocks: Dictionary = map.get("_destructible_rocks") as Dictionary
	if not bool(rocks.get(target, false)) or not _ram_corners_clear(map, origin, delta):
		return false
	impact.call("consume_attack")
	if not bool(map.call("_break_rock", target)):
		return false
	var effects: Node2D = map.get("_effects") as Node2D
	effects.call("emit_rock_impact", map.call("grid_to_screen", target), target)
	map.call("_save_world_state")
	map.call("_update_status", &"status.ram_breached")
	return true


static func _ram_corners_clear(map: Node, origin: Vector2i, delta: Vector2i) -> bool:
	if delta.x == 0 or delta.y == 0:
		return true
	return (
		bool(map.call("is_walkable", origin + Vector2i(delta.x, 0)))
		and bool(map.call("is_walkable", origin + Vector2i(0, delta.y)))
	)
