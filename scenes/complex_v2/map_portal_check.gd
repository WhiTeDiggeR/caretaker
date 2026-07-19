extends SceneTree

const MAP_SCENE := preload("res://scenes/complex_v2/complex_v2.tscn")


func _initialize() -> void:
	var map := MAP_SCENE.instantiate()
	root.add_child(map)
	var player := map.get_node_or_null("Player")
	if player != null:
		player.queue_free()
	await physics_frame
	await physics_frame
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var space := root.get_world_3d().direct_space_state
	var errors := PackedStringArray()
	for child: Node in map.get_children():
		if not child is FacilityGridLevel:
			continue
		var level := child as FacilityGridLevel
		for passage: Dictionary in level.get_portal_passages():
			for step: int in 7:
				var distance := -1.5 + float(step) * 0.5
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.transform = Transform3D(Basis.IDENTITY, passage["center"] + passage["direction"] * distance + Vector3(0.0, 1.35, 0.0))
				query.collide_with_areas = false
				var hits := space.intersect_shape(query, 32)
				var collider: Node = null
				for hit: Dictionary in hits:
					var candidate := hit["collider"] as Node
					if candidate != null and not candidate.is_in_group("interactable_doors"):
						collider = candidate
						break
				if collider != null:
					errors.append("%s: проход %s заблокирован объектом %s" % [
						level.name, passage["name"], collider.get_path()
					])
					break
	if errors.is_empty():
		print("MAP_PORTALS_OK")
	else:
		for error: String in errors:
			push_error(error)
	var ambience := map.get_node_or_null("FacilityAmbience") as AudioStreamPlayer
	if ambience != null:
		ambience.stop()
	map.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
