@tool
class_name DreamKitFill
extends Node3D

## Dresses a blockout box of Bowser's dream with a module of the fortress kit (#195,
## docs/art/dream-bowser-s.md §4.1). The box is the BoxMesh of the sibling `Mesh` node, so the
## blockout keeps its collision and node paths; the art only replaces the look. The module is
## tiled over the box (rounded counts, the last bit of length taken up by scaling) and drawn
## with one MultiMesh per mesh, so a whole wall costs a draw call per material.
## The module's own axes: length along X, height along Y, depth along Z, origin at the bottom
## centre. A box that is longer in Z than in X gets the module turned by 90°.
## Tiled plates (floors, ceilings) get a backing slab of the blockout material just inside the
## box, so the seams between the plates never show the lava or the sky through (#208).

@export var module: PackedScene
## Size of one module (the tiling step), metres.
@export var module_size := Vector3(4.0, 4.0, 1.0)
## Optional crown laid along the top of the box (crenellations of open-air walls).
@export var cap: PackedScene
## Tile in depth as well (floor plates); otherwise one module is stretched over the depth.
@export var tile_depth := false
## Metres the wall goes on below the box, down into the lava: a footing, so a wall standing
## past the edge of a floor does not hang in the air (#208). The top stays where it is.
@export var foundation := 0.0

const BLOCKOUT := ^"../Mesh"
## The backing slab stays this far inside the top and bottom faces of the plates.
const BACKING_INSET := 0.02


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var blockout := get_node_or_null(BLOCKOUT) as MeshInstance3D
	if module == null or blockout == null or not blockout.mesh is BoxMesh:
		return
	var box_size := (blockout.mesh as BoxMesh).size
	var size := box_size + Vector3.UP * foundation
	var bottom := -box_size.y * 0.5 - foundation
	var turned := size.z > size.x and not tile_depth
	var length := size.z if turned else size.x
	var depth := size.x if turned else size.z
	var count := Vector3i(_count(length, module_size.x), _count(size.y, module_size.y),
			_count(depth, module_size.z) if tile_depth else 1)
	var step := Vector3(length / count.x, size.y / count.y, depth / count.z)
	var scale_xyz := Vector3(step.x / module_size.x, step.y / module_size.y, step.z / module_size.z)
	var basis := Basis(Vector3.UP, PI * 0.5) if turned else Basis.IDENTITY
	var cells: Array[Transform3D] = []
	for i in count.x:
		for j in count.y:
			for k in count.z:
				var local := Vector3(-length * 0.5 + step.x * (i + 0.5), bottom + step.y * j,
						-depth * 0.5 + step.z * (k + 0.5))
				cells.append(Transform3D(basis * Basis.from_scale(scale_xyz), basis * local))
	_add_multimeshes(module, cells)
	if cap:
		var crown: Array[Transform3D] = []
		var cap_scale := Vector3(scale_xyz.x, 1.0, depth / module_size.z)
		for i in count.x:
			var local := Vector3(-length * 0.5 + step.x * (i + 0.5), box_size.y * 0.5, 0.0)
			crown.append(Transform3D(basis * Basis.from_scale(cap_scale), basis * local))
		_add_multimeshes(cap, crown)
	if tile_depth:
		_add_backing(blockout.mesh as BoxMesh)


func _add_backing(box: BoxMesh) -> void:
	var slab := BoxMesh.new()
	slab.size = box.size - Vector3.UP * BACKING_INSET * 2.0
	slab.material = box.material
	var backing := MeshInstance3D.new()
	backing.name = "Backing"
	backing.mesh = slab
	add_child(backing)


static func _count(span: float, step: float) -> int:
	return maxi(1, roundi(span / step))


## One MultiMeshInstance3D per mesh of `scene`, placed at every cell.
func _add_multimeshes(scene: PackedScene, cells: Array[Transform3D]) -> void:
	var template := scene.instantiate() as Node3D
	for part in _meshes(template):
		var offset := _relative(part, template)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = part.mesh
		multimesh.instance_count = cells.size()
		for index in cells.size():
			multimesh.set_instance_transform(index, cells[index] * offset)
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		add_child(instance)
	template.free()


static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh:
			result.append(child)
		result.append_array(_meshes(child))
	return result


static func _relative(node: Node3D, root: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current := node
	while current and current != root:
		result = current.transform * result
		current = current.get_parent() as Node3D
	return result
