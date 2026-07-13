extends StaticBody3D

@export var furniture_material: Material = preload("res://materials/furniture_metal.tres")

func _ready() -> void:
	if $Model is MeshInstance3D:
		_prepare_mesh($Model as MeshInstance3D)
	for node in $Model.find_children("*", "MeshInstance3D", true, false):
		_prepare_mesh(node as MeshInstance3D)

func _prepare_mesh(mesh_instance: MeshInstance3D) -> void:
	mesh_instance.material_override = furniture_material
	mesh_instance.visibility_range_end = 42.0
	mesh_instance.visibility_range_end_margin = 6.0
