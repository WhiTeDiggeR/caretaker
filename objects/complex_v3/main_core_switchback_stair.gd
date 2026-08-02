@tool
extends Node3D
class_name MainCoreSwitchbackStair

const UTILITY_PANELS := preload("res://materials/complex_v3/utility_panels.tres")

const LEVEL_HEIGHT := 6.0
const FLIGHT_WIDTH := 1.8
const TREAD_DEPTH := 0.3
const RISER_HEIGHT := 0.15
const RISERS_PER_FLIGHT := 20
const OPENING_WIDTH := 5.9
const OPENING_DEPTH := 9.0
const OPENING_NORTH := -5.25
const OPENING_SOUTH := 3.75
const RUN_NORTH := -3.75
const RUN_SOUTH := 2.25
const WEST_FLIGHT_X := -1.8
const EAST_FLIGHT_X := 1.8
const LANDING_DEPTH := 1.5
const SLAB_THICKNESS := 0.12
const RAIL_HEIGHT := 0.95
const WALL_THICKNESS := 0.24
const SHAFT_TOP := 3.4
const ENTRY_HEIGHT := 3.4

@export var build_collisions := true
@export var editor_preview_enabled := true:
	set(value):
		editor_preview_enabled = value
		if Engine.is_editor_hint() and is_inside_tree():
			_rebuild.call_deferred()

var _rail_material: StandardMaterial3D


func _ready() -> void:
	if not Engine.is_editor_hint() or editor_preview_enabled:
		_rebuild()


func _rebuild() -> void:
	var existing := get_node_or_null("Generated")
	if existing != null:
		existing.free()
	if Engine.is_editor_hint() and not editor_preview_enabled:
		return
	_rail_material = StandardMaterial3D.new()
	_rail_material.albedo_color = Color(0.09, 0.14, 0.17, 1.0)
	_rail_material.metallic = 0.55
	_rail_material.roughness = 0.42
	var generated := Node3D.new()
	generated.name = "Generated"
	generated.set_meta("top_floor_y", 0.0)
	generated.set_meta("lower_floor_y", -LEVEL_HEIGHT)
	generated.set_meta("opening_xz", [-OPENING_WIDTH * 0.5, OPENING_NORTH, OPENING_WIDTH * 0.5, OPENING_SOUTH])
	add_child(generated)
	_build_shaft(generated)
	_build_decks(generated)
	_build_flights(generated)
	_build_railings(generated)


func _build_shaft(parent: Node3D) -> void:
	var shaft_bottom := -LEVEL_HEIGHT - SLAB_THICKNESS
	var shaft_height := SHAFT_TOP - shaft_bottom
	var shaft_y := shaft_bottom + shaft_height * 0.5
	var wall_x := OPENING_WIDTH * 0.5 + WALL_THICKNESS * 0.5
	var wall_z := OPENING_NORTH - WALL_THICKNESS * 0.5
	_add_box(parent, "ShaftWallWest", Vector3(-wall_x, shaft_y, (OPENING_NORTH + OPENING_SOUTH) * 0.5), Vector3(WALL_THICKNESS, shaft_height, OPENING_DEPTH + WALL_THICKNESS * 2.0), UTILITY_PANELS, _collisions_enabled())
	_add_box(parent, "ShaftWallEast", Vector3(wall_x, shaft_y, (OPENING_NORTH + OPENING_SOUTH) * 0.5), Vector3(WALL_THICKNESS, shaft_height, OPENING_DEPTH + WALL_THICKNESS * 2.0), UTILITY_PANELS, _collisions_enabled())
	_add_box(parent, "ShaftWallNorth", Vector3(0.0, shaft_y, wall_z), Vector3(OPENING_WIDTH, shaft_height, WALL_THICKNESS), UTILITY_PANELS, _collisions_enabled())
	_build_south_entry_walls(parent)


