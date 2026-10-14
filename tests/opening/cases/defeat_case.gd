extends RefCounted

## #123: defeat by catastrophe or gas, and when the game may be saved.


func run(c: OpeningCheck) -> void:
	Containment.set_process(false)
	var original_directory := Saves.directory
	Saves.directory = "user://defeat_case_saves"
	for slot in Saves.SLOTS:
		Saves.delete(slot)

	c.equal(Shell.save_block_reason(), Shell.SAVE_BLOCKED_NO_GAME, "no game, no save")
	var hero := Node3D.new()
	hero.add_to_group(&"player")
	c.add(hero)
	c.is_true(Shell.can_save(), "a running game in reality can be saved")
	Dreams.in_dream = true
	c.equal(Shell.save_block_reason(), Shell.SAVE_BLOCKED_DREAM, "no saving inside a dream")
	Dreams.abort()
	c.is_true(not Dreams.in_dream and Shell.can_save(), "aborting the session returns to reality")

	Shell.defeat_enabled = true
	var reasons: Array[StringName] = []
	var on_defeat := func(reason: StringName) -> void: reasons.append(reason)
	Shell.defeated.connect(on_defeat)

	Containment.add_instability(&"module_4", 100.0)
	c.is_true(not Shell.is_defeated(), "one awake module is not a defeat")
	Containment.add_instability(&"module_3", 100.0)
	c.is_true(Shell.is_defeated() and c.tree.paused, "the catastrophe stops the game")
	c.equal(Shell.defeat_reason, Shell.DEFEAT_CATASTROPHE, "defeat reason is the catastrophe")
	var screen := Shell.find_children("*", "DefeatScreen", false, false)
	c.equal(screen.size(), 1, "the defeat screen is shown")
	await c.tree.process_frame
	if screen.size() == 1:
		var defeat := screen[0] as DefeatScreen
		c.is_true(defeat.checkpoint_button.disabled, "no checkpoint to load without an autosave")
		var labels := defeat.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)
		c.is_true(labels.has("КАТАСТРОФА"), "the screen names the catastrophe")
	c.equal(Shell.save_block_reason(), Shell.SAVE_BLOCKED_DEFEAT, "no saving after a defeat")
	Shell.pause()
	c.is_true(not Shell.is_paused(), "the pause menu does not open over the defeat")
	Containment.add_instability(&"module_3", 1.0)
	c.equal(reasons, [Shell.DEFEAT_CATASTROPHE] as Array[StringName], "defeat is announced once")
	Shell._clear_defeat()
	c.is_true(not Shell.is_defeated() and not c.tree.paused, "clearing the defeat resumes the game")

	# Gas in a chamber with the hero inside and not connected to the chair.
	GameState.reset()
	Containment.set_hero_inside(&"module_4", true)
	Containment.add_instability(&"module_4", 95.0 - Containment.get_instability(&"module_4"))
	Containment.tick(0.1)
	Containment.tick(10.0)
	c.is_true(Shell.falling_asleep and not Shell.is_defeated(), "gas first puts the hero to sleep")
	c.equal(Shell.save_block_reason(), Shell.SAVE_BLOCKED_ASLEEP, "no saving while falling asleep")
	Shell.pause()
	c.is_true(not Shell.is_paused(), "the pause menu does not open while falling asleep")
	await c.tree.create_timer(ScreenEffects.duration(Shell.FALL_ASLEEP_EFFECT) + 0.2).timeout
	c.is_true(not Shell.falling_asleep and c.tree.paused, "the defeat screen opens once the hero is asleep")
	c.equal(Shell.defeat_reason, Shell.DEFEAT_GASSED, "gas in the chamber defeats the hero")
	Shell._clear_defeat()

	# A load during the fall cancels the defeat.
	Containment.hero_gassed.emit(&"module_4")
	c.is_true(Shell.falling_asleep, "the hero falls asleep again")
	Shell.falling_asleep = false
	await c.tree.create_timer(ScreenEffects.duration(Shell.FALL_ASLEEP_EFFECT) + 0.2).timeout
	c.is_true(not Shell.is_defeated(), "a cancelled fall does not end in a defeat")
	Containment.hero_gassed.emit(&"module_4")
	Shell._clear_defeat()
	Shell.defeat(Shell.DEFEAT_CATASTROPHE)
	c.equal(Shell.defeat_reason, Shell.DEFEAT_CATASTROPHE, "a catastrophe during the fall defeats at once")
	await c.tree.create_timer(ScreenEffects.duration(Shell.FALL_ASLEEP_EFFECT) + 0.2).timeout
	c.equal(Shell.defeat_reason, Shell.DEFEAT_CATASTROPHE, "the fall does not replace the catastrophe")
	c.equal(DefeatScreen.texts(Shell.DEFEAT_GASSED).get("title"), "ВЫ УСНУЛИ", "gas has its own text")
	Shell._clear_defeat()
	GameState.reset()
	c.is_true(not Containment.is_hero_inside(&"module_4"), "a new state starts with the hero outside the chambers")

	ScreenEffects.stop()

	# The hero's body falls asleep: controls lock and the eyes sink to the floor, tilted.
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(10, 0.2, 10)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(200, -0.1, 0)
	c.add(floor_body)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	player.position = Vector3(200, 0.9, 0)
	c.add(player)
	await c.physics_frames(3)
	player.call(&"fall_asleep")
	c.is_true(bool(player.get(&"controls_locked")), "a sleeping hero has no controls")
	await c.tree.create_timer(player.FALL_ASLEEP_DELAY + player.FALL_ASLEEP_SECONDS + 0.2).timeout
	var camera := player.get(&"camera") as Camera3D
	c.near(float(player.get(&"asleep")), 1.0, 0.0001, "the hero lies asleep")
	c.near(camera.position.y, player.FALL_ASLEEP_EYES, 0.01, "the eyes are down at the floor")
	c.near(camera.rotation.z, player.FALL_ASLEEP_ROLL, 0.01, "the head is tilted over")
	player.queue_free()
	floor_body.queue_free()

	Shell.defeated.disconnect(on_defeat)
	Shell.defeat_enabled = false
	for slot in Saves.SLOTS:
		Saves.delete(slot)
	Saves.directory = original_directory
	Containment.set_process(true)
