extends Resource

const REQUIRED_PATHS: Array[String] = [
	"res://assets/ui/modules/ram_plating.png",
	"res://assets/ui/modules/aftershock.png",
	"res://assets/ui/modules/storm_seal.png",
	"res://assets/vfx/pickups/worm_core.png",
	"res://assets/vfx/worm/ridge_segment.png",
	"res://assets/vfx/worm/breach_plume.png",
]
const DIRECTIONS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const STATES: Array[String] = ["walk", "attack"]


func validate_required() -> bool:
	for path: String in REQUIRED_PATHS:
		if not ResourceLoader.exists(path):
			return false
		var texture: Texture2D = load(path) as Texture2D
		if texture == null or texture.get_width() < 32 or texture.get_height() < 32:
			return false
	return true


func get_missing_optional() -> Array[String]:
	var missing: Array[String] = []
	for state: String in STATES:
		for direction: String in DIRECTIONS:
			var path: String = "res://assets/cardinal/cardinal_%s_%s.png" % [state, direction]
			if not ResourceLoader.exists(path):
				missing.append(path)
	return missing


func get_required_paths() -> Array[String]:
	return REQUIRED_PATHS.duplicate()
