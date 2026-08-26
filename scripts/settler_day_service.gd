extends RefCounted

const ConstructionStateScript: GDScript = preload(
	"res://scripts/construction_state_service.gd"
)
const WorkforceScript: GDScript = preload("res://scripts/workforce_service.gd")

const MAX_SETTLER_CONSTRUCTION_UNITS: int = 3
const WORKING: StringName = &"working"
const CARRYING: StringName = &"carrying"
const RESTING: StringName = &"resting"
const RECOVERING: StringName = &"recovering"
const IDLE: StringName = &"idle"


static func construction_contributors(farm: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var workforce: Dictionary = homestead.get(&"workforce", {}) as Dictionary
	for settler: Dictionary in workforce.get(&"settlers", []) as Array[Dictionary]:
		var settler_id: StringName = StringName(str(settler[&"settler_id"]))
		if not WorkforceScript.assignment_for(farm, settler_id).is_empty():
			continue
		if bool(WorkforceScript.availability(farm, settler_id)[&"available"]):
			result.append(settler_id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return result


static func construction_work(farm: Dictionary, required_units: int) -> Dictionary:
	return construction_work_for(construction_contributors(farm), required_units)


static func construction_work_for(
	contributors: Array[StringName], required_units: int
) -> Dictionary:
	var required: int = maxi(required_units, 1)
	var settler_units: int = mini(
		contributors.size(), mini(MAX_SETTLER_CONSTRUCTION_UNITS, required - 1)
	)
	return {
		&"required_units": required,
		&"protos_units": required - settler_units,
		&"settler_units": settler_units,
		&"contributors": contributors.slice(0, settler_units),
	}


static func presentation_status(farm: Dictionary, settler_id: StringName) -> StringName:
	var availability: Dictionary = WorkforceScript.availability(farm, settler_id)
	if not bool(availability[&"available"]):
		return RECOVERING if availability[&"reason"] == &"settler_recovering" else RESTING
	var assignment: Dictionary = WorkforceScript.assignment_for(farm, settler_id)
	if assignment.is_empty():
		return RESTING
	var report: Dictionary = last_shift_report(farm, settler_id)
	if not report.is_empty() and str(report[&"status"]) == "idle":
		return IDLE
	var building: Dictionary = ConstructionStateScript.building(
		farm, StringName(str(assignment[&"site_id"]))
	)
	if building.is_empty() or str(building[&"state"]) != "complete":
		return RESTING
	return CARRYING if not (building[&"local_stacks"] as Array).is_empty() else WORKING


static func last_shift_report(farm: Dictionary, settler_id: StringName) -> Dictionary:
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var workforce: Dictionary = homestead.get(&"workforce", {}) as Dictionary
	for report: Dictionary in workforce.get(&"shift_reports", []) as Array[Dictionary]:
		if str(report[&"settler_id"]) == str(settler_id):
			return report.duplicate(true)
	return {}


static func work_cell(farm: Dictionary, settler_id: StringName) -> Vector2i:
	var assignment: Dictionary = WorkforceScript.assignment_for(farm, settler_id)
	if assignment.is_empty():
		return Vector2i(1_000_001, 1_000_001)
	var building: Dictionary = ConstructionStateScript.building(
		farm, StringName(str(assignment[&"site_id"]))
	)
	if building.is_empty():
		return Vector2i(1_000_001, 1_000_001)
	var front: Vector2i = Vector2i.ZERO
	var front_depth: int = -2_000_001
	for encoded: Array in building[&"footprint"] as Array[Array]:
		var cell: Vector2i = Vector2i(int(encoded[0]), int(encoded[1]))
		var depth: int = cell.x + cell.y
		if depth > front_depth or depth == front_depth and cell.x > front.x:
			front = cell
			front_depth = depth
	var slot: int = int(assignment[&"slot"])
	return front + [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 2), Vector2i(2, -1)][
		slot % 4
	]
