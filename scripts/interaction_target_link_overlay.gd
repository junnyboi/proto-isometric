class_name InteractionTargetLinkOverlay
extends Control

const MAX_PANEL_ANCHORS: int = 2
const RING_RADIUS: float = 18.0
const EDGE_MARGIN: float = 15.0
const PANEL_GAP: float = 8.0
const CYAN: Color = Color("69e6ff")
const CYAN_FAINT: Color = Color(0.412, 0.902, 1.0, 0.16)
const CYAN_LINE: Color = Color(0.412, 0.902, 1.0, 0.82)

var _draw_state: Dictionary = _default_state()
var _dirty: bool = false
var _redraw_scheduled: bool = false
var _redraw_request_count: int = 0
var _draw_count: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process(false)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process(false)


func set_draw_state(state: Dictionary) -> bool:
	var normalized: Dictionary = _normalize_state(state)
	if normalized.is_empty() or normalized == _draw_state:
		return false
	_draw_state = normalized
	_mark_dirty()
	return true


func update_draw_state(state: Dictionary) -> bool:
	return set_draw_state(state)


func clear_draw_state() -> bool:
	return set_draw_state(_default_state())


func get_draw_state() -> Dictionary:
	return _draw_state.duplicate(true)


func get_redraw_request_count() -> int:
	return _redraw_request_count


func get_draw_count() -> int:
	return _draw_count


func is_redraw_pending() -> bool:
	return _redraw_scheduled


func _mark_dirty() -> void:
	_dirty = true
	if _redraw_scheduled:
		return
	_redraw_scheduled = true
	call_deferred("_flush_redraw")


func _flush_redraw() -> void:
	_redraw_scheduled = false
	if not _dirty:
		return
	_dirty = false
	_redraw_request_count += 1
	queue_redraw()


func _draw() -> void:
	_draw_count += 1
	if not bool(_draw_state[&"visible"]):
		return
	var safe_bounds: Rect2 = _draw_state[&"safe_bounds"] as Rect2
	var anchor: Vector2 = _draw_state[&"target_screen_anchor"] as Vector2
	if not safe_bounds.has_point(anchor):
		_draw_edge_marker(anchor, safe_bounds)
		return
	if bool(_draw_state[&"spotlight"]):
		draw_circle(anchor, RING_RADIUS + 10.0, CYAN_FAINT)
	_draw_ring_and_brackets(anchor)
	if bool(_draw_state[&"show_connectors"]):
		for panel_value: Variant in _draw_state[&"panel_rects"] as Array:
			_draw_connector(panel_value as Rect2, anchor, safe_bounds)


func _draw_ring_and_brackets(anchor: Vector2) -> void:
	draw_arc(anchor, RING_RADIUS, 0.0, TAU, 40, CYAN_LINE, 2.0, true)
	var outer: float = RING_RADIUS + 7.0
	var inner: float = RING_RADIUS + 1.0
	var half: float = 5.0
	for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		var tangent: Vector2 = Vector2(-direction.y, direction.x)
		var outer_center: Vector2 = anchor + direction * outer
		var inner_center: Vector2 = anchor + direction * inner
		draw_line(outer_center - tangent * half, outer_center + tangent * half, CYAN, 2.0, true)
		draw_line(outer_center, inner_center, CYAN, 2.0, true)


func _draw_connector(panel: Rect2, anchor: Vector2, safe_bounds: Rect2) -> void:
	if panel.has_point(anchor):
		return
	var start: Vector2 = _nearest_panel_edge(panel, anchor)
	var direction: Vector2 = (anchor - start).normalized()
	var finish: Vector2 = anchor - direction * (RING_RADIUS + 4.0)
	start = _clamp_point(start + direction * PANEL_GAP, safe_bounds)
	finish = _clamp_point(finish, safe_bounds)
	var horizontal_first: bool = absf(finish.x - start.x) >= absf(finish.y - start.y)
	var elbow: Vector2 = (
		Vector2(finish.x, start.y) if horizontal_first else Vector2(start.x, finish.y)
	)
	if panel.has_point(elbow):
		elbow = Vector2(start.x, finish.y) if horizontal_first else Vector2(finish.x, start.y)
	var points: PackedVector2Array = PackedVector2Array([start, elbow, finish])
	draw_polyline(points, CYAN_LINE, 2.0, true)
	draw_circle(start, 3.0, CYAN)


func _draw_edge_marker(anchor: Vector2, safe_bounds: Rect2) -> void:
	if not bool(_draw_state[&"show_edge_marker"]):
		return
	var center: Vector2 = safe_bounds.get_center()
	var direction: Vector2 = (anchor - center).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	var inset: Rect2 = safe_bounds.grow(-EDGE_MARGIN)
	var edge: Vector2 = _ray_rect_intersection(center, direction, inset)
	var tangent: Vector2 = Vector2(-direction.y, direction.x)
	var tip: Vector2 = edge + direction * 7.0
	var back: Vector2 = edge - direction * 7.0
	draw_colored_polygon(PackedVector2Array([tip, back + tangent * 6.0, back - tangent * 6.0]), CYAN)


