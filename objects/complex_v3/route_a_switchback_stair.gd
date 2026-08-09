@tool
extends Node3D
class_name RouteASwitchbackStair

const UTILITY_PANELS := preload("res://materials/complex_v3/utility_panels.tres")

const LEVEL_HEIGHT := 6.0
const FLIGHT_WIDTH := 1.5
const FLIGHT_CENTER_X := 1.1
const TREAD_DEPTH := 0.25
const RISER_HEIGHT := 0.15
const RISERS_PER_FLIGHT := 20
const RUN_NORTH := -3.5
const RUN_SOUTH := 1.5
const LANDING_DEPTH := 2.0
const SLAB_THICKNESS := 0.12
const RAIL_HEIGHT := 0.95
const WALL_THICKNESS := 0.24
const SHAFT_HALF_WIDTH := 3.0
const SHAFT_TOP := 3.4
const UPPER_APPROACH_WALL_EDGE_X := 2.6
const UPPER_SIDE_THRESHOLD_DEPTH := 1.5

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
	generated.set_meta("anchor_id", "A-ROUTE-A")
	add_child(generated)
	_build_shaft(generated)
	_build_landings(generated)
	_build_flights(generated)
	_build_railings(generated)


func _build_shaft(parent: Node3D) -> void:
	var shaft_bottom := -LEVEL_HEIGHT - SLAB_THICKNESS
	var shaft_height := SHAFT_TOP - shaft_bottom
	var shaft_y := shaft_bottom + shaft_height * 0.5
	var wall_x := SHAFT_HALF_WIDTH + WALL_THICKNESS * 0.5
	var wall_z := RUN_SOUTH + LANDING_DEPTH + WALL_THICKNESS * 0.5
	_add_box(parent, "ShaftWallWest", Vector3(-wall_x, shaft_y, 0.0), Vector3(WALL_THICKNESS, shaft_height, 7.0), UTILITY_PANELS, _collisions_enabled())
	_add_box(parent, "ShaftWallEast", Vector3(wall_x, shaft_y, 0.0), Vector3(WALL_THICKNESS, shaft_height, 7.0), UTILITY_PANELS, _collisions_enabled())
	_add_box(parent, "ShaftWallSouth", Vector3(0.0, shaft_y, wall_z), Vector3(SHAFT_HALF_WIDTH * 2.0, shaft_height, WALL_THICKNESS), UTILITY_PANELS, _collisions_enabled())


func _build_landings(parent: Node3D) -> void:
	_add_box(
		parent,
		"IntermediateLanding",
		Vector3(0.0, -LEVEL_HEIGHT * 0.5 - SLAB_THICKNESS * 0.5, RUN_SOUTH + LANDING_DEPTH * 0.5),
		Vector3(SHAFT_HALF_WIDTH * 2.0, SLAB_THICKNESS, LANDING_DEPTH),
		UTILITY_PANELS,
		_collisions_enabled()
	)
	_add_box(
		parent,
		"LowerThreshold",
		Vector3(-FLIGHT_CENTER_X, -LEVEL_HEIGHT - SLAB_THICKNESS * 0.5, RUN_NORTH + 0.75),
		Vector3(FLIGHT_WIDTH, SLAB_THICKNESS, 1.5),
		UTILITY_PANELS,
		_collisions_enabled()
	)
	var upper_outer_x := FLIGHT_CENTER_X + FLIGHT_WIDTH * 0.5
	_add_box(
		parent,
		"UpperSideThreshold",
		Vector3((upper_outer_x + UPPER_APPROACH_WALL_EDGE_X) * 0.5, -SLAB_THICKNESS * 0.5, RUN_NORTH + UPPER_SIDE_THRESHOLD_DEPTH * 0.5),
		Vector3(UPPER_APPROACH_WALL_EDGE_X - upper_outer_x, SLAB_THICKNESS, UPPER_SIDE_THRESHOLD_DEPTH),
		UTILITY_PANELS,
		_collisions_enabled()
	)


func _build_flights(parent: Node3D) -> void:
	var intermediate_y := -LEVEL_HEIGHT * 0.5
	for index: int in range(RISERS_PER_FLIGHT):
		var upper_top := -RISER_HEIGHT * index
		var upper_z := RUN_NORTH + TREAD_DEPTH * (index + 0.5)
		_add_box(parent, "UpperFlight_%02d" % index, Vector3(FLIGHT_CENTER_X, upper_top - RISER_HEIGHT * 0.5, upper_z), Vector3(FLIGHT_WIDTH, RISER_HEIGHT, TREAD_DEPTH), UTILITY_PANELS, _collisions_enabled())
		var lower_top := intermediate_y - RISER_HEIGHT * index
		var lower_z := RUN_SOUTH - TREAD_DEPTH * (index + 0.5)
		_add_box(parent, "LowerFlight_%02d" % index, Vector3(-FLIGHT_CENTER_X, lower_top - RISER_HEIGHT * 0.5, lower_z), Vector3(FLIGHT_WIDTH, RISER_HEIGHT, TREAD_DEPTH), UTILITY_PANELS, _collisions_enabled())
	for offset: float in [-0.5, 0.5]:
		_add_sloped_box(parent, "UpperStringer_%s" % str(offset), Vector3(FLIGHT_CENTER_X + offset, -0.24, RUN_NORTH), Vector3(FLIGHT_CENTER_X + offset, intermediate_y - 0.24, RUN_SOUTH), 0.20, UTILITY_PANELS)
		_add_sloped_box(parent, "LowerStringer_%s" % str(offset), Vector3(-FLIGHT_CENTER_X + offset, intermediate_y - 0.24, RUN_SOUTH), Vector3(-FLIGHT_CENTER_X + offset, -LEVEL_HEIGHT - 0.24, RUN_NORTH), 0.20, UTILITY_PANELS)


