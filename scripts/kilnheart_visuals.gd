extends RefCounted

const KilnheartBossScript: GDScript = preload("res://scripts/kilnheart_boss.gd")
const TEXTURES: Dictionary = {
	&"idle": preload("res://assets/enemies/kilnheart/kilnheart_idle.png"),
	&"walk_a": preload("res://assets/enemies/kilnheart/kilnheart_walk_a.png"),
	&"walk_b": preload("res://assets/enemies/kilnheart/kilnheart_walk_b.png"),
	&"windup": preload("res://assets/enemies/kilnheart/kilnheart_windup.png"),
	&"attack": preload("res://assets/enemies/kilnheart/kilnheart_attack.png"),
	&"cracked": preload("res://assets/enemies/kilnheart/kilnheart_cracked.png"),
	&"broken": preload("res://assets/enemies/kilnheart/kilnheart_broken.png"),
	&"defeat": preload("res://assets/enemies/kilnheart/kilnheart_defeat.png"),
}
const DRAW_SCALE: float = 0.36
const CONTACT_RATIO: float = 478.0 / 512.0
const HEALTH: Color = Color("ff7647")
const HEALTH_BACK: Color = Color("1a1110")
const CORE: Color = Color("ff9b2f")
const CORE_HOT: Color = Color("fff0b2")


static func draw_boss(
	canvas: Node2D,
	center: Vector2,
	boss: Dictionary,
	state: StringName,
	progress: float,
	alpha: float,
	time: float,
	hovered_id: int,
) -> void:
	var key: StringName = KilnheartBossScript.animation_key(boss, time)
	var texture: Texture2D = TEXTURES.get(key, TEXTURES[&"idle"]) as Texture2D
	var draw_alpha: float = alpha
	var rise: float = 0.0
	if state == KilnheartBossScript.STATE_EMERGE:
		draw_alpha *= progress
		rise = (1.0 - progress) * 30.0
	var bob: float = 0.0
	if state == KilnheartBossScript.STATE_TRACK:
		bob = absf(sin(time * 4.8 + float(boss[&"id"]) * 0.31)) * 5.0
	elif state == KilnheartBossScript.STATE_WARNING:
		bob = sin(progress * PI) * 4.0
	elif state == KilnheartBossScript.STATE_ATTACK:
		bob = sin(progress * PI) * 7.0
	var position: Vector2 = center + Vector2(0.0, rise - bob)
	_draw_phase_glow(canvas, position, boss, state, progress, draw_alpha, time)
	var size: Vector2 = texture.get_size() * DRAW_SCALE
	var rect: Rect2 = Rect2(
		position - Vector2(size.x * 0.5, size.y * CONTACT_RATIO),
		size,
	)
	var tint: Color = Color("ffd27a") if int(boss[&"id"]) == hovered_id else Color.WHITE
	if float(boss.get(&"hit_flash", 0.0)) > 0.0:
		tint = Color("fff1cf")
	tint.a = draw_alpha
	canvas.draw_texture_rect(texture, rect, false, tint)
	if state not in [KilnheartBossScript.STATE_EMERGE, KilnheartBossScript.STATE_DEFEATED]:
		_draw_health_bar(canvas, position + Vector2(0.0, -142.0), boss, draw_alpha)


static func texture_paths() -> PackedStringArray:
	return KilnheartBossScript.texture_paths()


static func _draw_phase_glow(
	canvas: Node2D,
	position: Vector2,
	boss: Dictionary,
	state: StringName,
	progress: float,
	alpha: float,
	time: float,
) -> void:
	var stage: int = int(boss.get(&"armor_stage", 0))
	var pulse: float = 0.5 + 0.5 * sin(time * (4.2 + stage))
	var radius: float = 48.0 + stage * 8.0 + pulse * 5.0
	var glow_alpha: float = (0.12 + stage * 0.05 + pulse * 0.05) * alpha
	if state == KilnheartBossScript.STATE_WARNING:
		glow_alpha += progress * 0.12 * alpha
	canvas.draw_circle(position + Vector2(0.0, 4.0), radius, Color(CORE, glow_alpha))
	canvas.draw_arc(
		position + Vector2(0.0, 4.0),
		radius + 5.0,
		0.0,
		TAU,
		42,
		Color(CORE_HOT, glow_alpha * 1.4),
		2.0,
	)


static func _draw_health_bar(
	canvas: Node2D, position: Vector2, boss: Dictionary, alpha: float
) -> void:
	var width: float = 112.0
	canvas.draw_rect(
		Rect2(position - Vector2(width * 0.5, 5.0), Vector2(width, 10.0)),
		Color(HEALTH_BACK, 0.9 * alpha),
	)
	var maximum: int = maxi(int(boss.get(&"max_health", KilnheartBossScript.MAX_HEALTH)), 1)
	var ratio: float = clampf(float(boss[&"health"]) / float(maximum), 0.0, 1.0)
	canvas.draw_rect(
		Rect2(position - Vector2(width * 0.5 - 2.0, 3.0), Vector2((width - 4.0) * ratio, 6.0)),
		Color(HEALTH, alpha),
	)
	for stage: int in range(1, 3):
		var marker_x: float = position.x - width * 0.5 + width * float(stage) / 3.0
		canvas.draw_line(
			Vector2(marker_x, position.y - 5.0),
			Vector2(marker_x, position.y + 5.0),
			Color(CORE_HOT, alpha),
			2.0,
		)
