extends RefCounted

const CalendarScript: GDScript = preload("res://scripts/calendar_state.gd")
const CatalogScript: GDScript = preload("res://scripts/resource_deposit_catalog.gd")
const GatheringScript: GDScript = preload("res://scripts/gathering_state_service.gd")
const PresentationCatalogScript: GDScript = preload(
	"res://scripts/resource_deposit_presentation_catalog.gd"
)


static func build_chunk_indexes(
	farm: Dictionary,
	world: RefCounted,
	chunks: Array[Vector2i],
) -> Dictionary:
	var indexes: Dictionary = {}
	if world == null:
		return indexes
	var seed: int = int(world.call("_get_world_seed"))
	var mode: StringName = world.call("_get_gameplay_mode") as StringName
	var day: int = CalendarScript.absolute_day(farm[&"calendar_weather"])
	var ordered: Array[Vector2i] = chunks.duplicate()
	ordered.sort_custom(_chunk_precedes)
	for chunk: Vector2i in ordered:
		var records: Array[Dictionary] = []
		for projected: Dictionary in CatalogScript.project_chunk(chunk, seed, mode):
			var source: Dictionary = world.call(
				"_resource_source_at", projected[&"cell"]
			) as Dictionary
			if source.is_empty():
				continue
			var state: Dictionary = GatheringScript.effective(farm, source, day)
			var record: Dictionary = PresentationCatalogScript.record(source, state)
			if not record.is_empty():
				records.append(record)
		if not records.is_empty():
			indexes[chunk] = records
	return indexes


static func _chunk_precedes(first: Vector2i, second: Vector2i) -> bool:
	return first.y < second.y or (first.y == second.y and first.x < second.x)
