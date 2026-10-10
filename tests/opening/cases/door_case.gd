extends RefCounted

const HERMETIC := "res://objects/doors/hermetic_door.tscn"
const MECHANICAL := "res://objects/doors/mechanical_door.tscn"
const GATE := "res://objects/doors/access_gate.tscn"
const AIRLOCK := "res://objects/doors/airlock.tscn"
const FAST := 0.05


func run(c: OpeningCheck) -> void:
	# Powered door: power, emergency lock, prompts.
	var door := _door(c, HERMETIC, &"sec_a")
	var panel := door.get_node(^"ControlFront").get_meta(Interactable.META) as Interactable
	c.equal(door.lock_reason(), FacilityDoor.REASON_NO_POWER, "unpowered door reports no power")
	c.is_true(not panel.is_available() and panel.get_prompt_text() == "НЕТ ПИТАНИЯ", "panel shows the reason")
	c.is_true(not door.open(), "unpowered door does not open")
	GameState.set_section_power(&"sec_a", GameState.Power.EMERGENCY)
	c.equal(door.lock_reason(), "", "emergency power is enough")
	c.is_true(panel.is_available() and panel.get_prompt_text().ends_with("ОТКРЫТЬ ДВЕРЬ"), "panel offers to open")
	door.emergency_lock = true
	c.equal(panel.get_prompt_text(), FacilityDoor.REASON_EMERGENCY, "emergency lock is shown on the panel")
	door.emergency_lock = false

	panel.trigger()
	c.equal(door.state, FacilityDoor.State.OPENING, "panel press starts opening")
	c.is_true(not panel.is_available(), "panel is unavailable while the leaf moves")
	await door.opened
	c.is_true(door.is_open(), "door is open")
	var leaf := door.get_node(^"Leaf") as Node3D
	c.is_true(leaf.position.x > door.width, "leaf slid aside")
	c.is_true(panel.get_prompt_text().ends_with("ЗАКРЫТЬ ДВЕРЬ"), "panel offers to close")
	GameState.set_section_power(&"sec_a", GameState.Power.OFF)
	c.is_true(door.is_open(), "losing power leaves an open door open")
	c.is_true(not door.close(), "unpowered door cannot be closed")
	GameState.set_section_power(&"sec_a", GameState.Power.MAIN)
	c.is_true(door.close(), "door closes again")
	await door.closed
	c.near(leaf.position.length(), 0.0, 0.001, "leaf returned")

	# Mechanical door works without power, by holding the wheel.
	var manual := _door(c, MECHANICAL, &"")
	var wheel := manual.get_node(^"ControlBack").get_meta(Interactable.META) as Interactable
	c.equal(wheel.mode, Interactable.Mode.HOLD, "mechanical door uses a hold control")
	c.equal(manual.lock_reason(), "", "mechanical door needs no power")
	wheel.trigger()
	await manual.opened
	c.is_true(manual.is_open(), "wheel opens the mechanical door")

	# Access gate requires the caretaker grant.
	var gate := _door(c, GATE, &"sec_a")
	c.equal(gate.lock_reason(), FacilityDoor.REASON_NO_ACCESS, "gate needs access")
	GameState.grant_access(&"caretaker")
	c.equal(gate.lock_reason(), "", "granted access unlocks the gate")
	c.is_true(gate.open(), "gate opens with access")
	await gate.opened
	c.is_true((gate.get_node(^"Leaf") as Node3D).position.y > 2.0, "gate leaf slid up")

	# Airlock: interlock and cycle.
	var airlock := (load(AIRLOCK) as PackedScene).instantiate() as Airlock
	airlock.section = &"sec_lock"
	airlock.cycle_time = FAST
	c.add(airlock)
	var a := airlock.door_a
	var b := airlock.door_b
	a.open_time = FAST
	b.open_time = FAST
	var both_open := [false]
	var watch := func(_state: int) -> void:
		if not a.is_closed() and not b.is_closed():
			both_open[0] = true
	a.state_changed.connect(watch)
	b.state_changed.connect(watch)
	c.is_true(not airlock.start_cycle(), "unpowered airlock does not cycle")
	GameState.set_section_power(&"sec_lock", GameState.Power.EMERGENCY)
	c.is_true(a.open(), "outer door opens")
	await a.opened
	c.equal(b.lock_reason(), "", "inner door panel stays usable: it calls the airlock")
	c.is_true(not b.open(), "inner door does not open while the outer is open")
	c.is_true(airlock.start_cycle(), "cycle starts")
	c.equal(a.lock_reason(), FacilityDoor.REASON_CYCLE, "doors are locked during the cycle")
	c.is_true(not airlock.start_cycle(), "second cycle is refused while running")
	await airlock.cycle_finished
	c.is_true(a.is_closed() and b.is_open(), "cycle closed the outer door and opened the inner")
	c.is_true(airlock.start_cycle(), "cycle back starts")
	await airlock.cycle_finished
	c.is_true(a.is_open() and b.is_closed(), "cycle back opens the outer door")
	var cycle_panel := airlock.get_node(^"CyclePanel/Interactable") as Interactable
	c.is_true(cycle_panel.is_available() and cycle_panel.unavailable_prompt.is_empty(), "cycle panel is free again after a cycle")

	# Door panels go through the airlock: no way around the cycle.
	c.is_true(not b.open(), "inner door cannot be opened directly while the outer is open")
	var b_panel := b.get_node(^"ControlFront").get_meta(Interactable.META) as Interactable
	c.is_true(b_panel.is_available() and b_panel.get_prompt_text().ends_with("ОТКРЫТЬ ШЛЮЗ"), "inner door panel calls the airlock")
	b_panel.trigger()
	c.is_true(airlock.cycling, "inner door panel starts a cycle")
	await airlock.cycle_finished
	c.is_true(a.is_closed() and b.is_open(), "panel cycle closed the outer door and opened the inner")
	b_panel.trigger()
	await b.closed
	var a_panel := a.get_node(^"ControlBack").get_meta(Interactable.META) as Interactable
	a_panel.trigger()
	c.is_true(not airlock.cycling and a.state == FacilityDoor.State.OPENING, "with both doors closed a panel opens its door at once")
	await a.opened
	c.is_true(not both_open[0], "airlock doors are never open together")


func _door(c: OpeningCheck, path: String, section: StringName) -> FacilityDoor:
	var door := (load(path) as PackedScene).instantiate() as FacilityDoor
	door.section = section
	door.open_time = FAST
	c.add(door)
	return door
