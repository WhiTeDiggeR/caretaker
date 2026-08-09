extends SceneTree

const BLOCKOUT_SCENE := preload("res://scenes/complex_v3_blockout/complex_v3_blockout.tscn")


func _initialize() -> void:
	var blockout := BLOCKOUT_SCENE.instantiate() as ComplexV3Blockout
	root.add_child(blockout)
	await process_frame
	await physics_frame
	var errors := blockout.validate_against_handoff()
	var stats := blockout.get_build_stats()
	var stair := blockout.find_child("MainCoreSwitchbackStair", true, false) as MainCoreSwitchbackStair
	if stair == null:
		errors.append("Full assembly is missing the separate main-core stair scene")
	else:
		for stair_error: String in stair.validate_geometry():
			errors.append("Main-core stair: %s" % stair_error)
	var east_stair := blockout.find_child("EastEmergencySwitchbackStair", true, false) as EastEmergencySwitchbackStair
	if east_stair == null:
		errors.append("Full assembly is missing the east emergency stair scene")
	else:
		for stair_error: String in east_stair.validate_geometry():
			errors.append("East emergency stair: %s" % stair_error)
	var connections := blockout.get_node_or_null("Infrastructure/Generated/Connections")
	if connections == null:
		errors.append("Full assembly is missing generated connection geometry")
	else:
		for connection: Node in connections.get_children():
			var segment_length := float(connection.get_meta("segment_length", 0.0))
			if bool(connection.get_meta("seam_floor", false)) and segment_length > 1.05:
				errors.append("Long floor-only bridge remains: %s (%.2f m)" % [connection.name, segment_length])
			if bool(connection.get_meta("enclosed", false)):
				for required_node: String in ["Floor", "WallLeft", "WallRight", "Ceiling"]:
					if connection.get_node_or_null(required_node) == null:
						errors.append("Enclosed connector %s is missing %s" % [connection.name, required_node])
		for forbidden_bridge: String in ["C-E-U06", "C-E-X05", "C-E-L02", "C-E-L15", "C-E-T03", "C-E-T08"]:
			if not connections.find_children("%s*" % forbidden_bridge, "", false, false).is_empty():
				errors.append("Redundant bridge geometry remains for %s" % forbidden_bridge)
		for enclosed_connection: String in ["C-E-U02", "C-E-U07", "C-E-U08", "C-E-U09", "C-E-U10", "C-E-L04", "C-E-L05", "C-E-L06", "C-E-L07", "C-E-L08", "C-E-L11", "T-TRANS-WEST", "T-TRANS-EAST"]:
			var matches := connections.find_children("%s*" % enclosed_connection, "", false, false)
			if matches.is_empty() or not bool(matches[0].get_meta("enclosed", false)):
				errors.append("Required enclosed connector is missing: %s" % enclosed_connection)
		var hall_store_connector := connections.get_node_or_null("C-E-U02")
		if hall_store_connector != null:
			var floor_mesh_instance := hall_store_connector.get_node_or_null("Floor/Mesh") as MeshInstance3D
			var floor_mesh := floor_mesh_instance.mesh as BoxMesh if floor_mesh_instance != null else null
			if floor_mesh == null or not is_equal_approx(floor_mesh.size.x, 1.2) or not is_equal_approx(floor_mesh.size.z, 0.5):
				errors.append("Hall-to-store connector must be a 1.2 x 0.5 m enclosed doorway")
	if int(stats.get("ceilings", 0)) != int(stats.get("floors", 0)):
		errors.append("Runtime blockout must preserve one ceiling per generated floor")
	if errors.is_empty():
		print("COMPLEX_V3_BLOCKOUT_OK spaces=%d routes=%d anchors=%d transitions=%d floors=%d ceilings=%d walls=%d colliders=%d" % [
			int(stats["spaces"]),
			int(stats["route_spaces"]),
			int(stats["anchors"]),
			int(stats["transitions"]),
			int(stats["floors"]),
			int(stats["ceilings"]),
			int(stats["walls"]),
			int(stats["colliders"]),
		])
		blockout.queue_free()
		await process_frame
		quit(0)
		return
	for error: String in errors:
		push_error(error)
	blockout.queue_free()
	await process_frame
	quit(1)
