extends RefCounted

const KIND_CROP: StringName = &"crop"
const KIND_RESIDENT: StringName = &"resident"
const KIND_FRIENDLY_FAUNA: StringName = &"friendly_fauna"
const KIND_STRUCTURE: StringName = &"structure"
const PROTECTED_KINDS: Array[StringName] = [KIND_CROP, KIND_RESIDENT, KIND_FRIENDLY_FAUNA]


static func denies_damage(kind: StringName, target_flags: Dictionary = {}) -> bool:
	if kind in PROTECTED_KINDS:
		return true
	return (
		kind == KIND_STRUCTURE
		and (bool(target_flags.get(&"machine", false)) or bool(target_flags.get(&"home", false)))
	)


static func protected_kinds() -> Array[StringName]:
	return PROTECTED_KINDS.duplicate()
