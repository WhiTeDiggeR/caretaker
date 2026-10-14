extends RefCounted

## #178: the cracked wall between the relay room and the senior officer's room, the crowbar
## and the door locked by the senior officer's access, on the sandbox station.

const STATION := "res://scenes/sandbox/stations/breach_station.tscn"
const SECTION := &"sandbox_a"
const ACCESS := &"caretaker"


func run(c: OpeningCheck) -> void:
	GameState.reset()
	DocumentLibrary.reload()
	var station := c.add((load(STATION) as PackedScene).instantiate()) as Node3D
	await c.physics_frames(2)
	var wall := station.get_node(^"BreachWall") as BreachWall
	var door := station.get_node(^"SeniorDoor") as FacilityDoor
	var crowbar := station.get_node(^"Crowbar") as CrowbarPickup
	var interactable := wall.interactable
	c.is_true(DocumentLibrary.has(BreachWall.TEXT_DARK) and DocumentLibrary.has(BreachWall.TEXT_LIT), "crack inspect texts exist")
	c.is_true(_blocked(wall), "the crack blocks the way")

	# Unpowered: the room behind is dark, the crack is only inspected.
	c.is_true(not wall.is_lit() and not wall.room_light.visible, "no power: the room behind the crack is dark")
	c.equal(interactable.mode, Interactable.Mode.INSPECT, "without the crowbar the crack is inspected")
	c.is_true(interactable.get_inspect_text().contains("За стеной темно"), "the dark crack says the room is dark")
	c.is_true(interactable.get_inspect_text().contains("руками не расширить"), "the crack says hands are not enough")
	interactable.trigger()
	c.is_true(not wall.strike() and wall.hits_done() == 0 and not wall.is_open(), "without the crowbar the wall does not break")

	# The generator powers the room: light through the crack.
	GameState.set_section_power(SECTION, GameState.Power.EMERGENCY)
	c.is_true(not wall.room_light.visible, "emergency power does not light the room")
	GameState.set_section_power(SECTION, GameState.Power.MAIN)
	c.is_true(wall.is_lit() and wall.room_light.visible, "main power lights the room behind the crack")
	c.is_true(interactable.get_inspect_text().contains("пробивается свет"), "the lit crack tells about the light")

	# The door from the old control point is locked by the senior officer's access (#178,
	# author's note): the succession protocol grants it, then the hero walks back out to ЦУ.
	var control: Interactable = door._controls[0]
	c.equal(door.required_access, ACCESS, "the door to the room needs the access of the succession protocol")
	c.equal(door.lock_reason(), FacilityDoor.REASON_NO_ACCESS, "without the access the door is locked")
	c.is_true(not door.open() and not control.is_available() and control.unavailable_prompt == FacilityDoor.REASON_NO_ACCESS, "the locked door does not open and says why")
	GameState.grant_access(ACCESS)
	c.is_true(door.lock_reason().is_empty() and control.is_available(), "the granted access opens the way back to ЦУ")
	GameState.revoke_access(ACCESS)
	c.equal(control.unavailable_prompt, FacilityDoor.REASON_NO_ACCESS, "revoking the access locks the door again")
	c.is_true(wall.is_in_group(BreachWall.ROUTE_PASSABLE_GROUP), "the route check treats the breach as passable")
	c.is_true(is_equal_approx(wall.opening_width, 1.2) and is_equal_approx(wall.opening_height, 2.0), "the opening matches the breach door of L-OLD-CORE")

	# The crowbar from the fire shield.
	(crowbar.get_meta(Interactable.META) as Interactable).trigger()
	c.is_true(GameState.has_flag(&"item_crowbar") and not crowbar.visible, "the crowbar is taken and disappears")
	c.equal(interactable.mode, Interactable.Mode.HOLD, "with the crowbar the crack is broken by holding")
	c.equal(interactable.prompt, BreachWall.PROMPT_BREAK, "the crack offers to break it with the crowbar")

	# Holding the interact action: one hit per hold, the last one opens the wall.
	var interactor := Interactor.new()
	c.add(interactor)
	for index in wall.hits_required - 1:
		interactor.step(interactable, true, index == 0, wall.hit_time * 0.5)
		interactor.step(interactable, true, false, wall.hit_time * 0.5 + 0.01)
	c.equal(wall.hits_done(), wall.hits_required - 1, "each full hold is one hit")
	c.is_true(not wall.is_open() and _blocked(wall), "the wall holds until the last hit")
	interactor.step(interactable, false, false, 0.1)
	interactor.step(interactable, true, true, wall.hit_time * 0.5)
	interactor.step(interactable, false, false, 0.1)
	c.equal(wall.hits_done(), wall.hits_required - 1, "a released hold is not a hit")
	interactor.step(interactable, true, true, wall.hit_time + 0.01)
	c.is_true(wall.is_open() and GameState.has_flag(wall.flag), "the last hit breaks the wall open")
	await c.physics_frames(2)
	c.is_true(not _blocked(wall) and not interactable.is_available(), "the hole lets the hero through")

	# Save and load: the state comes from GameState.
	var saved: Variant = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.reset()
	await c.physics_frames(2)
	c.is_true(not wall.is_open() and _blocked(wall) and crowbar.visible and not wall.room_light.visible, "a fresh state restores the crack, the crowbar and the dark")
	c.equal(interactable.mode, Interactable.Mode.INSPECT, "without the crowbar again the crack is only inspected")
	c.is_true(GameState.from_dict(saved), "the saved state loads")
	await c.physics_frames(2)
	c.is_true(wall.is_open() and not _blocked(wall) and wall.hits_done() == wall.hits_required, "loading restores the broken wall")
	c.is_true(not crowbar.visible and wall.room_light.visible, "loading restores the taken crowbar and the light")
	interactor.queue_free()
	GameState.reset()


## Whether something solid stands in the opening of the wall.
func _blocked(wall: BreachWall) -> bool:
	var probe := BoxShape3D.new()
	probe.size = Vector3(wall.opening_width * 0.6, wall.opening_height * 0.6, 0.6)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(wall.global_basis, wall.global_transform * Vector3(0, wall.opening_height * 0.5, 0))
	return not wall.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
