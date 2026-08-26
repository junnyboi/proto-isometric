extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const BlueprintCatalogScript: GDScript = preload(
	"res://scripts/construction_blueprint_catalog.gd"
)
const CatalogScript: GDScript = preload("res://scripts/interaction_option_catalog.gd")
const ConstructionProviderScript: GDScript = preload(
	"res://scripts/construction_interaction_provider.gd"
)
const DepositProviderScript: GDScript = preload(
	"res://scripts/resource_deposit_interaction_provider.gd"
)
const OccupancyScript: GDScript = preload("res://scripts/building_occupancy_index.gd")
const EcologyDirectorScript: GDScript = preload("res://scripts/ecology_director.gd")
const ExecutionResultScript: GDScript = preload("res://scripts/interaction_execution_result.gd")
const FarmProviderScript: GDScript = preload("res://scripts/harvest_interaction_farm_provider.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const FishingCatalogScript: GDScript = preload("res://scripts/fishing_catalog.gd")
const HomesteadPresentationScript: GDScript = preload(
	"res://scripts/homestead_presentation_catalog.gd"
)
const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")
const IronjawDesertArcScript: GDScript = preload("res://scripts/ironjaw_desert_arc.gd")
const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const OperationCatalogScript: GDScript = preload("res://scripts/interaction_operation_catalog.gd")
const OrchardServiceScript: GDScript = preload("res://scripts/orchard_service.gd")
const ReadResultCatalogScript: GDScript = preload(
	"res://scripts/interaction_read_result_catalog.gd"
)
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const SettlementProviderScript: GDScript = preload(
	"res://scripts/settlement_interaction_provider.gd"
)
const SeasonalProviderScript: GDScript = preload(
	"res://scripts/seasonal_interaction_provider.gd"
)
const StableFeatureProviderScript: GDScript = preload(
	"res://scripts/stable_feature_interaction_provider.gd"
)
const SettlerPresentationScript: GDScript = preload(
	"res://scripts/settler_presentation_catalog.gd"
)
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")
const WildernessProviderScript: GDScript = preload(
	"res://scripts/harvest_interaction_world_provider.gd"
)
const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")

const SHIPPING_CELL: Vector2i = Vector2i(7, 7)
const STORAGE_CELL: Vector2i = Vector2i(8, 7)
const WORKSHOP_CELL: Vector2i = Vector2i(9, 7)
const IRRIGATION_CELL: Vector2i = Vector2i(10, 6)
const WELL_CELL: Vector2i = Vector2i(5, 9)

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
	var world: RefCounted = _map.get("_world") as RefCounted
	var source: Dictionary = world.call("_resource_source_at", cell) as Dictionary
	if not source.is_empty():
		return {
			&"kinds": [ResolverScript.KIND_RESOURCE], &"blocked": true,
			&"home": false, &"machine": false, &"tool_damage": false,
		}
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
	var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
	var world: RefCounted = _map.get("_world") as RefCounted
	var source: Dictionary = world.call("_resource_source_at", cell) as Dictionary
	if not source.is_empty():
		return DepositProviderScript.deposit(
			farm,
			source,
			CalendarStateScript.absolute_day(farm[&"calendar_weather"]),
			selected_tool,
		)
	var description: Dictionary = _describe(cell)
	if description.is_empty() or bool(description.get(&"out_of_bounds", false)):
		return {}
	var projection: Dictionary = {}
	match description[&"family"] as StringName:
		&"terrain":
			projection = FarmProviderScript.terrain(
				farm,
				cell,
				selected_tool,
				_terrain_inspection_descriptor(cell, world, farm, description),
				Callable(world, "is_walkable"),
			)
		&"water":
			projection = SeasonalProviderScript.water(
				farm, cell, description[&"state"], WoodlandClearingScript.DEFAULT_SEED
			)
		&"safe_exit":
			projection = StableFeatureProviderScript.safe_exit(cell, description[&"state"])
		&"functional_prop":
			projection = StableFeatureProviderScript.functional_prop(
				cell,
				description[&"target_id"] as StringName,
				description[&"state"] as Dictionary,
			)
		&"home":
			projection = FarmProviderScript.home(farm, cell)
			if not projection.is_empty():
				_append_projection_option(projection, SettlementProviderScript.terminal_option())
		&"storage":
			projection = FarmProviderScript.storage(farm, cell)
		&"shipping":
			projection = FarmProviderScript.shipping(farm, cell)
		&"facility":
			projection = FarmProviderScript.facility(farm, cell, description[&"target_id"])
			var facility_id: StringName = description[&"target_id"] as StringName
			var facility: Dictionary = HomesteadServiceScript.facility_state(farm, facility_id)
			if (
				facility_id == HomesteadServiceScript.WORKSHOP_ID
				and bool(facility.get(&"repaired", false))
				and bool(facility.get(&"powered", false))
				and not projection.is_empty()
			):
				_append_projection_option(
					projection, ConstructionProviderScript.catalog_option()
				)
		&"machine":
			projection = FarmProviderScript.machine(farm, cell, description[&"record"])
			if cell == WORKSHOP_CELL and not projection.is_empty():
				_append_projection_option(
					projection, ConstructionProviderScript.catalog_option()
				)
		&"construction":
			projection = ConstructionProviderScript.building(
				farm, cell, description[&"record"]
			)
			var construction: Dictionary = description[&"record"] as Dictionary
			var blueprint_id: StringName = StringName(str(construction[&"blueprint_id"]))
			if (
				construction[&"state"] == "complete"
				and not projection.is_empty()
				and (
					BlueprintCatalogScript.housing_capacity(blueprint_id) > 0
					or not BlueprintCatalogScript.work_slot_types(blueprint_id).is_empty()
				)
			):
				_append_projection_option(projection, SettlementProviderScript.terminal_option())
			if (
				construction[&"state"] == "complete"
				and not projection.is_empty()
				and blueprint_id in [
					BlueprintCatalogScript.FIELD_WAREHOUSE,
					BlueprintCatalogScript.FABRICATOR_ANNEX,
				]
			):
				_append_projection_option(
					projection, SettlementProviderScript.logistics_option()
				)
		&"resident":
			projection = FarmProviderScript.resident(farm, cell, description[&"target_id"])
		&"settler":
			projection = SettlementProviderScript.settler(
				cell, description[&"target_id"] as StringName
			)
		&"livestock":
			projection = FarmProviderScript.livestock(farm, cell, description[&"record"])
		&"tree":
			projection = WildernessProviderScript.tree(
				farm, cell, description[&"source_kind"], selected_tool
			)
		&"orchard_tree":
			projection = SeasonalProviderScript.tree(farm, cell, description[&"record"])
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


func _terrain_inspection_descriptor(
	cell: Vector2i,
	world: RefCounted,
	farm: Dictionary,
	description: Dictionary,
) -> Dictionary:
	return {
		&"biome_id": world.call("_biome_at", cell) as StringName,
		&"blocked": bool(description.get(&"blocked", false)),
		&"farmable": (
			WoodlandClearingScript.is_farm_apron(cell)
			or IronjawDesertArcScript.deep_tillable(farm, cell)
		),
		&"surface_id": world.call("terrain_at", cell) as StringName,
		&"walkable": bool(world.call("is_walkable", cell)),
	}


func _append_projection_option(projection: Dictionary, option: Dictionary) -> void:
	var options: Array = projection[&"option_inputs"] as Array
	options.append(option)
	options.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"action_id"]) < str(b[&"action_id"])
	)
	projection[&"option_inputs"] = options


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
	var pair: Dictionary = _current_pair(cell, tool_id, option[&"action_id"])
	var current: Dictionary = pair.get(&"option", {}) as Dictionary
	if (
		pair.is_empty()
		or current.is_empty()
		or not _same_identity(option, current, resolved, pair[&"descriptor"])
	):
		return _result(false, &"stale_target_identity")
	if not bool(current[&"enabled"]):
		return _result(false, current[&"reason_key"])
	return _execute_option(
		cell,
		pair[&"menu"] as Dictionary,
		current,
		pair[&"descriptor"] as Dictionary,
	)


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
	var pair: Dictionary = _current_pair(cell, tool_id, option[&"action_id"])
	var current: Dictionary = pair.get(&"option", {}) as Dictionary
	if (
		pair.is_empty()
		or current.is_empty()
		or not _same_identity(option, current, resolved, pair[&"descriptor"])
	):
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
		var pair: Dictionary = _current_pair(cell, tool_id, action_id)
		var current: Dictionary = pair.get(&"option", {}) as Dictionary
		if pair.is_empty() or current.is_empty():
			continue
		if not _resolved_identity_matches(current, resolved):
			return _result(false, &"stale_target_identity")
		if not bool(current[&"enabled"]):
			return _result(false, current[&"reason_key"])
		return _execute_option(
			cell,
			pair[&"menu"] as Dictionary,
			current,
			pair[&"descriptor"] as Dictionary,
		)
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


