extends Node2D

signal impact_frame

const DIRECTIONS: Array[StringName] = [&"N", &"NE", &"E", &"SE", &"S", &"SW", &"W", &"NW"]
const STATES: Array[StringName] = [&"walk", &"attack"]
const AtlasTextureResource: Texture2D = preload("res://assets/walker/grunt_sprite_atlas.png")
const GruntSpriteFramesBuilderScript: GDScript = preload(
	"res://assets/walker/grunt_sprite_frames_builder.gd"
)
const TARGET_RUNTIME_HEIGHT: float = 148.0
const ATTACK_EVENT_FRAME: int = 11
const ATTACK_FPS: float = 12.0
const ATTACK_DURATION: float = float(GruntSpriteFramesBuilderScript.FRAME_COUNT) / ATTACK_FPS
const ATTACK_CONTACT_TIME: float = float(ATTACK_EVENT_FRAME) / ATTACK_FPS
const SPRITE_BASE_POSITION: Vector2 = Vector2(0.0, -TARGET_RUNTIME_HEIGHT * 0.5)

var _sprite: AnimatedSprite2D
var _frames: SpriteFrames
var _facing: StringName = &"SE"
var _moving: bool = false
var _speed_ratio: float = 0.0
var _attack_time: float = 0.0
var _impact_emitted: bool = false
var _using_proxy: bool = true
var _redraw_request_count: int = 0
var _hovered: bool = false
var _impact_hold_time: float = 0.0
var _presentation_offset: Vector2 = Vector2.ZERO
var _presentation_recovery: float = 0.0


func _ready() -> void:
	_frames = GruntSpriteFramesBuilderScript.build(AtlasTextureResource)
	_using_proxy = not _atlas_contract_is_valid()
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "DirectionalSprite"
	_sprite.centered = true
	_sprite.position = SPRITE_BASE_POSITION
	_sprite.scale = (
		Vector2.ONE * (TARGET_RUNTIME_HEIGHT / float(GruntSpriteFramesBuilderScript.CELL_SIZE.y))
	)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.sprite_frames = _frames
	_sprite.visible = not _using_proxy
	add_child(_sprite)
	_apply_animation()
	if _using_proxy:
		_request_redraw()


func _process(delta: float) -> void:
	_advance_impact_presentation(delta)
	if _impact_hold_time > 0.0:
		return
	if _attack_time > 0.0:
		_attack_time = maxf(_attack_time - maxf(delta, 0.0), 0.0)
		var attack_elapsed: float = ATTACK_DURATION - _attack_time
		if not _using_proxy:
			_sprite.frame = mini(floori(attack_elapsed * ATTACK_FPS), ATTACK_EVENT_FRAME * 2 + 2)
		if not _impact_emitted and attack_elapsed >= ATTACK_CONTACT_TIME:
			_impact_emitted = true
			impact_frame.emit()
		if _attack_time == 0.0:
			_apply_animation()


func set_motion(facing: StringName, moving: bool, speed_ratio: float) -> void:
	if facing in DIRECTIONS:
		_facing = facing
	_moving = moving
	_speed_ratio = maxf(speed_ratio, 0.0)
	if _attack_time <= 0.0:
		_apply_animation()


func play_attack() -> void:
	_attack_time = ATTACK_DURATION
	_impact_emitted = false
	var animation: StringName = get_animation_name(&"attack", _facing)
	_set_proxy_usage(not _frames.has_animation(animation))
	if not _using_proxy:
		_sprite.speed_scale = 1.0
		_sprite.play(animation)
		_sprite.frame = 0


func get_animation_name(state: StringName, facing: StringName) -> StringName:
	return StringName("%s_%s" % [state, String(facing).to_lower()])


func get_missing_directions(state: StringName = &"walk") -> Array[StringName]:
	var missing: Array[StringName] = []
	for direction: StringName in DIRECTIONS:
		if not _frames.has_animation(get_animation_name(state, direction)):
			missing.append(direction)
	return missing


func get_animation_frame_count(state: StringName, facing: StringName) -> int:
	var animation: StringName = get_animation_name(state, facing)
	return _frames.get_frame_count(animation) if _frames.has_animation(animation) else 0


func get_animation_speed(state: StringName, facing: StringName) -> float:
	var animation: StringName = get_animation_name(state, facing)
	return _frames.get_animation_speed(animation) if _frames.has_animation(animation) else 0.0


func is_animation_looping(state: StringName, facing: StringName) -> bool:
	var animation: StringName = get_animation_name(state, facing)
	return _frames.get_animation_loop(animation) if _frames.has_animation(animation) else false