func _build_south_entry_walls(parent: Node3D) -> void:
	var wall_z := OPENING_SOUTH + WALL_THICKNESS * 0.5
	var west_entry_min := WEST_FLIGHT_X - FLIGHT_WIDTH * 0.5
	var west_entry_max := WEST_FLIGHT_X + FLIGHT_WIDTH * 0.5
	var east_entry_min := EAST_FLIGHT_X - FLIGHT_WIDTH * 0.5
	var east_entry_max := EAST_FLIGHT_X + FLIGHT_WIDTH * 0.5
	_add_wall_segment_x(parent, "UpperSouthWallWest", -OPENING_WIDTH * 0.5, west_entry_min, SHAFT_TOP - ENTRY_HEIGHT, SHAFT_TOP, wall_z)
	_add_wall_segment_x(parent, "UpperSouthWallEast", west_entry_max, OPENING_WIDTH * 0.5, SHAFT_TOP - ENTRY_HEIGHT, SHAFT_TOP, wall_z)
	_add_wall_segment_x(parent, "SouthWallMidBand", -OPENING_WIDTH * 0.5, OPENING_WIDTH * 0.5, -LEVEL_HEIGHT + ENTRY_HEIGHT, 0.0, wall_z)
	_add_wall_segment_x(parent, "LowerSouthWallWest", -OPENING_WIDTH * 0.5, east_entry_min, -LEVEL_HEIGHT, -LEVEL_HEIGHT + ENTRY_HEIGHT, wall_z)
	_add_wall_segment_x(parent, "LowerSouthWallEast", east_entry_max, OPENING_WIDTH * 0.5, -LEVEL_HEIGHT, -LEVEL_HEIGHT + ENTRY_HEIGHT, wall_z)


func _add_wall_segment_x(parent: Node3D, node_name: String, x_min: float, x_max: float, y_min: float, y_max: float, z: float) -> void:
	if x_max - x_min <= 0.01 or y_max - y_min <= 0.01:
		return
	_add_box(parent, node_name, Vector3((x_min + x_max) * 0.5, (y_min + y_max) * 0.5, z), Vector3(x_max - x_min, y_max - y_min, WALL_THICKNESS), UTILITY_PANELS, _collisions_enabled())


func _build_decks(parent: Node3D) -> void:
	_add_box(parent, "UpperLanding", Vector3(0.0, -SLAB_THICKNESS * 0.5, RUN_SOUTH + LANDING_DEPTH * 0.5), Vector3(OPENING_WIDTH, SLAB_THICKNESS, LANDING_DEPTH), UTILITY_PANELS, _collisions_enabled())
	var upper_closure_x_min := WEST_FLIGHT_X + FLIGHT_WIDTH * 0.5
	_add_box(parent, "UpperRightClosure", Vector3((upper_closure_x_min + OPENING_WIDTH * 0.5) * 0.5, -SLAB_THICKNESS * 0.5, (RUN_NORTH + RUN_SOUTH) * 0.5), Vector3(OPENING_WIDTH * 0.5 - upper_closure_x_min, SLAB_THICKNESS, RUN_SOUTH - RUN_NORTH), UTILITY_PANELS, _collisions_enabled())
	_add_box(parent, "IntermediateLanding", Vector3(0.0, -LEVEL_HEIGHT * 0.5 - SLAB_THICKNESS * 0.5, OPENING_NORTH + LANDING_DEPTH * 0.5), Vector3(OPENING_WIDTH, SLAB_THICKNESS, LANDING_DEPTH), UTILITY_PANELS, _collisions_enabled())
	_add_box(parent, "LowerLandingDeck", Vector3(0.0, -LEVEL_HEIGHT - SLAB_THICKNESS * 0.5, (OPENING_NORTH + OPENING_SOUTH) * 0.5), Vector3(OPENING_WIDTH, SLAB_THICKNESS, OPENING_DEPTH), UTILITY_PANELS, _collisions_enabled())


