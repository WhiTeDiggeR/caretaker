extends Node3D

## Sandbox station for #99: press, hold, inspect and an unavailable object.

const LAMP_OFF := Color(0.25, 0.08, 0.06)
const LAMP_ON := Color(0.2, 0.9, 0.35)
const WHEEL_TURNS := 1.5

@onready var _button: Interactable = $Button/Interactable
@onready var _lamp: MeshInstance3D = $Lamp
@onready var _wheel_body: Node3D = $Wheel
@onready var _wheel: Interactable = $Wheel/Interactable
@onready var _wheel_state: Label3D = $Wheel/State

var _lamp_on := false
var _lamp_material: StandardMaterial3D


func _ready() -> void:
	_lamp_material = (_lamp.get_surface_override_material(0) as StandardMaterial3D).duplicate()
	_lamp.set_surface_override_material(0, _lamp_material)
	_set_lamp(false)
	_button.interacted.connect(func() -> void: _set_lamp(not _lamp_on))
	_wheel.hold_progress_changed.connect(_on_wheel_progress)
	_wheel.hold_cancelled.connect(func() -> void: _wheel_body.rotation.z = 0.0)
	_wheel.interacted.connect(_on_wheel_done)


func _set_lamp(on: bool) -> void:
	_lamp_on = on
	var color := LAMP_ON if on else LAMP_OFF
	_lamp_material.albedo_color = color
	_lamp_material.emission = color


func _on_wheel_progress(ratio: float) -> void:
	_wheel_body.rotation.z = -ratio * TAU * WHEEL_TURNS


func _on_wheel_done() -> void:
	_wheel_state.text = "ОТКРЫТО"
