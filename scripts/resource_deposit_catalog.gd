extends RefCounted

const ConstructionCatalogScript: GDScript = preload(
	"res://scripts/construction_blueprint_catalog.gd"
)
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const PROJECTION_VERSION: String = "p5.deposit.v1"
const CHUNK_SIZE: int = 8
const PLAYABLE_HALF_EXTENT: int = 72
const MAX_PROJECTED_SOURCES: int = 124
const BASE_RANGE: int = 6
const RANGE_PER_LEVEL: int = 2

const SALVAGE: StringName = &"salvage"
const MINERAL: StringName = &"mineral"
const BIOMASS: StringName = &"biomass"
const SOURCE_KINDS: Array[StringName] = [SALVAGE, MINERAL, BIOMASS]
const FIXED_SOURCES: Array[Dictionary] = [
	{&"cell": Vector2i(2, 6), &"source_kind": SALVAGE, &"tier": 1},
	{&"cell": Vector2i(15, 6), &"source_kind": MINERAL, &"tier": 1},
	{&"cell": Vector2i(2, 15), &"source_kind": BIOMASS, &"tier": 1},
]
const DEFINITIONS: Array[Dictionary] = [
	{
		&"source_kind": SALVAGE,
		&"capacity": 6,
		&"renewable": false,
		&"renewal_days": 0,
		&"reward_item_id": &"item.material.scrap",
		&"reward_count": 2,
		&"required_tool": &"tool.pick",
		&"compatible_blueprint": ConstructionCatalogScript.SALVAGE_CAMP,
		&"title_key": &"interaction.target.deposit_salvage.title",
	},
	{
		&"source_kind": MINERAL,
		&"capacity": 8,
		&"renewable": false,
		&"renewal_days": 0,
		&"reward_item_id": &"item.ore.iron",
		&"reward_count": 2,
		&"required_tool": &"tool.pick",
		&"compatible_blueprint": ConstructionCatalogScript.SURVEY_DRILL,
		&"title_key": &"interaction.target.deposit_mineral.title",
	},
	{
		&"source_kind": BIOMASS,
		&"capacity": 4,
		&"renewable": true,
		&"renewal_days": 3,
		&"reward_item_id": &"item.material.wood",
		&"reward_count": 2,
		&"required_tool": &"tool.axe",
		&"compatible_blueprint": ConstructionCatalogScript.COPPICE_STATION,
		&"title_key": &"interaction.target.deposit_biomass.title",
	},
]
const SOURCE_KEYS: Array[StringName] = [
	&"source_id", &"source_kind", &"cell", &"capacity", &"tier", &"renewable",
	&"renewal_days", &"reward_item_id", &"reward_count", &"required_tool",
	&"compatible_blueprint", &"title_key",
]


static func definition(source_kind: StringName) -> Dictionary:
	for candidate: Dictionary in DEFINITIONS:
		if candidate[&"source_kind"] == source_kind:
			return candidate.duplicate(true)
	return {}


static func project_at(
	cell: Vector2i,
	world_seed: int,
	gameplay_mode: StringName = RuntimeIdsScript.MODE_FRESH_FARM,
) -> Dictionary:
	if gameplay_mode != RuntimeIdsScript.MODE_FRESH_FARM or not _inside_world(cell):
		return {}
	for fixed: Dictionary in FIXED_SOURCES:
		if fixed[&"cell"] == cell:
			return _source(cell, fixed[&"source_kind"], int(fixed[&"tier"]))
	var chunk: Vector2i = chunk_for(cell)
	if not _chunk_selected(chunk, world_seed) or _candidate_cell(chunk, world_seed) != cell:
		return {}
	var kind_index: int = _sample(world_seed, chunk, "kind") % SOURCE_KINDS.size()
	var tier: int = 1 + _sample(world_seed, chunk, "tier") % 3
	return _source(cell, SOURCE_KINDS[kind_index], tier)