func _build_flights(parent: Node3D) -> void:
	var intermediate_y := -LEVEL_HEIGHT * 0.5
	var lower_y := -LEVEL_HEIGHT
	for index: int in range(RISERS_PER_FLIGHT):
		var west_top := -RISER_HEIGHT * index
		var west_z := RUN_SOUTH - TREAD_DEPTH * (index + 0.5)
		_add_box(parent, "WestFlight_%02d" % index, Vector3(WEST_FLIGHT_X, west_top - RISER_HEIGHT * 0.5, west_z), Vector3(FLIGHT_WIDTH, RISER_HEIGHT, TREAD_DEPTH), UTILITY_PANELS, _collisions_enabled())
		var east_top := intermediate_y - RISER_HEIGHT * index
		var east_z := RUN_NORTH + TREAD_DEPTH * (index + 0.5)
		_add_box(parent, "EastFlight_%02d" % index, Vector3(EAST_FLIGHT_X, east_top - RISER_HEIGHT * 0.5, east_z), Vector3(FLIGHT_WIDTH, RISER_HEIGHT, TREAD_DEPTH), UTILITY_PANELS, _collisions_enabled())
	var stringer_index := 0
	for stringer_offset: float in [-0.55, 0.55]:
		_add_sloped_box(parent, "WestStringer_%02d" % stringer_index, Vector3(WEST_FLIGHT_X + stringer_offset, -0.24, RUN_SOUTH), Vector3(WEST_FLIGHT_X + stringer_offset, intermediate_y - 0.24, RUN_NORTH), 0.22, UTILITY_PANELS)
		_add_sloped_box(parent, "EastStringer_%02d" % stringer_index, Vector3(EAST_FLIGHT_X + stringer_offset, intermediate_y - 0.24, RUN_NORTH), Vector3(EAST_FLIGHT_X + stringer_offset, lower_y - 0.24, RUN_SOUTH), 0.22, UTILITY_PANELS)
		stringer_index += 1


func _build_railings(parent: Node3D) -> void:
	var intermediate_y := -LEVEL_HEIGHT * 0.5
	var lower_y := -LEVEL_HEIGHT
	var west_rail_x := WEST_FLIGHT_X + FLIGHT_WIDTH * 0.5
	var east_rail_x := EAST_FLIGHT_X - FLIGHT_WIDTH * 0.5
	_add_bar(parent, "WestFlightRail_00", Vector3(west_rail_x, RAIL_HEIGHT, RUN_SOUTH), Vector3(west_rail_x, intermediate_y + RAIL_HEIGHT, RUN_NORTH), 0.10, _collisions_enabled())
	_add_bar(parent, "WestFlightMidRail", Vector3(west_rail_x, RAIL_HEIGHT * 0.55, RUN_SOUTH), Vector3(west_rail_x, intermediate_y + RAIL_HEIGHT * 0.55, RUN_NORTH), 0.08, _collisions_enabled())
	_add_bar(parent, "EastFlightRail_00", Vector3(east_rail_x, intermediate_y + RAIL_HEIGHT, RUN_NORTH), Vector3(east_rail_x, lower_y + RAIL_HEIGHT, RUN_SOUTH), 0.10, _collisions_enabled())
	_add_bar(parent, "EastFlightMidRail", Vector3(east_rail_x, intermediate_y + RAIL_HEIGHT * 0.55, RUN_NORTH), Vector3(east_rail_x, lower_y + RAIL_HEIGHT * 0.55, RUN_SOUTH), 0.08, _collisions_enabled())
	for index: int in range(0, RISERS_PER_FLIGHT + 1, 5):
		var west_t := float(index) / float(RISERS_PER_FLIGHT)
		var west_z := lerpf(RUN_SOUTH, RUN_NORTH, west_t)
		var west_y := lerpf(0.0, intermediate_y, west_t)
		_add_box(parent, "WestPost_%02d" % index, Vector3(west_rail_x, west_y + RAIL_HEIGHT * 0.5, west_z), Vector3(0.10, RAIL_HEIGHT, 0.10), _rail_material, _collisions_enabled())
		var east_z := lerpf(RUN_NORTH, RUN_SOUTH, west_t)
		var east_y := lerpf(intermediate_y, lower_y, west_t)
		_add_box(parent, "EastPost_%02d" % index, Vector3(east_rail_x, east_y + RAIL_HEIGHT * 0.5, east_z), Vector3(0.10, RAIL_HEIGHT, 0.10), _rail_material, _collisions_enabled())
	_add_landing_guard(parent, intermediate_y)


