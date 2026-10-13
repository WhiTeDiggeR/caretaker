@tool
class_name JammedDoor
extends FacilityDoor

## A door jammed by something fallen against it (#178: the pipe in the senior officer's room
## presses on the door to the old control point). It is an ordinary `FacilityDoor` whose lock
## reason is «ЗАКЛИНИЛО» until `unjam_flag` is set; an empty flag keeps it jammed for good.
## The door logic itself stays in FacilityDoor (#174); only the lock reason is added.

const REASON_JAMMED := "ЗАКЛИНИЛО"

@export var unjam_flag: StringName = &""


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	GameState.flag_changed.connect(_on_flag_changed)


func is_jammed() -> bool:
	return unjam_flag.is_empty() or not GameState.has_flag(unjam_flag)


func lock_reason() -> String:
	if is_jammed():
		return REASON_JAMMED
	return super()


func _on_flag_changed(changed: StringName, _value: Variant) -> void:
	if changed == unjam_flag:
		refresh()
