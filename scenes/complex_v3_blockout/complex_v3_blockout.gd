@tool
extends Node3D
class_name ComplexV3BlockoutPart

const MEDICAL_PANELS := preload("res://materials/complex_v3/medical_panels.tres")
const COMMAND_PANELS := preload("res://materials/complex_v3/command_panels.tres")
const DOMESTIC_PANELS := preload("res://materials/complex_v3/domestic_panels.tres")
const CONTAINMENT_PANELS := preload("res://materials/complex_v3/containment_panels.tres")
const FREIGHT_PANELS := preload("res://materials/complex_v3/freight_panels.tres")
const UTILITY_PANELS := preload("res://materials/complex_v3/utility_panels.tres")
const HISTORIC_PANELS := preload("res://materials/complex_v3/historic_panels.tres")
const MAIN_CORE_STAIR_SCENE := preload("res://objects/complex_v3/main_core_switchback_stair.tscn")
const EAST_EMERGENCY_STAIR_SCENE := preload("res://objects/complex_v3/east_emergency_switchback_stair.tscn")
const ROUTE_A_STAIR_SCENE := preload("res://objects/complex_v3/route_a_switchback_stair.tscn")

const DEFAULT_HANDOFF_PATH := "res://docs/design/complex_v3/handoff/geometry/complex-handoff.json"
const DEFAULT_VERTICAL_PATH := "res://docs/design/complex_v3/handoff/vertical/vertical-transitions.json"
const FLOOR_THICKNESS := 0.2
const WALL_EPSILON := 0.01
const MIN_SEGMENT_LENGTH := 0.05
const FULL_SEAM_FLOOR_CONNECTION_IDS := ["E-U02"]

@export_file("*.json") var handoff_path: String = DEFAULT_HANDOFF_PATH
@export_file("*.json") var vertical_path: String = DEFAULT_VERTICAL_PATH
@export var build_on_ready := true
@export var build_collisions := true
@export var include_ceilings := true
@export var show_space_labels := false
@export var show_old_incline_debug := false
@export var build_room_spaces := true
@export var build_shared_infrastructure := true
@export var sector_ids := PackedStringArray()
@export var shared_route_space_ids := PackedStringArray()
@export var shared_connection_ids := PackedStringArray()
@export var vertical_transition_ids := PackedStringArray()
@export var preview_shared_infrastructure_when_standalone := false
@export var preview_main_core_verticals_when_standalone := false
@export var show_vertical_debug_geometry := false
@export var editor_preview_enabled := false:
	set(value):
		if editor_preview_enabled == value:
			return
		editor_preview_enabled = value
		_queue_editor_preview_refresh()


@export var editor_preview_show_ceilings := false:
	set(value):
		if editor_preview_show_ceilings == value:
			return
		editor_preview_show_ceilings = value
		_queue_editor_preview_refresh()

var _handoff: Dictionary = {}
var _vertical: Dictionary = {}
var _materials: Dictionary[String, StandardMaterial3D] = {}
var _level_nodes: Dictionary[String, Node3D] = {}
var _spaces_by_id: Dictionary[String, Dictionary] = {}
var _openings_by_space: Dictionary[String, Array] = {}
var _stats: Dictionary[String, int] = {}
var _editor_preview_refresh_pending := false


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		if editor_preview_enabled:
			build_from_handoff()
		return
	if preview_shared_infrastructure_when_standalone and (get_parent() == null or get_parent().name != "Zones"):
		build_shared_infrastructure = true
	if build_on_ready:
		build_from_handoff()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or not editor_preview_enabled:
		return
	if get_node_or_null("Generated") == null:
		_queue_editor_preview_refresh()


func _refresh_editor_preview() -> void:
	_editor_preview_refresh_pending = false
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if editor_preview_enabled:
		build_from_handoff()
	else:
		_clear_generated()


func _queue_editor_preview_refresh() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or _editor_preview_refresh_pending:
		return
	_editor_preview_refresh_pending = true
	_refresh_editor_preview.call_deferred()


func build_from_handoff() -> void:
	_clear_generated()
	_handoff = _load_json(handoff_path)
	_vertical = _load_json(vertical_path)
	if _handoff.is_empty() or _vertical.is_empty():
		return
	_reset_stats()
	_create_materials()
	_create_level_nodes()
	_index_spaces()
	_compile_openings()
	_build_spaces()
	if build_shared_infrastructure:
		_build_connection_corridors()
		_build_vertical_markers()
	set_meta("map_id", str(_handoff.get("map_id", "")))
	set_meta("handoff_artifact_id", str(_handoff.get("artifact_id", "")))
	set_meta("units", str(_handoff.get("units", "")))
	set_meta("sector_ids", sector_ids)
	set_meta("build_role", "infrastructure" if not build_room_spaces else "sector" if not build_shared_infrastructure else "full")


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Не найден файл handoff: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть handoff: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Некорректный JSON handoff: %s" % path)
		return {}
	return parsed as Dictionary


func _clear_generated() -> void:
	var existing := get_node_or_null("Generated")
	if existing != null:
		existing.free()
	_level_nodes.clear()
	_spaces_by_id.clear()
	_openings_by_space.clear()


func _reset_stats() -> void:
	_stats = {
		"spaces": 0,
		"route_spaces": 0,
		"floors": 0,
		"ceilings": 0,
		"walls": 0,
		"colliders": 0,
		"corridors": 0,
		"anchors": 0,
		"transitions": 0,
	}


