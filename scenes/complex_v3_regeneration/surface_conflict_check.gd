extends SceneTree

## Looks for the joint defects that were found by eye on the pilot sector, in the generated geometry of
## every sector (architecture + stairs, in world space):
##   coplanar  - two meshes have same-facing faces closer than COPLANAR_TOLERANCE_M that overlap by more than
##               MIN_OVERLAP_M2: the renderer flickers there (z-fighting).
##   crossing  - an edge of one mesh passes through a face of another mesh by more than CROSSING_DEPTH_M:
##               one body sticks into another (a tread through a floor, a wall through a stair).
## Findings are counted per sector and per kind (pairs of meshes) and compared with
## surface_conflict_baseline.json: a count above the baseline fails, a count below it asks for the baseline to
## be lowered. Sectors listed in "clean" must have no findings at all.
## Run with `-- --write-baseline` to rewrite the baseline, with `-- --verbose` to list every pair.
const MANIFEST := "res://tools/complex_v3_regeneration/sector_generation_manifest.json"
const BASELINE := "res://scenes/complex_v3_regeneration/surface_conflict_baseline.json"
const COPLANAR_TOLERANCE_M := 0.005
const MIN_OVERLAP_M2 := 0.0004
const CROSSING_DEPTH_M := 0.01
const MIN_TRIANGLE_AREA_M2 := 0.000001
const NORMAL_KEY_SCALE := 1000.0
const KINDS := ["coplanar", "crossing"]


class Tri:
	var a: Vector3
	var b: Vector3
	var c: Vector3
	var normal: Vector3
	var area: float
	var mesh: int
	var low: Vector3
	var high: Vector3


func _init() -> void:
	var verbose := OS.get_cmdline_user_args().has("--verbose")
	var write_baseline := OS.get_cmdline_user_args().has("--write-baseline")
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) as Dictionary
	var baseline := JSON.parse_string(FileAccess.get_file_as_string(BASELINE)) as Dictionary if FileAccess.file_exists(BASELINE) else {"clean": [], "counts": {}}
	var clean: Array = baseline.get("clean", [])
	var allowed: Dictionary = baseline.get("counts", {})
	var errors := PackedStringArray()
	var notes := PackedStringArray()
	var counts := {}
	var total := 0
	await _self_test(errors)
	for sector: Dictionary in manifest["sectors"]:
		var sector_id := str(sector["sector_id"])
		var root := (load(str(sector["sector_scene"])) as PackedScene).instantiate()
		get_root().add_child(root)
		await process_frame
		var names: Array[String] = []
		_stair_mesh.clear()
		verbose_details.clear()
		var triangles := _collect_triangles(root.get_node("Generated"), names)
		var found := {"coplanar": {}, "crossing": {}}
		_find_coplanar(triangles, found["coplanar"])
		_find_crossings(triangles, found["crossing"])
		root.queue_free()
		await process_frame
		counts[sector_id] = {}
		var line := ""
		for kind: String in KINDS:
			var pairs: Dictionary = found[kind]
			counts[sector_id][kind] = pairs.size()
			total += pairs.size()
			if pairs.size() > 0:
				line += " %s=%d" % [kind, pairs.size()]
			if verbose:
				for key: String in pairs:
					var parts := key.split("|")
					print("  %s %s: %s x %s (%s)" % [sector_id, kind, names[int(parts[0])], names[int(parts[1])], ("%.2f m2" if kind == "coplanar" else "%.3f m deep") % float(pairs[key]) + " " + str(verbose_details.get(key, ""))])
			var limit := int(((allowed.get(sector_id, {}) as Dictionary).get(kind, 0)))
			if clean.has(sector_id):
				limit = 0
			if pairs.size() > limit:
				errors.append("%s: %d %s pairs, baseline allows %d" % [sector_id, pairs.size(), kind, limit])
			elif pairs.size() < limit:
				notes.append("%s: %s pairs dropped from %d to %d, lower the baseline" % [sector_id, kind, limit, pairs.size()])
		if not line.is_empty():
			print("SURFACE %s%s" % [sector_id, line])
	if write_baseline:
		var kept_clean: Array = []
		for sector_id: String in counts:
			var all_zero := true
			for kind: String in KINDS:
				all_zero = all_zero and int(counts[sector_id][kind]) == 0
			if all_zero:
				kept_clean.append(sector_id)
		var document := {"clean": kept_clean, "counts": counts}
		var file := FileAccess.open(BASELINE, FileAccess.WRITE)
		file.store_string(JSON.stringify(document, "\t", true) + "\n")
		file.close()
		print("SURFACE_CONFLICT_BASELINE written clean=%d" % kept_clean.size())
		quit(0)
		return
	for line: String in notes:
		print("NOTE: ", line)
	for line: String in errors:
		printerr("ERROR: ", line)
	print("SURFACE_CONFLICT_CHECK sectors=%d findings=%d errors=%d" % [counts.size(), total, errors.size()])
	quit(0 if errors.is_empty() else 1)


