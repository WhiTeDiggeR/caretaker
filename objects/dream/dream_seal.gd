class_name DreamSeal
extends StaticBody3D

## Seal holding the prisoner asleep. Restoring it (hold) calms the dream.

const CRACKED := Color(0.9, 0.35, 0.1)
const RESTORED := Color(0.55, 0.85, 1.0)

@onready var _interactable: Interactable = $Interactable
@onready var _glow: MeshInstance3D = $Glow

var _material: StandardMaterial3D


func _ready() -> void:
	_material = (_glow.get_surface_override_material(0) as StandardMaterial3D).duplicate()
	_glow.set_surface_override_material(0, _material)
	_interactable.interacted.connect(_on_restored)
	_show(Dreams.in_dream and Dreams.seal_restored)


func _on_restored() -> void:
	Dreams.restore_seal()
	_show(true)


func _show(restored: bool) -> void:
	_interactable.available = not restored
	_interactable.unavailable_prompt = "ПЕЧАТЬ ВОССТАНОВЛЕНА" if restored else ""
	var color := RESTORED if restored else CRACKED
	_material.albedo_color = color
	_material.emission = color
