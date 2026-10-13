extends SceneTree
## Headless traversal check of the opening route (#170).
##
## Builds the full production assembly (generated packages, collisions, authored set dressing), bakes a navigation
## mesh from the static colliders around the route and asks for a walkable path between consecutive route waypoints.
## Waypoints are the centres of floor rectangles of the canonical SVG plans (world plan coordinates, see
## `docs/design/complex_v4/review/opening-route-status.md`). The path of every leg is attributed to the vertical
## shafts it uses, so a leg that silently takes another staircase is visible.
##
## Report mode: blocked legs are printed as `BLOCKED` and counted, but the check still exits 0 while the route is
## known to be incomplete. Pass `-- --strict` to fail on any blocked route leg, `-- --verbose` to print the paths.

const BLOCKOUT_SCENE := preload("res://scenes/complex_v4/complex_v4_blockout.tscn")

## The agent is the standing player capsule (`scenes/player.tscn`: height 1.8 m, radius 0.35 m rounded up to the cell,
## steps up to STEP_MAX_HEIGHT 0.3 m in `scenes/player.gd`). Doors are openings in the generated geometry, so the check
## sees every door open; lock states (G-05) are gameplay, not geometry.
const AGENT_HEIGHT := 1.8
const AGENT_RADIUS := 0.4
const AGENT_MAX_CLIMB := 0.3
const AGENT_MAX_SLOPE := 46.0
const CELL_SIZE := 0.2
const CELL_HEIGHT := 0.1
## Route region: west half of the complex plus the central core (x, y, z min / size).
const BAKE_AABB := AABB(Vector3(-115.0, -13.0, -15.0), Vector3(155.0, 20.0, 100.0))
## A waypoint counts as reached when the path ends this close to it (horizontal metres).
const REACH_TOLERANCE := 0.75
const SETTLE_FRAMES := 4
const MAP_SYNC_FRAMES := 120

## [id, sector, room, world position on the floor]; y is the floor elevation of the level (U 0, L -6, T -11.5).
const WAYPOINTS: Array[Array] = [
	["capsule_hall", "U-EMERGENCY", "капсульный зал", Vector3(-97.22, 0.0, 1.22)],
	["distribution_hall", "U-EMERGENCY", "распределительный холл", Vector3(-72.78, 0.0, 7.89)],
	["route_a_service", "U-ROUTE-A", "служебный / склад", Vector3(-56.67, 0.0, 5.2)],
	["route_a_ventilation", "U-ROUTE-A", "вентиляция", Vector3(-50.0, 0.0, 5.2)],
	["archive_fenced", "L-ARCHIVE-A", "отгороженная часть архива", Vector3(-57.2, -6.0, 14.52)],
	["old_core_hall", "L-OLD-CORE", "распределительный холл старого ядра", Vector3(-71.11, -6.0, 15.93)],
	["old_reserve_cu", "L-OLD-CORE", "старый резервный ЦУ", Vector3(-72.5, -6.0, -3.26)],
	["old_core_access", "L-OLD-CORE", "общий доступ", Vector3(-85.0, -6.0, 31.73)],
	["old_access_vestibule", "T-OLD-ACCESS", "старый служебный вестибюль", Vector3(-87.3, -11.5, 33.45)],
	["energy_generator_hall", "T-ENERGY", "генераторный зал", Vector3(-88.81, -11.5, 5.42)],
	["energy_switchboard", "T-ENERGY", "щитовая", Vector3(-66.94, -11.5, -0.53)],
	["energy_cooling", "T-ENERGY", "охлаждение", Vector3(-66.94, -11.5, 9.78)],
	["old_core_senior_room", "L-OLD-CORE", "комната старшего", Vector3(-64.17, -6.0, 0.02)],
	["control_senior_office", "U-CONTROL", "кабинет старшего", Vector3(-28.21, 0.0, -5.74)],
	["control_operator_hall", "U-CONTROL", "основной операторский зал", Vector3(-23.66, 0.0, 3.53)],
	["lower_core_vestibule", "L-CENTRAL-CORE", "общий вестибюль вертикального узла", Vector3(0.0, -6.0, 17.1)],
	["upper_core_vestibule", "U-CENTRAL-CORE", "общий вестибюль вертикального узла", Vector3(0.0, 0.0, 17.1)],
	["chamber_4_airlock", "U-CHAMBER-4", "главный шлюз", Vector3(-89.95, 0.0, 32.81)],
	["chamber_4_module", "U-CHAMBER-4", "камера 4", Vector3(-91.19, 0.0, 46.25)],
]

