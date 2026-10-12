@tool
class_name DoorArt
extends RefCounted

## Art geometry of `FacilityDoor` (#157). Frames and leaves are sized per door, so they are assembled here from boxes
## with the shared prop materials: object-space triplanar, so the paint stays put on a moving leaf, and one mesh per
## part with a surface per material. The fixed-size controls are props from `tools/props/props_doors.py`.
## Visuals only: the door script keeps its own collision shapes.

const PAINT := preload("res://materials/doors/paint.tres")
const STEEL := preload("res://materials/doors/steel.tres")
const RUBBER := preload("res://materials/doors/rubber.tres")
const HAZARD := preload("res://materials/doors/hazard_stripes.tres")
const LABELS := preload("res://materials/doors/panel_labels.tres")
const PANEL_MODEL := preload("res://loads/props/door_panel/door_panel.gltf")
const WHEEL_MODEL := preload("res://loads/props/door_wheel/door_wheel.gltf")
const HANDLE_MODEL := preload("res://loads/props/door_handle/door_handle.gltf")
const HINGE_MODEL := preload("res://loads/props/door_hinge/door_hinge.gltf")

## Colour the paint texture is authored for: `leaf_color`/`frame_color` tint relative to it.
const BASE_COLOR := Color(0.33, 0.35, 0.36)
## Atlas rects (loads/textures/decals/*.json).
const HAZARD_RECT := Rect2(0.0, 0.0, 1.0, 0.48)
const LABEL_WARNING_RECT := Rect2(0.0, 0.5, 0.125, 1.0 / 6.0)  # «ВНИМАНИЕ»
const HAZARD_PERIOD := 0.6  # metres of band per atlas width
const DECAL_OFFSET := 0.003
const BORDER := 0.08
const DETAIL := 0.02
const RIVET := 0.022
const RIVET_STEP := 0.3
const SLAT_STEP := 0.16
const LAMP_RADIUS := 0.022
## Lamp lens centre in each control model and how far the model's wall face sits behind the control node.
const LAMP_POSITION: Dictionary[FacilityDoor.Kind, Vector3] = {
	FacilityDoor.Kind.POWERED: Vector3(0, 0.1, 0.072),
	FacilityDoor.Kind.MECHANICAL: Vector3(0, 0.36, 0.05),
	FacilityDoor.Kind.MANUAL: Vector3(0, 0.09, 0.022),
}
const WALL_GAP: Dictionary[FacilityDoor.Kind, float] = {
	FacilityDoor.Kind.POWERED: 0.06,
	FacilityDoor.Kind.MECHANICAL: 0.06,
	FacilityDoor.Kind.MANUAL: 0.05,
}
## Distance from the wall face to the hand wheel plane (door_wheel model).
const WHEEL_REACH := 0.24

static var _tints: Dictionary[Color, Material] = {}


## Frame visuals; `post` and `depth` are the door script's frame sizes.
static func frame(parent: Node3D, width: float, height: float, post: float, depth: float, color: Color) -> void:
	var b := MeshBatch.new()
	var paint := tinted(color)
	var post_x := width * 0.5 + post * 0.5
	var face := depth * 0.5
	for sx: float in [-1.0, 1.0]:
		b.box(paint, Vector3(sx * post_x, height * 0.5, 0), Vector3(post, height, depth))
		b.box(STEEL, Vector3(sx * (width * 0.5 + 0.006), height * 0.5, 0), Vector3(0.012, height, depth - 0.04))
	b.box(paint, Vector3(0, height + post * 0.5, 0), Vector3(width + post * 2.0, post, depth))
	b.box(STEEL, Vector3(0, height + 0.006, 0), Vector3(width, 0.012, depth - 0.04))
	b.box(STEEL, Vector3(0, 0.005, 0), Vector3(width, 0.01, depth))  # threshold plate
	for sz: float in [-1.0, 1.0]:
		var z := sz * (face + DETAIL * 0.3)
		for sx: float in [-1.0, 1.0]:
			b.box(RUBBER, Vector3(sx * (width * 0.5 + 0.015), height * 0.5, z), Vector3(0.03, height, DETAIL * 0.6))
			var y := 0.25
			while y < height:
				b.box(STEEL, Vector3(sx * (width * 0.5 + post * 0.65), y, z), Vector3(RIVET, RIVET, DETAIL))
				y += RIVET_STEP * 1.5
		b.box(RUBBER, Vector3(0, height + 0.015, z), Vector3(width + 0.06, 0.03, DETAIL * 0.6))
		b.decal(HAZARD, Vector3(0, height + post * 0.5, sz * (face + DECAL_OFFSET)), Vector2(width + post * 2.0 - 0.06, post * 0.55),
				sz, _hazard_uv(width + post * 2.0 - 0.06))
	b.attach(parent, "FrameArt")


