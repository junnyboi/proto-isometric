extends Control

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const AMBER: Color = Color("f5a62d")
const PANEL: Color = Color("080c13e8")
const TEXT: Color = Color("f5f1e8")
const MUTED: Color = Color("9fada9")
const TEAL: Color = Color("55c9bd")
const WALKER_HIT_SIZE: Vector2 = Vector2(58.0, 82.0)
const CARD_SIZE: Vector2 = Vector2(342.0, 256.0)
const CARD_MARGIN: float = 16.0
const POINTER_OFFSET: Vector2 = Vector2(18.0, 18.0)
const LONG_PRESS_SECONDS: float = 0.55
const LONG_PRESS_DRAG_TOLERANCE: float = 18.0
const FADE_IN_SECONDS: float = 0.18

var _avatar: Node2D
var _enemies: Node2D
var _walker_snapshot_provider: Callable
var _walk_speed: float = 0.0
var _run_speed: float = 0.0
var _panel: PanelContainer
var _eyebrow_label: Label
var _name_label: Label
var _class_label: Label
var _stats_label: Label
var _lore_label: Label
var _current_candidate: Dictionary = {}
var _last_signature: String = ""
var _touch_candidate: Dictionary = {}
var _touch_index: int = -1
var _touch_origin: Vector2 = Vector2.ZERO
var _touch_position: Vector2 = Vector2.ZERO
var _touch_elapsed: float = 0.0
var _touch_pinned: bool = false
var _touch_mode: bool = false
var _fade_tween: Tween


func _ready() -> void:
	name = "CharacterHoverCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_card()
	add_to_group("localization_listeners")


func bind_sources(
	avatar: Node2D,
	enemies: Node2D,
	walker_snapshot_provider: Callable,
	walk_speed: float,
	run_speed: float,
) -> bool:
	if avatar == null or enemies == null or not walker_snapshot_provider.is_valid():
		return false
	_avatar = avatar
	_enemies = enemies
	_walker_snapshot_provider = walker_snapshot_provider
	_walk_speed = maxf(walk_speed, 0.0)
	_run_speed = maxf(run_speed, _walk_speed)
	return true


func _process(delta: float) -> void:
	if _panel == null or _avatar == null or _enemies == null:
		return
	if _process_touch(delta):
		return
	_process_pointer()


func _process_touch(delta: float) -> bool:
	if _touch_index >= 0 and not _touch_pinned:
		advance_long_press(delta)
		return true
	if _touch_pinned:
		var refreshed: Dictionary = _refresh_candidate(_current_candidate)
		if refreshed.is_empty():
			dismiss_pinned()
		else:
			_apply_candidate(refreshed)
			_position_card(_touch_position)
		return true
	if _touch_mode:
		_clear_candidate()
		return true
	return false


func _process_pointer() -> void:
	var hovered_control: Control = get_viewport().gui_get_hovered_control()
	if hovered_control != null:
		_clear_candidate()
		return
	var pointer: Vector2 = get_viewport().get_mouse_position()
	var candidate: Dictionary = _resolve_candidate(pointer)
	if candidate.is_empty():
		_clear_candidate()
		return
	_apply_candidate(candidate)
	_position_card(pointer)


func is_card_visible() -> bool:
	return _panel != null and _panel.visible


func get_displayed_name() -> String:
	return _name_label.text if _name_label != null else ""


func get_displayed_stats() -> String:
	return _stats_label.text if _stats_label != null else ""


func get_current_profile() -> Dictionary:
	return _profile_for(_current_candidate).duplicate(true)


func get_card_alpha() -> float:
	return _panel.modulate.a if _panel != null else 0.0


func is_fade_in_active() -> bool:
	return _fade_tween != null and _fade_tween.is_running()


func begin_long_press(index: int, position: Vector2) -> bool:
	_touch_mode = true
	var candidate: Dictionary = _resolve_candidate(position)
	if _touch_index >= 0:
		return (
			index == _touch_index
			and candidate.get(&"key", &"") == _touch_candidate.get(&"key", &"")
		)
	if candidate.is_empty():
		dismiss_pinned()
		return false
	if _touch_pinned:
		dismiss_pinned()
	_touch_index = index
	_touch_origin = position
	_touch_position = position
	_touch_elapsed = 0.0
	_touch_candidate = candidate.duplicate(true)
	_clear_highlight()
	_current_candidate = candidate.duplicate(true)
	_apply_highlight()
	_panel.visible = false
	return true


