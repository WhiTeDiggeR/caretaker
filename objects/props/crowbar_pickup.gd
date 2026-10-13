@tool
class_name CrowbarPickup
extends StaticBody3D

## The fire crowbar from the fire shield (#178): taken into the inventory as an item flag, like
## the senior officer's key (`KeyPickup`). Hidden once the flag is set, also after loading a save.
## The model is the placeholder `ph_crowbar`, standing upright as it hangs on the shield.

const MODEL := preload("res://loads/props/ph_crowbar/ph_crowbar.gltf")
const REACH := Vector3(0.2, 0.7, 0.25)

@export var flag: StringName = &"item_crowbar"
@export var prompt := "ВЗЯТЬ ЛОМ"

var _interactable: Interactable


func _ready() -> void:
	add_child(MODEL.instantiate())
	var shape := CollisionShape3D.new()
	var reach := BoxShape3D.new()
	reach.size = REACH
	shape.shape = reach
	add_child(shape)
	if Engine.is_editor_hint():
		return
	_interactable = PropKit.interactable(self, Interactable.Mode.PRESS, prompt)
	_interactable.sets_flag = flag
	_interactable.one_shot = true
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_loaded.connect(_refresh)
	_refresh()


func is_taken() -> bool:
	return GameState.has_flag(flag)


func _on_flag_changed(changed: StringName, _value: Variant) -> void:
	if changed == flag:
		_refresh()


func _refresh() -> void:
	# A state without the flag (reset, an earlier save) lets the crowbar be taken again.
	_interactable.used = is_taken()
	visible = not is_taken()
	process_mode = Node.PROCESS_MODE_DISABLED if is_taken() else Node.PROCESS_MODE_INHERIT
	collision_layer = 0 if is_taken() else 1
