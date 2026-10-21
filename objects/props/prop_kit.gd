class_name PropKit
extends RefCounted

## Small builders for props: art models from loads/props, invisible box collision, and boxes
## with plain materials for parts that have no model yet.
## Generated nodes are not owned by the scene, so they are never saved into .tscn files.


static func material(color: Color, emissive: bool = false, alpha: float = 1.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color, alpha)
	result.roughness = 0.65
	if alpha < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 2.0
	return result


## Adds a box mesh to `parent`; with `collide` (parent must be a CollisionObject3D) also a
## matching collision shape in the same local frame.
static func box(parent: Node3D, position: Vector3, size: Vector3, mat: Material, collide: bool = false, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation = rotation
	parent.add_child(mesh_instance)
	if collide:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		shape.position = position
		shape.rotation = rotation
		parent.add_child(shape)
	return mesh_instance


## Instances an art model (a glTF scene from loads/props) under `parent` (#241).
static func art(parent: Node3D, model: PackedScene, position: Vector3 = Vector3.ZERO, rotation: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> Node3D:
	var result := model.instantiate() as Node3D
	result.name = "Model"
	result.position = position
	result.rotation = rotation
	result.scale = scale
	parent.add_child(result)
	return result


## Invisible box collision of an art model: the shape stays simple, the mesh is the model's.
static func collider(parent: CollisionObject3D, position: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = position
	shape.rotation = rotation
	parent.add_child(shape)
	return shape


static func label(parent: Node3D, position: Vector3, text: String, size: int = 40, color: Color = Color.WHITE) -> Label3D:
	var result := Label3D.new()
	result.text = text
	result.position = position
	result.pixel_size = 0.003
	result.font_size = size
	result.outline_size = 0
	result.modulate = color
	parent.add_child(result)
	return result


static func interactable(parent: Node, mode: Interactable.Mode, prompt: String, inspect_text_id: String = "") -> Interactable:
	var result := Interactable.new()
	result.mode = mode
	result.prompt = prompt
	result.inspect_text_id = inspect_text_id
	parent.add_child(result)
	return result
