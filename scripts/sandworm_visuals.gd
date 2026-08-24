extends RefCounted

const HEAD_TEXTURE: Texture2D = preload(
	"res://assets/enemies/sandworm/ironjaw_dune_burrower_head.png"
)
const BODY_TEXTURE: Texture2D = preload(
	"res://assets/enemies/sandworm/ironjaw_dune_burrower_body.png"
)
const TAIL_TEXTURE: Texture2D = preload(
	"res://assets/enemies/sandworm/ironjaw_dune_burrower_tail.png"
)
const APEX_HEAD_TEXTURE: Texture2D = preload("res://assets/enemies/sandworm/ironjaw_apex_head.png")
const APEX_BODY_TEXTURE: Texture2D = preload("res://assets/enemies/sandworm/ironjaw_apex_body.png")
const APEX_TAIL_TEXTURE: Texture2D = preload("res://assets/enemies/sandworm/ironjaw_apex_tail.png")
const APEX_HEAD_CRACKED_TEXTURE: Texture2D = preload(
	"res://assets/enemies/sandworm/ironjaw_apex_head_cracked.png"
)
const APEX_BODY_CRACKED_TEXTURE: Texture2D = preload(
	"res://assets/enemies/sandworm/ironjaw_apex_body_cracked.png"
)
const APEX_HEAD_BROKEN_TEXTURE: Texture2D = preload(
	"res://assets/enemies/sandworm/ironjaw_apex_head_broken.png"
)
const APEX_BODY_BROKEN_TEXTURE: Texture2D = preload(
	"res://assets/enemies/sandworm/ironjaw_apex_body_broken.png"
)
const BURROW_TEXTURES: Array[Texture2D] = [
	preload("res://assets/enemies/sandworm/ironjaw_burrow_01.png"),
	preload("res://assets/enemies/sandworm/ironjaw_burrow_02.png"),
	preload("res://assets/enemies/sandworm/ironjaw_burrow_03.png"),
]
const PART_SPECS: Array[Dictionary] = [
	{&"kind": &"body", &"distance": 63.0, &"scale": 0.208, &"wave": 5.8},
	{&"kind": &"body", &"distance": 116.0, &"scale": 0.195, &"wave": 9.1},
	{&"kind": &"body", &"distance": 167.0, &"scale": 0.185, &"wave": 11.5},
	{&"kind": &"tail", &"distance": 215.0, &"scale": 0.168, &"wave": 14.9},
]
const APEX_PART_SPECS: Array[Dictionary] = [
	{&"kind": &"body", &"distance": 86.0, &"scale": 0.31, &"wave": 7.0},
	{&"kind": &"body", &"distance": 158.0, &"scale": 0.298, &"wave": 10.0},
	{&"kind": &"body", &"distance": 227.0, &"scale": 0.283, &"wave": 13.0},
	{&"kind": &"body", &"distance": 293.0, &"scale": 0.268, &"wave": 16.0},
	{&"kind": &"body", &"distance": 356.0, &"scale": 0.25, &"wave": 19.0},
	{&"kind": &"tail", &"distance": 414.0, &"scale": 0.225, &"wave": 23.0},
]
const HEAD_SCALE: float = 0.297
const HEAD_RISE: Vector2 = Vector2(0.0, -28.0)
const APEX_HEAD_SCALE: float = 0.415
const APEX_HEAD_RISE: Vector2 = Vector2(0.0, -42.0)
const HEALTH: Color = Color("e75d46")
const HEALTH_BACK: Color = Color("1a1110")


static func draw_exposed_body(
	canvas: Node2D,
	center: Vector2,
	direction: Vector2,
	time: float,
	worm_id: int,
	state: StringName,
	health: int,
	max_health: int,
	alpha: float,
	hovered: bool,
	hit_flash: bool,
	is_boss: bool = false,
	armor_stage: int = 0,
) -> void:
	var screen_direction: Vector2 = _screen_direction(direction)
	if is_boss:
		_draw_apex(
			canvas,
			center,
			screen_direction,
			time,
			worm_id,
			state,
			health,
			max_health,
			alpha,
			hovered,
			hit_flash,
			armor_stage,
		)
		return
	var layout: Array[Dictionary] = build_layout(screen_direction, time, worm_id, state)
	var tint: Color = _presentation_tint(state, hovered, hit_flash, alpha)
	for part: Dictionary in layout:
		_draw_part(canvas, part, tint)
	var head_center: Vector2 = center + HEAD_RISE
	_draw_texture(canvas, HEAD_TEXTURE, head_center, screen_direction.angle(), HEAD_SCALE, tint)
	_draw_health_bar(canvas, head_center + Vector2(0.0, -88.0), health, max_health, alpha)


