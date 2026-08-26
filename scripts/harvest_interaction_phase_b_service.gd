extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const CatalogScript: GDScript = preload("res://scripts/interaction_option_catalog.gd")
const EcologyDirectorScript: GDScript = preload("res://scripts/ecology_director.gd")
const FarmProviderScript: GDScript = preload("res://scripts/harvest_interaction_farm_provider.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const HomesteadPresentationScript: GDScript = preload(
	"res://scripts/homestead_presentation_catalog.gd"
)
const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")
const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")
const WildernessProviderScript: GDScript = preload(
	"res://scripts/harvest_interaction_world_provider.gd"
)
const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")

const SHIPPING_CELL: Vector2i = Vector2i(7, 7)
const STORAGE_CELL: Vector2i = Vector2i(8, 7)
const CROSS_DOMAIN_OPERATIONS: Array[StringName] = [
	&"animal_feed",
	&"animal_pet",
	&"animal_product",
	&"craft_claim",
	&"craft_start",
	&"facility_power",
	&"facility_repair",
	&"gift",
	&"herd_interact",
	&"request_complete",
	&"sleep",
	&"talk",
	&"upgrade",
	&"world_clear_reward",
]
const READ_OPERATIONS: Array[StringName] = [
	&"admire",
	&"inspect",
	&"observe_herd",
	&"read_herd_yield",
	&"read_inventory",
	&"read_machine_progress",
	&"read_relationship",
	&"read_safehouse",
	&"read_service",
	&"read_shipping",
	&"read_storage",
	&"review_drops",
	&"review_first_clear",
	&"review_forecast",
	&"review_gate_biome",
	&"review_gate_risk",
	&"review_habitat",
	&"review_mitigation",
	&"review_sanctuary",
	&"review_threat",
]

var _map: Node2D
var _farm_runtime: RefCounted
var _transactions: RefCounted
var _committed: Callable


func configure(
	map: Node2D,
	farm_runtime: RefCounted,
	transactions: RefCounted,
	committed: Callable,
) -> bool:
	if map == null or farm_runtime == null or transactions == null or not committed.is_valid():
		return false
	_map = map
	_farm_runtime = farm_runtime
	_transactions = transactions
	_committed = committed
	return true


func resolver_snapshot(cell: Vector2i) -> Dictionary:
	var description: Dictionary = _describe(cell)
	if bool(description.get(&"out_of_bounds", false)):
		return {&"kinds": [], &"out_of_bounds": true}
	var kind: StringName = description.get(&"kind", &"") as StringName
	var kinds: Array[StringName] = []
	if kind != &"":
		kinds.append(kind)
	return {
		&"kinds": kinds,
		&"blocked": bool(description.get(&"blocked", false)),
		&"home": description.get(&"family", &"") == &"home",
		&"machine": description.get(&"family", &"") == &"machine",
		&"tool_damage": false,
	}


func project(cell: Vector2i, selected_tool: StringName) -> Dictionary:
	var description: Dictionary = _describe(cell)
	if description.is_empty() or bool(description.get(&"out_of_bounds", false)):
		return {}
	var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
	var projection: Dictionary = {}
	match description[&"family"] as StringName:
		&"terrain":
			projection = FarmProviderScript.terrain(farm, cell, selected_tool)
		&"home":
			projection = FarmProviderScript.home(farm, cell)
		&"storage":
			projection = FarmProviderScript.storage(farm, cell)
		&"shipping":
			projection = FarmProviderScript.shipping(farm, cell)
		&"facility":
			projection = FarmProviderScript.facility(farm, cell, description[&"target_id"])
		&"machine":
			projection = FarmProviderScript.machine(farm, cell, description[&"record"])
		&"resident":
			projection = FarmProviderScript.resident(farm, cell, description[&"target_id"])
		&"livestock":
			projection = FarmProviderScript.livestock(farm, cell, description[&"record"])
		&"tree":
			projection = WildernessProviderScript.tree(
				farm, cell, description[&"source_kind"], selected_tool
			)
		&"resource":
			projection = WildernessProviderScript.resource(
				farm, cell, description[&"source_kind"], selected_tool
			)
		&"pickup":
			projection = WildernessProviderScript.pickup(
				cell,
				description[&"target_id"],
				description[&"state"],
				description[&"operation"],
			)
		&"habitat":
			var day: int = CalendarStateScript.absolute_day(farm[&"calendar_weather"])
			projection = WildernessProviderScript.habitat(
				farm, cell, description[&"record"], day
			)
		&"hostile":
			projection = WildernessProviderScript.hostile(
				cell, description[&"target_id"], description[&"record"]
			)
		&"hazard":
			projection = WildernessProviderScript.hazard(farm, description[&"record"])
		&"ruin":
			projection = WildernessProviderScript.ruin(cell, description[&"record"], farm)
		&"gate":
			projection = WildernessProviderScript.gate(cell, _active_run())
	return projection


