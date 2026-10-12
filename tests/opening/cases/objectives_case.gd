extends RefCounted

## #125: objective chains and one-time hints.

const TEST_CHAIN := {
	"t_chain": {
		"final_text": "Всё сделано",
		"steps": [
			{"id": "t_a", "text": "Шаг А", "done_when": {"flag": "t_a"}},
			{"id": "t_b", "text": "Шаг Б", "done_when": {"access": "t_b"}},
			{"id": "t_c", "text": "Шаг В", "done_when": {"flag": "t_c"}},
		],
	},
}


class FakeDisplay:
	extends Node
	var shown: Array[String] = []

	func show_hint(text: String) -> void:
		shown.append(text)


func run(c: OpeningCheck) -> void:
	c.equal(Objectives.validate(), PackedStringArray(), "objective data is valid")
	c.is_true(Objectives.chains.has(&"opening") and Objectives.chains.has(&"sandbox_tour"), "opening and sandbox chains load")
	c.equal(Hints.validate(), PackedStringArray(), "hint data is valid (texts and key placeholders)")

	GameState.set_flag(&"t_list", ["doc"])
	c.is_true(GameState.has_flag(&"t_list"), "a flag holding a non-empty list holds")
	GameState.set_flag(&"t_list", [])
	c.is_true(not GameState.has_flag(&"t_list"), "a flag holding an empty list does not hold")

	Objectives.add_chains(TEST_CHAIN)
	var started: Array[StringName] = []
	var on_step := func(_chain: StringName, step: StringName) -> void: started.append(step)
	Objectives.step_started.connect(on_step)
	Objectives.start(&"t_chain")
	c.equal(GameState.objective_text, "Шаг А", "the first step becomes the objective")
	GameState.set_flag(&"t_a")
	await c.tree.process_frame
	c.equal(GameState.objective_text, "Шаг Б", "a done step starts the next one")
	c.equal(Objectives.completed_texts(), PackedStringArray(["Шаг А"]), "finished steps are listed")

	# Saved and loaded with the game.
	var saved := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.grant_access(&"t_b")
	GameState.set_flag(&"t_c")
	await c.tree.process_frame
	c.is_true(Objectives.is_completed(), "steps that are already done are skipped")
	c.equal(GameState.objective_text, "Всё сделано", "the final text follows the last step")
	GameState.from_dict(saved)
	await c.tree.process_frame
	c.equal(Objectives.current_step().get("id"), "t_b", "loading restores the step")
	c.equal(GameState.objective_text, "Шаг Б", "loading restores the objective")
	c.equal(started, [&"t_a", &"t_b"] as Array[StringName], "step starts are announced (loading does not repeat them)")
	GameState.reset()
	await c.tree.process_frame
	c.equal(Objectives.active_chain(), &"", "a new game has no chain until a scenario starts one")
	Objectives.step_started.disconnect(on_step)
	Objectives.chains.erase(&"t_chain")

	# Hints: once, with the current keys, only when the screen is free.
	Hints._queue.clear()
	Hints._cooldown = 0.0
	var display := FakeDisplay.new()
	display.add_to_group(Hints.DISPLAY_GROUP)
	c.add(display)
	var hero := Node3D.new()
	hero.add_to_group(&"player")
	c.add(hero)
	Hints.hints[&"t_hint"] = {"text": "Нажмите {crawl}, чтобы лечь."}
	c.is_true(Hints.text_of(&"t_hint").contains(InputPromptFormatter.action_label(&"crawl")) if InputMap.has_action(&"crawl") else Hints.text_of(&"t_hint").contains("{crawl}"), "placeholders become keys")
	Hints.hints[&"t_hint"] = {"text": "Нажмите {interact}."}
	c.equal(Hints.text_of(&"t_hint"), "Нажмите E.", "the interact key is shown")
	Hints.request(&"t_hint")
	Hints.request(&"t_hint")
	await c.tree.process_frame
	await c.tree.process_frame
	c.equal(display.shown.count("Нажмите E."), 1, "a requested hint is shown once")
	c.is_true(Hints.was_shown(&"t_hint"), "a shown hint is remembered")
	Hints._cooldown = 0.0
	Hints.request(&"t_hint")
	await c.tree.process_frame
	c.equal(display.shown.count("Нажмите E."), 1, "a shown hint never repeats")

	Hints.hints[&"t_when"] = {"text": "Условие", "when": {"flag": "t_when"}}
	Hints._cooldown = 0.0
	c.tree.paused = true
	GameState.set_flag(&"t_when")
	await c.tree.process_frame
	c.is_true(not display.shown.has("Условие"), "hints wait while the game is paused")
	c.tree.paused = false
	await c.tree.process_frame
	c.is_true(display.shown.has("Условие"), "a hint whose condition holds is shown")
	Hints.hints.erase(&"t_hint")
	Hints.hints.erase(&"t_when")
	Hints._cooldown = 0.0
	GameState.reset()
