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
	# The save indicator of the HUD shows the record (issue #152); the frame for the thumbnail
	# follows a couple of frames later, without the HUD.
	if Saves.write(Saves.AUTO, get_tree()) == OK:
		Sfx.play(&"checkpoint")
		var frame: Image = await Saves.grab_frame(get_tree())
		Saves.store_thumbnail(Saves.AUTO, frame)
