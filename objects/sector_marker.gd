extends Node3D

@export var marker_color := Color(0.12, 0.55, 0.9, 1)

func _ready() -> void:
	var mesh_instance := $Strip as MeshInstance3D
	var material := mesh_instance.get_active_material(0).duplicate() as StandardMaterial3D
	material.albedo_color = marker_color.darkened(0.35)
	material.emission = marker_color
	mesh_instance.material_override = material

