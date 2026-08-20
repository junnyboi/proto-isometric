extends RefCounted

const ExpeditionRadarScript: GDScript = preload("res://scripts/expedition_radar.gd")
const FrozenTundraScript: GDScript = preload("res://scripts/frozen_tundra.gd")
const LavaFieldsScript: GDScript = preload("res://scripts/lava_fields.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var desert: Vector2i = Vector2i(8, 10)
	var tundra: Dictionary = ExpeditionRadarScript.biome_navigation(
		desert, FrozenTundraScript.BIOME_FROZEN
	)
	var lava: Dictionary = ExpeditionRadarScript.biome_navigation(
		desert, LavaFieldsScript.BIOME_LAVA
	)
	_add(cases, "desert radar names a northeast Tundra route", tundra[&"direction"] == &"NE")
	_add(
		cases, "desert radar reports exact Tundra boundary distance", int(tundra[&"distance"]) == 18
	)
	_add(cases, "desert radar names a northwest Lava route", lava[&"direction"] == &"NW")
	_add(cases, "desert radar reports exact Lava boundary distance", int(lava[&"distance"]) == 16)
	var in_tundra: Dictionary = ExpeditionRadarScript.biome_navigation(
		Vector2i(8, -15), FrozenTundraScript.BIOME_FROZEN
	)
	_add(cases, "radar reports Tundra when Walker is inside it", bool(in_tundra[&"inside"]))
	var lava_from_tundra: Dictionary = ExpeditionRadarScript.biome_navigation(
		Vector2i(-15, -15), LavaFieldsScript.BIOME_LAVA
	)
	_add(
		cases,
		"Lava marker escapes Frozen priority before pointing southwest",
		lava_from_tundra[&"direction"] == &"SW"
	)
	_add(
		cases,
		"Lava marker never claims overlap inside Frozen",
		not bool(lava_from_tundra[&"inside"])
	)
	var in_lava: Dictionary = ExpeditionRadarScript.biome_navigation(
		Vector2i(-15, 8), LavaFieldsScript.BIOME_LAVA
	)
	_add(cases, "radar reports Lava Fields when Walker is inside them", bool(in_lava[&"inside"]))
	_test_enemy_contacts(cases)
	_test_layout(cases, Vector2(1280.0, 720.0), "desktop")
	_test_layout(cases, Vector2(844.0, 390.0), "short landscape")
	_test_layout(cases, Vector2(390.0, 844.0), "portrait")
	return cases


static func _test_enemy_contacts(cases: Array[Dictionary]) -> void:
	var contacts: Array[Dictionary] = (
		ExpeditionRadarScript
		. nearby_contacts(
			Vector2i(8, 10),
			[
				{
					&"id": 4,
					&"kind": &"mud_skimmer",
					&"state": &"intercept",
					&"position": Vector2(10.0, 11.0)
				},
				{
					&"id": 2,
					&"kind": &"sandworm",
					&"state": &"expose",
					&"position": Vector2(7.0, 8.0)
				},
				{
					&"id": 6,
					&"kind": &"rime_stalker",
					&"state": &"defeated",
					&"position": Vector2(9.0, 10.0)
				},
				{
					&"id": 8,
					&"kind": &"cinder_crawler",
					&"state": &"burrow",
					&"position": Vector2(30.0, 30.0)
				},
			]
		)
	)
	_add(cases, "radar shows only nearby active enemies", contacts.size() == 2)
	_add(cases, "enemy radar contacts sort by stable runtime ID", int(contacts[0][&"id"]) == 2)
	_add(
		cases,
		"enemy radar contacts preserve biome-native species",
		contacts[1][&"kind"] == &"mud_skimmer"
	)
	_add(
		cases,
		"enemy radar contact offsets remain Walker-relative",
		contacts[0][&"offset"] == Vector2(-1.0, -2.0)
	)


static func _test_layout(cases: Array[Dictionary], viewport: Vector2, name: String) -> void:
	var layout: Dictionary = ExpeditionRadarScript.layout_for(viewport)
	var rect: Rect2 = layout[&"rect"] as Rect2
	_add(
		cases,
		"%s biome radar remains inside the native viewport" % name,
		Rect2(Vector2.ZERO, viewport).encloses(rect),
	)


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
