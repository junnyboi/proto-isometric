extends RefCounted

const CropCatalogScript: GDScript = preload("res://scripts/crop_catalog.gd")
const FarmOccupancyScript: GDScript = preload("res://scripts/farm_occupancy_service.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")
const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")
const IronjawDesertArcScript: GDScript = preload("res://scripts/ironjaw_desert_arc.gd")

const CHUNK_SIZE: int = 8


static func till(farm: Dictionary, cell: Vector2i) -> Dictionary:
	var tillable: bool = (
		WoodlandClearingScript.is_farm_apron(cell)
		or (IronjawDesertArcScript.deep_tillable(farm, cell))
	)
	if not tillable or _plot_index(farm, cell) >= 0:
		return _result(false, farm, &"not_tillable", [])
	if (
		FarmOccupancyScript.occupied(farm, cell)
		or (
			WoodlandClearingScript.is_farm_apron(cell)
			and FarmOccupancyScript.orchard_reason(farm, cell) == &"protected_path"
		)
	):
		return _result(false, farm, &"not_tillable", [])
	var spent: Dictionary = ToolServiceScript.spend(farm, ToolServiceScript.TOOL_HOE)
	if not bool(spent[&"ok"]):
		return _result(false, farm, spent[&"reason"] as StringName, [])
	var candidate: Dictionary = spent[&"candidate"] as Dictionary
	var plots: Array = (candidate[&"plots"] as Array).duplicate(true)
	plots.append(_make_plot(cell))
	plots.sort_custom(_plot_less)
	candidate[&"plots"] = plots
	return _result(true, candidate, &"", [cell])


static func water(farm: Dictionary, cell: Vector2i, absolute_day: int) -> Dictionary:
	var plot_index: int = _plot_index(farm, cell)
	if (
		plot_index < 0
		or (
			int(((farm[&"plots"] as Array)[plot_index] as Dictionary)[&"last_watered_day"])
			== absolute_day
		)
	):
		return _result(false, farm, &"not_waterable", [])
	var spent: Dictionary = ToolServiceScript.spend(farm, ToolServiceScript.TOOL_WATERING)
	if not bool(spent[&"ok"]):
		return _result(false, farm, spent[&"reason"] as StringName, [])
	var candidate: Dictionary = spent[&"candidate"] as Dictionary
	var plots: Array = (candidate[&"plots"] as Array).duplicate(true)
	var plot: Dictionary = (plots[plot_index] as Dictionary).duplicate(true)
	plot[&"last_watered_day"] = absolute_day
	plots[plot_index] = plot
	candidate[&"plots"] = plots
	return _result(true, candidate, &"", [cell])


static func plant(
	farm: Dictionary, cell: Vector2i, seed_item_id: StringName, absolute_day: int
) -> Dictionary:
	var plot_index: int = _plot_index(farm, cell)
	var crop_id: StringName = CropCatalogScript.crop_for_seed(seed_item_id)
	if plot_index < 0 or crop_id == &"":
		return _result(false, farm, &"invalid_seed_target", [])
	var plot: Dictionary = (farm[&"plots"] as Array)[plot_index] as Dictionary
	if not str(plot[&"crop_id"]).is_empty():
		return _result(false, farm, &"plot_occupied", [])
	var removed: Dictionary = InventoryServiceScript.remove(
		farm, InventoryServiceScript.ROBOT_ID, seed_item_id, 1
	)
	if not bool(removed[&"ok"]):
		return _result(false, farm, &"missing_seed", [])
	var candidate: Dictionary = removed[&"candidate"] as Dictionary
	var plots: Array = (candidate[&"plots"] as Array).duplicate(true)
	plot = (plots[plot_index] as Dictionary).duplicate(true)
	plot[&"crop_id"] = String(crop_id)
	plot[&"planted_day"] = absolute_day
	plot[&"growth_points"] = 0
	plot[&"stage"] = 0
	plot[&"harvest_sequence"] = 0
	plot[&"ready"] = false
	var calendar: Dictionary = candidate[&"calendar_weather"] as Dictionary
	plot[&"dormant"] = not CropCatalogScript.is_favored(
		crop_id, StringName(str(calendar[&"season_id"]))
	)
	plots[plot_index] = plot
	candidate[&"plots"] = plots
	return _result(true, candidate, &"", [cell])


static func harvest(farm: Dictionary, cell: Vector2i) -> Dictionary:
	var plot_index: int = _plot_index(farm, cell)
	if plot_index < 0:
		return _result(false, farm, &"missing_crop", [])
	var plot: Dictionary = (farm[&"plots"] as Array)[plot_index] as Dictionary
	var crop_id: StringName = StringName(plot[&"crop_id"])
	if crop_id == &"" or not bool(plot[&"ready"]):
		return _result(false, farm, &"crop_not_ready", [])
	var crop: Dictionary = CropCatalogScript.definition(crop_id)
	var yield_count: int = (
		CropCatalogScript
		. deterministic_yield(
			crop_id,
			cell,
			int(plot[&"planted_day"]),
			int(plot[&"harvest_sequence"]),
		)
	)
	var spent: Dictionary = ToolServiceScript.spend(farm, ToolServiceScript.TOOL_CONTEXT)
	if not bool(spent[&"ok"]):
		return _result(false, farm, spent[&"reason"] as StringName, [])
	var credited: Dictionary = (
		InventoryServiceScript
		. credit_with_overflow(
			spent[&"candidate"] as Dictionary,
			crop[&"produce_item_id"] as StringName,
			yield_count,
		)
	)
	if not bool(credited[&"ok"]):
		return _result(false, farm, &"inventory_full", [])
	var candidate: Dictionary = credited[&"candidate"] as Dictionary
	var plots: Array = (candidate[&"plots"] as Array).duplicate(true)
	plot = (plots[plot_index] as Dictionary).duplicate(true)
	plot[&"harvest_sequence"] = int(plot[&"harvest_sequence"]) + 1
	plot[&"ready"] = false
	if int(crop[&"regrow_days"]) > 0:
		plot[&"growth_points"] = int((crop[&"stage_growth"] as Array)[2])
		plot[&"stage"] = 2
	else:
		plot[&"crop_id"] = ""
		plot[&"planted_day"] = 0
		plot[&"growth_points"] = 0
		plot[&"stage"] = 0
	plots[plot_index] = plot
	candidate[&"plots"] = plots
	var result: Dictionary = _result(true, candidate, &"", [cell])
	result[&"yield_count"] = yield_count
	result[&"produce_item_id"] = crop[&"produce_item_id"]
	return result