static func project_chunk(
	chunk: Vector2i,
	world_seed: int,
	gameplay_mode: StringName = RuntimeIdsScript.MODE_FRESH_FARM,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if gameplay_mode != RuntimeIdsScript.MODE_FRESH_FARM:
		return result
	for fixed: Dictionary in FIXED_SOURCES:
		var fixed_cell: Vector2i = fixed[&"cell"] as Vector2i
		if chunk_for(fixed_cell) == chunk:
			result.append(_source(fixed_cell, fixed[&"source_kind"], int(fixed[&"tier"])))
	if _chunk_selected(chunk, world_seed):
		var candidate: Dictionary = project_at(_candidate_cell(chunk, world_seed), world_seed)
		if not candidate.is_empty() and not _has_id(result, candidate[&"source_id"]):
			result.append(candidate)
	result.sort_custom(_source_precedes)
	return result


static func chunk_for(cell: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(cell.x) / float(CHUNK_SIZE)),
		floori(float(cell.y) / float(CHUNK_SIZE)),
	)


static func effective_range(level: int) -> int:
	return BASE_RANGE + maxi(level - 1, 0) * RANGE_PER_LEVEL


static func compatible(source: Dictionary, blueprint_id: StringName, level: int) -> bool:
	return (
		validate_source(source)
		and blueprint_id == source[&"compatible_blueprint"]
		and level >= int(source[&"tier"])
	)


static func source_kind_from_id(source_id: String) -> StringName:
	var parts: PackedStringArray = source_id.split(".")
	return StringName(parts[1]) if parts.size() == 4 and parts[0] == "source" else &""


static func canonical_source_id(source_kind: StringName, cell: Vector2i) -> StringName:
	if source_kind not in SOURCE_KINDS or not _inside_world(cell):
		return &""
	return _source_id(source_kind, cell)


static func cell_from_id(source_id: String) -> Vector2i:
	var parts: PackedStringArray = source_id.split(".")
	if parts.size() != 4 or parts[0] != "source" or StringName(parts[1]) not in SOURCE_KINDS:
		return Vector2i(PLAYABLE_HALF_EXTENT + 1, PLAYABLE_HALF_EXTENT + 1)
	var x: Variant = _decoded_coordinate(parts[2])
	var y: Variant = _decoded_coordinate(parts[3])
	if x == null or y == null:
		return Vector2i(PLAYABLE_HALF_EXTENT + 1, PLAYABLE_HALF_EXTENT + 1)
	return Vector2i(int(x), int(y))