func _execute_option(
	cell: Vector2i,
	menu: Dictionary,
	option: Dictionary,
	descriptor: Dictionary,
) -> Dictionary:
	if descriptor.is_empty():
		return _result(false, &"operation_unrouted")
	var operation: StringName = option[&"operation"] as StringName
	var route: StringName = descriptor[&"route"] as StringName
	var result: Dictionary = {}
	match route:
		OperationCatalogScript.ROUTE_READ:
			result = ReadResultCatalogScript.build(menu, option, descriptor)
		OperationCatalogScript.ROUTE_CONSTRUCTION_UI:
			var opened: Dictionary = _result(true, &"")
			opened[&"arguments"] = (option[&"arguments"] as Dictionary).duplicate(true)
			_committed.call(operation, cell, opened.duplicate(true))
			result = _ui_result(menu, option, descriptor)
		OperationCatalogScript.ROUTE_CROSS_DOMAIN, OperationCatalogScript.ROUTE_FARM:
			result = _execute_persistent_option(cell, option, route)
		_:
			result = _result(false, &"operation_unrouted")
	return result


func _execute_persistent_option(
	cell: Vector2i,
	option: Dictionary,
	route: StringName,
) -> Dictionary:
	var operation: StringName = option[&"operation"] as StringName
	var arguments: Dictionary = (option[&"arguments"] as Dictionary).duplicate(true)
	if operation == &"deposit_gather":
		return _execute_deposit_gather(cell, option, arguments)
	if operation in [&"fish_cast", &"tree_harvest", &"tree_plant", &"tree_remove"]:
		return _execute_seasonal_exact_once(cell, option, arguments)
	var result: Dictionary
	if route == OperationCatalogScript.ROUTE_CROSS_DOMAIN:
		result = _transactions.call("transact", operation, arguments) as Dictionary
	else:
		result = _farm_runtime.call("transact", operation, arguments) as Dictionary
	if bool(result.get(&"ok", false)):
		if route == OperationCatalogScript.ROUTE_CROSS_DOMAIN:
			if not _sync_cross_domain_farm(result):
				return _result(false, &"live_farm_sync_failed")
		_committed.call(operation, cell, result.duplicate(true))
	elif route == OperationCatalogScript.ROUTE_CROSS_DOMAIN:
		_sync_cross_domain_farm(result)
	return result