func execute(
	intent: StringName,
	tool_id: StringName,
	resolved: Dictionary,
	option: Dictionary = {},
) -> Dictionary:
	if not bool(resolved.get(&"valid", false)):
		return _result(false, &"invalid_resolved_target")
	var cell: Vector2i = resolved[&"target_cell"] as Vector2i
	if intent == ResolverScript.ACTION_TOOL:
		return _execute_tool(cell, tool_id, resolved)
	if option.is_empty():
		return _result(false, &"missing_option")
	var current: Dictionary = _current_option(cell, tool_id, option[&"action_id"])
	if current.is_empty() or not _same_identity(option, current, resolved):
		return _result(false, &"stale_target_identity")
	if not bool(current[&"enabled"]):
		return _result(false, current[&"reason_key"])
	return _execute_option(cell, current)


func execute_quick(
	intent: StringName,
	tool_id: StringName,
	resolved: Dictionary,
	option: Dictionary = {},
) -> Dictionary:
	if intent != ResolverScript.ACTION_CONTEXT or tool_id != ToolServiceScript.TOOL_CONTEXT:
		return _result(false, &"invalid_quick_intent")
	if not bool(resolved.get(&"valid", false)) or option.is_empty():
		return _result(false, &"invalid_resolved_target")
	var cell: Vector2i = resolved[&"target_cell"] as Vector2i
	var current: Dictionary = _current_option(cell, tool_id, option[&"action_id"])
	if current.is_empty() or not _same_identity(option, current, resolved):
		return _result(false, &"stale_target_identity")
	if not bool(current[&"enabled"]):
		return _result(false, current[&"reason_key"])
	var source: Dictionary = _transactions.call("get_snapshot") as Dictionary
	var revision: int = int(((source[&"farm"] as Dictionary)[&"revisions"] as Dictionary)[
		&"result_revision"
	])
	var digest: String = CodecScript.digest(current)
	var token: String = "quick:%d:%s" % [revision, digest.left(32)]
	var payload: Dictionary = {
		&"action_id": str(current[&"action_id"]),
		&"operation": str(current[&"operation"]),
		&"option_digest": digest,
		&"source_revision": revision,
	}
	var deterministic: Dictionary = {
		&"result_id": "quick.result.%s" % digest.left(24),
		&"action_id": str(current[&"action_id"]),
		&"operation": str(current[&"operation"]),
		&"source_revision": revision,
	}
	var result: Dictionary = _transactions.call(
		"transact_exact_once",
		current[&"operation"],
		(current[&"arguments"] as Dictionary).duplicate(true),
		token,
		payload,
		deterministic,
	) as Dictionary
	return _finalize_quick(result, current, cell)


func _finalize_quick(
	result: Dictionary,
	option: Dictionary,
	cell: Vector2i,
) -> Dictionary:
	if not _sync_cross_domain_farm(result):
		return _result(false, &"live_farm_sync_failed")
	if not bool(result.get(&"ok", false)):
		return result
	if not bool(result.get(&"replayed", false)):
		_committed.call(option[&"operation"], cell, result.duplicate(true))
	return result


