extends RefCounted

const REGION_KEYS: Dictionary = {
	&"desert": &"field_intel.region.desert",
	&"oasis": &"field_intel.region.oasis",
	&"frozen": &"field_intel.region.frozen",
	&"lava": &"field_intel.region.lava",
}
const PRIMARY_THREAT_KEYS: Dictionary = {
	&"desert": &"enemy.sandworm.name",
	&"oasis": &"enemy.mud_skimmer.name",
	&"frozen": &"enemy.rime_stalker.name",
	&"lava": &"enemy.cinder_crawler.name",
}
const SWARM_THREAT_KEYS: Dictionary = {
	&"desert": &"enemy.glassback_scarab.name",
	&"oasis": &"enemy.mire_tick.name",
	&"frozen": &"enemy.rime_shardling.name",
	&"lava": &"enemy.ember_skitter.name",
}
const RESOURCE_FAUNA_KEYS: Dictionary = {
	&"desert": &"fauna.dune_grazer.name",
	&"oasis": &"fauna.reedback.name",
	&"frozen": &"fauna.rimehorn.name",
	&"lava": &"fauna.ember_ram.name",
}
const OUTPOST_KINDS: Array[StringName] = [
	&"ancient_ruin",
	&"ancient_temple",
	&"ancient_ziggurat",
	&"ancient_palace",
	&"ancient_safehouse",
]
const SURFACE_KEYS: Dictionary = {
	&"sand": &"field_intel.surface.sand",
	&"salt": &"field_intel.surface.salt",
	&"ruin": &"field_intel.surface.ruin",
	&"rock": &"field_intel.surface.rock",
	&"wetland": &"field_intel.surface.wetland",
	&"mud": &"field_intel.surface.mud",
	&"snow": &"field_intel.surface.snow",
	&"blue_ice": &"field_intel.surface.blue_ice",
	&"lava": &"field_intel.surface.lava",
	&"volcanic_ash": &"field_intel.surface.volcanic_ash",
	&"lava_basalt": &"field_intel.surface.lava_basalt",
	&"void": &"field_intel.surface.void",
}


static func supports(biome: StringName, surface: StringName) -> bool:
	return REGION_KEYS.has(biome) and SURFACE_KEYS.has(surface)


static func supports_outpost(biome: StringName, outpost_kind: StringName) -> bool:
	return REGION_KEYS.has(biome) and outpost_kind in OUTPOST_KINDS


static func outpost_name_key(biome: StringName, outpost_kind: StringName) -> StringName:
	if not supports_outpost(biome, outpost_kind):
		return &""
	return StringName("outpost.name.%s.%s" % [biome, outpost_kind])


static func snapshot(biome: StringName, surface: StringName) -> Dictionary:
	if not supports(biome, surface):
		return {}
	return {
		&"biome": biome,
		&"surface": surface,
		&"region_key": REGION_KEYS[biome],
		&"surface_key": SURFACE_KEYS[surface],
		&"primary_threat_key": PRIMARY_THREAT_KEYS[biome],
		&"swarm_threat_key": SWARM_THREAT_KEYS[biome],
		&"resource_fauna_key": RESOURCE_FAUNA_KEYS[biome],
	}