func _ui_result(
	menu: Dictionary,
	option: Dictionary,
	descriptor: Dictionary,
) -> Dictionary:
	return ExecutionResultScript.build(
		true,
		&"",
		false,
		menu[&"snapshot_id"] as StringName,
		option[&"action_id"] as StringName,
		menu[&"target_id"] as StringName,
		menu[&"target_cell"] as Vector2i,
		menu[&"target_state"] as Dictionary,
		{
			&"title_key": menu[&"target_title_key"] as StringName,
			&"body_key": &"interaction.result.ui_success.body",
			&"parameters": {},
			&"facts": [],
		},
		descriptor,
	)


func _execute_deposit_gather(
	cell: Vector2i,
	option: Dictionary,
	arguments: Dictionary,
) -> Dictionary:
	var source: Dictionary = _transactions.call("get_snapshot") as Dictionary
	var revision: int = int(((source[&"farm"] as Dictionary)[&"revisions"] as Dictionary)[
		&"result_revision"
	])
	var digest: String = CodecScript.digest(option)
	var token: String = "deposit:%d:%s" % [revision, digest.left(32)]
	var payload: Dictionary = {
		&"source_id": str(arguments[&"source_id"]), &"option_digest": digest,
		&"source_revision": revision,
	}
	var deterministic: Dictionary = {
		&"result_id": "deposit.result.%s" % digest.left(24),
		&"source_id": str(arguments[&"source_id"]), &"source_revision": revision,
	}
	var result: Dictionary = _transactions.call(
		"transact_exact_once", &"deposit_gather", arguments, token, payload, deterministic
	) as Dictionary
	if not _sync_cross_domain_farm(result):
		return _result(false, &"live_farm_sync_failed")
	if bool(result.get(&"ok", false)) and not bool(result.get(&"replayed", false)):
		result[&"dirty_cells"] = [cell]
		_committed.call(&"deposit_gather", cell, result.duplicate(true))
	return result