func _execute_tool(cell: Vector2i, tool_id: StringName, resolved: Dictionary) -> Dictionary:
	var actions: Array[StringName] = _tool_actions(tool_id)
	if actions.is_empty():
		return _result(false, &"unknown_tool")
	for action_id: StringName in actions:
		var current: Dictionary = _current_option(cell, tool_id, action_id)
		if current.is_empty():
			continue
		if not _resolved_identity_matches(current, resolved):
			return _result(false, &"stale_target_identity")
		if not bool(current[&"enabled"]):
			return _result(false, current[&"reason_key"])
		return _execute_option(cell, current)
	return _result(false, &"tool_has_no_compatible_target")


func _tool_actions(tool_id: StringName) -> Array[StringName]:
	match tool_id:
		ToolServiceScript.TOOL_HOE:
			return [&"interaction.action.till"]
		ToolServiceScript.TOOL_WATERING:
			return [&"interaction.action.water"]
		ToolServiceScript.TOOL_AXE:
			return [&"interaction.action.chop"]
		ToolServiceScript.TOOL_PICK:
			return [&"interaction.action.break", &"interaction.action.mine"]
	return []


func _execute_option(cell: Vector2i, option: Dictionary) -> Dictionary:
	var operation: StringName = option[&"operation"] as StringName
	if operation in READ_OPERATIONS:
		return _result(true, &"preview_only")
	var arguments: Dictionary = (option[&"arguments"] as Dictionary).duplicate(true)
	var result: Dictionary
	if operation in CROSS_DOMAIN_OPERATIONS:
		result = _transactions.call("transact", operation, arguments) as Dictionary
	else:
		result = _farm_runtime.call("transact", operation, arguments) as Dictionary
	if bool(result.get(&"ok", false)):
		if operation in CROSS_DOMAIN_OPERATIONS:
			if not _sync_cross_domain_farm(result):
				return _result(false, &"live_farm_sync_failed")
		_committed.call(operation, cell, result.duplicate(true))
	elif operation in CROSS_DOMAIN_OPERATIONS:
		_sync_cross_domain_farm(result)
	return result


func _sync_cross_domain_farm(result: Dictionary) -> bool:
	var envelope: Dictionary = result.get(&"candidate", {}) as Dictionary
	if envelope.is_empty() or not envelope.get(&"farm", {}) is Dictionary:
		return false
	return bool(_farm_runtime.call("sync_committed", envelope[&"farm"]))


func _current_option(
	cell: Vector2i, selected_tool: StringName, action_id: StringName
) -> Dictionary:
	var menu: Dictionary = CatalogScript.build_menu(project(cell, selected_tool))
	for candidate: Dictionary in menu.get(&"options", []) as Array[Dictionary]:
		if candidate[&"action_id"] == action_id:
			return candidate.duplicate(true)
	return {}


func _same_identity(option: Dictionary, current: Dictionary, resolved: Dictionary) -> bool:
	return option == current and _resolved_identity_matches(current, resolved)


func _resolved_identity_matches(option: Dictionary, resolved: Dictionary) -> bool:
	var affected: Array = option[&"affected_cells"] as Array
	return (
		affected.size() == 1
		and affected[0] == resolved[&"target_cell"]
		and option[&"target_kind"] == resolved[&"target_kind"]
	)


func _describe(cell: Vector2i) -> Dictionary:
	var world: RefCounted = _map.get("_world") as RefCounted
	if world == null or not bool(world.call("is_valid_cell", cell)):
		return {&"out_of_bounds": true}
	var result: Dictionary = _priority_description(cell, world)
	if result.is_empty():
		result = _terrain_description(cell, world)
	return result


func _priority_description(cell: Vector2i, world: RefCounted) -> Dictionary:
	var result: Dictionary = _pickup_at(cell)
	var presentation: Dictionary = _presentation_at(cell)
	if result.is_empty():
		if not presentation.is_empty() and presentation[&"family"] in [&"resident", &"livestock"]:
			result = presentation
		else:
			result = _habitat_at(cell, true)
	if result.is_empty():
		result = _hostile_at(cell)
	if result.is_empty():
		result = _hazard_at(cell)
	if result.is_empty():
		result = _habitat_at(cell, false)
	if result.is_empty():
		result = _structure_at(cell, presentation, world)
	return result


