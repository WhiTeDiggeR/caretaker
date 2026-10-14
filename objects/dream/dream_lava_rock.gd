@tool
class_name DreamLavaRock
extends MeshInstance3D

## A rock standing in the lava of a dream (#217): a closed crag of real volume, rough from every
## side — an icosphere pushed out by noise into ledges and creases, its foot sunk under the lava.
## Built in code from `rock_seed`, so neighbouring rocks never repeat and nothing binary is added.
## Origin at the centre of the foot (the lava line sits a little above it); `size` is the bounding box.

const SUBDIVISIONS := 3
## Share of the height under the foot: the rock goes on below the lava, no edge shows.
const SINK := 0.25
const NOISE_FREQUENCY := 1.4
## How far the noise pushes the surface, as a share of the radius: broad bulges and sharp creases.
const BULGE := 0.32
const CREASE := 0.18
## The top narrows into a crag; the foot stays broad.
const TAPER := 0.35

@export var size := Vector3(7.0, 5.5, 5.5):
	set(value):
		size = value
		_rebuild()
@export var rock_seed := 1:
	set(value):
		rock_seed = value
		_rebuild()
@export var rock_material: Material:
	set(value):
		rock_material = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	mesh = build_mesh(size, rock_seed, rock_material)


static func build_mesh(box: Vector3, noise_seed: int, material: Material) -> ArrayMesh:
	var bulge := FastNoiseLite.new()
	bulge.seed = noise_seed
	bulge.frequency = NOISE_FREQUENCY
	bulge.fractal_octaves = 3
	var crease := FastNoiseLite.new()
	crease.seed = noise_seed + 101
	crease.frequency = NOISE_FREQUENCY * 2.3
	crease.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	crease.fractal_octaves = 2
	var sphere := _icosphere(SUBDIVISIONS)
	var tools := SurfaceTool.new()
	tools.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height := box.y * (1.0 + SINK)
	var points := PackedVector3Array()
	for unit: Vector3 in sphere.vertices:
		var push := 1.0 + bulge.get_noise_3dv(unit) * BULGE - absf(crease.get_noise_3dv(unit)) * CREASE
		var p := unit * push
		var up := (p.y + 1.0) * 0.5  # 0 at the foot … 1 at the top
		var narrow := 1.0 - TAPER * up * up
		points.append(Vector3(p.x * box.x * 0.5 * narrow, up * height - box.y * SINK, p.z * box.z * 0.5 * narrow))
	tools.set_smooth_group(0xFFFFFFFF)
	for index in sphere.indices.size():
		tools.add_vertex(points[sphere.indices[index]])
	# Flat facets: a crag reads by its planes, the material adds the grain.
	tools.generate_normals()
	if material:
		tools.set_material(material)
	return tools.commit()


## An icosphere of unit radius: {"vertices": PackedVector3Array, "indices": PackedInt32Array}.
static func _icosphere(subdivisions: int) -> Dictionary:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var vertices := PackedVector3Array()
	for v in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		vertices.append((v as Vector3).normalized())
	var faces := PackedInt32Array([0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11,
			1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
			3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9,
			4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1])
	for _step in subdivisions:
		var middles := {}
		var next := PackedInt32Array()
		for f in range(0, faces.size(), 3):
			var a := faces[f]
			var b := faces[f + 1]
			var c := faces[f + 2]
			var ab := _middle(vertices, middles, a, b)
			var bc := _middle(vertices, middles, b, c)
			var ca := _middle(vertices, middles, c, a)
			next.append_array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca])
		faces = next
	# Godot faces are clockwise seen from outside.
	var indices := PackedInt32Array()
	for f in range(0, faces.size(), 3):
		indices.append_array([faces[f], faces[f + 2], faces[f + 1]])
	return {"vertices": vertices, "indices": indices}


static func _middle(vertices: PackedVector3Array, middles: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if not middles.has(key):
		middles[key] = vertices.size()
		vertices.append(((vertices[a] + vertices[b]) * 0.5).normalized())
	return middles[key]
