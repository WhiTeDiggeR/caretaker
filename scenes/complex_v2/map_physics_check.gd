extends SceneTree

const MAP_SCENE := preload("res://scenes/complex_v2/complex_v2.tscn")


func _initialize() -> void:
	var map := MAP_SCENE.instantiate()
	root.add_child(map)
	await physics_frame
	await physics_frame
	var errors := PackedStringArray()
	var player := map.get_node_or_null("Player") as CollisionObject3D
	var excluded: Array[RID] = []
	if player != null:
		excluded.append(player.get_rid())
	var space := root.get_world_3d().direct_space_state
	for child: Node in map.get_children():
		if not child is FacilityGridLevel:
			continue
		var level := child as FacilityGridLevel
		for local_sample: Vector3 in level.get_support_samples():
			var sample := level.to_global(local_sample)
			var query := PhysicsRayQueryParameters3D.create(
				sample + Vector3(0.0, 1.2, 0.0),
				sample - Vector3(0.0, 3.2, 0.0)
			)
			query.exclude = excluded
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				errors.append("%s: нет опоры под точкой %s" % [level.name, local_sample])
			elif (hit["normal"] as Vector3).y < 0.45:
				errors.append("%s: непроходимая опора под точкой %s" % [level.name, local_sample])
	var transitions := map.get_node_or_null("VerticalTransitions")
	if transitions != null and transitions.has_method("get_transition_support_samples"):
		for sample: Vector3 in transitions.get_transition_support_samples():
			var query := PhysicsRayQueryParameters3D.create(
				sample + Vector3(0.0, 1.5, 0.0),
				sample - Vector3(0.0, 2.0, 0.0)
			)
			query.exclude = excluded
			var hit := space.intersect_ray(query)
			if hit.is_empty() or (hit["normal"] as Vector3).y < 0.45:
				errors.append("VerticalTransitions: нет проходимой опоры под %s" % sample)
	if errors.is_empty():
		print("MAP_PHYSICS_OK")
	else:
		for error: String in errors:
			push_error(error)
	var ambience := map.get_node_or_null("FacilityAmbience") as AudioStreamPlayer
	if ambience != null:
		ambience.stop()
	map.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
