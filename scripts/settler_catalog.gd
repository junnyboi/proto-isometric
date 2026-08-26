extends RefCounted

const AMARA_VOSS: StringName = &"settler.amara_voss"
const TOMAS_REED: StringName = &"settler.tomas_reed"
const KEIKO_TAN: StringName = &"settler.keiko_tan"
const MALIK_OKAFOR: StringName = &"settler.malik_okafor"
const ELENA_MOROZ: StringName = &"settler.elena_moroz"
const NOOR_HADDAD: StringName = &"settler.noor_haddad"
const ISHAN_PATEL: StringName = &"settler.ishan_patel"
const MAEVE_QUINN: StringName = &"settler.maeve_quinn"

const IDS: Array[StringName] = [
	AMARA_VOSS,
	TOMAS_REED,
	KEIKO_TAN,
	MALIK_OKAFOR,
	ELENA_MOROZ,
	NOOR_HADDAD,
	ISHAN_PATEL,
	MAEVE_QUINN,
]
const DEFINITIONS: Array[Dictionary] = [
	{
		&"settler_id": AMARA_VOSS,
		&"name": "Amara Voss",
		&"pronouns_key": &"settlement.pronouns.she_her",
		&"bio_key": &"settlement.bio.amara_voss",
		&"trait_keys": [&"settlement.trait.resourceful", &"settlement.trait.communal"],
		&"need_keys": [&"settlement.need.safety", &"settlement.need.community"],
		&"preferred_job_types": [&"fabrication", &"repair"],
		&"portrait_path": "res://assets/settlement/settlers/portraits/settler_amara_voss.png",
		&"sprite_path": "res://assets/settlement/settlers/sprites/settler_amara_voss.png",
	},
	{
		&"settler_id": TOMAS_REED,
		&"name": "Tomas Reed",
		&"pronouns_key": &"settlement.pronouns.he_him",
		&"bio_key": &"settlement.bio.tomas_reed",
		&"trait_keys": [&"settlement.trait.resilient", &"settlement.trait.observant"],
		&"need_keys": [&"settlement.need.rest", &"settlement.need.autonomy"],
		&"preferred_job_types": [&"salvage", &"hauling"],
		&"portrait_path": "res://assets/settlement/settlers/portraits/settler_tomas_reed.png",
		&"sprite_path": "res://assets/settlement/settlers/sprites/settler_tomas_reed.png",
	},
	{
		&"settler_id": KEIKO_TAN,
		&"name": "Keiko Tan",
		&"pronouns_key": &"settlement.pronouns.she_her",
		&"bio_key": &"settlement.bio.keiko_tan",
		&"trait_keys": [&"settlement.trait.patient", &"settlement.trait.methodical"],
		&"need_keys": [&"settlement.need.daylight", &"settlement.need.quiet"],
		&"preferred_job_types": [&"cultivation", &"logistics"],
		&"portrait_path": "res://assets/settlement/settlers/portraits/settler_keiko_tan.png",
		&"sprite_path": "res://assets/settlement/settlers/sprites/settler_keiko_tan.png",
	},
	{
		&"settler_id": MALIK_OKAFOR,
		&"name": "Malik Okafor",
		&"pronouns_key": &"settlement.pronouns.he_him",
		&"bio_key": &"settlement.bio.malik_okafor",
		&"trait_keys": [&"settlement.trait.observant", &"settlement.trait.calm"],
		&"need_keys": [&"settlement.need.privacy", &"settlement.need.safety"],
		&"preferred_job_types": [&"mining", &"survey"],
		&"portrait_path": "res://assets/settlement/settlers/portraits/settler_malik_okafor.png",
		&"sprite_path": "res://assets/settlement/settlers/sprites/settler_malik_okafor.png",
	},
	{
		&"settler_id": ELENA_MOROZ,
		&"name": "Elena Moroz",
		&"pronouns_key": &"settlement.pronouns.she_her",
		&"bio_key": &"settlement.bio.elena_moroz",
		&"trait_keys": [&"settlement.trait.inventive", &"settlement.trait.methodical"],
		&"need_keys": [&"settlement.need.warm_meals", &"settlement.need.rest"],
		&"preferred_job_types": [&"repair", &"fabrication"],
		&"portrait_path": "res://assets/settlement/settlers/portraits/settler_elena_moroz.png",
		&"sprite_path": "res://assets/settlement/settlers/sprites/settler_elena_moroz.png",
	},
	{
		&"settler_id": NOOR_HADDAD,
		&"name": "Noor Haddad",
		&"pronouns_key": &"settlement.pronouns.they_them",
		&"bio_key": &"settlement.bio.noor_haddad",
		&"trait_keys": [&"settlement.trait.patient", &"settlement.trait.communal"],
		&"need_keys": [&"settlement.need.daylight", &"settlement.need.community"],
		&"preferred_job_types": [&"forestry", &"cultivation"],
		&"portrait_path": "res://assets/settlement/settlers/portraits/settler_noor_haddad.png",
		&"sprite_path": "res://assets/settlement/settlers/sprites/settler_noor_haddad.png",
	},
	{
		&"settler_id": ISHAN_PATEL,
		&"name": "Ishan Patel",
		&"pronouns_key": &"settlement.pronouns.he_him",
		&"bio_key": &"settlement.bio.ishan_patel",
		&"trait_keys": [&"settlement.trait.calm", &"settlement.trait.resourceful"],
		&"need_keys": [&"settlement.need.quiet", &"settlement.need.autonomy"],
		&"preferred_job_types": [&"fishing", &"maintenance"],
		&"portrait_path": "res://assets/settlement/settlers/portraits/settler_ishan_patel.png",
		&"sprite_path": "res://assets/settlement/settlers/sprites/settler_ishan_patel.png",
	},
	{
		&"settler_id": MAEVE_QUINN,
		&"name": "Maeve Quinn",
		&"pronouns_key": &"settlement.pronouns.she_her",
		&"bio_key": &"settlement.bio.maeve_quinn",
		&"trait_keys": [&"settlement.trait.resilient", &"settlement.trait.inventive"],
		&"need_keys": [&"settlement.need.warm_meals", &"settlement.need.privacy"],
		&"preferred_job_types": [&"logistics", &"hauling"],
		&"portrait_path": "res://assets/settlement/settlers/portraits/settler_maeve_quinn.png",
		&"sprite_path": "res://assets/settlement/settlers/sprites/settler_maeve_quinn.png",
	},
]


