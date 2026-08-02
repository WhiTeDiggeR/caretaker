extends SceneTree

const STAIR_SCENE := preload("res://objects/complex_v3/main_core_switchback_stair.tscn")


func _initialize() -> void:
	var stair := STAIR_SCENE.instantiate() as MainCoreSwitchbackStair
	root.add_child(stair)
	await process_frame
	await physics_frame
	var errors := stair.validate_geometry()
	var summary := stair.get_geometry_summary()
	if not is_equal_approx(float(summary.get("level_height", 0.0)), 6.0):
		errors.append("Stair must connect the 6 m central-core level interval")
	if float(summary.get("flight_width", 0.0)) < 1.2:
		errors.append("Stair clear flight width is below the traversal minimum")
	var collision_count := stair.find_children("*", "StaticBody3D", true, false).size()
	if collision_count < 65:
		errors.append("Runtime stair is missing wall, closure, step, landing, or guard collisions")
	if errors.is_empty():
		print("MAIN_CORE_STAIR_OK risers=40 landings=3 rails=2 shaft_walls=8 upper_closure=1 level_height=6.0 collisions=%d" % collision_count)
	else:
		for error: String in errors:
			push_error(error)
	stair.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
