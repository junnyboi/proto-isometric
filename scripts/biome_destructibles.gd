extends RefCounted

const KIND_DESERT_SANDSTONE_CLUSTER: StringName = &"desert_sandstone_cluster"
const KIND_DESERT_IRONSTONE_OUTCROP: StringName = &"desert_ironstone_outcrop"
const KIND_DESERT_ROCK: StringName = KIND_DESERT_SANDSTONE_CLUSTER
const KIND_WETLAND_MANGROVE: StringName = &"wetland_mangrove"
const KIND_WETLAND_STUMP: StringName = &"wetland_stump"
const KIND_FROZEN_SNOW_ROCK: StringName = &"frozen_snow_rock"
const KIND_FROZEN_PINE: StringName = &"frozen_pine"
const KIND_LAVA_BASALT_CHIMNEY: StringName = &"lava_basalt_chimney"
const KIND_LAVA_OBSIDIAN_CLUSTER: StringName = &"lava_obsidian_cluster"

const GENERATED_KINDS: Array[StringName] = [
	KIND_DESERT_SANDSTONE_CLUSTER,
	KIND_DESERT_IRONSTONE_OUTCROP,
	KIND_WETLAND_MANGROVE,
	KIND_WETLAND_STUMP,
	KIND_FROZEN_SNOW_ROCK,
	KIND_FROZEN_PINE,
	KIND_LAVA_BASALT_CHIMNEY,
	KIND_LAVA_OBSIDIAN_CLUSTER,
]

const DESERT_DEBRIS: Array[Color] = [Color("934d35"), Color("bd7152"), Color("e8b861")]
const WETLAND_DEBRIS: Array[Color] = [
	Color("4a3427"), Color("9b7047"), Color("68733f"), Color("2d281f")
]
const FROZEN_ROCK_DEBRIS: Array[Color] = [
	Color("dce8ed"), Color("9fc6d4"), Color("52616b"), Color("36a8c8")
]
const FROZEN_PINE_DEBRIS: Array[Color] = [
	Color("dce8ed"), Color("244844"), Color("52616b"), Color("8eb6c2")
]
const LAVA_DEBRIS: Array[Color] = [
	Color("252326"), Color("575253"), Color("8c8a86"), Color("ff5a12")
]
const DEBRIS_PROFILES: Dictionary = {
	&"dry_stone": {
		&"shape": &"stone", &"gravity": 1.35, &"speed": Vector2(110.0, 245.0),
		&"size": Vector2(4.0, 9.0), &"spin": Vector2(3.0, 8.0),
	},
	&"wet_wood": {
		&"shape": &"splinter", &"gravity": 0.9, &"speed": Vector2(85.0, 205.0),
		&"size": Vector2(4.0, 11.0), &"spin": Vector2(5.0, 12.0),
	},
	&"frozen_stone": {
		&"shape": &"ice", &"gravity": 0.75, &"speed": Vector2(115.0, 250.0),
		&"size": Vector2(3.0, 8.0), &"spin": Vector2(6.0, 13.0),
	},
	&"cold_wood": {
		&"shape": &"splinter", &"gravity": 0.82, &"speed": Vector2(95.0, 220.0),
		&"size": Vector2(4.0, 10.0), &"spin": Vector2(5.0, 12.0),
	},
	&"basalt": {
		&"shape": &"jagged", &"gravity": 1.55, &"speed": Vector2(120.0, 260.0),
		&"size": Vector2(4.0, 9.0), &"spin": Vector2(6.0, 14.0),
	},
	&"obsidian": {
		&"shape": &"jagged", &"gravity": 1.45, &"speed": Vector2(130.0, 270.0),
		&"size": Vector2(3.0, 9.0), &"spin": Vector2(7.0, 15.0),
	},
}
const BLOCK_PALETTES: Dictionary = {
	&"dry_stone":
	{
		&"top": Color("8b4c2d"),
		&"right": Color("63341f"),
		&"left": Color("482519"),
	},
	&"wet_wood":
	{
		&"top": Color("716a3a"),
		&"right": Color("4f4930"),
		&"left": Color("373326"),
	},
	&"frozen_stone":
	{
		&"top": Color("afbfca"),
		&"right": Color("788d9a"),
		&"left": Color("5c707c"),
	},
	&"cold_wood":
	{
		&"top": Color("6f8583"),
		&"right": Color("4a5d5b"),
		&"left": Color("334340"),
	},
	&"basalt":
	{
		&"top": Color("34363a"),
		&"right": Color("242529"),
		&"left": Color("18191d"),
	},
	&"obsidian":
	{
		&"top": Color("252a35"),
		&"right": Color("181c24"),
		&"left": Color("10131a"),
	},
}

