extends SceneTree

const BLOCKOUT_SCENE := preload("res://scenes/complex_v3_blockout/complex_v3_blockout.tscn")


func _initialize() -> void:
	var blockout := BLOCKOUT_SCENE.instantiate() as ComplexV3Blockout
	root.add_child(blockout)
	await process_frame
	await physics_frame
	var errors := blockout.validate_against_handoff()
	var stats := blockout.get_build_stats()
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
