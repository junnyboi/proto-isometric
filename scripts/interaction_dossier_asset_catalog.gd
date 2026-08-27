extends RefCounted

const ACTION_ATLAS: Texture2D = preload("res://assets/ui/dossier/dossier_action_icons.png")
const SURFACE_ATLAS: Texture2D = preload("res://assets/ui/dossier/dossier_surface_thumbnails.png")
const OBJECT_ATLAS: Texture2D = preload("res://assets/ui/dossier/dossier_object_portraits.png")
const ACTION_COLUMNS: int = 4
const TARGET_COLUMNS: int = 3
const ACTION_CELL: Vector2i = Vector2i(256, 256)
const TARGET_CELL: Vector2i = Vector2i(256, 256)

const ACTION_INDEX: Dictionary = {
	&"inspect": 0,
	&"range": 0,
	&"till": 1,
	&"plant": 2,
	&"buy": 2,
	&"gift": 2,
	&"water": 3,
	&"harvest": 4,
	&"fish": 5,
	&"repair": 6,
	&"service": 6,
	&"craft": 6,
	&"upgrade": 6,
	&"power": 7,
	&"ship": 8,
	&"return": 8,
	&"open": 9,
	&"neutral": 10,
	&"sleep": 11,
	&"demolish": 12,
	&"move": 15,
}

static var _action_cache: Dictionary = {}
static var _surface_cache: Dictionary = {}
static var _object_cache: Dictionary = {}


static func action_icon(icon_id: StringName) -> Texture2D:
	var suffix: StringName = StringName(str(icon_id).trim_prefix("interaction.icon.procedural."))
	var index: int = int(ACTION_INDEX.get(suffix, ACTION_INDEX[&"neutral"]))
	return _cached_region(_action_cache, ACTION_ATLAS, index, ACTION_COLUMNS, ACTION_CELL)


static func target_thumbnail(subkind: StringName, state: Dictionary) -> Texture2D:
	if subkind in [&"terrain", &"plot", &"crop", &"water", &"tree", &"deposit", &"pickup"]:
		return _surface_thumbnail(subkind, state)
	return _object_thumbnail(subkind, state)


static func validate_assets() -> bool:
	return (
		ACTION_ATLAS != null
		and ACTION_ATLAS.get_size() == Vector2(1024.0, 1024.0)
		and SURFACE_ATLAS != null
		and SURFACE_ATLAS.get_size() == Vector2(768.0, 768.0)
		and OBJECT_ATLAS != null
		and OBJECT_ATLAS.get_size() == Vector2(768.0, 768.0)
	)


static func _surface_thumbnail(subkind: StringName, state: Dictionary) -> Texture2D:
	var index: int = 0
	match subkind:
		&"water":
			index = 1
		&"plot":
			index = 2
		&"crop":
			index = 3
		&"tree":
			index = 4
		&"deposit":
			index = 5
		&"pickup":
			index = 6
		&"terrain":
			if bool(state.get(&"farmable", false)) and bool(state.get(&"blocked", false)):
				index = 7
	return _cached_region(_surface_cache, SURFACE_ATLAS, index, TARGET_COLUMNS, TARGET_CELL)


static func _object_thumbnail(subkind: StringName, state: Dictionary) -> Texture2D:
	var index: int = 0
	match subkind:
		&"home":
			index = 3
		&"storage", &"shipping":
			index = 4
		&"facility":
			index = 5 if bool(state.get(&"repaired", false)) else 0
		&"machine", &"functional_prop":
			index = 1
		&"resident", &"livestock", &"herd":
			index = 3
		&"ruin", &"construction":
			index = 0
		_:
			index = 2
	return _cached_region(_object_cache, OBJECT_ATLAS, index, TARGET_COLUMNS, TARGET_CELL)


static func _cached_region(
	cache: Dictionary,
	atlas: Texture2D,
	index: int,
	columns: int,
	cell_size: Vector2i,
) -> Texture2D:
	if cache.has(index):
		return cache[index] as Texture2D
	var region := AtlasTexture.new()
	region.atlas = atlas
	region.region = Rect2(
		Vector2(index % columns, index / columns) * Vector2(cell_size),
		Vector2(cell_size),
	)
	cache[index] = region
	return region
