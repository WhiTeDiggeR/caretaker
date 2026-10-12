extends RefCounted

## #126: the sound catalogue and the events that request sounds.

const MAX_TOTAL_BYTES := 2 * 1024 * 1024


func run(c: OpeningCheck) -> void:
	c.equal(Sfx.validate(), PackedStringArray(), "every catalogued sound loads on a known bus")
	var total := 0
	for id: StringName in Sfx.sounds:
		var file := FileAccess.open(str(Sfx.sounds[id]["file"]), FileAccess.READ)
		total += file.get_length() if file else 0
	c.is_true(total > 0 and total <= MAX_TOTAL_BYTES, "placeholder sounds stay within 2 MB (%d KiB)" % (total / 1024))

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

	# Interaction: a press clicks, a blocked press is refused, a finished hold confirms.
	var interactor := Interactor.new()
	c.add(interactor)
	var press := Interactable.new()
	c.add(press)
	interactor.step(press, true, true, 0.016)
	press.available = false
	interactor.step(press, true, true, 0.016)
	var hold := Interactable.new()
	hold.mode = Interactable.Mode.HOLD
	hold.hold_time = 0.1
	c.add(hold)
	interactor.step(hold, true, true, 0.2)
	c.equal(heard, [&"interact_click", &"interact_denied", &"hold_done"] as Array[StringName], "press, refusal and hold sounds")
	heard.clear()

	# #137: a locked handle rattles; a wheel and a powered door's panel keep the common refusal.
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
	c.equal(heard, [&"door_locked", &"interact_denied", &"interact_denied"] as Array[StringName], "only a locked handle rattles")
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

	Sfx.requested.disconnect(on_request)
	GameState.reset()