func _create_materials() -> void:
	_materials.clear()
	_materials["medical"] = MEDICAL_PANELS
	_materials["personnel"] = MEDICAL_PANELS
	_materials["domestic"] = DOMESTIC_PANELS
	_materials["control"] = COMMAND_PANELS
	_materials["containment"] = CONTAINMENT_PANELS
	_materials["historic"] = HISTORIC_PANELS
	_materials["utility"] = UTILITY_PANELS
	_materials["freight"] = FREIGHT_PANELS
	_materials["passenger_route"] = COMMAND_PANELS
	_materials["service_route"] = UTILITY_PANELS
	_materials["freight_route"] = FREIGHT_PANELS
	_materials["stair"] = _material(Color(0.48, 0.35, 0.68, 0.62), 0.7, true)
	_materials["lift"] = _material(Color(0.10, 0.18, 0.22, 1.0), 0.52)
	_materials["vertical_debug"] = _material(Color(0.20, 0.56, 0.76, 0.32), 0.65, true)
	_materials["old_incline"] = HISTORIC_PANELS


func _material(color: Color, roughness: float, transparent := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	if transparent:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result


func _create_level_nodes() -> void:
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	for level_value: Variant in _handoff.get("levels", []):
		var level := level_value as Dictionary
		var level_id := str(level["id"])
		var node := Node3D.new()
		node.name = level_id
		node.set_meta("level_id", level_id)
		node.set_meta("floor_y", float(level["floor_y"]))
		generated.add_child(node)
		_level_nodes[level_id] = node
	var connectors := Node3D.new()
	connectors.name = "Connections"
	generated.add_child(connectors)
	_level_nodes["Connections"] = connectors
	var verticals := Node3D.new()
	verticals.name = "VerticalTransitions"
	generated.add_child(verticals)
	_level_nodes["VerticalTransitions"] = verticals


func _index_spaces() -> void:
	for space_value: Variant in _handoff.get("spaces", []):
		var space := space_value as Dictionary
		_spaces_by_id[str(space["id"])] = space
	for route_value: Variant in _handoff.get("route_spaces", []):
		var route := route_value as Dictionary
		_spaces_by_id[str(route["id"])] = route


func _compile_openings() -> void:
	for portal_value: Variant in _handoff.get("internal_portals", []):
		var portal := portal_value as Dictionary
		for space_id_value: Variant in portal["between"]:
			_add_opening(str(space_id_value), portal["segment_xz"], float(portal["height"]))
	for portal_value: Variant in _handoff.get("external_portals", []):
		var portal := portal_value as Dictionary
		_add_opening(str(portal["space"]), portal["segment_xz"], float(portal["height"]))
	for corridor_value: Variant in _handoff.get("connection_corridors", []):
		var corridor := corridor_value as Dictionary
		if not _shared_connection_is_included(str(corridor["connection_id"])):
			continue
		for point_value: Variant in [corridor["centerline_xz"][0], corridor["centerline_xz"][-1]]:
			var point := _vector2(point_value)
			for route_value: Variant in _handoff.get("route_spaces", []):
				var route := route_value as Dictionary
				var bounds: Array = route["bounds_xz"]
				if _point_on_boundary(point, bounds):
					_add_centered_opening(str(route["id"]), point, bounds, float(corridor["width"]), float(corridor["clear_height"]))
	for transition_value: Variant in _handoff.get("controlled_technical_transitions", []):
		var transition := transition_value as Dictionary
		var points: Array = transition["centerline_xz"]
		_add_centered_opening("T-TECH", _vector2(points[0]), _spaces_by_id["T-TECH"]["bounds_xz"], float(transition["width"]), float(transition["clear_height"]))
		_add_centered_opening("T-FRT", _vector2(points[-1]), _spaces_by_id["T-FRT"]["bounds_xz"], float(transition["width"]), float(transition["clear_height"]))


func _add_opening(space_id: String, segment: Array, height: float) -> void:
	if not _openings_by_space.has(space_id):
		_openings_by_space[space_id] = []
	_openings_by_space[space_id].append({"segment": segment, "height": height})


func _add_centered_opening(space_id: String, point: Vector2, bounds: Array, width: float, height: float) -> void:
	var x0 := float(bounds[0])
	var z0 := float(bounds[1])
	var x1 := float(bounds[2])
	var z1 := float(bounds[3])
	var half := width * 0.5
	var segment: Array
	if absf(point.x - x0) <= WALL_EPSILON or absf(point.x - x1) <= WALL_EPSILON:
		segment = [[point.x, clampf(point.y - half, z0, z1)], [point.x, clampf(point.y + half, z0, z1)]]
	else:
		segment = [[clampf(point.x - half, x0, x1), point.y], [clampf(point.x + half, x0, x1), point.y]]
	_add_opening(space_id, segment, height)


func _build_spaces() -> void:
	if build_room_spaces:
		for space_value: Variant in _handoff.get("spaces", []):
			var space := space_value as Dictionary
			if _space_is_included(space):
				_build_space(space, false)
	if build_shared_infrastructure:
		for route_value: Variant in _handoff.get("route_spaces", []):
			var route := route_value as Dictionary
			if _shared_route_space_is_included(str(route["id"])):
				_build_space(route, true)


func _space_is_included(space: Dictionary) -> bool:
	if not build_room_spaces:
		return false
	return sector_ids.is_empty() or sector_ids.has(str(space.get("sector_id", "")))


func _shared_route_space_is_included(route_space_id: String) -> bool:
	return shared_route_space_ids.is_empty() or shared_route_space_ids.has(route_space_id)


func _shared_connection_is_included(connection_id: String) -> bool:
	return shared_connection_ids.is_empty() or shared_connection_ids.has(connection_id)


func _vertical_transition_is_included(transition_id: String) -> bool:
	return vertical_transition_ids.is_empty() or vertical_transition_ids.has(transition_id)


func _vertical_anchor_is_included(anchor_id: String) -> bool:
	if vertical_transition_ids.is_empty():
		return true
	for transition_value: Variant in _vertical.get("transitions", []):
		var transition := transition_value as Dictionary
		if _vertical_transition_is_included(str(transition["id"])) and str(transition.get("anchor", "")) == anchor_id:
			return true
	return false


func _controlled_transition_is_included(transition: Dictionary) -> bool:
	if shared_connection_ids.is_empty():
		return true
	for connection_value: Variant in transition.get("represents_connections", []):
		if shared_connection_ids.has(str(connection_value)):
			return true
	return false


func _build_space(space: Dictionary, is_route: bool) -> void:
	var level_id := str(space.get("level", _level_for_floor(float(space["floor_y"]))))
	var parent := _level_nodes.get(level_id) as Node3D
	if parent == null:
		push_error("Неизвестный уровень пространства %s: %s" % [space["id"], level_id])
		return
	var root := Node3D.new()
	root.name = _safe_name(str(space["id"]))
	root.set_meta("space_id", str(space["id"]))
	root.set_meta("sector_id", str(space.get("sector_id", space["id"])))
	root.set_meta("level_id", level_id)
	root.set_meta("kind", str(space.get("kind", "room")))
	parent.add_child(root)
	if is_route and str(space.get("kind", "")) == "cable_gallery":
		_build_overlay_route(root, space)
		_stats["route_spaces"] += 1
		return
	var bounds: Array = space["bounds_xz"]
	var floor_y := float(space["floor_y"])
	var height := float(space["clear_height"])
	var thickness := float(space.get("wall_thickness", 0.35 if is_route else 0.3))
	var material := _material_for_space(space, is_route)
	var space_id := str(space["id"])
	var open_vertical := space_id in [
		"U-CENTRAL-CORE/passenger_elevator",
		"U-CENTRAL-CORE/main_stair",
		"L-CENTRAL-CORE/passenger_elevator",
		"L-CENTRAL-CORE/main_stair",
		"U-EAST-SUPPORT/emergency_stair",
		"U-ROUTE-A/stair_landing",
		"L-ARCHIVE-A/route_a_stair",
	]
	if not open_vertical:
		_build_floor(root, bounds, floor_y, material)
	_build_walls(root, str(space["id"]), bounds, floor_y, height, thickness, material)
	_build_special_space_features(root, space_id, bounds, floor_y, material)
	if _ceilings_enabled() and not open_vertical:
		_build_ceiling(root, bounds, floor_y + height, material)
	if show_space_labels:
		_add_label(root, space, bounds, floor_y)
	_stats["route_spaces" if is_route else "spaces"] += 1


func _build_special_space_features(parent: Node3D, space_id: String, bounds: Array, floor_y: float, material: Material) -> void:
	if space_id == "U-EAST-SUPPORT/emergency_stair":
		var center := _bounds_center(bounds)
		var stair := EAST_EMERGENCY_STAIR_SCENE.instantiate() as EastEmergencySwitchbackStair
		stair.name = "EastEmergencySwitchbackStair"
		stair.position = Vector3(center.x, floor_y, center.y)
		stair.build_collisions = _collisions_enabled()
		parent.add_child(stair)
		return
	if space_id.ends_with("CENTRAL-CORE/main_stair"):
		_build_main_core_stair_opening(parent, bounds, floor_y, material)
		return
	if not preview_main_core_verticals_when_standalone:
		return
	if space_id.ends_with("CENTRAL-CORE/passenger_elevator"):
		var center := _bounds_center(bounds)
		var size := _bounds_size(bounds)
		_add_box(parent, "ElevatorLandingFloor", Vector3(center.x, floor_y - FLOOR_THICKNESS * 0.5, center.y), Vector3(size.x, FLOOR_THICKNESS, size.y), material, _collisions_enabled())
		_build_passenger_elevator_cabin(parent, bounds, floor_y)


func _build_main_core_stair_opening(parent: Node3D, bounds: Array, floor_y: float, material: Material) -> void:
	var x0 := float(bounds[0])
	var z0 := float(bounds[1])
	var x1 := float(bounds[2])
	var z1 := float(bounds[3])
	var center := _bounds_center(bounds)
	var opening_half_width := 2.95
	var opening_x0 := center.x - opening_half_width
	var opening_x1 := center.x + opening_half_width
	var opening_z0 := center.y - 5.25
	var opening_z1 := center.y + 3.75
	_add_floor_panel(parent, "StairOpeningNorthSlab", [x0, z0, x1, opening_z0], floor_y, material)
	_add_floor_panel(parent, "StairOpeningSouthSlab", [x0, opening_z1, x1, z1], floor_y, material)
	_add_floor_panel(parent, "StairOpeningWestSlab", [x0, opening_z0, opening_x0, opening_z1], floor_y, material)
	_add_floor_panel(parent, "StairOpeningEastSlab", [opening_x1, opening_z0, x1, opening_z1], floor_y, material)


func _add_floor_panel(parent: Node3D, node_name: String, bounds: Array, floor_y: float, material: Material) -> void:
	var center := _bounds_center(bounds)
	var size := _bounds_size(bounds)
	_add_box(parent, node_name, Vector3(center.x, floor_y - FLOOR_THICKNESS * 0.5, center.y), Vector3(size.x, FLOOR_THICKNESS, size.y), material, _collisions_enabled())


func _build_passenger_elevator_cabin(parent: Node3D, bounds: Array, floor_y: float) -> void:
	var center := _bounds_center(bounds)
	var cabin_width := 2.6
	var cabin_depth := 2.8
	var cabin_height := 2.4
	var wall := 0.12
	_add_box(parent, "CabinFloor", Vector3(center.x, floor_y + 0.05, center.y), Vector3(cabin_width, 0.10, cabin_depth), _materials["lift"], _collisions_enabled())
	_add_box(parent, "CabinBack", Vector3(center.x, floor_y + cabin_height * 0.5, center.y - cabin_depth * 0.5), Vector3(cabin_width, cabin_height, wall), _materials["lift"], _collisions_enabled())
	_add_box(parent, "CabinWest", Vector3(center.x - cabin_width * 0.5, floor_y + cabin_height * 0.5, center.y), Vector3(wall, cabin_height, cabin_depth), _materials["lift"], _collisions_enabled())
	_add_box(parent, "CabinEast", Vector3(center.x + cabin_width * 0.5, floor_y + cabin_height * 0.5, center.y), Vector3(wall, cabin_height, cabin_depth), _materials["lift"], _collisions_enabled())
	_add_box(parent, "CabinCeiling", Vector3(center.x, floor_y + cabin_height, center.y), Vector3(cabin_width, 0.12, cabin_depth), _materials["lift"], false)
	_add_box(parent, "CabinThreshold", Vector3(center.x, floor_y + 0.10, center.y + cabin_depth * 0.5), Vector3(cabin_width, 0.08, 0.22), _materials["lift"], _collisions_enabled())


func _build_overlay_route(parent: Node3D, space: Dictionary) -> void:
	var bounds: Array = space["bounds_xz"]
	var center := _bounds_center(bounds)
	var size := _bounds_size(bounds)
	_add_box(parent, "ServiceOverlay", Vector3(center.x, float(space["floor_y"]) + 0.04, center.y), Vector3(size.x, 0.08, size.y), _materials["service_route"], false)


func _build_floor(parent: Node3D, bounds: Array, floor_y: float, material: Material) -> void:
	var center := _bounds_center(bounds)
	var size := _bounds_size(bounds)
	_add_box(parent, "Floor", Vector3(center.x, floor_y - FLOOR_THICKNESS * 0.5, center.y), Vector3(size.x, FLOOR_THICKNESS, size.y), material, _collisions_enabled())
	_stats["floors"] += 1


func _build_ceiling(parent: Node3D, bounds: Array, ceiling_y: float, material: Material) -> void:
	var center := _bounds_center(bounds)
	var size := _bounds_size(bounds)
	_add_box(parent, "Ceiling", Vector3(center.x, ceiling_y + FLOOR_THICKNESS * 0.5, center.y), Vector3(size.x, FLOOR_THICKNESS, size.y), material, _collisions_enabled())
	_stats["ceilings"] += 1


func _build_walls(parent: Node3D, space_id: String, bounds: Array, floor_y: float, height: float, thickness: float, material: Material) -> void:
	var x0 := float(bounds[0])
	var z0 := float(bounds[1])
	var x1 := float(bounds[2])
	var z1 := float(bounds[3])
	_build_wall_side(parent, space_id, "North", x0, x1, z0, true, floor_y, height, thickness, material)
	_build_wall_side(parent, space_id, "South", x0, x1, z1, true, floor_y, height, thickness, material)
	_build_wall_side(parent, space_id, "West", z0, z1, x0, false, floor_y, height, thickness, material)
	_build_wall_side(parent, space_id, "East", z0, z1, x1, false, floor_y, height, thickness, material)


func _build_wall_side(parent: Node3D, space_id: String, side_name: String, start: float, end: float, fixed: float, horizontal: bool, floor_y: float, height: float, thickness: float, material: Material) -> void:
	var openings := _openings_on_side(space_id, fixed, horizontal, start, end)
	var merged := _merge_intervals(openings)
	var cursor := start
	var index := 0
	for opening: Dictionary in merged:
		var opening_start := float(opening["start"])
		var opening_end := float(opening["end"])
		if opening_start - cursor > MIN_SEGMENT_LENGTH:
			_add_wall_segment(parent, "%s_%02d" % [side_name, index], cursor, opening_start, fixed, horizontal, floor_y, height, thickness, material)
			index += 1
		var opening_height := minf(float(opening["height"]), height)
		if height - opening_height > MIN_SEGMENT_LENGTH:
			_add_wall_segment(parent, "%s_Lintel_%02d" % [side_name, index], opening_start, opening_end, fixed, horizontal, floor_y + opening_height, height - opening_height, thickness, material)
			index += 1
		cursor = maxf(cursor, opening_end)
	if end - cursor > MIN_SEGMENT_LENGTH:
		_add_wall_segment(parent, "%s_%02d" % [side_name, index], cursor, end, fixed, horizontal, floor_y, height, thickness, material)


func _openings_on_side(space_id: String, fixed: float, horizontal: bool, start: float, end: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for opening_value: Variant in _openings_by_space.get(space_id, []):
		var opening := opening_value as Dictionary
		var segment: Array = opening["segment"]
		var a := _vector2(segment[0])
		var b := _vector2(segment[1])
		var same_side := absf(a.y - fixed) <= WALL_EPSILON and absf(b.y - fixed) <= WALL_EPSILON if horizontal else absf(a.x - fixed) <= WALL_EPSILON and absf(b.x - fixed) <= WALL_EPSILON
		if not same_side:
			continue
		var lo := minf(a.x, b.x) if horizontal else minf(a.y, b.y)
		var hi := maxf(a.x, b.x) if horizontal else maxf(a.y, b.y)
		lo = clampf(lo, start, end)
		hi = clampf(hi, start, end)
		if hi - lo > MIN_SEGMENT_LENGTH:
			result.append({"start": lo, "end": hi, "height": float(opening["height"])})
	return result


func _merge_intervals(intervals: Array[Dictionary]) -> Array[Dictionary]:
	if intervals.is_empty():
		return []
	intervals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["start"]) < float(b["start"]))
	var result: Array[Dictionary] = []
	for interval: Dictionary in intervals:
		if result.is_empty() or float(interval["start"]) > float(result[-1]["end"]) + WALL_EPSILON:
			result.append(interval.duplicate())
		else:
			result[-1]["end"] = maxf(float(result[-1]["end"]), float(interval["end"]))
			result[-1]["height"] = maxf(float(result[-1]["height"]), float(interval["height"]))
	return result


