extends RefCounted

const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")

var _snapshot: Dictionary = {}


func restore(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)


func snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func count(container_id: StringName, item_id: StringName) -> int:
	return InventoryServiceScript.count_item(_snapshot, container_id, item_id)
