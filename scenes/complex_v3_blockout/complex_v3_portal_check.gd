extends SceneTree

const BLOCKOUT_SCENE := preload("res://scenes/complex_v3_blockout/complex_v3_blockout.tscn")


func _initialize() -> void:
	var blockout := BLOCKOUT_SCENE.instantiate() as ComplexV3Blockout
	blockout.include_ceilings = false
	root.add_child(blockout)
	await physics_frame
	await physics_frame
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var space := root.get_world_3d().direct_space_state
	var errors := PackedStringArray()
	var checked := 0
	for passage: Dictionary in blockout.get_portal_passages():
		var half_depth := float(passage.get("test_half_depth", 0.8))
		for step: int in 5:
			var distance := -half_depth + float(step) * half_depth * 0.5
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform = Transform3D(Basis.IDENTITY, passage["center"] + passage["direction"] * distance)
			query.collide_with_areas = false
			var hits := space.intersect_shape(query, 32)
			var blocker: Node = null
			for hit: Dictionary in hits:
				var candidate := hit["collider"] as Node
				if candidate != null and candidate.name != "Floor" and not str(candidate.get_path()).contains("VT-OLD-INCLINE"):
					blocker = candidate
					break
			if blocker != null:
				errors.append("%s blocked by %s" % [passage["id"], blocker.get_path()])
				break
		checked += 1
	if errors.is_empty():
		print("COMPLEX_V3_PORTALS_OK checked=%d" % checked)
	else:
		for error: String in errors:
			push_error(error)
	blockout.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
