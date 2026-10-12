class_name HintTrigger
extends Area3D

## Requests a one-time hint (Hints) when the hero walks in.

@export var hint_id: StringName = &""


func _ready() -> void:
	body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group(&"player"):
			Hints.request(hint_id))
