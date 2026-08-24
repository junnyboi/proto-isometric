extends RefCounted

const MUD_SKIMMER_TEXTURE: Texture2D = preload("res://assets/enemies/mud_skimmer.png")
const RIME_STALKER_TEXTURE: Texture2D = preload("res://assets/enemies/rime_stalker.png")
const CINDER_CRAWLER_TEXTURE: Texture2D = preload("res://assets/enemies/cinder_crawler.png")
const SKIMMER_KIND: StringName = &"mud_skimmer"
const RIME_KIND: StringName = &"rime_stalker"
const CINDER_KIND: StringName = &"cinder_crawler"
const MUD: Color = Color("2d281f")
const WETLAND: Color = Color("75a06c")
const HEALTH: Color = Color("e75d46")
const HEALTH_BACK: Color = Color("1a1110")


static func draw_enemy(
	canvas: Node2D,
	center: Vector2,
	worm: Dictionary,
	state: StringName,
	progress: float,
	alpha: float,
	time: float,
	hovered_id: int,
	max_health: int,
) -> bool:
	var kind: StringName = worm.get(&"kind", &"sandworm") as StringName
	if kind == SKIMMER_KIND:
		_draw_skimmer(canvas, center, worm, state, progress, alpha, time, hovered_id, max_health)
		return true
	if kind == RIME_KIND:
		_draw_native(
			canvas,
			center,
			worm,
			state,
			progress,
			alpha,
			time,
			hovered_id,
			max_health,
			RIME_STALKER_TEXTURE,
			Color("aeeeff"),
			Color("27688f"),
		)
		return true
	if kind == CINDER_KIND:
		_draw_native(
			canvas,
			center,
			worm,
			state,
			progress,
			alpha,
			time,
			hovered_id,
			max_health,
			CINDER_CRAWLER_TEXTURE,
			Color("ff9b2f"),
			Color("8f2414"),
		)
		return true
	return false


static func _draw_skimmer(
	canvas: Node2D,
	center: Vector2,
	worm: Dictionary,
	state: StringName,
	progress: float,
	alpha: float,
	time: float,
	hovered_id: int,
	max_health: int,
) -> void:
	_draw_mud_wake(canvas, center, progress, alpha, time)
	if state == &"wake_sweep":
		alpha *= 0.78
	var size: Vector2 = MUD_SKIMMER_TEXTURE.get_size() * 0.23
	var tint: Color = Color("ffd27a") if int(worm[&"id"]) == hovered_id else Color.WHITE
	tint.a = alpha
	canvas.draw_texture_rect(
		MUD_SKIMMER_TEXTURE, Rect2(center - size * Vector2(0.5, 0.66), size), false, tint
	)
	if state in [&"recover", &"staggered"]:
		_draw_health_bar(
			canvas, center + Vector2(0.0, -69.0), int(worm[&"health"]), max_health, alpha
		)


static func _draw_native(
	canvas: Node2D,
	center: Vector2,
	worm: Dictionary,
	state: StringName,
	progress: float,
	alpha: float,
	time: float,
	hovered_id: int,
	max_health: int,
	texture: Texture2D,
	wake_light: Color,
	wake_dark: Color,
) -> void:
	canvas.draw_arc(
		center, 18.0 + progress * 14.0, 0.0, TAU, 28, Color(wake_light, 0.7 * alpha), 3.0
	)
	for mote: int in range(10):
		var phase: float = float(mote) * 2.399 + time * 3.2
		var point: Vector2 = center + Vector2(cos(phase) * 24.0, sin(phase) * 9.0)
		canvas.draw_circle(
			point, 2.0 + float(mote % 2), Color(wake_dark, (0.25 + mote % 3 * 0.08) * alpha)
		)
	if state in [&"pounce", &"ember_salvo"]:
		alpha *= 0.78
	var size: Vector2 = texture.get_size() * 0.23
	var tint: Color = Color("ffd27a") if int(worm[&"id"]) == hovered_id else Color.WHITE
	tint.a = alpha
	canvas.draw_texture_rect(texture, Rect2(center - size * Vector2(0.5, 0.66), size), false, tint)
	if state in [&"recover", &"staggered"]:
		_draw_health_bar(
			canvas, center + Vector2(0.0, -69.0), int(worm[&"health"]), max_health, alpha
		)


static func _draw_mud_wake(
	canvas: Node2D, center: Vector2, progress: float, alpha: float, time: float
) -> void:
	canvas.draw_arc(center, 18.0 + progress * 14.0, 0.0, TAU, 28, Color(WETLAND, 0.7 * alpha), 3.0)
	for mote: int in range(10):
		var phase: float = float(mote) * 2.399 + time * 3.2
		var point: Vector2 = center + Vector2(cos(phase) * 24.0, sin(phase) * 9.0)
		canvas.draw_circle(
			point, 2.0 + float(mote % 2), Color(MUD, (0.25 + mote % 3 * 0.08) * alpha)
		)


static func _draw_health_bar(
	canvas: Node2D, position: Vector2, health: int, max_health: int, alpha: float
) -> void:
	var width: float = 58.0
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
