extends SceneTree
## Finds flickering surfaces (z-fighting) around stairs and shafts: faces of different meshes that lie in the same plane, face the
## same way and overlap, where one of them belongs to a stair or a shaft closure. Only meshes near those layers are checked.
## godot --headless --path . --script res://tools/complex_v4/tests/coplanar_check.gd
## Prints COPLANAR_CHECK meshes=<n> overlaps=<n>; exit 1 on overlaps.

const ASSEMBLY := "res://scenes/complex_v4/complex_v4_blockout.tscn"
const PLANE_TOLERANCE_M := 0.001
const MIN_OVERLAP_M2 := 0.002  # smaller overlaps are edge slivers of touching faces
const NEAR_M := 0.5


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var assembly: Node = (load(ASSEMBLY) as PackedScene).instantiate()
	root.add_child(assembly)
	await process_frame
	var meshes: Array[MeshInstance3D] = []
	var focus: Array[AABB] = []
	for node: Node in assembly.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var path := str(mesh.get_path())
		if path.contains("/Railings") or path.contains("_Riser_"):
			continue  # a riser top is always covered by the tread above it
		meshes.append(mesh)
		if path.contains("/Generated/Stairs/") or path.contains("/Closures/"):
			focus.append((mesh.global_transform * mesh.mesh.get_aabb()).grow(NEAR_M))
	var buckets := {}
	var checked := 0
	for mesh: MeshInstance3D in meshes:
		var box := mesh.global_transform * mesh.mesh.get_aabb()
		if not focus.any(func(area: AABB) -> bool: return area.intersects(box)):
			continue
		checked += 1
		_collect(mesh, buckets)
	var overlaps: Array[String] = []
	for key: String in buckets:
		var faces: Array = buckets[key]
		for i in faces.size():
			for j in range(i + 1, faces.size()):
				if faces[i][0] == faces[j][0]:
					continue
				var area := _overlap(faces[i][1], faces[j][1])
				var near_stair: bool = str(faces[i][0]).contains("Stairs/") or str(faces[i][0]).contains("Closures/") or str(faces[j][0]).contains("Stairs/") or str(faces[j][0]).contains("Closures/")
				if area > MIN_OVERLAP_M2 and near_stair:
					overlaps.append("%s: %s / %s (%.4f m2)" % [key, faces[i][0], faces[j][0], area])
	var unique := {}
	for line: String in overlaps:
		unique[line.get_slice(" (", 0)] = line
	for line: String in unique.values():
		print("  ", line)
	print("COPLANAR_CHECK meshes=%d overlaps=%d" % [checked, unique.size()])
	quit(0 if unique.is_empty() else 1)


func _collect(mesh: MeshInstance3D, buckets: Dictionary) -> void:
	var name := str(mesh.get_path()).get_slice("/Zones/", 1)
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for t in range(0, count, 3):
			var a := mesh.global_transform * vertices[indices[t] if not indices.is_empty() else t]
			var b := mesh.global_transform * vertices[indices[t + 1] if not indices.is_empty() else t + 1]
			var c := mesh.global_transform * vertices[indices[t + 2] if not indices.is_empty() else t + 2]
			var normal := (b - a).cross(c - a)
			if normal.length() < 1e-9:
				continue
			normal = normal.normalized()
			var axis := -1
			for k in 3:
				if absf(normal[k]) > 0.999:
					axis = k
			if axis < 0:
				continue
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			var key := "%s%s=%.3f" % ["+" if normal[axis] > 0 else "-", "xyz"[axis], snappedf(a[axis], PLANE_TOLERANCE_M)]
			if not buckets.has(key):
				buckets[key] = []
			(buckets[key] as Array).append([name, PackedVector2Array([Vector2(a[u], a[v]), Vector2(b[u], b[v]), Vector2(c[u], c[v])])])


func _overlap(first: PackedVector2Array, second: PackedVector2Array) -> float:
	var total := 0.0
	for polygon: PackedVector2Array in Geometry2D.intersect_polygons(first, second):
		var area := 0.0
		for i in polygon.size():
			var p := polygon[i]
			var q := polygon[(i + 1) % polygon.size()]
			area += p.x * q.y - q.x * p.y
		total += absf(area) / 2.0
	return total