## Three synthetic slabs: B's top is 2 mm above A's top (z-fighting) and C stands through A (crossing).
## The check is worthless if it cannot see them, so it fails when it does not.
func _self_test(errors: PackedStringArray) -> void:
	var holder := Node3D.new()
	get_root().add_child(holder)
	var specs := [[Vector3(4, 1, 4), Vector3(0, 0, 0)], [Vector3(2, 1, 2), Vector3(0, 0.002, 0)], [Vector3(0.5, 3, 0.5), Vector3(1, 0, 1)]]
	for spec: Array in specs:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = spec[0]
		box.mesh = mesh
		box.position = spec[1]
		holder.add_child(box)
	await process_frame
	var names: Array[String] = []
	_stair_mesh.clear()
	var triangles := _collect_triangles(holder, names)
	var coplanar := {}
	var crossing := {}
	_find_coplanar(triangles, coplanar)
	_find_crossings(triangles, crossing)
	if not coplanar.has(_pair_key(0, 1)):
		errors.append("self-test: the check does not see two slabs with coplanar tops")
	if not crossing.has(_pair_key(0, 2)):
		errors.append("self-test: the check does not see a body passing through a slab")
	holder.queue_free()
	await process_frame


func _collect_triangles(node: Node, names: Array[String]) -> Array[Tri]:
	var triangles: Array[Tri] = []
	_gather(node, names, triangles)
	return triangles


func _gather(node: Node, names: Array[String], triangles: Array[Tri]) -> void:
	var instance := node as MeshInstance3D
	if instance != null and instance.mesh != null and instance.is_visible_in_tree():
		var index := names.size()
		var short_name := str(instance.get_path()).get_slice("/Generated/", 1) if "/Generated/" in str(instance.get_path()) else str(instance.name)
		names.append(short_name)
		_stair_mesh[index] = short_name.begins_with("Stairs/")
		var xform := instance.global_transform
		var faces := instance.mesh.get_faces()
		for i in range(0, faces.size() - 2, 3):
			var tri := Tri.new()
			tri.a = xform * faces[i]
			tri.b = xform * faces[i + 1]
			tri.c = xform * faces[i + 2]
			var cross := (tri.b - tri.a).cross(tri.c - tri.a)
			tri.area = cross.length() * 0.5
			if tri.area < MIN_TRIANGLE_AREA_M2:
				continue
			tri.normal = cross.normalized()
			tri.mesh = index
			tri.low = Vector3(minf(tri.a.x, minf(tri.b.x, tri.c.x)), minf(tri.a.y, minf(tri.b.y, tri.c.y)), minf(tri.a.z, minf(tri.b.z, tri.c.z)))
			tri.high = Vector3(maxf(tri.a.x, maxf(tri.b.x, tri.c.x)), maxf(tri.a.y, maxf(tri.b.y, tri.c.y)), maxf(tri.a.z, maxf(tri.b.z, tri.c.z)))
			triangles.append(tri)
	for child: Node in node.get_children():
		_gather(child, names, triangles)


## Pairs of meshes that both belong to the stair package are the stair generator's own business (posts
## through rails, shaft wall corners): the flow cannot change them, so they are not reported.
var _stair_mesh: Dictionary = {}


func _pair_key(first: int, second: int) -> String:
	return "%d|%d" % [mini(first, second), maxi(first, second)]


var verbose_details: Dictionary = {}


func _find_coplanar(triangles: Array[Tri], pairs: Dictionary) -> void:
	var groups := {}
	for tri in triangles:
		var key := Vector3i(roundi(tri.normal.x * NORMAL_KEY_SCALE), roundi(tri.normal.y * NORMAL_KEY_SCALE), roundi(tri.normal.z * NORMAL_KEY_SCALE))
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(tri)
	for key: Vector3i in groups:
		var group: Array = groups[key]
		group.sort_custom(func(left: Tri, right: Tri) -> bool: return left.normal.dot(left.a) < right.normal.dot(right.a))
		for i in group.size():
			var first := group[i] as Tri
			var first_d := first.normal.dot(first.a)
			for j in range(i + 1, group.size()):
				var second := group[j] as Tri
				if second.normal.dot(second.a) - first_d > COPLANAR_TOLERANCE_M:
					break
				if first.mesh == second.mesh or _stair_internal(first, second) or not _boxes_overlap(first, second):
					continue
				var overlap := _overlap_area(first, second)
				if overlap > MIN_OVERLAP_M2:
					var pair := _pair_key(first.mesh, second.mesh)
					pairs[pair] = float(pairs.get(pair, 0.0)) + overlap
					if verbose_details != null and not verbose_details.has(pair):
						verbose_details[pair] = "n=%s d=%.3f at %s" % [first.normal.snappedf(0.001), first.normal.dot(first.a), ((first.a + first.b + first.c) / 3.0).snappedf(0.01)]


