class_name InterdreamCorridor
extends Node3D

## The white corridor of the interdream (docs/game_design/10-interdream.md, variant A, #228):
## a short corridor in milky fog, built from primitives. The camera walks on its own
## (`progress` 0–1), the mouse turns the head a little (`look_offset`); the echo props are the
## only dark spots in the frame. Shown by InterdreamOverlay in its own world.

const WIDTH := 2.4
const HEIGHT := 2.7
const LENGTH := 8.0
const EYE := 1.6
const SEAM_STEP := 1.2
const WALK_FROM := -0.2
const WALK_TO := -3.6
const TORN_WALK := 0.5
const LOOK_LIMIT := 15.0
## The silhouette never lets the camera close: it is gone nearer than this.
const SILHOUETTE_KEEP := 2.0
const FOCUS_WEIGHT := 0.35
## The key is small: drawn larger than life so it reads from the walk.
const KEY_SCALE := 1.8
## Font of the plate: the old-queue plates of the lower floor share it (canon, 06-story).
const PLATE_FONT: FontVariation = UiStyle.FONT_SCREEN_OLD
const WHITE := Color(0.92, 0.94, 0.96)
const SEAM := Color(0.84, 0.86, 0.89)
const DARK := Color(0.16, 0.17, 0.18)
const PLATE_INK := Color(0.86, 0.82, 0.7)
const CRACK := Color(0.62, 0.36, 0.24)
const FOG_DENSITY := 0.11

## 0 — at the start of the walk, 1 — at its end.
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		_update_camera()
## Head turn from the mouse in degrees (yaw, pitch), clamped to ±LOOK_LIMIT.
var look_offset := Vector2.ZERO:
	set(value):
		look_offset = value.clamp(Vector2(-LOOK_LIMIT, -LOOK_LIMIT), Vector2(LOOK_LIMIT, LOOK_LIMIT))
		_update_camera()
## Camera shake of the torn interdream, metres.
var jitter := 0.0
## A torn interdream barely moves.
var torn := false

var camera: Camera3D
var props: Dictionary[String, Node3D] = {}
var _focus: Node3D
var _silhouettes: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_build_world()
	_build_corridor()
	_build_props()
	show_props([])


## Shows only the props named (InterdreamEchoes.PROPS); `tag` is written on the key's tag.
func show_props(names: Array, tag: String = "") -> void:
	_focus = null
	_silhouettes.clear()
	for id: String in props:
		var visible_now := id in names
		props[id].visible = visible_now
		if visible_now and id.begins_with("silhouette"):
			_silhouettes.append(props[id])
		elif visible_now and _focus == null:
			_focus = props[id]
	var label := props["key_lanyard"].get_node(^"Tag/Text") as Label3D
	label.text = tag
	_update_camera()


func is_prop_visible(id: String) -> bool:
	return props.has(id) and props[id].visible


func _process(_delta: float) -> void:
	if jitter > 0.0:
		_update_camera()
	for silhouette in _silhouettes:
		var offset := silhouette.global_position - camera.global_position
		silhouette.visible = Vector2(offset.x, offset.z).length() >= SILHOUETTE_KEEP


func _update_camera() -> void:
	if camera == null:
		return
	var walk := TORN_WALK if torn else 1.0
	var eased := smoothstep(0.0, 1.0, progress) * walk
	var position_now := Vector3(0.0, EYE, lerpf(WALK_FROM, WALK_TO, eased))
	if jitter > 0.0:
		position_now += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0.0) * jitter
	var target := position_now + Vector3.FORWARD * 4.0
	if _focus:
		var to_focus := (_focus.global_position - position_now).normalized() * 4.0
		target = position_now + (target - position_now).lerp(to_focus, FOCUS_WEIGHT * smoothstep(0.0, 0.7, progress))
	camera.global_transform = Transform3D(Basis.looking_at(target - position_now), position_now)
	camera.rotate_object_local(Vector3.UP, deg_to_rad(-look_offset.x))
	camera.rotate_object_local(Vector3.RIGHT, deg_to_rad(-look_offset.y))


func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = WHITE
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 1, 1)
	environment.ambient_light_energy = 0.9
	environment.fog_enabled = true
	environment.fog_light_color = WHITE
	environment.fog_density = FOG_DENSITY
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var light := OmniLight3D.new()
	light.position = Vector3(0, HEIGHT - 0.3, -2.0)
	light.omni_range = 9.0
	light.light_energy = 0.6
	light.light_color = Color(0.92, 0.96, 1.0)
	add_child(light)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.current = true
	add_child(camera)


