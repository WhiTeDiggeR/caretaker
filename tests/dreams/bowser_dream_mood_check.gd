extends Node

## Headless check of the sky and light of Bowser's dream (#202): the sky is the stage shader,
## the events of the dream switch the stage (entry — alarm, ambush — unrest, seal — alarm,
## the open gate close by — calm), a sleeper near awakening forces pre-wake, and the blend
## reaches the preset values of fog, back light and lava. No preset light is white (Б-5).
## Prints `BOWSER_DREAM_MOOD_OK checks=<n>` on success.

const BOWSER_DREAM := "res://scenes/dreams/bowser_dream.tscn"
const WHITE_SATURATION := 0.2

var _errors := PackedStringArray()
var _checks := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().current_scene = null
	Containment.set_process(false)
	Dreams.module_id = &"module_4"
	var dream := (load(BOWSER_DREAM) as PackedScene).instantiate() as BowserDream
	add_child(dream)
	await get_tree().process_frame
	var mood := dream.get_node(^"Mood") as DreamStageMood
	_check(mood != null, "the dream's Mood is DreamStageMood")
	if mood == null:
		_finish()
		return
	var sky_material := mood.environment.sky.sky_material as ShaderMaterial if mood.environment.sky else null
	_check(mood.environment.background_mode == Environment.BG_SKY and sky_material != null
			and sky_material.shader == DreamStageMood.SKY_SHADER, "the sky is the stage shader")
	_check(mood.target_stage() == DreamStageMood.Stage.ALARM and is_equal_approx(mood.shown_stage, 1.0), "entry is the alarm stage")

	(dream.get_node(BowserDream.WAKE_LINE).get_parent() as DreamAmbush).ambush_started.emit()
	_check(mood.event_stage == DreamStageMood.Stage.UNREST, "the ambush switches to unrest")
	await get_tree().process_frame
	_check(mood.shown_stage > 1.0 and mood.shown_stage < 2.0, "the switch blends smoothly")
	mood.finish_transition()
	_check(is_equal_approx(mood.shown_stage, 2.0) and is_equal_approx(float(sky_material.get_shader_parameter(&"stage")), 2.0), "the sky reaches unrest")
	_check(is_equal_approx(mood.environment.fog_density, DreamStageMood.FOG_DENSITY[2]), "fog of unrest")
	var sun := dream.get_node(^"Sun") as DirectionalLight3D
	_check(sun.light_color.is_equal_approx(DreamStageMood.SUN_COLOR[2]) and is_equal_approx(sun.light_energy, DreamStageMood.SUN_ENERGY[2]), "back light of unrest")
	var lava := (dream.get_node(^"LavaSurface") as MeshInstance3D).material_override as ShaderMaterial
	_check(lava != null and is_equal_approx(float(lava.get_shader_parameter(&"level_offset")), DreamStageMood.LAVA_LEVEL[2]), "the lava rises with the stage")

	Dreams.seal_restored_signal.emit(&"module_4")
	mood.finish_transition()
	_check(mood.event_stage == DreamStageMood.Stage.ALARM and is_equal_approx(mood.shown_stage, 1.0), "the restored seal returns to alarm")

	Dreams.in_dream = true
	Dreams.seal_restored = true
	var gate := dream.get_node(^"Bastion/Gate") as DreamGate
	var player := dream.get_node(^"Player") as Node3D
	player.global_position = gate.global_position + Vector3(0, 0, 3)
	dream.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	mood.finish_transition()
	_check(mood.event_stage == DreamStageMood.Stage.CALM and is_equal_approx(mood.shown_stage, 0.0), "the open gate close by calms the sleep")

	Containment.add_instability(&"module_4", 100.0 - Containment.get_instability(&"module_4") - 1.0)
	mood.apply()
	mood.finish_transition()
	_check(mood.target_stage() == DreamStageMood.Stage.PRE_WAKE and is_equal_approx(mood.shown_stage, 3.0), "a sleeper near awakening forces pre-wake")

	for colors: Array[Color] in [DreamStageMood.SUN_COLOR, DreamStageMood.FOG_COLOR, DreamStageMood.SKY_HORIZON, DreamStageMood.LAVA_COLOR]:
		for color in colors:
			_check(color.s > WHITE_SATURATION, "no white in the stage presets (%s)" % color.to_html(false))
	Dreams.in_dream = false
	Dreams.seal_restored = false
	Dreams.module_id = &""
	_finish()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(message)


func _finish() -> void:
	for error in _errors:
		push_error("BOWSER_DREAM_MOOD_FAIL: " + error)
	if _errors.is_empty():
		print("BOWSER_DREAM_MOOD_OK checks=%d" % _checks)
	get_tree().quit(0 if _errors.is_empty() else 1)
