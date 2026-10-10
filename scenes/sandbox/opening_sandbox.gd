extends Node3D

## Test range for the opening systems, isolated from the startup scene.
## Each system adds its own station under `Stations`. Debug keys:
## F1 — cycle power of every sandbox section, F2 — toggle caretaker access, F3 — reset state.

const SECTIONS: Array[StringName] = [&"sandbox_a", &"sandbox_b"]
const CARETAKER_ACCESS := &"caretaker"


func _ready() -> void:
	GameState.reset()
	for section in SECTIONS:
		GameState.set_section_power(section, GameState.Power.EMERGENCY)
	GameState.set_objective(&"sandbox", "Проверить станции полигона")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1:
			for section in SECTIONS:
				GameState.set_section_power(section, (GameState.get_section_power(section) + 1) % 3)
			print("Sandbox power: ", GameState.power_name(GameState.get_section_power(SECTIONS[0])))
		KEY_F2:
			if GameState.has_access(CARETAKER_ACCESS):
				GameState.revoke_access(CARETAKER_ACCESS)
			else:
				GameState.grant_access(CARETAKER_ACCESS)
			print("Sandbox caretaker access: ", GameState.has_access(CARETAKER_ACCESS))
		KEY_F3:
			_ready()
			print("Sandbox state reset")
		_:
			return
	get_viewport().set_input_as_handled()
