@tool
class_name StaffCapsule
extends StaticBody3D

## Emergency sleep capsule of the staff block (≈1.2 × 1.35 × 2.6 m, lying). The status panel
## at the foot end is inspected; the hero's damaged capsule has a jammed lid that is pushed
## open by holding the interact key.
## Sized for a large occupant (docs/game_design/02-prop-standard.md): up to 2.0 m tall and
## 0.6 m across the shoulders, plus room to turn and to raise the head. A fixed tub rises
## RIM_HEIGHT above the floor; the lid is a low hollow frosted canopy on top of it, so the
## sleeper inside stays visible as a silhouette only. The canopy opens upright on its +X
## hinge and stays inside the 0.6 m gap of the hall pitch (1.8 m): it never reaches the
## neighbour and never hangs over the bed.

enum Variant { OCCUPIED, EMPTY, HERO }

const LENGTH := 2.6
const WIDTH := 1.2
const BASE_HEIGHT := 0.5
## Inner bed (mattress) and the free height above it under the closed lid.
const BED_LENGTH := 2.3
const BED_WIDTH := 1.0
const BED_THICKNESS := 0.06
## Fixed tub walls up to RIM_HEIGHT, the canopy lid of LID_HEIGHT above them.
const RIM_HEIGHT := 0.8
const TUB_WALL := 0.06
const LID_HEIGHT := 0.55
const LID_WALL := 0.04
## Hall pitch of the capsules (Р-11): the open lid must stay inside the gap.
const HALL_PITCH := 1.8
## Largest occupant the capsule is designed for.
const DESIGN_OCCUPANT_HEIGHT := 2.0
const DESIGN_OCCUPANT_SHOULDERS := 0.6
## Placeholder sleeper: an average adult for scale.
const SLEEPER_HEIGHT := 1.75
const LID_OPEN_ANGLE := deg_to_rad(-90.0)  # negative lifts the free edge (hinge on +X)
const HERO_LID_FLAG := &"opening/hero_capsule_open"
const PANEL_TEXT := {Variant.OCCUPIED: "pod_staff_occupied", Variant.EMPTY: "pod_staff_empty", Variant.HERO: "pod_hero"}
const LAMP := {Variant.OCCUPIED: Color(0.2, 0.85, 0.35), Variant.EMPTY: Color(0.08, 0.08, 0.08), Variant.HERO: Color(0.95, 0.2, 0.1)}

@export var variant: Variant = Variant.OCCUPIED

var lid: AnimatableBody3D
var panel_interactable: Interactable
var lid_interactable: Interactable


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	if variant == Variant.HERO:
		lid_interactable.interacted.connect(open_lid)
		GameState.state_loaded.connect(func() -> void: _pose_lid(is_open()))
		_pose_lid(is_open())


func is_open() -> bool:
	return variant == Variant.EMPTY or (variant == Variant.HERO and GameState.has_flag(HERO_LID_FLAG))


func open_lid() -> void:
	if variant != Variant.HERO or is_open():
		return
	GameState.set_flag(HERO_LID_FLAG)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(lid, "rotation:z", LID_OPEN_ANGLE, 0.7)
	lid_interactable.available = false


func _pose_lid(open: bool) -> void:
	lid.rotation.z = LID_OPEN_ANGLE if open else (deg_to_rad(-6.0) if variant == Variant.HERO else 0.0)
	if lid_interactable:
		lid_interactable.available = not open


