class_name DreamHazard
extends Area3D

## Deadly area of a dream (lava, abyss, a guard's grip): death throws the hero back into
## the chair and raises the instability.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		Dreams.die()