func get_attack_event_frame() -> int:
	return ATTACK_EVENT_FRAME


func get_attack_contact_time() -> float:
	return ATTACK_CONTACT_TIME


func get_attack_duration() -> float:
	return ATTACK_DURATION


func is_attacking() -> bool:
	return _attack_time > 0.0


func is_using_proxy() -> bool:
	return _using_proxy


func get_facing() -> StringName:
	return _facing


func get_active_animation() -> StringName:
	return _sprite.animation if _sprite != null else &""


func get_active_frame() -> int:
	return _sprite.frame if _sprite != null else -1


func get_redraw_request_count() -> int:
	return _redraw_request_count


func set_hovered(value: bool) -> void:
	if value == _hovered:
		return
	_hovered = value
	self_modulate = Color("ffe0a3") if value else Color.WHITE
	scale = Vector2.ONE * (1.04 if value else 1.0)


func is_hovered() -> bool:
	return _hovered


func _apply_impact_presentation(hold_seconds: float, direction: Vector2, strength: int) -> void:
	_impact_hold_time = maxf(_impact_hold_time, clampf(hold_seconds, 0.0, 0.12))
	_presentation_recovery = maxf(_presentation_recovery, 0.12)
	var normalized: Vector2 = (
		Vector2.RIGHT if direction.is_zero_approx() else direction.normalized()
	)
	_presentation_offset = -normalized * (2.0 + float(clampi(strength, 0, 2)) * 1.5)
	if _sprite != null and _sprite.is_playing():
		_sprite.pause()
	_apply_presentation_offset()


func _get_impact_presentation() -> Dictionary:
	return {&"hold": _impact_hold_time, &"offset": _presentation_offset}


func _atlas_contract_is_valid() -> bool:
	for state: StringName in STATES:
		for direction: StringName in DIRECTIONS:
			var animation: StringName = get_animation_name(state, direction)
			if (
				not _frames.has_animation(animation)
				or _frames.get_frame_count(animation) != GruntSpriteFramesBuilderScript.FRAME_COUNT
				or not is_equal_approx(_frames.get_animation_speed(animation), ATTACK_FPS)
				or _frames.get_animation_loop(animation) != (state == &"walk")
			):
				return false
	return true


func _apply_animation() -> void:
	var state: StringName = &"attack" if _attack_time > 0.0 else &"walk"
	var animation: StringName = get_animation_name(state, _facing)
	_set_proxy_usage(not _frames.has_animation(animation))
	if _using_proxy:
		_sprite.stop()
		return
	_sprite.speed_scale = clampf(_speed_ratio, 0.55, 1.5) if state == &"walk" else 1.0
	if _sprite.animation != animation:
		_sprite.play(animation)
	elif state == &"walk" and _moving and not _sprite.is_playing():
		_sprite.play()
	if state == &"walk" and not _moving:
		_sprite.pause()


func _set_proxy_usage(value: bool) -> void:
	var changed: bool = value != _using_proxy
	_using_proxy = value
	if _sprite != null:
		_sprite.visible = not _using_proxy
	if changed:
		_request_redraw()


func _advance_impact_presentation(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	var was_holding: bool = _impact_hold_time > 0.0
	_impact_hold_time = maxf(_impact_hold_time - step, 0.0)
	if was_holding and _impact_hold_time <= 0.0 and _sprite != null and _attack_time > 0.0:
		_sprite.play()
	if _impact_hold_time <= 0.0 and _presentation_recovery > 0.0:
		_presentation_recovery = maxf(_presentation_recovery - step, 0.0)
		var blend: float = 1.0 - exp(-28.0 * step)
		_presentation_offset = _presentation_offset.lerp(Vector2.ZERO, blend)
		if _presentation_recovery <= 0.0:
			_presentation_offset = Vector2.ZERO
	_apply_presentation_offset()


func _apply_presentation_offset() -> void:
	if _sprite != null:
		_sprite.position = SPRITE_BASE_POSITION + _presentation_offset
	if _using_proxy:
		_request_redraw()


func _request_redraw() -> void:
	_redraw_request_count += 1
	queue_redraw()


func _draw() -> void:
	if not _using_proxy:
		return
	draw_set_transform(_presentation_offset)
	draw_circle(Vector2(0.0, -70.0), 34.0, Color("d9b28d"))
	draw_line(Vector2(-30.0, -60.0), Vector2(-42.0, -12.0), Color("17191d"), 18.0)
	draw_line(Vector2(30.0, -60.0), Vector2(42.0, -12.0), Color("17191d"), 18.0)