func _add_wall_segment(parent: Node3D, node_name: String, start: float, end: float, fixed: float, horizontal: bool, base_y: float, height: float, thickness: float, material: Material) -> void:
	var length := end - start
	if length <= MIN_SEGMENT_LENGTH or height <= MIN_SEGMENT_LENGTH:
		return
	var center: Vector3
	var size: Vector3
	if horizontal:
		center = Vector3((start + end) * 0.5, base_y + height * 0.5, fixed)
		size = Vector3(length, height, thickness)
	else:
		center = Vector3(fixed, base_y + height * 0.5, (start + end) * 0.5)
		size = Vector3(thickness, height, length)
	_add_box(parent, node_name, center, size, material, _collisions_enabled())
	_stats["walls"] += 1


func _build_connection_corridors() -> void:
	var parent := _level_nodes["Connections"]
	for corridor_value: Variant in _handoff.get("connection_corridors", []):
		var corridor := corridor_value as Dictionary
		if not _shared_connection_is_included(str(corridor["connection_id"])):
			continue
		if str(corridor["connection_id"]) == "E-X05":
			continue
		var points: Array = corridor["centerline_xz"]
		var start := _vector2(points[0])
		var end := _vector2(points[-1])
		var delta := end - start
		if delta.length() <= MIN_SEGMENT_LENGTH:
			continue
		var connection_id := str(corridor["connection_id"])
		var floor_y := _floor_for_connection(connection_id)
		var floor_width := _connection_floor_width(connection_id, delta, float(corridor["width"]))
		_build_corridor_segment(parent, str(corridor["id"]), start, end, floor_y, floor_width, float(corridor["clear_height"]), _materials["service_route"])
		_stats["corridors"] += 1
	for transition_value: Variant in _handoff.get("controlled_technical_transitions", []):
		var transition := transition_value as Dictionary
		if not _controlled_transition_is_included(transition):
			continue
		var points: Array = transition["centerline_xz"]
		_build_corridor_segment(parent, str(transition["id"]), _vector2(points[0]), _vector2(points[-1]), -11.5, float(transition["width"]), float(transition["clear_height"]), _materials["service_route"])
		_stats["corridors"] += 1


