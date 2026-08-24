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
const PART_SPECS: Array[Dictionary] = [
	{&"kind": &"body", &"distance": 63.0, &"scale": 0.208, &"wave": 5.8},
	{&"kind": &"body", &"distance": 116.0, &"scale": 0.195, &"wave": 9.1},
	{&"kind": &"body", &"distance": 167.0, &"scale": 0.185, &"wave": 11.5},
	{&"kind": &"tail", &"distance": 215.0, &"scale": 0.168, &"wave": 14.9},
]
const HEAD_SCALE: float = 0.297
const HEAD_RISE: Vector2 = Vector2(0.0, -28.0)
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
) -> void:
	var screen_direction: Vector2 = _screen_direction(direction)
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
	var direction: Vector2 = (
		Vector2.RIGHT if screen_direction.is_zero_approx() else screen_direction.normalized()
	)
	var side: Vector2 = direction.orthogonal()
	var wave_speed: float = 2.8 if state == &"staggered" else 5.2
	var wave_scale: float = 0.52 if state == &"staggered" else 1.0
	var identity_phase: float = float(worm_id % 13) * 0.47
	var layout: Array[Dictionary] = []
	for index: int in range(PART_SPECS.size() - 1, -1, -1):
		var spec: Dictionary = PART_SPECS[index]
		var phase: float = time * wave_speed + float(index) * 0.86 + identity_phase
		var offset: float = sin(phase) * float(spec[&"wave"]) * wave_scale
		(
			layout
			. append(
				{
					&"kind": spec[&"kind"],
					&"offset": HEAD_RISE - direction * float(spec[&"distance"]) + side * offset,
					&"rotation": direction.angle() + sin(phase + 0.55) * 0.11 * wave_scale,
					&"scale": float(spec[&"scale"]),
				}
			)
		)
	return layout


static func texture_paths() -> PackedStringArray:
	return PackedStringArray(
		[HEAD_TEXTURE.resource_path, BODY_TEXTURE.resource_path, TAIL_TEXTURE.resource_path]
	)


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