func _terrain_description(cell: Vector2i, world: RefCounted) -> Dictionary:
	var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
	var plot: Dictionary = FarmStateScript.plot_at(farm, cell)
	if not plot.is_empty():
		var kind: StringName = (
			ResolverScript.KIND_CROP
			if not str(plot[&"crop_id"]).is_empty()
			else ResolverScript.KIND_PLOT
		)
		return {&"family": &"terrain", &"kind": kind, &"blocked": false}
	var tree_kind: StringName = world.call("_tree_kind_at", cell) as StringName
	if tree_kind != &"":
		return {
			&"family": &"tree",
			&"kind": ResolverScript.KIND_TREE,
			&"source_kind": tree_kind,
			&"blocked": true,
		}
	if bool(_map.call("has_destructible_rock", cell)):
		var objects: Node2D = _map.get("_world_objects") as Node2D
		return {
			&"family": &"resource",
			&"kind": ResolverScript.KIND_STRUCTURE,
			&"source_kind": objects.call("get_destructible_kind", cell) as StringName,
			&"blocked": true,
		}
	if WoodlandClearingScript.is_farm_apron(cell) or bool(world.call("is_walkable", cell)):
		return {
			&"family": &"terrain",
			&"kind": ResolverScript.KIND_TERRAIN,
			&"blocked": false,
		}
	return {&"family": &"", &"kind": &"", &"blocked": true}


func _pickup_at(cell: Vector2i) -> Dictionary:
	var objects: Node2D = _map.get("_world_objects") as Node2D
	var run_pickups: Node2D
	if objects != null:
		run_pickups = objects.get_node_or_null("RunPickups") as Node2D
	if run_pickups != null:
		for drop: Dictionary in run_pickups.call("get_snapshot") as Array[Dictionary]:
			var raw: Array = drop[&"cell"] as Array
			if Vector2i(int(raw[0]), int(raw[1])) == cell:
				return {
					&"family": &"pickup",
					&"kind": ResolverScript.KIND_PICKUP,
					&"target_id": StringName(str(drop[&"drop_id"])),
					&"state": drop,
					&"operation": &"collect_run_pickup",
				}
	if not bool(_map.call("has_scrap", cell)):
		return {}
	var scrap: Dictionary = _map.get("_scrap") as Dictionary
	var amount: int = int(scrap.get(cell, 0))
	return {
		&"family": &"pickup",
		&"kind": ResolverScript.KIND_PICKUP,
		&"target_id": StringName("pickup.scrap:%d,%d" % [cell.x, cell.y]),
		&"state": {&"source": &"world_scrap", &"amount": amount},
		&"operation": &"world_collect_reward",
	}


func _presentation_at(cell: Vector2i) -> Dictionary:
	var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
	for record: Dictionary in HomesteadPresentationScript.build_records(farm):
		if record[&"cell"] != cell:
			continue
		var record_type: StringName = record[&"type"] as StringName
		if record_type == &"resident":
			return {
				&"family": &"resident",
				&"kind": ResolverScript.KIND_RESIDENT,
				&"target_id": record[&"stable_id"],
				&"record": record,
			}
		if record_type == &"livestock":
			var animal: Dictionary = _animal(record[&"stable_id"] as StringName, farm)
			return {
				&"family": &"livestock",
				&"kind": ResolverScript.KIND_FRIENDLY_FAUNA,
				&"target_id": record[&"stable_id"],
				&"record": animal,
			}
		var family: StringName = (
			&"home" if record[&"stable_id"] == HomesteadServiceScript.HOME_ID else &"facility"
		)
		return {
			&"family": family,
			&"kind": ResolverScript.KIND_STRUCTURE,
			&"target_id": record[&"stable_id"],
			&"record": record,
		}
	return {}