func _build_corridor_segment(parent: Node3D, corridor_id: String, start: Vector2, end: Vector2, floor_y: float, width: float, height: float, material: Material) -> void:
	var delta := end - start
	var length := delta.length()
	if length <= MIN_SEGMENT_LENGTH:
		return
	var direction := Vector3(delta.x, 0.0, delta.y).normalized()
	var side := Vector3(direction.z, 0.0, -direction.x)
	var basis := Basis(side, Vector3.UP, direction)
	var midpoint := Vector3((start.x + end.x) * 0.5, floor_y, (start.y + end.y) * 0.5)
	var root := Node3D.new()
	root.name = _safe_name(corridor_id)
	root.set_meta("connection_id", corridor_id)
	root.set_meta("clear_height", height)
	parent.add_child(root)
	_add_oriented_box(root, "Floor", Transform3D(basis, midpoint + Vector3(0.0, -FLOOR_THICKNESS * 0.5, 0.0)), Vector3(width, FLOOR_THICKNESS, length), material, _collisions_enabled())


func _build_vertical_markers() -> void:
	var parent := _level_nodes["VerticalTransitions"]
	var anchors: Array = _vertical.get("anchors", [])
	for anchor_value: Variant in anchors:
		var anchor := anchor_value as Dictionary
		if not _vertical_anchor_is_included(str(anchor["id"])):
			continue
		var root := Node3D.new()
		root.name = _safe_name(str(anchor["id"]))
		root.set_meta("anchor_id", str(anchor["id"]))
		parent.add_child(root)
		if anchor.has("position_xz"):
			var point := _vector2(anchor["position_xz"])
			var levels: Array = anchor["levels"]
			var top := _level_datum(str(levels[0])) + 2.0
			var bottom := _level_datum(str(levels[-1]))
			if show_vertical_debug_geometry:
				_add_box(root, "Datum", Vector3(point.x, (top + bottom) * 0.5, point.y), Vector3(0.35, top - bottom, 0.35), _materials["vertical_debug"], false)
		else:
			var z := float(anchor["centerline_z"])
			if show_vertical_debug_geometry:
				_add_box(root, "HeavySpineDatum", Vector3(-39.0, -5.75, z), Vector3(142.0, 0.12, 0.35), _materials["vertical_debug"], false)
		_stats["anchors"] += 1
	for transition_value: Variant in _vertical.get("transitions", []):
		var transition := transition_value as Dictionary
		if not _vertical_transition_is_included(str(transition["id"])):
			continue
		_build_transition_marker(parent, transition)
		_stats["transitions"] += 1


