extends Node3D
class_name FacilityGridLevel

const CELL_SIZE := 5.0
const WALL_HEIGHT := 4.0

const FLOOR_SCENE := preload("res://objects/floor.tscn")
const WALL_SCENE := preload("res://objects/wall.tscn")
const CEILING_SCENE := preload("res://objects/celling.tscn")
const DOOR_SCENE := preload("res://objects/temporary_blast_door.tscn")
const CAGED_LIGHT_SCENE := preload("res://objects/caged_light.tscn")
const EMERGENCY_LIGHT_SCENE := preload("res://objects/emergency_light.tscn")

var _scene_cache: Dictionary[String, PackedScene] = {}


func _ready() -> void:
	_build_structure()
	_build_doors()
	_build_lights()
	_build_props()
	_build_signs()


func _get_zones() -> Array[Dictionary]:
	return []


func _get_doors() -> Array[Dictionary]:
	return []


func _get_lights() -> Array[Dictionary]:
	return []


func _get_props() -> Array[Dictionary]:
	return []


func _get_signs() -> Array[Dictionary]:
	return []


func _get_ceiling_holes() -> Array[Vector2i]:
	return []


func _get_wall_openings() -> Array[Dictionary]:
	return []


func _build_structure() -> void:
	var cells: Dictionary[Vector2i, bool] = {}
	for zone: Dictionary in _get_zones():
		var rect: Rect2i = zone["rect"]
		for x: int in range(rect.position.x, rect.end.x):
			for z: int in range(rect.position.y, rect.end.y):
				cells[Vector2i(x, z)] = true

	var ceiling_holes: Dictionary[Vector2i, bool] = {}
	for hole: Vector2i in _get_ceiling_holes():
		ceiling_holes[hole] = true
	var wall_openings: Dictionary[String, bool] = {}
	for opening: Dictionary in _get_wall_openings():
		var opening_cell: Vector2i = opening["cell"]
		var opening_direction: Vector2i = opening["direction"]
		wall_openings[_wall_key(opening_cell, opening_direction)] = true

	var structure := Node3D.new()
	structure.name = "Structure"
	add_child(structure)

	for cell: Vector2i in cells:
		_add_floor_tile(structure, cell)
		if not ceiling_holes.has(cell):
			_add_ceiling_tile(structure, cell)
		_add_boundary_wall(structure, cells, wall_openings, cell, Vector2i(0, -1))
		_add_boundary_wall(structure, cells, wall_openings, cell, Vector2i(0, 1))
		_add_boundary_wall(structure, cells, wall_openings, cell, Vector2i(-1, 0))
		_add_boundary_wall(structure, cells, wall_openings, cell, Vector2i(1, 0))


func _add_floor_tile(parent: Node3D, cell: Vector2i) -> void:
	var tile := FLOOR_SCENE.instantiate() as Node3D
	tile.name = "Floor_%d_%d" % [cell.x, cell.y]
	tile.position = Vector3(
		(cell.x + 0.5) * CELL_SIZE,
		-0.25,
		(cell.y + 0.5) * CELL_SIZE
	)
	parent.add_child(tile)


func _add_ceiling_tile(parent: Node3D, cell: Vector2i) -> void:
	var tile := CEILING_SCENE.instantiate() as Node3D
	tile.name = "Ceiling_%d_%d" % [cell.x, cell.y]
	tile.position = Vector3(
		(cell.x + 0.5) * CELL_SIZE,
		WALL_HEIGHT + 0.25,
		(cell.y + 0.5) * CELL_SIZE
	)
	parent.add_child(tile)


