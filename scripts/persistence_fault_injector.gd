extends RefCounted

const PHASE_OPEN: StringName = &"open"
const PHASE_WRITE: StringName = &"write"
const PHASE_FLUSH: StringName = &"flush"
const PHASE_RENAME: StringName = &"rename"
const PHASE_BACKUP: StringName = &"backup"
const PHASE_PUBLISH: StringName = &"publish"
const PHASES: Array[StringName] = [
	PHASE_OPEN,
	PHASE_WRITE,
	PHASE_FLUSH,
	PHASE_RENAME,
	PHASE_BACKUP,
	PHASE_PUBLISH,
]

var _armed_phase: StringName = &""
var _triggered: bool = false


func arm(phase: StringName) -> bool:
	if phase not in PHASES:
		return false
	_armed_phase = phase
	_triggered = false
	return true


func should_fail(phase: StringName) -> bool:
	if _triggered or phase != _armed_phase:
		return false
	_triggered = true
	return true


func was_triggered() -> bool:
	return _triggered
