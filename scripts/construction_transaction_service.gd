extends RefCounted

const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const LedgerScript: GDScript = preload("res://scripts/world_mutation_ledger.gd")
const LinksScript: GDScript = preload("res://scripts/construction_envelope_links.gd")
const PlacementScript: GDScript = preload("res://scripts/placement_validator.gd")
const StateScript: GDScript = preload("res://scripts/construction_state_service.gd")

const OPERATIONS: Array[StringName] = [
	&"construction_place",
	&"construction_complete",
	&"construction_move",
	&"construction_upgrade",
	&"construction_demolish",
]


static func build(
	source: Dictionary,
	operation: StringName,
	arguments: Dictionary,
	world_runtime: RefCounted,
) -> Dictionary:
	if operation not in OPERATIONS:
		return _result(false, source, &"unknown_construction_operation")
	var source_farm: Dictionary = source.get(&"farm", {}) as Dictionary
	if not _revision_matches(source_farm, arguments):
		return _result(false, source, &"stale_construction_revision")
	match operation:
		&"construction_place":
			return _place(source, arguments, world_runtime)
		&"construction_complete":
			return _farm_only(source, StateScript.complete(
				source_farm, arguments.get(&"instance_id", &"") as StringName
			))
		&"construction_move":
			return _move(source, arguments, world_runtime)
		&"construction_upgrade":
			return _farm_only(source, StateScript.upgrade(
				source_farm, arguments.get(&"instance_id", &"") as StringName
			))
		&"construction_demolish":
			return _demolish(source, arguments)
	return _result(false, source, &"unknown_construction_operation")


static func _place(
	source: Dictionary, arguments: Dictionary, world_runtime: RefCounted
) -> Dictionary:
	var farm: Dictionary = source[&"farm"] as Dictionary
	var blueprint_id: StringName = arguments.get(&"blueprint_id", &"") as StringName
	var instance_id: StringName = arguments.get(&"instance_id", &"") as StringName
	var anchor: Variant = arguments.get(&"anchor")
	var orientation: int = int(arguments.get(&"orientation", -1))
	var actors: Array[Vector2i] = _actor_cells(arguments)
	if not anchor is Vector2i or actors.is_empty():
		return _result(false, source, &"invalid_construction_anchor")
	var preview: Dictionary = PlacementScript.evaluate(
		farm,
		world_runtime,
		blueprint_id,
		anchor as Vector2i,
		orientation,
		&"",
		actors,
	)
	if not bool(preview[&"ok"]):
		return _result(false, source, preview[&"reason"] as StringName)
	var changed: Dictionary = StateScript.place(
		farm, blueprint_id, instance_id, anchor as Vector2i, orientation
	)
	if not bool(changed[&"ok"]):
		return _result(false, source, changed[&"reason"] as StringName)
	var building: Dictionary = StateScript.building(changed[&"candidate"], instance_id)
	var ledger_record: Dictionary = LinksScript.ledger_record(building)
	return _with_ledger(source, changed[&"candidate"], &"place", &"", ledger_record)


static func _move(
	source: Dictionary, arguments: Dictionary, world_runtime: RefCounted
) -> Dictionary:
	var farm: Dictionary = source[&"farm"] as Dictionary
	var instance_id: StringName = arguments.get(&"instance_id", &"") as StringName
	var before: Dictionary = StateScript.building(farm, instance_id)
	var anchor: Variant = arguments.get(&"anchor")
	var orientation: int = int(arguments.get(&"orientation", -1))
	var actors: Array[Vector2i] = _actor_cells(arguments)
	if before.is_empty() or not anchor is Vector2i or actors.is_empty():
		return _result(false, source, &"building_missing")
	var blueprint_id: StringName = StringName(str(before[&"blueprint_id"]))
	var preview: Dictionary = PlacementScript.evaluate(
		farm,
		world_runtime,
		blueprint_id,
		anchor as Vector2i,
		orientation,
		instance_id,
		actors,
	)
	if not bool(preview[&"ok"]):
		return _result(false, source, preview[&"reason"] as StringName)
	var changed: Dictionary = StateScript.relocate(
		farm, instance_id, anchor as Vector2i, orientation
	)
	if not bool(changed[&"ok"]):
		return _result(false, source, changed[&"reason"] as StringName)
	var after: Dictionary = StateScript.building(changed[&"candidate"], instance_id)
	return _with_ledger(
		source,
		changed[&"candidate"],
		&"replace",
		StringName(str(LinksScript.ledger_record(before)[&"stable_id"])),
		LinksScript.ledger_record(after),
	)


