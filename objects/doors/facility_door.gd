@tool
class_name FacilityDoor
extends Node3D

## Door of the facility with readable lock reasons. Placeholder geometry (frame, sliding
## leaf, controls on both sides) is generated from `width`/`height`, so presets only set
## exports. Powered doors open from a panel and need section power; mechanical doors open
## with a hand wheel (hold) and work without power. Both may require an access grant or be
## put under emergency lock. An airlock interlocks two doors through `interlock_partner`.

signal state_changed(state: State)
signal opened
signal closed

enum Kind { POWERED, MECHANICAL }
enum State { CLOSED, OPENING, OPEN, CLOSING }
## How the leaf opens (decision R-10, docs/game_design/02-prop-standard.md):
## SIDE — slides into a wall pocket (hermetic and mechanical doors),
## UP — rises like a shutter (late sectors), SWING — hinged leaf (old core «historic»).
enum SlideAxis { SIDE, UP, SWING }

const REASON_NO_POWER := "НЕТ ПИТАНИЯ"
const REASON_NO_ACCESS := "НЕТ ДОПУСКА"
const REASON_EMERGENCY := "БЛОКИРОВКА: АВАРИЯ"
const REASON_INTERLOCK := "ШЛЮЗ: ВТОРАЯ ДВЕРЬ ОТКРЫТА"
const REASON_CYCLE := "ШЛЮЗ: ИДЁТ ЦИКЛ"
const REASON_MOVING := ""

const FRAME_DEPTH := 0.3
const FRAME_POST := 0.2
const LEAF_DEPTH := 0.12
const CONTROL_OFFSET := 0.45  # from the frame edge to the control centre
const CONTROL_HEIGHT := 1.25
const SWING_ANGLE := deg_to_rad(95.0)
const LAMP_OFF := Color(0.05, 0.05, 0.05)
const LAMP_READY := Color(0.15, 0.85, 0.3)
const LAMP_LOCKED := Color(0.9, 0.15, 0.1)

@export var kind: Kind = Kind.POWERED
@export var width := 1.8
@export var height := 2.8
@export var slide_axis: SlideAxis = SlideAxis.SIDE
@export var open_time := 1.4
@export var section: StringName = &""
@export var required_access: StringName = &""
@export var emergency_lock := false:
	set(value):
		emergency_lock = value
		refresh()
@export var starts_open := false
@export var hold_time := 1.6
@export var open_prompt := ""
@export var close_prompt := ""
@export var leaf_color := Color(0.33, 0.35, 0.36)
@export var frame_color := Color(0.22, 0.23, 0.24)

## Set by an airlock: the door may open only while the partner is closed.
var interlock_partner: FacilityDoor
## Set by an airlock while its cycle runs.
var cycle_lock := false
## Set by an airlock: the door's controls ask it to open the door instead of moving
## the door directly (receives this door).
var operator: Callable

var state: State = State.CLOSED
var _leaf: AnimatableBody3D
## 0 — closed, 1 — open; drives the leaf pose.
var _open_amount := 0.0:
	set(value):
		_open_amount = value
		_apply_leaf_pose()
var _controls: Array[Interactable] = []
var _lamps: Array[StandardMaterial3D] = []
var _tween: Tween


func _ready() -> void:
	_build()
	if starts_open:
		state = State.OPEN
		_open_amount = 1.0
	if Engine.is_editor_hint():
		return
	add_to_group(&"persist")
	GameState.section_power_changed.connect(func(_section: StringName, _power: int) -> void: refresh())
	GameState.access_changed.connect(func(_access: StringName, _granted: bool) -> void: refresh())
	GameState.state_loaded.connect(refresh)
	refresh()


func save_state() -> Dictionary:
	return {"open": state == State.OPEN or state == State.OPENING}


## Restores a saved door at once, without the opening animation.
func load_state(data: Dictionary) -> void:
	if _tween:
		_tween.kill()
	var open_door := bool(data.get("open", false))
	state = State.OPEN if open_door else State.CLOSED
	_open_amount = 1.0 if open_door else 0.0
	refresh()
	state_changed.emit(state)


