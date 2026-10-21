@tool
class_name KeyPickup
extends StaticBody3D

## A small item taken into the inventory as a story flag (the senior officer's personal key).
## Hidden once the flag is set, also after loading a save. The key's number is printed large on
## its tag and named in the prompt (#238): the player meets it again in Bowser's dream.

const TAG_SIZE := Vector3(0.075, 0.003, 0.04)
const TAG_OFFSET := Vector3(-0.1, 0.0015, 0.0)
const TAG_FONT_SIZE := 64
const TAG_PIXEL := 0.00022

@export var flag: StringName = &"senior_key_taken"
@export var tag_text := "SE 067"
@export var prompt := "ВЗЯТЬ ЛИЧНЫЙ КЛЮЧ SE 067"

var _interactable: Interactable


func _ready() -> void:
	PropKit.box(self, Vector3(0, 0.01, 0), Vector3(0.09, 0.02, 0.035), PropKit.material(Color(0.72, 0.62, 0.3)), true)
	PropKit.box(self, Vector3(-0.05, 0.004, 0.0), Vector3(0.03, 0.006, 0.008), PropKit.material(Color(0.15, 0.2, 0.45)))
	PropKit.box(self, TAG_OFFSET, TAG_SIZE, PropKit.material(Color(0.86, 0.83, 0.74)))
	_add_tag_text()
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


func _add_tag_text() -> void:
	var text := Label3D.new()
	text.name = "TagText"
	text.text = tag_text
	text.font = UiStyle.FONT_SCREEN_OLD
	text.font_size = TAG_FONT_SIZE
	text.pixel_size = TAG_PIXEL
	text.modulate = Color(0.08, 0.08, 0.1)
	text.outline_size = 0
	text.double_sided = false
	text.rotation_degrees.x = -90.0
	text.position = TAG_OFFSET + Vector3(0, TAG_SIZE.y * 0.5 + 0.0005, 0)
	add_child(text)


func is_taken() -> bool:
	return GameState.has_flag(flag)


func _refresh() -> void:
	visible = not is_taken()
	process_mode = Node.PROCESS_MODE_DISABLED if is_taken() else Node.PROCESS_MODE_INHERIT
	collision_layer = 0 if is_taken() else 1
