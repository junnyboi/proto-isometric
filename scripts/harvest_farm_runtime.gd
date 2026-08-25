extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const DayAdvanceServiceScript: GDScript = preload("res://scripts/day_advance_service.gd")
const EconomyServiceScript: GDScript = preload("res://scripts/economy_service.gd")
const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const LivestockServiceScript: GDScript = preload("res://scripts/livestock_service.gd")
const MachineServiceScript: GDScript = preload("res://scripts/machine_service.gd")
const RelationshipServiceScript: GDScript = preload("res://scripts/relationship_service.gd")
const ResidentServiceScript: GDScript = preload("res://scripts/resident_service.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")

var _farm: Dictionary = {}
var _commit_candidate: Callable
var _world_seed: int = CalendarStateScript.DEFAULT_WORLD_SEED
var _last_error: StringName = &""


func configure(farm: Dictionary, commit_candidate: Callable, world_seed: int = 0) -> bool:
	if not commit_candidate.is_valid():
		return false
	_commit_candidate = commit_candidate
	_world_seed = world_seed if world_seed != 0 else CalendarStateScript.DEFAULT_WORLD_SEED
	var initialized: Dictionary = InventoryServiceScript.ensure_default(farm)
	initialized = CalendarStateScript.ensure_default(initialized, _world_seed)
	initialized = ToolServiceScript.ensure_default(initialized)
	initialized = EconomyServiceScript.ensure_default(initialized)
	initialized = MachineServiceScript.ensure_default(initialized)
	initialized = HomesteadServiceScript.ensure_default(initialized)
	initialized = ResidentServiceScript.ensure_default(initialized)
	initialized = RelationshipServiceScript.ensure_default(initialized)
	initialized = LivestockServiceScript.ensure_default(initialized)
	var reconciled: Dictionary = HomesteadServiceScript.reconcile(initialized)
	if not bool(reconciled[&"ok"]):
		return false
	initialized = reconciled[&"candidate"] as Dictionary
	var arrivals: Dictionary = ResidentServiceScript.reconcile_arrivals(initialized)
	initialized = arrivals[&"candidate"] as Dictionary
	var normalized: Dictionary = FarmSaveSchemaScript.validate(initialized)
	if normalized.is_empty():
		return false
	_farm = normalized
	return true


func get_snapshot() -> Dictionary:
	return _farm.duplicate(true)


func get_render_indexes() -> Dictionary:
	return FarmStateScript.build_chunk_indexes(_farm)


func get_last_error() -> StringName:
	return _last_error


func preview(operation: StringName, arguments: Dictionary = {}) -> Dictionary:
	var before: Dictionary = _farm.duplicate(true)
	var result: Dictionary = _build_operation(operation, arguments)
	result[&"preview"] = true
	result[&"source_unchanged"] = _farm == before
	return result


func transact(operation: StringName, arguments: Dictionary = {}) -> Dictionary:
	var source: Dictionary = _farm.duplicate(true)
	var result: Dictionary = _build_operation(operation, arguments)
	if not bool(result.get(&"ok", false)):
		_last_error = result.get(&"reason", &"rejected") as StringName
		return result
	var candidate: Dictionary = FarmSaveSchemaScript.validate(result[&"candidate"])
	if candidate.is_empty():
		_last_error = &"invalid_candidate"
		return {&"ok": false, &"candidate": source, &"reason": _last_error}
	if not bool(_commit_candidate.call(candidate)):
		_last_error = &"persistence_failed"
		return {&"ok": false, &"candidate": source, &"reason": _last_error}
	_farm = candidate
	_last_error = &""
	result[&"candidate"] = _farm.duplicate(true)
	return result


func _build_operation(operation: StringName, arguments: Dictionary) -> Dictionary:
	var result: Dictionary = {
		&"ok": false, &"candidate": _farm.duplicate(true), &"reason": &"unknown_operation"
	}
	match operation:
		&"till":
			result = FarmStateScript.till(_farm, arguments[&"cell"] as Vector2i)
		&"water":
			result = (
				FarmStateScript
				. water(
					_farm,
					arguments[&"cell"] as Vector2i,
					CalendarStateScript.absolute_day(_farm[&"calendar_weather"]),
				)
			)
		&"plant":
			result = (
				FarmStateScript
				. plant(
					_farm,
					arguments[&"cell"] as Vector2i,
					arguments.get(&"seed_item_id", &"item.seed.glowroot") as StringName,
					CalendarStateScript.absolute_day(_farm[&"calendar_weather"]),
				)
			)
		&"harvest":
			result = FarmStateScript.harvest(_farm, arguments[&"cell"] as Vector2i)
		&"transfer":
			result = (
				InventoryServiceScript
				. transfer(
					_farm,
					arguments[&"source_id"] as StringName,
					arguments[&"destination_id"] as StringName,
					arguments[&"item_id"] as StringName,
					int(arguments[&"count"]),
				)
			)
		&"ship":
			result = EconomyServiceScript.ship(
				_farm, arguments[&"item_id"] as StringName, int(arguments[&"count"])
			)
		&"buy_seed":
			result = EconomyServiceScript.buy_seed(
				_farm, arguments[&"item_id"] as StringName, int(arguments[&"count"])
			)
		&"upgrade":
			result = EconomyServiceScript.purchase_workshop_upgrade(_farm)
		&"sleep":
			result = DayAdvanceServiceScript.build_candidate(_farm, _world_seed)
		&"facility_repair":
			result = HomesteadServiceScript.repair(
				_farm, arguments.get(&"facility_id", &"") as StringName
			)
		&"facility_power":
			result = HomesteadServiceScript.power(
				_farm, arguments.get(&"facility_id", &"") as StringName
			)
		&"talk":
			result = RelationshipServiceScript.talk(
				_farm, arguments.get(&"resident_id", &"") as StringName
			)
		&"gift":
			result = RelationshipServiceScript.gift(
				_farm,
				arguments.get(&"resident_id", &"") as StringName,
				arguments.get(&"item_id", &"") as StringName,
			)
		&"request", &"request_complete":
			result = RelationshipServiceScript.complete_request(
				_farm, arguments.get(&"request_id", &"") as StringName
			)
		&"animal_add":
			result = LivestockServiceScript.add_animal(
				_farm,
				arguments.get(&"animal_id", &"") as StringName,
				arguments.get(&"species_id", &"") as StringName,
				arguments.get(&"housing_id", &"") as StringName,
			)
		&"animal_feed":
			result = LivestockServiceScript.feed(
				_farm, arguments.get(&"animal_id", &"") as StringName
			)
		&"animal_pet":
			result = LivestockServiceScript.pet(
				_farm, arguments.get(&"animal_id", &"") as StringName
			)
		&"animal_product":
			result = LivestockServiceScript.claim_product(
				_farm, arguments.get(&"animal_id", &"") as StringName
			)
	return result