## [scene, from, to, kind]. `route` legs are the opening scenes 1-12 in order; the operator room (scene 10) is not
## placed yet (Р-2), so it is routed through candidate A (L-OLD-CORE senior room). `option` legs only inform the
## author's decisions (candidate B, a route that bypasses the closed operator block) and never count as blocked.
const LEGS: Array[Array] = [
	["1-3", "capsule_hall", "distribution_hall", "route"],
	["3-4", "distribution_hall", "route_a_service", "route"],
	["4", "route_a_service", "route_a_ventilation", "route"],
	["4-5", "route_a_ventilation", "archive_fenced", "route"],
	["5-6", "archive_fenced", "old_core_hall", "route"],
	["6-7", "old_core_hall", "old_reserve_cu", "route"],
	["7-8", "old_reserve_cu", "old_core_access", "route"],
	["8", "old_core_access", "old_access_vestibule", "route"],
	["8-9", "old_access_vestibule", "energy_generator_hall", "route"],
	["9", "energy_generator_hall", "energy_switchboard", "route"],
	["9", "energy_switchboard", "energy_cooling", "route"],
	["9-10", "energy_generator_hall", "old_core_senior_room", "route"],
	["10-11", "old_core_senior_room", "chamber_4_airlock", "route"],
	["12", "chamber_4_airlock", "chamber_4_module", "route"],
	["10B", "energy_generator_hall", "control_operator_hall", "option"],
	["10B", "control_operator_hall", "control_senior_office", "option"],
	["11B", "control_operator_hall", "chamber_4_airlock", "option"],
	["11", "old_core_hall", "chamber_4_airlock", "option"],
	["11C", "old_core_hall", "lower_core_vestibule", "option"],
	["11C", "lower_core_vestibule", "upper_core_vestibule", "option"],
	["11C", "upper_core_vestibule", "chamber_4_airlock", "option"],
]

## Shaft rectangles of the vertical transitions in world plan coordinates [x, z, width, depth] (canonical SVG).
const SHAFTS := {
	"VT-ROUTE-A": Rect2(-55.556, 11.867, 6.667, 7.777),
	"VT-OLD-STAIR": Rect2(-102.2, 28.4, 10.0, 13.4),
	"VT-MAIN-STAIR": Rect2(0.0, 0.0, 7.1, 14.6),
	"VT-EAST-STAIR": Rect2(21.1, 7.6, 10.0, 7.9),
	"VT-SERVICE-STAIR": Rect2(-47.8, 53.2, 4.7, 8.6),
}

var _strict := false
var _verbose := false


