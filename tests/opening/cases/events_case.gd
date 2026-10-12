extends RefCounted

## #133: scripted events — catalogue, step order and waits, once-only, cancel on load,
## triggers (area, condition, call) and the sandbox blackout station.

const STATION := "res://scenes/sandbox/stations/event_station.tscn"
const DOOR := "res://objects/doors/hermetic_door.tscn"


func run(c: OpeningCheck) -> void:
	c.equal(EventLibrary.errors(), PackedStringArray(), "event catalogue has no errors")
	c.is_true(EventLibrary.has(&"sandbox_blackout"), "the sandbox blackout is in the catalogue")
	var bad := EventLibrary.validate_steps([{"wait": 1, "message": {}}, {"teleport": 1}, {"door": {"action": "smash"}}, {"power": {"power": "max"}}], "t")
	c.equal(bad.size(), 4, "invalid steps are reported")

	# Order and waits.
	var sequence := _sequence(c, &"t_order", [
		{"effects": [{"set_flag": "t/a"}]},
		{"wait": 0.3},
		{"effects": [{"set_flag": "t/b"}]},
	])
	var finished: Array[StringName] = []
	sequence.finished.connect(func(id: StringName) -> void: finished.append(id))
	c.is_true(sequence.play(), "an event starts")
	c.is_true(GameState.has_flag(&"t/a") and not GameState.has_flag(&"t/b"), "steps run in order up to a wait")
	c.is_true(not sequence.play(), "a running event does not restart")
	await c.tree.create_timer(0.45).timeout
	c.is_true(GameState.has_flag(&"t/b"), "the step after the wait runs")
	c.equal(finished, [&"t_order"] as Array[StringName], "finished is emitted once")
	c.is_true(GameState.has_flag(EventSequence.done_flag(&"t_order")), "a finished event is marked done")

	# Once only, also after a save round trip.
	GameState.clear_flag(&"t/a")
	c.is_true(not sequence.play(), "a done event does not run again")
	var saved := GameState.to_dict()
	GameState.reset()
	GameState.from_dict(saved)
	c.is_true(not sequence.can_play(), "done survives a save")
	sequence.repeatable = true
	c.is_true(sequence.play(), "a repeatable event runs again")
	await c.tree.create_timer(0.45).timeout

	# Loading a save cancels a running event.
	var long := _sequence(c, &"t_cancel", [{"wait": 0.3}, {"effects": [{"set_flag": "t/late"}]}])
	var before := GameState.to_dict()
	long.play()
	GameState.from_dict(before)
	c.is_true(not long.running, "loading cancels a running event")
	await c.tree.create_timer(0.45).timeout
	c.is_true(not GameState.has_flag(&"t/late") and not long.is_done(), "a cancelled event does not finish")

	# Chained events.
	var inner := _sequence(c, &"t_inner", [{"wait": 0.2}, {"effects": [{"set_flag": "t/inner"}]}])
	var outer := _sequence(c, &"t_outer", [{"run": "t_inner", "await": true}, {"effects": [{"set_flag": "t/outer"}]}])
	outer.play()
	await c.tree.create_timer(0.1).timeout
	c.is_true(inner.running and not GameState.has_flag(&"t/outer"), "run with await waits for the other event")
	await c.tree.create_timer(0.3).timeout
	c.is_true(GameState.has_flag(&"t/inner") and GameState.has_flag(&"t/outer"), "the chain completes in order")

	# Condition trigger: checked on state changes.
	var on_flag := _sequence(c, &"t_condition", [{"effects": [{"set_flag": "t/condition_ran"}]}])
	var condition := EventTrigger.new()
	condition.mode = EventTrigger.Mode.CONDITION
	condition.condition_json = "{\"flag\": \"t/go\"}"
	condition.sequence = on_flag
	c.add(condition)
	await c.tree.process_frame
	c.is_true(not on_flag.is_done(), "a condition trigger waits for its condition")
	GameState.set_flag(&"t/go")
	await c.tree.process_frame
	c.is_true(GameState.has_flag(&"t/condition_ran"), "the condition starts the event")

	# Area trigger: the player entering the zone.
	var in_area := _sequence(c, &"t_area", [{"effects": [{"set_flag": "t/area_ran"}]}])
	var area := EventTrigger.new()
	area.sequence = in_area
	area.position = Vector3(40, 1, 0)
	var zone := CollisionShape3D.new()
	zone.shape = BoxShape3D.new()
	area.add_child(zone)
	c.add(area)
	var hero := CharacterBody3D.new()
	var body := CollisionShape3D.new()
	body.shape = SphereShape3D.new()
	hero.add_child(body)
	hero.position = Vector3(44, 1, 0)
	hero.add_to_group(&"player")
	c.add(hero)
	await c.physics_frames(3)
	c.is_true(not in_area.is_done(), "the area waits for the player")
	hero.position = Vector3(40, 1, 0)
	await c.physics_frames(4)
	c.is_true(GameState.has_flag(&"t/area_ran"), "entering the area starts the event")
	hero.queue_free()

	# Doors keep a scripted lock in saves.
	var door := (load(DOOR) as PackedScene).instantiate() as FacilityDoor
	c.add(door)
	door.emergency_lock = true
	var door_state := door.save_state()
	door.emergency_lock = false
	door.load_state(door_state)
	c.is_true(door.emergency_lock, "a door save keeps the emergency lock")
	door.load_state({"open": false})
	c.is_true(door.emergency_lock, "older saves keep the authored lock")

	await _station(c)