static func build_layout(
	screen_direction: Vector2, time: float, worm_id: int, state: StringName
) -> Array[Dictionary]:
	return _build_layout(
		screen_direction, time, worm_id, state, PART_SPECS, HEAD_RISE, 2.8, 5.2, 0.52
	)


static func build_boss_layout(
	screen_direction: Vector2, time: float, worm_id: int, state: StringName
) -> Array[Dictionary]:
	return _build_layout(
		screen_direction, time, worm_id, state, APEX_PART_SPECS, APEX_HEAD_RISE, 3.8, 6.1, 0.45
	)


static func texture_paths() -> PackedStringArray:
	return PackedStringArray(
		[HEAD_TEXTURE.resource_path, BODY_TEXTURE.resource_path, TAIL_TEXTURE.resource_path]
	)


static func boss_texture_paths() -> PackedStringArray:
	return PackedStringArray(
		[
			APEX_HEAD_TEXTURE.resource_path,
			APEX_BODY_TEXTURE.resource_path,
			APEX_TAIL_TEXTURE.resource_path,
			APEX_HEAD_CRACKED_TEXTURE.resource_path,
			APEX_BODY_CRACKED_TEXTURE.resource_path,
			APEX_HEAD_BROKEN_TEXTURE.resource_path,
			APEX_BODY_BROKEN_TEXTURE.resource_path,
		]
	)


static func burrow_texture_paths() -> PackedStringArray:
	return PackedStringArray(
		[
			BURROW_TEXTURES[0].resource_path,
			BURROW_TEXTURES[1].resource_path,
			BURROW_TEXTURES[2].resource_path,
		]
	)


static func draw_burrow_transition(
	canvas: Node2D, center: Vector2, worm: Dictionary, progress: float, alpha: float
) -> bool:
	var state: StringName = worm.get(&"state", &"missing") as StringName
	if state not in [&"burrow", &"intercept", &"dive"]:
		return false
	var frame: int = 0
	if state == &"intercept":
		frame = burrow_frame_index(progress, false)
	elif state == &"dive":
		frame = burrow_frame_index(progress, true)
	var direction: Vector2 = _screen_direction(worm.get(&"direction", Vector2.RIGHT) as Vector2)
	var boss: bool = bool(worm.get(&"is_boss", false))
	var scale: float = 0.36 if boss else 0.245
	var tint: Color = Color(1.0, 0.91, 0.76, alpha) if boss else Color(1.0, 1.0, 1.0, alpha)
	_draw_texture(
		canvas,
		BURROW_TEXTURES[frame],
		center + Vector2(0.0, -8.0 if boss else -4.0),
		direction.angle(),
		scale,
		tint,
	)
	return true


static func burrow_frame_index(progress: float, reverse: bool) -> int:
	var playback: float = 1.0 - progress if reverse else progress
	return clampi(floori(clampf(playback, 0.0, 0.9999) * 3.0), 0, 2)


static func _build_layout(
	screen_direction: Vector2,
	time: float,
	worm_id: int,
	state: StringName,
	specs: Array[Dictionary],
	head_rise: Vector2,
	staggered_speed: float,
	normal_speed: float,
	staggered_scale: float,
) -> Array[Dictionary]:
	var direction: Vector2 = (
		Vector2.RIGHT if screen_direction.is_zero_approx() else screen_direction.normalized()
	)
	var side: Vector2 = direction.orthogonal()
	var wave_speed: float = staggered_speed if state == &"staggered" else normal_speed
	var wave_scale: float = staggered_scale if state == &"staggered" else 1.0
	var identity_phase: float = float(worm_id % 17) * 0.41
	var layout: Array[Dictionary] = []
	for index: int in range(specs.size() - 1, -1, -1):
		var spec: Dictionary = specs[index]
		var phase: float = time * wave_speed + float(index) * 0.78 + identity_phase
		(
			layout
			. append(
				{
					&"kind": spec[&"kind"],
					&"offset":
					(
						head_rise
						- direction * float(spec[&"distance"])
						+ side * sin(phase) * float(spec[&"wave"]) * wave_scale
					),
					&"rotation": direction.angle() + sin(phase + 0.5) * 0.1 * wave_scale,
					&"scale": float(spec[&"scale"]),
				}
			)
		)
	return layout


