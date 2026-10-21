extends Node3D

## Frames of the interdream for review (#240), not a check: a stand-in dream with a glowing
## gate, the hero walking into it, then the real exit through the gate (corridor with the
## plate «2», wash into the veil, the chair). Also stills of every corridor look. Run with a
## window: `godot --path . res://tests/dreams/interdream_shots.tscn -- <out_dir>`; without
## `out_dir` it only plays the transition.

const WALK_SPEED := 3.0
const GATE_Z := -6.0
## Seconds after the gate when a frame of the transition is saved.
const FRAMES: Array[float] = [-0.4, 0.0, 0.1, 0.2, 0.35, 0.6, 1.0, 2.0, 3.2, 4.0, 4.4]
const STILL_PROGRESS: Array[float] = [0.35, 0.6, 0.9]
const HERO_SCRIPT := """
extends CharacterBody3D
func set_controls_locked(_locked: bool) -> void:
	pass
"""

var _out := ""
var _hero: CharacterBody3D
var _dream: Node3D
var _walking := true


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else ""
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _process(delta: float) -> void:
	if _walking and _hero:
		_hero.velocity = Vector3(0, 0, -WALK_SPEED)
		_hero.position += _hero.velocity * delta


func _run() -> void:
	await _stills()
	_build_dream()
	GameState.reset()
	Dreams.scene_loader = func(_path: String) -> void: _to_chair()
	Dreams.in_dream = true
	Dreams.module_id = &"module_4"
	Dreams.seal_restored = false
	Dreams._return_scene = "res://tests/dreams/interdream_shots.tscn"
	Dreams.interdream().prepare()
	# The gate's area takes the hero a step before its glowing plane.
	var gate_at := (GATE_Z + 0.8 - _hero.position.z) / -WALK_SPEED
	var start := Time.get_ticks_msec() / 1000.0
	var exited := false
	var index := 0
	while index < FRAMES.size():
		await RenderingServer.frame_post_draw
		var t := Time.get_ticks_msec() / 1000.0 - start - gate_at
		if not exited and t >= 0.0:
			exited = true
			Dreams.exit_through_gate()
		if t >= FRAMES[index]:
			_save("transition_%02d_%+.2fs" % [index, FRAMES[index]])
			index += 1
	await Dreams.arrived
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_save("transition_%02d_chair" % index)
	get_tree().quit()


## Every look with the plate and the far silhouette, early and late in the walk.
func _stills() -> void:
	if _out.is_empty():
		return
	var overlay := Dreams.interdream()
	for look: String in InterdreamCorridor.LOOKS:
		InterdreamEchoes.config["look"] = look
		overlay.prepare(look)
		overlay.play({"id": "shot", "props": ["plate_2", "silhouette_far"], "mandatory": true}, Dreams.Exit.GATE)
		overlay.set_process(false)
		overlay._root.modulate.a = 1.0
		overlay._wash.modulate.a = 0.0
		for progress in STILL_PROGRESS:
			overlay.corridor.progress = progress
			for i in 4:
				await RenderingServer.frame_post_draw
			_save("look_%s_%d" % [look, roundi(progress * 100.0)])
		overlay.set_process(true)
		overlay.stop()
	InterdreamEchoes.reload()


func _build_dream() -> void:
	_dream = Node3D.new()
	add_child(_dream)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.06, 0.1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.45, 0.6)
	var world := WorldEnvironment.new()
	world.environment = environment
	_dream.add_child(world)
	_box(Vector3(8, 0.1, 20), Vector3(0, -0.05, -4), Color(0.2, 0.22, 0.28))
	for x in [-1.1, 1.1]:
		_box(Vector3(0.3, 3.0, 0.3), Vector3(x, 1.5, GATE_Z), Color(0.35, 0.33, 0.3))
	_box(Vector3(2.5, 0.3, 0.3), Vector3(0, 3.1, GATE_Z), Color(0.35, 0.33, 0.3))
	var portal := _box(Vector3(1.9, 3.0, 0.02), Vector3(0, 1.5, GATE_Z), Color(1, 1, 1))
	(portal.material_override as StandardMaterial3D).emission_enabled = true
	(portal.material_override as StandardMaterial3D).emission = Color(0.9, 0.95, 1.0)
	_hero = CharacterBody3D.new()
	var script := GDScript.new()
	script.source_code = HERO_SCRIPT
	script.reload()
	_hero.set_script(script)
	_hero.add_to_group(&"player")
	_hero.position = Vector3(0, 0, 0)
	add_child(_hero)
	var camera := Camera3D.new()
	camera.position.y = 1.6
	camera.rotation_degrees.x = -4.0
	camera.current = true
	_hero.add_child(camera)


## The stand-in for the complex: the view from the chair.
func _to_chair() -> void:
	_walking = false
	_dream.queue_free()
	_dream = Node3D.new()
	add_child(_dream)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.08, 0.07)
	var world := WorldEnvironment.new()
	world.environment = environment
	_dream.add_child(world)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.5, -1)
	_dream.add_child(light)
	_box(Vector3(6, 0.1, 6), Vector3(0, -0.05, -2), Color(0.3, 0.3, 0.28))
	_box(Vector3(0.8, 1.2, 0.8), Vector3(0, 0.6, -2.5), Color(0.5, 0.55, 0.6))
	_hero.position = Vector3.ZERO


func _box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	instance.material_override = material
	_dream.add_child(instance)
	return instance


func _save(name: String) -> void:
	if _out.is_empty():
		return
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
