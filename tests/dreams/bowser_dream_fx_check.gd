extends Node

## Headless check of the banners, decals and particles of Bowser's dream (#203): the banners
## carry the emblem shader, the ash and embers follow the stage of the sleep, the sparks,
## the brazier fire, the chain flash and the guard smoke answer their events, the operator's
## trace keeps its flicker, the shaft over the seal stands, all within the particle budget.
## No white outside the places Б-5 allows. Prints `BOWSER_DREAM_FX_OK checks=<n>` on success.

const BOWSER_DREAM := "res://scenes/dreams/bowser_dream.tscn"
const BANNER_SHADER := "res://objects/dream/fx/dream_banner.gdshader"
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
	var fx := dream.get_node_or_null(^"Fx") as BowserDreamFx
	_check(fx != null, "the dream has the Fx node")
	if fx == null:
		_finish()
		return
	var mood := dream.get_node(^"Mood") as DreamStageMood

	var banners := fx.get_node(^"Banners").get_children()
	_check(banners.size() >= 4, "banners hang in the yard and the hall")
	for banner in banners:
		var cloth := banner.get_node(^"Cloth") as MeshInstance3D
		var material := cloth.mesh.surface_get_material(0) as ShaderMaterial
		_check(material != null and material.shader.resource_path == BANNER_SHADER, "%s carries the emblem" % banner.name)
		_check(cloth.mesh.get_faces().size() / 3 <= 300, "%s within 300 triangles" % banner.name)
		for param in [&"cloth_color", &"disc_color", &"emblem_color", &"eye_color"]:
			var color := material.get_shader_parameter(param) as Color if material else Color.WHITE
			_check(color.s > WHITE_SATURATION, "%s: %s is not white" % [banner.name, param])
	_check(fx.get_node(^"Decals").get_child_count() >= 4, "soot, drips and cracks decals")
	var shaft := fx.get_node(^"SealShaft") as SpotLight3D
	_check(shaft != null and is_equal_approx(shaft.spot_angle, 12.0) and is_equal_approx(shaft.light_energy, 6.0), "the light shaft over the seal")
	_check(mood.environment.volumetric_fog_enabled and is_zero_approx(mood.environment.volumetric_fog_density), "the hall haze shows, the global fog does not")

	_check(fx.particle_capacity() <= BowserDreamFx.PARTICLE_BUDGET, "particles within the budget (%d)" % fx.particle_capacity())
	_check(is_equal_approx(fx.ash.amount_ratio, BowserDreamFx.ASH_RATE[1] / BowserDreamFx.ASH_RATE[3]) and not fx.embers.emitting, "alarm: some ash, no embers")
	_check(BowserDreamFx.ASH_COLOR.v < 0.5, "the ash is dark grey, not glowing")
	for color in [BowserDreamFx.EMBER_COLOR, BowserDreamFx.SPARK_COLOR, BowserDreamFx.FIRE_COLOR]:
		_check(color.s > WHITE_SATURATION, "no white in the embers, sparks and fire (%s)" % color.to_html(false))

	var ambush := dream.get_node(BowserDream.WAKE_LINE).get_parent() as DreamAmbush
	var remains := dream.get_node(BowserDream.REMAINS) as DreamRemains
	_check(not fx.brazier_fire.emitting, "the brazier is cold before the ambush")
	remains.awaken()
	ambush.ambush_started.emit()
	_check(fx.brazier_fire.emitting and fx.chain_flash.emitting, "the ambush lights the brazier and flashes the chain")
	_check(fx.guard_smoke.size() == 2 and fx.guard_smoke.all(func(s: GPUParticles3D) -> bool: return s.emitting), "smoke where the guards assemble")
	var trace := dream.get_node(^"Yard/Ambush/OperatorTrace") as GeometryInstance3D
	var trace_material := trace.material_override as ShaderMaterial
	_check(trace_material != null and is_equal_approx(float(trace_material.get_shader_parameter(&"glow_energy")), DreamRemains.TRACE_ENERGY), "the awake trace still flickers, brighter")
	_check(fx.trace_motes != null and fx.trace_motes.emitting, "motes over the operator's trace")
	mood.finish_transition()
	_check(is_equal_approx(fx.ash.amount_ratio, BowserDreamFx.ASH_RATE[2] / BowserDreamFx.ASH_RATE[3]) and fx.embers.emitting, "unrest: more ash and embers")
	await get_tree().create_timer(DreamRemains.BRAZIER_LIGHT_SECONDS + 0.1).timeout
	var energies := {}
	for i in 4:
		await get_tree().process_frame
		await get_tree().create_timer(0.03).timeout
		energies[snappedf(remains.brazier_light.light_energy, 0.001)] = true
	_check(energies.size() > 1, "the brazier light flickers")

	var seal := dream.get_node(BowserDream.SEAL) as DreamSealRings
	_check(not fx.ring_sparks.emitting, "no sparks before a ring turns")
	seal.ring_turned.emit(0, 1)
	_check(fx.ring_sparks.emitting, "a turned ring showers sparks")
	Dreams.module_id = &""
	_finish()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(message)


func _finish() -> void:
	for error in _errors:
		push_error("BOWSER_DREAM_FX_FAIL: " + error)
	if _errors.is_empty():
		print("BOWSER_DREAM_FX_OK checks=%d" % _checks)
	get_tree().quit(0 if _errors.is_empty() else 1)
