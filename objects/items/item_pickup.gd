@tool
class_name ItemPickup
extends StaticBody3D

## A carried item lying in the world (#231), like the crowbar (`CrowbarPickup`): taking it sets
## the item flag of data/items. Hidden once the flag is set, also after loading a save. The
## placeholder model is a box or an upright cylinder of `size`. `reagent_charges` adds charges
## to the reagent stock of the containment modules when taken (the storage cylinder).

enum Shape { BOX, CYLINDER }

@export var flag: StringName = &""
@export var prompt := "ВЗЯТЬ"
@export var shape: Shape = Shape.BOX
@export var size := Vector3(0.3, 0.1, 0.12)
@export var color := Color(0.5, 0.5, 0.5)
@export var reagent_charges := 0

var _interactable: Interactable


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	_interactable = PropKit.interactable(self, Interactable.Mode.PRESS, prompt)
	_interactable.one_shot = true
	_interactable.interacted.connect(take)
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_loaded.connect(_refresh)
	_refresh()


func is_taken() -> bool:
	return GameState.has_flag(flag)


## Takes the item: the reagent goes into the stock before the flag shows «Взято».
func take() -> void:
	if is_taken():
		return
	if reagent_charges > 0:
		Containment.add_reagent_stock(reagent_charges)
	GameState.set_flag(flag)


func _build() -> void:
	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()
	if shape == Shape.CYLINDER:
		var mesh := CylinderMesh.new()
		mesh.top_radius = size.x * 0.5
		mesh.bottom_radius = size.x * 0.5
		mesh.height = size.y
		mesh_instance.mesh = mesh
		var cylinder := CylinderShape3D.new()
		cylinder.radius = size.x * 0.5
		cylinder.height = size.y
		collision.shape = cylinder
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh_instance.mesh = box
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision.shape = box_shape
	(mesh_instance.mesh as PrimitiveMesh).material = PropKit.material(color)
	mesh_instance.position.y = size.y * 0.5
	collision.position.y = size.y * 0.5
	add_child(mesh_instance)
	add_child(collision)


func _on_flag_changed(changed: StringName, _value: Variant) -> void:
	if changed == flag:
		_refresh()


func _refresh() -> void:
	# A state without the flag (reset, an earlier save) lets the item be taken again.
	_interactable.used = is_taken()
	visible = not is_taken()
	process_mode = Node.PROCESS_MODE_DISABLED if is_taken() else Node.PROCESS_MODE_INHERIT
	collision_layer = 0 if is_taken() else 1
