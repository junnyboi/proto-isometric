extends RefCounted

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")


static func payload(key: StringName, placeholders: Dictionary = {}) -> Dictionary:
	return {&"key": key, &"placeholders": placeholders.duplicate(true)}


static func coerce(status: Variant, placeholders: Dictionary = {}) -> Dictionary:
	return (
		status.duplicate(true)
		if status is Dictionary
		else payload(status as StringName, placeholders)
	)


static func render(status: Dictionary) -> String:
	var key: StringName = status.get(&"key", &"status.heavy_frame_online") as StringName
	var placeholders: Dictionary = (status.get(&"placeholders", {}) as Dictionary).duplicate(true)
	if placeholders.has(&"facing"):
		placeholders[&"facing"] = LocalizationScript.t("direction.%s" % placeholders[&"facing"])
	if placeholders.has(&"band"):
		placeholders[&"band"] = LocalizationScript.t(placeholders[&"band"])
	if placeholders.has(&"source"):
		placeholders[&"source"] = LocalizationScript.t("source.%s" % placeholders[&"source"])
	if placeholders.has(&"enemy"):
		placeholders[&"enemy"] = LocalizationScript.t(placeholders[&"enemy"])
	if placeholders.has(&"result"):
		placeholders[&"result"] = LocalizationScript.t(placeholders[&"result"])
	if placeholders.has(&"health_value"):
		var health_value: int = int(placeholders[&"health_value"])
		placeholders[&"health"] = (
			LocalizationScript.t(&"status.enemy_health", {&"hp": health_value})
			if health_value >= 0
			else ""
		)
		placeholders.erase(&"health_value")
	return LocalizationScript.t(key, placeholders)


static func vector_blocked(facing: StringName, scrap: int) -> Dictionary:
	return payload(&"status.vector_blocked", {&"facing": facing, &"scrap": "%03d" % scrap})


static func impact_windup(band: StringName, scrap: int) -> Dictionary:
	return payload(&"status.impact_windup", {&"band": band, &"scrap": "%03d" % scrap})


static func worm_result(band: StringName, remaining: int) -> Dictionary:
	var result: StringName = &"status.worm_destroyed" if remaining <= 0 else &"status.worm_hit"
	return payload(&"status.worm_result", {&"band": band, &"result": result, &"hp": remaining})


static func enemy_result(
	band: StringName,
	enemy: StringName,
	destroyed: bool,
	hits: int,
	last_health: int,
) -> Dictionary:
	var result: StringName = &"status.worm_destroyed" if destroyed else &"status.worm_hit"
	return payload(
		&"status.enemy_result",
		{
			&"band": band,
			&"enemy": enemy,
			&"result": result,
			&"hits": hits,
			&"health_value": last_health if hits == 1 else -1,
		},
	)


static func rock_salvaged(count: int, scrap: int) -> Dictionary:
	return payload(
		&"status.rock_salvaged_multi", {&"count": count, &"scrap": "%03d" % scrap}
	)


static func damage(source: StringName, amount: int, chassis: int, maximum: int) -> Dictionary:
	return payload(
		&"status.damage_contact",
		{
			&"source": source,
			&"damage": "%02d" % amount,
			&"chassis": "%03d" % chassis,
			&"max_chassis": "%03d" % maximum,
		}
	)


static func repair(chassis: int, scrap: int) -> Dictionary:
	return payload(
		&"status.outpost_repair", {&"chassis": "%03d" % chassis, &"scrap": "%03d" % scrap}
	)


static func scrap_collected(amount: int, total: int) -> Dictionary:
	return payload(&"status.scrap_collected", {&"amount": amount, &"total": "%03d" % total})


static func resource_magnet(amount: int, total: int) -> Dictionary:
	return payload(&"status.resource_magnet", {&"amount": amount, &"total": "%03d" % total})


static func drive(facing: StringName, speed_ratio: float) -> Dictionary:
	return payload(
		&"status.drive",
		{&"facing": facing, &"speed": "%03d" % roundi(speed_ratio * 100.0)},
	)
