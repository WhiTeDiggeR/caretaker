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
	c.equal(Shell.defeat_reason, Shell.DEFEAT_GASSED, "gas in the chamber defeats the hero")
	c.equal(DefeatScreen.texts(Shell.DEFEAT_GASSED).get("title"), "ВЫ УСНУЛИ", "gas has its own text")
	Shell._clear_defeat()
	GameState.reset()
	c.is_true(not Containment.is_hero_inside(&"module_4"), "a new state starts with the hero outside the chambers")

	Shell.defeated.disconnect(on_defeat)
	Shell.defeat_enabled = false
	for slot in Saves.SLOTS:
		Saves.delete(slot)
	Saves.directory = original_directory
	Containment.set_process(true)
