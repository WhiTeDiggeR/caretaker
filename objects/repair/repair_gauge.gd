@tool
class_name RepairGauge
extends Node3D

## Dial gauge with a needle and a green zone. `value` is 0..1 over the dial.

const SWEEP := deg_to_rad(240.0)
const RADIUS := 0.16

@export_range(0.0, 1.0) var value := 0.0:
	set(new_value):
		value = clampf(new_value, 0.0, 1.0)
		_update_needle()
@export var green_from := 0.7
@export var green_to := 0.9
@export var caption := ""

var _needle: Node3D


func _ready() -> void:
	_build()
	_update_needle()


func in_green_zone() -> bool:
	return value >= green_from and value <= green_to


func _update_needle() -> void:
	if _needle:
		_needle.rotation.z = SWEEP * 0.5 - value * SWEEP


func _build() -> void:
	for child in get_children():
		if child.has_meta(&"gauge_generated"):
			child.free()
	var face := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.04
	disc.material = _material(Color(0.85, 0.84, 0.78))
	face.mesh = disc
	face.rotation = Vector3(PI * 0.5, 0, 0)
	_generated(face)
	var zone := MeshInstance3D.new()
	var zone_mesh := BoxMesh.new()
	zone_mesh.size = Vector3(0.05, 0.02, 0.01)
	zone_mesh.material = _material(Color(0.2, 0.7, 0.3))
	zone.mesh = zone_mesh
	var middle := (green_from + green_to) * 0.5
	var angle := SWEEP * 0.5 - middle * SWEEP
	zone.position = Vector3(-sin(angle), cos(angle), 0) * RADIUS * 0.8 + Vector3(0, 0, 0.025)
	zone.rotation.z = angle
	_generated(zone)
	_needle = Node3D.new()
	_needle.position = Vector3(0, 0, 0.03)
	_generated(_needle)
	var needle_mesh := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.012, RADIUS * 0.9, 0.006)
	bar.material = _material(Color(0.7, 0.1, 0.08))
	needle_mesh.mesh = bar
	needle_mesh.position = Vector3(0, RADIUS * 0.45, 0)
	_needle.add_child(needle_mesh)
	if not caption.is_empty():
		var label := Label3D.new()
		label.text = caption
		label.pixel_size = 0.003
		label.font_size = 40
		label.outline_size = 8
		label.position = Vector3(0, -RADIUS - 0.06, 0)
		_generated(label)


func _generated(node: Node) -> void:
	node.set_meta(&"gauge_generated", true)
	add_child(node)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