## Leaf visuals. `x` is the leaf centre (a hinged leaf is offset from its hinge).
static func leaf(parent: Node3D, axis: FacilityDoor.SlideAxis, width: float, height: float, depth: float, x: float,
		color: Color) -> void:
	var b := MeshBatch.new()
	var paint := tinted(color)
	var face := depth * 0.5
	b.box(paint, Vector3(x, height * 0.5, 0), Vector3(width, height, depth))
	for sz: float in [-1.0, 1.0]:
		var z := sz * (face + DETAIL * 0.5)
		var decal_z := sz * (face + DECAL_OFFSET)
		match axis:
			FacilityDoor.SlideAxis.SIDE:
				_side_face(b, paint, width, height, x, z, sz)
				b.decal(HAZARD, Vector3(x, 0.2, sz * (face + DETAIL + DECAL_OFFSET)), Vector2(width - BORDER * 2.0, 0.26), sz,
						_hazard_uv(width - BORDER * 2.0))
				b.decal(LABELS, Vector3(x, 0.5, decal_z), Vector2(0.48, 0.12), sz, LABEL_WARNING_RECT)
			FacilityDoor.SlideAxis.UP:
				var y := SLAT_STEP
				while y < height - 0.05:
					b.box(STEEL, Vector3(x, y, sz * (face + 0.004)), Vector3(width - 0.04, 0.025, 0.008))
					y += SLAT_STEP
				b.decal(HAZARD, Vector3(x, 0.2, sz * (face + 0.008 + DECAL_OFFSET)), Vector2(width - 0.04, 0.2), sz,
						_hazard_uv(width - 0.04))
			FacilityDoor.SlideAxis.SWING:
				_swing_face(b, paint, width, height, x, z, sz)
	if axis == FacilityDoor.SlideAxis.SIDE:
		for sx: float in [-1.0, 1.0]:
			b.box(STEEL, Vector3(x + sx * (width * 0.5 - 0.015), height * 0.5, 0), Vector3(0.03, height, depth + 0.01))
	elif axis == FacilityDoor.SlideAxis.UP:
		b.box(RUBBER, Vector3(x, 0.025, 0), Vector3(width, 0.05, depth + 0.02))
	b.attach(parent, "LeafArt")
	if axis == FacilityDoor.SlideAxis.SWING:
		for y: float in [0.35, height - 0.35]:
			var hinge := HINGE_MODEL.instantiate() as Node3D
			hinge.position = Vector3(x - width * 0.5, y, face + 0.02)
			parent.add_child(hinge)


## Control model under `control` (a door control node in front of the wall face, `side` = ±1); returns the hand
## wheel node of a mechanical control, or null.
static func control(control_node: Node3D, kind: FacilityDoor.Kind, side: float, lamp: Material) -> Node3D:
	var scene: PackedScene = PANEL_MODEL
	if kind == FacilityDoor.Kind.MECHANICAL:
		scene = WHEEL_MODEL
	elif kind == FacilityDoor.Kind.MANUAL:
		scene = HANDLE_MODEL
	var model := scene.instantiate() as Node3D
	model.name = "Model"
	model.position = Vector3(0, 0, -side * WALL_GAP[kind])
	if side < 0.0:
		model.rotation.y = PI
	control_node.add_child(model)
	var lens := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = LAMP_RADIUS
	mesh.bottom_radius = LAMP_RADIUS
	mesh.height = 0.008
	mesh.radial_segments = 16
	mesh.rings = 1
	mesh.material = lamp
	lens.mesh = mesh
	lens.name = "Lamp"
	lens.position = LAMP_POSITION[kind]
	lens.rotation.x = PI * 0.5
	model.add_child(lens)
	return model.find_child("Wheel", true, false) as Node3D


