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
var _cell_rooms: Dictionary[Vector2i, String] = {}
var _portal_edges: Dictionary[String, bool] = {}
var _portal_records: Array[Dictionary] = []


func _ready() -> void:
	_compile_layout()
	_build_structure()
	_build_doors()
	_build_lights()
	_build_props()
	_build_signs()


func _get_zones() -> Array[Dictionary]:
	return []


func _get_connections() -> Array[Dictionary]:
	return []


func _get_lights() -> Array[Dictionary]:
	return []


func _get_props() -> Array[Dictionary]:
	return []


func _get_signs() -> Array[Dictionary]:
	return []


func _get_ceiling_holes() -> Array[Vector2i]:
	return []


func _get_floor_holes() -> Array[Vector2i]:
	return []


func _get_wall_openings() -> Array[Dictionary]:
	return []


func _build_structure() -> void:
	var ceiling_holes: Dictionary[Vector2i, bool] = {}
	for hole: Vector2i in _get_ceiling_holes():
		ceiling_holes[hole] = true
	var floor_holes: Dictionary[Vector2i, bool] = {}
	for hole: Vector2i in _get_floor_holes():
		floor_holes[hole] = true
	for opening: Dictionary in _get_wall_openings():
		var opening_cell: Vector2i = opening["cell"]
		var opening_direction: Vector2i = opening["direction"]
		_portal_edges[_edge_key(opening_cell, opening_cell + opening_direction)] = true

	var structure := Node3D.new()
	structure.name = "Structure"
	add_child(structure)

	for cell: Vector2i in _cell_rooms:
		if not floor_holes.has(cell):
			_add_floor_tile(structure, cell)
		if not ceiling_holes.has(cell):
			_add_ceiling_tile(structure, cell)
		_add_required_wall(structure, cell, Vector2i(0, -1))
		_add_required_wall(structure, cell, Vector2i(0, 1))
		_add_required_wall(structure, cell, Vector2i(-1, 0))
		_add_required_wall(structure, cell, Vector2i(1, 0))


func _compile_layout() -> void:
	_cell_rooms.clear()
	_portal_edges.clear()
	_portal_records.clear()
	for zone: Dictionary in _get_zones():
		var room_id := str(zone["id"])
		var rect: Rect2i = zone["rect"]
		for x: int in range(rect.position.x, rect.end.x):
			for z: int in range(rect.position.y, rect.end.y):
				var cell := Vector2i(x, z)
				if _cell_rooms.has(cell):
					push_error("Ячейка %s одновременно принадлежит %s и %s" % [cell, _cell_rooms[cell], room_id])
					continue
				_cell_rooms[cell] = room_id
	for connection: Dictionary in _get_connections():
		_compile_connection(connection)


func _compile_connection(connection: Dictionary) -> void:
	var room_a := str(connection["from"])
	var room_b := str(connection["to"])
	var candidates := _find_shared_edges(room_a, room_b)
	if candidates.is_empty():
		push_error("Помещения %s и %s не имеют общей границы" % [room_a, room_b])
		return
	var edge_index := clampi(int(connection.get("edge_index", candidates.size() / 2)), 0, candidates.size() - 1)
	var portal: Dictionary = candidates[edge_index].duplicate()
	portal["from"] = room_a
	portal["to"] = room_b
	portal["name"] = str(connection.get("name", "%s_%s" % [room_a, room_b]))
	portal["door"] = bool(connection.get("door", false))
	_portal_edges[_edge_key(portal["cell"], portal["cell"] + portal["direction"])] = true
	_portal_records.append(portal)


