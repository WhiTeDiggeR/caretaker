@tool
class_name FacilityDoor
extends Node3D

## Door of the facility with readable lock reasons. Geometry (frame, sliding leaf, controls
## on both sides; art from `DoorArt`, #157) is generated from `width`/`height`, so presets
## only set exports. Powered doors open from a panel and need section power; mechanical doors open
## with a hand wheel (hold) and work without power. Both may require an access grant or be
## put under emergency lock. An airlock interlocks two doors through `interlock_partner`.
## The hand wheel turns while the hold runs and rolls back when it is let go (#174); a manual
## door's handle sits on the leaf at its free edge and has no lamp.

signal state_changed(state: State)
signal opened
signal closed

## POWERED — panel, needs section power; MECHANICAL — hand wheel (hold), no power;
## MANUAL — ordinary handle (press), no power (service room doors).
enum Kind { POWERED, MECHANICAL, MANUAL }
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
const WHEEL_TURNS := 1.5  # hand wheel turns over a full hold
const WHEEL_RETURN_TIME := 0.4  # a hand wheel let go rolls back to its rest position
## Handle of a manual door: centre from the leaf's free edge, height, and the interaction zone
## around it (larger than the small handle model).
const HANDLE_INSET := 0.08
const HANDLE_HEIGHT := 1.05
const HANDLE_ZONE := Vector3(0.32, 0.36, 0.1)
const LAMP_OFF := Color(0.05, 0.05, 0.05)
const LAMP_READY := Color(0.15, 0.85, 0.3)
const LAMP_LOCKED := Color(0.9, 0.15, 0.1)
const SOUND_MOVE: Dictionary[Kind, StringName] = {Kind.POWERED: &"door_motor", Kind.MECHANICAL: &"door_mech", Kind.MANUAL: &"door_swing"}
const SOUND_STOP := &"door_stop"
## The wheel being let go: the stop sound, quieter and shortened (a short roll-back knock).
const WHEEL_KNOCK_TIME := 0.7
const WHEEL_KNOCK_DB := -6.0
## A locked handle rattles (manual doors only); wheels and powered panels keep the common refusal.
const SOUND_LOCKED := &"door_locked"

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
var _wheels: Array[Node3D] = []
## 0 — the wheel at the closed door's rest, 1 — at the open door's rest (one full hold apart).
var _wheel_turn := 0.0:
	set(value):
		_wheel_turn = value
		_apply_wheel_pose()
var _tween: Tween
var _wheel_tween: Tween
## Hand wheel sound: owned by the door so it can be cut off when the wheel is let go.
var _wheel_audio: AudioStreamPlayer3D
var _wheel_turning_sound := false


func _ready() -> void:
	_build()
	if starts_open:
		state = State.OPEN
		_open_amount = 1.0
		_wheel_turn = 1.0
	if Engine.is_editor_hint():
		return
	if kind == Kind.MECHANICAL:
		_wheel_audio = AudioStreamPlayer3D.new()
		_wheel_audio.name = "WheelAudio"
		_wheel_audio.position = Vector3(-(width * 0.5 + FRAME_POST * 0.5 + CONTROL_OFFSET), CONTROL_HEIGHT, 0)
		add_child(_wheel_audio)
	add_to_group(&"persist")
	GameState.section_power_changed.connect(func(_section: StringName, _power: int) -> void: refresh())
	GameState.access_changed.connect(func(_access: StringName, _granted: bool) -> void: refresh())
	GameState.state_loaded.connect(refresh)
	refresh()


func save_state() -> Dictionary:
	return {"open": state == State.OPEN or state == State.OPENING, "emergency_lock": emergency_lock}


## Restores a saved door at once, without the opening animation.
func load_state(data: Dictionary) -> void:
	if _tween:
		_tween.kill()
	var open_door := bool(data.get("open", false))
	# Scripted events lock doors (#133); older saves have no lock key and keep the authored one.
	if data.has("emergency_lock"):
		emergency_lock = bool(data["emergency_lock"])
	state = State.OPEN if open_door else State.CLOSED
	_open_amount = 1.0 if open_door else 0.0
	_stop_wheel()
	_wheel_turn = _open_amount
	refresh()
	state_changed.emit(state)


func is_open() -> bool:
	return state == State.OPEN


