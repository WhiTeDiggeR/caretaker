@tool
class_name BreachWall
extends StaticBody3D

## A wall cracked by a fallen load (#178): a crack the player notices, then breaks open with a
## tool. States: CRACK — the plug in the opening blocks the way, inspecting it tells that the
## hands are not enough; with the tool flag the plug is broken by holding the interact action,
## one hit per hold, `hits_required` hits in all; OPEN — a hole one can walk through.
## The wall, the plug and the rubble share one material (#211): the plug is the broken-in part
## of the same wall, its outline jagged. The crack is a real slit through the plug — the plug
## is two pieces with a gap that each hit widens, so the room light shines through it.
## The state lives in GameState flags (`flag`, and the hits done in `<flag>_hits`), so it is
## saved and loaded with the playthrough. The room behind the wall has its own light that turns
## on with the power of `section`; a second light just behind the crack throws a streak through it.
## The root is in the group `opening_route_passable`: the opening route check (#177) builds
## its navmesh from static collisions and treats this wall as the open breach the player makes.
## Local frame: the wall runs along X, the player's side (relay room) is +Z, the room is -Z;
## the origin is on the floor at the centre of the opening.

signal hit(hits_done: int)
signal broken

## The route check (scenes/complex_v4/review/opening_route_check.gd) walks through these.
const ROUTE_PASSABLE_GROUP := &"opening_route_passable"
const PROMPT_INSPECT := "ОСМОТРЕТЬ ТРЕЩИНУ"
const PROMPT_BREAK := "ВЫЛОМАТЬ ЛОМОМ"
## Inspect texts (data/documents/opening.json): dark and lit room behind the crack.
const TEXT_DARK := "relay_crack_dark"
const TEXT_LIT := "relay_crack_lit"
const WALL_COLOR := Color(0.36, 0.36, 0.34)
const ROOM_LIGHT_COLOR := Color(1.0, 0.86, 0.66)
const ROOM_LIGHT_ENERGY := 1.6
const ROOM_LIGHT_RANGE := 6.0
const LEAK_LIGHT_COLOR := Color(1.0, 0.82, 0.55)
const LEAK_LIGHT_ENERGY := 2.5
const LEAK_LIGHT_RANGE := 3.0
## Width of the slit before the first hit (wide enough to see into the room, #219) and how
## much each hit widens it, m.
const CRACK_WIDTH := 0.08
const CRACK_GROWTH := 0.03
## Outline of the opening for a 1.2 × 2.0 m opening, from the floor at the left, over the top,
## down to the floor at the right. Every point lies outside the clear 1.2 × 2.0 rectangle, so
## the jagged hole never narrows the way. Scaled with `opening_width`/`opening_height`.
const OUTLINE: PackedVector2Array = [
	Vector2(-0.68, 0.0), Vector2(-0.75, 0.32), Vector2(-0.65, 0.66), Vector2(-0.8, 1.02),
	Vector2(-0.68, 1.38), Vector2(-0.77, 1.74), Vector2(-0.63, 2.03), Vector2(-0.46, 2.17),
	Vector2(-0.22, 2.07), Vector2(0.0, 2.26), Vector2(0.19, 2.09), Vector2(0.41, 2.2),
	Vector2(0.66, 2.04), Vector2(0.74, 1.7), Vector2(0.65, 1.37), Vector2(0.8, 0.99),
	Vector2(0.67, 0.64), Vector2(0.76, 0.3), Vector2(0.67, 0.0),
]
## The crack zigzag through the plug, top to bottom (same scale); it runs past the outline.
const CRACK_LINE: PackedVector2Array = [
	Vector2(0.03, 2.6), Vector2(0.0, 2.1), Vector2(-0.12, 1.78), Vector2(0.07, 1.42),
	Vector2(-0.06, 1.08), Vector2(0.1, 0.72), Vector2(-0.04, 0.38), Vector2(0.05, -0.2),
]
## Far edge of the half-planes that cut the plug along the crack.
const CUT_FAR := 10.0
const SHAKE_OFFSET := 0.025
const SHAKE_TIME := 0.18
const DUST_AMOUNT := 40

