extends RefCounted

const DATA_DIR := "res://data/terminals"
const SANDBOX := "res://scenes/sandbox/opening_sandbox.tscn"

const SAMPLE := {
	"id": "sample",
	"title": "ПРОБА",
	"start": "main",
	"screens": {
		"main": {
			"redirects": [{"if": {"flag": "done"}, "goto": "after"}],
			"lines": [
				"всегда",
				{"text": "при питании", "if": {"power": {"section": "s", "min": "main"}}},
				{"text": "без основного", "if": {"power": {"section": "s", "max": "emergency"}}, "wait": 0.5},
			],
			"options": [
				{"text": "дальше", "goto": "proc", "requires": {"access": "caretaker"}, "locked_text": "нет допуска"},
				{"text": "скрыт", "goto": "after", "visible_if": {"flag": "never"}},
				{"text": "выход", "action": "exit", "effects": [{"set_flag": "left"}]},
			],
		},
		"proc": {
			"lines": ["процедура"],
			"effects": [{"set_flag": "done"}, {"event": "proc_done"}, {"set_power": {"section": "s", "power": "main"}}],
			"next": "main",
		},
		"after": {"lines": ["после"], "options": [{"text": "выход", "action": "exit"}]},
	},
}


func run(c: OpeningCheck) -> void:
	# Every authored program is valid.
	var files := DirAccess.get_files_at(DATA_DIR)
	var programs := 0
	for file in files:
		if file.get_extension() != "json":
			continue
		programs += 1
		var authored := TerminalProgram.load_file(DATA_DIR.path_join(file))
		c.equal(authored.errors, PackedStringArray(), "%s is valid" % file)
	c.is_true(programs > 0, "authored terminal programs exist")

	# Model behaviour.
	var program := TerminalProgram.new()
	program.load_data(SAMPLE)
	c.equal(program.errors, PackedStringArray(), "sample program is valid")
	var events: Array[StringName] = []
	program.event_triggered.connect(func(event: StringName) -> void: events.append(event))
	var view := program.enter("main")
	c.equal((view["lines"] as Array).map(func(line: Dictionary) -> String: return line["text"]), ["всегда", "без основного"], "conditional lines")
	c.near(float((view["lines"] as Array)[1]["wait"]), 0.5, 0.001, "line wait is kept")
	var options: Array = view["options"]
	c.equal(options.size(), 2, "hidden option is skipped")
	c.is_true(not options[0]["available"] and options[0]["locked_text"] == "нет допуска", "locked option shows its reason")
	c.equal(program.choose("main", 0), "", "locked option cannot be chosen")
	GameState.grant_access(&"caretaker")
	c.equal(program.choose("main", 0), "proc", "available option leads on")
	program.enter("proc")
	c.is_true(not GameState.has_flag(&"done"), "screen effects wait for the lines")
	program.complete("proc")
	c.is_true(GameState.has_flag(&"done"), "screen effects apply on completion")
	c.equal(events, [&"proc_done"] as Array[StringName], "event effect is emitted")
	c.equal(GameState.get_section_power(&"s"), GameState.Power.MAIN, "power effect is applied")
	c.equal(program.enter("main")["id"], "after", "redirect follows the new state")
	c.equal(program.choose("main", 2), "exit", "exit option")
	c.is_true(GameState.has_flag(&"left"), "option effects apply on choice")

	var broken := TerminalProgram.new()
	broken.load_data({"id": "broken", "start": "a", "screens": {"a": {"options": [{"text": "x", "goto": "missing"}], "effects": [{"explode": true}]}}})
	c.equal(broken.errors.size(), 2, "unknown screen and unknown effect are reported")

	await _ui_case(c)


func _ui_case(c: OpeningCheck) -> void:
	var sandbox: Node3D = c.add((load(SANDBOX) as PackedScene).instantiate())
	await c.physics_frames(2)
	var player := sandbox.get_node(^"Player") as CharacterBody3D
	var terminal := sandbox.get_node(^"Stations/DoorStation/Terminal") as Terminal
	var gate := sandbox.get_node(^"Stations/DoorStation/AccessGate") as FacilityDoor
	GameState.set_section_power(&"sandbox_a", GameState.Power.OFF)
	terminal.open()
	c.is_true(terminal.screen == null, "unpowered terminal does not open")
	GameState.set_section_power(&"sandbox_a", GameState.Power.EMERGENCY)
	terminal.open()
	var screen := terminal.screen
	c.is_true(screen != null, "powered terminal opens")
	c.is_true(player.controls_locked, "player is locked while the terminal is open")
	screen.finish_typing()
	c.is_true(screen.body_label.text.contains("Основное питание секции: отсутствует."), "screen shows conditional lines")
	c.equal(screen.options_box.get_child_count(), 3, "main screen options")
	screen.choose(1)
	c.equal(screen.screen_id, "main", "protocol is locked without main power")
	GameState.set_section_power(&"sandbox_a", GameState.Power.MAIN)
	screen.show_screen("main")
	screen.finish_typing()
	screen.choose(1)
	c.equal(screen.screen_id, "protocol", "protocol starts with main power")
	c.equal(gate.lock_reason(), FacilityDoor.REASON_NO_ACCESS, "gate is still locked during the protocol")
	screen.finish_typing()
	c.is_true(GameState.has_access(&"caretaker"), "protocol grants caretaker access")
	c.equal(gate.lock_reason(), "", "gate unlocks after the protocol")
	c.equal(GameState.objective_id, &"sandbox_gate", "protocol sets the objective")
	await c.tree.create_timer(TerminalScreen.AUTO_NEXT_PAUSE + 0.2).timeout
	c.equal(screen.screen_id, "main_caretaker", "procedure returns to the caretaker main screen")
	screen.close()
	await c.tree.process_frame
	c.is_true(not player.controls_locked, "player is unlocked after closing")
	c.is_true(terminal.screen == null, "terminal forgets the closed screen")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
