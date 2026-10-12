class_name DreamGate
extends Area3D

## Arch gate out of the dream (canon: the silhouette stays recognisable in every dream).
## Walking through it returns the hero to the chair.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		Dreams.exit_through_gate()
