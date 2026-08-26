extends RefCounted

const CatalogScript: GDScript = preload("res://scripts/resource_deposit_catalog.gd")


static func validate(gathering: Dictionary) -> bool:
	if gathering.is_empty():
		return false
	for delta: Dictionary in gathering.get(&"resource_deltas", []) as Array[Dictionary]:
		if not _valid_delta(delta):
			return false
	return true


static func _valid_delta(delta: Dictionary) -> bool:
	var source_id: String = str(delta[&"source_id"])
	var kind: StringName = CatalogScript.source_kind_from_id(source_id)
	var cell: Vector2i = CatalogScript.cell_from_id(source_id)
	var canonical: StringName = CatalogScript.canonical_source_id(kind, cell)
	var policy: Dictionary = CatalogScript.definition(kind)
	if policy.is_empty() or str(canonical) != source_id:
		return false
	var remaining: int = int(delta[&"remaining_charges"])
	var renewal_day: int = int(delta[&"renewal_day"])
	var reserved_by: String = str(delta[&"reserved_by"])
	var capacity: int = int(policy[&"capacity"])
	if remaining > capacity:
		return false
	if not bool(policy[&"renewable"]) and renewal_day != 0:
		return false
	if bool(policy[&"renewable"]) and remaining == 0 and renewal_day <= 0:
		return false
	if remaining > 0 and renewal_day != 0:
		return false
	if remaining == capacity and renewal_day == 0 and reserved_by.is_empty():
		return false
	return true
