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