func _find_shared_edges(room_a: String, room_b: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell: Vector2i in _cell_rooms:
		if _cell_rooms[cell] != room_a:
			continue
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var neighbour := cell + direction
			if _cell_rooms.get(neighbour, "") == room_b:
				result.append({"cell": cell, "direction": direction})
	return result


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


func _add_required_wall(parent: Node3D, cell: Vector2i, direction: Vector2i) -> void:
	var neighbour := cell + direction
	var edge_key := _edge_key(cell, neighbour)
	if _portal_edges.has(edge_key):
		return
	if _cell_rooms.has(neighbour) and _cell_rooms[neighbour] == _cell_rooms[cell]:
		return
	if _cell_rooms.has(neighbour) and (direction == Vector2i.LEFT or direction == Vector2i.UP):
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


func _edge_key(cell_a: Vector2i, cell_b: Vector2i) -> String:
	if cell_a.x > cell_b.x or (cell_a.x == cell_b.x and cell_a.y > cell_b.y):
		var swap := cell_a
		cell_a = cell_b
		cell_b = swap
	return "%d:%d|%d:%d" % [cell_a.x, cell_a.y, cell_b.x, cell_b.y]


func _build_doors() -> void:
	var group := Node3D.new()
	group.name = "Doors"
	add_child(group)
	for data: Dictionary in _portal_records:
		if not bool(data["door"]):
			continue
		var door := DOOR_SCENE.instantiate() as Node3D
		door.name = str(data["name"])
		var cell: Vector2i = data["cell"]
		var direction: Vector2i = data["direction"]
		door.position = _edge_center(cell, direction) + Vector3(0.0, WALL_HEIGHT * 0.5, 0.0)
		door.rotation_degrees.y = 90.0 if direction.x != 0 else 0.0
		group.add_child(door)


func _edge_center(cell: Vector2i, direction: Vector2i) -> Vector3:
	return Vector3(
		(cell.x + 0.5 + direction.x * 0.5) * CELL_SIZE,
		0.0,
		(cell.y + 0.5 + direction.y * 0.5) * CELL_SIZE
	)


func _build_lights() -> void:
	var group := Node3D.new()
	group.name = "Lighting"
	add_child(group)
	for data: Dictionary in _get_lights():
		var emergency := bool(data.get("emergency", false))
		var light_scene: PackedScene = EMERGENCY_LIGHT_SCENE if emergency else CAGED_LIGHT_SCENE
		var light := light_scene.instantiate() as Node3D
		light.name = str(data.get("name", "EmergencyLight" if emergency else "CagedLight"))
		var requested_position: Vector3 = data["position"]
		light.position = requested_position
		if not emergency:
			light.position.y = WALL_HEIGHT
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
		if bool(data.get("grounded", prop.position.y <= 1.0)):
			_ground_prop(prop)


func _ground_prop(prop: Node3D) -> void:
	var bounds := _node_world_bounds(prop)
	if bounds.size != Vector3.ZERO:
		prop.global_position.y -= bounds.position.y - global_position.y


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


func validate_layout() -> PackedStringArray:
	var errors := PackedStringArray()
	if _cell_rooms.is_empty():
		errors.append("%s: карта не содержит доступных ячеек" % name)
		return errors
	_validate_cell_connectivity(errors)
	for hole: Vector2i in _get_ceiling_holes():
		if not _cell_rooms.has(hole):
			errors.append("%s: отверстие в потолке %s находится вне пола" % [name, hole])
	for hole: Vector2i in _get_floor_holes():
		if not _cell_rooms.has(hole):
			errors.append("%s: отверстие в полу %s находится вне помещения" % [name, hole])
	for data: Dictionary in _get_lights():
		var position_value: Vector3 = data["position"]
		if not _cell_rooms.has(_world_to_cell(position_value)):
			errors.append("%s: светильник %s находится вне помещения" % [name, data.get("name", "без имени")])
	for data: Dictionary in _get_props():
		var position_value: Vector3 = data["position"]
		if not _cell_rooms.has(_world_to_cell(position_value)):
			errors.append("%s: объект %s находится вне пола" % [name, data.get("name", data["scene"])])
	for portal: Dictionary in _portal_records:
		if not _cell_rooms.has(portal["cell"] + portal["direction"]):
			errors.append("%s: портал %s ведёт за пределы карты" % [name, portal["name"]])
	_validate_built_structure(errors)
	_validate_built_placements(errors)
	return errors


func _validate_built_structure(errors: PackedStringArray) -> void:
	var floor_holes: Dictionary[Vector2i, bool] = {}
	for hole: Vector2i in _get_floor_holes():
		floor_holes[hole] = true
	for cell: Vector2i in _cell_rooms:
		var floor_path := "Structure/Floor_%d_%d" % [cell.x, cell.y]
		var has_floor := get_node_or_null(floor_path) != null
		if floor_holes.has(cell) == has_floor:
			errors.append("%s: неверное состояние пола в ячейке %s" % [name, cell])
	for portal: Dictionary in _portal_records:
		if bool(portal["door"]) and get_node_or_null("Doors/%s" % portal["name"]) == null:
			errors.append("%s: дверь %s не создана в портале" % [name, portal["name"]])


func _validate_built_placements(errors: PackedStringArray) -> void:
	var lighting := get_node_or_null("Lighting") as Node3D
	if lighting != null:
		for light: Node in lighting.get_children():
			if light is Node3D and not light.name.to_lower().contains("emergency"):
				if not is_equal_approx((light as Node3D).position.y, WALL_HEIGHT):
					errors.append("%s: потолочный светильник %s не прикреплён к потолку" % [name, light.name])
				var light_bounds := _node_world_bounds(light as Node3D)
				var ceiling_y := global_position.y + WALL_HEIGHT
				if light_bounds.size != Vector3.ZERO and light_bounds.end.y < ceiling_y - 0.06:
					errors.append("%s: корпус светильника %s не касается потолка" % [name, light.name])
	var props := get_node_or_null("Props") as Node3D
	if props == null:
		return
	var prop_data := _get_props()
	for index: int in mini(props.get_child_count(), prop_data.size()):
		var prop := props.get_child(index) as Node3D
		var data: Dictionary = prop_data[index]
		var bounds := _node_world_bounds(prop)
		if bool(data.get("grounded", data["position"].y <= 1.0)) and bounds.size != Vector3.ZERO:
			if absf(bounds.position.y - global_position.y) > 0.04:
				errors.append("%s: объект %s не стоит на полу" % [name, prop.name])
		for portal: Dictionary in _portal_records:
			if not bool(portal["door"]):
				continue
			var center := to_global(_edge_center(portal["cell"], portal["direction"]))
			var keepout := AABB(center + Vector3(-2.2, 0.0, -2.2), Vector3(4.4, 3.8, 4.4))
			if bounds.size != Vector3.ZERO and bounds.intersects(keepout):
				errors.append("%s: объект %s (%s, индекс %d) перекрывает дверь %s" % [
					name, prop.name, data["scene"], index, portal["name"]
				])


func _node_world_bounds(node: Node3D) -> AABB:
	var result := AABB()
	var has_bounds := false
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var world_bounds: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		if not has_bounds:
			result = world_bounds
			has_bounds = true
		else:
			result = result.merge(world_bounds)
	return result


func _validate_cell_connectivity(errors: PackedStringArray) -> void:
	var first_cell := _cell_rooms.keys()[0] as Vector2i
	var visited: Dictionary[Vector2i, bool] = {first_cell: true}
	var queue: Array[Vector2i] = [first_cell]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var neighbour: Vector2i = cell + direction
			if visited.has(neighbour) or not _cell_rooms.has(neighbour):
				continue
			var same_room: bool = _cell_rooms[cell] == _cell_rooms[neighbour]
			if same_room or _portal_edges.has(_edge_key(cell, neighbour)):
				visited[neighbour] = true
				queue.append(neighbour)
	if visited.size() != _cell_rooms.size():
		errors.append("%s: доступны только %d из %d ячеек" % [name, visited.size(), _cell_rooms.size()])


func _world_to_cell(position_value: Vector3) -> Vector2i:
	return Vector2i(floori(position_value.x / CELL_SIZE), floori(position_value.z / CELL_SIZE))


func get_support_samples() -> Array[Vector3]:
	var samples: Array[Vector3] = []
	for cell: Vector2i in _cell_rooms:
		var center := Vector3((cell.x + 0.5) * CELL_SIZE, 0.0, (cell.y + 0.5) * CELL_SIZE)
		for offset: Vector2 in [Vector2(-1.8, -1.8), Vector2(1.8, -1.8), Vector2(-1.8, 1.8), Vector2(1.8, 1.8)]:
			samples.append(center + Vector3(offset.x, 0.0, offset.y))
	return samples


func get_portal_passages() -> Array[Dictionary]:
	var passages: Array[Dictionary] = []
	for portal: Dictionary in _portal_records:
		passages.append({
			"name": portal["name"],
			"center": to_global(_edge_center(portal["cell"], portal["direction"])),
			"direction": Vector3(portal["direction"].x, 0.0, portal["direction"].y),
		})
	return passages
