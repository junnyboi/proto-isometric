extends RefCounted

const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")

const SHELTER_POD: StringName = &"blueprint.shelter_pod"
const FIELD_WAREHOUSE: StringName = &"blueprint.field_warehouse"
const SALVAGE_CAMP: StringName = &"blueprint.salvage_camp"
const SURVEY_DRILL: StringName = &"blueprint.survey_drill"
const COPPICE_STATION: StringName = &"blueprint.coppice_station"
const FABRICATOR_ANNEX: StringName = &"blueprint.fabricator_annex"
const FISHING_PLATFORM: StringName = &"blueprint.fishing_platform"
const LEDGER_KIND: StringName = &"structure.settlement"
const MAX_LEVEL: int = 3

const SHELTER_TEXTURE: Texture2D = preload(
	"res://assets/settlement/construction/building_shelter_pod.png"
)
const WAREHOUSE_TEXTURE: Texture2D = preload(
	"res://assets/settlement/construction/building_field_warehouse.png"
)
const SALVAGE_TEXTURE: Texture2D = preload(
	"res://assets/settlement/construction/building_salvage_camp.png"
)
const DRILL_TEXTURE: Texture2D = preload(
	"res://assets/settlement/construction/building_survey_drill.png"
)
const COPPICE_TEXTURE: Texture2D = preload(
	"res://assets/settlement/construction/building_coppice_station.png"
)
const FABRICATOR_TEXTURE: Texture2D = preload(
	"res://assets/settlement/construction/building_fabricator_annex.png"
)
const FISHING_TEXTURE: Texture2D = preload(
	"res://assets/settlement/construction/building_fishing_platform.png"
)
const SCAFFOLD_SMALL: Texture2D = preload(
	"res://assets/settlement/construction/construction_scaffold_small.png"
)
const SCAFFOLD_LARGE: Texture2D = preload(
	"res://assets/settlement/construction/construction_scaffold_large.png"
)
const BLUEPRINT_ICON: Texture2D = preload(
	"res://assets/settlement/construction/icon_build_blueprint.png"
)
const ROTATE_ICON: Texture2D = preload(
	"res://assets/settlement/construction/icon_rotate_building.png"
)

