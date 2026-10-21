@tool
class_name RepairControl
extends StaticBody3D

## On/off repair control: lever, valve, knife switch or circuit breaker. Its state lives in
## GameState as the flag `ctl/<control_id>`, so it is saved and drives RepairProcedure.
## The look is the art model of its kind (loads/props, #241) with a simple box collision; the
## model's moving part (wheel, lever, handle) turns with the control.

signal toggled(on: bool)

enum Kind { LEVER, VALVE, SWITCH, BREAKER }

const SOUNDS: Dictionary[Kind, StringName] = {Kind.LEVER: &"lever", Kind.VALVE: &"valve", Kind.SWITCH: &"switch", Kind.BREAKER: &"breaker"}

## Art model, its moving part and where the model sits relative to the control's origin (the
## pivot of the moving part stays near the origin, as with the earlier placeholders). A floor
## lever stands on the floor: its origin is the lever's pivot 0.2 m above it.
const MODELS: Dictionary[Kind, PackedScene] = {
	Kind.LEVER: preload("res://loads/props/start_lever/start_lever.gltf"),
	Kind.VALVE: preload("res://loads/props/valve_wheel/valve_wheel.gltf"),
	Kind.SWITCH: preload("res://loads/props/wall_breaker/wall_breaker.gltf"),
	Kind.BREAKER: preload("res://loads/props/wall_breaker/wall_breaker.gltf"),
}
const MOVING_PART: Dictionary[Kind, NodePath] = {Kind.LEVER: ^"Lever", Kind.VALVE: ^"Wheel", Kind.SWITCH: ^"Handle", Kind.BREAKER: ^"Handle"}
const MODEL_OFFSET: Dictionary[Kind, Vector3] = {
	Kind.LEVER: Vector3(0, -0.2, 0),
	Kind.VALVE: Vector3.ZERO,
	Kind.SWITCH: Vector3(0, -0.175, -0.12),
	Kind.BREAKER: Vector3(0, -0.105, -0.08),
}
## The breaker is the same model as the switch, smaller.
const MODEL_SCALE: Dictionary[Kind, float] = {Kind.LEVER: 1.0, Kind.VALVE: 1.0, Kind.SWITCH: 1.0, Kind.BREAKER: 0.6}
## Collision box of each kind (centre, size); it also catches the interaction ray.
const SHAPE_CENTER: Dictionary[Kind, Vector3] = {
	Kind.LEVER: Vector3(0, 0.4, 0),
	Kind.VALVE: Vector3(0, 0, -0.05),
	Kind.SWITCH: Vector3(0, 0, -0.06),
	Kind.BREAKER: Vector3(0, 0, -0.05),
}
const SHAPE_SIZE: Dictionary[Kind, Vector3] = {
	Kind.LEVER: Vector3(0.4, 1.2, 0.3),
	Kind.VALVE: Vector3(0.34, 0.34, 0.2),
	Kind.SWITCH: Vector3(0.3, 0.4, 0.2),
	Kind.BREAKER: Vector3(0.16, 0.24, 0.12),
}

const FLAG_PREFIX := "ctl/"
const ANIMATION_TIME := 0.35

@export var kind: Kind = Kind.SWITCH
@export var control_id: StringName = &""
@export var prompt_on := ""
@export var prompt_off := ""
@export var hold_time := 1.2
## Shown when a procedure fixed the control after its step was completed.
@export var fixed_prompt := ""

var interactable: Interactable
var fixed := false
var _moving: Node3D
var _tween: Tween


static func flag_for(id: StringName) -> StringName:
	return StringName(FLAG_PREFIX + String(id))


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	interactable.interacted.connect(func() -> void: set_on(not is_on()))
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_loaded.connect(func() -> void: _refresh(true))
	_refresh(true)


func is_on() -> bool:
	return GameState.has_flag(flag_for(control_id))


func set_on(on: bool) -> void:
	if on == is_on():
		return
	Sfx.play(SOUNDS[kind], self)
	if on:
		GameState.set_flag(flag_for(control_id))
	else:
		GameState.clear_flag(flag_for(control_id))


func set_fixed(value: bool) -> void:
	fixed = value
	_refresh(false)


func _on_flag_changed(flag: StringName, _value: Variant) -> void:
	if flag != flag_for(control_id):
		return
	_refresh(false)
	toggled.emit(is_on())


func _refresh(instant: bool) -> void:
	var on := is_on()
	interactable.prompt = _prompt(on)
	interactable.available = not fixed
	interactable.unavailable_prompt = fixed_prompt
	if _tween:
		_tween.kill()
	var target := _pose(on)
	if instant:
		_moving.rotation = target
	else:
		_tween = create_tween()
		_tween.tween_property(_moving, "rotation", target, ANIMATION_TIME)


func _prompt(on: bool) -> String:
	if on and not prompt_off.is_empty():
		return prompt_off
	if not on and not prompt_on.is_empty():
		return prompt_on
	match kind:
		Kind.LEVER:
			return "ВЕРНУТЬ РЫЧАГ" if on else "ПОТЯНУТЬ РЫЧАГ"
		Kind.VALVE:
			return "ЗАКРЫТЬ ВЕНТИЛЬ" if on else "ОТКРЫТЬ ВЕНТИЛЬ"
		Kind.BREAKER:
			return "ОТКЛЮЧИТЬ АВТОМАТ" if on else "ВЗВЕСТИ АВТОМАТ"
	return "ВЫКЛЮЧИТЬ РУБИЛЬНИК" if on else "ВКЛЮЧИТЬ РУБИЛЬНИК"


func _pose(on: bool) -> Vector3:
	match kind:
		Kind.VALVE:
			return Vector3(0, 0, -TAU * 1.5 if on else 0.0)
		Kind.LEVER, Kind.SWITCH:
			return Vector3(deg_to_rad(-50.0 if on else 50.0), 0, 0)
	return Vector3(deg_to_rad(-30.0 if on else 30.0), 0, 0)


# --- Art model -----------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		if child.has_meta(&"repair_generated"):
			child.free()
	var model := MODELS[kind].instantiate() as Node3D
	model.position = MODEL_OFFSET[kind]
	model.scale = Vector3.ONE * MODEL_SCALE[kind]
	_generated(model)
	var part := model.get_node(MOVING_PART[kind]) as Node3D
	_moving = Node3D.new()
	_moving.position = (model.transform * part.transform).origin
	_generated(_moving)
	part.reparent(_moving, false)
	part.transform = Transform3D(Basis.from_scale(model.scale), Vector3.ZERO)
	_generated_shape(SHAPE_CENTER[kind], SHAPE_SIZE[kind])
	interactable = Interactable.new()
	interactable.mode = Interactable.Mode.HOLD if kind in [Kind.LEVER, Kind.VALVE] else Interactable.Mode.PRESS
	interactable.hold_time = hold_time
	interactable.set_meta(&"repair_generated", true)
	add_child(interactable)


func _generated(node: Node) -> void:
	node.set_meta(&"repair_generated", true)
	add_child(node)


func _generated_shape(position: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = position
	_generated(shape)