func _add_boundary_wall(
	parent: Node3D,
	cells: Dictionary[Vector2i, bool],
	wall_openings: Dictionary[String, bool],
	cell: Vector2i,
	direction: Vector2i
) -> void:
	if cells.has(cell + direction) or wall_openings.has(_wall_key(cell, direction)):
		return

	var wall := WALL_SCENE.instantiate() as Node3D
	wall.name = "Wall_%d_%d_%d_%d" % [cell.x, cell.y, direction.x, direction.y]
	wall.position.y = WALL_HEIGHT * 0.5
	if direction == Vector2i(0, -1):
		wall.position.x = (cell.x + 0.5) * CELL_SIZE
		wall.position.z = cell.y * CELL_SIZE
	elif direction == Vector2i(0, 1):
		wall.position.x = (cell.x + 0.5) * CELL_SIZE
		wall.position.z = (cell.y + 1) * CELL_SIZE
	elif direction == Vector2i(-1, 0):
		wall.position.x = cell.x * CELL_SIZE
		wall.position.z = (cell.y + 0.5) * CELL_SIZE
		wall.rotation_degrees.y = 90.0
	else:
		wall.position.x = (cell.x + 1) * CELL_SIZE
		wall.position.z = (cell.y + 0.5) * CELL_SIZE
		wall.rotation_degrees.y = 90.0
	parent.add_child(wall)


func _wall_key(cell: Vector2i, direction: Vector2i) -> String:
	return "%d:%d:%d:%d" % [cell.x, cell.y, direction.x, direction.y]


func _build_doors() -> void:
	var group := Node3D.new()
	group.name = "Doors"
	add_child(group)
	for data: Dictionary in _get_doors():
		var door := DOOR_SCENE.instantiate() as Node3D
		door.name = str(data.get("name", "BlastDoor"))
		door.position = data["position"] + Vector3(0.0, WALL_HEIGHT * 0.5, 0.0)
		door.rotation_degrees.y = float(data.get("rotation_y", 0.0))
		group.add_child(door)


func _build_lights() -> void:
	var group := Node3D.new()
	group.name = "Lighting"
	add_child(group)
	for data: Dictionary in _get_lights():
		var emergency := bool(data.get("emergency", false))
		var light_scene: PackedScene = EMERGENCY_LIGHT_SCENE if emergency else CAGED_LIGHT_SCENE
		var light := light_scene.instantiate() as Node3D
		light.name = str(data.get("name", "EmergencyLight" if emergency else "CagedLight"))
		light.position = data["position"]
		light.rotation_degrees = data.get("rotation", Vector3.ZERO)
		if not emergency:
			light.set("flicker_enabled", bool(data.get("flicker", false)))
			var fill_light := OmniLight3D.new()
			fill_light.name = "WallFill"
			fill_light.position = Vector3(0.0, -0.65, 0.0)
			fill_light.light_color = Color(0.3, 0.48, 0.72, 1.0)
			fill_light.light_energy = 1.05
			fill_light.omni_range = 6.5
			fill_light.shadow_enabled = false
			fill_light.distance_fade_enabled = true
			fill_light.distance_fade_begin = 18.0
			fill_light.distance_fade_length = 7.0
			light.add_child(fill_light)
		group.add_child(light)


func _build_props() -> void:
	var group := Node3D.new()
	group.name = "Props"
	add_child(group)
	for data: Dictionary in _get_props():
		var path := str(data["scene"])
		var packed := _load_packed_scene(path)
		if packed == null:
			push_warning("Не удалось загрузить объект карты: %s" % path)
			continue
		var prop := packed.instantiate() as Node3D
		prop.name = str(data.get("name", path.get_file().get_basename()))
		prop.position = data["position"]
		prop.rotation_degrees = data.get("rotation", Vector3.ZERO)
		var uniform_scale := float(data.get("scale", 1.0))
		prop.scale = Vector3.ONE * uniform_scale
		group.add_child(prop)


func _build_signs() -> void:
	var group := Node3D.new()
	group.name = "Signs"
	add_child(group)
	for data: Dictionary in _get_signs():
		var sign := Label3D.new()
		sign.name = str(data.get("name", "ZoneSign"))
		sign.text = str(data["text"])
		sign.position = data["position"]
		sign.rotation_degrees = data.get("rotation", Vector3.ZERO)
		sign.font_size = int(data.get("font_size", 48))
		sign.modulate = data.get("color", Color(0.45, 0.82, 1.0, 1.0))
		sign.outline_size = 10
		sign.no_depth_test = false
		group.add_child(sign)


func _load_packed_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path]
	var resource := load(path)
	if resource is PackedScene:
		var packed := resource as PackedScene
		_scene_cache[path] = packed
		return packed
	return null