static func ids() -> Array[StringName]:
	return IDS.duplicate()


static func definition(settler_id: StringName) -> Dictionary:
	for candidate: Dictionary in DEFINITIONS:
		if candidate[&"settler_id"] == settler_id:
			return _with_textures(candidate)
	return {}


static func deterministic_offer_id(
	world_seed: int,
	offer_day: int,
	sequence: int,
	excluded: Array[StringName] = [],
) -> StringName:
	var available: Array[StringName] = []
	for settler_id: StringName in IDS:
		if settler_id not in excluded:
			available.append(settler_id)
	if available.is_empty():
		return &""
	var key: String = "%d|%d|%d" % [world_seed, offer_day, sequence]
	var value: int = 2_166_136_261
	for character: int in key.to_utf8_buffer():
		value = int((value ^ character) * 16_777_619) & 0x7fffffff
	return available[posmod(value, available.size())]


static func validate() -> bool:
	if DEFINITIONS.size() != IDS.size():
		return false
	var seen: Dictionary = {}
	for candidate: Dictionary in DEFINITIONS:
		var settler_id: StringName = candidate.get(&"settler_id", &"") as StringName
		if settler_id not in IDS or seen.has(settler_id) or not _valid_definition(candidate):
			return false
		seen[settler_id] = true
	return seen.size() == IDS.size()


static func _with_textures(source: Dictionary) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	result[&"portrait"] = load(str(source[&"portrait_path"])) as Texture2D
	result[&"sprite"] = load(str(source[&"sprite_path"])) as Texture2D
	return result


static func _valid_definition(value: Dictionary) -> bool:
	var expected: Array[StringName] = [
		&"settler_id", &"name", &"pronouns_key", &"bio_key", &"trait_keys", &"need_keys",
		&"preferred_job_types", &"portrait_path", &"sprite_path",
	]
	if value.keys() != expected or not str(value[&"settler_id"]).begins_with("settler."):
		return false
	if str(value[&"name"]).is_empty() or not str(value[&"portrait_path"]).ends_with(".png"):
		return false
	if not str(value[&"sprite_path"]).ends_with(".png"):
		return false
	for key: StringName in [&"trait_keys", &"need_keys", &"preferred_job_types"]:
		var values: Array = value[key] as Array
		if values.size() != 2 or str(values[0]).is_empty() or str(values[1]).is_empty():
			return false
	return true