func _add_landing_guard(parent: Node3D, landing_y: float) -> void:
	var x_min := WEST_FLIGHT_X + FLIGHT_WIDTH * 0.5
	var x_max := EAST_FLIGHT_X - FLIGHT_WIDTH * 0.5
	var guard_z := RUN_NORTH
	_add_bar(parent, "IntermediateGapTopRail", Vector3(x_min, landing_y + RAIL_HEIGHT, guard_z), Vector3(x_max, landing_y + RAIL_HEIGHT, guard_z), 0.10, _collisions_enabled())
	_add_bar(parent, "IntermediateGapMidRail", Vector3(x_min, landing_y + RAIL_HEIGHT * 0.55, guard_z), Vector3(x_max, landing_y + RAIL_HEIGHT * 0.55, guard_z), 0.08, _collisions_enabled())
	for index: int in range(3):
		var rail_x := lerpf(x_min, x_max, float(index) * 0.5)
		_add_box(parent, "IntermediateGapPost_%02d" % index, Vector3(rail_x, landing_y + RAIL_HEIGHT * 0.5, guard_z), Vector3(0.10, RAIL_HEIGHT, 0.10), _rail_material, _collisions_enabled())


func validate_geometry() -> PackedStringArray:
	var errors := PackedStringArray()
	var generated := get_node_or_null("Generated")
	if generated == null:
		errors.append("Stair scene did not build Generated")
		return errors
	if generated.find_children("WestFlight_*", "", true, false).size() != RISERS_PER_FLIGHT:
		errors.append("West flight must contain %d risers" % RISERS_PER_FLIGHT)
	if generated.find_children("EastFlight_*", "", true, false).size() != RISERS_PER_FLIGHT:
		errors.append("East flight must contain %d risers" % RISERS_PER_FLIGHT)
	if generated.find_children("*FlightRail_*", "", true, false).size() != 2:
		errors.append("Stair must contain two open-edge handrails; wall-side rails are redundant")
	for required_name: String in ["UpperLanding", "UpperRightClosure", "IntermediateLanding", "LowerLandingDeck", "ShaftWallWest", "ShaftWallEast", "ShaftWallNorth", "UpperSouthWallWest", "UpperSouthWallEast", "SouthWallMidBand", "LowerSouthWallWest", "LowerSouthWallEast", "IntermediateGapTopRail"]:
		if generated.find_children(required_name, "", true, false).is_empty():
			errors.append("Missing required stair component: %s" % required_name)
	return errors


func get_geometry_summary() -> Dictionary:
	return {
		"level_height": LEVEL_HEIGHT,
		"flight_width": FLIGHT_WIDTH,
		"riser_height": RISER_HEIGHT,
		"tread_depth": TREAD_DEPTH,
		"risers_per_flight": RISERS_PER_FLIGHT,
		"opening_width": OPENING_WIDTH,
		"opening_depth": OPENING_DEPTH,
	}


func _collisions_enabled() -> bool:
	return build_collisions and not Engine.is_editor_hint()


func _add_bar(parent: Node3D, node_name: String, start: Vector3, end: Vector3, thickness: float, collision: bool = false) -> void:
	_add_sloped_box(parent, node_name, start, end, thickness, _rail_material, collision)


func _add_sloped_box(parent: Node3D, node_name: String, start: Vector3, end: Vector3, thickness: float, material: Material, collision: bool = false) -> void:
	var delta := end - start
	var length := delta.length()
	if length <= 0.01:
		return
	var direction := delta.normalized()
	var side := Vector3.UP.cross(direction).normalized()
	if side.length() <= 0.01:
		side = Vector3.RIGHT
	var up := direction.cross(side).normalized()
	_add_oriented_box(parent, node_name, Transform3D(Basis(side, up, direction), (start + end) * 0.5), Vector3(thickness, thickness, length), material, collision)


func _add_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3, material: Material, collision: bool) -> void:
	_add_oriented_box(parent, node_name, Transform3D(Basis.IDENTITY, center), size, material, collision)


func _add_oriented_box(parent: Node3D, node_name: String, box_transform: Transform3D, size: Vector3, material: Material, collision: bool) -> void:
	var root: Node3D
	if collision:
		root = StaticBody3D.new()
	else:
		root = Node3D.new()
	root.name = node_name
	root.transform = box_transform
	parent.add_child(root)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	root.add_child(mesh_instance)
	if collision:
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "Collision"
		var shape := BoxShape3D.new()
		shape.size = size
		collision_shape.shape = shape
		root.add_child(collision_shape)
