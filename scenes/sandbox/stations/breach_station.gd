@tool
extends Node3D

## Sandbox station for #178: the relay room, the cracked wall to the senior officer's room
## (scene 10), the room with the body under the fallen pipe and the key, the jammed door from
## the old control point (ЦУ) and the fire shield with the crowbar (scene 9, T-ENERGY).
## The room light follows the power of `BreachWall.section` (F1 in the sandbox cycles it).
## Shell walls and the body are placeholders built here; the gameplay objects are instances.
## Layout (local): relay x −3…3, z 0…4; senior room x −3…3, z −4…0; ЦУ x 3…8, z −4…4 with the
## entrance at x 8; the fire shield outside at x 11.

const WALL_HEIGHT := 3.0
const WALL_THICKNESS := 0.2
const WALL_COLOR := Color(0.34, 0.35, 0.34)
const ROOF_COLOR := Color(0.22, 0.22, 0.22)
const BODY_COLOR := Color(0.24, 0.27, 0.3)
const PIPE_COLOR := Color(0.36, 0.3, 0.24)
const SHIELD_COLOR := Color(0.62, 0.1, 0.08)
const CABINET_COLOR := Color(0.3, 0.33, 0.3)
## Gap of the jammed door in the wall x = 3 (door width plus its frame posts).
const DOOR_Z := -2.0
const DOOR_GAP := 1.4
const DOOR_FRAME_HEIGHT := 2.3
## Open doorway relay ↔ ЦУ.
const DOORWAY_Z := Vector2(1.5, 2.5)


func _ready() -> void:
	var shell := StaticBody3D.new()
	shell.name = "Shell"
	add_child(shell)
	var wall := PropKit.material(WALL_COLOR)
	var h := WALL_HEIGHT * 0.5
	var t := WALL_THICKNESS
	PropKit.box(shell, Vector3(-3.0 - t * 0.5, h, 0), Vector3(t, WALL_HEIGHT, 8.0 + t * 2.0), wall, true)
	PropKit.box(shell, Vector3(2.5, h, 4.0 + t * 0.5), Vector3(11.0 + t * 2.0, WALL_HEIGHT, t), wall, true)
	PropKit.box(shell, Vector3(2.5, h, -4.0 - t * 0.5), Vector3(11.0 + t * 2.0, WALL_HEIGHT, t), wall, true)
	# The entrance into ЦУ: the east wall with a gap at z −1…1.
	PropKit.box(shell, Vector3(8.0 + t * 0.5, h, -2.5), Vector3(t, WALL_HEIGHT, 3.0), wall, true)
	PropKit.box(shell, Vector3(8.0 + t * 0.5, h, 2.5), Vector3(t, WALL_HEIGHT, 3.0), wall, true)
	# The wall x = 3 between the relay/senior room and ЦУ: the jammed door and the doorway.
	var door_low := DOOR_Z - DOOR_GAP * 0.5
	var door_high := DOOR_Z + DOOR_GAP * 0.5
	_wall_x(shell, -4.0, door_low, wall)
	_wall_x(shell, door_high, DOORWAY_Z.x, wall)
	_wall_x(shell, DOORWAY_Z.y, 4.0, wall)
	var lintel := WALL_HEIGHT - DOOR_FRAME_HEIGHT
	PropKit.box(shell, Vector3(3.0, DOOR_FRAME_HEIGHT + lintel * 0.5, DOOR_Z), Vector3(t, lintel, DOOR_GAP), wall, true)
	PropKit.box(shell, Vector3(3.0, 2.4 + 0.3, (DOORWAY_Z.x + DOORWAY_Z.y) * 0.5), Vector3(t, 0.6, DOORWAY_Z.y - DOORWAY_Z.x), wall, true)
	# A roof keeps the rooms dark until the room light comes on.
	PropKit.box(shell, Vector3(2.5, WALL_HEIGHT + 0.1, 0), Vector3(11.0 + t * 2.0, 0.2, 8.0 + t * 2.0), PropKit.material(ROOF_COLOR), true)
	# Relay cabinets along the west wall.
	var cabinet := PropKit.material(CABINET_COLOR)
	for z: float in [1.2, 2.2, 3.2]:
		PropKit.box(shell, Vector3(-2.65, 1.0, z), Vector3(0.5, 2.0, 0.8), cabinet, true)
	_build_body()
	_build_shield()


func _wall_x(parent: Node3D, z_from: float, z_to: float, mat: Material) -> void:
	PropKit.box(parent, Vector3(3.0, WALL_HEIGHT * 0.5, (z_from + z_to) * 0.5), Vector3(WALL_THICKNESS, WALL_HEIGHT, z_to - z_from), mat, true)


## The senior officer under the riser pipe that tore off, broke the wall and jams the door.
func _build_body() -> void:
	var body := StaticBody3D.new()
	body.name = "SeniorBody"
	add_child(body)
	PropKit.box(body, Vector3(0.9, 0.14, -2.9), Vector3(0.5, 0.28, 1.7), PropKit.material(BODY_COLOR), true, Vector3(0, 1.2, 0))
	var pipe := PropKit.material(PIPE_COLOR)
	PropKit.box(body, Vector3(1.75, 0.55, -2.45), Vector3(2.6, 0.26, 0.26), pipe, true, Vector3(0, 0.25, 0.22))
	if Engine.is_editor_hint():
		return
	var interactable := PropKit.interactable(body, Interactable.Mode.INSPECT, "ОСМОТРЕТЬ", "senior_body")
	interactable.name = "Inspect"


func _build_shield() -> void:
	var shield := StaticBody3D.new()
	shield.name = "FireShieldBoard"
	add_child(shield)
	PropKit.box(shield, Vector3(11.0, 1.3, 0), Vector3(0.05, 1.6, 1.2), PropKit.material(SHIELD_COLOR), true)
	var title := PropKit.label(shield, Vector3(10.96, 2.0, 0), "ПОЖАРНЫЙ ЩИТ", 40)
	title.rotation = Vector3(0, -PI * 0.5, 0)
