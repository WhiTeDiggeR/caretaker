class_name ShellConfirm
extends CanvasLayer

## Confirmation dialog of the shell (issue #144): the question, what happens, the action and
## «Отмена». Esc cancels. Built by ShellUI.confirm.

signal answered(yes: bool)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		answer(false)
		get_viewport().set_input_as_handled()


func answer(yes: bool) -> void:
	answered.emit(yes)
	queue_free()