static func apply_rain(farm: Dictionary, absolute_day: int) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var plots: Array = (candidate[&"plots"] as Array).duplicate(true)
	for index: int in plots.size():
		var plot: Dictionary = (plots[index] as Dictionary).duplicate(true)
		plot[&"last_watered_day"] = absolute_day
		plots[index] = plot
	candidate[&"plots"] = plots
	return candidate


static func grow(farm: Dictionary, watered_day: int) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var plots: Array = (candidate[&"plots"] as Array).duplicate(true)
	var calendar: Dictionary = candidate[&"calendar_weather"] as Dictionary
	var season_id: StringName = StringName(str(calendar[&"season_id"]))
	for index: int in plots.size():
		var plot: Dictionary = (plots[index] as Dictionary).duplicate(true)
		var crop_id: StringName = StringName(plot[&"crop_id"])
		if crop_id == &"" or bool(plot[&"ready"]):
			continue
		var increment: int = CropCatalogScript.growth_increment(crop_id, season_id)
		plot[&"dormant"] = increment == 0
		if increment == 0 or int(plot[&"last_watered_day"]) != watered_day:
			plots[index] = plot
			continue
		plot[&"growth_points"] = int(plot[&"growth_points"]) + increment
		plot[&"stage"] = CropCatalogScript.stage_for(crop_id, int(plot[&"growth_points"]))
		plot[&"ready"] = int(plot[&"stage"]) == 3
		plots[index] = plot
	candidate[&"plots"] = plots
	return candidate


static func plot_at(farm: Dictionary, cell: Vector2i) -> Dictionary:
	var index: int = _plot_index(farm, cell)
	return {} if index < 0 else ((farm[&"plots"] as Array)[index] as Dictionary).duplicate(true)


static func build_chunk_indexes(farm: Dictionary) -> Dictionary:
	var indexes: Dictionary = {}
	for plot: Dictionary in farm.get(&"plots", []) as Array[Dictionary]:
		var raw_cell: Array = plot[&"cell"] as Array
		var cell: Vector2i = Vector2i(int(raw_cell[0]), int(raw_cell[1]))
		var chunk: Vector2i = Vector2i(
			floori(float(cell.x) / CHUNK_SIZE), floori(float(cell.y) / CHUNK_SIZE)
		)
		if not indexes.has(chunk):
			indexes[chunk] = []
		(indexes[chunk] as Array).append(
			{&"cell": cell, &"type": &"soil", &"stable_id": "plot:%d,%d" % [cell.x, cell.y]}
		)
		var crop_id: StringName = StringName(plot[&"crop_id"])
		if crop_id != &"":
			var crop: Dictionary = CropCatalogScript.definition(crop_id)
			(
				(indexes[chunk] as Array)
				. append(
					{
						&"cell": cell,
						&"type": &"crop",
						&"stable_id": "%s:%d,%d" % [crop_id, cell.x, cell.y],
						&"texture": load(str(crop[&"texture_path"])) as Texture2D,
						&"atlas_region": Rect2(int(plot[&"stage"]) * 256, 0, 256, 256),
						&"draw_size": Vector2(100.0, 100.0),
						&"draw_offset": Vector2(0.0, -34.0),
					}
				)
			)
	return indexes


static func _make_plot(cell: Vector2i) -> Dictionary:
	return {
		&"cell": [cell.x, cell.y],
		&"tilled": true,
		&"last_watered_day": 0,
		&"crop_id": "",
		&"planted_day": 0,
		&"growth_points": 0,
		&"stage": 0,
		&"fertilizer_id": "",
		&"regrowth_count": 0,
		&"health": 100,
		&"dormant": false,
		&"harvest_sequence": 0,
		&"ready": false,
	}


static func _plot_index(farm: Dictionary, cell: Vector2i) -> int:
	var plots: Array = farm.get(&"plots", []) as Array
	for index: int in plots.size():
		var raw_cell: Array = (plots[index] as Dictionary)[&"cell"] as Array
		if Vector2i(int(raw_cell[0]), int(raw_cell[1])) == cell:
			return index
	return -1


static func _plot_less(first: Dictionary, second: Dictionary) -> bool:
	var a: Array = first[&"cell"] as Array
	var b: Array = second[&"cell"] as Array
	return int(a[1]) < int(b[1]) or (int(a[1]) == int(b[1]) and int(a[0]) < int(b[0]))


static func _result(
	ok: bool, farm: Dictionary, reason: StringName, dirty_cells: Array[Vector2i]
) -> Dictionary:
	return {
		&"ok": ok,
		&"candidate": farm.duplicate(true),
		&"reason": reason,
		&"dirty_cells": dirty_cells.duplicate(),
	}
