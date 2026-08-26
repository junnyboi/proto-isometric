extends RefCounted

const CalendarScript: GDScript = preload("res://scripts/calendar_state.gd")
const CatalogScript: GDScript = preload("res://scripts/resource_deposit_catalog.gd")
const GatheringScript: GDScript = preload("res://scripts/gathering_state_service.gd")
const InventoryScript: GDScript = preload("res://scripts/inventory_service.gd")
const ToolScript: GDScript = preload("res://scripts/tool_service.gd")

const OPERATION: StringName = &"deposit_gather"
const ARGUMENT_KEYS: Array[StringName] = [
	&"source_id", &"cell", &"expected_remaining", &"absolute_day", &"actor_kind", &"actor_id",
]


static func build(
	envelope: Dictionary,
	arguments: Dictionary,
	_world_seed: int,
	world_validator: RefCounted,
) -> Dictionary:
	if not _exact_keys(arguments, ARGUMENT_KEYS) or world_validator == null:
		return _failure(envelope, &"invalid_deposit_arguments")
	var cell: Variant = arguments[&"cell"]
	if not cell is Vector2i:
		return _failure(envelope, &"invalid_deposit_cell")
	var source: Dictionary = world_validator.call("_resource_source_at", cell) as Dictionary
	if source.is_empty() or str(source[&"source_id"]) != str(arguments[&"source_id"]):
		return _failure(envelope, &"stale_deposit_identity")
	var farm: Dictionary = envelope[&"farm"] as Dictionary
	var day: int = CalendarScript.absolute_day(farm[&"calendar_weather"])
	if day != int(arguments[&"absolute_day"]):
		return _failure(envelope, &"stale_deposit_day")
	var current: Dictionary = GatheringScript.effective(farm, source, day)
	if current.is_empty() or int(current[&"remaining_charges"]) != int(
		arguments[&"expected_remaining"]
	):
		return _failure(envelope, &"stale_deposit_state")
	var actor_kind: StringName = StringName(str(arguments[&"actor_kind"]))
	if actor_kind != &"manual":
		return _failure(envelope, &"unsupported_deposit_actor")
	var tool_id: StringName = source[&"required_tool"] as StringName
	var stamina_cost: int = ToolScript.stamina_cost(farm, tool_id)
	if not ToolScript.can_spend(farm, tool_id):
		return _failure(envelope, &"tool_unavailable")
	var spent: Dictionary = ToolScript.spend(farm, tool_id)
	if not bool(spent[&"ok"]):
		return _failure(envelope, spent[&"reason"] as StringName)
	var gathered: Dictionary = GatheringScript.gather(
		spent[&"candidate"], source, day, actor_kind, str(arguments[&"actor_id"])
	)
	if not bool(gathered[&"ok"]):
		return _failure(envelope, gathered[&"reason"] as StringName)
	var credited: Dictionary = InventoryScript.credit_with_overflow(
		gathered[&"candidate"],
		source[&"reward_item_id"] as StringName,
		int(source[&"reward_count"]),
	)
	if not bool(credited[&"ok"]):
		return _failure(envelope, credited[&"reason"] as StringName)
	var candidate: Dictionary = envelope.duplicate(true)
	candidate[&"farm"] = credited[&"candidate"]
	return {
		&"ok": true,
		&"candidate": candidate,
		&"reason": &"gathered",
		&"dirty_cells": [cell],
		&"source_id": str(source[&"source_id"]),
		&"remaining_charges": int((gathered[&"source_state"] as Dictionary)[&"remaining_charges"]),
		&"item_id": str(source[&"reward_item_id"]),
		&"item_count": int(source[&"reward_count"]),
		&"stamina_cost": stamina_cost,
	}


static func _failure(envelope: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": false, &"candidate": envelope.duplicate(true), &"reason": reason}


static func _exact_keys(value: Dictionary, expected: Array[StringName]) -> bool:
	if value.size() != expected.size():
		return false
	for key: StringName in expected:
		if not value.has(key):
			return false
	return true
