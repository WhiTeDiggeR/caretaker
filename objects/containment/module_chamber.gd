class_name ModuleChamber
extends Area3D

## Volume of a containment module's chamber: tells Containment whether the hero is inside
## when the chemical protocol fills it with sleeping gas.

@export var module_id: StringName = &"module_4"


func _ready() -> void:
	body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group(&"player"):
			Containment.set_hero_inside(module_id, true))
	body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group(&"player"):
			Containment.set_hero_inside(module_id, false))
