extends RefCounted

const StateScript: GDScript = preload("res://scripts/construction_state_service.gd")


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
	for record: Dictionary in records:
		if record[&"state"] != "constructing":
			continue
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
	return {&"ok": true, &"candidate": candidate, &"completed": completed, &"reason": &""}
