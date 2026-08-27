extends SceneTree

const AnchorCatalogScript: GDScript = preload(
	"res://scripts/interaction_target_anchor_catalog.gd"
)
const NearbyIndexScript: GDScript = preload("res://scripts/world_nearby_interest_index.gd")
const OverlayScript: GDScript = preload("res://scripts/interaction_target_link_overlay.gd")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_anchor_catalog()
	await _test_overlay()
	_test_nearby_index()
	if _failures == 0:
		print("[INTERACTION_OVERLAY_AND_NEARBY_PASS] checks=%d" % _checks)
		quit(0)
	else:
		print(
			"[INTERACTION_OVERLAY_AND_NEARBY_FAIL] checks=%d failures=%d"
			% [_checks, _failures]
		)
		quit(1)


func _test_anchor_catalog() -> void:
	_check(
		"ION-01 anchor catalog is presentation-only with a safe cell-center default",
		(
			AnchorCatalogScript.offset_for(&"unknown") == Vector2.ZERO
			and AnchorCatalogScript.offset_for(&"facility") == Vector2(0.0, -16.0)
			and AnchorCatalogScript.has_explicit_offset(&"facility")
		),
	)


func _test_overlay() -> void:
	var overlay: Control = OverlayScript.new() as Control
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(overlay)
	await process_frame
	var state: Dictionary = _overlay_state(Vector2(640.0, 320.0), 1)
	var first_change: bool = bool(overlay.call("set_draw_state", state))
	var duplicate_change: bool = bool(overlay.call("set_draw_state", state.duplicate(true)))
	var camera_change: Dictionary = state.duplicate(true)
	camera_change[&"camera_generation"] = 2
	var second_change: bool = bool(overlay.call("set_draw_state", camera_change))
	_check(
		"ION-02 one Control ignores mouse/focus and creates no target or connector nodes",
		(
			overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and overlay.focus_mode == Control.FOCUS_NONE
			and overlay.get_child_count() == 0
		),
	)
	_check(
		"ION-03 duplicate state is ignored while dirty changes coalesce before a frame",
		(
			first_change
			and not duplicate_change
			and second_change
			and int(overlay.call("get_redraw_request_count")) == 0
			and bool(overlay.call("is_redraw_pending"))
		),
	)
	await process_frame
	await process_frame
	var redraws: int = int(overlay.call("get_redraw_request_count"))
	_check(
		"ION-04 dirty notifications request at most one redraw for the frame",
		redraws == 1 and int(overlay.call("get_draw_count")) >= 1,
	)
	for _frame: int in 12:
		overlay.call("set_draw_state", camera_change.duplicate(true))
		await process_frame
	_check(
		"ION-05 unchanged stabilized state produces zero redraw requests",
		int(overlay.call("get_redraw_request_count")) == redraws,
	)
	var offscreen: Dictionary = camera_change.duplicate(true)
	offscreen[&"target_screen_anchor"] = Vector2(1800.0, -300.0)
	_check(
		"ION-06 offscreen sealed anchor is accepted without retargeting its identity",
		(
			overlay.call("set_draw_state", offscreen)
			and (overlay.call("get_draw_state") as Dictionary)[&"snapshot_id"] == &"sealed.alpha"
			and (overlay.call("get_draw_state") as Dictionary)[&"target_id"] == &"facility.alpha"
		),
	)
	await process_frame
	await process_frame
	_check(
		"ION-07 offscreen edge fallback draws safely and hides connector routing",
		int(overlay.call("get_draw_count")) >= 2,
	)
	overlay.free()
	await process_frame


