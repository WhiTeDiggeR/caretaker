extends RefCounted

const SANDBOX_STATION := "res://scenes/sandbox/stations/power_station.tscn"


func run(c: OpeningCheck) -> void:
	# Light states.
	var light := _light(c, &"p1", 0.0)
	var section_light := light.get_node(^"SectionLight") as SectionLight
	c.is_true(not light.visible, "unpowered light is dark")
	GameState.set_section_power(&"p1", GameState.Power.EMERGENCY)
	c.is_true(light.visible, "emergency light is lit")
	c.near(light.light_energy, 0.5, 0.001, "emergency energy")
	c.equal(light.light_color, section_light.emergency_color, "emergency colour")
	GameState.set_section_power(&"p1", GameState.Power.MAIN)
	c.near(light.light_energy, 3.0, 0.001, "main energy")
	c.equal(light.light_color, Color(1, 1, 1), "main colour restored")
	GameState.set_section_power(&"p1", GameState.Power.OFF)
	c.is_true(not light.visible, "light goes dark without power")

	# Cascade delay on power-up, immediate power-down, cancelled power-up.
	var late := _light(c, &"p2", 0.2)
	GameState.set_section_power(&"p2", GameState.Power.MAIN)
	c.is_true(not late.visible, "delayed light is still dark right after power-up")
	await c.tree.create_timer(0.3).timeout
	c.is_true(late.visible, "delayed light comes on after its delay")
	GameState.set_section_power(&"p2", GameState.Power.OFF)
	c.is_true(not late.visible, "power-down is immediate")
	GameState.set_section_power(&"p2", GameState.Power.MAIN)
	GameState.set_section_power(&"p2", GameState.Power.OFF)
	await c.tree.create_timer(0.3).timeout
	c.is_true(not late.visible, "cancelled power-up does not light the lamp")

	# Loading a save applies power at once.
	var saved := GameState.to_dict()
	(saved["section_power"] as Dictionary)["p2"] = "main"
	GameState.from_dict(saved)
	c.is_true(late.visible, "loaded power is applied without delay")

	# Sound follows power.
	var speaker := AudioStreamPlayer.new()
	var sound := SectionSound.new()
	sound.section = &"p3"
	speaker.add_child(sound)
	c.add(speaker)
	c.is_true(speaker.stream == null, "no sound without power")
	GameState.set_section_power(&"p3", GameState.Power.EMERGENCY)
	c.equal(speaker.stream, PlaceholderTones.alarm(), "alarm on emergency power")
	GameState.set_section_power(&"p3", GameState.Power.MAIN)
	c.equal(speaker.stream, PlaceholderTones.hum(), "hum on main power")
	c.is_true(PlaceholderTones.alarm().data.size() > 0, "alarm tone is generated")

	# Cascade delays grow with distance.
	var cascade := PowerCascade.new()
	var near_light := _light_node(&"p4", Vector3(2, 0, 0))
	var far_light := _light_node(&"p4", Vector3(10, 0, 0))
	cascade.add_child(near_light)
	cascade.add_child(far_light)
	c.add(cascade)
	var near_delay := (near_light.get_node(^"SectionLight") as PowerConsumer).cascade_delay
	var far_delay := (far_light.get_node(^"SectionLight") as PowerConsumer).cascade_delay
	c.is_true(far_delay > near_delay and near_delay > 0.0, "farther lights come on later")

	# Sandbox station: three of seven lamps work on emergency power.
	GameState.set_section_power(&"sandbox_b", GameState.Power.EMERGENCY)
	var station: Node3D = c.add((load(SANDBOX_STATION) as PackedScene).instantiate())
	var lit := 0
	for node in station.find_children("*", "SectionLight", true, false):
		if (node as SectionLight).is_lit():
			lit += 1
	c.equal(lit, 3, "emergency lighting in the sandbox station")


func _light(c: OpeningCheck, section: StringName, delay: float) -> OmniLight3D:
	var light := _light_node(section, Vector3.ZERO)
	(light.get_node(^"SectionLight") as SectionLight).cascade_delay = delay
	c.add(light)
	return light


func _light_node(section: StringName, position: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = Color(1, 1, 1)
	var component := SectionLight.new()
	component.name = "SectionLight"
	component.section = section
	component.main_energy = 3.0
	component.emergency_energy = 0.5
	component.startup_flicker = 0.0
	light.add_child(component)
	return light
