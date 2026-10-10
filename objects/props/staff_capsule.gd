@tool
class_name StaffCapsule
extends StaticBody3D

## Emergency sleep capsule of the staff block (≈1.0 × 1.2 × 2.4 m, lying). The status panel
## at the foot end is inspected; the hero's damaged capsule has a jammed lid that is pushed
## open by holding the interact key.

enum Variant { OCCUPIED, EMPTY, HERO }

const LENGTH := 2.4
const WIDTH := 1.0
const BASE_HEIGHT := 0.55
const LID_OPEN_ANGLE := deg_to_rad(-75.0)  # negative lifts the free edge (hinge on +X)
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
	PropKit.box(self, Vector3(0, BASE_HEIGHT + 0.03, 0), Vector3(WIDTH * 0.86, 0.06, LENGTH * 0.92), dark)
	if variant == Variant.OCCUPIED:
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.2
		capsule.height = 1.7
		capsule.material = PropKit.material(Color(0.3, 0.32, 0.35))
		body.mesh = capsule
		body.position = Vector3(0, BASE_HEIGHT + 0.22, -0.05)
		body.rotation = Vector3(PI * 0.5, 0, 0)
		add_child(body)
	# Lid hinged on the +X side, frosted so faces stay unreadable (opening doc, Р-6).
	lid = AnimatableBody3D.new()
	lid.sync_to_physics = false
	lid.position = Vector3(WIDTH * 0.5, BASE_HEIGHT, 0)
	add_child(lid)
	PropKit.box(lid, Vector3(-WIDTH * 0.45, 0.32, 0), Vector3(WIDTH * 0.9, 0.62, LENGTH * 0.94), PropKit.material(Color(0.78, 0.88, 0.92), false, 0.42), true)
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
