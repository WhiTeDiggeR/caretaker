extends SceneTree

const SHARED := "res://gen/shared/Generated/Infrastructure/shared_infrastructure_generated.tscn"
const ROUTE_A_STAIR := "res://scenes/cv3_route_a/u/Generated/Stairs/route_a_stair/route_a_stair.tscn"
const REPORT := "res://scenes/complex_v3_regeneration/rollout/shared/reports/combined-physics.json"
const EPS := 0.0001
var _errors: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sectors := Node3D.new()
	sectors.name = "Sectors"
	root.add_child(sectors)
	for level: String in ["upper", "lower", "technical"]:
		var manifest := _json("res://tools/complex_v3_regeneration/rollouts/%s_generation_manifest.json" % level)
		for value: Variant in manifest.get("sectors", []):
			var entry := value as Dictionary
			_load_architecture(sectors, str(entry["output_resource_dir"]), str(entry["scene_name"]), str(entry["sector_id"]))
	var medbay := _json("res://tools/complex_v3_regeneration/pilots/u_medbay/pilot_generation_manifest.json")
	for value: Variant in medbay.get("sectors", []):
		var entry := value as Dictionary
		_load_architecture(sectors, str(entry["output_resource_dir"]), str(entry["scene_name"]), str(entry["sector_id"]))
	var route_a := _json("res://tools/complex_v3_regeneration/pilots/route_a_vertical/pilot_generation_manifest.json")
	for value: Variant in route_a.get("sectors", []):
		var entry := value as Dictionary
		_load_architecture(sectors, str(entry["output_resource_dir"]), str(entry["scene_name"]), str(entry["sector_id"]))
	var shared := _instantiate(SHARED, "Shared")
	var stair := _instantiate(ROUTE_A_STAIR, "RouteAStair")
	if shared == null or stair == null:
		_finish()
		return
	root.add_child(shared)
	root.add_child(stair)
	_checks += 2
	if str(shared.get_meta("geometry_policy", "")) != "external_single_owner":
		_errors.append("shared package does not declare external single-owner geometry")
	var shared_collisions := shared.find_children("*", "CollisionShape3D", true, false)
	_checks += 1
	if not shared_collisions.is_empty():
		_errors.append("shared contract duplicates %d sector-owned collision shapes" % shared_collisions.size())
	_set_layer(sectors, 1)
	_set_layer(shared, 2)
	_set_layer(stair, 4)
	await process_frame
	await physics_frame
	await physics_frame
	var space := shared.get_world_3d().direct_space_state
	_check_box_shapes(space, shared, 1, "shared/sector")
	_check_box_shapes(space, stair, 2, "route-a/shared")
	_finish()


func _load_architecture(parent: Node3D, directory: String, scene_name: String, sector_id: String) -> void:
	var path := "%s/Generated/Architecture/%s.tscn" % [directory, scene_name]
	var instance := _instantiate(path, sector_id)
	if instance == null:
		return
	parent.add_child(instance)
	_checks += 1


func _instantiate(path: String, label: String) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		_errors.append("cannot load %s: %s" % [label, path])
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		_errors.append("root is not Node3D: %s" % path)
	return instance


func _check_box_shapes(space: PhysicsDirectSpaceState3D, source: Node, mask: int, relation: String) -> void:
	for value: Node in source.find_children("*", "CollisionShape3D", true, false):
		var collision := value as CollisionShape3D
		if collision.shape == null:
			_errors.append("empty shape: %s" % collision.get_path())
			continue
		if not collision.shape is BoxShape3D:
			continue
		var shape := collision.shape.duplicate() as BoxShape3D
		shape.size -= Vector3.ONE * EPS * 2.0
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = collision.global_transform
		query.collision_mask = mask
		query.margin = 0.0
		for hit: Dictionary in space.intersect_shape(query, 256):
			_errors.append("%s overlap: %s with %s" % [relation, collision.get_path(), (hit["collider"] as Node).get_path()])
		_checks += 1


func _set_layer(node: Node, layer: int) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = layer
		(node as CollisionObject3D).collision_mask = 0
	for child: Node in node.get_children():
		_set_layer(child, layer)


func _json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("cannot read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _finish() -> void:
	var report := {"schema_id":"caretaker.shared_combined_physics","schema_version":"1.0.0","status":"passed" if _errors.is_empty() else "blocked","checks":_checks,"penetration_tolerance_m":EPS,"errors":_errors,"startup_modified":false}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  ") + "\n")
	print("SHARED_COMBINED checks=%d errors=%d" % [_checks,_errors.size()])
	for error: String in _errors:
		push_error(error)
	quit(0 if _errors.is_empty() else 1)
