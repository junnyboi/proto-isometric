extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const LegacyRecipeAdapterScript: GDScript = preload(
	"res://scripts/legacy_machine_recipe_adapter.gd"
)
const RecipeCatalogScript: GDScript = preload("res://scripts/recipe_catalog.gd")

const STATE_IDLE: StringName = &"machine.idle"
const STATE_RUNNING: StringName = &"machine.running"
const STATE_COMPLETE: StringName = &"machine.complete"
const WORKBENCH_ID: StringName = &"machine.home.workbench"
const FURNACE_ID: StringName = &"machine.home.furnace"


static func ensure_default(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	if not (candidate.get(&"machines", []) as Array).is_empty():
		return candidate
	candidate[&"machines"] = [
		_make_machine(WORKBENCH_ID, RecipeCatalogScript.STATION_WORKBENCH, Vector2i(9, 7)),
	]
	return candidate


static func install_furnace(farm: Dictionary) -> Dictionary:
	if _machine_index(farm, FURNACE_ID) >= 0:
		return _result(false, farm, &"furnace_already_installed")
	var candidate: Dictionary = farm.duplicate(true)
	var machines: Array = (candidate.get(&"machines", []) as Array).duplicate(true)
	machines.append(_make_machine(FURNACE_ID, RecipeCatalogScript.STATION_FURNACE, Vector2i(6, 7)))
	machines.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"machine_id"]) < str(b[&"machine_id"])
	)
	candidate[&"machines"] = machines
	return _result(true, candidate, &"")


static func start(farm: Dictionary, machine_id: StringName, recipe_id: StringName) -> Dictionary:
	var index: int = _machine_index(farm, machine_id)
	var recipe: Dictionary = RecipeCatalogScript.definition(recipe_id)
	if index < 0 or recipe.is_empty():
		return _result(false, farm, &"unknown_machine_or_recipe")
	var machine: Dictionary = (farm[&"machines"] as Array)[index] as Dictionary
	if StringName(machine[&"state"]) != STATE_IDLE:
		return _result(false, farm, &"machine_busy")
	if machine[&"station_tag"] != recipe[&"station_tag"]:
		return _result(false, farm, &"station_mismatch")
	var candidate: Dictionary = farm.duplicate(true)
	for raw_ingredient: Variant in LegacyRecipeAdapterScript.ingredients(recipe):
		var ingredient: Dictionary = raw_ingredient as Dictionary
		var removed: Dictionary = InventoryServiceScript.remove_across(
			candidate,
			StringName(str(ingredient[&"item_id"])),
			int(ingredient[&"count"]),
		)
		if not bool(removed[&"ok"]):
			return _result(false, farm, &"missing_ingredients")
		candidate = removed[&"candidate"] as Dictionary
	var machines: Array = (candidate[&"machines"] as Array).duplicate(true)
	machine = (machines[index] as Dictionary).duplicate(true)
	var start_day: int = CalendarStateScript.absolute_day(candidate[&"calendar_weather"])
	var operation_token: String = "%s:%d:%s" % [String(machine_id), start_day, String(recipe_id)]
	if operation_token in (machine[&"claimed_tokens"] as Array):
		return _result(false, farm, &"operation_already_applied")
	machine[&"state"] = String(STATE_RUNNING)
	machine[&"recipe_id"] = String(recipe_id)
	machine[&"start_day"] = start_day
	machine[&"complete_day"] = start_day + int(recipe[&"duration_days"])
	machine[&"operation_token"] = operation_token
	machines[index] = machine
	candidate[&"machines"] = machines
	return _result(true, candidate, &"")


static func advance(farm: Dictionary, target_absolute_day: int) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var machines: Array = (candidate.get(&"machines", []) as Array).duplicate(true)
	for index: int in machines.size():
		var machine: Dictionary = (machines[index] as Dictionary).duplicate(true)
		if (
			StringName(machine[&"state"]) == STATE_RUNNING
			and target_absolute_day >= int(machine[&"complete_day"])
		):
			machine[&"state"] = String(STATE_COMPLETE)
			machines[index] = machine
	candidate[&"machines"] = machines
	return candidate


static func claim(farm: Dictionary, machine_id: StringName) -> Dictionary:
	var index: int = _machine_index(farm, machine_id)
	if index < 0:
		return _result(false, farm, &"unknown_machine")
	var machine: Dictionary = (farm[&"machines"] as Array)[index] as Dictionary
	if StringName(machine[&"state"]) != STATE_COMPLETE:
		return _result(false, farm, &"machine_not_complete")
	var recipe: Dictionary = RecipeCatalogScript.definition(StringName(machine[&"recipe_id"]))
	if recipe.is_empty():
		return _result(false, farm, &"orphaned_recipe")
	var token: String = str(machine[&"operation_token"])
	if token in (machine[&"claimed_tokens"] as Array):
		return _result(false, farm, &"already_claimed")
	var candidate: Dictionary = farm.duplicate(true)
	for raw_output: Variant in LegacyRecipeAdapterScript.outputs(recipe):
		var output: Dictionary = raw_output as Dictionary
		var credited: Dictionary = InventoryServiceScript.credit_with_overflow(
			candidate, StringName(str(output[&"item_id"])), int(output[&"count"])
		)
		if not bool(credited[&"ok"]):
			return _result(false, farm, &"inventory_full")
		candidate = credited[&"candidate"] as Dictionary
	var machines: Array = (candidate[&"machines"] as Array).duplicate(true)
	machine = (machines[index] as Dictionary).duplicate(true)
	var claimed: Array = (machine[&"claimed_tokens"] as Array).duplicate()
	claimed.append(token)
	if claimed.size() > 64:
		claimed.pop_front()
	machine[&"claimed_tokens"] = claimed
	machine[&"state"] = String(STATE_IDLE)
	machine[&"recipe_id"] = ""
	machine[&"start_day"] = 0
	machine[&"complete_day"] = 0
	machine[&"operation_token"] = ""
	machines[index] = machine
	candidate[&"machines"] = machines
	return _result(true, candidate, &"")


static func _make_machine(
	machine_id: StringName, station_tag: StringName, cell: Vector2i
) -> Dictionary:
	return {
		&"machine_id": String(machine_id),
		&"station_tag": String(station_tag),
		&"cell": [cell.x, cell.y],
		&"state": String(STATE_IDLE),
		&"recipe_id": "",
		&"start_day": 0,
		&"complete_day": 0,
		&"operation_token": "",
		&"claimed_tokens": [],
	}


static func _machine_index(farm: Dictionary, machine_id: StringName) -> int:
	var machines: Array = farm.get(&"machines", []) as Array
	for index: int in machines.size():
		if StringName((machines[index] as Dictionary)[&"machine_id"]) == machine_id:
			return index
	return -1


static func _result(ok: bool, farm: Dictionary, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"candidate": farm.duplicate(true), &"reason": reason}