func _build_transition_marker(parent: Node3D, transition: Dictionary) -> void:
	var root := Node3D.new()
	root.name = _safe_name(str(transition["id"]))
	root.set_meta("transition_id", str(transition["id"]))
	root.set_meta("kind", str(transition["kind"]))
	parent.add_child(root)
	if str(transition["kind"]) == "historic_inclined_freight_tunnel":
		root.visible = show_old_incline_debug
	if transition.has("shaft_bounds_xz"):
		var bounds: Array = transition["shaft_bounds_xz"]
		var center := _bounds_center(bounds)
		var size := _bounds_size(bounds)
		var bottom := -11.5
		var top := 4.5
		if show_vertical_debug_geometry:
			_add_box(root, "ShaftEnvelope", Vector3(center.x, (top + bottom) * 0.5, center.y), Vector3(size.x, top - bottom, size.y), _materials["vertical_debug"], false)
		if str(transition["id"]) == "VT-MAIN-ELEVATOR":
			_build_passenger_elevator_cabin(root, bounds, 0.0)
	elif transition.has("centerline_xyz"):
		var points: Array = transition["centerline_xyz"]
		for index: int in range(points.size() - 1):
			var a := _vector3_x_y_z(points[index])
			var b := _vector3_x_y_z(points[index + 1])
			_add_ramp_segment(root, "Ramp_%02d" % index, a, b, float(transition["clear_width"]), _materials["old_incline"])
	elif transition.has("center_xz"):
		if str(transition["id"]) == "VT-MAIN-STAIR":
			var center_xz := _vector2(transition["center_xz"])
			var stair := MAIN_CORE_STAIR_SCENE.instantiate() as MainCoreSwitchbackStair
			stair.name = "MainCoreSwitchbackStair"
			stair.position = Vector3(center_xz.x, 0.0, center_xz.y)
			stair.build_collisions = _collisions_enabled()
			root.add_child(stair)
		elif str(transition["id"]) == "VT-ROUTE-A":
			var center_xz := _vector2(transition["center_xz"])
			var stair := ROUTE_A_STAIR_SCENE.instantiate() as RouteASwitchbackStair
			stair.name = "RouteASwitchbackStair"
			stair.position = Vector3(center_xz.x, 0.0, center_xz.y)
			stair.build_collisions = _collisions_enabled()
			root.add_child(stair)
		else:
			var center_xz := _vector2(transition["center_xz"])
			var connects: Array = transition.get("connects", ["LV-U", "LV-L"])
			var top := _level_datum(str(connects[0])) + 0.25
			var bottom := _level_datum(str(connects[-1]))
			if show_vertical_debug_geometry:
				_add_box(root, "StairEnvelope", Vector3(center_xz.x, (top + bottom) * 0.5, center_xz.y), Vector3(float(transition.get("clear_width", 1.5)), top - bottom, 2.2), _materials["vertical_debug"], false)