## Story flag set when the wall is broken open.
@export var flag: StringName = &"opening/senior_breach_open"
## The tool the player must carry (an item flag, e.g. the crowbar pickup).
@export var tool_flag: StringName = &"item_crowbar"
@export var hits_required := 3
## Hold time of one hit.
@export var hit_time := 0.9
## Power section of the room behind the wall and the power level that lights it.
@export var section: StringName = &""
@export_enum("Выкл.", "Аварийное", "Основное") var light_power := 2
@export var width := 4.0
@export var height := 3.0
@export var thickness := 0.25
## The opening matches the breach door of L-OLD-CORE (#177): 1.2 × 2.0 m.
@export var opening_width := 1.2
@export var opening_height := 2.0
@export var hit_sound: StringName = &"breach_hit"
@export var break_sound: StringName = &"breach_break"

var interactable: Interactable
var room_light: OmniLight3D
var _plug: StaticBody3D
var _wall_material: StandardMaterial3D
var _pieces: Array[MeshInstance3D] = []
var _leak_light: OmniLight3D
var _rubble: Node3D
var _dust: CPUParticles3D
var _shake: Tween


func _ready() -> void:
	_build()
	add_to_group(ROUTE_PASSABLE_GROUP)
	if Engine.is_editor_hint():
		return
	interactable = PropKit.interactable(_plug, Interactable.Mode.INSPECT, PROMPT_INSPECT)
	interactable.hold_time = hit_time
	interactable.interacted.connect(_on_interacted)
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.section_power_changed.connect(_on_section_power_changed)
	GameState.state_loaded.connect(_refresh)
	_refresh()


func hits_flag() -> StringName:
	return StringName(String(flag) + "_hits")


func is_open() -> bool:
	return GameState.has_flag(flag)


func hits_done() -> int:
	return int(GameState.get_flag(hits_flag(), 0))


func has_tool() -> bool:
	return tool_flag.is_empty() or GameState.has_flag(tool_flag)


## Width of the slit through the plug now: it grows with every hit.
func crack_width() -> float:
	return CRACK_WIDTH + CRACK_GROWTH * mini(hits_done(), hits_required)


func is_lit() -> bool:
	return GameState.get_section_power(section) >= light_power


## One hit with the tool; the last one breaks the wall open. Returns false without the tool.
func strike() -> bool:
	if is_open() or not has_tool():
		return false
	var hits := hits_done() + 1
	GameState.set_flag(hits_flag(), hits)
	_play(hit_sound)
	_burst_dust()
	_shake_plug()
	hit.emit(hits)
	if hits >= hits_required:
		_play(break_sound)
		GameState.set_flag(flag)
		broken.emit()
	return true


func _on_interacted() -> void:
	if interactable.mode == Interactable.Mode.HOLD:
		strike()


func _on_flag_changed(changed: StringName, _value: Variant) -> void:
	if changed == flag or changed == tool_flag or changed == hits_flag():
		_refresh()


func _on_section_power_changed(changed: StringName, _power: int) -> void:
	if changed == section:
		_refresh()


func _refresh() -> void:
	var open := is_open()
	var lit := is_lit()
	_plug.visible = not open
	_plug.collision_layer = 0 if open else 1
	_rubble.visible = open
	room_light.visible = lit
	_leak_light.visible = lit and not open
	_build_pieces(crack_width())
	interactable.available = not open
	interactable.unavailable_prompt = ""
	if has_tool():
		interactable.mode = Interactable.Mode.HOLD
		interactable.prompt = PROMPT_BREAK
	else:
		interactable.mode = Interactable.Mode.INSPECT
		interactable.prompt = PROMPT_INSPECT
		interactable.inspect_text_id = TEXT_LIT if lit else TEXT_DARK


func _play(id: StringName) -> void:
	if not id.is_empty():
		Sfx.play(id, _plug)


func _burst_dust() -> void:
	_dust.restart()
	_dust.emitting = true


