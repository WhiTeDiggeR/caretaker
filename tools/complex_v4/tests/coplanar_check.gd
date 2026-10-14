extends SceneTree
## Finds flickering surfaces (z-fighting) in the whole assembled complex: faces of different meshes that lie in the
## same plane, face the same way and overlap. Every visible mesh of every sector is checked against every other
## (shared walls and slabs between sectors, #205; stairs and shafts, #95).
## A sector whose generated package was built from an older canonical SVG than the current one (the source sha256 in
## its generation_manifest.json differs) is waiting for regeneration: its pairs outside stairs and shafts are listed
## as pending, not as overlaps. Stair and shaft pairs are always strict.
## godot --headless --path . --script res://tools/complex_v4/tests/coplanar_check.gd
## Prints COPLANAR_CHECK meshes=<n> overlaps=<n> pending=<n>; exit 1 on overlaps.

const ASSEMBLY := "res://scenes/complex_v4/complex_v4_blockout.tscn"
const MANIFEST := "res://tools/complex_v4/sector_generation_manifest.json"
const PLANE_TOLERANCE_M := 0.001
const MIN_OVERLAP_M2 := 0.002  # smaller overlaps are edge slivers of touching faces


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stale := _stale_sectors()
	var assembly: Node = (load(ASSEMBLY) as PackedScene).instantiate()
	root.add_child(assembly)
	await process_frame
	var buckets := {}
	var checked := 0
	for node: Node in assembly.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var path := str(mesh.get_path())
		if path.contains("/Railings") or path.contains("_Riser_"):
			continue  # a riser top is always covered by the tread above it
		checked += 1
		_collect(mesh, buckets)
	var overlaps := {}
	var pending := {}
	for key: String in buckets:
		var faces: Array = buckets[key]
		for i in faces.size():
			for j in range(i + 1, faces.size()):
				var first: String = faces[i][0]
				var second: String = faces[j][0]
				if first == second:
					continue
				var area := _overlap(faces[i][1], faces[j][1])
				if area <= MIN_OVERLAP_M2:
					continue
				var pair := "%s: %s / %s" % [key, first, second]
				var line := "%s (%.4f m2)" % [pair, area]
				if not _is_vertical(first) and not _is_vertical(second) and (stale.has(_sector(first)) or stale.has(_sector(second))):
					pending[pair] = line
				else:
					overlaps[pair] = line
	for line: String in overlaps.values():
		print("  ", line)
	if not pending.is_empty():
		var waiting: Array = stale.keys()
		waiting.sort()
		print("  pending regeneration (%d pairs): %s" % [pending.size(), ", ".join(waiting)])
	print("COPLANAR_CHECK meshes=%d overlaps=%d pending=%d" % [checked, overlaps.size(), pending.size()])
	quit(0 if overlaps.is_empty() else 1)


## Node names (L_ARCHIVE_A) of sectors whose package is older than their canonical SVG.
func _stale_sectors() -> Dictionary:
	var stale := {}
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) as Dictionary
	for sector: Dictionary in manifest["sectors"]:
		var generation := JSON.parse_string(FileAccess.get_file_as_string(str(sector["output_resource_dir"]) + "/generation_manifest.json")) as Dictionary
		var built := str((generation.get("source", {}) as Dictionary).get("sha256", "")) if generation else ""
		var current := "sha256:" + FileAccess.get_sha256("res://" + str(sector["source_svg"]))
		if built != current:
			stale[str(sector["sector_id"]).replace("-", "_")] = true
	return stale


func _sector(name: String) -> String:
	return name.get_slice("/", 0)


func _is_vertical(name: String) -> bool:
	return name.contains("Stairs/") or name.contains("Closures/")


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
