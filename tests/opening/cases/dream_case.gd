extends RefCounted

const CHAIR := "res://objects/dream/immersion_chair.tscn"
const TEST_DREAM := "res://scenes/dreams/test_dream.tscn"
const PLAYER := "res://scenes/player.tscn"


func run(c: OpeningCheck) -> void:
	Containment.set_process(false)
	var loads: Array[String] = []
	var original_loader := Dreams.scene_loader
	Dreams.scene_loader = func(path: String) -> void: loads.append(path)

	c.equal(Dreams.dream_scene_for(&"module_4"), TEST_DREAM, "module 4 dream scene is configured")
	c.near(Dreams.time_ratio, 15.0, 0.001, "default dream time ratio 1:15")

	var chair := (load(CHAIR) as PackedScene).instantiate() as ImmersionChair
	chair.chair_id = &"test_chair"
	chair.section = &"chair_power"
	chair.required_access = &"module_4"
	chair.required_flag = &"module4_ready"
	chair.position = Vector3(5, 0, 0)
	c.add(chair)
	var player := (load(PLAYER) as PackedScene).instantiate() as CharacterBody3D
	player.position = Vector3(0, 0.9, 0)
	c.add(player)

	c.equal(chair.lock_reason(), ImmersionChair.REASON_NO_POWER, "chair needs power")
	GameState.set_section_power(&"chair_power", GameState.Power.MAIN)
	c.equal(chair.lock_reason(), ImmersionChair.REASON_NO_ACCESS, "chair needs module access")
	GameState.grant_access(&"module_4")
	c.equal(chair.lock_reason(), chair.required_flag_prompt, "chair needs preparation")
	GameState.set_flag(&"module4_ready")
	c.equal(chair.lock_reason(), "", "prepared chair is free")
	c.is_true(chair.interactable.is_available(), "chair prompt is available")

	var start := Containment.get_instability(&"module_4")
	chair.sit_down()
	await c.tree.process_frame
	c.is_true(player.controls_locked, "the hero is locked while the hoop lowers")
	await Dreams.entered
	c.near(Containment.get_instability(&"module_4"), start + Dreams.entry_cost, 0.001, "entering raises the instability")
	await c.tree.create_timer(ImmersionChair.SEQUENCE_SECONDS + Dreams.FADE_SECONDS * 2.0 + 0.3).timeout
	c.equal(loads, [TEST_DREAM] as Array[String], "the dream scene is loaded")
	c.is_true(Dreams.in_dream, "session is in the dream")
	c.equal(chair.lock_reason(), ImmersionChair.REASON_IN_DREAM, "chair is busy during the dream")

	var real_before := Dreams.real_seconds
	var subjective_before := Dreams.subjective_seconds
	await c.tree.create_timer(0.5).timeout
	var real := Dreams.real_seconds - real_before
	c.near((Dreams.subjective_seconds - subjective_before) / real, 15.0, 0.01, "dream time runs 15 times faster")

	var before_seal := Containment.get_instability(&"module_4")
	Dreams.restore_seal()
	Dreams.restore_seal()
	c.near(Containment.get_instability(&"module_4"), before_seal - Dreams.seal_relief, 0.001, "a seal calms the dream once per visit")
	c.is_true(Dreams.seal_restored, "the visit's main task is done")

	var reasons: Array[int] = []
	Dreams.left.connect(func(_id: StringName, reason: int) -> void: reasons.append(reason))
	player.global_position = Vector3(30, 0.9, 30)
	Dreams.exit_through_gate()
	await c.tree.create_timer(Dreams.FADE_SECONDS * 2.0 + 0.3).timeout
	c.is_true(not Dreams.in_dream, "the gate ends the session")
	c.equal(loads.back(), c.tree.current_scene.scene_file_path, "the complex scene is loaded back")
	var exit_point := chair.exit_transform().origin
	c.is_true(Vector2(player.global_position.x - exit_point.x, player.global_position.z - exit_point.z).length() < 0.01,
			"the hero stands at the chair after returning")
	c.is_true(Dreams.return_text(Dreams.Exit.GATE).contains("во сне — около"), "return message tells both times")

	var before_death := Containment.get_instability(&"module_4")
	await Dreams.enter(&"module_4", &"test_chair")
	c.is_true(not Dreams.seal_restored, "a new visit has its own main task")
	Dreams.die()
	await c.tree.create_timer(Dreams.FADE_SECONDS * 2.0 + 0.3).timeout
	c.near(Containment.get_instability(&"module_4"), before_death + Dreams.entry_cost + Dreams.death_penalty, 0.001, "death in the dream raises the instability")
	c.equal(reasons, [Dreams.Exit.GATE, Dreams.Exit.DEATH] as Array[int], "exits are reported with their reason")

	Containment.add_instability(&"module_4", 100.0)
	c.equal(chair.lock_reason(), ImmersionChair.REASON_AWAKE, "an awakened prisoner has no dream to enter")
	c.is_true(not await Dreams.enter(&"module_4", &"test_chair"), "no session into an awakened prisoner")

	# The placeholder dream is wired: seal, gate, hazard, mood.
	GameState.reset()
	var dream: Node3D = c.add((load(TEST_DREAM) as PackedScene).instantiate())
	c.is_true(dream.get_node(^"Seal") is DreamSeal and dream.get_node(^"Gate") is DreamGate and dream.get_node(^"Lava") is DreamHazard, "test dream has a seal, a gate and lava")
	Dreams.module_id = &"module_4"
	Containment.add_instability(&"module_4", 30.0)
	var mood := dream.get_node(^"Mood") as DreamMood
	mood.apply()
	c.equal(mood.environment.background_color, DreamMood.SKY_BY_STAGE[Containment.get_stage(&"module_4")], "dream mood follows the stage")

	Dreams.scene_loader = original_loader
	Dreams.module_id = &""
	Containment.set_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
