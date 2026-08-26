extends RefCounted

const StateScript: GDScript = preload("res://scripts/construction_state_service.gd")
const SettlerDayScript: GDScript = preload("res://scripts/settler_day_service.gd")


static func advance(farm: Dictionary) -> Dictionary:
	var candidate: Dictionary = farm.duplicate(true)
	var records: Array[Dictionary] = []
	var homestead: Dictionary = candidate.get(&"homestead", {}) as Dictionary
	var construction: Dictionary = homestead.get(&"construction", {}) as Dictionary
	for record: Dictionary in construction.get(&"buildings", []) as Array[Dictionary]:
		records.append(record.duplicate(true))
	records.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"instance_id"]) < str(b[&"instance_id"])
	)
	var completed: Array[String] = []
	var work_results: Array[Dictionary] = []
	var contributors: Array[StringName] = SettlerDayScript.construction_contributors(candidate)
	var contributor_cursor: int = 0
	for record: Dictionary in records:
		if record[&"state"] != "constructing":
			continue
		var available: Array[StringName] = contributors.slice(contributor_cursor)
		var work: Dictionary = SettlerDayScript.construction_work_for(
			available, (record[&"footprint"] as Array).size()
		)
		contributor_cursor += int(work[&"settler_units"])
		var result: Dictionary = StateScript.complete(
			candidate, StringName(str(record[&"instance_id"]))
		)
		if not bool(result[&"ok"]):
			return {
				&"ok": false,
				&"candidate": farm.duplicate(true),
				&"completed": [],
				&"reason": result[&"reason"],
			}
		candidate = result[&"candidate"] as Dictionary
		completed.append(str(record[&"instance_id"]))
		var summary: Dictionary = work.duplicate(true)
		summary[&"site_id"] = str(record[&"instance_id"])
		work_results.append(summary)
	return {
		&"ok": true, &"candidate": candidate, &"completed": completed,
		&"work_results": work_results, &"reason": &"",
	}
