extends RefCounted


func run(c: OpeningCheck) -> void:
	Containment.set_process(false)
	c.equal(Containment.modules.size(), 4, "four containment modules are configured")
	c.near(Containment.get_instability(&"module_4"), 55.0, 0.001, "module 4 starts from its configured value")
	c.equal(Containment.get_stage(&"module_4"), Containment.Stage.UNREST, "55 % is the unrest stage")

	Containment.tick(60.0)
	c.near(Containment.get_instability(&"module_4"), 55.0, 0.001, "inactive modules do not grow")
	GameState.set_flag(&"containment_online")
	Containment.tick(60.0)
	c.near(Containment.get_instability(&"module_4"), 56.2, 0.001, "module 4 grows 1.2 % per real minute")

	var stages: Array[int] = []
	var awakened: Array[StringName] = []
	var catastrophes := [0]
	var on_stage := func(id: StringName, stage: int) -> void:
		if id == &"module_4":
			stages.append(stage)
	var on_awake := func(id: StringName) -> void: awakened.append(id)
	var on_catastrophe := func(_ids: Array[StringName]) -> void: catastrophes[0] += 1
	Containment.stage_changed.connect(on_stage)
	Containment.module_awakened.connect(on_awake)
	Containment.catastrophe.connect(on_catastrophe)

	Containment.add_instability(&"module_4", 20.0)
	c.equal(stages, [Containment.Stage.PRE_WAKE] as Array[int], "stage change is announced")
	Containment.stabilize(&"module_4", 30.0)
	c.equal(Containment.get_stage(&"module_4"), Containment.Stage.ALARM, "stabilising lowers the stage")

	Containment.set_held(&"module_4", true)
	var held := Containment.get_instability(&"module_4")
	Containment.tick(120.0)
	c.near(Containment.get_instability(&"module_4"), held, 0.001, "a held module does not grow")
	Containment.set_held(&"module_4", false)

	Containment.add_instability(&"module_4", 200.0)
	c.is_true(Containment.is_awake(&"module_4"), "module 4 wakes at 100 %")
	c.equal(awakened, [&"module_4"] as Array[StringName], "awakening is announced once")
	c.near(Containment.stabilize(&"module_4", 50.0), 100.0, 0.001, "an awakened prisoner stays awake")
	c.equal(catastrophes[0], 0, "one awake module is not the catastrophe")
	Containment.add_instability(&"module_3", 100.0)
	c.equal(catastrophes[0], 1, "modules 3 and 4 awake together cause the catastrophe")
	c.is_true(GameState.has_flag(Containment.CATASTROPHE_FLAG), "catastrophe flag is set")

	# Save and load.
	var saved := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.reset()
	c.near(Containment.get_instability(&"module_4"), 55.0, 0.001, "reset restores start values")
	GameState.from_dict(saved)
	c.is_true(Containment.is_awake(&"module_4") and Containment.is_awake(&"module_3"), "instability survives a save")
	GameState.reset()

	# Monitor: only granted modules, never the number of cells.
	c.equal(Containment.monitor_lines(), PackedStringArray([Containment.MONITOR_HIDDEN_LINE]), "no access shows only the hidden line")
	GameState.grant_access(&"module_4")
	var lines := Containment.monitor_lines()
	c.equal(lines.size(), 2, "one visible module and the hidden line")
	c.is_true(lines[0].begins_with("МОДУЛЬ 4 — 55 % — БЕСПОКОЙСТВО"), "monitor line shows label, value and stage")

	var program := TerminalProgram.new()
	program.load_data({"id": "m", "start": "a", "screens": {"a": {"lines": ["Заголовок", "{containment_monitor}"]}}})
	var texts: Array = (program.enter("a")["lines"] as Array).map(func(line: Dictionary) -> String: return line["text"])
	c.equal(texts.size(), 3, "terminal expands the monitor lines")
	c.equal(texts[1], lines[0], "terminal shows the module line")

	var monitor: ModuleMonitor = c.add((load("res://objects/containment/module_monitor.tscn") as PackedScene).instantiate())
	monitor.section = &"mon"
	monitor.refresh()
	c.equal((monitor.get_node(^"Screen/Text") as Label3D).text, "", "unpowered monitor is dark")
	GameState.set_section_power(&"mon", GameState.Power.EMERGENCY)
	monitor.refresh()
	c.is_true((monitor.get_node(^"Screen/Text") as Label3D).text.contains("МОДУЛЬ 4"), "powered monitor shows the modules")

	Containment.stage_changed.disconnect(on_stage)
	Containment.module_awakened.disconnect(on_awake)
	Containment.catastrophe.disconnect(on_catastrophe)
	Containment.set_process(true)
