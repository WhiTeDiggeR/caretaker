extends SceneTree

const PILOT := "res://scenes/complex_v3_regeneration/pilots/route_a_vertical/pilot_scene.tscn"
const REPORT := "res://scenes/complex_v3_regeneration/pilots/route_a_vertical/reports/combined-physics.json"
const EPS := 0.0001
var _errors: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(PILOT) as PackedScene
	if packed == null:
		push_error("Cannot load Route A pilot")
		quit(1)
		return
	var pilot := packed.instantiate() as Node3D
	root.add_child(pilot)
	var architecture: Array[Node] = [pilot.get_node("Generated/Upper"), pilot.get_node("Generated/Lower")]
	var stair := pilot.get_node("Generated/Stair")
	for item: Node in architecture:
		_set_layer(item, 1)
	_set_layer(stair, 2)
	await process_frame
	await physics_frame
	await physics_frame
	var space := pilot.get_world_3d().direct_space_state
	var shapes := stair.find_children("*", "CollisionShape3D", true, false)
	_expect(shapes.size() > 100, "stair collision shapes must load")
	for node: Node in shapes:
		var collision := node as CollisionShape3D
		if collision.shape == null:
			_errors.append("missing stair shape: %s" % node.get_path())
			continue
		var shape := collision.shape.duplicate() as Shape3D
		if shape is BoxShape3D:
			(shape as BoxShape3D).size -= Vector3.ONE * EPS * 2.0
		var hits := _overlaps(space, shape, collision.global_transform, 1)
		for hit: Dictionary in hits:
			_errors.append("stair/architecture penetration: %s with %s" % [node.get_path(), (hit["collider"] as Node).get_path()])
		_checks += 1
	# Both threshold volumes lie on the approach side of the first/last tread.
	for entry: Vector3 in [Vector3(-53.6, -6, 5.8), Vector3(-51.4, 0, 5.8)]:
		var clearance := BoxShape3D.new()
		clearance.size = Vector3(1.3, 2.35, 0.35)
		var hits := _overlaps(space, clearance, Transform3D(Basis.IDENTITY, entry + Vector3(0, 1.2, 0)), 3)
		_expect(hits.is_empty(), "blocked stair threshold at %s: %s" % [entry, hits])
	# Test all authored footprints against actual architecture and stair bodies.
	for node: Node in pilot.get_node("AuthoredContent").get_children():
		if node.has_method("get_anchor_errors"):
			_expect(node.call("get_anchor_errors").is_empty(), "authored anchor resolution: %s" % node.name)
		var mesh_node := node as MeshInstance3D if node is MeshInstance3D else node.get_node("Visual") as MeshInstance3D
		var mesh := mesh_node.mesh as BoxMesh
		var shape := BoxShape3D.new()
		shape.size = mesh.size - Vector3.ONE * EPS * 2.0
		_expect(_overlaps(space, shape, mesh_node.global_transform, 3).is_empty(), "authored footprint intersects generated geometry: %s" % node.name)
		var ray := PhysicsRayQueryParameters3D.create(mesh_node.global_position, mesh_node.global_position + Vector3.DOWN * 1.0, 3)
		if node.name != "ShaftBeacon":
			var support := space.intersect_ray(ray)
			if support.is_empty():
				var below := PhysicsRayQueryParameters3D.create(mesh_node.global_position + Vector3.DOWN, mesh_node.global_position, 3)
				var reverse_hit := space.intersect_ray(below)
				print("SUPPORT_DIAGNOSTIC %s downward=%s upward=%s" % [node.name, support, reverse_hit])
			_expect(not support.is_empty(), "missing physical support: %s" % node.name)
	var report := {"schema_id": "caretaker.route_a_combined_physics", "schema_version": "1.0.0", "status": "passed" if _errors.is_empty() else "blocked", "checks": _checks, "stair_shapes": shapes.size(), "penetration_tolerance_m": EPS, "errors": _errors}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file == null:
		_errors.append("cannot write physics report")
	else:
		file.store_string(JSON.stringify(report, "  ") + "\n")
	print("ROUTE_A_COMBINED checks=%d errors=%d" % [_checks, _errors.size()])
	for error: String in _errors:
		push_error(error)
	pilot.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)


func _set_layer(node: Node, layer: int) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = layer
	for child: Node in node.get_children():
		_set_layer(child, layer)


func _overlaps(space: PhysicsDirectSpaceState3D, shape: Shape3D, placement: Transform3D, mask: int) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = placement
	query.collision_mask = mask
	query.margin = 0.0
	return space.intersect_shape(query, 256)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(message)
