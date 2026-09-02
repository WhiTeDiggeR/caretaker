extends SceneTree

const FIXTURE := preload("res://scenes/complex_v3_blockout/fixtures/sector_wrapper_fixture.tscn")


func _initialize() -> void:
	var errors := PackedStringArray()
	var wrapper: Variant = FIXTURE.instantiate()
	root.add_child(wrapper)
	await process_frame
	for error: String in wrapper.validate_regeneration_contract(true):
		errors.append(error)
	var authored := wrapper.get_node_or_null("AuthoredContent") as Node3D
	if authored == null:
		errors.append("Fixture did not instantiate AuthoredContent")
	else:
		var authored_id := authored.get_instance_id()
		var authored_scene_path := authored.scene_file_path
		var marker := authored.get_node_or_null("ManualMarker") as Marker3D
		var marker_position := marker.position if marker != null else Vector3.ZERO
		var generated: Node = wrapper.get_node_or_null("Generated")
		if generated == null:
			errors.append("Fixture did not instantiate Generated")
		else:
			generated.free()
		if wrapper.get_node_or_null("AuthoredContent") != authored:
			errors.append("Deleting Generated changed AuthoredContent")
		for error: String in wrapper.rebuild_contract_generated():
			errors.append(error)
		if wrapper.get_node_or_null("AuthoredContent") != authored or authored.get_instance_id() != authored_id:
			errors.append("Generated rebuild replaced AuthoredContent")
		if authored.scene_file_path != authored_scene_path or authored_scene_path.is_empty():
			errors.append("AuthoredContent is not preserved as a separate resource")
		if marker == null or marker.position != marker_position or str(marker.get_meta("object_id", "")) != "OBJ-FIXTURE-MANUAL-MARKER":
			errors.append("Generated rebuild changed authored marker data")
		var rebuilt: Node = wrapper.get_node_or_null("Generated")
		if rebuilt == null or rebuilt.get_node_or_null("Architecture") == null or rebuilt.get_node_or_null("Stairs") == null:
			errors.append("Generated rebuild did not restore Architecture and Stairs layers")
	for error: String in wrapper.rebuild_contract_editor_preview():
		errors.append(error)
	var preview: Node = wrapper.get_node_or_null("EditorPreview")
	if preview == null:
		errors.append("EditorPreview was not built")
	elif preview.owner != null:
		errors.append("EditorPreview must remain transient and unserializable")
	elif not preview.find_children("*", "CollisionObject3D", true, false).is_empty() or not preview.find_children("*", "CollisionShape3D", true, false).is_empty():
		errors.append("EditorPreview contains collision")
	if authored != null and authored.find_child("EditorPreview", true, false) != null:
		errors.append("EditorPreview leaked into AuthoredContent")
	if errors.is_empty():
		print("COMPLEX_V3_SECTOR_WRAPPER_CONTRACT_OK generated=replaceable authored=preserved preview=transient_collision_free")
	else:
		for error: String in errors:
			push_error(error)
	wrapper.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
