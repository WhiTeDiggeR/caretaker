class_name SectionLight
extends PowerConsumer

## Switches a light by section power: off, dim emergency light or full working light.
## Put it under the light (or set `light`). `glow` is an optional emissive part shown
## while the light is lit.

const FLICKER_STEPS := 6

@export var light: Light3D
@export var glow: Node3D
## Working-light energy; a negative value keeps the energy authored on the light.
@export var main_energy := -1.0
## Emergency energy; zero keeps the light dark on emergency power.
@export var emergency_energy := 0.0
@export var emergency_color := Color(1.0, 0.32, 0.18)
## Seconds of flicker when the working light comes on (not on load).
@export var startup_flicker := 0.5

var _main_color: Color
var _flicker: Tween


func _ready() -> void:
	if light == null:
		light = get_parent() as Light3D
	_main_color = light.light_color
	if main_energy < 0.0:
		main_energy = light.light_energy
	super()


func is_lit() -> bool:
	return light.visible


func _apply_power(power: int, instant: bool) -> void:
	if _flicker:
		_flicker.kill()
		_flicker = null
	match power:
		GameState.Power.MAIN:
			light.light_color = _main_color
			light.light_energy = main_energy
			_set_lit(true)
			if not instant and startup_flicker > 0.0:
				_start_flicker()
		GameState.Power.EMERGENCY:
			light.light_color = emergency_color
			light.light_energy = emergency_energy
			_set_lit(emergency_energy > 0.0)
		_:
			_set_lit(false)


func _set_lit(lit: bool) -> void:
	light.visible = lit
	if glow:
		glow.visible = lit


func _start_flicker() -> void:
	_flicker = create_tween()
	var step := startup_flicker / FLICKER_STEPS
	for index in FLICKER_STEPS:
		_flicker.tween_property(light, "light_energy", main_energy * (0.15 if index % 2 == 0 else 0.8), step)
	_flicker.tween_property(light, "light_energy", main_energy, step)
