extends StaticBody3D

@export var furniture_material: Material = preload("res://materials/furniture_metal.tres")

func _ready() -> void:
	if $Model is MeshInstance3D:
		($Model as MeshInstance3D).material_override = furniture_material
	for node in $Model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = furniture_material