func _execute_seasonal_exact_once(
	cell: Vector2i, option: Dictionary, arguments: Dictionary
) -> Dictionary:
	var revision: int = int(arguments.get(&"expected_revision", -1))
	if revision < 0:
		return _result(false, &"missing_source_revision")
	var digest: String = CodecScript.digest(option)
	var operation: StringName = option[&"operation"] as StringName
	var token_namespace: String = "fish" if operation == &"fish_cast" else "tree"
	var token: String = "%s:%d:%s" % [token_namespace, revision, digest.left(32)]
	var payload: Dictionary = {
		&"operation": str(operation),
		&"option_digest": digest,
		&"source_revision": revision,
	}
	var deterministic: Dictionary = {
		&"result_id": "%s.result.%s" % [token_namespace, digest.left(24)],
		&"operation": str(operation),
		&"source_revision": revision,
	}
	var result: Dictionary = _transactions.call(
		"transact_exact_once", operation, arguments, token, payload, deterministic
	) as Dictionary
	if not _sync_cross_domain_farm(result):
		return _result(false, &"live_farm_sync_failed")
	if bool(result.get(&"ok", false)) and not bool(result.get(&"replayed", false)):
		result[&"dirty_cells"] = [cell]
		_committed.call(operation, cell, result.duplicate(true))
	return result


func _sync_cross_domain_farm(result: Dictionary) -> bool:
	var envelope: Dictionary = result.get(&"candidate", {}) as Dictionary
	if envelope.is_empty() or not envelope.get(&"farm", {}) is Dictionary:
		return false
	return bool(_farm_runtime.call("sync_committed", envelope[&"farm"]))


func _current_pair(
	cell: Vector2i, selected_tool: StringName, action_id: StringName
) -> Dictionary:
	var menu: Dictionary = CatalogScript.build_menu(project(cell, selected_tool))
	if menu.is_empty():
		return {}
	for candidate: Dictionary in menu.get(&"options", []) as Array[Dictionary]:
		if candidate[&"action_id"] == action_id:
			var descriptor: Dictionary = OperationCatalogScript.descriptor_for(
				candidate[&"operation"] as StringName,
				candidate[&"provider_id"] as StringName,
			)
			if (
				descriptor.is_empty()
				or not OperationCatalogScript.accepts(
					descriptor,
					candidate[&"provider_id"] as StringName,
					candidate[&"operation"] as StringName,
					candidate[&"close_behavior"] as StringName,
				)
			):
				return {}
			return {
				&"descriptor": descriptor,
				&"menu": menu.duplicate(true),
				&"option": candidate.duplicate(true),
			}
	return {}


func _same_identity(
	option: Dictionary,
	current: Dictionary,
	resolved: Dictionary,
	descriptor: Dictionary,
) -> bool:
	if (
		descriptor[&"mutability"] == OperationCatalogScript.MUTABILITY_MUTATING
		and option != current
	):
		return false
	for key: StringName in [
		&"action_id",
		&"provider_id",
		&"target_id",
		&"target_kind",
		&"target_subkind",
		&"operation",
	]:
		if option[key] != current[key]:
			return false
	return _resolved_identity_matches(current, resolved)