func is_open() -> bool:
	return state == State.OPEN


func is_closed() -> bool:
	return state == State.CLOSED


func is_powered() -> bool:
	return kind == Kind.MECHANICAL or GameState.is_section_powered(section)


## Why the door cannot be operated now, or an empty string when it can.
func lock_reason() -> String:
	if not is_powered():
		return REASON_NO_POWER
	if emergency_lock:
		return REASON_EMERGENCY
	if not GameState.has_access(required_access):
		return REASON_NO_ACCESS
	if cycle_lock:
		return REASON_CYCLE
	if state == State.OPENING or state == State.CLOSING:
		return REASON_MOVING
	if not operator.is_valid() and _interlocked():
		return REASON_INTERLOCK
	return ""


func _interlocked() -> bool:
	return state == State.CLOSED and interlock_partner != null and not interlock_partner.is_closed()


func can_operate() -> bool:
	return lock_reason().is_empty() and (state == State.OPEN or state == State.CLOSED)


func open() -> bool:
	if state != State.CLOSED or not can_operate() or _interlocked():
		return false
	_move(true)
	return true


func close() -> bool:
	if state != State.OPEN or not can_operate():
		return false
	_move(false)
	return true


func toggle() -> bool:
	return close() if state == State.OPEN else open()


## Moves the door regardless of locks (used by airlock cycles and scripted events).
func force(open_door: bool) -> void:
	if (open_door and state in [State.OPEN, State.OPENING]) or (not open_door and state in [State.CLOSED, State.CLOSING]):
		return
	_move(open_door)


func refresh() -> void:
	if _controls.is_empty() or Engine.is_editor_hint():
		return
	var reason := lock_reason()
	var available := reason.is_empty() and (state == State.OPEN or state == State.CLOSED)
	for control in _controls:
		control.available = available
		control.unavailable_prompt = reason
		control.prompt = _prompt()
	var lamp_color := LAMP_READY if available else LAMP_LOCKED
	if not is_powered():
		lamp_color = LAMP_OFF
	for lamp in _lamps:
		lamp.albedo_color = lamp_color
		lamp.emission = lamp_color


func _prompt() -> String:
	if state == State.OPEN:
		if not close_prompt.is_empty():
			return close_prompt
		return "ЗАКРЫТЬ ДВЕРЬ" if kind == Kind.POWERED else "ПОВЕРНУТЬ ШТУРВАЛ: ЗАКРЫТЬ"
	if not open_prompt.is_empty():
		return open_prompt
	if operator.is_valid():
		return "ОТКРЫТЬ ШЛЮЗ"
	return "ОТКРЫТЬ ДВЕРЬ" if kind == Kind.POWERED else "ПОВЕРНУТЬ ШТУРВАЛ"


func _move(open_door: bool) -> void:
	if _tween:
		_tween.kill()
	state = State.OPENING if open_door else State.CLOSING
	refresh()
	if interlock_partner:
		interlock_partner.refresh()
	state_changed.emit(state)
	var target := 1.0 if open_door else 0.0
	var duration := open_time * absf(target - _open_amount)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "_open_amount", target, maxf(duration, 0.01))
	_tween.finished.connect(_on_move_finished.bind(open_door))


func _on_move_finished(open_door: bool) -> void:
	state = State.OPEN if open_door else State.CLOSED
	refresh()
	if interlock_partner:
		interlock_partner.refresh()
	state_changed.emit(state)
	if open_door:
		opened.emit()
	else:
		closed.emit()


func _apply_leaf_pose() -> void:
	if _leaf == null:
		return
	if slide_axis == SlideAxis.SWING:
		_leaf.position = Vector3(-width * 0.5, 0, 0)
		_leaf.rotation.y = -SWING_ANGLE * _open_amount
	else:
		_leaf.position = _open_position() * _open_amount
		_leaf.rotation.y = 0.0


