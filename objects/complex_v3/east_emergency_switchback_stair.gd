@tool
extends Node3D
class_name EastEmergencySwitchbackStair

const UTILITY_PANELS := preload("res://materials/complex_v3/utility_panels.tres")

const LEVEL_HEIGHT := 6.0
const OPENING_LENGTH := 9.0
const OPENING_DEPTH := 5.5
const TREAD_DEPTH := 0.3
const RISER_HEIGHT := 0.15
const RISERS_PER_FLIGHT := 20
const FLIGHT_WIDTH := OPENING_DEPTH * 0.5
const RUN_WEST := -3.0
const RUN_EAST := 3.0
const LANDING_LENGTH := 1.5
const SLAB_THICKNESS := 0.12
const WALL_THICKNESS := 0.20
const RAIL_HEIGHT := 0.95

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
	generated.set_meta("opening_xz", [-OPENING_LENGTH * 0.5, -OPENING_DEPTH * 0.5, OPENING_LENGTH * 0.5, OPENING_DEPTH * 0.5])
	add_child(generated)
	_build_decks(generated)
	_build_flights(generated)
	_build_lower_shaft_walls(generated)
	_build_railings(generated)


func _build_decks(parent: Node3D) -> void:
	_add_box(parent, "UpperLanding", Vector3(RUN_EAST + LANDING_LENGTH * 0.5, -SLAB_THICKNESS * 0.5, 0.0), Vector3(LANDING_LENGTH, SLAB_THICKNESS, OPENING_DEPTH), UTILITY_PANELS, _collisions_enabled())
	_add_box(parent, "UpperNorthClosure", Vector3(0.0, -SLAB_THICKNESS * 0.5, -OPENING_DEPTH * 0.25), Vector3(RUN_EAST - RUN_WEST, SLAB_THICKNESS, OPENING_DEPTH * 0.5), UTILITY_PANELS, _collisions_enabled())
	_add_box(parent, "IntermediateLanding", Vector3(RUN_WEST - LANDING_LENGTH * 0.5, -LEVEL_HEIGHT * 0.5 - SLAB_THICKNESS * 0.5, 0.0), Vector3(LANDING_LENGTH, SLAB_THICKNESS, OPENING_DEPTH), UTILITY_PANELS, _collisions_enabled())
	_add_box(parent, "LowerLandingDeck", Vector3(0.0, -LEVEL_HEIGHT - SLAB_THICKNESS * 0.5, 0.0), Vector3(OPENING_LENGTH, SLAB_THICKNESS, OPENING_DEPTH), UTILITY_PANELS, _collisions_enabled())


func _build_flights(parent: Node3D) -> void:
	var upper_z := OPENING_DEPTH * 0.25
	var lower_z := -OPENING_DEPTH * 0.25
	for index: int in range(RISERS_PER_FLIGHT):
		var upper_x := RUN_EAST - TREAD_DEPTH * (index + 0.5)
		var upper_top := -RISER_HEIGHT * index
		_add_box(parent, "UpperFlight_%02d" % index, Vector3(upper_x, upper_top - RISER_HEIGHT * 0.5, upper_z), Vector3(TREAD_DEPTH, RISER_HEIGHT, FLIGHT_WIDTH), UTILITY_PANELS, _collisions_enabled())
		var lower_x := RUN_WEST + TREAD_DEPTH * (index + 0.5)
		var lower_top := -LEVEL_HEIGHT * 0.5 - RISER_HEIGHT * index
		_add_box(parent, "LowerFlight_%02d" % index, Vector3(lower_x, lower_top - RISER_HEIGHT * 0.5, lower_z), Vector3(TREAD_DEPTH, RISER_HEIGHT, FLIGHT_WIDTH), UTILITY_PANELS, _collisions_enabled())