func _test_nearby_index() -> void:
	var index: RefCounted = NearbyIndexScript.new() as RefCounted
	var records: Array[Dictionary] = [
		_record(&"selected", Vector2i.ZERO, true, 7),
		_record(&"zeta", Vector2i(2, 0), true, 7),
		_record(&"alpha", Vector2i(0, 2), true, 7),
		_record(&"hidden", Vector2i(1, 0), false, 7),
		_record(&"outside", Vector2i(25, 0), true, 7),
		_record(&"near", Vector2i(-1, 0), true, 7),
		_record(&"four", Vector2i(0, 4), true, 7),
		_record(&"five", Vector2i(0, 5), true, 7),
	]
	var built: bool = bool(index.call("rebuild", records, 7))
	var result: Array = index.call("query", Vector2i.ZERO, 999, &"selected", 999) as Array
	var ids: Array[StringName] = []
	var all_valid: bool = true
	for value: Variant in result:
		var row: Dictionary = value as Dictionary
		ids.append(row[&"interest_id"] as StringName)
		all_valid = all_valid and NearbyIndexScript.validate_result(row)
	_check(
		"ION-08 registered canonical records build revisioned chunk buckets",
		(
			built
			and int(index.call("get_build_count")) == 1
			and int(index.call("get_revision")) == 1
			and int(index.call("get_record_count")) == records.size()
			and int(index.call("get_bucket_count")) > 1
		),
	)
	_check(
		"ION-09 query caps radius/results and uses stable distance-then-ID ordering",
		(
			result.size() == NearbyIndexScript.MAX_RESULTS
			and ids == [&"near", &"alpha", &"zeta", &"four"]
			and all_valid
			and int((result[0] as Dictionary)[&"tile_distance"]) == 1
		),
	)
	_check(
		"ION-10 unavailable, selected, and radius-25 records are excluded",
		not &"hidden" in ids and not &"selected" in ids and not &"outside" in ids,
	)
	var query_count: int = int(index.call("get_query_count"))
	for _frame: int in 300:
		index.call("query", Vector2i.ZERO, 999, &"selected", 999)
	_check(
		"ION-11 unchanged target/index uses cached rows with zero additional queries",
		int(index.call("get_query_count")) == query_count,
	)
	var unchanged_build: bool = bool(index.call("rebuild", records, 7))
	_check(
		"ION-12 unchanged source revision performs zero additional bucket builds",
		not unchanged_build and int(index.call("get_build_count")) == 1,
	)
	var dense: Array[Dictionary] = []
	for item: int in 180:
		dense.append(
			_record(StringName("dense.%03d" % item), Vector2i(item % 7, item / 7), true, 8)
		)
	var rebuilt: bool = bool(index.call("rebuild", dense, 8))
	var dense_result: Array = index.call("query", Vector2i.ZERO, 24) as Array
	_check(
		"ION-13 dense queries examine at most 128 candidates and return at most four",
		(
			rebuilt
			and int(index.call("get_last_candidate_count")) <= NearbyIndexScript.MAX_CANDIDATES
			and dense_result.size() <= NearbyIndexScript.MAX_RESULTS
			and int(index.call("get_build_count")) == 2
			and int(index.call("get_revision")) == 2
		),
	)
	var malformed: Dictionary = _record(&"bad", Vector2i.ZERO, true, 9)
	var rejected_node: Node = Node.new()
	malformed[&"scene_node"] = rejected_node
	_check(
		"ION-14 exact canonical record schema rejects scene-node and revision leakage",
		(
			not NearbyIndexScript.validate_record(malformed)
			and not index.call("rebuild", [_record(&"wrong.rev", Vector2i.ZERO, true, 9)], 10)
		),
	)
	rejected_node.free()


static func _overlay_state(anchor: Vector2, camera_generation: int) -> Dictionary:
	return {
		&"visible": true,
		&"snapshot_id": &"sealed.alpha",
		&"target_cell": Vector2i(4, 6),
		&"target_id": &"facility.alpha",
		&"target_screen_anchor": anchor,
		&"panel_rects": [
			Rect2(20.0, 60.0, 320.0, 580.0),
			Rect2(940.0, 80.0, 300.0, 540.0),
		],
		&"safe_bounds": Rect2(12.0, 12.0, 1256.0, 696.0),
		&"viewport_size": Vector2(1280.0, 720.0),
		&"camera_generation": camera_generation,
		&"show_connectors": true,
		&"show_edge_marker": true,
		&"spotlight": true,
	}


static func _record(
	interest_id: StringName,
	cell: Vector2i,
	available: bool,
	source_revision: int,
) -> Dictionary:
	return {
		&"interest_id": interest_id,
		&"kind": &"facility",
		&"title_key": &"interaction.target.facility.title",
		&"cell": cell,
		&"source_revision": source_revision,
		&"available": available,
	}


func _check(label: String, passed: bool) -> void:
	_checks += 1
	print("[%s] %s" % ["PASS" if passed else "FAIL", label])
	if not passed:
		_failures += 1
