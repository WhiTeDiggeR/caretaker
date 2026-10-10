extends Node3D

## Placeholder dream used to test the dream loop: a seal in the middle, the gate at the end,
## lava below. Falling out of the world counts as death.

const FALL_LIMIT_Y := -20.0

@onready var _player: Node3D = $Player


func _physics_process(_delta: float) -> void:
	if _player.global_position.y < FALL_LIMIT_Y:
		set_physics_process(false)
		Dreams.die()
