extends RefCounted

const C := &"module_4"


func run(c: OpeningCheck) -> void:
	Containment.set_process(false)
	var events: Array[String] = []
	var log_event := func(name: String) -> Callable:
		return func(id: StringName, _extra: Variant = null) -> void: events.append("%s:%s" % [name, id])
	var on_warning: Callable = log_event.call("warning")
	var on_sealed: Callable = log_event.call("sealed")
	var on_window: Callable = log_event.call("window")
	var on_gassed: Callable = log_event.call("gassed")
	var on_woken: Callable = log_event.call("woken")
	Containment.chemical_warning.connect(on_warning)
	Containment.module_sealed.connect(on_sealed)
	Containment.repair_window_ended.connect(on_window)
	Containment.hero_gassed.connect(on_gassed)
	Containment.hero_woken.connect(on_woken)

	c.equal(Containment.chemical_phase(C), Containment.Chemical.READY, "protocol starts armed")
	c.is_true(Containment.is_charged(C), "module 4 starts charged")
	c.equal(Containment.reagent_stock(), 1, "one reagent charge in stock")

	Containment.add_instability(C, 95.0 - Containment.get_instability(C))
	Containment.tick(0.1)
	c.equal(Containment.chemical_phase(C), Containment.Chemical.WARNING, "threshold starts the warning")
	c.near(Containment.chemical_timer(C), 10.0, 0.001, "warning lasts 10 s")
	Containment.tick(10.0)
	c.equal(Containment.chemical_phase(C), Containment.Chemical.SEALED, "module seals after the warning")
	c.is_true(Containment.is_held(C) and Containment.has_gas(C) and not Containment.is_charged(C), "sealed: held, gassed, reagent spent")
	c.near(Containment.chemical_timer(C), 180.0, 0.001, "full repair window when the hero is outside")
	c.is_true(Containment.monitor_lines().size() == 1, "module 4 is not granted yet")
	GameState.grant_access(C)
	c.is_true(Containment.monitor_lines()[0].contains("ХИМИЧЕСКИЙ СОН 03:00"), "monitor shows the chemical sleep and its clock")

	var held := Containment.get_instability(C)
	Containment.tick(60.0)
	c.near(Containment.get_instability(C), held, 0.001, "chemical sleep holds the instability")
	c.equal(Containment.vent_lock_reason(C), Containment.REASON_SEALED, "no ventilation while sealed")
	Containment.stabilize(C, 40.0)
	Containment.tick(120.0)
	c.equal(Containment.chemical_phase(C), Containment.Chemical.SPENT, "repair window ends")
	c.is_true(not Containment.is_held(C), "growth resumes after the window")

	c.equal(Containment.recharge_lock_reason(C), Containment.REASON_GAS, "recharge needs ventilation first")
	c.is_true(Containment.vent(C), "ventilation starts")
	c.equal(Containment.vent_lock_reason(C), Containment.REASON_VENTING, "ventilation runs")
	Containment.tick(30.0)
	c.is_true(not Containment.has_gas(C), "ventilation clears the gas")
	c.is_true(Containment.recharge(C), "recharge from the stock")
	c.equal(Containment.reagent_stock(), 0, "stock is used")
	c.equal(Containment.chemical_phase(C), Containment.Chemical.READY, "protocol is armed again")

	# Saved and restored.
	var saved := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.reset()
	GameState.from_dict(saved)
	c.is_true(Containment.is_charged(C) and Containment.reagent_stock() == 0, "protocol state survives a save")

	# A hero inside without the chair falls asleep.
	Containment.set_hero_inside(&"module_3", true)
	Containment.add_instability(&"module_3", 95.0 - Containment.get_instability(&"module_3"))
	Containment.tick(0.1)
	Containment.tick(10.0)
	c.is_true(GameState.has_flag(Containment.GASSED_FLAG), "hero inside without the chair is gassed")
	Containment.set_hero_inside(&"module_3", false)

	# A hero connected to the chair is woken and gets a shorter window.
	var loads: Array[String] = []
	var original_loader := Dreams.scene_loader
	Dreams.scene_loader = func(path: String) -> void: loads.append(path)
	Dreams.in_dream = true
	Dreams.module_id = &"module_5"
	Containment.add_instability(&"module_5", 95.0 - Containment.get_instability(&"module_5"))
	Containment.tick(0.1)
	Containment.tick(10.0)
	c.near(Containment.chemical_timer(&"module_5"), 72.0, 0.001, "woken hero gets 40 % of the window")
	c.is_true(not Dreams.in_dream, "the session ends when object 2 wakes the hero")
	c.equal(Dreams.return_title(Dreams.Exit.WOKEN), "ЭКСТРЕННОЕ ПРОБУЖДЕНИЕ", "emergency wake-up message")
	await c.tree.create_timer(Dreams.FADE_SECONDS * 2.0 + 0.2).timeout
	Dreams.scene_loader = original_loader
	Dreams.module_id = &""

	# Without reagent the next crisis wakes the prisoner.
	Containment.tick(73.0)
	Containment.add_instability(&"module_5", 10.0)
	Containment.tick(1.0)
	c.equal(Containment.recharge_lock_reason(&"module_5"), Containment.REASON_GAS, "spent module cannot fire again")
	Containment.add_instability(&"module_5", 100.0)
	c.is_true(Containment.is_awake(&"module_5"), "a second crisis without service wakes the prisoner")

	c.equal(events, ["warning:module_4", "sealed:module_4", "window:module_4", "warning:module_3", "sealed:module_3", "gassed:module_3",
			"warning:module_5", "sealed:module_5", "woken:module_5", "window:module_5"] as Array[String], "protocol events in order")

	var panel: ReagentPanel = c.add((load("res://objects/containment/reagent_panel.tscn") as PackedScene).instantiate())
	panel.module_id = C
	panel.refresh()
	c.is_true((panel.get_node(^"Status") as Label3D).text.contains("Запас реагента: 0"), "reagent panel shows the stock")

	Containment.chemical_warning.disconnect(on_warning)
	Containment.module_sealed.disconnect(on_sealed)
	Containment.repair_window_ended.disconnect(on_window)
	Containment.hero_gassed.disconnect(on_gassed)
	Containment.hero_woken.disconnect(on_woken)
	Containment.set_process(true)