const TEXTURES: Dictionary = {
	KIND_DESERT_SANDSTONE_CLUSTER: preload("res://assets/destructibles/desert_sandstone_cluster.png"),
	KIND_DESERT_IRONSTONE_OUTCROP: preload("res://assets/destructibles/desert_ironstone_outcrop.png"),
	KIND_WETLAND_MANGROVE: preload("res://assets/destructibles/wetland_mangrove.png"),
	KIND_WETLAND_STUMP: preload("res://assets/destructibles/wetland_stump.png"),
	KIND_FROZEN_SNOW_ROCK: preload("res://assets/destructibles/frozen_snow_rock.png"),
	KIND_FROZEN_PINE: preload("res://assets/destructibles/frozen_pine.png"),
	KIND_LAVA_BASALT_CHIMNEY: preload("res://assets/destructibles/lava_basalt_chimney.png"),
	KIND_LAVA_OBSIDIAN_CLUSTER: preload("res://assets/destructibles/lava_obsidian_cluster.png"),
}

const DISPLAY_SIZES: Dictionary = {
	KIND_DESERT_SANDSTONE_CLUSTER: Vector2(84.0, 66.0),
	KIND_DESERT_IRONSTONE_OUTCROP: Vector2(82.0, 70.0),
	KIND_WETLAND_MANGROVE: Vector2(88.0, 118.0),
	KIND_WETLAND_STUMP: Vector2(76.0, 66.0),
	KIND_FROZEN_SNOW_ROCK: Vector2(78.0, 60.0),
	KIND_FROZEN_PINE: Vector2(92.0, 138.0),
	KIND_LAVA_BASALT_CHIMNEY: Vector2(82.0, 104.0),
	KIND_LAVA_OBSIDIAN_CLUSTER: Vector2(82.0, 64.0),
}


static func kind_for(biome: StringName, cell: Vector2i) -> StringName:
	var variant: int = posmod(cell.x * 37 + cell.y * 61 + cell.x * cell.y * 11, 2)
	match biome:
		&"oasis":
			return KIND_WETLAND_MANGROVE if variant == 0 else KIND_WETLAND_STUMP
		&"frozen":
			return KIND_FROZEN_SNOW_ROCK if variant == 0 else KIND_FROZEN_PINE
		&"lava":
			return KIND_LAVA_BASALT_CHIMNEY if variant == 0 else KIND_LAVA_OBSIDIAN_CLUSTER
		_:
			return KIND_DESERT_SANDSTONE_CLUSTER if variant == 0 else KIND_DESERT_IRONSTONE_OUTCROP


static func texture_for(kind: StringName) -> Texture2D:
	return TEXTURES.get(kind) as Texture2D


static func display_size_for(kind: StringName) -> Vector2:
	return DISPLAY_SIZES.get(kind, Vector2.ZERO) as Vector2


static func is_generated_kind(kind: StringName) -> bool:
	return kind in GENERATED_KINDS


static func debris_palette_for(kind: StringName) -> Array[Color]:
	match kind:
		KIND_WETLAND_MANGROVE, KIND_WETLAND_STUMP:
			return WETLAND_DEBRIS
		KIND_FROZEN_SNOW_ROCK:
			return FROZEN_ROCK_DEBRIS
		KIND_FROZEN_PINE:
			return FROZEN_PINE_DEBRIS
		KIND_LAVA_BASALT_CHIMNEY, KIND_LAVA_OBSIDIAN_CLUSTER:
			return LAVA_DEBRIS
		_:
			return DESERT_DEBRIS


static func material_family_for(kind: StringName) -> StringName:
	match kind:
		KIND_WETLAND_MANGROVE, KIND_WETLAND_STUMP:
			return &"wet_wood"
		KIND_FROZEN_SNOW_ROCK:
			return &"frozen_stone"
		KIND_FROZEN_PINE:
			return &"cold_wood"
		KIND_LAVA_BASALT_CHIMNEY:
			return &"basalt"
		KIND_LAVA_OBSIDIAN_CLUSTER:
			return &"obsidian"
		_:
			return &"dry_stone"


static func debris_profile_for(kind: StringName) -> Dictionary:
	var family: StringName = material_family_for(kind)
	return (DEBRIS_PROFILES.get(family, DEBRIS_PROFILES[&"dry_stone"]) as Dictionary).duplicate()


static func block_palette_for(kind: StringName) -> Dictionary:
	var family: StringName = material_family_for(kind)
	return (BLOCK_PALETTES.get(family, BLOCK_PALETTES[&"dry_stone"]) as Dictionary).duplicate()


static func get_required_paths() -> Array[String]:
	var result: Array[String] = []
	for kind: StringName in GENERATED_KINDS:
		var texture: Texture2D = texture_for(kind)
		if texture != null:
			result.append(texture.resource_path)
	return result