func is_closed() -> bool:
	return state == State.CLOSED


func is_powered() -> bool:
	return kind != Kind.POWERED or GameState.is_section_powered(section)


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
		var rattles := kind == Kind.MANUAL and not reason.is_empty() and reason != REASON_MOVING
		control.denied_sound = SOUND_LOCKED if rattles else &""
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
		return "ПОВЕРНУТЬ ШТУРВАЛ: ЗАКРЫТЬ" if kind == Kind.MECHANICAL else "ЗАКРЫТЬ ДВЕРЬ"
	if not open_prompt.is_empty():
		return open_prompt
	if operator.is_valid():
		return "ОТКРЫТЬ ШЛЮЗ"
	return "ПОВЕРНУТЬ ШТУРВАЛ" if kind == Kind.MECHANICAL else "ОТКРЫТЬ ДВЕРЬ"


func _move(open_door: bool) -> void:
	if _tween:
		_tween.kill()
	state = State.OPENING if open_door else State.CLOSING
	refresh()
	if interlock_partner:
		interlock_partner.refresh()
	state_changed.emit(state)
	if not Engine.is_editor_hint():
		Sfx.play(SOUND_MOVE[kind], self)
	var target := 1.0 if open_door else 0.0
	var duration := open_time * absf(target - _open_amount)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "_open_amount", target, maxf(duration, 0.01))
	_tween.finished.connect(_on_move_finished.bind(open_door))
	# A full hold has already turned the wheel; a door moved otherwise (airlock, script) turns it with the leaf.
	_stop_wheel()
	if not is_equal_approx(_wheel_turn, target):
		_wheel_tween = create_tween()
		_wheel_tween.tween_property(self, "_wheel_turn", target, maxf(duration, 0.01))


func _on_move_finished(open_door: bool) -> void:
	state = State.OPEN if open_door else State.CLOSED
	if kind != Kind.MANUAL:
		Sfx.play(SOUND_STOP, self)
	refresh()
	if interlock_partner:
		interlock_partner.refresh()
	state_changed.emit(state)
	if open_door:
		opened.emit()
	else:
		closed.emit()


func _apply_wheel_pose() -> void:
	for wheel in _wheels:
		wheel.rotation.z = TAU * WHEEL_TURNS * _wheel_turn


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
	# A completed hold the door refused (or an airlock that only queued a cycle) leaves the wheel turned.
	if kind == Kind.MECHANICAL and (state == State.OPEN or state == State.CLOSED):
		_on_wheel_cancelled()


## The wheel follows the hold: from the rest of the current state towards the other one.
func _on_wheel_progress(ratio: float) -> void:
	if state != State.OPEN and state != State.CLOSED:
		return
	_kill_wheel_tween()
	var rest := 1.0 if state == State.OPEN else 0.0
	_wheel_turn = rest + (1.0 - 2.0 * rest) * clampf(ratio, 0.0, 1.0)
	if _wheel_audio and not _wheel_turning_sound:
		_wheel_turning_sound = true
		Sfx.play_on(_wheel_audio, SOUND_MOVE[kind], hold_time * (1.0 - ratio))


## A hold let go early: the wheel rolls back to its rest with a short knock.
func _on_wheel_cancelled() -> void:
	var rest := 1.0 if state == State.OPEN or state == State.OPENING else 0.0
	if is_equal_approx(_wheel_turn, rest):
		return
	_kill_wheel_tween()
	_wheel_tween = create_tween()
	_wheel_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_wheel_tween.tween_property(self, "_wheel_turn", rest, WHEEL_RETURN_TIME)
	if _wheel_audio:
		_wheel_turning_sound = false
		Sfx.play_on(_wheel_audio, SOUND_STOP, WHEEL_KNOCK_TIME, WHEEL_KNOCK_DB)


## Cuts the hand wheel sound and motion (the leaf takes over, or a save is loaded).
func _stop_wheel() -> void:
	_kill_wheel_tween()
	_wheel_turning_sound = false
	if _wheel_audio:
		_wheel_audio.stop()


func _kill_wheel_tween() -> void:
	if _wheel_tween:
		_wheel_tween.kill()
		_wheel_tween = null


