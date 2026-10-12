@tool
extends Node3D

## Personal items on the senior officer's console: a cold mug and a photo lying face down.


func _ready() -> void:
	var mug := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.045
	cylinder.bottom_radius = 0.04
	cylinder.height = 0.1
	cylinder.material = PropKit.material(Color(0.75, 0.73, 0.68))
	mug.mesh = cylinder
	mug.position = Vector3(-0.15, 0.05, 0)
	add_child(mug)
	PropKit.box(self, Vector3(0.12, 0.004, 0.02), Vector3(0.15, 0.008, 0.1), PropKit.material(Color(0.88, 0.86, 0.8)), false, Vector3(0, 0.4, 0))
