extends SceneTree

const ASSEMBLY_SCENE := preload("res://scenes/complex_v3_blockout/review/u_emergency_plan_assembly.tscn")


func _initialize() -> void:
	var assembly := ASSEMBLY_SCENE.instantiate()
	root.add_child(assembly)
	await process_frame
	await process_frame
	var errors := PackedStringArray()
	var zones := assembly.get_node_or_null("Zones")
	if zones == null or zones.get_child_count() != 3:
		errors.append("Plan assembly must instance exactly three upper zones")
	else:
		for zone_name: String in ["U_EMERGENCY", "U_MEDBAY", "U_ROUTE_A"]:
			var zone := zones.get_node_or_null(zone_name)
			if zone == null or zone.get_node_or_null("Generated") == null:
				errors.append("Missing generated zone in plan assembly: %s" % zone_name)
	var infrastructure := assembly.get_node_or_null("Infrastructure") as ComplexV3BlockoutPart
	if infrastructure == null:
		errors.append("Plan assembly infrastructure is missing")
	else:
		var stats := infrastructure.get_build_stats()
		var expected := {"route_spaces": 1, "corridors": 1, "anchors": 1, "transitions": 1}
		for key: String in expected:
			if int(stats.get(key, -1)) != int(expected[key]):
				errors.append("Expected %d %s, built %d" % [int(expected[key]), key, int(stats.get(key, -1))])
		for error: String in infrastructure.validate_against_handoff():
			errors.append("Infrastructure: %s" % error)
		var seam_mesh_instance := infrastructure.get_node_or_null("Generated/Connections/C-E-U02/Floor/Mesh") as MeshInstance3D
		var seam_mesh := seam_mesh_instance.mesh as BoxMesh if seam_mesh_instance != null else null
		if seam_mesh == null or seam_mesh.size.x < 3.95:
			errors.append("E-U02 connector floor does not close the full wall seam")
		if infrastructure.get_node_or_null("Generated/Connections/C-E-U02A") != null:
			errors.append("E-U02A must be a shared doorway, not a bridge between detached sectors")
		if infrastructure.find_children("RouteASwitchbackStair", "", true, false).is_empty():
			errors.append("Route A stair is missing from plan assembly")
	if errors.is_empty():
		print("U_EMERGENCY_PLAN_ASSEMBLY_OK zones=3 route_spaces=1 corridors=1 anchors=1 transitions=1")
	else:
		for error: String in errors:
			push_error(error)
	assembly.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
