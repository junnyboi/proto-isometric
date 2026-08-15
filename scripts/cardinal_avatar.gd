extends Node2D

signal impact_frame

const DIRECTIONS: Array[StringName] = [&"N", &"NE", &"E", &"SE", &"S", &"SW", &"W", &"NW"]
const STATES: Array[StringName] = [&"walk", &"attack"]
const SHEET_ROOT: String = "res://assets/cardinal"
const TARGET_RUNTIME_HEIGHT: float = 148.0
const ATTACK_DURATION: float = 0.42
const ATTACK_CONTACT_TIME: float = 0.22

const BONE: Color = Color("d9b28d")
const BONE_LIGHT: Color = Color("f0c7a0")
const BONE_SHADOW: Color = Color("9b684f")
const CHARCOAL: Color = Color("17191d")
const JOINT: Color = Color("34363c")
const AMBER: Color = Color("e29035")

var _sprite: AnimatedSprite2D
var _frames: SpriteFrames = SpriteFrames.new()
var _available: Dictionary = {}
var _facing: StringName = &"SE"
var _moving: bool = false
var _speed_ratio: float = 0.0
var _gait_phase: float = 0.0
var _attack_time: float = 0.0
var _impact_emitted: bool = false
var _using_proxy: bool = true
var _source_cell_size: int = 0


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "DirectionalSprite"
	_sprite.centered = true
	_sprite.position = Vector2(0.0, -TARGET_RUNTIME_HEIGHT * 0.5)
	_sprite.sprite_frames = _frames
	add_child(_sprite)
	_load_directional_sheets()
	if _source_cell_size > 0:
		_sprite.scale = Vector2.ONE * (TARGET_RUNTIME_HEIGHT / float(_source_cell_size))
	_apply_animation()
	queue_redraw()


func _process(delta: float) -> void:
	if _attack_time > 0.0:
		_attack_time = maxf(_attack_time - delta, 0.0)
		var attack_elapsed: float = ATTACK_DURATION - _attack_time
		if not _impact_emitted and attack_elapsed >= ATTACK_CONTACT_TIME:
			_impact_emitted = true
			impact_frame.emit()
		if _attack_time == 0.0:
			_apply_animation()
	if _moving:
		_gait_phase = fmod(
			_gait_phase + delta * lerpf(5.0, 9.0, clampf(_speed_ratio, 0.0, 1.5)), TAU
		)
	queue_redraw()


func set_motion(facing: StringName, moving: bool, speed_ratio: float) -> void:
	if facing in DIRECTIONS:
		_facing = facing
	_moving = moving
	_speed_ratio = maxf(speed_ratio, 0.0)
	if _attack_time <= 0.0:
		_apply_animation()
	queue_redraw()


func play_attack() -> void:
	_attack_time = ATTACK_DURATION
	_impact_emitted = false
	_apply_animation()
	queue_redraw()


func get_animation_name(state: StringName, facing: StringName) -> StringName:
	return StringName("%s_%s" % [state, String(facing).to_lower()])


func get_missing_directions(state: StringName = &"walk") -> Array[StringName]:
	var missing: Array[StringName] = []
	for direction: StringName in DIRECTIONS:
		if not bool(_available.get(get_animation_name(state, direction), false)):
			missing.append(direction)
	return missing


func is_using_proxy() -> bool:
	return _using_proxy


func get_facing() -> StringName:
	return _facing


func _load_directional_sheets() -> void:
	for state: StringName in STATES:
		for direction: StringName in DIRECTIONS:
			var animation: StringName = get_animation_name(state, direction)
			var path: String = (
				"%s/cardinal_%s_%s.png" % [SHEET_ROOT, String(state), String(direction).to_lower()]
			)
			if not ResourceLoader.exists(path):
				continue
			var texture: Texture2D = load(path) as Texture2D
			if texture == null:
				continue
			var texture_size: Vector2i = Vector2i(texture.get_size())
			var cell_size: int = texture_size.y
			if cell_size <= 0 or texture_size.x % cell_size != 0:
				push_warning("Ignoring malformed Cardinal sheet: %s" % path)
				continue
			if _source_cell_size == 0:
				_source_cell_size = cell_size
			elif cell_size != _source_cell_size:
				push_warning("Ignoring mismatched Cardinal cell size: %s" % path)
				continue
			_frames.add_animation(animation)
			_frames.set_animation_loop(animation, state == &"walk")
			_frames.set_animation_speed(animation, 12.0 if state == &"walk" else 15.0)
			for frame_index: int in range(texture_size.x / cell_size):
				var atlas: AtlasTexture = AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(frame_index * cell_size, 0, cell_size, cell_size)
				_frames.add_frame(animation, atlas)
			_available[animation] = true


func _apply_animation() -> void:
	var state: StringName = &"attack" if _attack_time > 0.0 else &"walk"
	var animation: StringName = get_animation_name(state, _facing)
	_using_proxy = not bool(_available.get(animation, false))
	_sprite.visible = not _using_proxy
	if _using_proxy:
		_sprite.stop()
		return
	_sprite.speed_scale = clampf(_speed_ratio, 0.55, 1.5) if state == &"walk" else 1.0
	if _sprite.animation != animation or not _sprite.is_playing():
		_sprite.play(animation)
	if state == &"walk" and not _moving:
		_sprite.pause()
		_sprite.frame = 0


