class_name DreamGlyph
extends RefCounted

## One source of a glyph's shape for every place it is drawn (07-dream-glyphs.md, section 6;
## #194 З-Р2): the strokes of data/dreams/knowledge.json on the 3 × 3 grid (nodes 0…2) become
## polylines in a unit square, then lines in UI (DreamGlyphView) or a flat ribbon mesh in 3D
## (DreamGlyphImage, the resync panel keys). One stroke width, rounded ends and joints.

## Stroke width as a share of the glyph size; on screen never thinner than MIN_UI_WIDTH.
const WIDTH := 0.09
const MIN_UI_WIDTH := 2.0
const DOT_RADIUS := 0.07
const CIRCLE_SEGMENTS := 28
const JOINT_SEGMENTS := 8
const GRID := 2.0


## Polylines of glyph `id` in the unit square (x right, y down). A dot is a one-point line.
static func polylines(id: String) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for stroke: Dictionary in DreamKnowledge.glyph(id).get("strokes", []):
		var line := PackedVector2Array()
		if stroke.has("line"):
			for point: Array in stroke["line"]:
				line.append(Vector2(point[0], point[1]) / GRID)
		elif stroke.has("circle"):
			var circle: Array = stroke["circle"]
			var center := Vector2(circle[0], circle[1]) / GRID
			for index in CIRCLE_SEGMENTS + 1:
				line.append(center + Vector2.from_angle(TAU * index / CIRCLE_SEGMENTS) * float(circle[2]) / GRID)
		elif stroke.has("dot"):
			line.append(Vector2(stroke["dot"][0], stroke["dot"][1]) / GRID)
		if not line.is_empty():
			result.append(line)
	return result


## A flat mesh of the glyph in the XY plane, centred, `size` metres wide, facing +Z; `width_scale`
## widens the stroke (a glow under it, #217).
static func build_mesh(id: String, size: float, width_scale := 1.0) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var half := size * WIDTH * 0.5 * width_scale
	for line in polylines(id):
		if line.size() == 1:
			_disc(vertices, _to_3d(line[0], size), size * DOT_RADIUS * width_scale, JOINT_SEGMENTS * 2)
			continue
		for index in line.size():
			_disc(vertices, _to_3d(line[index], size), half, JOINT_SEGMENTS)
			if index > 0:
				_segment(vertices, _to_3d(line[index - 1], size), _to_3d(line[index], size), half)
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.BACK)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func mesh_instance(id: String, size: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = "Glyph"
	instance.mesh = build_mesh(id, size)
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


static func flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


static func _to_3d(point: Vector2, size: float) -> Vector3:
	return Vector3(point.x - 0.5, 0.5 - point.y, 0.0) * size


static func _segment(vertices: PackedVector3Array, from: Vector3, to: Vector3, half: float) -> void:
	var side := Vector3.BACK.cross(to - from).normalized() * half
	vertices.append_array([from - side, from + side, to + side, from - side, to + side, to - side])


static func _disc(vertices: PackedVector3Array, center: Vector3, radius: float, segments: int) -> void:
	for index in segments:
		var a := Vector2.from_angle(TAU * index / segments) * radius
		var b := Vector2.from_angle(TAU * (index + 1) / segments) * radius
		vertices.append_array([center, center + Vector3(a.x, a.y, 0), center + Vector3(b.x, b.y, 0)])
