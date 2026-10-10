extends SceneTree

const REGISTRY_SCRIPT := preload("res://scenes/complex_v3_regeneration/anchor_registry.gd")
const PLACEMENT_SCRIPT := preload("res://scenes/complex_v3_regeneration/anchor_placement.gd")
const AXIS_SCRIPT := preload("res://scenes/complex_v3_regeneration/anchor_axis_placement.gd")
const ANCHORED_SCRIPT := preload("res://scenes/complex_v3_regeneration/anchored_object_3d.gd")
const ANCHORS_PATH := "res://scenes/complex_v3_regeneration/pilots/u_medbay/live/anchor_frames.json"
const BINDINGS_PATH := "res://scenes/complex_v3_regeneration/pilots/u_medbay/AuthoredContent/object_bindings.json"
const GENERATED_SCENE := "res://scenes/complex_v3_regeneration/pilots/u_medbay/live/Generated/Architecture/u_medbay_pilot_generated.tscn"

var _errors := PackedStringArray()


func _initialize() -> void:
	var architecture_resource := load(GENERATED_SCENE) as PackedScene
	_expect(architecture_resource != null, "generated architecture scene must load")
	if architecture_resource != null:
		var architecture := architecture_resource.instantiate()
		root.add_child(architecture)
		_expect(_count_valid_meshes(architecture) >= 50, "generated architecture must contain loaded meshes")
		_expect(_count_valid_collisions(architecture) >= 40, "generated architecture must contain loaded collision shapes")

	var anchors := _read_json(ANCHORS_PATH)
	var bindings := _read_json(BINDINGS_PATH)
	if anchors.is_empty() or bindings.is_empty():
		_finish()
		return
	var registry := REGISTRY_SCRIPT.new()
	registry.load_on_ready = false
	root.add_child(registry)
	_append(registry.load_anchor_document(anchors))
	var nodes: Dictionary = {}
	for binding_value: Variant in bindings.get("bindings", []):
		var binding := binding_value as Dictionary
		var node := ANCHORED_SCRIPT.new()
		node.object_id = str((binding["object_ref"] as Dictionary)["object_id"])
		node.anchor_id = str((binding["anchor_ref"] as Dictionary)["anchor_id"])
		node.expected_anchor_type = str((binding["anchor_ref"] as Dictionary)["expected_type"])
		node.placement = _placement_from_binding(binding)
		node.anchor_registry = registry
		nodes[node.object_id] = node
		root.add_child(node)
	await process_frame

	var expected := {
		"OBJ-U-MEDBAY-WALL-TERMINAL-01": Vector3(-86.382, 1.4, 11.16),
		"OBJ-U-MEDBAY-DOOR-BEACON-01": Vector3(-80.9, 1.2, 11.65),
		"OBJ-U-MEDBAY-FLOOR-CART-01": Vector3(-91.7896, 0.0, 9.1025),
	}
	for object_id: String in expected:
		var anchored := nodes[object_id] as Node3D
		_expect(anchored.global_position.is_equal_approx(expected[object_id]), "%s baseline transform" % object_id)
		_expect((anchored as AnchoredObject3D).get_anchor_errors().is_empty(), "%s baseline binding" % object_id)

	var free_object := Node3D.new()
	free_object.position = Vector3(-82.0, 0.4, 11.0)
	root.add_child(free_object)
	var free_before := free_object.global_transform
	var moved := anchors.duplicate(true)
	_shift_anchor(moved, "svg:u-medbay-wall-west-corridor:wall", Vector3(0.2, 0.0, 0.0))
	_shift_anchor(moved, "svg:u-medbay-door-external-east:door:threshold_inside", Vector3(0.0, 0.0, 0.3))
	_shift_anchor(moved, "svg:u-medbay-floor-procedure-room:floor", Vector3(0.5, 0.0, 0.0))
	moved["generation_id"] = "runtime-moved"
	_append(registry.load_anchor_document(moved))
	_append(registry.refresh_registered_objects())
	_expect((nodes["OBJ-U-MEDBAY-WALL-TERMINAL-01"] as Node3D).global_position.is_equal_approx(expected["OBJ-U-MEDBAY-WALL-TERMINAL-01"] + Vector3(0.2, 0, 0)), "wall object follows anchor")
	_expect((nodes["OBJ-U-MEDBAY-DOOR-BEACON-01"] as Node3D).global_position.is_equal_approx(expected["OBJ-U-MEDBAY-DOOR-BEACON-01"] + Vector3(0, 0, 0.3)), "door object follows anchor")
	_expect((nodes["OBJ-U-MEDBAY-FLOOR-CART-01"] as Node3D).global_position.is_equal_approx(expected["OBJ-U-MEDBAY-FLOOR-CART-01"] + Vector3(0.5, 0, 0)), "floor object follows anchor")
	_expect(free_object.global_transform.is_equal_approx(free_before), "free object remains fixed")

	var floor_node := nodes["OBJ-U-MEDBAY-FLOOR-CART-01"] as AnchoredObject3D
	var floor_before := floor_node.global_transform
	var missing := moved.duplicate(true)
	missing["anchors"] = (missing["anchors"] as Array).filter(func(frame: Variant) -> bool:
		return str((frame as Dictionary).get("anchor_id", "")) != floor_node.anchor_id
	)
	missing["generation_id"] = "runtime-missing"
	_append(registry.load_anchor_document(missing))
	var missing_errors: PackedStringArray = registry.refresh_registered_objects()
	_expect(not missing_errors.is_empty(), "removed anchor must block refresh")
	_expect(floor_node.global_transform.is_equal_approx(floor_before), "removed anchor must preserve transform")
	_expect(floor_node.anchor_id == "svg:u-medbay-floor-procedure-room:floor", "removed anchor ID must not be replaced")
	_finish()


