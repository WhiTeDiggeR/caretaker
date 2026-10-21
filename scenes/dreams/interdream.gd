class_name InterdreamCorridor
extends Node3D

## The white corridor of the interdream (docs/game_design/10-interdream.md, variant A, #228):
## a short corridor in milky fog, built from primitives. The camera walks on its own
## (`progress` 0–1), the mouse turns the head a little (`look_offset`); the echo props are the
## only dark spots in the frame. Shown by InterdreamOverlay in its own world.
## #240: it is a dream, not a place — `look` (LOOKS) sets how much the fog, the swaying walls
## and the washed-out props take the edge off; the overlay blurs the frame to match. The walk
## starts at the hero's own pace from the gate (`carry`) and slows down to a stop.

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
const SILHOUETTE_SCENE := preload("res://objects/dream/no2_silhouette.tscn")
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
const BACKLIGHT := Color(1.0, 1.0, 1.0)
const BREATH_SECONDS := 7.0
const SUBDIVIDE_STEP := 0.4
## Views of the corridor (#240): "clear" — the sharp corridor of #228, "haze" — recommended,
## "deep" — the farthest from reality. `contrast` — how dark the props stay (1 — as drawn),
## `sway` — metres the walls float, `breath` — degrees of the slow FOV breathing; the screen
## keys (`blur_center`, `blur_edge` — mip levels, `haze` — milky veil, `edge_white` — white
## soft edges, `swim` — screen wobble) are drawn by InterdreamOverlay.
const LOOKS := {
	"clear": {"fog": 0.11, "ambient": 0.9, "contrast": 1.0, "sway": 0.0, "breath": 0.0, "fov": 68.0,
			"blur_center": 0.0, "blur_edge": 0.0, "haze": 0.0, "edge_white": 0.0, "swim": 0.0, "bloom": 0.0},
	"haze": {"fog": 0.15, "ambient": 1.0, "contrast": 0.88, "sway": 0.018, "breath": 1.5, "fov": 72.0,
			"blur_center": 0.5, "blur_edge": 2.6, "haze": 0.1, "edge_white": 0.4, "swim": 1.0, "bloom": 0.5},
	"deep": {"fog": 0.24, "ambient": 1.05, "contrast": 0.62, "sway": 0.032, "breath": 2.5, "fov": 78.0,
			"blur_center": 1.6, "blur_edge": 4.4, "haze": 0.24, "edge_white": 0.6, "swim": 1.8, "bloom": 0.8},
}
const DEFAULT_LOOK := "haze"
## The walls float in the dream; `sway` 0 keeps them still.
const SURFACE_SHADER := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float emission = 0.0;
uniform float sway = 0.0;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 drift = vec3(sin(TIME * 0.61 + w.z * 1.3 + w.y * 0.7), 0.6 * sin(TIME * 0.47 + w.z * 0.9 + w.x * 1.9), 0.0);
	VERTEX += drift * sway;
}
void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	EMISSION = albedo.rgb * emission;
}
"""

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
## One of LOOKS; set before the corridor enters the tree.
var look := DEFAULT_LOOK
## The hero's pace at the gate, m/s, and how many seconds the walk lasts: the walk starts at
## that pace and slows down to a stop (0 — starts from standing, as a torn one does).
var entry_speed := 0.0
var walk_seconds := 3.0
## The hero's head pitch at the gate, degrees: it settles to level during the first steps.
var entry_pitch := 0.0

var camera: Camera3D
var props: Dictionary[String, Node3D] = {}
var _focus: Node3D
var _silhouettes: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _look: Dictionary = LOOKS[DEFAULT_LOOK]
var _shader: Shader
var _time := 0.0


func _ready() -> void:
	_look = LOOKS.get(look, LOOKS[DEFAULT_LOOK])
	_shader = Shader.new()
	_shader.code = SURFACE_SHADER
	_build_world()
	_build_corridor()
	_build_props()
	show_props([])


## The view settings in use (LOOKS), for the overlay's screen pass.
func look_settings() -> Dictionary:
	return _look


## Takes over the hero's walk at the gate: `speed` m/s, `pitch` degrees, over `seconds`.
func carry(speed: float, pitch: float, seconds: float) -> void:
	entry_speed = maxf(speed, 0.0)
	entry_pitch = clampf(pitch, -LOOK_LIMIT * 2.0, LOOK_LIMIT * 2.0)
	walk_seconds = maxf(seconds, 0.1)
	_update_camera()


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


func _process(delta: float) -> void:
	_time += delta
	if camera:
		camera.fov = float(_look["fov"]) + float(_look["breath"]) * sin(TAU * _time / BREATH_SECONDS)
	if jitter > 0.0 or float(_look["breath"]) > 0.0:
		_update_camera()
	for silhouette in _silhouettes:
		var offset := silhouette.global_position - camera.global_position
		silhouette.visible = Vector2(offset.x, offset.z).length() >= SILHOUETTE_KEEP


func _update_camera() -> void:
	if camera == null:
		return
	var walk := TORN_WALK if torn else 1.0
	var eased := walk_curve(progress, 0.0 if torn else entry_speed * walk_seconds / absf(WALK_TO - WALK_FROM)) * walk
	var position_now := Vector3(0.0, EYE, lerpf(WALK_FROM, WALK_TO, eased))
	if jitter > 0.0:
		position_now += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0.0) * jitter
	var target := position_now + Vector3.FORWARD * 4.0
	if _focus:
		var to_focus := (_focus.global_position - position_now).normalized() * 4.0
		target = position_now + (target - position_now).lerp(to_focus, FOCUS_WEIGHT * smoothstep(0.0, 0.7, progress))
	camera.global_transform = Transform3D(Basis.looking_at(target - position_now), position_now)
	camera.rotate_object_local(Vector3.UP, deg_to_rad(-look_offset.x))
	camera.rotate_object_local(Vector3.RIGHT, deg_to_rad(-look_offset.y + entry_pitch * (1.0 - smoothstep(0.0, 0.35, progress))))
	var roll := float(_look["breath"]) * 0.4 * sin(TAU * _time / (BREATH_SECONDS * 1.6))
	camera.rotate_object_local(Vector3.FORWARD, deg_to_rad(roll))


## Share of the walk done at `t` (0–1): starts at `slope` (the hero's pace in walk lengths per
## walk time) and stops softly. Hermite, monotonic for slopes up to 3.
static func walk_curve(t: float, slope: float) -> float:
	var s := clampf(slope, 0.0, 3.0)
	var u := clampf(t, 0.0, 1.0)
	return s * (u * u * u - 2.0 * u * u + u) + 3.0 * u * u - 2.0 * u * u * u


func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = WHITE
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 1, 1)
	environment.ambient_light_energy = float(_look["ambient"])
	environment.fog_enabled = true
	environment.fog_light_color = WHITE
	environment.fog_density = float(_look["fog"])
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
	camera.fov = float(_look["fov"])
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
	# Beyond the doorway — a light, so the figure in it stands against the glow.
	var beyond := _box(Vector3(door + 0.4, HEIGHT, 0.1), Vector3(0, HEIGHT / 2.0, end_z - 1.6), BACKLIGHT)
	(beyond.material_override as ShaderMaterial).set_shader_parameter(&"emission", 0.6)


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
	_box(Vector3(0.36, 0.27, 0.016), Vector3(0, 0, 0.008), _tint(DARK), plate)
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


## The silhouette of №2 in the doorway — the same figure as on the terrace of the first dream;
## the look's contrast washes it towards the white.
func _silhouette(at: Vector3) -> Node3D:
	var figure := SILHOUETTE_SCENE.instantiate() as No2Silhouette
	figure.position = at
	figure.color = _tint(No2Silhouette.DEFAULT_COLOR)
	add_child(figure)
	return figure


## A key on a cord with a tag; the key cannot be taken.
func _key(at: Vector3) -> Node3D:
	var key := Node3D.new()
	key.position = at
	key.rotation_degrees.y = -90.0
	key.scale = Vector3.ONE * KEY_SCALE
	add_child(key)
	_box(Vector3(0.004, 0.32, 0.004), Vector3(0, -0.16, 0.01), _tint(DARK), key)
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
	if float(_look["sway"]) > 0.0 and parent == self:
		mesh.subdivide_width = mini(ceili(size.x / SUBDIVIDE_STEP), 24)
		mesh.subdivide_height = mini(ceili(size.y / SUBDIVIDE_STEP), 24)
		mesh.subdivide_depth = mini(ceili(size.z / SUBDIVIDE_STEP), 24)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _material(color, parent == self)
	parent.add_child(instance)
	return instance


## Only the corridor itself floats; the props hold still so their labels stay on them.
func _material(color: Color, floating := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"albedo", color)
	material.set_shader_parameter(&"sway", float(_look["sway"]) if floating else 0.0)
	return material


## Dark props wash out towards the white with the look's `contrast`.
func _tint(color: Color) -> Color:
	return color.lerp(WHITE, 1.0 - float(_look["contrast"]))
