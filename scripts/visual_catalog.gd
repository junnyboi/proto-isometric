extends Resource

const REQUIRED_PATHS: Array[String] = [
	"res://assets/title/title_scene_desktop.png",
	"res://assets/title/title_scene_mobile.png",
	"res://assets/walker/grunt_sprite_atlas.png",
	"res://assets/ui/modules/aftershock.png",
	"res://assets/ui/modules/storm_seal.png",
	"res://assets/vfx/pickups/worm_core.png",
	"res://assets/vfx/worm/ridge_segment.png",
	"res://assets/vfx/worm/breach_plume.png",
	"res://assets/walker/grunt_sprite_atlas.png",
	"res://assets/textures/terrain/oasis_wetland.png",
	"res://assets/textures/terrain/dark_mud.png",
	"res://assets/enemies/mud_skimmer.png",
	"res://assets/textures/terrain/tundra_snow.png",
	"res://assets/textures/terrain/blue_ice.png",
	"res://assets/enemies/rime_stalker.png",
	"res://assets/textures/terrain/lava_basalt.png",
	"res://assets/textures/terrain/volcanic_ash.png",
	"res://assets/textures/terrain/lava_flow.png",
	"res://assets/enemies/cinder_crawler.png",
	"res://assets/destructibles/wetland_mangrove.png",
	"res://assets/destructibles/wetland_stump.png",
	"res://assets/destructibles/frozen_snow_rock.png",
	"res://assets/destructibles/frozen_pine.png",
	"res://assets/destructibles/lava_basalt_chimney.png",
	"res://assets/destructibles/lava_obsidian_cluster.png",
	"res://assets/vfx/juice/impact_contact.png",
	"res://assets/vfx/juice/footstep_dust.png",
	"res://assets/vfx/juice/charge_ready.png",
	"res://assets/vfx/juice/relay_flare.png",
	"res://assets/vfx/juice/pickup_spark.png",
]


func validate_required() -> bool:
	for path: String in REQUIRED_PATHS:
		if not ResourceLoader.exists(path):
			return false
		var texture: Texture2D = load(path) as Texture2D
		if texture == null or texture.get_width() < 32 or texture.get_height() < 32:
			return false
	return true


func get_required_paths() -> Array[String]:
	return REQUIRED_PATHS.duplicate()
