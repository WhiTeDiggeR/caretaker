extends SceneTree

const MAP_SCENE := preload("res://scenes/complex_v2/complex_v2.tscn")


func _initialize() -> void:
	var map := MAP_SCENE.instantiate()
	root.add_child(map)
	await process_frame
	var errors := PackedStringArray()
	for child: Node in map.get_children():
		if child is FacilityGridLevel:
			errors.append_array((child as FacilityGridLevel).validate_layout())
	if errors.is_empty():
		print("MAP_INTEGRITY_OK")
		_stop_ambience(map)
		map.queue_free()
		await process_frame
		quit(0)
		return
	for error: String in errors:
		push_error(error)
	_stop_ambience(map)
	map.queue_free()
	await process_frame
	quit(1)


func _stop_ambience(map: Node) -> void:
	var ambience := map.get_node_or_null("FacilityAmbience") as AudioStreamPlayer
	if ambience != null:
		ambience.stop()
