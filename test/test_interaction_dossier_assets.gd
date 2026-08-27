extends RefCounted

const CatalogScript: GDScript = preload("res://scripts/interaction_dossier_asset_catalog.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_add(
		cases,
		"DAS-01 generated atlases load at certified dimensions",
		CatalogScript.validate_assets(),
	)
	var icons: Array[Texture2D] = []
	for icon_id: StringName in [
		&"interaction.icon.procedural.inspect",
		&"interaction.icon.procedural.till",
		&"interaction.icon.procedural.water",
		&"interaction.icon.procedural.fish",
		&"interaction.icon.procedural.repair",
		&"interaction.icon.procedural.power",
		&"interaction.icon.procedural.open",
		&"interaction.icon.procedural.neutral",
	]:
		icons.append(CatalogScript.action_icon(icon_id))
	_add(cases, "DAS-02 canonical actions resolve bounded atlas regions", _regions_valid(icons))
	var targets: Array[Texture2D] = [
		CatalogScript.target_thumbnail(&"terrain", {&"farmable": true, &"blocked": false}),
		CatalogScript.target_thumbnail(&"water", {}),
		CatalogScript.target_thumbnail(&"plot", {}),
		CatalogScript.target_thumbnail(&"crop", {}),
		CatalogScript.target_thumbnail(&"tree", {}),
		CatalogScript.target_thumbnail(&"deposit", {}),
		CatalogScript.target_thumbnail(&"facility", {&"repaired": false}),
		CatalogScript.target_thumbnail(&"facility", {&"repaired": true}),
		CatalogScript.target_thumbnail(&"home", {}),
	]
	_add(
		cases,
		"DAS-03 canonical targets resolve truthful 256-pixel portraits",
		_regions_valid(targets),
	)
	var fallback: Texture2D = CatalogScript.action_icon(&"interaction.icon.procedural.unknown")
	_add(cases, "DAS-04 unknown actions use a stable neutral generated icon", fallback != null)
	return cases


static func _regions_valid(textures: Array[Texture2D]) -> bool:
	if textures.is_empty():
		return false
	for texture: Texture2D in textures:
		if not texture is AtlasTexture or texture.get_size() != Vector2(256.0, 256.0):
			return false
	return true


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