func _build_lower_shaft_walls(parent: Node3D) -> void:
	var wall_y := -LEVEL_HEIGHT * 0.5
	_add_box(parent, "LowerWallNorth", Vector3(0.0, wall_y, -OPENING_DEPTH * 0.5 - WALL_THICKNESS * 0.5), Vector3(OPENING_LENGTH, LEVEL_HEIGHT, WALL_THICKNESS), UTILITY_PANELS, _collisions_enabled())
	_add_box(parent, "LowerWallSouth", Vector3(0.0, wall_y, OPENING_DEPTH * 0.5 + WALL_THICKNESS * 0.5), Vector3(OPENING_LENGTH, LEVEL_HEIGHT, WALL_THICKNESS), UTILITY_PANELS, _collisions_enabled())
	_add_box(parent, "LowerWallWest", Vector3(-OPENING_LENGTH * 0.5 - WALL_THICKNESS * 0.5, wall_y, 0.0), Vector3(WALL_THICKNESS, LEVEL_HEIGHT, OPENING_DEPTH), UTILITY_PANELS, _collisions_enabled())
	_add_box(parent, "LowerWallEast", Vector3(OPENING_LENGTH * 0.5 + WALL_THICKNESS * 0.5, wall_y, 0.0), Vector3(WALL_THICKNESS, LEVEL_HEIGHT, OPENING_DEPTH), UTILITY_PANELS, _collisions_enabled())


func _build_railings(parent: Node3D) -> void:
	_add_sloped_rail(parent, "UpperInnerRail", Vector3(RUN_EAST, RAIL_HEIGHT, 0.0), Vector3(RUN_WEST, -LEVEL_HEIGHT * 0.5 + RAIL_HEIGHT, 0.0))
	_add_sloped_rail(parent, "LowerInnerRail", Vector3(RUN_WEST, -LEVEL_HEIGHT * 0.5 + RAIL_HEIGHT, 0.0), Vector3(RUN_EAST, -LEVEL_HEIGHT + RAIL_HEIGHT, 0.0))
	for index: int in range(0, RISERS_PER_FLIGHT + 1, 5):
		var t := float(index) / float(RISERS_PER_FLIGHT)
		_add_box(parent, "UpperPost_%02d" % index, Vector3(lerpf(RUN_EAST, RUN_WEST, t), lerpf(0.0, -LEVEL_HEIGHT * 0.5, t) + RAIL_HEIGHT * 0.5, 0.0), Vector3(0.10, RAIL_HEIGHT, 0.10), _rail_material, _collisions_enabled())
		_add_box(parent, "LowerPost_%02d" % index, Vector3(lerpf(RUN_WEST, RUN_EAST, t), lerpf(-LEVEL_HEIGHT * 0.5, -LEVEL_HEIGHT, t) + RAIL_HEIGHT * 0.5, 0.0), Vector3(0.10, RAIL_HEIGHT, 0.10), _rail_material, _collisions_enabled())


func validate_geometry() -> PackedStringArray:
	var errors := PackedStringArray()
	var generated := get_node_or_null("Generated")
	if generated == null:
		errors.append("East stair scene did not build Generated")
		return errors
	if generated.find_children("UpperFlight_*", "", true, false).size() != RISERS_PER_FLIGHT:
		errors.append("Upper flight must contain %d risers" % RISERS_PER_FLIGHT)
	if generated.find_children("LowerFlight_*", "", true, false).size() != RISERS_PER_FLIGHT:
		errors.append("Lower flight must contain %d risers" % RISERS_PER_FLIGHT)
	for required_name: String in ["UpperLanding", "UpperNorthClosure", "IntermediateLanding", "LowerLandingDeck", "LowerWallNorth", "LowerWallSouth", "UpperInnerRail", "LowerInnerRail"]:
		if generated.find_children(required_name, "", true, false).is_empty():
			errors.append("Missing east stair component: %s" % required_name)
	return errors


func _collisions_enabled() -> bool:
	return build_collisions and not Engine.is_editor_hint()


func _add_sloped_rail(parent: Node3D, node_name: String, start: Vector3, end: Vector3) -> void:
	var delta := end - start
	var direction := delta.normalized()
	var side := Vector3.UP.cross(direction).normalized()
	var up := direction.cross(side).normalized()
	_add_oriented_box(parent, node_name, Transform3D(Basis(side, up, direction), (start + end) * 0.5), Vector3(0.10, 0.10, delta.length()), _rail_material, _collisions_enabled())


func _add_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3, material: Material, collision: bool) -> void:
	_add_oriented_box(parent, node_name, Transform3D(Basis.IDENTITY, center), size, material, collision)


func _add_oriented_box(parent: Node3D, node_name: String, box_transform: Transform3D, size: Vector3, material: Material, collision: bool) -> void:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
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
