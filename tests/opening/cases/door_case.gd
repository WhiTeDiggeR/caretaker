extends RefCounted

const HERMETIC := "res://objects/doors/hermetic_door.tscn"
const MECHANICAL := "res://objects/doors/mechanical_door.tscn"
const GATE := "res://objects/doors/access_gate.tscn"
const AIRLOCK := "res://objects/doors/airlock.tscn"
const SERVICE := "res://objects/doors/service_door.tscn"
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

	# Mechanical door works without power, by holding the wheel; the wheel turns with the hold (#174).
	var manual := _door(c, MECHANICAL, &"")
	var wheel := manual.get_node(^"ControlBack").get_meta(Interactable.META) as Interactable
	var wheel_model := manual.get_node(^"ControlBack").find_child("Wheel", true, false) as Node3D
	var full_turn := TAU * FacilityDoor.WHEEL_TURNS
	c.equal(wheel.mode, Interactable.Mode.HOLD, "mechanical door uses a hold control")
	c.equal(manual.lock_reason(), "", "mechanical door needs no power")
	var interactor := Interactor.new()
	c.add(interactor)
	interactor.set_physics_process(false)  # driven by hand below
	var dt := manual.hold_time * 0.25
	interactor.step(wheel, true, true, dt)
	interactor.step(wheel, true, false, dt)
	c.near(wheel_model.rotation.z, full_turn * 0.5, 0.001, "wheel turns with the hold progress")
	c.is_true(manual.is_closed(), "a half hold does not open the door")
	interactor.step(wheel, false, false, dt)
	await c.tree.create_timer(FacilityDoor.WHEEL_RETURN_TIME + 0.1).timeout
	c.near(wheel_model.rotation.z, 0.0, 0.001, "a released wheel rolls back")
	c.is_true(manual.is_closed(), "an interrupted hold leaves the door closed")
	for i in 5:  # one step more than needed: float steps must not fall short of a full hold
		interactor.step(wheel, true, i == 0, dt)
	c.near(wheel_model.rotation.z, full_turn, 0.001, "a full hold turns the wheel all the way")
	c.equal(manual.state, FacilityDoor.State.OPENING, "a full hold opens the door")
	await manual.opened
	c.is_true(manual.is_open(), "wheel opens the mechanical door")
	c.near(wheel_model.rotation.z, full_turn, 0.001, "the wheel stays turned on an open door")
	interactor.step(wheel, true, true, dt)
	c.near(wheel_model.rotation.z, full_turn * 0.75, 0.001, "closing turns the wheel back")
	interactor.step(null, false, false, dt)
	await c.tree.create_timer(FacilityDoor.WHEEL_RETURN_TIME + 0.1).timeout
	c.near(wheel_model.rotation.z, full_turn, 0.001, "looking away rolls the wheel back to the open rest")
	c.is_true(manual.is_open(), "an interrupted closing hold leaves the door open")

	# Service door: a handle on the leaf at the edge away from the hinges, no lamp, a large zone (#174).
	var service := _door(c, SERVICE, &"")
	var service_leaf := service.get_node(^"Leaf") as Node3D
	for path: NodePath in [^"Leaf/ControlFront", ^"Leaf/ControlBack"]:
		var handle := service.get_node_or_null(path) as Node3D
		c.is_true(handle != null and handle.get_meta(Interactable.META, null) is Interactable, "handle %s is on the leaf" % path)
		c.is_true(handle.position.x > service.width * 0.5, "handle %s is on the free edge" % path)
		c.is_true(handle.find_child("Lamp", true, false) == null, "handle %s has no lamp" % path)
		var zone := (handle.get_child(0) as CollisionShape3D).shape as BoxShape3D
		c.is_true(zone.size.x >= 0.3 and zone.size.y >= 0.3, "handle %s zone is larger than the handle" % path)
	c.is_true(service.get_node_or_null(^"ControlFront") == null, "no handle on the frame")
	var handle_front := service.get_node(^"Leaf/ControlFront") as Node3D
	var closed_at := handle_front.global_position
	c.is_true(service.open(), "service door opens")
	await service.opened
	c.is_true(handle_front.global_position.distance_to(closed_at) > 0.5, "the handle leaves with the leaf")
	c.near(service_leaf.rotation.y, -FacilityDoor.SWING_ANGLE, 0.001, "service leaf swung open")

	# The old-core «historic» door is hinged.
	var historic := _door(c, "res://objects/doors/historic_door.tscn", &"")
	var historic_leaf := historic.get_node(^"Leaf") as Node3D
	c.equal(historic.slide_axis, FacilityDoor.SlideAxis.SWING, "historic door swings on hinges")
	c.is_true(historic.open(), "historic door opens")
	await historic.opened
	c.near(historic_leaf.rotation.y, -FacilityDoor.SWING_ANGLE, 0.001, "leaf swung around the hinge")
	c.near(historic_leaf.position.x, -historic.width * 0.5, 0.001, "hinge stays at the frame edge")
	c.is_true(historic.close(), "historic door closes")
	await historic.closed
	c.near(historic_leaf.rotation.y, 0.0, 0.001, "leaf returned to the frame")

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
	c.is_true(airlock.cycling, "closing the inner door does not skip the ventilation to the outer side")
	await airlock.cycle_finished
	c.is_true(a.is_open() and b.is_closed() and airlock.synced_door == a, "outer door opens only after ventilation")
	a_panel.trigger()
	await a.closed
	a_panel.trigger()
	c.is_true(not airlock.cycling and a.state == FacilityDoor.State.OPENING, "the equalised side opens at once")
	await a.opened
	c.is_true(not both_open[0], "airlock doors are never open together")


func _door(c: OpeningCheck, path: String, section: StringName) -> FacilityDoor:
	var door := (load(path) as PackedScene).instantiate() as FacilityDoor
	door.section = section
	door.open_time = FAST
	c.add(door)
	return door
