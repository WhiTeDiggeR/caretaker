extends Node3D

@export var flicker_enabled := false
@export var base_energy := 9.25

@onready var main_light: SpotLight3D = $Light

var _next_change := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	main_light.light_energy = base_energy

func _process(delta: float) -> void:
	if not flicker_enabled:
		return
	_next_change -= delta
	if _next_change > 0.0:
		return
	_next_change = _rng.randf_range(0.04, 0.45)
	var dimmed := _rng.randf() < 0.2
	main_light.light_energy = base_energy * (0.18 if dimmed else _rng.randf_range(0.78, 1.0))
