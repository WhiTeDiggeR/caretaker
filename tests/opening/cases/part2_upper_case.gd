extends RefCounted

## #235: direction «Верх» of part 2 on the sandbox station — two late substations repaired by
## procedures open their short paths, the server room of the new control point starts on both,
## its monitor closes the direction and shows the 3+4 regulation exactly once (one flag shared
## with post №2); the rest of the control point stays closed.

const STATION := "res://scenes/sandbox/stations/upper_station.tscn"
const MONITOR := "res://data/terminals/part2_new_cp.json"
const RULE_FLAG := &"part2/rule_3_4"
const DONE_FLAG := &"part2/dir_upper_done"
const RULE_LINE := "Одновременное снижение стабильности объектов 3 и 4 недопустимо."


func run(c: OpeningCheck) -> void:
	GameState.reset()
	var station := c.add((load(STATION) as PackedScene).instantiate()) as Node3D
	await c.physics_frames(2)
	var east := station.get_node(^"EastProcedure") as RepairProcedure
	var west := station.get_node(^"WestProcedure") as RepairProcedure
	var servers := station.get_node(^"ServersProcedure") as RepairProcedure
	for procedure: RepairProcedure in [east, west, servers]:
		c.is_true(procedure.errors.is_empty(), "%s loads with all its controls" % procedure.id)
	var east_door := station.get_node(^"EastShortcut") as FacilityDoor
	var west_door := station.get_node(^"WestShortcut") as FacilityDoor
	var closed_wing := station.get_node(^"ClosedWing") as FacilityDoor
	c.is_true(not east_door.can_operate() and not west_door.can_operate(), "short paths are dead before the repair")
	c.is_true(not closed_wing.can_operate(), "the rest of the new control point is closed")
	GameState.set_objective(&"part2_restore", "Восстановить системы")

	# Servers refuse to start before both substations feed them.
	_switch(&"ncp_rack_1")
	await c.tree.process_frame
	await c.tree.process_frame
	c.is_true(not GameState.has_flag(RepairControl.flag_for(&"ncp_rack_1")), "a rack springs back without the substations")

	# East: journal, input before section, then the lever.
	_switch(&"up_east_input")
	await c.tree.process_frame
	await c.tree.process_frame
	c.is_true(not GameState.has_flag(RepairControl.flag_for(&"up_east_input")), "east: breakers wait for the protection journal")
	GameState.set_flag(&"part2/upper_east_diagnosed")
	_switch(&"up_east_section")
	await c.tree.process_frame
	await c.tree.process_frame
	c.is_true(not GameState.has_flag(RepairControl.flag_for(&"up_east_section")), "east: the section before the input springs back")
	for control_id: StringName in [&"up_east_input", &"up_east_section", &"up_east_lever"]:
		_switch(control_id)
	await c.tree.process_frame
	c.is_true(east.is_done() and GameState.get_section_power(&"late_east") == GameState.Power.MAIN, "east substation powers its sector")
	c.is_true(east_door.can_operate() and not west_door.can_operate(), "the east short path opens on its own")

	# West: journal, both fans, input before the line.
	GameState.set_flag(&"part2/upper_west_diagnosed")
	for control_id: StringName in [&"up_west_fan_2", &"up_west_fan_1", &"up_west_input", &"up_west_output"]:
		_switch(control_id)
	await c.tree.process_frame
	c.is_true(west.is_done() and west_door.can_operate(), "west substation opens its short path")
	c.equal(GameState.objective_id, &"part2_restore", "substation procedures keep the part 2 objective")

	var program := TerminalProgram.load_file(MONITOR)
	c.equal(program.enter("main")["id"], "no_servers", "without the server room the monitor has no summary")
	for control_id: StringName in [&"ncp_rack_1", &"ncp_rack_2", &"ncp_start"]:
		_switch(control_id)
	await c.tree.process_frame
	c.is_true(servers.is_done() and GameState.get_section_power(&"new_cp") == GameState.Power.MAIN, "both substations start the server room")
	c.is_true(not closed_wing.can_operate(), "the rest of the control point stays closed after the start")

	# The monitor: more systems, the emergency block line, camera 2 off the late network.
	var view := program.enter("main")
	var texts := _texts(view)
	c.equal(view["id"], "main", "the monitor shows its summary")
	c.is_true(texts.has("Аварийный блок: капсул 5. Пробуждение: заблокировано."), "the emergency block line is shown")
	c.is_true(texts.has("Камера №2: нет подключения к поздней сети."), "camera 2 is not on the late network")
	c.is_true(texts.has("Нижний контур: нет данных."), "the lower circuit is unknown before its direction")
	c.is_true(texts.size() > 10, "the monitor lists more systems than the old post")
	c.is_true(not GameState.has_flag(DONE_FLAG), "the direction closes once the summary is read")
	program.complete("main")
	c.is_true(GameState.has_flag(DONE_FLAG), "reading the summary closes «Верх»")

	# «Верх» first: the regulation follows the summary once.
	view = program.enter(view["next"])
	c.equal(view["id"], "rule_3_4", "the regulation follows the summary when it was not read")
	c.is_true(_texts(view).has(RULE_LINE), "the regulation states the 3+4 rule")
	program.complete("rule_3_4")
	c.is_true(GameState.has_flag(RULE_FLAG), "the regulation sets the shared flag")
	c.equal(program.enter(view["next"])["id"], "summary_end", "after it the summary ends")
	c.equal(program.enter(program.enter("main")["next"])["id"], "summary_end", "the regulation is not shown a second time")

	# «Верх» after post №2: the regulation was read there, the monitor skips it.
	GameState.reset()
	GameState.set_section_power(&"new_cp", GameState.Power.MAIN)
	GameState.set_flag(RULE_FLAG)
	GameState.set_flag(&"part2/dir_lower_done")
	view = program.enter("main")
	c.is_true(_texts(view).has("Нижний контур: норма."), "the monitor reports the restored lower circuit")
	program.complete("main")
	c.equal(program.enter(view["next"])["id"], "summary_end", "a regulation read at post 2 is not repeated")
	c.is_true(GameState.has_flag(DONE_FLAG), "«Верх» closes in either order")
	station.queue_free()
	GameState.reset()
	await c.tree.process_frame


func _switch(control_id: StringName) -> void:
	GameState.set_flag(RepairControl.flag_for(control_id))


func _texts(view: Dictionary) -> Array:
	return (view["lines"] as Array).map(func(line: Dictionary) -> String: return line["text"])
