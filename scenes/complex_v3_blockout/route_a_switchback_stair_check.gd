extends SceneTree

const STAIR_SCENE := preload("res://objects/complex_v3/route_a_switchback_stair.tscn")


func _initialize() -> void:
	var stair := STAIR_SCENE.instantiate() as RouteASwitchbackStair
	root.add_child(stair)
	await process_frame
	await physics_frame
	var errors := stair.validate_geometry()
	var summary := stair.get_geometry_summary()
	if not is_equal_approx(float(summary.get("level_height", 0.0)), 6.0):
		errors.append("Route A stair must connect the 6 m level interval")
	if float(summary.get("flight_width", 0.0)) < 1.5:
		errors.append("Route A stair clear width is below the plan requirement")
	if not is_equal_approx(float(summary.get("tread_depth", 0.0)), 0.25):
		errors.append("Route A stair tread depth must fit the approved 7 m room")
	if not is_equal_approx(float(summary.get("footprint_width", 0.0)), 6.0) or not is_equal_approx(float(summary.get("footprint_depth", 0.0)), 7.0):
		errors.append("Route A stair footprint must remain inside its plan room")
	var collision_count := stair.find_children("*", "StaticBody3D", true, false).size()
	if collision_count < 55:
		errors.append("Route A stair is missing step, landing, wall, or railing collisions")
	if errors.is_empty():
		print("ROUTE_A_STAIR_OK risers=40 flights=2 shaft_walls=3 footprint=6.0x7.0 level_height=6.0 collisions=%d" % collision_count)
	else:
		for error: String in errors:
			push_error(error)
	stair.queue_free()
	await process_frame
	quit(0 if errors.is_empty() else 1)