static func _demolish(source: Dictionary, arguments: Dictionary) -> Dictionary:
	var farm: Dictionary = source[&"farm"] as Dictionary
	var instance_id: StringName = arguments.get(&"instance_id", &"") as StringName
	var before: Dictionary = StateScript.building(farm, instance_id)
	if before.is_empty():
		return _result(false, source, &"building_missing")
	var changed: Dictionary = StateScript.demolish(farm, instance_id)
	if not bool(changed[&"ok"]):
		return _result(false, source, changed[&"reason"] as StringName)
	var record: Dictionary = LinksScript.ledger_record(before)
	return _with_ledger(
		source,
		changed[&"candidate"],
		&"remove",
		StringName(str(record[&"stable_id"])),
		{},
	)


static func _farm_only(source: Dictionary, changed: Dictionary) -> Dictionary:
	if not bool(changed.get(&"ok", false)):
		return _result(false, source, changed.get(&"reason", &"rejected") as StringName)
	var candidate: Dictionary = source.duplicate(true)
	candidate[&"farm"] = FarmSchemaScript.validate(changed[&"candidate"])
	if (candidate[&"farm"] as Dictionary).is_empty() or not LinksScript.validate(candidate):
		return _result(false, source, &"invalid_construction_candidate")
	return _result(true, candidate, &"")


static func _with_ledger(
	source: Dictionary,
	farm_candidate: Dictionary,
	mode: StringName,
	old_stable_id: StringName,
	record: Dictionary,
) -> Dictionary:
	var candidate: Dictionary = source.duplicate(true)
	var world: Dictionary = candidate[&"world"] as Dictionary
	var ledger: Dictionary = (
		LedgerScript.validate(world[&"mutation_ledger"])
		if world.has(&"mutation_ledger")
		else LedgerScript.from_legacy(world)
	)
	var changed: Dictionary = {}
	match mode:
		&"place":
			changed = LedgerScript.place(ledger, record)
		&"replace":
			changed = LedgerScript.replace_placed(ledger, old_stable_id, record)
		&"remove":
			changed = LedgerScript.remove_placed(ledger, old_stable_id)
	if not bool(changed.get(&"ok", false)):
		return _result(false, source, changed.get(&"reason", &"ledger_rejected") as StringName)
	var adapted: Dictionary = LedgerScript.legacy_arrays_exact(world, changed[&"candidate"])
	if adapted.is_empty():
		return _result(false, source, &"ledger_projection_failed")
	adapted[&"mutation_ledger"] = (changed[&"candidate"] as Dictionary).duplicate(true)
	candidate[&"world"] = adapted
	candidate[&"farm"] = FarmSchemaScript.validate(farm_candidate)
	if (candidate[&"farm"] as Dictionary).is_empty() or not LinksScript.validate(candidate):
		return _result(false, source, &"construction_bijection_failed")
	return _result(true, candidate, &"")


static func _revision_matches(farm: Dictionary, arguments: Dictionary) -> bool:
	var revisions: Dictionary = farm.get(&"revisions", {}) as Dictionary
	return (
		arguments.get(&"source_revision") is int
		and int(arguments[&"source_revision"]) == int(revisions.get(&"result_revision", -1))
	)


static func _actor_cells(arguments: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var value: Variant = arguments.get(&"actor_cells", [])
	if not value is Array or (value as Array).size() > 32:
		return result
	for cell: Variant in value as Array:
		if cell is Vector2i and cell not in result:
			result.append(cell as Vector2i)
	return result


static func _result(ok: bool, candidate: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": candidate.duplicate(true), &"reason": reason}
