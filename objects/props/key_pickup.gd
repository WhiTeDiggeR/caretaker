@tool
class_name KeyPickup
extends StaticBody3D

## A small item taken into the inventory as a story flag (the senior officer's personal key).
## Hidden once the flag is set, also after loading a save.

@export var flag: StringName = &"senior_key_taken"
@export var prompt := "ВЗЯТЬ ЛИЧНЫЙ КЛЮЧ"

var _interactable: Interactable


func _ready() -> void:
	PropKit.box(self, Vector3(0, 0.01, 0), Vector3(0.09, 0.02, 0.035), PropKit.material(Color(0.72, 0.62, 0.3)), true)
	PropKit.box(self, Vector3(-0.08, 0.005, 0.0), Vector3(0.1, 0.008, 0.012), PropKit.material(Color(0.15, 0.2, 0.45)))
	var shape := CollisionShape3D.new()
	var reach := BoxShape3D.new()
	reach.size = Vector3(0.3, 0.12, 0.25)
	shape.shape = reach
	add_child(shape)
	if Engine.is_editor_hint():
		return
	_interactable = PropKit.interactable(self, Interactable.Mode.PRESS, prompt)
	_interactable.sets_flag = flag
	_interactable.one_shot = true
	GameState.flag_changed.connect(func(changed: StringName, _value: Variant) -> void:
		if changed == flag:
			_refresh())
	GameState.state_loaded.connect(_refresh)
	_refresh()


func is_taken() -> bool:
	return GameState.has_flag(flag)


func _refresh() -> void:
	visible = not is_taken()
	process_mode = Node.PROCESS_MODE_DISABLED if is_taken() else Node.PROCESS_MODE_INHERIT
	collision_layer = 0 if is_taken() else 1
