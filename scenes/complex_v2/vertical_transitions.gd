extends Node3D

const RAMP_WIDTH := 4.6
const FLOOR_MATERIAL: Material = preload("res://materials/hangar_concrete_floor.tres")
const WALL_MATERIAL: Material = preload("res://materials/concrete_slab_wall_02.tres")
const EMERGENCY_LIGHT := preload("res://objects/emergency_light.tscn")
const CAGED_LIGHT := preload("res://objects/caged_light.tscn")


func _ready() -> void:
	_build_manual_evacuation_stair()
	_build_central_shortcut()
	_build_generator_stair()


func _build_manual_evacuation_stair() -> void:
	_add_shaft_shell("ManualEvacShaft", -55.0, -40.0, 45.0, 67.5, 0.0, 16.0, false, -47.5)
	_add_ramp("ManualEvacUpper", Vector3(-47.5, 12.0, 40.0), Vector3(-50.0, 6.0, 62.5), true)
	_add_landing("ManualEvacLanding", Vector3(-47.5, 6.0, 62.5), Vector2(10.0, 8.0))
	_add_ramp("ManualEvacLower", Vector3(-45.0, 6.0, 62.5), Vector3(-50.0, 0.0, 40.0), true)
	_add_emergency_light("ManualEvacEmergency", Vector3(-47.5, 7.25, 64.8), Vector3(0.0, 180.0, 0.0))
	_add_crossbeam_light("ManualEvacMidLight", Vector3(-47.5, 9.0, 59.0), 14.0)
	_add_crossbeam_light("ManualEvacUpperLight", Vector3(-47.5, 15.0, 49.0), 14.0)


func _build_central_shortcut() -> void:
	_add_shaft_shell("CentralShaft", 7.5, 22.5, 45.0, 67.5, 0.0, 16.0, false)
	_add_ramp("CentralUpper", Vector3(12.5, 12.0, 40.0), Vector3(12.5, 6.0, 62.5))
	_add_landing("CentralLanding", Vector3(15.0, 6.0, 62.5), Vector2(10.0, 8.0))
	_add_ramp("CentralLower", Vector3(17.5, 6.0, 62.5), Vector3(12.5, 0.0, 40.0))
	_add_emergency_light("CentralEmergency", Vector3(15.0, 7.25, 64.8), Vector3(0.0, 180.0, 0.0))
	_add_crossbeam_light("CentralMidLight", Vector3(15.0, 9.0, 59.0), 14.0)
	_add_crossbeam_light("CentralUpperLight", Vector3(15.0, 15.0, 49.0), 14.0)


func _build_generator_stair() -> void:
	_add_shaft_shell("GeneratorShaft", -27.5, -12.5, -42.5, -15.0, -12.0, 4.0, true)
	_add_ramp("GeneratorUpper", Vector3(-22.5, 0.0, -15.0), Vector3(-22.5, -6.0, -37.5))
	_add_landing("GeneratorLanding", Vector3(-20.0, -6.0, -37.5), Vector2(10.0, 8.0))
	_add_ramp("GeneratorLower", Vector3(-17.5, -6.0, -37.5), Vector3(-17.5, -12.0, -15.0))
	_add_emergency_light("GeneratorEmergency", Vector3(-20.0, -4.75, -39.8), Vector3.ZERO)
	_add_crossbeam_light("GeneratorMidLight", Vector3(-20.0, -3.0, -34.0), 14.0)
	_add_crossbeam_light("GeneratorUpperLight", Vector3(-20.0, 3.0, -24.0), 14.0)


func _add_ramp(name_value: String, start: Vector3, end: Vector3, clear_landings: bool = false) -> void:
	var direction := (end - start).normalized()
	var right := Vector3.UP.cross(direction).normalized()
	var surface_up := direction.cross(right).normalized()
	var length := start.distance_to(end)

	var body := StaticBody3D.new()
	body.name = name_value
	body.position = (start + end) * 0.5
	if clear_landings:
		body.position -= surface_up * 0.25
	body.basis = Basis(right, surface_up, direction)
	add_child(body)

	_add_mesh_and_collision(body, "Ramp", Vector3(RAMP_WIDTH, 0.5, length), Vector3.ZERO, FLOOR_MATERIAL)
	var rail_length := maxf(length - 4.0, 0.5) if clear_landings else length
	var rail_offset := Vector3(0.0, 0.95, 0.0)
	_add_mesh_and_collision(
		body,
		"LeftRail",
		Vector3(0.25, 1.4, rail_length),
		Vector3(-RAMP_WIDTH * 0.5 + 0.12, rail_offset.y, rail_offset.z),
		WALL_MATERIAL
	)
	_add_mesh_and_collision(
		body,
		"RightRail",
		Vector3(0.25, 1.4, rail_length),
		Vector3(RAMP_WIDTH * 0.5 - 0.12, rail_offset.y, rail_offset.z),
		WALL_MATERIAL
	)


