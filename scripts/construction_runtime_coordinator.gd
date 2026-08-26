extends RefCounted

signal construction_committed(operation: StringName, result: Dictionary)

const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const LinksScript: GDScript = preload("res://scripts/construction_envelope_links.gd")
const OccupancyScript: GDScript = preload("res://scripts/building_occupancy_index.gd")
const PlacementScript: GDScript = preload("res://scripts/placement_validator.gd")
const StateScript: GDScript = preload("res://scripts/construction_state_service.gd")

var _map: Node2D
var _farm_runtime: RefCounted
var _transactions: RefCounted


func configure(map: Node2D, farm_runtime: RefCounted, transactions: RefCounted) -> bool:
	if map == null or farm_runtime == null or transactions == null:
		return false
	_map = map
	_farm_runtime = farm_runtime
	_transactions = transactions
	return true


func preview(
	blueprint_id: StringName,
	anchor: Vector2i,
	orientation: int,
	exempt_instance: StringName = &"",
) -> Dictionary:
	return PlacementScript.evaluate(
		_farm(),
		_world(),
		blueprint_id,
		anchor,
		orientation,
		exempt_instance,
		_actor_cells(),
	)


func find_initial(blueprint_id: StringName) -> Dictionary:
	return PlacementScript.find_nearby(
		_farm(), _world(), blueprint_id, _player_cell(), _actor_cells()
	)


func building_at(cell: Vector2i) -> Dictionary:
	return OccupancyScript.building_at(OccupancyScript.build(_farm()), cell)


func building(instance_id: StringName) -> Dictionary:
	return StateScript.building(_farm(), instance_id)


func place(blueprint_id: StringName, anchor: Vector2i, orientation: int) -> Dictionary:
	var farm: Dictionary = _farm()
	var revision: int = _revision(farm)
	var instance_id: StringName = StateScript.next_instance_id(farm, blueprint_id)
	var payload: Dictionary = {
		&"operation": "place",
		&"blueprint_id": str(blueprint_id),
		&"instance_id": str(instance_id),
		&"anchor": [anchor.x, anchor.y],
		&"orientation": orientation,
		&"source_revision": revision,
	}
	var arguments: Dictionary = {
		&"blueprint_id": blueprint_id,
		&"instance_id": instance_id,
		&"anchor": anchor,
		&"orientation": orientation,
		&"source_revision": revision,
		&"actor_cells": _actor_cells(),
	}
	return _transact_exact(&"construction_place", arguments, payload, instance_id, [])


func move(instance_id: StringName, anchor: Vector2i, orientation: int) -> Dictionary:
	var before: Dictionary = building(instance_id)
	if before.is_empty():
		return _failure(&"building_missing")
	var revision: int = _revision(_farm())
	var payload: Dictionary = {
		&"operation": "move",
		&"instance_id": str(instance_id),
		&"anchor": [anchor.x, anchor.y],
		&"orientation": orientation,
		&"source_revision": revision,
	}
	var arguments: Dictionary = {
		&"instance_id": instance_id,
		&"anchor": anchor,
		&"orientation": orientation,
		&"source_revision": revision,
		&"actor_cells": _actor_cells(),
	}
	return _transact_exact(
		&"construction_move", arguments, payload, instance_id, _encoded_cells(before)
	)


func upgrade(instance_id: StringName) -> Dictionary:
	var revision: int = _revision(_farm())
	var payload: Dictionary = {
		&"operation": "upgrade",
		&"instance_id": str(instance_id),
		&"source_revision": revision,
	}
	var arguments: Dictionary = {
		&"instance_id": instance_id,
		&"source_revision": revision,
	}
	return _transact_exact(&"construction_upgrade", arguments, payload, instance_id, [])


func demolish(instance_id: StringName) -> Dictionary:
	var before: Dictionary = building(instance_id)
	if before.is_empty():
		return _failure(&"building_missing")
	var revision: int = _revision(_farm())
	var payload: Dictionary = {
		&"operation": "demolish",
		&"instance_id": str(instance_id),
		&"source_revision": revision,
	}
	var arguments: Dictionary = {
		&"instance_id": instance_id,
		&"source_revision": revision,
	}
	return _transact_exact(
		&"construction_demolish", arguments, payload, instance_id, _encoded_cells(before)
	)


func _transact_exact(
	operation: StringName,
	arguments: Dictionary,
	payload: Dictionary,
	instance_id: StringName,
	before_cells: Array[Vector2i],
) -> Dictionary:
	var digest: String = CodecScript.digest(payload)
	if digest.is_empty():
		return _failure(&"invalid_construction_payload")
	var token: String = "construction:%s:%s" % [
		String(operation).trim_prefix("construction_"), digest.left(32)
	]
	var deterministic: Dictionary = {
		&"status": "committed",
		&"operation": str(operation),
		&"instance_id": str(instance_id),
		&"source_revision": int(payload[&"source_revision"]),
	}
	var result: Dictionary = _transactions.call(
		"transact_exact_once", operation, arguments, token, payload, deterministic
	) as Dictionary
	if not _sync_farm(result):
		return _failure(result.get(&"reason", &"live_farm_sync_failed") as StringName)
	if not bool(result.get(&"ok", false)):
		return result
	var after: Dictionary = building(instance_id)
	var affected: Array[Vector2i] = before_cells.duplicate()
	for cell: Vector2i in LinksScript.changed_cells({}, after):
		if cell not in affected:
			affected.append(cell)
	affected.sort_custom(_cell_precedes)
	result[&"dirty_cells"] = affected
	result[&"instance_id"] = instance_id
	if not bool(result.get(&"replayed", false)):
		construction_committed.emit(operation, result.duplicate(true))
	return result


func _sync_farm(result: Dictionary) -> bool:
	var envelope: Dictionary = result.get(&"candidate", {}) as Dictionary
	if envelope.is_empty() or not envelope.get(&"farm", {}) is Dictionary:
		return false
	return bool(_farm_runtime.call("sync_committed", envelope[&"farm"]))


func _farm() -> Dictionary:
	return _farm_runtime.call("get_snapshot") as Dictionary


func _world() -> RefCounted:
	return _map.get("_world") as RefCounted


func _player_cell() -> Vector2i:
	return _map.call("get_robot_grid") as Vector2i


func _actor_cells() -> Array[Vector2i]:
	return [_player_cell()]


func _revision(farm: Dictionary) -> int:
	return int((farm[&"revisions"] as Dictionary)[&"result_revision"])


func _encoded_cells(building_value: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for encoded: Array in building_value.get(&"footprint", []) as Array[Array]:
		result.append(Vector2i(int(encoded[0]), int(encoded[1])))
	return result


func _failure(reason: StringName) -> Dictionary:
	return {&"ok": false, &"reason": reason, &"candidate": {}}


func _cell_precedes(first: Vector2i, second: Vector2i) -> bool:
	return first.y < second.y or (first.y == second.y and first.x < second.x)