func _placement_from_binding(binding: Dictionary) -> ComplexV3AnchorPlacement:
	var source := binding["placement"] as Dictionary
	var placement := PLACEMENT_SCRIPT.new()
	placement.mode = str(source["mode"])
	placement.normal_offset_m = float(source["normal_offset_m"])
	placement.height_m = float(source["height_m"])
	var rotation := (source["rotation"] as Dictionary)["yaw_pitch_roll"] as Array
	placement.yaw_pitch_roll_deg = Vector3(float(rotation[0]), float(rotation[1]), float(rotation[2]))
	placement.footprint_m = _vector3(binding["footprint_m"] as Array)
	placement.footprint_center_m = _vector3(binding["footprint_center_m"] as Array)
	if placement.mode == "linear":
		_apply_axis(placement, ((source["linear"] as Dictionary)["along"] as Dictionary))
	else:
		var surface := source["surface"] as Dictionary
		placement.surface_u = AXIS_SCRIPT.new()
		placement.surface_v = AXIS_SCRIPT.new()
		_apply_axis(placement.surface_u, surface["u"] as Dictionary)
		_apply_axis(placement.surface_v, surface["v"] as Dictionary)
	return placement


func _apply_axis(target: Resource, source: Dictionary) -> void:
	target.set("policy", str(source["policy"]))
	target.set("normalized_value", float(source.get("value", 0.5)))
	target.set("distance_m", float(source.get("distance_m", 0.0)))
	target.set("centered_offset_m", float(source.get("offset_m", 0.0)))


func _shift_anchor(document: Dictionary, anchor_id: String, delta: Vector3) -> void:
	for frame_value: Variant in document["anchors"]:
		var frame := frame_value as Dictionary
		if str(frame["anchor_id"]) == anchor_id:
			frame["origin"] = _array3(_vector3(frame["origin"] as Array) + delta)
			if (frame["bounds"] as Dictionary).has("polygon_xz"):
				for point: Array in (frame["bounds"] as Dictionary)["polygon_xz"]:
					point[0] = float(point[0]) + delta.x
					point[1] = float(point[1]) + delta.z
			return
	_errors.append("anchor not found for runtime mutation: %s" % anchor_id)


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_errors.append("invalid JSON object: %s" % path)
		return {}
	return parsed as Dictionary


func _count_valid_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D and (node as MeshInstance3D).mesh != null else 0
	for child: Node in node.get_children():
		count += _count_valid_meshes(child)
	return count


func _count_valid_collisions(node: Node) -> int:
	var count := 1 if node is CollisionShape3D and (node as CollisionShape3D).shape != null else 0
	for child: Node in node.get_children():
		count += _count_valid_collisions(child)
	return count


func _vector3(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _array3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _append(source: PackedStringArray) -> void:
	for item: String in source:
		_errors.append(item)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_errors.append(label)


func _finish() -> void:
	if _errors.is_empty():
		print("U_MEDBAY_RUNTIME_OK meshes>=50 collisions>=40 bindings=3 follow=wall,door,floor free=fixed missing=blocked")
	else:
		for error: String in _errors:
			push_error(error)
	quit(0 if _errors.is_empty() else 1)