func _add_ramp_segment(parent: Node3D, node_name: String, start: Vector3, end: Vector3, width: float, material: Material) -> void:
	var delta := end - start
	var length := delta.length()
	if length <= MIN_SEGMENT_LENGTH:
		return
	var direction := delta.normalized()
	var side := Vector3.UP.cross(direction).normalized()
	if side.length() <= MIN_SEGMENT_LENGTH:
		side = Vector3.RIGHT
	var up := direction.cross(side).normalized()
	var basis := Basis(side, up, direction)
	_add_oriented_box(parent, node_name, Transform3D(basis, (start + end) * 0.5), Vector3(width, FLOOR_THICKNESS, length), material, _collisions_enabled())


func _collisions_enabled() -> bool:
	return build_collisions and not Engine.is_editor_hint()


func _ceilings_enabled() -> bool:
	return include_ceilings and (not Engine.is_editor_hint() or editor_preview_show_ceilings)


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
		_stats["colliders"] += 1


func _add_label(parent: Node3D, space: Dictionary, bounds: Array, floor_y: float) -> void:
	var center := _bounds_center(bounds)
	var label := Label3D.new()
	label.name = "Label"
	label.text = str(space["id"])
	label.position = Vector3(center.x, floor_y + 0.03, center.y)
	label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	label.font_size = 56
	label.modulate = Color(0.92, 0.96, 1.0)
	label.outline_size = 8
	parent.add_child(label)


