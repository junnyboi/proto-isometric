extends Node2D

signal tool_contact_frame(result: Dictionary)
signal tool_action_finished

const HOE_TEXTURE: Texture2D = preload("res://assets/tools/protos_hoe_spritesheet.png")
const WATER_TEXTURE: Texture2D = preload("res://assets/tools/protos_water_spritesheet.png")
const FRAME_SIZE: Vector2i = Vector2i(256, 256)
const FRAME_COUNT: int = 8
const CONTACT_FRAME: int = 3
const FRAME_RATE: float = 12.0
const DURATION: float = float(FRAME_COUNT) / FRAME_RATE

var _sprite: Sprite2D
var _remaining: float = 0.0
var _contact_emitted: bool = false
var _pending_result: Dictionary = {}


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "ToolActionSprite"
	_sprite.centered = true
	_sprite.position = Vector2(0.0, -76.0)
	_sprite.scale = Vector2.ONE * 0.58
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(Vector2.ZERO, FRAME_SIZE)
	_sprite.visible = false
	add_child(_sprite)


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining = maxf(_remaining - maxf(delta, 0.0), 0.0)
	var frame: int = mini(floori((DURATION - _remaining) * FRAME_RATE), FRAME_COUNT - 1)
	_sprite.region_rect = _frame_rect(frame)
	if not _contact_emitted and frame >= CONTACT_FRAME:
		_contact_emitted = true
		tool_contact_frame.emit(_pending_result.duplicate(true))
	if _remaining <= 0.0:
		_sprite.visible = false
		_pending_result.clear()
		tool_action_finished.emit()


func play_tool(tool_id: StringName, result: Dictionary) -> bool:
	if _remaining > 0.0 or not bool(result.get(&"valid", false)):
		return false
	_sprite.texture = WATER_TEXTURE if tool_id == &"tool.watering" else HOE_TEXTURE
	_sprite.region_rect = _frame_rect(0)
	_sprite.visible = true
	_remaining = DURATION
	_contact_emitted = false
	_pending_result = result.duplicate(true)
	return true


func is_playing() -> bool:
	return _remaining > 0.0


func get_contact_frame() -> int:
	return CONTACT_FRAME


func get_contact_time() -> float:
	return float(CONTACT_FRAME) / FRAME_RATE


func get_duration() -> float:
	return DURATION


func _frame_rect(frame: int) -> Rect2:
	var column: int = frame % 4
	var row: int = frame / 4
	return Rect2(Vector2(column, row) * Vector2(FRAME_SIZE), Vector2(FRAME_SIZE))
