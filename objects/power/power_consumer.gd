class_name PowerConsumer
extends Node

## Follows the power state of one facility section from `GameState`.
## Rising power is applied after `cascade_delay` (lights come on one after another);
## falling power is applied at once. Subclasses override `_apply_power()`.

signal power_applied(power: int)

@export var section: StringName = &""
@export var cascade_delay := 0.0

## Power state currently shown by this consumer (-1 before the first apply).
var applied_power := -1

var _token := 0


func _ready() -> void:
	GameState.section_power_changed.connect(_on_section_power_changed)
	GameState.state_loaded.connect(_apply_current)
	_apply_current()


func _apply_current() -> void:
	_token += 1
	_apply(GameState.get_section_power(section), true)


func _on_section_power_changed(changed: StringName, power: int) -> void:
	if changed != section:
		return
	_token += 1
	var token := _token
	if cascade_delay > 0.0 and power > applied_power:
		await get_tree().create_timer(cascade_delay).timeout
		if token != _token:
			return
	_apply(power, false)


func _apply(power: int, instant: bool) -> void:
	applied_power = power
	_apply_power(power, instant)
	power_applied.emit(power)


## Override in subclasses. `instant` is true for the initial state and loaded saves.
func _apply_power(_power: int, _instant: bool) -> void:
	pass