func _build_corridor() -> void:
	var half := WIDTH / 2.0
	var mid := -LENGTH / 2.0 + 0.5
	_box(Vector3(WIDTH, 0.1, LENGTH), Vector3(0, -0.05, mid), WHITE)
	_box(Vector3(WIDTH, 0.1, LENGTH), Vector3(0, HEIGHT + 0.05, mid), WHITE)
	_box(Vector3(0.1, HEIGHT, LENGTH), Vector3(-half - 0.05, HEIGHT / 2.0, mid), WHITE)
	_box(Vector3(0.1, HEIGHT, LENGTH), Vector3(half + 0.05, HEIGHT / 2.0, mid), WHITE)
	# Barely visible plate seams on the walls.
	var z := 0.0
	while z > -LENGTH + 0.5:
		for side in [-1.0, 1.0]:
			_box(Vector3(0.01, HEIGHT, 0.015), Vector3(side * (half - 0.004), HEIGHT / 2.0, z), SEAM)
		z -= SEAM_STEP
	# The far wall with a doorway into grey.
	var end_z := -LENGTH + 0.5
	var door := 1.0
	var side_width := (WIDTH - door) / 2.0
	_box(Vector3(side_width, HEIGHT, 0.1), Vector3(-half + side_width / 2.0, HEIGHT / 2.0, end_z), WHITE)
	_box(Vector3(side_width, HEIGHT, 0.1), Vector3(half - side_width / 2.0, HEIGHT / 2.0, end_z), WHITE)
	_box(Vector3(door, HEIGHT - 2.1, 0.1), Vector3(0, 2.1 + (HEIGHT - 2.1) / 2.0, end_z), WHITE)
	_box(Vector3(door + 0.4, HEIGHT, 0.1), Vector3(0, HEIGHT / 2.0, end_z - 1.6), Color(0.55, 0.57, 0.6))


func _build_props() -> void:
	var half := WIDTH / 2.0
	props["plate_2"] = _plate(Vector3(-half + 0.01, 1.62, -2.9), "")
	props["plate_2_healed"] = _plate(Vector3(-half + 0.01, 1.62, -2.9), "healed")
	props["plate_2_turned"] = _plate(Vector3(-half + 0.01, 1.62, -2.9), "turned")
	props["plate_2_flash"] = _plate(Vector3(-half + 0.01, 1.62, -1.7), "")
	props["silhouette_far"] = _silhouette(Vector3(0, 0, -LENGTH + 0.2))
	props["silhouette_near"] = _silhouette(Vector3(0.2, 0, -5.0))
	props["key_lanyard"] = _key(Vector3(half - 0.01, 1.62, -4.0))


## A metal plate with the old-queue «2»; `variant` "healed" — a crack drawn over like cooled
## metal, "turned" — turned to the wall, its blank back out.
func _plate(at: Vector3, variant: String) -> Node3D:
	var plate := Node3D.new()
	plate.position = at
	plate.rotation_degrees.y = 90.0
	add_child(plate)
	_box(Vector3(0.36, 0.27, 0.016), Vector3(0, 0, 0.008), DARK, plate)
	if variant == "turned":
		plate.rotation_degrees.z = 4.0
		for x in [-0.15, 0.15]:
			_box(Vector3(0.02, 0.02, 0.01), Vector3(x, 0.1, 0.02), Color(0.4, 0.4, 0.4), plate)
		return plate
	var number := Label3D.new()
	number.text = "2"
	number.font = PLATE_FONT
	number.font_size = 160
	number.pixel_size = 0.0012
	number.modulate = PLATE_INK
	number.outline_size = 0
	number.double_sided = false
	number.shaded = false
	number.position = Vector3(0, 0, 0.018)
	plate.add_child(number)
	if variant == "healed":
		var crack := _box(Vector3(0.006, 0.3, 0.004), Vector3(0.02, 0, 0.02), CRACK, plate)
		crack.rotation_degrees.z = 28.0
	return plate


func _silhouette(at: Vector3) -> Node3D:
	var figure := Node3D.new()
	figure.position = at
	add_child(figure)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.23
	capsule.height = 1.5
	body.mesh = capsule
	body.position.y = 0.75
	body.material_override = _material(Color(0.2, 0.21, 0.23, 0.82))
	figure.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	head.mesh = sphere
	head.position.y = 1.62
	head.material_override = body.material_override
	figure.add_child(head)
	return figure


## A key on a cord with a tag; the key cannot be taken.
func _key(at: Vector3) -> Node3D:
	var key := Node3D.new()
	key.position = at
	key.rotation_degrees.y = -90.0
	key.scale = Vector3.ONE * KEY_SCALE
	add_child(key)
	_box(Vector3(0.004, 0.32, 0.004), Vector3(0, -0.16, 0.01), DARK, key)
	_box(Vector3(0.03, 0.09, 0.006), Vector3(0, -0.36, 0.012), Color(0.45, 0.42, 0.36), key)
	_box(Vector3(0.05, 0.04, 0.006), Vector3(0, -0.3, 0.012), Color(0.45, 0.42, 0.36), key)
	var tag := Node3D.new()
	tag.name = "Tag"
	tag.position = Vector3(0.06, -0.33, 0.012)
	key.add_child(tag)
	_box(Vector3(0.09, 0.05, 0.004), Vector3.ZERO, Color(0.8, 0.77, 0.68), tag)
	var text := Label3D.new()
	text.name = "Text"
	text.font = PLATE_FONT
	text.font_size = 48
	text.pixel_size = 0.0006
	text.modulate = DARK
	text.outline_size = 0
	text.shaded = false
	text.double_sided = false
	text.position = Vector3(0, 0, 0.004)
	tag.add_child(text)
	return key


func _box(size: Vector3, at: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
