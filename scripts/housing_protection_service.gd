extends RefCounted

const BlueprintCatalogScript: GDScript = preload(
	"res://scripts/construction_blueprint_catalog.gd"
)
const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")

const HOME_BED_COUNT: int = 2


static func safehouse_ready(farm: Dictionary) -> bool:
	var services: Dictionary = HomesteadServiceScript.home_services(farm)
	return bool(services.get(&"safehouse", false)) and bool(services.get(&"bed", false))


static func protected_beds(farm: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not safehouse_ready(farm):
		return result
	for index: int in HOME_BED_COUNT:
		result.append(
		{
				&"bed_id": "bed.home.%d" % index,
				&"site_id": str(HomesteadServiceScript.HOME_ID),
				&"slot": index,
				&"cell": HomesteadServiceScript.HOME_CELL,
				&"protected": true,
			}
		)
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var construction: Dictionary = homestead.get(&"construction", {}) as Dictionary
	for building: Dictionary in construction.get(&"buildings", []) as Array[Dictionary]:
		if str(building.get(&"state", "")) != "complete":
			continue
		var blueprint_id: StringName = StringName(str(building.get(&"blueprint_id", "")))
		var capacity: int = BlueprintCatalogScript.housing_capacity(blueprint_id)
		if capacity <= 0:
			continue
		var anchor: Array = building.get(&"anchor", []) as Array
		var cell: Vector2i = Vector2i(int(anchor[0]), int(anchor[1]))
		for index: int in capacity:
			result.append(
				{
					&"bed_id": "bed.%s.%d" % [str(building[&"instance_id"]), index],
					&"site_id": str(building[&"instance_id"]),
					&"slot": index,
					&"cell": cell,
					&"protected": true,
				}
			)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"bed_id"]) < str(b[&"bed_id"])
	)
	return result


static func available_beds(farm: Dictionary) -> Array[Dictionary]:
	var occupied: Dictionary = {}
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var workforce: Dictionary = homestead.get(&"workforce", {}) as Dictionary
	for assignment: Dictionary in workforce.get(&"housing_assignments", []) as Array[Dictionary]:
		occupied[str(assignment[&"bed_id"])] = true
	var result: Array[Dictionary] = []
	for bed: Dictionary in protected_beds(farm):
		if not occupied.has(str(bed[&"bed_id"])):
			result.append(bed.duplicate(true))
	return result


static func first_available_bed(farm: Dictionary) -> Dictionary:
	var available: Array[Dictionary] = available_beds(farm)
	return {} if available.is_empty() else available[0].duplicate(true)


static func bed(farm: Dictionary, bed_id: String) -> Dictionary:
	for candidate: Dictionary in protected_beds(farm):
		if str(candidate[&"bed_id"]) == bed_id:
			return candidate.duplicate(true)
	return {}


static func assignment_is_protected(farm: Dictionary, settler_id: StringName) -> bool:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var workforce: Dictionary = homestead.get(&"workforce", {}) as Dictionary
	for assignment: Dictionary in workforce.get(&"housing_assignments", []) as Array[Dictionary]:
		if str(assignment[&"settler_id"]) != str(settler_id):
			continue
		return not bed(farm, str(assignment[&"bed_id"])).is_empty()
	return false