func _draw() -> void:
	if not _using_proxy:
		return
	var direction: Vector2 = _direction_vector(_facing)
	var side: float = direction.x
	var backness: float = -direction.y
	var gait: float = sin(_gait_phase) * (5.0 * clampf(_speed_ratio, 0.0, 1.0)) if _moving else 0.0
	var attack: float = sin((_attack_time / ATTACK_DURATION) * PI) if _attack_time > 0.0 else 0.0
	var body_y: float = -76.0 + absf(sin(_gait_phase * 2.0)) * 2.0 if _moving else -76.0

	_draw_flat_ellipse(Vector2(0.0, 3.0), Vector2(56.0, 17.0), Color(0.05, 0.04, 0.03, 0.34))

	var far_arm_x: float = -38.0 + side * 5.0
	var near_arm_x: float = 38.0 + side * 5.0
	var far_arm_y: float = body_y + 29.0 + gait
	var near_arm_y: float = body_y + 29.0 - gait
	if attack > 0.0:
		near_arm_y += attack * 24.0
		near_arm_x += side * attack * 18.0

	_draw_leg(Vector2(-17.0 - side * 4.0, body_y + 39.0), -gait * 0.45, true)
	_draw_leg(Vector2(17.0 - side * 4.0, body_y + 39.0), gait * 0.45, false)
	_draw_arm(Vector2(far_arm_x, far_arm_y), false, attack * 0.35)

	var shell: PackedVector2Array = PackedVector2Array(
		[
			Vector2(-50.0 + side * 5.0, body_y + 14.0),
			Vector2(-39.0 + side * 3.0, body_y - 26.0),
			Vector2(-13.0, body_y - 40.0),
			Vector2(28.0 + side * 4.0, body_y - 35.0),
			Vector2(51.0 + side * 6.0, body_y - 5.0),
			Vector2(40.0 + side * 4.0, body_y + 35.0),
			Vector2(-35.0 + side * 4.0, body_y + 37.0),
		]
	)
	draw_colored_polygon(shell, BONE if backness < 0.25 else BONE_SHADOW.lightened(0.16))
	draw_polyline(PackedVector2Array(Array(shell) + [shell[0]]), CHARCOAL, 4.0)
	draw_line(Vector2(-25.0, body_y - 29.0), Vector2(31.0, body_y - 25.0), BONE_LIGHT, 3.0)
	draw_line(Vector2(-42.0, body_y + 4.0), Vector2(42.0, body_y + 8.0), BONE_SHADOW, 4.0)
	draw_rect(Rect2(Vector2(-19.0, body_y + 26.0), Vector2(38.0, 14.0)), CHARCOAL)
	if backness < 0.35:
		draw_circle(Vector2(side * 13.0, body_y + 7.0), 7.0, CHARCOAL)
		draw_circle(Vector2(side * 13.0, body_y + 7.0), 3.0, AMBER)
	else:
		draw_rect(Rect2(Vector2(-15.0, body_y - 40.0), Vector2(10.0, 10.0)), JOINT)
		draw_rect(Rect2(Vector2(8.0, body_y - 39.0), Vector2(10.0, 10.0)), JOINT)

	_draw_arm(Vector2(near_arm_x, near_arm_y), true, attack)


func _draw_arm(origin: Vector2, near: bool, attack: float) -> void:
	var shade: Color = BONE if near else BONE_SHADOW
	var lower: Vector2 = origin + Vector2(3.0, 38.0 - attack * 12.0)
	draw_line(origin, lower, CHARCOAL, 25.0)
	draw_line(origin, lower, shade, 18.0)
	draw_circle(origin, 13.0, JOINT)
	var fist_size: Vector2 = Vector2(26.0, 32.0) * (1.0 + attack * 0.08)
	draw_rect(Rect2(lower - fist_size * 0.5, fist_size), shade)
	draw_rect(Rect2(lower + Vector2(-11.0, 7.0), Vector2(22.0, 7.0)), CHARCOAL)


func _draw_leg(origin: Vector2, gait: float, far: bool) -> void:
	var shade: Color = BONE_SHADOW if far else BONE
	var foot: Vector2 = origin + Vector2(gait, 35.0)
	draw_line(origin, foot, CHARCOAL, 15.0)
	draw_line(origin, foot, shade, 9.0)
	draw_rect(Rect2(foot + Vector2(-10.0, -2.0), Vector2(21.0, 9.0)), CHARCOAL)


func _direction_vector(facing: StringName) -> Vector2:
	var directions: Dictionary = {
		&"N": Vector2(0.0, -1.0),
		&"NE": Vector2(1.0, -1.0).normalized(),
		&"E": Vector2(1.0, 0.0),
		&"SE": Vector2(1.0, 1.0).normalized(),
		&"S": Vector2(0.0, 1.0),
		&"SW": Vector2(-1.0, 1.0).normalized(),
		&"W": Vector2(-1.0, 0.0),
		&"NW": Vector2(-1.0, -1.0).normalized(),
	}
	return directions.get(facing, Vector2(1.0, 1.0).normalized()) as Vector2


func _draw_flat_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(24):
		var angle: float = TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