func _build_railings(parent: Node3D) -> void:
	var intermediate_y := -LEVEL_HEIGHT * 0.5
	var upper_inner_x := FLIGHT_CENTER_X - FLIGHT_WIDTH * 0.5
	var upper_outer_x := FLIGHT_CENTER_X + FLIGHT_WIDTH * 0.5
	var lower_inner_x := -FLIGHT_CENTER_X + FLIGHT_WIDTH * 0.5
	var lower_outer_x := -FLIGHT_CENTER_X - FLIGHT_WIDTH * 0.5
	_add_flight_guard(parent, "UpperInner", upper_inner_x, 0.0, intermediate_y, RUN_NORTH, RUN_SOUTH)
	_add_flight_guard(parent, "UpperOuter", upper_outer_x, 0.0, intermediate_y, RUN_NORTH, RUN_SOUTH)
	_add_flight_guard(parent, "LowerInner", lower_inner_x, intermediate_y, -LEVEL_HEIGHT, RUN_SOUTH, RUN_NORTH)
	_add_flight_guard(parent, "LowerOuter", lower_outer_x, intermediate_y, -LEVEL_HEIGHT, RUN_SOUTH, RUN_NORTH)
	_add_landing_guard(parent, "LandingWest", intermediate_y, -SHAFT_HALF_WIDTH, lower_outer_x, RUN_SOUTH)
	_add_landing_guard(parent, "LandingGap", intermediate_y, lower_inner_x, upper_inner_x, RUN_SOUTH)
	_add_landing_guard(parent, "LandingEast", intermediate_y, upper_outer_x, SHAFT_HALF_WIDTH, RUN_SOUTH)
	_add_landing_guard(parent, "UpperOpening", 0.0, upper_outer_x, UPPER_APPROACH_WALL_EDGE_X, RUN_NORTH + UPPER_SIDE_THRESHOLD_DEPTH)


func _add_flight_guard(parent: Node3D, prefix: String, rail_x: float, start_y: float, end_y: float, start_z: float, end_z: float) -> void:
	_add_bar(parent, "%sTopRail" % prefix, Vector3(rail_x, start_y + RAIL_HEIGHT, start_z), Vector3(rail_x, end_y + RAIL_HEIGHT, end_z), 0.10, _collisions_enabled())
	_add_bar(parent, "%sMidRail" % prefix, Vector3(rail_x, start_y + RAIL_HEIGHT * 0.55, start_z), Vector3(rail_x, end_y + RAIL_HEIGHT * 0.55, end_z), 0.08, _collisions_enabled())
	for index: int in range(0, RISERS_PER_FLIGHT + 1, 5):
		var t := float(index) / float(RISERS_PER_FLIGHT)
		_add_box(parent, "%sPost_%02d" % [prefix, index], Vector3(rail_x, lerpf(start_y, end_y, t) + RAIL_HEIGHT * 0.5, lerpf(start_z, end_z, t)), Vector3(0.10, RAIL_HEIGHT, 0.10), _rail_material, _collisions_enabled())


func _add_landing_guard(parent: Node3D, prefix: String, landing_y: float, x_min: float, x_max: float, rail_z: float) -> void:
	_add_bar(parent, "%sTopRail" % prefix, Vector3(x_min, landing_y + RAIL_HEIGHT, rail_z), Vector3(x_max, landing_y + RAIL_HEIGHT, rail_z), 0.10, _collisions_enabled())
	_add_bar(parent, "%sMidRail" % prefix, Vector3(x_min, landing_y + RAIL_HEIGHT * 0.55, rail_z), Vector3(x_max, landing_y + RAIL_HEIGHT * 0.55, rail_z), 0.08, _collisions_enabled())
	for index: int in range(3):
		var rail_x := lerpf(x_min, x_max, float(index) * 0.5)
		_add_box(parent, "%sPost_%02d" % [prefix, index], Vector3(rail_x, landing_y + RAIL_HEIGHT * 0.5, rail_z), Vector3(0.10, RAIL_HEIGHT, 0.10), _rail_material, _collisions_enabled())


func validate_geometry() -> PackedStringArray:
	var errors := PackedStringArray()
	var generated := get_node_or_null("Generated")
	if generated == null:
		errors.append("Route A stair did not build Generated")
		return errors
	if generated.find_children("UpperFlight_*", "", true, false).size() != RISERS_PER_FLIGHT:
		errors.append("Upper flight must contain %d risers" % RISERS_PER_FLIGHT)
	if generated.find_children("LowerFlight_*", "", true, false).size() != RISERS_PER_FLIGHT:
		errors.append("Lower flight must contain %d risers" % RISERS_PER_FLIGHT)
	for required_name: String in ["IntermediateLanding", "LowerThreshold", "UpperSideThreshold", "ShaftWallWest", "ShaftWallEast", "ShaftWallSouth", "UpperInnerTopRail", "UpperOuterTopRail", "LowerInnerTopRail", "LowerOuterTopRail", "LandingWestTopRail", "LandingGapTopRail", "LandingEastTopRail", "UpperOpeningTopRail"]:
		if generated.find_children(required_name, "", true, false).is_empty():
			errors.append("Missing Route A stair component: %s" % required_name)
	return errors


func get_geometry_summary() -> Dictionary:
	return {
		"level_height": LEVEL_HEIGHT,
		"flight_width": FLIGHT_WIDTH,
		"riser_height": RISER_HEIGHT,
		"tread_depth": TREAD_DEPTH,
		"risers_per_flight": RISERS_PER_FLIGHT,
		"guarded_flight_sides": 4,
		"landing_guard_spans": 4,
		"footprint_width": SHAFT_HALF_WIDTH * 2.0,
		"footprint_depth": 7.0,
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