func _station(c: OpeningCheck) -> void:
	GameState.set_section_power(&"sandbox_event", GameState.Power.MAIN)
	Objectives.start(&"sandbox_tour")
	var station := (load(STATION) as PackedScene).instantiate() as Node3D
	station.position = Vector3(-40, 0, 0)
	c.add(station)
	var station_door := station.get_node(^"Door") as FacilityDoor
	var blackout := station.get_node(^"Blackout") as EventSequence
	var reset := station.get_node(^"Reset") as EventSequence
	c.is_true(station_door.is_open() and station_door.lock_reason().is_empty(), "the station door starts open and free")
	c.is_true((station.get_node(^"Lamp1") as OmniLight3D).visible, "the station lamps start lit")
	(station.get_node(^"Zone") as EventTrigger).fire()
	await blackout.finished
	c.equal(GameState.get_section_power(&"sandbox_event"), GameState.Power.EMERGENCY, "blackout drops the section to emergency power")
	c.is_true(station_door.state in [FacilityDoor.State.CLOSING, FacilityDoor.State.CLOSED], "blackout closes the door")
	c.equal(station_door.lock_reason(), FacilityDoor.REASON_EMERGENCY, "blackout locks the door")
	c.equal(Objectives.active_chain(), &"sandbox_blackout", "blackout sets the objective")
	c.is_true(not (station.get_node(^"Zone") as EventTrigger).fire(), "the blackout happens once")
	(station.get_node(^"ResetButton/Interactable") as Interactable).trigger()
	await reset.finished
	c.equal(GameState.get_section_power(&"sandbox_event"), GameState.Power.MAIN, "reset restores the power")
	c.is_true(not station_door.emergency_lock, "reset unlocks the door")
	c.equal(Objectives.active_chain(), &"sandbox_tour", "reset returns to the sandbox tour")
	c.is_true(blackout.can_play(), "reset re-arms the blackout")
	var camera := c.tree.root.get_viewport().get_camera_3d()
	if camera:
		c.is_true(is_zero_approx(camera.h_offset) and is_zero_approx(camera.v_offset), "the shake leaves the camera centred")


func _sequence(c: OpeningCheck, id: StringName, steps: Array) -> EventSequence:
	var sequence := EventSequence.new()
	sequence.event_id = id
	sequence.steps = steps
	c.add(sequence)
	return sequence
