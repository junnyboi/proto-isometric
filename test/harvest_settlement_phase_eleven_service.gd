extends RefCounted

const BudgetScript: GDScript = preload("res://scripts/persistence_budget_catalog.gd")
const CalendarScript: GDScript = preload("res://scripts/calendar_state.gd")
const DayAdvanceScript: GDScript = preload("res://scripts/day_advance_service.gd")
const FarmSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const FishingCatalogScript: GDScript = preload("res://scripts/fishing_catalog.gd")
const FishingScript: GDScript = preload("res://scripts/fishing_service.gd")
const InventoryScript: GDScript = preload("res://scripts/inventory_service.gd")
const OrchardScript: GDScript = preload("res://scripts/orchard_service.gd")
const StateHashScript: GDScript = preload("res://scripts/persistence_state_hash.gd")

const FARM_CELL: Vector2i = Vector2i(10, 8)
const TREE_CELL: Vector2i = Vector2i(10, 7)
const WORLD_SEED: int = 902_011


static func run(base: Dictionary, days: int, run_id: String) -> Dictionary:
	if base.is_empty() or days <= 0:
		return _result(false, {}, "invalid_schedule_source")
	var farm: Dictionary = _prepare_representative_farm(base[&"farm"] as Dictionary)
	if farm.is_empty():
		return _result(false, {}, "representative_setup_invalid")
	for offset: int in days:
		farm = _apply_daily_actions(farm, offset)
		var advanced: Dictionary = DayAdvanceScript.build_candidate(farm, WORLD_SEED)
		if not bool(advanced.get(&"ok", false)):
			return _result(
				false,
				{},
				"day_%d:%s" % [offset + 1, str(advanced.get(&"reason", "rejected"))],
			)
		farm = advanced[&"candidate"] as Dictionary
		if (offset + 1) % 100 == 0:
			if FarmSchemaScript.validate(farm).is_empty():
				return _result(false, {}, "day_%d:schema_invalid" % (offset + 1))
			print("[P11_SCHEDULE_PROGRESS] run=%s day=%d" % [run_id, offset + 1])
	var final_candidate: Dictionary = base.duplicate(true)
	final_candidate[&"farm"] = farm
	var final: Dictionary = StateHashScript.apply_next(base, final_candidate)
	if final.is_empty() or not StateHashScript.result_hash_matches(final):
		return _result(false, {}, "final_hash_invalid")
	var preflight: Dictionary = BudgetScript.preflight(final)
	if not bool(preflight.get(&"ok", false)):
		return _result(false, {}, "final_budget:%s" % str(preflight.get(&"reason", "")))
	return {
		&"ok": true,
		&"envelope": final,
		&"hash": StateHashScript.state_hash(final),
		&"bytes": int(preflight[&"bytes"]),
		&"reason": "",
	}


static func _prepare_representative_farm(source: Dictionary) -> Dictionary:
	var farm: Dictionary = source.duplicate(true)
	farm = _candidate_or_same(FarmStateScript.till(farm, FARM_CELL), farm)
	farm = _candidate_or_same(
		FarmStateScript.plant(farm, FARM_CELL, &"item.seed.glowroot", _absolute_day(farm)), farm
	)
	farm = _candidate_or_same(FarmStateScript.water(farm, FARM_CELL, _absolute_day(farm)), farm)
	for item_id: StringName in [
		&"item.tool.fishing_rod",
		&"item.bait.luminous",
		&"item.sapling.ironbark",
	]:
		var count: int = 24 if item_id == &"item.bait.luminous" else 1
		farm = _candidate_or_same(InventoryScript.credit_with_overflow(farm, item_id, count), farm)
	var planted: Dictionary = OrchardScript.plant(
		farm, TREE_CELL, &"item.sapling.ironbark", _absolute_day(farm),
		func(_cell: Vector2i) -> bool: return true,
	)
	farm = _candidate_or_same(planted, farm)
	return FarmSchemaScript.validate(farm)


static func _apply_daily_actions(source: Dictionary, offset: int) -> Dictionary:
	var farm: Dictionary = source.duplicate(true)
	var plot: Dictionary = FarmStateScript.plot_at(farm, FARM_CELL)
	if bool(plot.get(&"ready", false)):
		farm = _candidate_or_same(FarmStateScript.harvest(farm, FARM_CELL), farm)
		plot = FarmStateScript.plot_at(farm, FARM_CELL)
	if str(plot.get(&"crop_id", "")).is_empty():
		farm = _candidate_or_same(
			FarmStateScript.plant(farm, FARM_CELL, &"item.seed.glowroot", _absolute_day(farm)),
			farm,
		)
	farm = _candidate_or_same(FarmStateScript.water(farm, FARM_CELL, _absolute_day(farm)), farm)
	if offset % 7 == 0:
		farm = _candidate_or_same(
			FishingScript.cast(
				farm, FishingCatalogScript.WOODLAND_POND, _absolute_day(farm), WORLD_SEED, true
			),
			farm,
		)
	if offset % 40 == 39:
		var tree: Dictionary = OrchardScript.tree_at(farm, TREE_CELL)
		if not tree.is_empty():
			farm = _candidate_or_same(
				OrchardScript.harvest(farm, StringName(str(tree[&"tree_id"]))), farm
			)
	return farm


static func _candidate_or_same(result: Dictionary, fallback: Dictionary) -> Dictionary:
	return (
		(result[&"candidate"] as Dictionary).duplicate(true)
		if bool(result.get(&"ok", false))
		else fallback.duplicate(true)
	)


static func _absolute_day(farm: Dictionary) -> int:
	return CalendarScript.absolute_day(farm[&"calendar_weather"] as Dictionary)


static func _result(ok: bool, envelope: Dictionary, reason: String) -> Dictionary:
	return {
		&"ok": ok,
		&"envelope": envelope.duplicate(true),
		&"hash": "",
		&"bytes": 0,
		&"reason": reason,
	}
