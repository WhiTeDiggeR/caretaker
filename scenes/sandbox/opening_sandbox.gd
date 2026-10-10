extends Node3D

## Test range for the opening systems, isolated from the startup scene.
## Each system adds its own station under `Stations`. Debug keys:
## F1 — cycle power of every sandbox section, F2 — toggle caretaker access, F3 — reset state,
## F4 — module 4 instability +10 %, F5 — module 4 stabilised by 20 %,
## F6 — module 4 straight to the chemical protocol threshold.

const SECTIONS: Array[StringName] = [&"sandbox_a", &"sandbox_b"]
const CARETAKER_ACCESS := &"caretaker"


const INITIALIZED_FLAG := &"sandbox/initialized"


func _ready() -> void:
	# Returning from a dream reloads this scene: keep the state of the running session.
	if not GameState.has_flag(INITIALIZED_FLAG):
		reset_state()


func reset_state() -> void:
	GameState.reset()
	GameState.set_flag(INITIALIZED_FLAG)
	for section in SECTIONS:
		GameState.set_section_power(section, GameState.Power.EMERGENCY)
	GameState.set_objective(&"sandbox", "Проверить станции полигона")
	GameState.set_flag(&"containment_online")
	GameState.grant_access(&"module_4")


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
			reset_state()
			print("Sandbox state reset")
		KEY_F4:
			print("Module 4: ", Containment.add_instability(&"module_4", 10.0))
		KEY_F5:
			print("Module 4: ", Containment.stabilize(&"module_4", 20.0))
		KEY_F6:
			var trigger := float(Containment.chemical.get("trigger_at", 95.0))
			Containment.add_instability(&"module_4", maxf(trigger - Containment.get_instability(&"module_4"), 0.0))
			print("Module 4 at the chemical threshold")
		_:
			return
	get_viewport().set_input_as_handled()