const BLUEPRINT_IDS: Array[StringName] = [
	SHELTER_POD,
	FIELD_WAREHOUSE,
	SALVAGE_CAMP,
	SURVEY_DRILL,
	COPPICE_STATION,
	FABRICATOR_ANNEX,
	FISHING_PLATFORM,
]
const DEFINITIONS: Array[Dictionary] = [
	{
		&"blueprint_id": SHELTER_POD,
		&"label_key": &"construction.blueprint.shelter_pod",
		&"purpose_key": &"construction.purpose.shelter_pod",
		&"footprint": [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE],
		&"entrance": Vector2i(0, 2),
		&"bill": {&"item.material.wood": 4, &"item.material.stone": 2},
		&"upgrade_bill": {&"item.material.wood": 2, &"item.material.scrap": 1},
		&"texture": SHELTER_TEXTURE,
		&"draw_size": Vector2(224.0, 224.0),
		&"draw_offset": Vector2(0.0, -66.0),
	},
	{
		&"blueprint_id": FIELD_WAREHOUSE,
		&"label_key": &"construction.blueprint.field_warehouse",
		&"purpose_key": &"construction.purpose.field_warehouse",
		&"footprint": [
			Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0),
			Vector2i.DOWN, Vector2i.ONE, Vector2i(2, 1),
		],
		&"entrance": Vector2i(1, 2),
		&"bill": {
			&"item.material.wood": 6,
			&"item.material.stone": 4,
			&"item.material.scrap": 2,
		},
		&"upgrade_bill": {&"item.material.wood": 3, &"item.material.scrap": 2},
		&"texture": WAREHOUSE_TEXTURE,
		&"draw_size": Vector2(272.0, 272.0),
		&"draw_offset": Vector2(0.0, -82.0),
	},
	{
		&"blueprint_id": SALVAGE_CAMP,
		&"label_key": &"construction.blueprint.salvage_camp",
		&"purpose_key": &"construction.purpose.salvage_camp",
		&"footprint": [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE],
		&"entrance": Vector2i(0, 2),
		&"bill": {&"item.material.wood": 4, &"item.material.scrap": 3},
		&"upgrade_bill": {&"item.material.scrap": 3, &"item.part.iron_ingot": 1},
		&"texture": SALVAGE_TEXTURE,
		&"draw_size": Vector2(232.0, 232.0),
		&"draw_offset": Vector2(0.0, -70.0),
	},
	{
		&"blueprint_id": SURVEY_DRILL,
		&"label_key": &"construction.blueprint.survey_drill",
		&"purpose_key": &"construction.purpose.survey_drill",
		&"footprint": [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE],
		&"entrance": Vector2i(0, 2),
		&"bill": {&"item.material.stone": 5, &"item.material.scrap": 4},
		&"upgrade_bill": {&"item.material.scrap": 3, &"item.part.iron_ingot": 2},
		&"texture": DRILL_TEXTURE,
		&"draw_size": Vector2(232.0, 232.0),
		&"draw_offset": Vector2(0.0, -72.0),
	},
	{
		&"blueprint_id": COPPICE_STATION,
		&"label_key": &"construction.blueprint.coppice_station",
		&"purpose_key": &"construction.purpose.coppice_station",
		&"footprint": [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE],
		&"entrance": Vector2i(0, 2),
		&"bill": {&"item.material.wood": 6, &"item.material.stone": 2},
		&"upgrade_bill": {&"item.material.wood": 4, &"item.material.scrap": 1},
		&"texture": COPPICE_TEXTURE,
		&"draw_size": Vector2(232.0, 232.0),
		&"draw_offset": Vector2(0.0, -70.0),
	},
	{
		&"blueprint_id": FABRICATOR_ANNEX,
		&"label_key": &"construction.blueprint.fabricator_annex",
		&"purpose_key": &"construction.purpose.fabricator_annex",
		&"footprint": [
			Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0),
			Vector2i.DOWN, Vector2i.ONE, Vector2i(2, 1),
		],
		&"entrance": Vector2i(1, 2),
		&"bill": {
			&"item.material.wood": 5,
			&"item.material.stone": 4,
			&"item.material.scrap": 4,
		},
		&"upgrade_bill": {&"item.material.scrap": 4, &"item.part.iron_ingot": 2},
		&"texture": FABRICATOR_TEXTURE,
		&"draw_size": Vector2(276.0, 276.0),
		&"draw_offset": Vector2(0.0, -84.0),
	},
	{
		&"blueprint_id": FISHING_PLATFORM,
		&"label_key": &"construction.blueprint.fishing_platform",
		&"purpose_key": &"construction.purpose.fishing_platform",
		&"footprint": [Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2, 0), Vector2i.DOWN],
		&"entrance": Vector2i.ONE,
		&"bill": {&"item.material.wood": 6, &"item.material.scrap": 2},
		&"upgrade_bill": {&"item.material.wood": 3, &"item.material.scrap": 2},
		&"texture": FISHING_TEXTURE,
		&"draw_size": Vector2(254.0, 254.0),
		&"draw_offset": Vector2(0.0, -76.0),
	},
]


static func ids() -> Array[StringName]:
	return BLUEPRINT_IDS.duplicate()


static func definition(blueprint_id: StringName) -> Dictionary:
	for candidate: Dictionary in DEFINITIONS:
		if candidate[&"blueprint_id"] == blueprint_id:
			return candidate.duplicate(true)
	return {}


static func footprint(
	blueprint_id: StringName, anchor: Vector2i, orientation: int
) -> Array[Vector2i]:
	var blueprint: Dictionary = definition(blueprint_id)
	var result: Array[Vector2i] = []
	if blueprint.is_empty() or orientation < 0 or orientation > 3:
		return result
	for offset: Vector2i in blueprint[&"footprint"] as Array[Vector2i]:
		result.append(anchor + _rotate(offset, orientation))
	result.sort_custom(_cell_precedes)
	return result