# --- Geometry -----------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		if child.has_meta(&"door_generated"):
			child.free()
	_controls.clear()
	_lamps.clear()
	_wheels.clear()
	var frame := StaticBody3D.new()
	frame.name = "Frame"
	_generated(frame)
	var post_x := width * 0.5 + FRAME_POST * 0.5
	_shape(frame, Vector3(-post_x, height * 0.5, 0), Vector3(FRAME_POST, height, FRAME_DEPTH))
	_shape(frame, Vector3(post_x, height * 0.5, 0), Vector3(FRAME_POST, height, FRAME_DEPTH))
	_shape(frame, Vector3(0, height + FRAME_POST * 0.5, 0), Vector3(width + FRAME_POST * 2.0, FRAME_POST, FRAME_DEPTH))
	DoorArt.frame(frame, width, height, FRAME_POST, FRAME_DEPTH, frame_color)

	_leaf = AnimatableBody3D.new()
	_leaf.name = "Leaf"
	_leaf.sync_to_physics = false
	_generated(_leaf)
	# A hinged leaf turns around its left edge, so its geometry is offset from the hinge.
	var leaf_x := width * 0.5 if slide_axis == SlideAxis.SWING else 0.0
	_shape(_leaf, Vector3(leaf_x, height * 0.5, 0), Vector3(width, height, LEAF_DEPTH))
	DoorArt.leaf(_leaf, slide_axis, width, height, LEAF_DEPTH, leaf_x, leaf_color)

	for side: float in [1.0, -1.0]:
		var control := StaticBody3D.new()
		control.name = "ControlFront" if side > 0.0 else "ControlBack"
		if kind == Kind.MANUAL:
			_build_handle(control, side, leaf_x)
		else:
			control.position = Vector3(-(post_x + CONTROL_OFFSET), CONTROL_HEIGHT, side * (FRAME_DEPTH * 0.5 + 0.06))
			_generated(control)
			var lamp_material := _material(LAMP_OFF, true)
			_lamps.append(lamp_material)
			var wheel := DoorArt.control(control, kind, side, lamp_material)
			if wheel:
				_wheels.append(wheel)
		if kind == Kind.POWERED:
			_shape(control, Vector3.ZERO, Vector3(0.28, 0.4, 0.08))
		elif kind == Kind.MECHANICAL:
			var shape := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = 0.26
			cylinder.height = 0.1
			shape.shape = cylinder
			shape.rotation = Vector3(PI * 0.5, 0, 0)
			# In the plane of the hand wheel, which stands off the wall on its gearbox.
			shape.position = Vector3(0, 0, side * (DoorArt.WHEEL_REACH - DoorArt.WALL_GAP[kind]))
			control.add_child(shape)
		var interactable := Interactable.new()
		interactable.mode = Interactable.Mode.HOLD if kind == Kind.MECHANICAL else Interactable.Mode.PRESS
		interactable.hold_time = hold_time
		interactable.prompt = _prompt()
		control.add_child(interactable)
		if not Engine.is_editor_hint():
			interactable.interacted.connect(_on_control_used)
			if kind == Kind.MECHANICAL:
				interactable.hold_progress_changed.connect(_on_wheel_progress)
				interactable.hold_cancelled.connect(_on_wheel_cancelled)
		_controls.append(interactable)
	_apply_leaf_pose()
	_apply_wheel_pose()


## A manual door's handle: on the leaf face near the edge away from the hinges (a hinged leaf turns about
## its left edge; a sliding leaf leads with its left edge), so it leaves with the leaf. No lamp.
func _build_handle(control: StaticBody3D, side: float, leaf_x: float) -> void:
	var free_edge := 1.0 if slide_axis == SlideAxis.SWING else -1.0
	control.position = Vector3(leaf_x + free_edge * (width * 0.5 - HANDLE_INSET), HANDLE_HEIGHT, side * LEAF_DEPTH * 0.5)
	_leaf.add_child(control)
	# The zone covers the handle standing off the face and reaches a little into the leaf.
	_shape(control, Vector3(0, 0, side * (HANDLE_ZONE.z * 0.5 - 0.01)), HANDLE_ZONE)
	DoorArt.handle(control, side, -free_edge)


func _generated(node: Node3D) -> void:
	node.set_meta(&"door_generated", true)
	add_child(node)


func _shape(parent: Node3D, position: Vector3, size: Vector3) -> void:
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
