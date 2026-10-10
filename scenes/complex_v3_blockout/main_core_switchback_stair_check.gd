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
	if absf(float(summary.get("wall_side_gap", 1.0))) > 0.001:
		errors.append("Stair has a fall gap between treads and side walls")
	if not is_equal_approx(float(summary.get("upper_guard_span", 0.0)), 3.85):
		errors.append("Upper guard must span from the inner stair rail to the east wall")
	var collision_count := stair.find_children("*", "StaticBody3D", true, false).size()
	if collision_count < 70:
		errors.append("Runtime stair is missing wall, step, landing, or guard collisions")
	if errors.is_empty():
		print("MAIN_CORE_STAIR_OK risers=40 landings=3 flight_rails=2 upper_guard=1 shaft_walls=3 upper_closure=0 wall_side_gap=0.0 level_height=6.0 collisions=%d" % collision_count)
	else:
		for error: String in errors:
			push_error(error)
	stair.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
