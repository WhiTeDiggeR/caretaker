class_name Checkpoint
extends Area3D

## Autosave point: the first time the hero walks in, the game is saved to the autosave slot.

const FLAG_PREFIX := "checkpoint/"

@export var checkpoint_id: StringName = &"checkpoint"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func is_reached() -> bool:
	return GameState.has_flag(StringName(FLAG_PREFIX + String(checkpoint_id)))


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player") or is_reached():
		return
	GameState.set_flag(StringName(FLAG_PREFIX + String(checkpoint_id)))
	if Saves.write(Saves.AUTO, get_tree()) == OK:
		get_tree().call_group(&"message_display", "show_message", "КОНТРОЛЬНАЯ ТОЧКА", "Игра сохранена.")
