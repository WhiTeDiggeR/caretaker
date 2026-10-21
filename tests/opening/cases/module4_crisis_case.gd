extends RefCounted

## #232: the module 4 crisis on the sandbox station. The first text of №2 starts the cooling
## leak (pressure falls, no forecast yet); a repair in time is «believed №2» — no crisis, trust
## grows, the heat still cracks the seal; a late repair comes after the overheating, whose
## sudden forecast fires the chemical protocol with its repair window. Either way the dry test
## of the protocol spends no reagent and resolves the crisis; the state survives a save.

const STATION := "res://scenes/sandbox/stations/module4_station.tscn"
const M := &"module_4"
const FIRST := &"part2/n2_first_text"
const LEAK := &"part2/module4_cooling_leak"
const OVERHEAT := &"part2/module4_overheat"
const BELIEVED := &"part2/n2_believed"
const CHEM := &"part2/chem_protocol_fired"
const RESOLVED := &"part2/module4_crisis_resolved"
const TRUST := &"part2/n2_trust"
const CONTROLS: Array[StringName] = [&"m4_cool_isolate", &"m4_cool_feed", &"m4_cool_pump"]


func run(c: OpeningCheck) -> void:
	Containment.set_process(false)
	Cooling.set_process(false)
	c.is_true(Cooling.modules.has(M), "module 4 has a cooling")
	var config: Dictionary = Cooling.modules[M]
	var grace := float(config["grace_seconds"])

	# --- Believed: repaired during the leak. ---
	_fresh()
	var station := c.add((load(STATION) as PackedScene).instantiate()) as Node3D
	await c.physics_frames(2)
	var gallery := station.get_node(^"CoolingGallery")
	var procedure := station.get_node(^"CoolingGallery/Procedure") as RepairProcedure
	var post := (station.get_node(^"Post") as Terminal).program
	c.equal(procedure.errors, PackedStringArray(), "the cooling procedure loads")
	c.equal(post.errors, PackedStringArray(), "the module 4 post loads")
	c.equal(Cooling.get_phase(M), Cooling.Phase.NOMINAL, "cooling is nominal before the first text")
	c.is_true(_text(post.enter("main")).contains(Cooling.LINE_NOMINAL), "the post shows a nominal cooling")
	GameState.set_flag(RepairControl.flag_for(CONTROLS[0]))
	await c.tree.process_frame
	c.is_true(not GameState.has_flag(RepairControl.flag_for(CONTROLS[0])), "nothing to repair before the leak")

	GameState.set_flag(FIRST)
	c.equal(Cooling.get_phase(M), Cooling.Phase.LEAK, "the first text of №2 starts the leak")
	c.is_true(GameState.has_flag(LEAK), "the leak is a flag for the procedure")
	Cooling.tick(grace * 0.5)
	c.is_true(Cooling.pressure(M) < 1.0 and Cooling.pressure(M) > float(config["critical_pressure"]), "the pressure falls")
	c.is_true(_text(post.enter("main")).contains("ПАДАЕТ"), "the post shows the falling pressure")
	c.is_true(Containment.is_stable(M) and Containment.forecast_seconds(M) < 0.0, "no crisis and no forecast during the leak")
	c.is_true(not procedure.drive_objective, "the procedure does not tell the hero to repair")
	await _repair(c)
	c.is_true(GameState.has_flag(BELIEVED) and not GameState.has_flag(CHEM), "a repair in time: believed №2")
	c.equal(int(GameState.get_flag(TRUST, 0)), int(config["trust_bonus"]), "trust in №2 grows")
	c.is_true(GameState.has_flag(OVERHEAT), "the heat still cracked the seal: the second dream opens")
	c.near(Containment.get_instability(M), float(config["seal_crack_instability"]), 0.001, "a small loss of stability, a long forecast")
	c.equal(Cooling.get_phase(M), Cooling.Phase.DRY_TEST, "the dry test of the protocol runs")
	c.is_true(not GameState.has_flag(RESOLVED), "the crisis waits for the dry test")
	Cooling.tick(float(config["dry_test_seconds"]))
	c.is_true(GameState.has_flag(RESOLVED), "the dry test resolves the crisis")
	c.is_true(Containment.is_charged(M) and Containment.chemical_phase(M) == Containment.Chemical.READY, "the dry test spends no reagent")
	c.is_true(_text(post.enter("main")).contains(Cooling.LINE_DRY_TEST_DONE), "the post shows the dry test result")
	c.equal(gallery.call("board_text"), gallery.get("BOARD_RESOLVED"), "the gallery board shows the restored cooling")
	station.queue_free()
	await c.tree.process_frame

	# --- Hesitated: overheating, forecast, chemical protocol, repair in its window. ---
	_fresh()
	station = c.add((load(STATION) as PackedScene).instantiate()) as Node3D
	await c.physics_frames(2)
	post = (station.get_node(^"Post") as Terminal).program
	GameState.set_flag(FIRST)
	Cooling.tick(grace)
	c.equal(Cooling.get_phase(M), Cooling.Phase.OVERHEAT, "the leak runs out: overheating")
	c.is_true(GameState.has_flag(OVERHEAT), "overheating is remembered for the second dream")
	c.near(Containment.get_instability(M), float(config["overheat_instability"]), 0.001, "the forecast appears at once")
	c.is_true(Containment.forecast_seconds(M) > 0.0, "the module has a forecast")
	c.near(Containment.growth_per_minute(M), float(Containment.modules[M]["growth_per_minute"]) + float(config["overheat_growth_per_minute"]), 0.001, "overheating speeds up the forecast")
	c.is_true(_text(post.enter("main")).contains("КРИТИЧЕСКОЕ"), "the post shows the critical pressure")
	var to_protocol := Containment.forecast_seconds(M)
	Containment.tick(to_protocol + 0.1)
	Containment.tick(0.01)
	c.equal(Containment.chemical_phase(M), Containment.Chemical.WARNING, "the forecast expires: the protocol warns")
	Containment.tick(float(Containment.chemical["warning_seconds"]))
	c.equal(Containment.chemical_phase(M), Containment.Chemical.SEALED, "the chemical protocol fires")
	c.is_true(GameState.has_flag(CHEM), "the fired protocol is a flag for the interdream")
	c.is_true(not Containment.is_charged(M), "the reagent of module 4 is spent")
	Containment.tick(30.0)
	await _repair(c)
	c.is_true(not GameState.has_flag(BELIEVED), "a late repair is not «believed»")
	c.equal(int(GameState.get_flag(TRUST, 0)), 0, "no trust for a late repair")
	c.is_true(not Containment.growth_bonus.has(M), "the repair stops the overheating")
	Cooling.tick(float(config["dry_test_seconds"]))
	c.is_true(GameState.has_flag(RESOLVED), "the dry test resolves the crisis after the protocol too")
	c.equal(Containment.reagent_stock(), 0, "the dry test does not touch the stock")

	# Save and load keep the outcome; a save during the overheating keeps the faster growth.
	var saved := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.reset()
	c.equal(Cooling.get_phase(M), Cooling.Phase.NOMINAL, "a fresh state has a nominal cooling")
	GameState.from_dict(saved)
	c.equal(Cooling.get_phase(M), Cooling.Phase.RESOLVED, "a save keeps the resolved crisis")
	_fresh()
	GameState.set_flag(FIRST)
	Cooling.tick(grace)
	saved = JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.reset()
	c.is_true(not Containment.growth_bonus.has(M), "a reset clears the overheating")
	GameState.from_dict(saved)
	c.equal(Cooling.get_phase(M), Cooling.Phase.OVERHEAT, "a save keeps the overheating")
	c.is_true(Containment.growth_bonus.has(M), "a loaded overheating keeps speeding up the forecast")

	station.queue_free()
	GameState.reset()
	Containment.set_process(true)
	Cooling.set_process(true)
	await c.tree.process_frame


func _fresh() -> void:
	GameState.reset()
	GameState.set_flag(&"containment_online")
	Containment.set_instability(M, 0.0)


func _repair(c: OpeningCheck) -> void:
	for control in CONTROLS:
		GameState.set_flag(RepairControl.flag_for(control))
		await c.tree.process_frame
	c.is_true(GameState.has_flag(StringName(str(Cooling.modules[M]["repair_flag"]))), "the gallery procedure is done")


func _text(view: Dictionary) -> String:
	return "\n".join((view["lines"] as Array).map(func(line: Dictionary) -> String: return line["text"]))