static func encoded_footprint(
	blueprint_id: StringName, anchor: Vector2i, orientation: int
) -> Array[Array]:
	var result: Array[Array] = []
	for cell: Vector2i in footprint(blueprint_id, anchor, orientation):
		result.append([cell.x, cell.y])
	return result


static func entrance(
	blueprint_id: StringName, anchor: Vector2i, orientation: int
) -> Vector2i:
	var blueprint: Dictionary = definition(blueprint_id)
	if blueprint.is_empty() or orientation < 0 or orientation > 3:
		return Vector2i(1_000_001, 1_000_001)
	return anchor + _rotate(blueprint[&"entrance"] as Vector2i, orientation)


static func bill(blueprint_id: StringName, level: int = 1) -> Dictionary:
	var blueprint: Dictionary = definition(blueprint_id)
	if blueprint.is_empty() or level < 1:
		return {}
	var key: StringName = &"bill" if level == 1 else &"upgrade_bill"
	return (blueprint[key] as Dictionary).duplicate(true)


static func texture_for(blueprint_id: StringName, state: StringName) -> Texture2D:
	var blueprint: Dictionary = definition(blueprint_id)
	if blueprint.is_empty():
		return null
	if state != &"complete":
		return (
			SCAFFOLD_LARGE
			if (blueprint[&"footprint"] as Array).size() > 4
			else SCAFFOLD_SMALL
		)
	return blueprint[&"texture"] as Texture2D


static func is_movable(blueprint_id: StringName) -> bool:
	return blueprint_id in BLUEPRINT_IDS and blueprint_id != FISHING_PLATFORM


static func validate() -> bool:
	if DEFINITIONS.size() != BLUEPRINT_IDS.size():
		return false
	var seen: Dictionary = {}
	for blueprint: Dictionary in DEFINITIONS:
		var blueprint_id: StringName = blueprint[&"blueprint_id"] as StringName
		if blueprint_id not in BLUEPRINT_IDS or seen.has(blueprint_id):
			return false
		seen[blueprint_id] = true
		if not _definition_is_valid(blueprint):
			return false
	return seen.size() == BLUEPRINT_IDS.size()


static func _definition_is_valid(blueprint: Dictionary) -> bool:
	var expected: Array[StringName] = [
		&"blueprint_id", &"label_key", &"purpose_key", &"footprint", &"entrance", &"bill",
		&"upgrade_bill", &"texture", &"draw_size", &"draw_offset",
	]
	if blueprint.keys() != expected:
		return false
	var offsets: Array = blueprint[&"footprint"] as Array
	if (
		offsets.is_empty()
		or offsets.size() > 16
		or Vector2i.ZERO not in offsets
		or not blueprint[&"entrance"] is Vector2i
	):
		return false
	var unique: Dictionary = {}
	for offset: Variant in offsets:
		if not offset is Vector2i or unique.has(offset):
			return false
		var cell: Vector2i = offset as Vector2i
		if absi(cell.x) > 8 or absi(cell.y) > 8:
			return false
		unique[cell] = true
	if blueprint[&"entrance"] in unique:
		return false
	return (
		blueprint[&"texture"] is Texture2D
		and (blueprint[&"draw_size"] as Vector2).x > 0.0
		and _bill_is_valid(blueprint[&"bill"])
		and _bill_is_valid(blueprint[&"upgrade_bill"])
	)


static func _bill_is_valid(value: Variant) -> bool:
	if not value is Dictionary or (value as Dictionary).is_empty():
		return false
	for raw_id: Variant in value:
		var item_id: StringName = StringName(str(raw_id))
		if item_id not in ItemCatalogScript.ids() or not value[raw_id] is int:
			return false
		if int(value[raw_id]) < 1 or int(value[raw_id]) > 99:
			return false
	return true


static func _rotate(offset: Vector2i, orientation: int) -> Vector2i:
	match orientation:
		1:
			return Vector2i(-offset.y, offset.x)
		2:
			return -offset
		3:
			return Vector2i(offset.y, -offset.x)
	return offset


static func _cell_precedes(first: Vector2i, second: Vector2i) -> bool:
	return first.y < second.y or (first.y == second.y and first.x < second.x)
