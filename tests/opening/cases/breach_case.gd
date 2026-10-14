extends RefCounted

## #178: the cracked wall between the relay room and the senior officer's room, the crowbar
## and the door locked by the senior officer's access, on the sandbox station.
## #211: the electronic door with pass readers, the senior officer's computer granting the
## access, the plug of the wall's own material and the crack as a real slit.
## #219: a wider crack, the computer's dialogue in steps that open the menu items one by one.

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
	var plug := wall.get_node(^"Plug")
	var pieces := plug.find_children("Piece*", "MeshInstance3D", false, false)
	var wall_mesh := wall.get_node(^"WallMesh") as MeshInstance3D
	c.equal(pieces.size(), 2, "the crack splits the plug in two pieces")
	c.is_true(pieces.all(func(piece: Node) -> bool: return (piece as MeshInstance3D).mesh.surface_get_material(0) == wall_mesh.mesh.surface_get_material(0)), "the plug and the wall share one material")
	c.is_true(not _solid_at_crack(pieces), "the crack is a real slit through the plug")
	var start_width := wall.crack_width()
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
	var reader := station.get_node(^"ReaderOutside") as AccessReader
	c.equal(reader.idle_text(), "СЧИТЫВАТЕЛЬ\nДОПУСК СТАРШЕГО", "the reader names the access the door wants")
	c.is_true(not reader.scan() and reader.screen.text.contains("2-117") and reader.screen.text.contains("ОТКАЗАНО"), "the reader refuses the guard's pass and says why")
	c.is_true(door.is_closed(), "a refused pass leaves the door closed")

	# The senior officer's computer: the key, then the succession protocol grants the access.
	var computer := station.get_node(^"SeniorComputer") as Terminal
	c.equal(computer.program.id, "opening_succession", "the computer in the room runs the succession protocol")
	c.is_true(computer.is_powered(), "the computer works on the section power")
	var program := computer.program
	c.equal(_options(program), ["Проверка ключа", "Выход"], "on login only the key check is offered")
	c.equal(program.choose("main", 0), "", "without the key the check is locked")
	GameState.set_flag(&"senior_key_taken")
	# #219: login → key check → operator identification → caretaker status → protocol; each
	# step opens the next menu item.
	var steps := [
		["key_check", "Идентификация оператора", "ПОДЛИННЫЙ"],
		["identify", "Статус смотрителя", "НЕ ПРИНАДЛЕЖИТ ОПЕРАТОРУ"],
		["status", "Протокол преемственности", "НЕ НА СВЯЗИ"],
	]
	for index in steps.size():
		var step: Array = steps[index]
		c.is_true(not _options(program).has(step[1]), "%s is closed before %s" % [step[1], step[0]])
		c.equal(program.choose("main", index), step[0], "the menu leads to %s" % step[0])
		var lines := (program.enter(step[0])["lines"] as Array).map(func(line: Dictionary) -> String: return str(line["text"]).to_upper())
		c.is_true(lines.any(func(line: String) -> bool: return line.contains(step[2])), "%s says %s" % [step[0], step[2]])
		program.complete(step[0])
		c.equal(program.enter(step[0])["next"], "main", "%s returns to the menu" % step[0])
		c.is_true(_options(program).has(step[1]), "%s opens %s" % [step[0], step[1]])
		c.is_true(not GameState.has_access(ACCESS), "%s does not grant the access yet" % step[0])
	c.equal(program.choose("main", 3), "protocol", "after the status check the protocol opens")
	program.complete("protocol")
	c.is_true(GameState.has_access(ACCESS), "the protocol grants the senior officer's access")
	c.is_true(door.lock_reason().is_empty() and control.is_available(), "the granted access opens the way back to ЦУ")
	c.is_true((station.get_node(^"ReaderInside") as AccessReader).scan() and door.state == FacilityDoor.State.OPENING, "the reader lets the pass through and opens the door")
	await c.physics_frames(int((door.open_time + 0.3) * Engine.physics_ticks_per_second))
	c.is_true(door.is_open(), "the electronic door opens")
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
	c.is_true(wall.crack_width() > start_width, "every hit widens the crack")
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


## Texts of the menu options the main screen shows now.
func _options(program: TerminalProgram) -> Array:
	return (program.enter("main")["options"] as Array).map(func(option: Dictionary) -> String: return str(option["text"]))


## Whether something solid stands in the opening of the wall.
func _blocked(wall: BreachWall) -> bool:
	var probe := BoxShape3D.new()
	probe.size = Vector3(wall.opening_width * 0.6, wall.opening_height * 0.6, 0.6)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(wall.global_basis, wall.global_transform * Vector3(0, wall.opening_height * 0.5, 0))
	return not wall.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Whether a plug piece covers the middle of the crack (the crack line at mid-height).
func _solid_at_crack(pieces: Array[Node]) -> bool:
	var origin := Vector3(BreachWall.CRACK_LINE[3].x, BreachWall.CRACK_LINE[3].y, 1.0)
	for piece: Node in pieces:
		var faces := (piece as MeshInstance3D).mesh.get_faces()
		for index in range(0, faces.size(), 3):
			if Geometry3D.ray_intersects_triangle(origin, Vector3.FORWARD, faces[index], faces[index + 1], faces[index + 2]) != null:
				return true
	return false