func drag_long_press(index: int, position: Vector2) -> bool:
	if index != _touch_index:
		return false
	_touch_position = position
	if _touch_origin.distance_to(position) > LONG_PRESS_DRAG_TOLERANCE:
		_reset_touch_tracking()
		_clear_candidate()
		return false
	return true


func advance_long_press(delta: float) -> bool:
	if _touch_index < 0 or _touch_candidate.is_empty() or _touch_pinned:
		return false
	_touch_elapsed += maxf(delta, 0.0)
	if _touch_elapsed < LONG_PRESS_SECONDS:
		return false
	var candidate: Dictionary = _refresh_candidate(_touch_candidate)
	if candidate.is_empty():
		_reset_touch_tracking()
		return false
	_touch_pinned = true
	_apply_candidate(candidate)
	_position_card(_touch_position)
	Input.vibrate_handheld(18)
	return true


func end_long_press(index: int) -> bool:
	if index != _touch_index:
		return false
	_reset_touch_tracking()
	if not _touch_pinned:
		_clear_candidate()
	return true


func dismiss_pinned() -> void:
	_touch_pinned = false
	_reset_touch_tracking()
	_clear_candidate()


func is_long_press_active(index: int = -1) -> bool:
	return _touch_index >= 0 and (index < 0 or index == _touch_index)


func is_touch_pinned() -> bool:
	return _touch_pinned


func get_long_press_progress() -> float:
	return clampf(_touch_elapsed / LONG_PRESS_SECONDS, 0.0, 1.0)


static func long_press_is_within_drag_tolerance(origin: Vector2, position: Vector2) -> bool:
	return origin.distance_to(position) <= LONG_PRESS_DRAG_TOLERANCE


static func walker_profile(snapshot: Dictionary, walk_speed: float, run_speed: float) -> Dictionary:
	var chassis: int = int(snapshot.get(&"chassis", 0))
	var maximum: int = int(snapshot.get(&"max_chassis", 100))
	var impact: float = clampf(float(snapshot.get(&"impact_charge", 0.0)), 0.0, 1.0)
	return {
		&"id": &"walker",
		&"name_key": &"hover.walker.name",
		&"class_key": &"hover.walker.class",
		&"lore_key": &"hover.walker.lore",
		&"stats":
		[
			{
				&"label_key": &"hover.stat.integrity",
				&"value": "%03d / %03d" % [chassis, maximum],
			},
			{
				&"label_key": &"hover.stat.impact",
				&"value": "%03d%%" % roundi(impact * 100.0),
			},
			{
				&"label_key": &"hover.stat.drive",
				&"value": "%d / %d PX/S" % [roundi(walk_speed), roundi(run_speed)],
			},
		],
	}


static func enemy_profile(target: Dictionary) -> Dictionary:
	var kind: StringName = target.get(&"kind", &"sandworm") as StringName
	var state: StringName = target.get(&"state", &"burrow") as StringName
	return {
		&"id": StringName("enemy_%d" % int(target.get(&"id", -1))),
		&"name_key": target.get(&"name_key", &"enemy.sandworm.name"),
		&"class_key": StringName("hover.enemy.%s.class" % String(kind)),
		&"lore_key": StringName("hover.enemy.%s.lore" % String(kind)),
		&"stats":
		[
			{
				&"label_key": &"hover.stat.vitals",
				&"value":
				"%02d / %02d" % [int(target.get(&"health", 0)), int(target.get(&"max_health", 0))],
			},
			{
				&"label_key": &"hover.stat.strike",
				&"value": "%02d" % int(target.get(&"attack_damage", 0)),
			},
			{
				&"label_key": &"hover.stat.range",
				&"value": "%.2f T" % float(target.get(&"attack_range", 0.0)),
			},
			{
				&"label_key": &"hover.stat.state",
				&"value_key": StringName("hover.state.%s" % String(state)),
			},
		],
	}