static func _draw_apex(
	canvas: Node2D,
	center: Vector2,
	screen_direction: Vector2,
	time: float,
	worm_id: int,
	state: StringName,
	health: int,
	max_health: int,
	alpha: float,
	hovered: bool,
	hit_flash: bool,
	armor_stage: int,
) -> void:
	var stage: int = clampi(armor_stage, 0, 2)
	var textures: Array[Texture2D] = _apex_textures(stage)
	var tint: Color = _presentation_tint(state, hovered, hit_flash, alpha)
	if stage == 2 and not hovered and not hit_flash:
		tint = Color(1.0, 0.86, 0.72, alpha)
	for part: Dictionary in build_boss_layout(screen_direction, time, worm_id, state):
		var texture: Texture2D = textures[2] if part[&"kind"] == &"tail" else textures[1]
		_draw_texture(
			canvas,
			texture,
			center + (part[&"offset"] as Vector2),
			float(part[&"rotation"]),
			float(part[&"scale"]),
			tint,
		)
	var head_center: Vector2 = center + APEX_HEAD_RISE
	_draw_texture(canvas, textures[0], head_center, screen_direction.angle(), APEX_HEAD_SCALE, tint)
	_draw_boss_health(canvas, head_center + Vector2(0.0, -128.0), health, max_health, alpha)


static func _apex_textures(stage: int) -> Array[Texture2D]:
	if stage >= 2:
		return [APEX_HEAD_BROKEN_TEXTURE, APEX_BODY_BROKEN_TEXTURE, APEX_TAIL_TEXTURE]
	if stage == 1:
		return [APEX_HEAD_CRACKED_TEXTURE, APEX_BODY_CRACKED_TEXTURE, APEX_TAIL_TEXTURE]
	return [APEX_HEAD_TEXTURE, APEX_BODY_TEXTURE, APEX_TAIL_TEXTURE]


static func _draw_part(canvas: Node2D, part: Dictionary, tint: Color) -> void:
	var texture: Texture2D = TAIL_TEXTURE if part[&"kind"] == &"tail" else BODY_TEXTURE
	_draw_texture(
		canvas,
		texture,
		part[&"offset"] as Vector2,
		float(part[&"rotation"]),
		float(part[&"scale"]),
		tint,
	)


static func _draw_texture(
	canvas: Node2D,
	texture: Texture2D,
	position: Vector2,
	rotation: float,
	scale: float,
	tint: Color,
) -> void:
	canvas.draw_set_transform(position, rotation, Vector2.ONE * scale)
	canvas.draw_texture(texture, texture.get_size() * -0.5, tint)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _screen_direction(direction: Vector2) -> Vector2:
	if direction.is_zero_approx():
		return Vector2.RIGHT
	var projected: Vector2 = Vector2(direction.x - direction.y, (direction.x + direction.y) * 0.5)
	return projected.normalized()


static func _presentation_tint(
	state: StringName, hovered: bool, hit_flash: bool, alpha: float
) -> Color:
	var tint: Color = Color.WHITE
	if state == &"staggered":
		tint = Color("c4d7dc")
	if hovered:
		tint = Color("ffd27a")
	if hit_flash:
		tint = Color("fff3df")
	tint.a = alpha
	return tint


static func _draw_health_bar(
	canvas: Node2D, position: Vector2, health: int, max_health: int, alpha: float
) -> void:
	var width: float = 84.0
	(
		canvas
		. draw_rect(
			Rect2(position - Vector2(width * 0.5, 4.0), Vector2(width, 8.0)),
			Color(HEALTH_BACK, 0.88 * alpha),
		)
	)
	var ratio: float = clampf(float(health) / float(maxi(max_health, 1)), 0.0, 1.0)
	(
		canvas
		. draw_rect(
			Rect2(position - Vector2(width * 0.5 - 2.0, 2.0), Vector2((width - 4.0) * ratio, 4.0)),
			Color(HEALTH, alpha),
		)
	)


static func _draw_boss_health(
	canvas: Node2D, position: Vector2, health: int, max_health: int, alpha: float
) -> void:
	var width: float = 156.0
	(
		canvas
		. draw_rect(
			Rect2(position - Vector2(width * 0.5, 5.0), Vector2(width, 10.0)),
			Color(HEALTH_BACK, 0.92 * alpha),
		)
	)
	var ratio: float = clampf(float(health) / float(maxi(max_health, 1)), 0.0, 1.0)
	(
		canvas
		. draw_rect(
			Rect2(position - Vector2(width * 0.5 - 2.0, 3.0), Vector2((width - 4.0) * ratio, 6.0)),
			Color(HEALTH, alpha),
		)
	)
	for threshold: float in [1.0 / 3.0, 2.0 / 3.0]:
		var x: float = position.x - width * 0.5 + width * threshold
		canvas.draw_line(
			Vector2(x, position.y - 7.0), Vector2(x, position.y + 7.0), Color.WHITE, 2.0
		)
