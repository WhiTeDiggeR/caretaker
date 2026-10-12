extends OmniLight3D
## Failing fluorescent tube for the look-dev rooms (#131): mostly on, with short random dropouts and stutters.

@export var on_energy := 1.2
@export var min_steady := 0.6
@export var max_steady := 3.5

var _timer := 0.0


func _ready() -> void:
	light_energy = on_energy
	_timer = randf_range(min_steady, max_steady)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if light_energy > 0.0:
		light_energy = 0.0 if randf() < 0.7 else on_energy * 0.35
		_timer = randf_range(0.03, 0.18)
	else:
		light_energy = on_energy
		_timer = randf_range(min_steady, max_steady) if randf() < 0.6 else randf_range(0.05, 0.25)
