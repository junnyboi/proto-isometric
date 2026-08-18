extends Camera2D

const ResponsiveViewportScript: GDScript = preload("res://scripts/responsive_viewport.gd")


func _ready() -> void:
	get_viewport().size_changed.connect(_apply_responsive_zoom)
	_apply_responsive_zoom()


func get_responsive_zoom() -> float:
	return float(ResponsiveViewportScript.camera_zoom(get_viewport().get_visible_rect().size))


func _apply_responsive_zoom() -> void:
	var value: float = get_responsive_zoom()
	zoom = Vector2.ONE * value
