extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const CropCatalogScript: GDScript = preload("res://scripts/crop_catalog.gd")
const DayAdvanceServiceScript: GDScript = preload("res://scripts/day_advance_service.gd")
const DurableUpgradeCatalogScript: GDScript = preload("res://scripts/durable_upgrade_catalog.gd")
const DurableUpgradeServiceScript: GDScript = preload("res://scripts/durable_upgrade_service.gd")
const EconomyServiceScript: GDScript = preload("res://scripts/economy_service.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const LivestockServiceScript: GDScript = preload("res://scripts/livestock_service.gd")
const MachineServiceScript: GDScript = preload("res://scripts/machine_service.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const OrchardCatalogScript: GDScript = preload("res://scripts/orchard_catalog.gd")
const OrchardServiceScript: GDScript = preload("res://scripts/orchard_service.gd")
const RecipeCatalogScript: GDScript = preload("res://scripts/recipe_catalog.gd")
const RelationshipServiceScript: GDScript = preload("res://scripts/relationship_service.gd")
const ResidentServiceScript: GDScript = preload("res://scripts/resident_service.gd")
const TargetBridgeScript: GDScript = preload("res://scripts/harvest_interaction_target_bridge.gd")
const TargetScript: GDScript = preload("res://scripts/interaction_target_snapshot.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")

const MAX_SHIPPING_ROWS: int = 24
const P10_SUPPLIES: Array[StringName] = [
	&"item.sapling.cinderapple",
	&"item.sapling.ironbark",
	&"item.tool.fishing_rod",
	&"item.bait.luminous",
]


static func terrain(
	farm: Dictionary,
	cell: Vector2i,
	selected_tool: StringName,
	terrain_descriptor: Dictionary = {},
	world_cell_clear: Callable = Callable(),
) -> Dictionary:
	var plot: Dictionary = FarmStateScript.plot_at(farm, cell)
	var subkind: StringName = &"terrain"
	if not plot.is_empty():
		subkind = &"crop" if not str(plot[&"crop_id"]).is_empty() else &"plot"
	var target_id: StringName = StringName("%s:%d,%d" % [subkind, cell.x, cell.y])
	var options: Array[Dictionary] = [_inspect(cell)]
	var till: Dictionary = FarmStateScript.till(farm, cell)
	options.append(
		_tool_offer(&"till", &"till", cell, ToolServiceScript.TOOL_HOE, selected_tool, till, 100)
	)
	var day: int = CalendarStateScript.absolute_day(farm[&"calendar_weather"])
	var expected_revision: int = int((farm[&"revisions"] as Dictionary)[&"result_revision"])
	for crop_id: StringName in CropCatalogScript.CROP_IDS:
		var crop: Dictionary = CropCatalogScript.definition(crop_id)
		var seed_id: StringName = crop[&"seed_item_id"] as StringName
		var owned: int = InventoryServiceScript.count_item(
			farm, InventoryServiceScript.ROBOT_ID, seed_id
		)
		if owned <= 0:
			continue
		var planted: Dictionary = FarmStateScript.plant(farm, cell, seed_id, day)
		(
			options
			. append(
				_offer(
					StringName("plant.%s" % str(crop_id)),
					&"plant",
					{&"cell": cell, &"seed_item_id": seed_id},
					bool(planted[&"ok"]),
					_reason(planted[&"reason"] as StringName),
					200,
					[{&"cost_id": seed_id, &"amount": 1}],
				)
			)
		)
	for species_id: StringName in OrchardCatalogScript.SPECIES_IDS:
		var tree: Dictionary = OrchardCatalogScript.definition(species_id)
		var sapling_id: StringName = tree[&"sapling_item_id"] as StringName
		var owned: int = InventoryServiceScript.count_item(
			farm, InventoryServiceScript.ROBOT_ID, sapling_id
		)
		if owned <= 0:
			continue
		var planted_tree: Dictionary = OrchardServiceScript.plant(
			farm, cell, sapling_id, day, world_cell_clear
		)
		options.append(_offer(
			StringName("tree_plant.%s" % str(species_id)),
			&"tree_plant",
			{
				&"cell": cell,
				&"sapling_item_id": sapling_id,
				&"expected_revision": expected_revision,
			},
			bool(planted_tree[&"ok"]),
			_reason(planted_tree[&"reason"] as StringName),
			250,
			[{&"cost_id": sapling_id, &"amount": 1}],
		))
	var watered: Dictionary = FarmStateScript.water(farm, cell, day)
	(
		options
		. append(
			_tool_offer(
				&"water",
				&"water",
				cell,
				ToolServiceScript.TOOL_WATERING,
				selected_tool,
				watered,
				300,
			)
		)
	)
	var harvested: Dictionary = FarmStateScript.harvest(farm, cell)
	(
		options
		. append(
			_offer(
				&"harvest",
				&"harvest",
				{&"cell": cell},
				bool(harvested[&"ok"]),
				_reason(harvested[&"reason"] as StringName),
				400,
			)
		)
	)
	var state: Dictionary = {
		&"biome_id": terrain_descriptor.get(&"biome_id", &"unknown") as StringName,
		&"blocked": bool(terrain_descriptor.get(&"blocked", false)),
		&"farmable": bool(terrain_descriptor.get(&"farmable", false)),
		&"plot": plot,
		&"surface_id": terrain_descriptor.get(&"surface_id", &"unknown") as StringName,
		&"walkable": bool(terrain_descriptor.get(&"walkable", true)),
	}
	return _target(cell, target_id, subkind, state, options)


static func home(farm: Dictionary, cell: Vector2i) -> Dictionary:
	var services: Dictionary = HomesteadServiceScript.home_services(farm)
	var home_summary: Dictionary = InventoryServiceScript.summary(
		farm, InventoryServiceScript.HOME_ID
	)
	services[&"item_count"] = int(home_summary.get(&"item_count", 0))
	services[&"occupied_slots"] = int(home_summary.get(&"occupied_slots", 0))
	services[&"capacity_slots"] = int(home_summary.get(&"capacity_slots", 0))
	var sleep: Dictionary = DayAdvanceServiceScript.build_candidate(farm, 0)
	var options: Array[Dictionary] = [
		_inspect(cell),
		_offer(
			&"sleep",
			&"sleep",
			{},
			bool(sleep[&"ok"]) and bool(services[&"bed"]),
			(
				_reason(sleep[&"reason"] as StringName)
				if bool(services[&"bed"])
				else &"interaction.reason.bed_unavailable"
			),
			100,
		),
		_read(&"storage", &"read_storage", {&"container_id": InventoryServiceScript.HOME_ID}, 200),
		_read(&"safehouse", &"read_safehouse", {}, 300),
	]
	return _target(cell, HomesteadServiceScript.HOME_ID, &"home", services, options)


static func storage(farm: Dictionary, cell: Vector2i) -> Dictionary:
	var home_summary: Dictionary = InventoryServiceScript.summary(
		farm, InventoryServiceScript.HOME_ID
	)
	var robot_summary: Dictionary = InventoryServiceScript.summary(
		farm, InventoryServiceScript.ROBOT_ID
	)
	var options: Array[Dictionary] = [
		_inspect(cell),
		_read(
			&"inventory", &"read_inventory", {&"container_id": InventoryServiceScript.ROBOT_ID}, 100
		),
		_read(&"storage", &"read_storage", {&"container_id": InventoryServiceScript.HOME_ID}, 200),
	]
	return _target(
		cell,
		EconomyServiceScript.SEED_SHOP_ID,
		&"storage",
		{
			&"available": true,
			&"item_count": int(home_summary.get(&"item_count", 0)),
			&"occupied_slots": int(home_summary.get(&"occupied_slots", 0)),
			&"capacity_slots": int(home_summary.get(&"capacity_slots", 0)),
			&"robot_item_count": int(robot_summary.get(&"item_count", 0)),
		},
		options,
	)


static func shipping(farm: Dictionary, cell: Vector2i) -> Dictionary:
	var preview: Dictionary = EconomyServiceScript.shipping_preview(farm)
	var options: Array[Dictionary] = [
		_inspect(cell),
		_read(&"shipping_review", &"read_shipping", preview, 100),
	]
	var shippable: Array[StringName] = []
	for item_id: StringName in ItemCatalogScript.ids():
		if (
			ItemCatalogScript.sell_price(item_id) > 0
			and InventoryServiceScript.count_all(farm, item_id) > 0
		):
			shippable.append(item_id)
	shippable.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for item_id: StringName in shippable.slice(0, MAX_SHIPPING_ROWS):
		var count: int = InventoryServiceScript.count_all(farm, item_id)
		var shipped: Dictionary = EconomyServiceScript.ship(farm, item_id, count)
		(
			options
			. append(
				_offer(
					StringName("ship.%s" % str(item_id)),
					&"ship",
					{&"item_id": item_id, &"count": count},
					bool(shipped[&"ok"]),
					_reason(shipped[&"reason"] as StringName),
					200,
					[{&"cost_id": item_id, &"amount": count}],
				)
			)
		)
	return _target(cell, EconomyServiceScript.SHIPPING_BIN_ID, &"shipping", preview, options)


static func facility(farm: Dictionary, cell: Vector2i, facility_id: StringName) -> Dictionary:
	var definition: Dictionary = HomesteadServiceScript.definition(facility_id)
	var state: Dictionary = HomesteadServiceScript.facility_state(farm, facility_id)
	if definition.is_empty() or state.is_empty():
		return {}
	var repair: Dictionary = HomesteadServiceScript.repair(farm, facility_id)
	var power: Dictionary = HomesteadServiceScript.power(farm, facility_id)
	var options: Array[Dictionary] = [
		_inspect(cell),
		_offer(
			&"facility_repair",
			&"facility_repair",
			{&"facility_id": facility_id},
			bool(repair[&"ok"]),
			_reason(repair[&"reason"] as StringName),
			100,
			_costs(definition[&"repair_materials"] as Dictionary),
		),
		_offer(
			&"facility_power",
			&"facility_power",
			{&"facility_id": facility_id},
			bool(power[&"ok"]),
			_reason(power[&"reason"] as StringName),
			200,
			_costs(definition[&"power_materials"] as Dictionary),
		),
	]
	var active: bool = bool(state[&"repaired"]) and bool(state[&"powered"])
	for service_id: StringName in definition[&"service_ids"] as Array[StringName]:
		(
			options
			. append(
				_offer(
					StringName("service.%s" % str(service_id)),
					&"read_service",
					{&"service_id": service_id},
					active,
					&"" if active else &"interaction.reason.facility_service_inactive",
					300,
					[],
					OptionScript.CLOSE_NEVER,
				)
			)
		)
	if facility_id == HomesteadServiceScript.GREENHOUSE_ID:
		_append_seed_shop(options, farm, active)
	return _target(cell, facility_id, &"facility", state, options)


static func machine(farm: Dictionary, cell: Vector2i, record: Dictionary) -> Dictionary:
	var machine_id: StringName = StringName(record[&"machine_id"])
	var state_id: StringName = StringName(record[&"state"])
	var options: Array[Dictionary] = [
		_inspect(cell),
		_read(
			&"machine_progress",
			&"read_machine_progress",
			{
				&"machine_id": machine_id,
				&"state": state_id,
				&"complete_day": int(record[&"complete_day"]),
			},
			100,
		),
	]
	for recipe_id: StringName in RecipeCatalogScript.ids():
		var recipe: Dictionary = RecipeCatalogScript.definition(recipe_id)
		if recipe[&"station_tag"] != StringName(record[&"station_tag"]):
			continue
		var started: Dictionary = MachineServiceScript.start(farm, machine_id, recipe_id)
		(
			options
			. append(
				_offer(
					StringName("machine_start.%s" % str(recipe_id)),
					&"craft_start",
					{&"machine_id": machine_id, &"recipe_id": recipe_id},
					bool(started[&"ok"]),
					_reason(started[&"reason"] as StringName),
					200,
					_recipe_costs(recipe),
				)
			)
		)
	var claim: Dictionary = MachineServiceScript.claim(farm, machine_id)
	(
		options
		. append(
			_offer(
				&"machine_claim",
				&"craft_claim",
				{&"machine_id": machine_id},
				bool(claim[&"ok"]),
				_reason(claim[&"reason"] as StringName),
				300,
			)
		)
	)
	if machine_id == MachineServiceScript.WORKBENCH_ID:
		_append_upgrades(options, farm)
	return _target(cell, machine_id, &"machine", _machine_state(record), options)


static func resident(farm: Dictionary, cell: Vector2i, resident_id: StringName) -> Dictionary:
	var relation: Dictionary = RelationshipServiceScript.relationship(farm, resident_id)
	if relation.is_empty():
		return {}
	var talk: Dictionary = RelationshipServiceScript.talk(farm, resident_id)
	var options: Array[Dictionary] = [
		_inspect(cell),
		_offer(
			&"talk",
			&"talk",
			{&"resident_id": resident_id},
			bool(talk[&"ok"]),
			_reason(talk[&"reason"] as StringName),
			100,
		),
		_read(&"relationship", &"read_relationship", {&"resident_id": resident_id}, 500),
	]
	var gifts: Dictionary = RelationshipServiceScript.GIFT_POINTS.get(resident_id, {}) as Dictionary
	var gift_ids: Array[StringName] = []
	for raw_id: Variant in gifts:
		gift_ids.append(StringName(str(raw_id)))
	gift_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for item_id: StringName in gift_ids:
		var gift: Dictionary = RelationshipServiceScript.gift(farm, resident_id, item_id)
		(
			options
			. append(
				_offer(
					StringName("gift.%s" % str(item_id)),
					&"gift",
					{&"resident_id": resident_id, &"item_id": item_id},
					bool(gift[&"ok"]),
					_reason(gift[&"reason"] as StringName),
					200,
					[{&"cost_id": item_id, &"amount": 1}],
				)
			)
		)
	for request_id: StringName in RelationshipServiceScript.REQUEST_IDS:
		var request: Dictionary = RelationshipServiceScript.request_definition(request_id)
		if request[&"resident_id"] != resident_id:
			continue
		var completion: Dictionary = RelationshipServiceScript.complete_request(farm, request_id)
		(
			options
			. append(
				_offer(
					&"request",
					&"request_complete",
					{&"request_id": request_id},
					bool(completion[&"ok"]),
					_reason(completion[&"reason"] as StringName),
					300,
					[{&"cost_id": request[&"item_id"], &"amount": int(request[&"count"])}],
				)
			)
		)
	for service_id: StringName in ResidentServiceScript.active_services(farm, resident_id):
		(
			options
			. append(
				_read(
					StringName("service.%s" % str(service_id)),
					&"read_service",
					{&"resident_id": resident_id, &"service_id": service_id},
					400,
				)
			)
		)
	return _target(cell, resident_id, &"resident", relation, options)


static func livestock(farm: Dictionary, cell: Vector2i, animal: Dictionary) -> Dictionary:
	var animal_id: StringName = StringName(animal[&"animal_id"])
	var species_id: StringName = StringName(animal[&"species_id"])
	var definition: Dictionary = LivestockServiceScript.definition(species_id)
	if definition.is_empty():
		return {}
	var feed: Dictionary = LivestockServiceScript.feed(farm, animal_id)
	var pet: Dictionary = LivestockServiceScript.pet(farm, animal_id)
	var product: Dictionary = LivestockServiceScript.claim_product(farm, animal_id)
	var options: Array[Dictionary] = [
		_inspect(cell),
		_offer(
			&"animal_feed",
			&"animal_feed",
			{&"animal_id": animal_id},
			bool(feed[&"ok"]),
			_reason(feed[&"reason"] as StringName),
			100,
			[{&"cost_id": definition[&"feed_item_id"], &"amount": 1}],
		),
		_offer(
			&"animal_pet",
			&"animal_pet",
			{&"animal_id": animal_id},
			bool(pet[&"ok"]),
			_reason(pet[&"reason"] as StringName),
			200,
		),
		_offer(
			&"animal_product",
			&"animal_product",
			{&"animal_id": animal_id},
			bool(product[&"ok"]),
			_reason(product[&"reason"] as StringName),
			300,
		),
	]
	return _target(
		cell,
		animal_id,
		&"livestock",
		{&"animal_id": animal_id, &"species_id": species_id, &"bond": int(animal[&"bond"])},
		options,
		&"friendly_fauna",
	)


static func _append_seed_shop(options: Array[Dictionary], farm: Dictionary, active: bool) -> void:
	var shop_items: Array[StringName] = []
	for crop_id: StringName in CropCatalogScript.CROP_IDS:
		var crop: Dictionary = CropCatalogScript.definition(crop_id)
		if &"wild_discovery" in (crop[&"traits"] as Array):
			continue
		var seed_id: StringName = crop[&"seed_item_id"] as StringName
		shop_items.append(seed_id)
	shop_items.append_array(P10_SUPPLIES)
	for seed_id: StringName in shop_items:
		var purchase: Dictionary = EconomyServiceScript.buy_seed(farm, seed_id, 1)
		var enabled: bool = active and bool(purchase[&"ok"])
		var reason: StringName = (
			_reason(purchase[&"reason"] as StringName)
			if active
			else &"interaction.reason.seed_shop_inactive"
		)
		(
			options
			. append(
				_offer(
					StringName("buy_seed.%s" % str(seed_id)),
					&"buy_seed",
					{&"item_id": seed_id, &"count": 1},
					enabled,
					reason,
					400,
					[
						{
							&"cost_id": &"item.currency.credit",
							&"amount": ItemCatalogScript.buy_price(seed_id)
						}
					],
				)
			)
		)


static func _append_upgrades(options: Array[Dictionary], farm: Dictionary) -> void:
	for upgrade_id: StringName in DurableUpgradeCatalogScript.ids():
		var definition: Dictionary = DurableUpgradeCatalogScript.definition(upgrade_id)
		var purchase: Dictionary = DurableUpgradeServiceScript.purchase(farm, upgrade_id)
		var costs: Array[Dictionary] = _upgrade_costs(definition[&"item_costs"] as Array)
		if int(definition[&"money_cost"]) > 0:
			costs.append(
				{&"cost_id": &"item.currency.credit", &"amount": int(definition[&"money_cost"])}
			)
		(
			options
			. append(
				_offer(
					StringName("upgrade.%s" % str(upgrade_id)),
					&"upgrade",
					{&"upgrade_id": upgrade_id},
					bool(purchase[&"ok"]),
					_reason(purchase[&"reason"] as StringName),
					500,
					costs,
				)
			)
		)


static func _tool_offer(
	action: StringName,
	operation: StringName,
	cell: Vector2i,
	required: StringName,
	selected: StringName,
	preview: Dictionary,
	priority: int,
) -> Dictionary:
	var tool_matches: bool = selected == required
	var enabled: bool = tool_matches and bool(preview[&"ok"])
	var reason: StringName = (
		_reason(preview[&"reason"] as StringName)
		if tool_matches
		else StringName("interaction.reason.requires_%s" % str(required).trim_prefix("tool."))
	)
	return _offer(
		action,
		operation,
		{&"cell": cell, &"required_tool": required},
		enabled,
		reason,
		priority,
		[
			{
				&"cost_id": &"tool.stamina",
				&"amount": ToolServiceScript.stamina_cost(preview[&"candidate"], required)
			}
		],
	)


static func _inspect(cell: Vector2i) -> Dictionary:
	return _read(&"inspect", &"inspect", {&"cell": cell}, 0)


static func _read(
	action: StringName, operation: StringName, arguments: Dictionary, priority: int
) -> Dictionary:
	return _offer(action, operation, arguments, true, &"", priority, [], OptionScript.CLOSE_NEVER)


static func _offer(
	action: StringName,
	operation: StringName,
	arguments: Dictionary,
	enabled: bool,
	reason: StringName,
	priority: int,
	costs: Array[Dictionary] = [],
	close: StringName = OptionScript.CLOSE_ON_SUCCESS,
) -> Dictionary:
	return (
		TargetBridgeScript
		. option_input(
			StringName("interaction.action.%s" % str(action)),
			operation,
			arguments,
			enabled,
			reason if not enabled else &"",
			priority,
			costs,
			close,
		)
	)


static func _target(
	cell: Vector2i,
	target_id: StringName,
	subkind: StringName,
	state: Dictionary,
	options: Array[Dictionary],
	kind: StringName = &"structure",
) -> Dictionary:
	var target_kind: StringName = kind
	if kind == &"structure" and subkind in [&"terrain", &"plot", &"crop"]:
		target_kind = subkind
	return (
		TargetScript
		. build(
			cell,
			target_id,
			target_kind,
			subkind,
			StringName("interaction.target.%s.title" % str(subkind)),
			state,
			options,
		)
	)


static func _reason(reason: StringName) -> StringName:
	return (
		&"interaction.reason.unavailable"
		if reason == &""
		else StringName("interaction.reason.%s" % str(reason))
	)


static func _costs(materials: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_id: Variant in materials:
		result.append({&"cost_id": StringName(str(raw_id)), &"amount": int(materials[raw_id])})
	return result


static func _recipe_costs(recipe: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw: Variant in recipe[&"ingredients"] as Array:
		var ingredient: Dictionary = raw as Dictionary
		(
			result
			. append(
				{
					&"cost_id": StringName(str(ingredient[&"item_id"])),
					&"amount": int(ingredient[&"count"]),
				}
			)
		)
	return result


static func _upgrade_costs(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw: Variant in values:
		var cost: Dictionary = raw as Dictionary
		result.append(
			{
				&"cost_id": StringName(str(cost[&"item_id"])),
				&"amount": int(cost[&"count"]),
			}
		)
	return result


static func _machine_state(record: Dictionary) -> Dictionary:
	return {
		&"machine_id": StringName(record[&"machine_id"]),
		&"state": StringName(record[&"state"]),
		&"recipe_id": StringName(record[&"recipe_id"]),
		&"complete_day": int(record[&"complete_day"]),
	}
