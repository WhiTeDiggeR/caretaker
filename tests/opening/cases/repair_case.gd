extends RefCounted

const PROCEDURES_DIR := "res://data/procedures"
const SANDBOX_STATION := "res://scenes/sandbox/stations/generator_station.tscn"

const DATA := {
	"id": "gen",
	"title": "Г-1",
	"steps": [
		{"id": "diagnose", "hint": "Диагностика", "done_when": {"flag": "diagnosed"}},
		{"id": "coolant", "hint": "Охлаждение", "sequence": ["valve_2", "valve_1"], "order_error": "порядок", "early_error": "рано-вентиль"},
		{"id": "protection", "hint": "Защита", "all_on": ["breaker_1", "breaker_2"]},
		{"id": "start", "hint": "Пуск", "all_on": ["lever"], "early_error": "рано-пуск"},
	],
	"completion_effects": [{"set_power": {"section": "gen_out", "power": "main"}}, {"set_flag": "gen_started"}],
}


func run(c: OpeningCheck) -> void:
	for file in DirAccess.get_files_at(PROCEDURES_DIR):
		if file.get_extension() == "json":
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROCEDURES_DIR.path_join(file)))
			c.equal(RepairProcedure.validate(parsed), PackedStringArray(), "%s is valid" % file)
	c.equal(RepairProcedure.validate({"id": "x", "steps": [{"id": "a"}]}).size(), 1, "step without a rule is reported")

	var root := Node3D.new()
	var valve_1 := _control(root, RepairControl.Kind.VALVE, &"valve_1")
	var valve_2 := _control(root, RepairControl.Kind.VALVE, &"valve_2")
	var breaker_1 := _control(root, RepairControl.Kind.BREAKER, &"breaker_1")
	var breaker_2 := _control(root, RepairControl.Kind.BREAKER, &"breaker_2")
	var lever := _control(root, RepairControl.Kind.LEVER, &"lever")
	var procedure := RepairProcedure.new()
	procedure.load_data(DATA)
	root.add_child(procedure)
	c.add(root)
	var messages: Array[String] = []
	procedure.message.connect(func(text: String) -> void: messages.append(text))
	var completions := [0]
	procedure.completed.connect(func() -> void: completions[0] += 1)

	c.equal(procedure.errors, PackedStringArray(), "procedure finds its controls")
	c.equal(procedure.current_step, 0, "starts at the first step")
	c.equal(GameState.objective_text, "Диагностика", "first hint is the objective")
	c.equal(valve_1.interactable.mode, Interactable.Mode.HOLD, "valves are turned by holding")
	c.equal(breaker_1.interactable.mode, Interactable.Mode.PRESS, "breakers are pressed")

	valve_2.interactable.trigger()
	await c.tree.process_frame
	c.is_true(not valve_2.is_on(), "a control of a later step springs back")
	c.equal(messages.back(), "рано-вентиль", "early use explains itself")

	GameState.set_flag(&"diagnosed")
	c.equal(procedure.current_step, 1, "condition step completes")
	c.equal(GameState.objective_text, "Охлаждение", "objective follows the step")
	valve_1.set_on(true)
	await c.tree.process_frame
	c.is_true(not valve_1.is_on(), "wrong order springs back")
	c.equal(messages.back(), "порядок", "wrong order explains itself")
	valve_2.set_on(true)
	c.equal(procedure.current_step, 1, "sequence needs every valve")
	valve_1.set_on(true)
	c.equal(procedure.current_step, 2, "sequence completes in order")
	c.is_true(not valve_1.interactable.is_available() and valve_1.interactable.get_prompt_text() == "ГОТОВО", "completed controls are fixed")

	lever.set_on(true)
	await c.tree.process_frame
	c.is_true(not lever.is_on() and messages.back() == "рано-пуск", "start lever is blocked until protection is reset")
	breaker_2.set_on(true)
	breaker_1.set_on(true)
	c.equal(procedure.current_step, 3, "all-on step completes in any order")
	lever.interactable.trigger()
	c.is_true(procedure.is_done(), "procedure is done")
	c.equal(completions[0], 1, "completion fires once")
	c.equal(GameState.get_section_power(&"gen_out"), GameState.Power.MAIN, "completion effects applied")
	c.is_true(not lever.interactable.is_available(), "last control is fixed")

	var saved := GameState.to_dict()
	GameState.reset()
	c.is_true(not procedure.is_done() and valve_1.interactable.is_available(), "reset clears the progress")
	GameState.from_dict(saved)
	c.is_true(procedure.is_done(), "progress is restored from a save")
	c.is_true(not valve_1.interactable.is_available() and valve_1.is_on(), "controls are restored and fixed")
	c.equal(completions[0], 1, "loading does not repeat the completion")

	# Sandbox station is wired.
	GameState.reset()
	var station: Node3D = c.add((load(SANDBOX_STATION) as PackedScene).instantiate())
	var station_procedure := station.get_node(^"Procedure") as RepairProcedure
	c.equal(station_procedure.errors, PackedStringArray(), "sandbox generator procedure is wired")
	c.equal(station_procedure.controls.size(), 5, "sandbox generator has five controls")
	(station.get_node(^"Valve2") as RepairControl).set_on(true)
	await c.tree.process_frame
	c.near((station.get_node(^"PressureGauge") as RepairGauge).value, 0.0, 0.001, "early valve leaves the pressure at zero")


func _control(root: Node3D, kind: RepairControl.Kind, id: StringName) -> RepairControl:
	var control := RepairControl.new()
	control.kind = kind
	control.control_id = id
	root.add_child(control)
	return control
