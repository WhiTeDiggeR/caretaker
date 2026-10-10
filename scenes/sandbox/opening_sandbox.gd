extends Node3D

## Test range for the opening systems, isolated from the startup scene.
## Each system adds its own station under `Stations`. Debug keys:
## F1 — cycle power of every sandbox section, F2 — toggle caretaker access, F3 — reset state,
## F4 — module 4 instability +10 %, F5 — module 4 stabilised by 20 %,
## F6 — module 4 straight to the chemical protocol threshold,
## F7 — containment time speed x1 / x10 / x60.
## A debug overlay shows the exact state of module 4; containment events go to the console.

const SECTIONS: Array[StringName] = [&"sandbox_a", &"sandbox_b"]
const CARETAKER_ACCESS := &"caretaker"


const INITIALIZED_FLAG := &"sandbox/initialized"
const DEBUG_MODULE := &"module_4"
const TIME_SCALES: Array[float] = [1.0, 10.0, 60.0]
const OVERLAY_REFRESH_SECONDS := 0.25

var _overlay: Label
var _overlay_elapsed := 0.0


func _ready() -> void:
	# Returning from a dream reloads this scene: keep the state of the running session.
	if not GameState.has_flag(INITIALIZED_FLAG):
		reset_state()
	_build_overlay()
	# Method connections are dropped automatically when the scene is freed (dream entry).
	Containment.chemical_warning.connect(_on_chemical_warning)
	Containment.module_sealed.connect(_on_module_sealed)
	Containment.repair_window_ended.connect(_on_repair_window_ended)
	Containment.module_awakened.connect(_on_module_awakened)
	Containment.catastrophe.connect(_on_catastrophe)


func _exit_tree() -> void:
	Containment.time_scale = 1.0


func _process(delta: float) -> void:
	_overlay_elapsed += delta
	if _overlay_elapsed >= OVERLAY_REFRESH_SECONDS:
		_overlay_elapsed = 0.0
		_refresh_overlay()


func _on_chemical_warning(id: StringName, seconds: float) -> void:
	print("Containment %s: chemical warning, sealing in %d s" % [id, seconds])


func _on_module_sealed(id: StringName) -> void:
	print("Containment %s: sealed, chemical sleep, repair window %d s" % [id, Containment.chemical_timer(id)])


func _on_repair_window_ended(id: StringName) -> void:
	print("Containment %s: repair window ended, instability grows again" % id)


func _on_module_awakened(id: StringName) -> void:
	print("Containment %s: PRISONER AWAKE" % id)


func _on_catastrophe(ids: Array[StringName]) -> void:
	print("Containment: CATASTROPHE ", ids)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_overlay = Label.new()
	layer.add_child(_overlay)
	# Bottom-left corner: the objective and prompts take the top and the centre.
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	_overlay.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_overlay.add_theme_color_override(&"font_color", Color(0.7, 1.0, 0.8))
	_overlay.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_overlay.add_theme_constant_override(&"outline_size", 4)
	_refresh_overlay()


func _refresh_overlay() -> void:
	var id := DEBUG_MODULE
	var phase := Containment.chemical_phase(id)
	var text := "[DEBUG] %s: %.1f %% · %s · время x%d\n" % [id, Containment.get_instability(id), Containment.stage_name(Containment.get_stage(id)), Containment.time_scale]
	text += "протокол: %s" % Containment.CHEMICAL_NAMES[phase]
	if phase in [Containment.Chemical.WARNING, Containment.Chemical.SEALED]:
		text += " %.0f с" % Containment.chemical_timer(id)
	var forecast := Containment.forecast_seconds(id)
	text += " · прогноз: %s" % ("нет" if forecast < 0.0 else "%.0f с" % forecast)
	text += "\nF4 +10 %  F5 −20 %  F6 к порогу  F7 скорость времени"
	_overlay.text = text


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
		KEY_F7:
			var index := (TIME_SCALES.find(Containment.time_scale) + 1) % TIME_SCALES.size()
			Containment.time_scale = TIME_SCALES[index]
			print("Containment time x", Containment.time_scale)
		_:
			return
	get_viewport().set_input_as_handled()
