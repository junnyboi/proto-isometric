extends RefCounted

const KIND_DESERT_ROCK: StringName = &"desert_rock"
const KIND_WETLAND_MANGROVE: StringName = &"wetland_mangrove"
const KIND_WETLAND_STUMP: StringName = &"wetland_stump"
const KIND_FROZEN_SNOW_ROCK: StringName = &"frozen_snow_rock"
const KIND_FROZEN_PINE: StringName = &"frozen_pine"
const KIND_LAVA_BASALT_CHIMNEY: StringName = &"lava_basalt_chimney"
const KIND_LAVA_OBSIDIAN_CLUSTER: StringName = &"lava_obsidian_cluster"

const GENERATED_KINDS: Array[StringName] = [
	KIND_WETLAND_MANGROVE,
	KIND_WETLAND_STUMP,
	KIND_FROZEN_SNOW_ROCK,
	KIND_FROZEN_PINE,
	KIND_LAVA_BASALT_CHIMNEY,
	KIND_LAVA_OBSIDIAN_CLUSTER,
]

const DESERT_DEBRIS: Array[Color] = [
	Color("934d35"), Color("bd7152"), Color("e8b861")
]
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

const TEXTURES: Dictionary = {
	KIND_WETLAND_MANGROVE: preload("res://assets/destructibles/wetland_mangrove.png"),
	KIND_WETLAND_STUMP: preload("res://assets/destructibles/wetland_stump.png"),
	KIND_FROZEN_SNOW_ROCK: preload("res://assets/destructibles/frozen_snow_rock.png"),
	KIND_FROZEN_PINE: preload("res://assets/destructibles/frozen_pine.png"),
	KIND_LAVA_BASALT_CHIMNEY: preload("res://assets/destructibles/lava_basalt_chimney.png"),
	KIND_LAVA_OBSIDIAN_CLUSTER: preload("res://assets/destructibles/lava_obsidian_cluster.png"),
}

const DISPLAY_SIZES: Dictionary = {
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
			return KIND_DESERT_ROCK


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


static func get_required_paths() -> Array[String]:
	var result: Array[String] = []
	for kind: StringName in GENERATED_KINDS:
		var texture: Texture2D = texture_for(kind)
		if texture != null:
			result.append(texture.resource_path)
	return result
