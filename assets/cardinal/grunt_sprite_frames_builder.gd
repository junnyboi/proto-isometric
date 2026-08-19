class_name GruntSpriteFramesBuilder
extends RefCounted

const CELL_SIZE := Vector2i(256, 256)
const FRAME_COUNT := 25
const DEFAULT_FPS := 12.0
const ATLAS_SIZE := Vector2i(6400, 4096)
const ANIMATIONS := [
	{"name": &"walk_n", "row": 0, "loop": true},
	{"name": &"walk_ne", "row": 1, "loop": true},
	{"name": &"walk_e", "row": 2, "loop": true},
	{"name": &"walk_se", "row": 3, "loop": true},
	{"name": &"walk_s", "row": 4, "loop": true},
	{"name": &"walk_sw", "row": 5, "loop": true},
	{"name": &"walk_w", "row": 6, "loop": true},
	{"name": &"walk_nw", "row": 7, "loop": true},
	{"name": &"attack_n", "row": 8, "loop": false},
	{"name": &"attack_ne", "row": 9, "loop": false},
	{"name": &"attack_e", "row": 10, "loop": false},
	{"name": &"attack_se", "row": 11, "loop": false},
	{"name": &"attack_s", "row": 12, "loop": false},
	{"name": &"attack_sw", "row": 13, "loop": false},
	{"name": &"attack_w", "row": 14, "loop": false},
	{"name": &"attack_nw", "row": 15, "loop": false},
]


static func build(atlas: Texture2D) -> SpriteFrames:
	var library := SpriteFrames.new()
	library.remove_animation(&"default")
	if atlas == null:
		push_error("GruntSpriteFramesBuilder requires a loaded Texture2D atlas.")
		return library
	if Vector2i(atlas.get_size()) != ATLAS_SIZE:
		push_error(
			"Unexpected grunt atlas size: %s; expected %s" % [atlas.get_size(), ATLAS_SIZE]
		)
		return library

	for definition: Dictionary in ANIMATIONS:
		var animation: StringName = definition["name"]
		library.add_animation(animation)
		library.set_animation_speed(animation, DEFAULT_FPS)
		library.set_animation_loop_mode(
			animation,
			SpriteFrames.LOOP_LINEAR if definition["loop"] else SpriteFrames.LOOP_NONE
		)
		var row: int = definition["row"]
		for frame_index in range(FRAME_COUNT):
			var frame := AtlasTexture.new()
			frame.atlas = atlas
			frame.region = Rect2i(
				frame_index * CELL_SIZE.x,
				row * CELL_SIZE.y,
				CELL_SIZE.x,
				CELL_SIZE.y
			)
			frame.filter_clip = true
			library.add_frame(animation, frame)
	return library