func _material_for_space(space: Dictionary, is_route: bool) -> Material:
	if is_route:
		var kind := str(space.get("kind", ""))
		if kind.contains("freight") or kind.contains("heavy"):
			return _materials["freight_route"]
		if kind.contains("passenger"):
			return _materials["passenger_route"]
		return _materials["service_route"]
	var sector_id := str(space.get("sector_id", ""))
	if sector_id.contains("MEDBAY") or sector_id.contains("EMERGENCY"):
		return _materials["medical"]
	if sector_id.contains("DOMESTIC") or sector_id.contains("EAST-SUPPORT"):
		return _materials["domestic"]
	if sector_id.contains("CHAMBER") or sector_id.contains("SLEEP"):
		return _materials["containment"]
	if sector_id.contains("CONTROL") or sector_id.contains("SECURITY"):
		return _materials["control"]
	if sector_id.contains("OLD") or sector_id.contains("ARCHIVE"):
		return _materials["historic"]
	if sector_id.contains("FREIGHT"):
		return _materials["freight"]
	if sector_id.begins_with("T-"):
		return _materials["utility"]
	return _materials["personnel"]


func _floor_for_connection(connection_id: String) -> float:
	for portal_value: Variant in _handoff.get("external_portals", []):
		var portal := portal_value as Dictionary
		if str(portal["connection_id"]) == connection_id:
			var space := _spaces_by_id.get(str(portal["space"])) as Dictionary
			if space != null:
				return float(space["floor_y"])
	return 0.0


func _connection_floor_width(connection_id: String, delta: Vector2, fallback_width: float) -> float:
	if not FULL_SEAM_FLOOR_CONNECTION_IDS.has(connection_id):
		return fallback_width
	var bounds_by_space: Array[Array] = []
	for portal_value: Variant in _handoff.get("external_portals", []):
		var portal := portal_value as Dictionary
		if str(portal["connection_id"]) != connection_id:
			continue
		var space := _spaces_by_id.get(str(portal["space"])) as Dictionary
		if space != null:
			bounds_by_space.append(space["bounds_xz"] as Array)
	if bounds_by_space.size() != 2:
		return fallback_width
	var first := bounds_by_space[0]
	var second := bounds_by_space[1]
	var overlap: float
	if absf(delta.x) >= absf(delta.y):
		overlap = minf(float(first[3]), float(second[3])) - maxf(float(first[1]), float(second[1]))
	else:
		overlap = minf(float(first[2]), float(second[2])) - maxf(float(first[0]), float(second[0]))
	return maxf(fallback_width, overlap)


func _level_for_floor(floor_y: float) -> String:
	for level_value: Variant in _handoff.get("levels", []):
		var level := level_value as Dictionary
		if is_equal_approx(float(level["floor_y"]), floor_y):
			return str(level["id"])
	return ""


func _level_datum(level_id: String) -> float:
	return float((_vertical.get("level_datums", {}) as Dictionary).get(level_id, 0.0))


func _point_on_boundary(point: Vector2, bounds: Array) -> bool:
	var x0 := float(bounds[0])
	var z0 := float(bounds[1])
	var x1 := float(bounds[2])
	var z1 := float(bounds[3])
	var on_vertical := (absf(point.x - x0) <= WALL_EPSILON or absf(point.x - x1) <= WALL_EPSILON) and point.y >= z0 - WALL_EPSILON and point.y <= z1 + WALL_EPSILON
	var on_horizontal := (absf(point.y - z0) <= WALL_EPSILON or absf(point.y - z1) <= WALL_EPSILON) and point.x >= x0 - WALL_EPSILON and point.x <= x1 + WALL_EPSILON
	return on_vertical or on_horizontal


func _bounds_center(bounds: Array) -> Vector2:
	return Vector2((float(bounds[0]) + float(bounds[2])) * 0.5, (float(bounds[1]) + float(bounds[3])) * 0.5)


func _bounds_size(bounds: Array) -> Vector2:
	return Vector2(float(bounds[2]) - float(bounds[0]), float(bounds[3]) - float(bounds[1]))


func _vector2(value: Variant) -> Vector2:
	var values := value as Array
	return Vector2(float(values[0]), float(values[1]))


func _vector3_x_y_z(value: Variant) -> Vector3:
	var values := value as Array
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _safe_name(value: String) -> String:
	return value.replace("/", "__").replace(":", "_").replace(" ", "_")


func get_build_stats() -> Dictionary:
	return _stats.duplicate()


func get_portal_passages() -> Array[Dictionary]:
	var passages: Array[Dictionary] = []
	for portal_value: Variant in _handoff.get("internal_portals", []):
		var portal := portal_value as Dictionary
		var first_space := _spaces_by_id[str(portal["between"][0])]
		var second_space := _spaces_by_id[str(portal["between"][1])]
		if not _space_is_included(first_space) or not _space_is_included(second_space):
			continue
		passages.append(_portal_passage(portal, float(first_space["floor_y"]), ""))
	for portal_value: Variant in _handoff.get("external_portals", []):
		var portal := portal_value as Dictionary
		if not bool(portal.get("traversable", true)):
			continue
		var space := _spaces_by_id[str(portal["space"])]
		if not _space_is_included(space):
			continue
		passages.append(_portal_passage(portal, float(space["floor_y"]), str(portal.get("side", ""))))
	return passages


