extends RefCounted


func run(c: OpeningCheck) -> void:
	Containment.set_process(false)
	c.equal(Containment.modules.size(), 2, "modules 3 and 4 take part in the first game")
	c.is_true(not Containment.modules.has(&"module_5") and not Containment.modules.has(&"module_6"), "modules 5-6 stay out of the story (canon #32)")
	GameState.set_flag(&"containment_online")
	c.is_true(Containment.is_stable(&"module_3"), "module 3 starts fully stable")
	Containment.tick(600.0)
	c.near(Containment.get_instability(&"module_3"), 0.0, 0.001, "a fully stable sleep never worsens by itself")
	c.equal(Containment.forecast_text(&"module_3"), "прогноза нет", "a stable sleep has no forecast")
	Containment.add_instability(&"module_3", 10.0)
	Containment.tick(60.0)
	c.near(Containment.get_instability(&"module_3"), 10.8, 0.001, "a disturbed sleep keeps worsening")
	var forecast := Containment.forecast_seconds(&"module_3")
	c.near(forecast, (95.0 - 10.8) / 0.8 * 60.0, 0.5, "forecast runs to the chemical threshold")
	Containment.add_instability(&"module_3", 20.0)
	c.is_true(Containment.forecast_seconds(&"module_3") < forecast, "worsening shortens the forecast")
	var worse := Containment.forecast_seconds(&"module_3")
	Containment.stabilize(&"module_3", 10.0)
	c.is_true(Containment.forecast_seconds(&"module_3") > worse, "repairs lengthen the forecast")
	Containment.stabilize(&"module_3", 100.0)
	c.is_true(Containment.is_stable(&"module_3") and Containment.forecast_seconds(&"module_3") < 0.0, "full stabilisation removes the forecast")
	GameState.reset()
	c.near(Containment.get_instability(&"module_4"), 55.0, 0.001, "module 4 starts from its configured value")
	c.equal(Containment.get_stage(&"module_4"), Containment.Stage.ANXIOUS, "55 % is the anxious sleep stage")
	c.equal(Containment.stage_names, ["СПОКОЙНЫЙ СОН", "БЕСПОКОЙНЫЙ СОН", "ТРЕВОЖНЫЙ СОН", "ПРЕДПРОБУЖДЕНИЕ", "ПРОБУЖДЕНИЕ"], "stage names grow in severity")

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
	c.equal(Containment.get_stage(&"module_4"), Containment.Stage.RESTLESS, "stabilising lowers the stage")

	Containment.set_held(&"module_4", true)
	var held := Containment.get_instability(&"module_4")
	Containment.tick(120.0)
	c.near(Containment.get_instability(&"module_4"), held, 0.001, "a held module does not grow")
	Containment.set_held(&"module_4", false)

	# Slow growth reaches 100 % and wakes the prisoner (no endless 99.99 %). The chemical
	# protocol is disarmed so it does not hold the module.
	Containment._chem(&"module_4")["charged"] = false
	Containment.add_instability(&"module_4", 99.0 - Containment.get_instability(&"module_4"))
	for i in 120:
		Containment.tick(1.0)
	c.is_true(Containment.is_awake(&"module_4"), "growth by small steps wakes module 4 at 100 %")
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
	c.equal(lines.size(), 3, "module header, its status line and the hidden line")
	c.equal(lines[0], "МОДУЛЬ 4 — ТРЕВОЖНЫЙ СОН", "monitor shows the stage, never exact percents")
	c.equal(lines[1], Containment.LINE_INDENT + Containment.OFFLINE_LINE, "an offline system gives no forecast and says why")
	GameState.set_flag(&"containment_online")
	c.is_true(Containment.monitor_lines()[1].begins_with(Containment.LINE_INDENT + "Прогноз пробуждения: около "), "an active disturbed module shows an approximate forecast")
	c.is_true(Containment.monitor_lines()[1].ends_with("Затем — химический протокол."), "an armed module says the protocol follows the forecast")
	GameState.grant_access(&"module_3")
	c.equal(Containment.monitor_lines()[0], "МОДУЛЬ 3 — СТАБИЛЬНЫЙ СОН", "a stable module is named stable")
	c.equal(Containment.monitor_lines()[1], Containment.LINE_INDENT + Containment.STABLE_LINE, "a stable module has no awakening threat")
	GameState.revoke_access(&"module_3")
	lines = Containment.monitor_lines()

	var program := TerminalProgram.new()
	program.load_data({"id": "m", "start": "a", "screens": {"a": {"lines": ["Заголовок", "{containment_monitor}"]}}})
	var texts: Array = (program.enter("a")["lines"] as Array).map(func(line: Dictionary) -> String: return line["text"])
	c.equal(texts.size(), 4, "terminal expands the monitor lines")
	c.equal(texts[1], lines[0], "terminal shows the module line")
	c.equal(texts[2], lines[1], "terminal shows the module status")

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