static func _normalize_state(state: Dictionary) -> Dictionary:
	var required: Array[StringName] = [
		&"visible", &"snapshot_id", &"target_cell", &"target_id",
		&"target_screen_anchor", &"panel_rects", &"safe_bounds", &"viewport_size",
		&"camera_generation",
	]
	for key: StringName in required:
		if not state.has(key):
			return {}
	if (
		not state[&"visible"] is bool
		or not state[&"snapshot_id"] is StringName
		or not state[&"target_cell"] is Vector2i
		or not state[&"target_id"] is StringName
		or not state[&"target_screen_anchor"] is Vector2
		or not state[&"panel_rects"] is Array
		or not state[&"safe_bounds"] is Rect2
		or not state[&"viewport_size"] is Vector2
		or not state[&"camera_generation"] is int
	):
		return {}
	var panel_rects: Array[Rect2] = []
	for panel_value: Variant in state[&"panel_rects"] as Array:
		if not panel_value is Rect2 or panel_rects.size() >= MAX_PANEL_ANCHORS:
			return {}
		var panel: Rect2 = panel_value as Rect2
		if panel.size.x <= 0.0 or panel.size.y <= 0.0:
			return {}
		panel_rects.append(panel)
	var safe_bounds: Rect2 = state[&"safe_bounds"] as Rect2
	var viewport_size: Vector2 = state[&"viewport_size"] as Vector2
	if safe_bounds.size.x <= 0.0 or safe_bounds.size.y <= 0.0 or viewport_size.x <= 0.0:
		return {}
	if viewport_size.y <= 0.0 or int(state[&"camera_generation"]) < 0:
		return {}
	return {
		&"visible": state[&"visible"],
		&"snapshot_id": state[&"snapshot_id"],
		&"target_cell": state[&"target_cell"],
		&"target_id": state[&"target_id"],
		&"target_screen_anchor": state[&"target_screen_anchor"],
		&"panel_rects": panel_rects,
		&"safe_bounds": safe_bounds,
		&"viewport_size": viewport_size,
		&"camera_generation": state[&"camera_generation"],
		&"show_connectors": bool(state.get(&"show_connectors", true)),
		&"show_edge_marker": bool(state.get(&"show_edge_marker", true)),
		&"spotlight": bool(state.get(&"spotlight", false)),
	}


static func _default_state() -> Dictionary:
	return {
		&"visible": false,
		&"snapshot_id": &"",
		&"target_cell": Vector2i.ZERO,
		&"target_id": &"",
		&"target_screen_anchor": Vector2.ZERO,
		&"panel_rects": [],
		&"safe_bounds": Rect2(Vector2.ZERO, Vector2.ONE),
		&"viewport_size": Vector2.ONE,
		&"camera_generation": 0,
		&"show_connectors": true,
		&"show_edge_marker": true,
		&"spotlight": false,
	}


static func _nearest_panel_edge(panel: Rect2, anchor: Vector2) -> Vector2:
	var point: Vector2 = Vector2(
		clampf(anchor.x, panel.position.x, panel.end.x),
		clampf(anchor.y, panel.position.y, panel.end.y),
	)
	if not panel.has_point(anchor):
		return point
	var distances: Array[float] = [
		absf(anchor.x - panel.position.x), absf(panel.end.x - anchor.x),
		absf(anchor.y - panel.position.y), absf(panel.end.y - anchor.y),
	]
	var nearest: int = distances.find(distances.min())
	match nearest:
		0:
			point.x = panel.position.x
		1:
			point.x = panel.end.x
		2:
			point.y = panel.position.y
		_:
			point.y = panel.end.y
	return point


static func _clamp_point(point: Vector2, bounds: Rect2) -> Vector2:
	return Vector2(
		clampf(point.x, bounds.position.x, bounds.end.x),
		clampf(point.y, bounds.position.y, bounds.end.y),
	)


static func _ray_rect_intersection(origin: Vector2, direction: Vector2, bounds: Rect2) -> Vector2:
	var scale: float = INF
	if direction.x > 0.0:
		scale = minf(scale, (bounds.end.x - origin.x) / direction.x)
	elif direction.x < 0.0:
		scale = minf(scale, (bounds.position.x - origin.x) / direction.x)
	if direction.y > 0.0:
		scale = minf(scale, (bounds.end.y - origin.y) / direction.y)
	elif direction.y < 0.0:
		scale = minf(scale, (bounds.position.y - origin.y) / direction.y)
	return _clamp_point(origin + direction * scale, bounds)