## Paint material tinted by a door colour relative to `BASE_COLOR`.
static func tinted(color: Color) -> Material:
	if not _tints.has(color):
		var material := PAINT.duplicate() as BaseMaterial3D
		material.albedo_color = Color(minf(color.r / BASE_COLOR.r, 1.0), minf(color.g / BASE_COLOR.g, 1.0),
				minf(color.b / BASE_COLOR.b, 1.0))
		_tints[color] = material
	return _tints[color]


static func _side_face(b: MeshBatch, paint: Material, width: float, height: float, x: float, z: float, _sz: float) -> void:
	var inner := width - BORDER * 2.0
	b.box(paint, Vector3(x, height - BORDER * 0.5, z), Vector3(width, BORDER, DETAIL))
	b.box(paint, Vector3(x, 0.2, z), Vector3(inner, 0.3, DETAIL))  # kick band under the hazard stripes
	for sx: float in [-1.0, 1.0]:
		b.box(paint, Vector3(x + sx * (width * 0.5 - BORDER * 0.5), height * 0.5, z), Vector3(BORDER, height, DETAIL))
		var y := RIVET_STEP
		while y < height - BORDER:
			b.box(STEEL, Vector3(x + sx * (width * 0.5 - BORDER * 0.5), y, z + signf(z) * DETAIL * 0.5),
					Vector3(RIVET, RIVET, DETAIL * 0.5))
			y += RIVET_STEP
	for f: float in [0.42, 0.72]:
		b.box(STEEL, Vector3(x, height * f, z + signf(z) * 0.004), Vector3(inner, 0.07, DETAIL + 0.008))
	var rx := -inner * 0.5 + RIVET_STEP * 0.5
	while rx < inner * 0.5:
		b.box(STEEL, Vector3(x + rx, height - BORDER * 0.5, z + signf(z) * DETAIL * 0.5), Vector3(RIVET, RIVET, DETAIL * 0.5))
		rx += RIVET_STEP


static func _swing_face(b: MeshBatch, paint: Material, width: float, height: float, x: float, z: float, sz: float) -> void:
	for f: float in [0.3, 0.7]:
		b.box(paint, Vector3(x, height * f, z), Vector3(width - 0.24, height * 0.32, DETAIL * 0.75))
	b.box(STEEL, Vector3(x, 0.13, sz * (absf(z) - DETAIL * 0.3)), Vector3(width - 0.08, 0.22, 0.006))  # kick plate
	if sz > 0.0:
		for y: float in [0.35, height - 0.35]:
			b.box(STEEL, Vector3(x - width * 0.2, y, z + 0.006), Vector3(width * 0.6, 0.07, 0.012))  # hinge straps


static func _hazard_uv(length: float) -> Rect2:
	return Rect2(HAZARD_RECT.position, Vector2(length / HAZARD_PERIOD, HAZARD_RECT.size.y))


## Collects boxes and decal quads into one ArrayMesh with a surface per material.
class MeshBatch:
	var _tools: Dictionary[Material, SurfaceTool] = {}

	func box(material: Material, center: Vector3, size: Vector3) -> void:
		var mesh := BoxMesh.new()
		mesh.size = size
		_tool(material).append_from(mesh, 0, Transform3D(Basis.IDENTITY, center))

	## Quad facing +Z (`facing` = 1) or -Z, with the atlas rect read left to right as seen from that side.
	func decal(material: Material, center: Vector3, size: Vector2, facing: float, rect: Rect2) -> void:
		var st := _tool(material)
		var hx := size.x * 0.5 * facing
		var hy := size.y * 0.5
		var corners := [Vector3(-hx, -hy, 0), Vector3(hx, -hy, 0), Vector3(hx, hy, 0), Vector3(-hx, hy, 0)]
		var uvs := [rect.position + Vector2(0, rect.size.y), rect.end, rect.position + Vector2(rect.size.x, 0), rect.position]
		# Mirroring x for the back side also mirrors the view, so both sides keep the clockwise (front) order.
		for i: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3(0, 0, facing))
			st.set_uv(uvs[i])
			st.add_vertex(center + corners[i])

	func attach(parent: Node3D, node_name: String) -> MeshInstance3D:
		var mesh := ArrayMesh.new()
		for material: Material in _tools:
			var st := _tools[material]
			st.set_material(material)
			st.commit(mesh)
		var instance := MeshInstance3D.new()
		instance.name = node_name
		instance.mesh = mesh
		parent.add_child(instance)
		return instance

	func _tool(material: Material) -> SurfaceTool:
		if not _tools.has(material):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_tools[material] = st
		return _tools[material]
