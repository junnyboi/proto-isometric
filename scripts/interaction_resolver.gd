extends RefCounted

const IsometricControlsScript: GDScript = preload("res://scripts/isometric_controls.gd")
const FriendlyFireScript: GDScript = preload("res://scripts/tool_friendly_fire_policy.gd")

const KIND_TERRAIN: StringName = &"terrain"
const KIND_PLOT: StringName = &"plot"
const KIND_CROP: StringName = &"crop"
const KIND_TREE: StringName = &"tree"
const KIND_STRUCTURE: StringName = &"structure"
const KIND_RESIDENT: StringName = &"resident"
const KIND_FRIENDLY_FAUNA: StringName = &"friendly_fauna"
const KIND_HOSTILE: StringName = &"hostile"
const KIND_PICKUP: StringName = &"pickup"

const ACTION_PREVIEW: StringName = &"preview"
const ACTION_CONTEXT: StringName = &"context"
const ACTION_TOOL: StringName = &"tool"
const ACTION_ATTACK: StringName = &"attack"
const ACTION_COLLECT: StringName = &"collect"
const ACTION_NONE: StringName = &"none"

const REJECT_NONE: StringName = &""
const REJECT_INVALID_FACING: StringName = &"invalid_facing"
const REJECT_OUT_OF_BOUNDS: StringName = &"out_of_bounds"
const REJECT_NO_MATCH: StringName = &"no_matching_target"
const REJECT_BLOCKED: StringName = &"blocked"
const REJECT_FRIENDLY_FIRE: StringName = &"friendly_fire_denied"

const PRIORITY: Array[StringName] = [
	KIND_PICKUP,
	KIND_RESIDENT,
	KIND_FRIENDLY_FAUNA,
	KIND_HOSTILE,
	KIND_STRUCTURE,
	KIND_CROP,
	KIND_TREE,
	KIND_PLOT,
	KIND_TERRAIN,
]
const MASK_TERRAIN: int = 1 << 0
const MASK_PLOT: int = 1 << 1
const MASK_CROP: int = 1 << 2
const MASK_TREE: int = 1 << 3
const MASK_STRUCTURE: int = 1 << 4
const MASK_RESIDENT: int = 1 << 5
const MASK_FRIENDLY_FAUNA: int = 1 << 6
const MASK_HOSTILE: int = 1 << 7
const MASK_PICKUP: int = 1 << 8
const MASK_ALL: int = (1 << 9) - 1
const BITS: Dictionary = {
	KIND_TERRAIN: MASK_TERRAIN,
	KIND_PLOT: MASK_PLOT,
	KIND_CROP: MASK_CROP,
	KIND_TREE: MASK_TREE,
	KIND_STRUCTURE: MASK_STRUCTURE,
	KIND_RESIDENT: MASK_RESIDENT,
	KIND_FRIENDLY_FAUNA: MASK_FRIENDLY_FAUNA,
	KIND_HOSTILE: MASK_HOSTILE,
	KIND_PICKUP: MASK_PICKUP,
}


static func adjacent_cell(origin: Vector2i, facing: StringName) -> Vector2i:
	var screen: Vector2i = IsometricControlsScript.facing_to_screen_direction(facing)
	return origin + IsometricControlsScript.screen_to_grid_delta(screen)


static func mask_for(kinds: Array[StringName]) -> int:
	var mask: int = 0
	for kind: StringName in kinds:
		mask |= int(BITS.get(kind, 0))
	return mask


static func resolve(
	origin: Vector2i,
	facing: StringName,
	mask: int,
	targets: Dictionary,
	intent: StringName = ACTION_CONTEXT,
) -> Dictionary:
	var cell: Vector2i = adjacent_cell(origin, facing)
	if facing not in IsometricControlsScript.facing_names():
		return _result(false, cell, &"", ACTION_NONE, REJECT_INVALID_FACING)
	if bool(targets.get(&"out_of_bounds", false)):
		return _result(false, cell, &"", ACTION_NONE, REJECT_OUT_OF_BOUNDS)
	for kind: StringName in PRIORITY:
		if kind not in _kinds_at(targets) or (mask & int(BITS[kind])) == 0:
			continue
		if intent == ACTION_ATTACK and kind != KIND_HOSTILE:
			var reason: StringName = (
				REJECT_FRIENDLY_FIRE
				if FriendlyFireScript.denies_damage(kind, targets)
				else REJECT_NO_MATCH
			)
			return _result(false, cell, kind, ACTION_NONE, reason)
		if intent == ACTION_TOOL and bool(targets.get(&"tool_damage", false)):
			if FriendlyFireScript.denies_damage(kind, targets):
				return _result(false, cell, kind, ACTION_NONE, REJECT_FRIENDLY_FIRE)
		return _result(true, cell, kind, _action_for(kind, intent), REJECT_NONE)
	var reason: StringName = (
		REJECT_BLOCKED if bool(targets.get(&"blocked", false)) else REJECT_NO_MATCH
	)
	return _result(false, cell, &"", ACTION_NONE, reason)


static func priority_order() -> Array[StringName]:
	return PRIORITY.duplicate()


static func validate_result(result: Dictionary) -> bool:
	var required: Array[StringName] = [
		&"valid", &"target_cell", &"target_kind", &"action", &"rejection_reason"
	]
	if result.keys() != required or not result[&"target_cell"] is Vector2i:
		return false
	if bool(result[&"valid"]):
		return (
			result[&"target_kind"] in PRIORITY
			and result[&"action"] != ACTION_NONE
			and result[&"rejection_reason"] == REJECT_NONE
		)
	return result[&"action"] == ACTION_NONE and result[&"rejection_reason"] != REJECT_NONE


static func _kinds_at(targets: Dictionary) -> Array[StringName]:
	var kinds: Array[StringName] = []
	var supplied: Variant = targets.get(&"kinds", [])
	if supplied is Array:
		for value: Variant in supplied as Array:
			var kind: StringName = StringName(value)
			if kind in PRIORITY and kind not in kinds:
				kinds.append(kind)
	return kinds


static func _action_for(kind: StringName, intent: StringName) -> StringName:
	if intent == ACTION_TOOL:
		return ACTION_PREVIEW
	if intent == ACTION_ATTACK:
		return ACTION_ATTACK
	if kind == KIND_PICKUP:
		return ACTION_COLLECT
	return ACTION_CONTEXT


static func _result(
	valid: bool,
	cell: Vector2i,
	kind: StringName,
	action: StringName,
	reason: StringName,
) -> Dictionary:
	return {
		&"valid": valid,
		&"target_cell": cell,
		&"target_kind": kind,
		&"action": action,
		&"rejection_reason": reason,
	}