func _resolved_identity_matches(option: Dictionary, resolved: Dictionary) -> bool:
	var affected: Array = option[&"affected_cells"] as Array
	return (
		affected.size() == 1
		and affected[0] == resolved[&"target_cell"]
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
	if result.is_empty():
		result = _stable_feature_at(cell, world)
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
	var farm_structure: Dictionary = _farm_structure_presentation(farm, cell)
	if not farm_structure.is_empty():
		return farm_structure
	for record: Dictionary in SettlerPresentationScript.build_records(farm):
		if record[&"cell"] == cell:
			return {
				&"family": &"settler",
				&"kind": ResolverScript.KIND_RESIDENT,
				&"target_id": record[&"stable_id"],
				&"record": record,
			}
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


func _farm_structure_presentation(farm: Dictionary, cell: Vector2i) -> Dictionary:
	var orchard_tree: Dictionary = OrchardServiceScript.tree_at(farm, cell)
	if not orchard_tree.is_empty():
		return {
			&"family": &"orchard_tree",
			&"kind": ResolverScript.KIND_RESOURCE,
			&"target_id": StringName(str(orchard_tree[&"tree_id"])),
			&"record": orchard_tree,
		}
	var building: Dictionary = OccupancyScript.building_at(OccupancyScript.build(farm), cell)
	if building.is_empty():
		return {}
	return {
		&"family": &"construction",
		&"kind": ResolverScript.KIND_STRUCTURE,
		&"target_id": StringName(str(building[&"instance_id"])),
		&"record": building,
	}


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


func _stable_feature_at(cell: Vector2i, world: RefCounted) -> Dictionary:
	var farm: Dictionary = _farm_runtime.call("get_snapshot") as Dictionary
	var pond: bool = world.has_method("_is_pond") and bool(world.call("_is_pond", cell))
	var biome_id: StringName = world.call("_biome_at", cell) as StringName
	return stable_feature_description(cell, farm, pond, biome_id)


static func stable_feature_description(
	cell: Vector2i,
	farm: Dictionary,
	is_pond: bool,
	biome_id: StringName = &"",
) -> Dictionary:
	var water_class: StringName = FishingCatalogScript.live_water_class(cell, biome_id, is_pond)
	if water_class != &"":
		return {
			&"family": &"water",
			&"kind": ResolverScript.KIND_STRUCTURE,
			&"state": {
				&"water_class": water_class,
				&"walkable": false,
				&"irrigation_relevant": true,
			},
		}
	if cell == IronjawDesertArcScript.SAFE_EXIT:
		var ready: bool = IronjawDesertArcScript.is_first_clear(farm)
		return {
			&"family": &"safe_exit",
			&"kind": ResolverScript.KIND_STRUCTURE,
			&"state": {
				&"destination": &"home_clearing",
				&"ready": ready,
				&"risk": &"secured" if ready else &"sealed",
			},
		}
	if cell == IRRIGATION_CELL and _has_upgrade(farm, &"upgrade.irrigation.grid_radius"):
		return {
			&"family": &"functional_prop",
			&"kind": ResolverScript.KIND_STRUCTURE,
			&"target_id": &"prop.irrigation_pump",
			&"state": {&"purpose": &"irrigation", &"active": true},
		}
	if cell == WELL_CELL and IronjawDesertArcScript.is_first_clear(farm):
		return {
			&"family": &"functional_prop",
			&"kind": ResolverScript.KIND_STRUCTURE,
			&"target_id": &"prop.burrow_well",
			&"state": {&"purpose": &"water_access", &"active": true},
		}
	return {}


static func _has_upgrade(farm: Dictionary, upgrade_id: StringName) -> bool:
	return (
		String(upgrade_id)
		in ((farm.get(&"tools", {}) as Dictionary).get(&"upgrade_ids", []) as Array)
	)


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