func _open_position() -> Vector3:
	if slide_axis == SlideAxis.UP:
		return Vector3(0, height - 0.15, 0)
	return Vector3(width + FRAME_POST * 0.5, 0, 0)


func _on_control_used() -> void:
	if operator.is_valid():
		operator.call(self)
	else:
		toggle()


# --- Placeholder geometry ----------------------------------------------------

func _build() -> void:
	for child in get_children():
		if child.has_meta(&"door_generated"):
			child.free()
	_controls.clear()
	_lamps.clear()
	var frame_material := _material(frame_color)
	var frame := StaticBody3D.new()
	frame.name = "Frame"
	_generated(frame)
	var post_x := width * 0.5 + FRAME_POST * 0.5
	_box(frame, Vector3(-post_x, height * 0.5, 0), Vector3(FRAME_POST, height, FRAME_DEPTH), frame_material, true)
	_box(frame, Vector3(post_x, height * 0.5, 0), Vector3(FRAME_POST, height, FRAME_DEPTH), frame_material, true)
	_box(frame, Vector3(0, height + FRAME_POST * 0.5, 0), Vector3(width + FRAME_POST * 2.0, FRAME_POST, FRAME_DEPTH), frame_material, true)

	_leaf = AnimatableBody3D.new()
	_leaf.name = "Leaf"
	_leaf.sync_to_physics = false
	_generated(_leaf)
	# A hinged leaf turns around its left edge, so its geometry is offset from the hinge.
	var leaf_x := width * 0.5 if slide_axis == SlideAxis.SWING else 0.0
	_box(_leaf, Vector3(leaf_x, height * 0.5, 0), Vector3(width, height, LEAF_DEPTH), _material(leaf_color), true)
	_box(_leaf, Vector3(leaf_x, height * 0.5, 0), Vector3(width * 0.9, 0.12, LEAF_DEPTH + 0.02), _material(Color(0.75, 0.6, 0.15)), false)
	_apply_leaf_pose()

	for side in [1.0, -1.0]:
		var control := StaticBody3D.new()
		control.name = "ControlFront" if side > 0.0 else "ControlBack"
		control.position = Vector3(-(post_x + CONTROL_OFFSET), CONTROL_HEIGHT, side * (FRAME_DEPTH * 0.5 + 0.06))
		_generated(control)
		var lamp_material := _material(LAMP_OFF, true)
		_lamps.append(lamp_material)
		if kind == Kind.POWERED:
			_box(control, Vector3.ZERO, Vector3(0.28, 0.4, 0.08), _material(Color(0.12, 0.13, 0.14)), true)
			_box(control, Vector3(0, 0.1, side * 0.045), Vector3(0.1, 0.1, 0.02), lamp_material, false)
		else:
			var wheel := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.18
			torus.outer_radius = 0.24
			torus.material = _material(Color(0.45, 0.18, 0.12))
			wheel.mesh = torus
			wheel.rotation = Vector3(PI * 0.5, 0, 0)
			control.add_child(wheel)
			var shape := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = 0.26
			cylinder.height = 0.1
			shape.shape = cylinder
			shape.rotation = Vector3(PI * 0.5, 0, 0)
			control.add_child(shape)
			_box(control, Vector3(0, 0.36, 0), Vector3(0.08, 0.08, 0.04), lamp_material, false)
		var interactable := Interactable.new()
		interactable.mode = Interactable.Mode.PRESS if kind == Kind.POWERED else Interactable.Mode.HOLD
		interactable.hold_time = hold_time
		interactable.prompt = _prompt()
		control.add_child(interactable)
		if not Engine.is_editor_hint():
			interactable.interacted.connect(_on_control_used)
		_controls.append(interactable)


func _generated(node: Node3D) -> void:
	node.set_meta(&"door_generated", true)
	add_child(node)


func _box(parent: Node3D, position: Vector3, size: Vector3, material: Material, collide: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	parent.add_child(mesh_instance)
	if collide:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = position
		parent.add_child(shape)


func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	material.metallic = 0.4
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	return material