func _build() -> void:
	var shell := PropKit.material(Color(0.62, 0.64, 0.64))
	var dark := PropKit.material(Color(0.18, 0.19, 0.2))
	PropKit.box(self, Vector3(0, BASE_HEIGHT * 0.5, 0), Vector3(WIDTH, BASE_HEIGHT, LENGTH), shell, true)
	PropKit.box(self, Vector3(0, BASE_HEIGHT + BED_THICKNESS * 0.5, 0), Vector3(BED_WIDTH, BED_THICKNESS, BED_LENGTH), dark, true)
	_build_tub(shell)
	if variant == Variant.OCCUPIED:
		_build_sleeper(BASE_HEIGHT + BED_THICKNESS)
	# Lid hinged on the +X side, frosted so faces stay unreadable (opening doc, Р-6).
	lid = AnimatableBody3D.new()
	lid.sync_to_physics = false
	lid.position = Vector3(WIDTH * 0.5, RIM_HEIGHT, 0)
	add_child(lid)
	_build_lid()
	if variant == Variant.EMPTY:
		lid.rotation.z = LID_OPEN_ANGLE
	if variant == Variant.HERO:
		lid_interactable = PropKit.interactable(lid, Interactable.Mode.HOLD, "ВЫТОЛКНУТЬ КРЫШКУ")
		lid_interactable.hold_time = 1.5
		lid_interactable.unavailable_prompt = ""
		lid.rotation.z = deg_to_rad(-6.0)
	var panel := StaticBody3D.new()
	panel.position = Vector3(0, 0, LENGTH * 0.5 + 0.12)
	add_child(panel)
	PropKit.box(panel, Vector3(0, 0.5, 0), Vector3(0.12, 1.0, 0.12), dark, true)
	PropKit.box(panel, Vector3(0, 1.1, 0.02), Vector3(0.42, 0.3, 0.06), dark, true, Vector3(deg_to_rad(-20.0), 0, 0))
	PropKit.box(panel, Vector3(0.14, 1.18, 0.07), Vector3(0.06, 0.06, 0.02), PropKit.material(LAMP[variant], true))
	panel_interactable = PropKit.interactable(panel, Interactable.Mode.INSPECT, "ОСМОТРЕТЬ ПАНЕЛЬ КАПСУЛЫ", PANEL_TEXT[variant])


## Fixed walls around the bed from the base up to the rim.
func _build_tub(mat: Material) -> void:
	var height := RIM_HEIGHT - BASE_HEIGHT
	var y := BASE_HEIGHT + height * 0.5
	for side: float in [-1.0, 1.0]:
		PropKit.box(self, Vector3(side * (WIDTH - TUB_WALL) * 0.5, y, 0), Vector3(TUB_WALL, height, LENGTH), mat, true)
		PropKit.box(self, Vector3(0, y, side * (LENGTH - TUB_WALL) * 0.5), Vector3(WIDTH, height, TUB_WALL), mat, true)


## Hollow frosted canopy in the lid's frame (hinge line at the origin, the shell towards -X):
## top plate, two long walls and two end walls, each with its own thin collision.
func _build_lid() -> void:
	var glass := PropKit.material(Color(0.78, 0.88, 0.92), false, 0.42)
	var frame := PropKit.material(Color(0.5, 0.52, 0.53))
	var centre_x := -WIDTH * 0.5
	PropKit.box(lid, Vector3(centre_x, LID_HEIGHT - LID_WALL * 0.5, 0), Vector3(WIDTH, LID_WALL, LENGTH), glass, true)
	for side: float in [-1.0, 1.0]:
		PropKit.box(lid, Vector3(centre_x + side * (WIDTH - LID_WALL) * 0.5, LID_HEIGHT * 0.5, 0), Vector3(LID_WALL, LID_HEIGHT, LENGTH), glass, true)
		PropKit.box(lid, Vector3(centre_x, LID_HEIGHT * 0.5, side * (LENGTH - LID_WALL) * 0.5), Vector3(WIDTH, LID_HEIGHT, LID_WALL), frame, true)


## Lying adult on its back, head towards -Z (the panel is at the feet, +Z).
func _build_sleeper(bed_top: float) -> void:
	var cloth := PropKit.material(Color(0.3, 0.32, 0.35))
	var skin := PropKit.material(Color(0.55, 0.5, 0.47))
	var k := SLEEPER_HEIGHT / 1.75  # proportions below are for a 1.75 m adult
	var head_z := -SLEEPER_HEIGHT * 0.5 + 0.12 * k
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.11 * k
	sphere.height = 0.22 * k
	sphere.material = skin
	head.mesh = sphere
	head.position = Vector3(0, bed_top + 0.11 * k, head_z)
	add_child(head)
	var torso_length := 0.62 * k
	var torso_z := head_z + 0.14 * k + torso_length * 0.5
	PropKit.box(self, Vector3(0, bed_top + 0.11 * k, torso_z), Vector3(0.46 * k, 0.22 * k, torso_length), cloth)
	var leg_length := SLEEPER_HEIGHT * 0.5 - (torso_z + torso_length * 0.5)
	for side: float in [-1.0, 1.0]:
		PropKit.box(self, Vector3(side * 0.11 * k, bed_top + 0.07 * k, torso_z + torso_length * 0.5 + leg_length * 0.5), Vector3(0.16 * k, 0.14 * k, leg_length), cloth)
		PropKit.box(self, Vector3(side * 0.29 * k, bed_top + 0.06 * k, torso_z), Vector3(0.1 * k, 0.12 * k, 0.6 * k), cloth)