func _add_landing(name_value: String, surface_position: Vector3, size: Vector2) -> void:
	var body := StaticBody3D.new()
	body.name = name_value
	body.position = surface_position - Vector3(0.0, 0.25, 0.0)
	add_child(body)
	_add_mesh_and_collision(body, "Landing", Vector3(size.x, 0.5, size.y), Vector3.ZERO, FLOOR_MATERIAL)
	_add_mesh_and_collision(
		body,
		"RearRail",
		Vector3(size.x, 1.4, 0.25),
		Vector3(0.0, 0.95, size.y * 0.5 - 0.12),
		WALL_MATERIAL
	)


func _add_shaft_shell(
	name_value: String,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	min_y: float,
	max_y: float,
	close_min_z: bool,
	near_opening_center_x: float = NAN
) -> void:
	var shell := Node3D.new()
	shell.name = name_value
	add_child(shell)
	var height := max_y - min_y
	var depth := max_z - min_z
	var width := max_x - min_x
	var center_y := min_y + height * 0.5
	var center_z := min_z + depth * 0.5
	_add_world_box(shell, "LeftWall", Vector3(0.5, height, depth), Vector3(min_x, center_y, center_z), WALL_MATERIAL)
	_add_world_box(shell, "RightWall", Vector3(0.5, height, depth), Vector3(max_x, center_y, center_z), WALL_MATERIAL)
	var closed_z := min_z if close_min_z else max_z
	var near_z := max_z if close_min_z else min_z
	_add_world_box(shell, "EndWall", Vector3(width, height, 0.5), Vector3((min_x + max_x) * 0.5, center_y, closed_z), WALL_MATERIAL)
	var middle_height := maxf(height - 8.0, 0.0)
	if middle_height > 0.0:
		var middle_y := min_y + 4.0 + middle_height * 0.5
		if is_nan(near_opening_center_x):
			_add_world_box(shell, "NearMidWall", Vector3(width, middle_height, 0.5), Vector3((min_x + max_x) * 0.5, middle_y, near_z), WALL_MATERIAL)
		else:
			var opening_half_width := 2.5
			var left_width := near_opening_center_x - opening_half_width - min_x
			var right_width := max_x - near_opening_center_x - opening_half_width
			if left_width > 0.0:
				_add_world_box(
					shell,
					"NearMidWallLeft",
					Vector3(left_width, middle_height, 0.5),
					Vector3(min_x + left_width * 0.5, middle_y, near_z),
					WALL_MATERIAL
				)
			if right_width > 0.0:
				_add_world_box(
					shell,
					"NearMidWallRight",
					Vector3(right_width, middle_height, 0.5),
					Vector3(max_x - right_width * 0.5, middle_y, near_z),
					WALL_MATERIAL
				)
	_add_world_box(shell, "Roof", Vector3(width, 0.5, depth), Vector3((min_x + max_x) * 0.5, max_y, center_z), WALL_MATERIAL)


func _add_world_box(
	parent: Node3D,
	part_name: String,
	size: Vector3,
	world_position: Vector3,
	material: Material
) -> void:
	var body := StaticBody3D.new()
	body.name = part_name
	body.position = world_position
	parent.add_child(body)
	_add_mesh_and_collision(body, part_name, size, Vector3.ZERO, material)


func _add_crossbeam_light(name_value: String, position_value: Vector3, width: float) -> void:
	var support := StaticBody3D.new()
	support.name = "%sSupport" % name_value
	support.position = position_value
	add_child(support)
	_add_mesh_and_collision(support, "Beam", Vector3(width, 0.24, 0.28), Vector3.ZERO, WALL_MATERIAL)
	var light := CAGED_LIGHT.instantiate() as Node3D
	light.name = name_value
	light.position = Vector3(0.0, -0.35, 0.0)
	light.set("base_energy", 7.5)
	support.add_child(light)
	var fill := OmniLight3D.new()
	fill.name = "ShaftFill"
	fill.position = Vector3(0.0, -0.55, 0.0)
	fill.light_color = Color(0.32, 0.5, 0.75, 1.0)
	fill.light_energy = 1.4
	fill.omni_range = 9.0
	fill.shadow_enabled = false
	support.add_child(fill)


func _add_mesh_and_collision(
	body: StaticBody3D,
	part_name: String,
	size: Vector3,
	local_position: Vector3,
	material: Material
) -> void:
	var mesh_resource := BoxMesh.new()
	mesh_resource.size = size
	mesh_resource.material = material
	var mesh := MeshInstance3D.new()
	mesh.name = "%sMesh" % part_name
	mesh.position = local_position
	mesh.mesh = mesh_resource
	body.add_child(mesh)

	var shape_resource := BoxShape3D.new()
	shape_resource.size = size
	var collision := CollisionShape3D.new()
	collision.name = "%sCollision" % part_name
	collision.position = local_position
	collision.shape = shape_resource
	body.add_child(collision)


func _add_emergency_light(name_value: String, light_position: Vector3, rotation: Vector3) -> void:
	var light := EMERGENCY_LIGHT.instantiate() as Node3D
	light.name = name_value
	light.position = light_position
	light.rotation_degrees = rotation
	add_child(light)