func _find_crossings(triangles: Array[Tri], pairs: Dictionary) -> void:
	var cell := 2.0
	var grid := {}
	for index in triangles.size():
		var tri := triangles[index]
		for x in range(floori(tri.low.x / cell), floori(tri.high.x / cell) + 1):
			for y in range(floori(tri.low.y / cell), floori(tri.high.y / cell) + 1):
				for z in range(floori(tri.low.z / cell), floori(tri.high.z / cell) + 1):
					var cell_key := Vector3i(x, y, z)
					if not grid.has(cell_key):
						grid[cell_key] = []
					(grid[cell_key] as Array).append(index)
	var tested := {}
	for cell_key: Vector3i in grid:
		var members: Array = grid[cell_key]
		for i in members.size():
			for j in range(i + 1, members.size()):
				var first := triangles[members[i]]
				var second := triangles[members[j]]
				if first.mesh == second.mesh or _stair_internal(first, second):
					continue
				var pair := _pair_key(first.mesh, second.mesh)
				if pairs.has(pair):
					continue
				var tri_key := (members[i] as int) * 1000003 + (members[j] as int)
				if tested.has(tri_key) or not _boxes_overlap(first, second):
					continue
				tested[tri_key] = true
				var depth := maxf(_penetration(first, second), _penetration(second, first))
				if depth > CROSSING_DEPTH_M:
					pairs[pair] = depth


func _stair_internal(first: Tri, second: Tri) -> bool:
	return bool(_stair_mesh.get(first.mesh, false)) and bool(_stair_mesh.get(second.mesh, false))


func _boxes_overlap(first: Tri, second: Tri) -> bool:
	return first.low.x <= second.high.x + COPLANAR_TOLERANCE_M and second.low.x <= first.high.x + COPLANAR_TOLERANCE_M \
		and first.low.y <= second.high.y + COPLANAR_TOLERANCE_M and second.low.y <= first.high.y + COPLANAR_TOLERANCE_M \
		and first.low.z <= second.high.z + COPLANAR_TOLERANCE_M and second.low.z <= first.high.z + COPLANAR_TOLERANCE_M


## Depth to which the edges of `edges_of` stick through the interior of `face_of` (0 when none does).
func _penetration(edges_of: Tri, face_of: Tri) -> float:
	var depth := 0.0
	var points := [edges_of.a, edges_of.b, edges_of.c]
	for i in 3:
		var from: Vector3 = points[i]
		var to: Vector3 = points[(i + 1) % 3]
		var from_side := face_of.normal.dot(from - face_of.a)
		var to_side := face_of.normal.dot(to - face_of.a)
		if from_side * to_side >= 0.0:
			continue
		var hit := from.lerp(to, from_side / (from_side - to_side))
		if not _inside(face_of, hit):
			continue
		depth = maxf(depth, minf(absf(from_side), absf(to_side)))
	return depth


func _inside(tri: Tri, point: Vector3) -> bool:
	var margin := 0.001
	var edges := [[tri.a, tri.b], [tri.b, tri.c], [tri.c, tri.a]]
	for edge: Array in edges:
		var direction: Vector3 = (edge[1] as Vector3) - (edge[0] as Vector3)
		var inward := tri.normal.cross(direction).normalized()
		if inward.dot(point - (edge[0] as Vector3)) < margin:
			return false
	return true


## Area where two coplanar triangles overlap (Sutherland-Hodgman clipping in the plane of the first one).
func _overlap_area(first: Tri, second: Tri) -> float:
	var polygon: Array[Vector3] = [second.a, second.b, second.c]
	var corners := [first.a, first.b, first.c]
	for i in 3:
		var from: Vector3 = corners[i]
		var to: Vector3 = corners[(i + 1) % 3]
		var inward := first.normal.cross(to - from).normalized()
		var clipped: Array[Vector3] = []
		for k in polygon.size():
			var current := polygon[k]
			var previous := polygon[(k + polygon.size() - 1) % polygon.size()]
			var current_in := inward.dot(current - from) >= 0.0
			var previous_in := inward.dot(previous - from) >= 0.0
			if current_in != previous_in:
				var s_prev := inward.dot(previous - from)
				var s_cur := inward.dot(current - from)
				clipped.append(previous.lerp(current, s_prev / (s_prev - s_cur)))
			if current_in:
				clipped.append(current)
		polygon = clipped
		if polygon.size() < 3:
			return 0.0
	var area_vector := Vector3.ZERO
	for k in range(1, polygon.size() - 1):
		area_vector += (polygon[k] - polygon[0]).cross(polygon[k + 1] - polygon[0])
	return area_vector.length() * 0.5