func _shake_plug() -> void:
	if _shake:
		_shake.kill()
	_plug.position = Vector3(0, 0, SHAKE_OFFSET)
	_shake = create_tween()
	_shake.tween_property(_plug, "position", Vector3.ZERO, SHAKE_TIME)


func _build() -> void:
	_wall_material = PropKit.material(WALL_COLOR)
	var outline := _outline()
	# The wall around the opening is one outline: the hole reaches the floor, so the wall is a
	# simple polygon running from the floor at the left edge round the hole to the right edge.
	var wall_polygon := PackedVector2Array([Vector2(-width * 0.5, 0.0)])
	wall_polygon.append_array(outline)
	wall_polygon.append_array([Vector2(width * 0.5, 0.0), Vector2(width * 0.5, height), Vector2(-width * 0.5, height)])
	var wall_mesh := MeshInstance3D.new()
	wall_mesh.name = "WallMesh"
	wall_mesh.mesh = extrude([wall_polygon], thickness, _wall_material)
	add_child(wall_mesh)
	var wall_shape := CollisionShape3D.new()
	wall_shape.shape = wall_mesh.mesh.create_trimesh_shape()
	add_child(wall_shape)

	_plug = StaticBody3D.new()
	_plug.name = "Plug"
	add_child(_plug)
	var bounds := _bounds(outline)
	var plug_shape := CollisionShape3D.new()
	var plug_box := BoxShape3D.new()
	plug_box.size = Vector3(bounds.size.x, bounds.size.y, thickness)
	plug_shape.shape = plug_box
	plug_shape.position = Vector3(bounds.get_center().x, bounds.get_center().y, 0)
	_plug.add_child(plug_shape)
	_build_pieces(CRACK_WIDTH)

	room_light = OmniLight3D.new()
	room_light.name = "RoomLight"
	room_light.position = Vector3(0, height - 0.4, -ROOM_LIGHT_RANGE * 0.4)
	room_light.light_color = ROOM_LIGHT_COLOR
	room_light.light_energy = ROOM_LIGHT_ENERGY
	room_light.omni_range = ROOM_LIGHT_RANGE
	# Shadows keep the room light from shining through the wall into the relay room.
	room_light.shadow_enabled = true
	room_light.visible = false
	add_child(room_light)
	# Just behind the crack on the room side: its light passes only through the slit.
	_leak_light = OmniLight3D.new()
	_leak_light.name = "LeakLight"
	_leak_light.position = Vector3(0, opening_height * 0.55, -thickness * 0.5 - 0.5)
	_leak_light.light_color = LEAK_LIGHT_COLOR
	_leak_light.light_energy = LEAK_LIGHT_ENERGY
	_leak_light.omni_range = LEAK_LIGHT_RANGE
	_leak_light.shadow_enabled = true
	_leak_light.visible = false
	add_child(_leak_light)

	# Chunks of the same wall on both sides of the hole once it is broken.
	_rubble = Node3D.new()
	_rubble.name = "Rubble"
	_rubble.visible = false
	add_child(_rubble)
	var chunk: PackedVector2Array = [Vector2(-0.12, -0.05), Vector2(0.03, -0.09), Vector2(0.13, -0.01), Vector2(0.08, 0.08), Vector2(-0.07, 0.07)]
	var pieces: Array[Vector3] = [Vector3(-0.3, 0.07, 0.45), Vector3(0.25, 0.06, 0.6), Vector3(0.05, 0.08, -0.5), Vector3(-0.42, 0.06, -0.7), Vector3(0.45, 0.05, -0.35), Vector3(-0.6, 0.06, 0.25), Vector3(0.62, 0.07, 0.15)]
	for index in pieces.size():
		var factor := 1.6 - 0.15 * index
		var scaled := PackedVector2Array()
		for point in chunk:
			scaled.append(point * factor)
		var piece := MeshInstance3D.new()
		piece.mesh = extrude([scaled], 0.12 * factor, _wall_material)
		piece.position = pieces[index]
		piece.rotation = Vector3(PI * 0.5 + 0.2 * (index % 3 - 1), 0.9 * index, 0.15 * (index % 2))
		_rubble.add_child(piece)

	_dust = CPUParticles3D.new()
	_dust.name = "Dust"
	_dust.position = Vector3(0, opening_height * 0.55, thickness * 0.5 + 0.05)
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = DUST_AMOUNT
	_dust.lifetime = 1.2
	_dust.explosiveness = 0.9
	_dust.direction = Vector3(0, 0, 1)
	_dust.spread = 50.0
	_dust.initial_velocity_min = 0.4
	_dust.initial_velocity_max = 1.4
	_dust.gravity = Vector3(0, -2.0, 0)
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(opening_width * 0.4, opening_height * 0.3, 0.02)
	var grain := BoxMesh.new()
	grain.size = Vector3(0.03, 0.03, 0.03)
	grain.material = PropKit.material(Color(0.55, 0.53, 0.5))
	_dust.mesh = grain
	add_child(_dust)