static func validate_profile(profile: Dictionary) -> bool:
	if (
		StringName(profile.get(&"name_key", &"")) == &""
		or StringName(profile.get(&"class_key", &"")) == &""
		or StringName(profile.get(&"lore_key", &"")) == &""
	):
		return false
	var stats: Array = profile.get(&"stats", []) as Array
	if stats.size() < 3:
		return false
	for raw_stat: Variant in stats:
		var stat: Dictionary = raw_stat as Dictionary
		if StringName(stat.get(&"label_key", &"")) == &"":
			return false
		if (
			str(stat.get(&"value", "")).is_empty()
			and StringName(stat.get(&"value_key", &"")) == &""
		):
			return false
	return true


func _build_card() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DossierPanel"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = CARD_SIZE
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = PANEL
	panel_style.border_color = Color(AMBER, 0.86)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(2)
	panel_style.content_margin_left = 18.0
	panel_style.content_margin_top = 15.0
	panel_style.content_margin_right = 18.0
	panel_style.content_margin_bottom = 15.0
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 6)
	_panel.add_child(stack)
	_eyebrow_label = _label(12, AMBER)
	_eyebrow_label.text = LocalizationScript.t(&"hover.eyebrow")
	_eyebrow_label.name = "Eyebrow"
	stack.add_child(_eyebrow_label)
	_name_label = _label(23, TEXT)
	_name_label.name = "Name"
	stack.add_child(_name_label)
	_class_label = _label(12, TEAL)
	_class_label.name = "Class"
	stack.add_child(_class_label)
	var divider: ColorRect = ColorRect.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.color = Color(AMBER, 0.42)
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	stack.add_child(divider)
	_stats_label = _label(13, TEXT)
	_stats_label.name = "Stats"
	_stats_label.add_theme_constant_override("line_spacing", 3)
	stack.add_child(_stats_label)
	_lore_label = _label(12, MUTED)
	_lore_label.name = "Lore"
	_lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore_label.custom_minimum_size = Vector2(306.0, 48.0)
	stack.add_child(_lore_label)


