extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const CropCatalogScript: GDScript = preload("res://scripts/crop_catalog.gd")
const DurableUpgradeCatalogScript: GDScript = preload("res://scripts/durable_upgrade_catalog.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const RecipeCatalogScript: GDScript = preload("res://scripts/recipe_catalog.gd")
const HomesteadSaveSchemaScript: GDScript = preload("res://scripts/homestead_save_schema.gd")

const STATE_VERSION: int = 1
const MAX_YEAR: int = 9_999
const MAX_DAY: int = 366
const MAX_MINUTE_OF_DAY: int = 1_439
const MAX_MONEY: int = 1_000_000_000
const MAX_PLOTS: int = 4_096
const MAX_INVENTORIES: int = 2
const MAX_SHIPPING_ENTRIES: int = 64
const MAX_PLACED_ENTITIES: int = 4_096
const MAX_MACHINES: int = 128
const MAX_FACILITIES: int = HomesteadSaveSchemaScript.MAX_FACILITIES
const MAX_RESIDENTS: int = HomesteadSaveSchemaScript.MAX_RESIDENTS
const MAX_RUINS: int = HomesteadSaveSchemaScript.MAX_RUINS
const MAX_RELATIONSHIPS: int = HomesteadSaveSchemaScript.MAX_RELATIONSHIPS
const MAX_REQUESTS: int = HomesteadSaveSchemaScript.MAX_REQUESTS
const MAX_ANIMALS: int = HomesteadSaveSchemaScript.MAX_ANIMALS
const MAX_TOOL_UPGRADES: int = 64
const MAX_ECOLOGY_DELTAS: int = 4_096
const MAX_BOSS_CLEARS: int = 256
const MAX_MIGRATION_TOKENS: int = 8
const MAX_DAY_TOKENS: int = 64
const MAX_STACKS_PER_INVENTORY: int = 256
const MAX_STAMINA: int = 100_000
const MAX_GROWTH_POINTS: int = 100_000
const MAX_MACHINE_TOKENS: int = 64
const MAX_ABSOLUTE_DAY: int = MAX_YEAR * 4 * 14

const MACHINE_STATES: Array[StringName] = [
	&"machine.idle", &"machine.running", &"machine.complete"
]
const MACHINE_STATIONS: Dictionary = {
	"machine.home.workbench": "station.workbench",
	"machine.home.furnace": "station.furnace",
}
const MACHINE_KEYS: Array[StringName] = [
	&"machine_id",
	&"station_tag",
	&"cell",
	&"state",
	&"recipe_id",
	&"start_day",
	&"complete_day",
	&"operation_token",
	&"claimed_tokens",
]

const SEASON_NEUTRAL: String = "season.neutral"
const WEATHER_NEUTRAL: String = "weather.neutral"
const VALID_SEASONS: Array[StringName] = [
	&"season.spring", &"season.summer", &"season.autumn", &"season.winter"
]
const VALID_WEATHER: Array[StringName] = [
	&"weather.clear", &"weather.cloudy", &"weather.rain", &"weather.wind"
]
const VALID_TOOLS: Array[StringName] = [&"tool.hoe", &"tool.watering", &"tool.axe", &"tool.pick"]
const PLOT_KEYS: Array[StringName] = [
	&"cell",
	&"tilled",
	&"last_watered_day",
	&"crop_id",
	&"planted_day",
	&"growth_points",
	&"stage",
	&"fertilizer_id",
	&"regrowth_count",
	&"health",
	&"dormant",
	&"harvest_sequence",
	&"ready",
]


static func make_neutral(
	mode: StringName = RuntimeIdsScript.MODE_FRESH_FARM, migrated_from_v3: bool = false
) -> Dictionary:
	var migration_tokens: Array[String] = []
	if migrated_from_v3:
		migration_tokens.append(String(RuntimeIdsScript.MIGRATION_FARM_V3_TO_V4))
	return {
		&"state_version": STATE_VERSION,
		&"mode": String(mode),
		&"calendar_weather":
		{
			&"state_version": STATE_VERSION,
			&"year": 1,
			&"season_id": SEASON_NEUTRAL,
			&"day": 1,
			&"minute_of_day": 0,
			&"current_weather_id": WEATHER_NEUTRAL,
			&"forecast_weather_id": WEATHER_NEUTRAL,
			&"day_token": "",
		},
		&"plots": [],
		&"inventories": [],
		&"economy": {&"state_version": STATE_VERSION, &"money": 0, &"shipping": []},
		&"placed_entities": [],
		&"machines": [],
		&"homestead":
		{
			&"state_version": STATE_VERSION,
			&"facilities": [],
			&"residents": [],
			&"ruins": [],
		},
		&"tools":
		{
			&"state_version": STATE_VERSION,
			&"equipped_tool_id": "",
			&"upgrade_ids": [],
		},
		&"ecology":
		{
			&"state_version": STATE_VERSION,
			&"deltas": [],
			&"boss_first_clear_ids": [],
		},
		&"migration_tokens": migration_tokens,
		&"day_tokens": [],
	}


static func validate(snapshot: Variant) -> Dictionary:
	if not snapshot is Dictionary:
		return {}
	var farm: Dictionary = snapshot as Dictionary
	if not _exact_keys(
		farm,
		[
			&"state_version",
			&"mode",
			&"calendar_weather",
			&"plots",
			&"inventories",
			&"economy",
			&"placed_entities",
			&"machines",
			&"homestead",
			&"tools",
			&"ecology",
			&"migration_tokens",
			&"day_tokens",
		],
	):
		return {}
	var state_version: Variant = _json_integer(
		farm.get(&"state_version"), STATE_VERSION, STATE_VERSION
	)
	var mode: Variant = farm.get(&"mode")
	if (
		state_version == null
		or (not mode is String and not mode is StringName)
		or StringName(str(mode)) not in RuntimeIdsScript.gameplay_mode_ids()
	):
		return {}
	var calendar_weather: Dictionary = _normalize_calendar(farm.get(&"calendar_weather"))
	var economy: Dictionary = _normalize_economy(farm.get(&"economy"))
	var homestead: Dictionary = _normalize_homestead(farm.get(&"homestead"))
	var tools: Dictionary = _normalize_tools(farm.get(&"tools"))
	var ecology: Dictionary = _normalize_ecology(farm.get(&"ecology"))
	var plots: Variant = _normalize_plots(farm.get(&"plots"))
	var inventories: Variant = _normalize_inventories(farm.get(&"inventories"))
	var placed: Variant = _normalize_empty_array(farm.get(&"placed_entities"), MAX_PLACED_ENTITIES)
	var machines: Variant = _normalize_machines(farm.get(&"machines"))
	var migration_tokens: Variant = _normalize_migration_tokens(farm.get(&"migration_tokens"))
	var day_tokens: Variant = _normalize_tokens(farm.get(&"day_tokens"), MAX_DAY_TOKENS, "day:")
	if (
		calendar_weather.is_empty()
		or economy.is_empty()
		or homestead.is_empty()
		or tools.is_empty()
		or ecology.is_empty()
		or plots == null
		or inventories == null
		or placed == null
		or machines == null
		or migration_tokens == null
		or day_tokens == null
	):
		return {}
	return {
		&"state_version": STATE_VERSION,
		&"mode": str(mode),
		&"calendar_weather": calendar_weather,
		&"plots": plots,
		&"inventories": inventories,
		&"economy": economy,
		&"placed_entities": placed,
		&"machines": machines,
		&"homestead": homestead,
		&"tools": tools,
		&"ecology": ecology,
		&"migration_tokens": migration_tokens,
		&"day_tokens": day_tokens,
	}


static func canonical_json(snapshot: Variant) -> String:
	var normalized: Dictionary = validate(snapshot)
	return "" if normalized.is_empty() else JSON.stringify(normalized, "", true, true)


static func mode_of(snapshot: Variant) -> StringName:
	var normalized: Dictionary = validate(snapshot)
	return &"" if normalized.is_empty() else StringName(str(normalized[&"mode"]))


static func _normalize_calendar(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var calendar: Dictionary = value as Dictionary
	if not _exact_keys(
		calendar,
		[
			&"state_version",
			&"year",
			&"season_id",
			&"day",
			&"minute_of_day",
			&"current_weather_id",
			&"forecast_weather_id",
			&"day_token",
		],
	):
		return {}
	var state_version: Variant = _json_integer(
		calendar.get(&"state_version"), STATE_VERSION, STATE_VERSION
	)
	var year: Variant = _json_integer(calendar.get(&"year"), 1, MAX_YEAR)
	var day: Variant = _json_integer(calendar.get(&"day"), 1, MAX_DAY)
	var minute: Variant = _json_integer(calendar.get(&"minute_of_day"), 0, MAX_MINUTE_OF_DAY)
	if state_version == null or year == null or day == null or minute == null:
		return {}
	var season_id: StringName = StringName(str(calendar.get(&"season_id")))
	var current_weather: StringName = StringName(str(calendar.get(&"current_weather_id")))
	var forecast_weather: StringName = StringName(str(calendar.get(&"forecast_weather_id")))
	var day_token: Variant = calendar.get(&"day_token")
	if season_id == StringName(SEASON_NEUTRAL):
		if (
			current_weather != StringName(WEATHER_NEUTRAL)
			or forecast_weather != StringName(WEATHER_NEUTRAL)
			or day_token != ""
		):
			return {}
	else:
		if (
			season_id not in VALID_SEASONS
			or current_weather not in VALID_WEATHER
			or forecast_weather not in VALID_WEATHER
			or not day_token is String
			or not str(day_token).begins_with("day:")
		):
			return {}
	return {
		&"state_version": STATE_VERSION,
		&"year": int(year),
		&"season_id": String(season_id),
		&"day": int(day),
		&"minute_of_day": int(minute),
		&"current_weather_id": String(current_weather),
		&"forecast_weather_id": String(forecast_weather),
		&"day_token": str(day_token),
	}


static func _normalize_economy(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var economy: Dictionary = value as Dictionary
	var keys: Array[StringName] = [&"state_version", &"money", &"shipping"]
	var active: bool = economy.has(&"last_settlement_total") or economy.has(&"settlement_tokens")
	if active:
		keys.append_array([&"last_settlement_total", &"settlement_tokens"])
	if not _exact_keys(economy, keys):
		return {}
	var state_version: Variant = _json_integer(
		economy.get(&"state_version"), STATE_VERSION, STATE_VERSION
	)
	var money: Variant = _json_integer(economy.get(&"money"), 0, MAX_MONEY)
	var shipping: Variant = _normalize_shipping(economy.get(&"shipping"))
	var settlement_total: Variant = _json_integer(
		economy.get(&"last_settlement_total", 0), 0, MAX_MONEY
	)
	var settlement_tokens: Variant = _normalize_tokens(
		economy.get(&"settlement_tokens", []), MAX_DAY_TOKENS, "day:"
	)
	if (
		state_version == null
		or money == null
		or shipping == null
		or settlement_total == null
		or settlement_tokens == null
	):
		return {}
	var result: Dictionary = {
		&"state_version": STATE_VERSION,
		&"money": int(money),
		&"shipping": shipping,
	}
	if active:
		result[&"last_settlement_total"] = int(settlement_total)
		result[&"settlement_tokens"] = settlement_tokens
	return result




static func _normalize_homestead(value: Variant) -> Dictionary:
	return HomesteadSaveSchemaScript.normalize(value)


static func _normalize_tools(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var tools: Dictionary = value as Dictionary
	var keys: Array[StringName] = [&"state_version", &"equipped_tool_id", &"upgrade_ids"]
	var active: bool = tools.has(&"stamina") or tools.has(&"max_stamina")
	if active:
		keys.append_array([&"stamina", &"max_stamina"])
	if not _exact_keys(tools, keys):
		return {}
	var state_version: Variant = _json_integer(
		tools.get(&"state_version"), STATE_VERSION, STATE_VERSION
	)
	var upgrades: Variant = _normalize_upgrade_ids(tools.get(&"upgrade_ids"))
	var equipped: StringName = StringName(str(tools.get(&"equipped_tool_id", "")))
	var stamina: Variant = _json_integer(tools.get(&"stamina", 0), 0, MAX_STAMINA)
	var max_stamina: Variant = _json_integer(tools.get(&"max_stamina", 0), 0, MAX_STAMINA)
	if (
		state_version == null
		or upgrades == null
		or stamina == null
		or max_stamina == null
		or (not active and equipped != &"")
		or (active and equipped not in VALID_TOOLS)
		or (active and (int(max_stamina) <= 0 or int(stamina) > int(max_stamina)))
	):
		return {}
	var result: Dictionary = {
		&"state_version": STATE_VERSION,
		&"equipped_tool_id": String(equipped),
		&"upgrade_ids": upgrades,
	}
	if active:
		result[&"stamina"] = int(stamina)
		result[&"max_stamina"] = int(max_stamina)
	return result


static func _normalize_ecology(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var ecology: Dictionary = value as Dictionary
	if not _exact_keys(ecology, [&"state_version", &"deltas", &"boss_first_clear_ids"]):
		return {}
	var state_version: Variant = _json_integer(
		ecology.get(&"state_version"), STATE_VERSION, STATE_VERSION
	)
	var deltas: Variant = _normalize_empty_array(ecology.get(&"deltas"), MAX_ECOLOGY_DELTAS)
	var boss_clears: Variant = _normalize_empty_array(
		ecology.get(&"boss_first_clear_ids"), MAX_BOSS_CLEARS
	)
	if state_version == null or deltas == null or boss_clears == null:
		return {}
	return {
		&"state_version": STATE_VERSION,
		&"deltas": deltas,
		&"boss_first_clear_ids": boss_clears,
	}


static func _normalize_inventories(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_INVENTORIES:
		return null
	var result: Array[Dictionary] = []
	var seen_containers: Dictionary = {}
	for raw_inventory: Variant in value as Array:
		var inventory: Dictionary = (
			raw_inventory as Dictionary if raw_inventory is Dictionary else {}
		)
		if not _exact_keys(inventory, [&"container_id", &"capacity_slots", &"stacks"]):
			return null
		var container_id: String = str(inventory[&"container_id"])
		var capacity: Variant = _json_integer(
			inventory[&"capacity_slots"], 1, MAX_STACKS_PER_INVENTORY
		)
		if (
			container_id not in ["inventory.robot", "inventory.home"]
			or seen_containers.has(container_id)
			or capacity == null
		):
			return null
		var stacks: Variant = _normalize_stacks(inventory[&"stacks"], int(capacity))
		if stacks == null:
			return null
		seen_containers[container_id] = true
		(
			result
			. append(
				{
					&"container_id": container_id,
					&"capacity_slots": int(capacity),
					&"stacks": stacks,
				}
			)
		)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"container_id"]) < str(b[&"container_id"])
	)
	return result


static func _normalize_stacks(value: Variant, capacity: int) -> Variant:
	if not value is Array or (value as Array).size() > capacity:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_stack: Variant in value as Array:
		var stack: Dictionary = raw_stack as Dictionary if raw_stack is Dictionary else {}
		if not _exact_keys(stack, [&"item_id", &"count"]):
			return null
		var item_id: StringName = StringName(str(stack[&"item_id"]))
		var count: Variant = _json_integer(
			stack[&"count"], 1, ItemCatalogScript.stack_limit(item_id)
		)
		if item_id not in ItemCatalogScript.ids() or seen.has(item_id) or count == null:
			return null
		seen[item_id] = true
		result.append({&"item_id": String(item_id), &"count": int(count)})
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return str(a[&"item_id"]) < str(b[&"item_id"])
	)
	return result


static func _normalize_plots(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_PLOTS:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_plot: Variant in value as Array:
		var plot: Dictionary = raw_plot as Dictionary if raw_plot is Dictionary else {}
		if not _exact_keys(plot, PLOT_KEYS):
			return null
		var cell: Variant = _normalize_cell(plot[&"cell"])
		var crop_id: StringName = StringName(str(plot[&"crop_id"]))
		var watered: Variant = _json_integer(plot[&"last_watered_day"], 0, MAX_YEAR * MAX_DAY)
		var planted: Variant = _json_integer(plot[&"planted_day"], 0, MAX_YEAR * MAX_DAY)
		var growth: Variant = _json_integer(plot[&"growth_points"], 0, MAX_GROWTH_POINTS)
		var stage: Variant = _json_integer(plot[&"stage"], 0, 3)
		var regrowth: Variant = _json_integer(plot[&"regrowth_count"], 0, MAX_GROWTH_POINTS)
		var health: Variant = _json_integer(plot[&"health"], 0, 100)
		var harvest_sequence: Variant = _json_integer(
			plot[&"harvest_sequence"], 0, MAX_GROWTH_POINTS
		)
		if (
			cell == null
			or watered == null
			or planted == null
			or growth == null
			or stage == null
			or regrowth == null
			or health == null
			or harvest_sequence == null
		):
			return null
		var key: String = "%d,%d" % [int(cell[0]), int(cell[1])]
		if (
			seen.has(key)
			or not plot[&"tilled"] is bool
			or not bool(plot[&"tilled"])
			or not plot[&"dormant"] is bool
			or not plot[&"ready"] is bool
		):
			return null
		if not plot[&"fertilizer_id"] is String or not str(plot[&"fertilizer_id"]).is_empty():
			return null
		if crop_id != &"" and crop_id not in CropCatalogScript.CROP_IDS:
			return null
		if (
			crop_id == &""
			and (int(planted) != 0 or int(growth) != 0 or int(stage) != 0 or bool(plot[&"ready"]))
		):
			return null
		if crop_id != &"" and int(stage) != CropCatalogScript.stage_for(crop_id, int(growth)):
			return null
		seen[key] = true
		(
			result
			. append(
				{
					&"cell": cell,
					&"tilled": true,
					&"last_watered_day": int(watered),
					&"crop_id": String(crop_id),
					&"planted_day": int(planted),
					&"growth_points": int(growth),
					&"stage": int(stage),
					&"fertilizer_id": "",
					&"regrowth_count": int(regrowth),
					&"health": int(health),
					&"dormant": bool(plot[&"dormant"]),
					&"harvest_sequence": int(harvest_sequence),
					&"ready": bool(plot[&"ready"]),
				}
			)
		)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return _cell_precedes(a[&"cell"] as Array, b[&"cell"] as Array)
	)
	return result


static func _normalize_shipping(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_SHIPPING_ENTRIES:
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_entry: Variant in value as Array:
		var entry: Dictionary = raw_entry as Dictionary if raw_entry is Dictionary else {}
		if not _exact_keys(entry, [&"item_id", &"count"]):
			return null
		var item_id: StringName = StringName(str(entry[&"item_id"]))
		var count: Variant = _json_integer(
			entry[&"count"], 1, ItemCatalogScript.stack_limit(item_id)
		)
		if ItemCatalogScript.sell_price(item_id) <= 0 or seen.has(item_id) or count == null:
			return null
		seen[item_id] = true
		result.append({&"item_id": String(item_id), &"count": int(count)})
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return str(a[&"item_id"]) < str(b[&"item_id"])
	)
	return result


static func _normalize_upgrade_ids(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_TOOL_UPGRADES:
		return null
	var result: Array[String] = []
	for raw_upgrade: Variant in value as Array:
		if (
			(not raw_upgrade is String and not raw_upgrade is StringName)
			or StringName(str(raw_upgrade)) not in DurableUpgradeCatalogScript.ids()
			or str(raw_upgrade) in result
		):
			return null
		result.append(str(raw_upgrade))
	result.sort()
	return result


static func _normalize_machines(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_MACHINES:
		return null
	var result: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var seen_cells: Dictionary = {}
	for raw_machine: Variant in value as Array:
		var machine: Dictionary = raw_machine as Dictionary if raw_machine is Dictionary else {}
		if not _exact_keys(machine, MACHINE_KEYS):
			return null
		var machine_id: String = str(machine[&"machine_id"])
		var station_tag: StringName = StringName(str(machine[&"station_tag"]))
		var state: StringName = StringName(str(machine[&"state"]))
		var recipe_id: StringName = StringName(str(machine[&"recipe_id"]))
		var cell: Variant = _normalize_cell(machine[&"cell"])
		var start_day: Variant = _json_integer(machine[&"start_day"], 0, MAX_ABSOLUTE_DAY)
		var complete_day: Variant = _json_integer(machine[&"complete_day"], 0, MAX_ABSOLUTE_DAY)
		var operation_token: Variant = machine[&"operation_token"]
		var claimed_tokens: Variant = _normalize_machine_tokens(machine[&"claimed_tokens"])
		if (
			not MACHINE_STATIONS.has(machine_id)
			or seen_ids.has(machine_id)
			or station_tag not in RecipeCatalogScript.STATION_TAGS
			or StringName(MACHINE_STATIONS[machine_id]) != station_tag
			or state not in MACHINE_STATES
			or cell == null
			or start_day == null
			or complete_day == null
			or not operation_token is String
			or (operation_token as String).length() > 128
			or claimed_tokens == null
		):
			return null
		var cell_key: String = "%d,%d" % [int(cell[0]), int(cell[1])]
		if seen_cells.has(cell_key):
			return null
		var is_idle: bool = state == &"machine.idle"
		var recipe: Dictionary = RecipeCatalogScript.definition(recipe_id)
		var expected_token: String = "%s:%d:%s" % [machine_id, int(start_day), String(recipe_id)]
		if is_idle:
			if recipe_id != &"" or int(start_day) != 0 or int(complete_day) != 0 or operation_token != "":
				return null
		elif (
			recipe.is_empty()
			or StringName(recipe[&"station_tag"]) != station_tag
			or int(start_day) <= 0
			or int(complete_day) != int(start_day) + int(recipe[&"duration_days"])
			or str(operation_token).is_empty()
			or str(operation_token) != expected_token
			or operation_token in (claimed_tokens as Array)
		):
			return null
		seen_ids[machine_id] = true
		seen_cells[cell_key] = true
		result.append(
			{
				&"machine_id": machine_id,
				&"station_tag": String(station_tag),
				&"cell": cell,
				&"state": String(state),
				&"recipe_id": String(recipe_id),
				&"start_day": int(start_day),
				&"complete_day": int(complete_day),
				&"operation_token": str(operation_token),
				&"claimed_tokens": claimed_tokens,
			}
		)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"machine_id"]) < str(b[&"machine_id"])
	)
	return result


static func _normalize_machine_tokens(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_MACHINE_TOKENS:
		return null
	var result: Array[String] = []
	for raw_token: Variant in value as Array:
		if (
			not raw_token is String
			or str(raw_token).is_empty()
			or str(raw_token).length() > 128
			or raw_token in result
		):
			return null
		result.append(str(raw_token))
	result.sort()
	return result


static func _normalize_migration_tokens(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() > MAX_MIGRATION_TOKENS:
		return null
	var result: Array[String] = []
	for raw_token: Variant in value as Array:
		if not raw_token is String and not raw_token is StringName:
			return null
		var token: StringName = StringName(str(raw_token))
		if token != RuntimeIdsScript.MIGRATION_FARM_V3_TO_V4 or String(token) in result:
			return null
		result.append(String(token))
	result.sort()
	return result


static func _normalize_tokens(value: Variant, maximum_size: int, prefix: String) -> Variant:
	if not value is Array or (value as Array).size() > maximum_size:
		return null
	var result: Array[String] = []
	for raw_token: Variant in value as Array:
		if not raw_token is String or not str(raw_token).begins_with(prefix) or raw_token in result:
			return null
		result.append(str(raw_token))
	return result


static func _normalize_empty_array(value: Variant, maximum_size: int) -> Variant:
	if (
		not value is Array
		or (value as Array).size() > maximum_size
		or not (value as Array).is_empty()
	):
		return null
	return []


static func _normalize_cell(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() != 2:
		return null
	var x: Variant = _json_integer(value[0], -1_000_000, 1_000_000)
	var y: Variant = _json_integer(value[1], -1_000_000, 1_000_000)
	return null if x == null or y == null else [int(x), int(y)]


static func _json_integer(value: Variant, minimum: int, maximum: int) -> Variant:
	if not value is int and not value is float:
		return null
	var number: float = float(value)
	if not is_finite(number) or number != floor(number) or number < minimum or number > maximum:
		return null
	return int(number)


static func _cell_precedes(first: Array, second: Array) -> bool:
	return first[1] < second[1] or (first[1] == second[1] and first[0] < second[0])


static func _exact_keys(value: Dictionary, expected: Array[StringName]) -> bool:
	if value.size() != expected.size():
		return false
	for key: StringName in expected:
		if not value.has(key):
			return false
	return true