## The plug as the pieces left of and right of the crack, `gap` m apart.
func _build_pieces(gap: float) -> void:
	for piece in _pieces:
		piece.free()
	_pieces.clear()
	var outline := _outline()
	var crack := _scaled(CRACK_LINE)
	for side: float in [-1.0, 1.0]:
		var half := PackedVector2Array()
		for point in crack:
			half.append(point + Vector2(side * gap * 0.5, 0))
		var last := crack[crack.size() - 1]
		var first := crack[0]
		half.append_array([Vector2(side * CUT_FAR, last.y), Vector2(side * CUT_FAR, first.y)])
		var piece := MeshInstance3D.new()
		piece.name = "PieceLeft" if side < 0.0 else "PieceRight"
		piece.mesh = extrude(Geometry2D.intersect_polygons(outline, half), thickness, _wall_material)
		_plug.add_child(piece)
		_pieces.append(piece)


func _outline() -> PackedVector2Array:
	return _scaled(OUTLINE)


func _scaled(points: PackedVector2Array) -> PackedVector2Array:
	var factor := Vector2(opening_width / 1.2, opening_height / 2.0)
	var result := PackedVector2Array()
	for point in points:
		result.append(point * factor)
	return result


func _bounds(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	return rect


## A prism mesh from simple polygons in the XY plane, `depth` thick along Z and centred on it.
## Flat-shaded: caps and every side face get their own normals.
static func extrude(polygons: Array[PackedVector2Array], depth: float, mat: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := depth * 0.5
	for polygon in polygons:
		if polygon.size() < 3:
			continue
		var points := polygon
		if Geometry2D.is_polygon_clockwise(points):
			points = polygon.duplicate()
			points.reverse()
		var triangles := Geometry2D.triangulate_polygon(points)
		for cap: float in [1.0, -1.0]:
			surface.set_normal(Vector3(0, 0, cap))
			for index in triangles.size():
				# Godot culls counter-clockwise faces: the front cap (seen from +Z) flips the
				# counter-clockwise order of the points, the back one keeps it.
				var corner := triangles[index] if cap < 0.0 else triangles[index - 2 * (index % 3) + 2]
				var point := points[corner]
				surface.set_uv(point)
				surface.add_vertex(Vector3(point.x, point.y, cap * half))
		for index in points.size():
			var a := points[index]
			var b := points[(index + 1) % points.size()]
			var edge := b - a
			surface.set_normal(Vector3(edge.y, -edge.x, 0).normalized())
			var length := edge.length()
			var quad: Array[Vector3] = [Vector3(a.x, a.y, half), Vector3(a.x, a.y, -half), Vector3(b.x, b.y, -half), Vector3(b.x, b.y, half)]
			var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(0, depth), Vector2(length, depth), Vector2(length, 0)]
			for corner: int in [0, 2, 1, 0, 3, 2]:
				surface.set_uv(uvs[corner])
				surface.add_vertex(quad[corner])
	surface.set_material(mat)
	return surface.commit()