func _portal_passage(portal: Dictionary, floor_y: float, declared_side: String) -> Dictionary:
	var segment: Array = portal["segment_xz"]
	var a := _vector2(segment[0])
	var b := _vector2(segment[1])
	var center := (a + b) * 0.5
	var direction: Vector3
	if declared_side == "west":
		direction = Vector3.LEFT
	elif declared_side == "east":
		direction = Vector3.RIGHT
	elif declared_side == "north":
		direction = Vector3.FORWARD
	elif declared_side == "south":
		direction = Vector3.BACK
	elif absf(a.x - b.x) <= WALL_EPSILON:
		direction = Vector3.RIGHT
	else:
		direction = Vector3.BACK
	var test_half_depth := 0.8
	if portal.has("between"):
		var minimum_normal_depth := INF
		var vertical_boundary := absf(a.x - b.x) <= WALL_EPSILON
		for space_id: Variant in portal["between"]:
			var bounds: Array = _spaces_by_id[str(space_id)]["bounds_xz"]
			var normal_depth := float(bounds[2]) - float(bounds[0]) if vertical_boundary else float(bounds[3]) - float(bounds[1])
			minimum_normal_depth = minf(minimum_normal_depth, normal_depth)
		test_half_depth = minf(test_half_depth, maxf(0.2, minimum_normal_depth - 0.6))
	return {
		"id": str(portal["id"]),
		"type": str(portal.get("type", "")),
		"center": Vector3(center.x, floor_y + 1.05, center.y),
		"direction": direction,
		"width": float(portal["width"]),
		"height": float(portal["height"]),
		"test_half_depth": test_half_depth,
	}


func validate_against_handoff() -> PackedStringArray:
	var errors := PackedStringArray()
	if _handoff.is_empty() or _vertical.is_empty():
		errors.append("Handoff data is not loaded")
		return errors
	if str(_handoff.get("status", "")) != "verified":
		errors.append("Geometry handoff is not verified")
	if str(_handoff.get("units", "")) != "m":
		errors.append("Handoff units are not meters")
	var expected_spaces := 0
	for space_value: Variant in _handoff.get("spaces", []):
		if _space_is_included(space_value as Dictionary):
			expected_spaces += 1
	if _stats["spaces"] != expected_spaces:
		errors.append("Expected %d room spaces, built %d" % [expected_spaces, _stats["spaces"]])
	var expected_routes := 0
	var expected_anchors := 0
	var expected_transitions := 0
	if build_shared_infrastructure:
		for route_value: Variant in _handoff.get("route_spaces", []):
			if _shared_route_space_is_included(str((route_value as Dictionary)["id"])):
				expected_routes += 1
		for anchor_value: Variant in _vertical.get("anchors", []):
			if _vertical_anchor_is_included(str((anchor_value as Dictionary)["id"])):
				expected_anchors += 1
		for transition_value: Variant in _vertical.get("transitions", []):
			if _vertical_transition_is_included(str((transition_value as Dictionary)["id"])):
				expected_transitions += 1
	if _stats["route_spaces"] != expected_routes:
		errors.append("Expected %d route spaces, built %d" % [expected_routes, _stats["route_spaces"]])
	if _stats["anchors"] != expected_anchors:
		errors.append("Expected %d anchors, built %d" % [expected_anchors, _stats["anchors"]])
	if _stats["transitions"] != expected_transitions:
		errors.append("Expected %d transition records, built %d" % [expected_transitions, _stats["transitions"]])
	if _level_nodes.size() != 5:
		errors.append("Expected three levels plus connection groups")
	if expected_spaces + expected_routes > 0 and _stats["colliders"] <= 0:
		errors.append("No collision geometry was built")
	return errors


func get_configured_sector_ids() -> PackedStringArray:
	return sector_ids.duplicate()


func get_primary_sector_id() -> String:
	return sector_ids[0] if not sector_ids.is_empty() else ""


func get_sector_level() -> String:
	for space_value: Variant in _handoff.get("spaces", []):
		var space := space_value as Dictionary
		if _space_is_included(space):
			return str(space.get("level", _level_for_floor(float(space["floor_y"]))))
	return ""


func get_focus_point() -> Vector3:
	for space_value: Variant in _handoff.get("spaces", []):
		var space := space_value as Dictionary
		if _space_is_included(space):
			var center := _bounds_center(space["bounds_xz"])
			return Vector3(center.x, float(space["floor_y"]) + 1.1, center.y)
	return Vector3.ZERO


func set_level_filter(level_id: String) -> void:
	for candidate: String in ["LV-U", "LV-L", "LV-T"]:
		var level := get_node_or_null("Generated/%s" % candidate) as Node3D
		if level != null:
			level.visible = level_id == "ALL" or level_id == candidate
	var connections := get_node_or_null("Generated/Connections") as Node3D
	if connections != null:
		connections.visible = level_id == "ALL"
	var verticals := get_node_or_null("Generated/VerticalTransitions") as Node3D
	if verticals != null:
		verticals.visible = level_id == "ALL"
