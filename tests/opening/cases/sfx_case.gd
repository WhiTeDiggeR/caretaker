extends RefCounted

## #126: the sound catalogue and the events that request sounds.

## Recorded sounds (#137, #209) replace the placeholders; long ones are Ogg Vorbis.
const MAX_TOTAL_BYTES := 4 * 1024 * 1024


func run(c: OpeningCheck) -> void:
	c.equal(Sfx.validate(), PackedStringArray(), "every catalogued sound loads on a known bus")
	var total := 0
	for id: StringName in Sfx.sounds:
		var file := FileAccess.open(str(Sfx.sounds[id]["file"]), FileAccess.READ)
		total += file.get_length() if file else 0
	c.is_true(total > 0 and total <= MAX_TOTAL_BYTES, "catalogued sounds stay within 4 MB (%d KiB)" % (total / 1024))

	var heard: Array[StringName] = []
	var on_request := func(id: StringName) -> void: heard.append(id)
	Sfx.requested.connect(on_request)

	# Doors: motor on the move, stop at the end; a manual door only swings.
	var door := FacilityDoor.new()
	door.kind = FacilityDoor.Kind.MECHANICAL
	door.open_time = 0.05
	c.add(door)
	await c.tree.process_frame
	door.open()
	await door.opened
	c.equal(heard, [&"door_mech", &"door_stop"] as Array[StringName], "a mechanical door grinds and stops")
	heard.clear()

	# Interaction: an electronic control clicks on a press, buzzes when blocked, chimes after a hold.
	var interactor := Interactor.new()
	c.add(interactor)
	var press := Interactable.new()
	press.ui_feedback = true
	c.add(press)
	interactor.step(press, true, true, 0.016)
	press.available = false
	interactor.step(press, true, true, 0.016)
	var hold := Interactable.new()
	hold.ui_feedback = true
	hold.mode = Interactable.Mode.HOLD
	hold.hold_time = 0.1
	c.add(hold)
	interactor.step(hold, true, true, 0.2)
	c.equal(heard, [&"interact_click", &"interact_denied", &"hold_done"] as Array[StringName], "press, refusal and hold sounds")
	heard.clear()
	# #209: a mechanism has no electronic beeps; it sounds only through its owner.
	var mechanism := Interactable.new()
	c.add(mechanism)
	interactor.step(mechanism, true, true, 0.016)
	mechanism.mode = Interactable.Mode.HOLD
	mechanism.hold_time = 0.1
	interactor.step(mechanism, true, true, 0.2)
	mechanism.available = false
	interactor.step(mechanism, true, true, 0.016)
	c.equal(heard, [] as Array[StringName], "a mechanism neither clicks, chimes nor buzzes")
	heard.clear()

	# #137, #209: a locked handle rattles, a locked wheel jerks; a powered door's panel buzzes.
	var manual := FacilityDoor.new()
	manual.kind = FacilityDoor.Kind.MANUAL
	manual.emergency_lock = true
	c.add(manual)
	var wheel := FacilityDoor.new()
	wheel.kind = FacilityDoor.Kind.MECHANICAL
	wheel.emergency_lock = true
	c.add(wheel)
	var powered := FacilityDoor.new()
	powered.emergency_lock = true
	c.add(powered)
	await c.tree.process_frame
	interactor.step(manual._controls[0], true, true, 0.016)
	interactor.step(wheel._controls[0], true, true, 0.016)
	interactor.step(powered._controls[0], true, true, 0.016)
	c.equal(heard, [&"door_locked", &"door_wheel_jammed", &"interact_denied"] as Array[StringName], "a locked mechanism sounds itself, only a panel buzzes")
	manual.emergency_lock = false
	c.equal(manual._controls[0].denied_sound, &"", "an unlocked door has no rattle")
	heard.clear()

	# Repair controls, containment service and global events.
	var lever := RepairControl.new()
	lever.kind = RepairControl.Kind.LEVER
	lever.control_id = &"sfx_lever"
	c.add(lever)
	lever.set_on(true)
	lever.set_on(true)
	Containment.set_process(false)
	GameState.set_flag(&"containment_online")
	Containment.add_instability(&"module_4", 30.0)
	Containment.add_instability(&"module_4", 95.0 - Containment.get_instability(&"module_4"))
	Containment.tick(0.1)
	Containment.tick(10.0)
	Containment.stabilize(&"module_4", 50.0)
	c.equal(heard, [&"lever", &"alarm_stage", &"chem_warning", &"gas_release"] as Array[StringName], "lever once, alarm on worsening only, protocol warning and gas")
	Containment.set_process(true)

	Sfx.play(&"door_motor", Vector3(1, 2, 3))
	Sfx.play(&"checkpoint")
	c.is_true(Sfx._spatial.any(func(p: AudioStreamPlayer3D) -> bool: return p.global_position == Vector3(1, 2, 3)), "positional sounds play in 3D at the point")
	c.is_true(not Sfx._flat.is_empty(), "flat sounds use the flat pool")
	for _i in Sfx.MAX_SPATIAL + 3:
		Sfx.play(&"door_stop", Vector3.ZERO)
	c.equal(Sfx._spatial.size(), Sfx.MAX_SPATIAL, "the 3D pool is bounded")

	# #137: the generator starts once, then loops; a loaded running generator only loops.
	heard.clear()
	var generator := GeneratorSound.new()
	generator.running_flag = &"sfx_generator"
	c.add(generator)
	c.is_true(not generator.is_running(), "a stopped generator is silent")
	GameState.set_flag(&"sfx_generator")
	c.equal(heard, [&"gen_start"] as Array[StringName], "starting the generator plays the start once")
	c.is_true(generator.is_running(), "the running loop follows the start")
	GameState.set_flag(&"sfx_generator", false)
	c.is_true(not generator.is_running(), "clearing the flag stops the loop")
	GameState.set_flag(&"sfx_generator")
	heard.clear()
	var loaded := GeneratorSound.new()
	loaded.running_flag = &"sfx_generator"
	c.add(loaded)
	c.is_true(loaded.is_running() and heard.is_empty(), "a generator running on load loops without the start")

	Sfx.requested.disconnect(on_request)
	GameState.reset()
