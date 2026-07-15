extends Node3D

@export var pulse_speed := 2.2
@export var minimum_energy := 0.45
@export var maximum_energy := 1.5

@onready var light: OmniLight3D = $Light
var _phase := 0.0

func _ready() -> void:
	_phase = randf() * TAU

func _process(delta: float) -> void:
	_phase += delta * pulse_speed
	var pulse := (sin(_phase) + 1.0) * 0.5
	light.light_energy = lerpf(minimum_energy, maximum_energy, pulse)