func _structure_at(
	cell: Vector2i, presentation: Dictionary, world: RefCounted
) -> Dictionary:
	var result: Dictionary = presentation
	if result.is_empty() and cell == SHIPPING_CELL:
		result = {&"family": &"shipping", &"kind": ResolverScript.KIND_STRUCTURE}
	if result.is_empty() and cell == STORAGE_CELL:
		result = {&"family": &"storage", &"kind": ResolverScript.KIND_STRUCTURE}
	if result.is_empty():
		var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
		var machine: Dictionary = _machine_at(cell, farm)
		if not machine.is_empty():
			result = {
			&"family": &"machine",
			&"kind": ResolverScript.KIND_STRUCTURE,
			&"target_id": StringName(machine[&"machine_id"]),
			&"record": machine,
		}
	if result.is_empty() and WoodlandClearingScript.is_gate(cell):
		result = {&"family": &"gate", &"kind": ResolverScript.KIND_STRUCTURE}
	if result.is_empty() and bool(world.call("_is_outpost", cell)):
		var registry: RefCounted = world.call("_get_ruin_registry") as RefCounted
		result = {
			&"family": &"ruin",
			&"kind": ResolverScript.KIND_STRUCTURE,
			&"record": registry.call("state_for", cell) as Dictionary,
		}
	return result


func _machine_at(cell: Vector2i, farm: Dictionary) -> Dictionary:
	for machine: Dictionary in farm.get(&"machines", []) as Array[Dictionary]:
		var raw: Array = machine[&"cell"] as Array
		if Vector2i(int(raw[0]), int(raw[1])) == cell:
			return machine.duplicate(true)
	return {}


func _animal(animal_id: StringName, farm: Dictionary) -> Dictionary:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	for animal: Dictionary in homestead.get(&"animals", []) as Array[Dictionary]:
		if StringName(animal[&"animal_id"]) == animal_id:
			return animal.duplicate(true)
	return {}


func _habitat_at(cell: Vector2i, friendly: bool) -> Dictionary:
	var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
	var calendar: Dictionary = farm[&"calendar_weather"] as Dictionary
	var day: int = CalendarStateScript.absolute_day(calendar)
	var habitats: Array[Dictionary] = EcologyDirectorScript.population_snapshot(
		farm, WoodlandClearingScript.DEFAULT_SEED, day, int(calendar[&"minute_of_day"])
	)
	for habitat: Dictionary in habitats:
		var is_friendly: bool = habitat[&"category"] == EcologyDirectorScript.HERD
		if habitat[&"anchor"] == cell and is_friendly == friendly:
			var kind: StringName = (
				ResolverScript.KIND_FRIENDLY_FAUNA if friendly else ResolverScript.KIND_HOSTILE
			)
			return {
				&"family": &"habitat",
				&"kind": kind,
				&"target_id": habitat[&"habitat_id"],
				&"record": habitat,
			}
	return {}


func _hostile_at(cell: Vector2i) -> Dictionary:
	var worms: Node2D = _map.get("_sandworms") as Node2D
	if worms == null:
		return {}
	for combat: Dictionary in worms.call("get_combat_snapshots") as Array[Dictionary]:
		if Vector2i((combat[&"position"] as Vector2).round()) != cell:
			continue
		var identifier: StringName = StringName(
			"hostile.%s.%d" % [str(combat[&"kind"]), int(combat[&"id"])]
		)
		return {
			&"family": &"hostile",
			&"kind": ResolverScript.KIND_HOSTILE,
			&"target_id": identifier,
			&"record": combat,
		}
	return {}


func _hazard_at(cell: Vector2i) -> Dictionary:
	var hazards: Node2D = _map.get("_hazards") as Node2D
	if hazards == null:
		return {}
	for event: Dictionary in hazards.call("get_deep_event_snapshots") as Array[Dictionary]:
		if event[&"cell"] == cell:
			return {
				&"family": &"hazard",
				&"kind": ResolverScript.KIND_HOSTILE,
				&"record": event,
			}
	return {}


func _active_run() -> Dictionary:
	return (_transactions.call("get_snapshot") as Dictionary)[&"active_run"] as Dictionary


func _result(ok: bool, reason: StringName) -> Dictionary:
	return {&"ok": ok, &"reason": reason}