func _label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _resolve_candidate(pointer: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = INF
	var avatar_center: Vector2 = _avatar.get_global_transform_with_canvas() * Vector2(0.0, -74.0)
	var avatar_delta: Vector2 = pointer - avatar_center
	var avatar_score: float = (
		Vector2(avatar_delta.x / WALKER_HIT_SIZE.x, avatar_delta.y / WALKER_HIT_SIZE.y).length()
	)
	if avatar_score <= 1.0:
		best = {&"type": &"walker", &"key": &"walker"}
		best_score = avatar_score
	var raw_targets: Array = _enemies.call("_get_character_hover_targets") as Array
	for raw_target: Variant in raw_targets:
		var target: Dictionary = raw_target as Dictionary
		var local_anchor: Vector2 = target.get(&"screen_position", Vector2.ZERO) as Vector2
		var center: Vector2 = _enemies.get_global_transform_with_canvas() * local_anchor
		var radius: float = maxf(float(target.get(&"hover_radius", 52.0)), 1.0)
		var score: float = pointer.distance_to(center) / radius
		if score <= 1.0 and score < best_score:
			best = {
				&"type": &"enemy",
				&"key": StringName("enemy_%d" % int(target.get(&"id", -1))),
				&"target": target,
			}
			best_score = score
	return best


func _refresh_candidate(candidate: Dictionary) -> Dictionary:
	var key: StringName = candidate.get(&"key", &"") as StringName
	if key == &"walker" and _avatar != null:
		return {&"type": &"walker", &"key": &"walker"}
	if candidate.get(&"type", &"") != &"enemy" or _enemies == null:
		return {}
	for raw_target: Variant in _enemies.call("_get_character_hover_targets") as Array:
		var target: Dictionary = raw_target as Dictionary
		if StringName("enemy_%d" % int(target.get(&"id", -1))) == key:
			return {&"type": &"enemy", &"key": key, &"target": target}
	return {}


func _apply_candidate(candidate: Dictionary) -> void:
	var changed: bool = candidate.get(&"key", &"") != _current_candidate.get(&"key", &"")
	if changed:
		_clear_highlight()
		_current_candidate = candidate.duplicate(true)
		_apply_highlight()
		_last_signature = ""
	var profile: Dictionary = _profile_for(candidate)
	var signature: String = JSON.stringify(profile)
	if signature != _last_signature:
		_update_card(profile)
		_last_signature = signature
	if changed or not _panel.visible:
		_play_fade_in()


func _profile_for(candidate: Dictionary) -> Dictionary:
	if candidate.get(&"type", &"") == &"walker":
		var snapshot: Dictionary = _walker_snapshot_provider.call() as Dictionary
		return walker_profile(snapshot, _walk_speed, _run_speed)
	if candidate.get(&"type", &"") == &"enemy":
		return enemy_profile(candidate.get(&"target", {}) as Dictionary)
	return {}


func _update_card(profile: Dictionary) -> void:
	if not validate_profile(profile):
		_clear_candidate()
		return
	_name_label.text = LocalizationScript.t(profile[&"name_key"])
	_class_label.text = LocalizationScript.t(profile[&"class_key"])
	var lines: PackedStringArray = []
	for raw_stat: Variant in profile[&"stats"] as Array:
		var stat: Dictionary = raw_stat as Dictionary
		var value: String = str(stat.get(&"value", ""))
		if value.is_empty():
			value = LocalizationScript.t(stat.get(&"value_key", &""))
		(
			lines
			. append(
				(
					LocalizationScript
					. t(
						&"hover.stat.line",
						{
							&"label": LocalizationScript.t(stat[&"label_key"]),
							&"value": value,
						},
					)
				)
			)
		)
	_stats_label.text = "\n".join(lines)
	_lore_label.text = LocalizationScript.t(profile[&"lore_key"])


func _position_card(pointer: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var next_position: Vector2 = pointer + POINTER_OFFSET
	if next_position.x + CARD_SIZE.x > viewport_size.x - CARD_MARGIN:
		next_position.x = pointer.x - CARD_SIZE.x - POINTER_OFFSET.x
	if next_position.y + CARD_SIZE.y > viewport_size.y - CARD_MARGIN:
		next_position.y = pointer.y - CARD_SIZE.y - POINTER_OFFSET.y
	var maximum: Vector2 = Vector2(
		maxf(CARD_MARGIN, viewport_size.x - CARD_SIZE.x - CARD_MARGIN),
		maxf(CARD_MARGIN, viewport_size.y - CARD_SIZE.y - CARD_MARGIN),
	)
	_panel.position = Vector2(
		clampf(next_position.x, CARD_MARGIN, maximum.x),
		clampf(next_position.y, CARD_MARGIN, maximum.y),
	)


func _apply_highlight() -> void:
	if _current_candidate.get(&"type", &"") == &"walker":
		_avatar.call("set_hovered", true)
	elif _current_candidate.get(&"type", &"") == &"enemy":
		var target: Dictionary = _current_candidate.get(&"target", {}) as Dictionary
		_enemies.call("_set_hovered_enemy", int(target.get(&"id", -1)))


func _clear_highlight() -> void:
	if _avatar != null:
		_avatar.call("set_hovered", false)
	if _enemies != null:
		_enemies.call("_set_hovered_enemy", -1)


func _clear_candidate() -> void:
	if _current_candidate.is_empty() and (_panel == null or not _panel.visible):
		return
	_clear_highlight()
	_current_candidate.clear()
	_last_signature = ""
	if _panel != null:
		_kill_fade_in()
		_panel.visible = false
		_panel.modulate.a = 1.0


func _play_fade_in() -> void:
	_kill_fade_in()
	_panel.modulate.a = 0.0
	_panel.visible = true
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.set_trans(Tween.TRANS_CUBIC)
	_fade_tween.set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN_SECONDS)


func _kill_fade_in() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _reset_touch_tracking() -> void:
	_touch_index = -1
	_touch_origin = Vector2.ZERO
	_touch_position = Vector2.ZERO
	_touch_elapsed = 0.0
	_touch_candidate.clear()


func _on_locale_changed(_locale: StringName) -> void:
	if _panel == null:
		return
	_eyebrow_label.text = LocalizationScript.t(&"hover.eyebrow")
	_last_signature = ""
	if not _current_candidate.is_empty():
		_update_card(_profile_for(_current_candidate))