static func validate_source(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var source: Dictionary = value as Dictionary
	if source.keys() != SOURCE_KEYS:
		return false
	var kind: StringName = source[&"source_kind"] as StringName
	var policy: Dictionary = definition(kind)
	return (
		not policy.is_empty()
		and source[&"cell"] is Vector2i
		and source[&"source_id"] == _source_id(kind, source[&"cell"] as Vector2i)
		and int(source[&"capacity"]) == int(policy[&"capacity"])
		and int(source[&"tier"]) in range(1, 4)
		and bool(source[&"renewable"]) == bool(policy[&"renewable"])
		and int(source[&"renewal_days"]) == int(policy[&"renewal_days"])
		and source[&"reward_item_id"] == policy[&"reward_item_id"]
		and int(source[&"reward_count"]) == int(policy[&"reward_count"])
		and source[&"required_tool"] == policy[&"required_tool"]
		and source[&"compatible_blueprint"] == policy[&"compatible_blueprint"]
		and source[&"title_key"] == policy[&"title_key"]
	)


static func golden_digest(world_seed: int) -> String:
	var records: Array[Dictionary] = []
	for y: int in range(-9, 10):
		for x: int in range(-9, 10):
			for source: Dictionary in project_chunk(Vector2i(x, y), world_seed):
				records.append(_encoded(source))
	records.sort_custom(_encoded_precedes)
	return JSON.stringify(records, "", true, true).sha256_text()


static func validate() -> bool:
	var seen: Dictionary = {}
	for policy: Dictionary in DEFINITIONS:
		var kind: StringName = policy[&"source_kind"] as StringName
		if kind not in SOURCE_KINDS or seen.has(kind):
			return false
		seen[kind] = true
		if int(policy[&"capacity"]) < 1 or int(policy[&"capacity"]) > 99:
			return false
		if bool(policy[&"renewable"]) != (int(policy[&"renewal_days"]) > 0):
			return false
	var projected: int = 0
	for y: int in range(-9, 10):
		for x: int in range(-9, 10):
			projected += project_chunk(Vector2i(x, y), 0x48415256).size()
	return seen.size() == SOURCE_KINDS.size() and projected <= MAX_PROJECTED_SOURCES


static func _source(cell: Vector2i, source_kind: StringName, tier: int) -> Dictionary:
	var policy: Dictionary = definition(source_kind)
	if policy.is_empty():
		return {}
	return {
		&"source_id": _source_id(source_kind, cell), &"source_kind": source_kind,
		&"cell": cell, &"capacity": int(policy[&"capacity"]), &"tier": tier,
		&"renewable": bool(policy[&"renewable"]),
		&"renewal_days": int(policy[&"renewal_days"]),
		&"reward_item_id": policy[&"reward_item_id"],
		&"reward_count": int(policy[&"reward_count"]),
		&"required_tool": policy[&"required_tool"],
		&"compatible_blueprint": policy[&"compatible_blueprint"],
		&"title_key": policy[&"title_key"],
	}


static func _source_id(source_kind: StringName, cell: Vector2i) -> StringName:
	return StringName(
		"source.%s.%s.%s" % [str(source_kind), _coordinate(cell.x), _coordinate(cell.y)]
	)


static func _coordinate(value: int) -> String:
	if value < 0:
		return "n%d" % absi(value)
	if value > 0:
		return "p%d" % value
	return "z0"


static func _decoded_coordinate(value: String) -> Variant:
	if value == "z0":
		return 0
	if value.length() < 2 or value[0] not in ["n", "p"] or not value.substr(1).is_valid_int():
		return null
	var number: int = value.substr(1).to_int()
	if number < 1 or number > PLAYABLE_HALF_EXTENT:
		return null
	return -number if value[0] == "n" else number


static func _chunk_selected(chunk: Vector2i, world_seed: int) -> bool:
	return posmod(chunk.x + chunk.y + posmod(world_seed, 3), 3) == 0


static func _candidate_cell(chunk: Vector2i, world_seed: int) -> Vector2i:
	var x: int = _sample(world_seed, chunk, "x") % CHUNK_SIZE
	var y: int = _sample(world_seed, chunk, "y") % CHUNK_SIZE
	return chunk * CHUNK_SIZE + Vector2i(x, y)


static func _sample(world_seed: int, chunk: Vector2i, domain: String) -> int:
	var preimage: String = "%s|%d|%d|%d|%s" % [
		PROJECTION_VERSION, world_seed, chunk.x, chunk.y, domain
	]
	return preimage.sha256_text().left(7).hex_to_int()


static func _inside_world(cell: Vector2i) -> bool:
	return absi(cell.x) <= PLAYABLE_HALF_EXTENT and absi(cell.y) <= PLAYABLE_HALF_EXTENT


static func _has_id(records: Array[Dictionary], source_id: StringName) -> bool:
	for record: Dictionary in records:
		if record[&"source_id"] == source_id:
			return true
	return false


static func _source_precedes(first: Dictionary, second: Dictionary) -> bool:
	var a: Vector2i = first[&"cell"] as Vector2i
	var b: Vector2i = second[&"cell"] as Vector2i
	return a.y < b.y or (a.y == b.y and (a.x < b.x or (a.x == b.x and str(
		first[&"source_id"]
	) < str(second[&"source_id"]))))


static func _encoded(source: Dictionary) -> Dictionary:
	var cell: Vector2i = source[&"cell"] as Vector2i
	return {
		&"source_id": str(source[&"source_id"]), &"source_kind": str(source[&"source_kind"]),
		&"cell": [cell.x, cell.y], &"capacity": int(source[&"capacity"]),
		&"tier": int(source[&"tier"]),
	}


static func _encoded_precedes(first: Dictionary, second: Dictionary) -> bool:
	return str(first[&"source_id"]) < str(second[&"source_id"])