func _initialize() -> void:
	_strict = OS.get_cmdline_user_args().has("--strict")
	_verbose = OS.get_cmdline_user_args().has("--verbose")
	var blockout := BLOCKOUT_SCENE.instantiate() as ComplexV4Blockout
	root.add_child(blockout)
	for _i: int in SETTLE_FRAMES:
		await physics_frame

	var started := Time.get_ticks_msec()
	var navmesh := _make_navmesh()
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source, blockout)
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)
	var polygons := navmesh.get_polygon_count()
	print("OPENING_ROUTE_NAVMESH polygons=%d vertices=%d bake_ms=%d" % [polygons, navmesh.vertices.size(), Time.get_ticks_msec() - started])

	var map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, CELL_SIZE)
	NavigationServer3D.map_set_cell_height(map, CELL_HEIGHT)
	NavigationServer3D.map_set_active(map, true)
	var region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(region, map)
	NavigationServer3D.region_set_navigation_mesh(region, navmesh)
	var iteration := NavigationServer3D.map_get_iteration_id(map)
	for _i: int in MAP_SYNC_FRAMES:
		if NavigationServer3D.map_get_iteration_id(map) > iteration + 1:
			break
		await physics_frame

	var points := {}
	var missing := 0
	for waypoint: Array in WAYPOINTS:
		var target := waypoint[3] as Vector3
		var on_mesh := NavigationServer3D.map_get_closest_point(map, target)
		var offset := _horizontal(on_mesh - target)
		var floor_gap := absf(on_mesh.y - target.y)
		points[waypoint[0]] = on_mesh
		var ok := offset <= REACH_TOLERANCE and floor_gap <= 0.5
		if not ok:
			missing += 1
		print("OPENING_ROUTE_POINT %s %s %s %s offset=%.2f floor_dy=%.2f" % [
			"ok" if ok else "OFF_MESH", waypoint[0], waypoint[1], _fmt(on_mesh), offset, floor_gap])

	var blocked := 0
	var route_legs := 0
	for leg: Array in LEGS:
		var is_route := str(leg[3]) == "route"
		if is_route:
			route_legs += 1
		var from := points[leg[1]] as Vector3
		var to := points[leg[2]] as Vector3
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		var end := path[path.size() - 1] if not path.is_empty() else from
		var gap := _horizontal(end - to) + absf(end.y - to.y)
		var reached := not path.is_empty() and gap <= REACH_TOLERANCE
		if not reached and is_route:
			blocked += 1
		print("OPENING_ROUTE_LEG %s scene=%s kind=%s %s -> %s length=%.1f verticals=%s%s" % [
			"ok" if reached else "BLOCKED", leg[0], leg[3], leg[1], leg[2], _length(path), _verticals(path),
			"" if reached else " stops_at=%s gap=%.1f" % [_fmt(end), gap]])
		if _verbose:
			print("  path %s" % _fmt_path(path))

	var mode := "strict" if _strict else "report"
	print("OPENING_ROUTE_CHECK mode=%s legs=%d passable=%d blocked=%d waypoints_off_mesh=%d" % [
		mode, route_legs, route_legs - blocked, blocked, missing])
	NavigationServer3D.free_rid(region)
	NavigationServer3D.free_rid(map)
	blockout.queue_free()
	await process_frame
	quit(1 if _strict and (blocked > 0 or missing > 0) else 0)


func _make_navmesh() -> NavigationMesh:
	var navmesh := NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	navmesh.cell_size = CELL_SIZE
	navmesh.cell_height = CELL_HEIGHT
	navmesh.agent_height = AGENT_HEIGHT
	navmesh.agent_radius = AGENT_RADIUS
	navmesh.agent_max_climb = AGENT_MAX_CLIMB
	navmesh.agent_max_slope = AGENT_MAX_SLOPE
	navmesh.filter_baking_aabb = BAKE_AABB
	return navmesh


func _verticals(path: PackedVector3Array) -> String:
	var used := PackedStringArray()
	for i: int in range(1, path.size()):
		if absf(path[i].y - path[i - 1].y) < 0.5:
			continue
		var mid := (path[i] + path[i - 1]) * 0.5
		var name := "?(%.0f,%.0f)" % [mid.x, mid.z]
		for shaft_id: String in SHAFTS:
			if (SHAFTS[shaft_id] as Rect2).grow(1.0).has_point(Vector2(mid.x, mid.z)):
				name = shaft_id
		if used.is_empty() or used[used.size() - 1] != name:
			used.append(name)
	return "[%s]" % ",".join(used)


func _fmt_path(path: PackedVector3Array) -> String:
	var parts := PackedStringArray()
	for point: Vector3 in path:
		parts.append(_fmt(point))
	return " ".join(parts)


func _length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i: int in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
	return total


func _horizontal(delta: Vector3) -> float:
	return Vector2(delta.x, delta.z).length()


func _fmt(point: Vector3) -> String:
	return "(%.1f,%.1f,%.1f)" % [point.x, point.y, point.z]
