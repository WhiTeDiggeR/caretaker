class_name Interactor
extends Node

## Finds what the player looks at and drives press, hold and inspect interactions.
## Objects take part through an `Interactable` child or, for older props, an `interact()`
## method with an optional `get_interaction_text()`.

signal target_changed(target: Object)
signal message_requested(title: String, text: String)

const LEGACY_PROMPT := "ВЗАИМОДЕЙСТВОВАТЬ"
const MESSAGE_GROUP := &"message_display"

@export var ray: RayCast3D
@export var prompt_label: Label
@export var hold_bar: Range

var target: Object
var hold_progress := 0.0


func _physics_process(delta: float) -> void:
	var collider: Object = ray.get_collider() if ray and ray.is_colliding() else null
	step(find_target(collider), Input.is_action_pressed(&"interact"), Input.is_action_just_pressed(&"interact"), delta)


## The interactable behind a collider: its `Interactable` component or a legacy node.
static func find_target(collider: Object) -> Object:
	var node := collider as Node
	while node:
		if node.has_meta(Interactable.META):
			return node.get_meta(Interactable.META)
		if node.has_method("interact"):
			return node
		node = node.get_parent()
	return null


func step(new_target: Object, pressed: bool, just_pressed: bool, delta: float) -> void:
	if new_target != target:
		_cancel_hold()
		target = new_target
		target_changed.emit(target)
	_update_prompt()
	if target == null:
		return

	var interactable := target as Interactable
	if interactable == null:
		if just_pressed:
			target.call("interact")
		return
	if not interactable.is_available():
		_cancel_hold()
		return

	match interactable.mode:
		Interactable.Mode.PRESS:
			if just_pressed:
				interactable.trigger()
		Interactable.Mode.INSPECT:
			if just_pressed:
				interactable.trigger()
				show_message(interactable.get_inspect_title(), interactable.get_inspect_text())
		Interactable.Mode.HOLD:
			if not pressed:
				_cancel_hold()
				return
			hold_progress = minf(hold_progress + delta / maxf(interactable.hold_time, 0.01), 1.0)
			interactable.hold_progress_changed.emit(hold_progress)
			_update_hold_bar()
			if hold_progress >= 1.0:
				hold_progress = 0.0
				_update_hold_bar()
				interactable.trigger()


func show_message(title: String, text: String) -> void:
	message_requested.emit(title, text)
	var tree := get_tree()
	if tree == null:
		return
	if tree.has_group(MESSAGE_GROUP):
		tree.call_group(MESSAGE_GROUP, "show_message", title, text)
	elif tree.current_scene and tree.current_scene.has_method("show_facility_message"):
		tree.current_scene.show_facility_message(title, text)


func _cancel_hold() -> void:
	if hold_progress <= 0.0:
		return
	hold_progress = 0.0
	_update_hold_bar()
	var interactable := target as Interactable
	if interactable:
		interactable.hold_cancelled.emit()


func _update_prompt() -> void:
	if prompt_label == null:
		return
	var text := ""
	if target is Interactable:
		text = (target as Interactable).get_prompt_text()
	elif target != null:
		var legacy := LEGACY_PROMPT
		if target.has_method("get_interaction_text"):
			legacy = str(target.call("get_interaction_text"))
		text = InputPromptFormatter.format_action(&"interact", legacy)
	prompt_label.text = text
	prompt_label.visible = not text.is_empty()


func _update_hold_bar() -> void:
	if hold_bar == null:
		return
	hold_bar.value = hold_progress * hold_bar.max_value
	hold_bar.visible = hold_progress > 0.0
