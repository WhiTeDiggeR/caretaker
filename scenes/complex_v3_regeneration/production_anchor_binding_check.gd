extends Node


func _ready() -> void:
	var errors := PackedStringArray()
	var control := _instantiate("res://scenes/complex_v3_blockout/zones/upper/u_control.tscn")
	if control == null:
		errors.append("cannot instantiate U-CONTROL")
		_finish(errors)
		return
	add_child(control)
	await get_tree().process_frame
	await get_tree().process_frame
	var controller := control.get_node("AnchorController") as ComplexV3SectorAnchorController
	errors.append_array(controller.apply_bindings())
	_expect(errors, controller.is_ready_for_use(), "U-CONTROL real authored bindings are ready")
	errors.append_array(controller.get_last_errors())
	var bindings := _load_json(controller.object_bindings_path)
	var anchors := _load_json(controller.anchor_frames_path)
	var wall_binding := _first_binding(bindings, "wall")
	var door_binding := _first_binding(bindings, "door")
	_expect(errors, not wall_binding.is_empty(), "U-CONTROL has a real wall binding")
	_expect(errors, not door_binding.is_empty(), "U-CONTROL has a real door binding")
	if errors.is_empty():
		var wall := _find_object(control.get_node("AuthoredContent"), str((wall_binding["object_ref"] as Dictionary)["object_id"]))
		var door := _find_object(control.get_node("AuthoredContent"), str((door_binding["object_ref"] as Dictionary)["object_id"]))
		var wall_before := wall.global_transform
		var door_before := door.global_transform
		wall.author_correction = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.2, 0.0))
		var moved := anchors.duplicate(true)
		moved["generation_id"] = "production-check:moved"
		_shift_anchor(moved, str((wall_binding["anchor_ref"] as Dictionary)["anchor_id"]), 0.5)
		_shift_anchor(moved, str((door_binding["anchor_ref"] as Dictionary)["anchor_id"]), 0.5)
		errors.append_array(controller.apply_documents(moved, bindings))
		_expect(errors, is_equal_approx(wall.global_position.x, wall_before.origin.x + 0.5), "real wall object follows moved wall frame")
		_expect(errors, is_equal_approx(door.global_position.x, door_before.origin.x + 0.5), "real door frame follows moved door anchor")
		_expect(errors, wall.author_correction.origin.is_equal_approx(Vector3(0.0, 0.2, 0.0)), "real object author correction is retained")
		var before_missing := wall.global_transform
		var removed := moved.duplicate(true)
		removed["generation_id"] = "production-check:removed"
		_remove_anchor(removed, str((wall_binding["anchor_ref"] as Dictionary)["anchor_id"]))
		var removed_errors := controller.apply_documents(removed, bindings)
		_expect(errors, _contains(removed_errors, "missing anchor_id"), "real removed anchor is blocking")
		_expect(errors, wall.global_transform.is_equal_approx(before_missing), "real object is not silently rebound")
	control.queue_free()

	var medbay := _instantiate("res://scenes/complex_v3_blockout/zones/upper/u_medbay.tscn")
	if medbay == null:
		errors.append("cannot instantiate U-MEDBAY")
	else:
		add_child(medbay)
		await get_tree().process_frame
		await get_tree().process_frame
		var free_object := _first_anchored(medbay.get_node("AuthoredContent"))
		var free_before := free_object.global_transform
		var medbay_controller := medbay.get_node("AnchorController") as ComplexV3SectorAnchorController
		errors.append_array(medbay_controller.apply_bindings())
		_expect(errors, free_object.global_transform.is_equal_approx(free_before), "unbound production authored object remains unchanged")
		medbay.queue_free()
	_finish(errors)


func _instantiate(path: String) -> Node3D:
	var packed := load(path) as PackedScene
	return packed.instantiate() as Node3D if packed != null else null


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	return parsed as Dictionary if parsed is Dictionary else {}


func _first_binding(document: Dictionary, expected_type: String) -> Dictionary:
	for value: Variant in document.get("bindings", []):
		var binding := value as Dictionary
		if str((binding.get("anchor_ref", {}) as Dictionary).get("expected_type", "")) == expected_type:
			return binding
	return {}


func _find_object(root: Node, object_id: String) -> AnchoredObject3D:
	for child: Node in root.get_children():
		if child is AnchoredObject3D and (child as AnchoredObject3D).object_id == object_id:
			return child as AnchoredObject3D
		var nested := _find_object(child, object_id)
		if nested != null:
			return nested
	return null


func _first_anchored(root: Node) -> AnchoredObject3D:
	for child: Node in root.get_children():
		if child is AnchoredObject3D:
			return child as AnchoredObject3D
		var nested := _first_anchored(child)
		if nested != null:
			return nested
	return null


func _shift_anchor(document: Dictionary, anchor_id: String, delta_x: float) -> void:
	for value: Variant in document["anchors"]:
		var frame := value as Dictionary
		if str(frame["anchor_id"]) == anchor_id:
			(frame["origin"] as Array)[0] = float((frame["origin"] as Array)[0]) + delta_x
			return


func _remove_anchor(document: Dictionary, anchor_id: String) -> void:
	var anchors := document["anchors"] as Array
	for index: int in range(anchors.size() - 1, -1, -1):
		if str((anchors[index] as Dictionary)["anchor_id"]) == anchor_id:
			anchors.remove_at(index)


func _contains(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false


func _expect(errors: PackedStringArray, condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)


func _finish(errors: PackedStringArray) -> void:
	if errors.is_empty():
		print("COMPLEX_V3_PRODUCTION_ANCHOR_BINDINGS_OK")
		get_tree().quit(0)
	else:
		for error: String in errors:
			push_error(error)
		get_tree().quit(1)
