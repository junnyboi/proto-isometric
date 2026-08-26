extends RefCounted

const ApplicantLifecycleScript: GDScript = preload(
	"res://scripts/applicant_lifecycle_service.gd"
)
const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const ConstructionDayScript: GDScript = preload("res://scripts/construction_day_service.gd")
const EconomyServiceScript: GDScript = preload("res://scripts/economy_service.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const GatheringStateScript: GDScript = preload("res://scripts/gathering_state_service.gd")
const GatheringExtractionScript: GDScript = preload(
	"res://scripts/gathering_extraction_service.gd"
)
const MachineServiceScript: GDScript = preload("res://scripts/machine_service.gd")
const LogisticsServiceScript: GDScript = preload("res://scripts/logistics_service.gd")
const ProductionPolicyScript: GDScript = preload(
	"res://scripts/production_policy_service.gd"
)
const ResidentServiceScript: GDScript = preload("res://scripts/resident_service.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")
const WellbeingServiceScript: GDScript = preload("res://scripts/wellbeing_service.gd")


static func build_candidate(
	farm: Dictionary,
	world_seed: int = CalendarStateScript.DEFAULT_WORLD_SEED,
	requested_token: String = "",
	source_resolver: Callable = Callable(),
	work_safety_resolver: Callable = Callable(),
) -> Dictionary:
	var source: Dictionary = farm.duplicate(true)
	var calendar: Dictionary = source[&"calendar_weather"] as Dictionary
	var token: String = str(calendar[&"day_token"])
	var callback_token: String = token if requested_token.is_empty() else requested_token
	if (
		callback_token.is_empty()
		or callback_token != token
		or callback_token in (source[&"day_tokens"] as Array)
	):
		return {
			&"ok": false,
			&"candidate": source,
			&"day_token": callback_token,
			&"reason": &"day_already_advanced"
		}
	var candidate: Dictionary = source.duplicate(true)
	var current_absolute: int = CalendarStateScript.absolute_day(calendar)
	if StringName(calendar[&"forecast_weather_id"]) == &"weather.rain":
		candidate = FarmStateScript.apply_rain(candidate, current_absolute)
	candidate = FarmStateScript.grow(candidate, current_absolute)
	candidate = WellbeingServiceScript.reconcile_recovery(candidate, current_absolute)
	var construction: Dictionary = ConstructionDayScript.advance(candidate)
	if not bool(construction[&"ok"]):
		return {
			&"ok": false,
			&"candidate": source,
			&"day_token": token,
			&"reason": construction[&"reason"],
		}
	candidate = construction[&"candidate"] as Dictionary
	var extracted: Dictionary = GatheringExtractionScript.advance(
		candidate,
		world_seed,
		current_absolute,
		source_resolver,
		work_safety_resolver,
	)
	if not bool(extracted[&"ok"]):
		return {
			&"ok": false, &"candidate": source, &"day_token": token,
			&"reason": extracted[&"reason"],
		}
	candidate = extracted[&"candidate"] as Dictionary
	var logistics: Dictionary = LogisticsServiceScript.advance(candidate, current_absolute)
	if not bool(logistics[&"ok"]):
		return {
			&"ok": false, &"candidate": source, &"day_token": token,
			&"reason": logistics[&"reason"],
		}
	candidate = logistics[&"candidate"] as Dictionary
	var production: Dictionary = ProductionPolicyScript.advance(candidate, current_absolute)
	if not bool(production[&"ok"]):
		return {
			&"ok": false, &"candidate": source, &"day_token": token,
			&"reason": production[&"reason"],
		}
	candidate = production[&"candidate"] as Dictionary
	var wellbeing: Dictionary = WellbeingServiceScript.advance(
		candidate, world_seed, current_absolute
	)
	if not bool(wellbeing[&"ok"]):
		return {
			&"ok": false, &"candidate": source, &"day_token": token,
			&"reason": wellbeing[&"reason"],
		}
	candidate = wellbeing[&"candidate"] as Dictionary
	candidate = MachineServiceScript.advance(candidate, current_absolute + 1)
	var settled: Dictionary = EconomyServiceScript.settle(candidate, token)
	if not bool(settled[&"ok"]):
		return {
			&"ok": false, &"candidate": source, &"day_token": token, &"reason": settled[&"reason"]
		}
	candidate = settled[&"candidate"] as Dictionary
	candidate = CalendarStateScript.advance_calendar(candidate, world_seed)
	var renewed: Dictionary = GatheringStateScript.advance_day(
		candidate,
		world_seed,
		CalendarStateScript.absolute_day(candidate[&"calendar_weather"]),
		source_resolver,
	)
	if not bool(renewed[&"ok"]):
		return {
			&"ok": false, &"candidate": source, &"day_token": token,
			&"reason": renewed[&"reason"],
		}
	candidate = renewed[&"candidate"] as Dictionary
	var applicants: Dictionary = ApplicantLifecycleScript.advance_dawn(
		candidate,
		world_seed,
		CalendarStateScript.absolute_day(candidate[&"calendar_weather"]),
	)
	if not bool(applicants[&"ok"]):
		return {
			&"ok": false, &"candidate": source, &"day_token": token,
			&"reason": applicants[&"reason"],
		}
	candidate = applicants[&"candidate"] as Dictionary
	candidate = ToolServiceScript.recover(candidate)
	var arrivals: Dictionary = ResidentServiceScript.reconcile_arrivals(candidate)
	if arrivals[&"reason"] not in [&"", &"no_arrivals", &"homestead_inactive"]:
		return {
			&"ok": false,
			&"candidate": source,
			&"day_token": token,
			&"reason": arrivals[&"reason"],
		}
	candidate = arrivals[&"candidate"] as Dictionary
	var tokens: Array = (candidate[&"day_tokens"] as Array).duplicate()
	tokens.append(token)
	if tokens.size() > 64:
		tokens.pop_front()
	candidate[&"day_tokens"] = tokens
	return {
		&"ok": true,
		&"candidate": candidate,
		&"day_token": token,
		&"money_earned": int(settled.get(&"money_earned", 0)),
		&"construction_work": construction.get(&"work_results", []),
		&"shift_results": extracted[&"shift_results"],
		&"logistics_summary": logistics[&"summary"],
		&"production_summary": production[&"summary"],
		&"wellbeing_summary": wellbeing[&"summaries"],
		&"reason": &"",
	}
