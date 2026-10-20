extends Node3D

## Sandbox station for #235, direction «Верх» of part 2: two late-sector substations (east,
## west) repaired by procedures, each opens its short path (a door on the section it powers);
## the new control point server room starts when both feed it, its monitor closes the
## direction and shows the 3+4 regulation once (`part2/rule_3_4`, shared with post №2).
## The rest of the new control point stays closed: a jammed door behind debris, no power.
## Board above each machine shows its current step; the procedures do not drive the objective,
## so the part2 chain keeps «Восстановить системы».

const DONE_TEXT := {
	&"East": "НАПРЯЖЕНИЕ ПОДАНО\nкороткий путь открыт",
	&"West": "НАПРЯЖЕНИЕ ПОДАНО\nкороткий путь открыт",
	&"Servers": "СЕРВЕРНАЯ В РАБОТЕ\nмонитор доступен",
}

var _boards: Dictionary[RepairProcedure, Label3D] = {}


func _ready() -> void:
	for key: StringName in DONE_TEXT:
		var procedure := get_node("%sProcedure" % key) as RepairProcedure
		_boards[procedure] = get_node("%sBoard" % key) as Label3D
		procedure.step_changed.connect(func(_index: int, _hint: String) -> void: _refresh(procedure, key))
		procedure.completed.connect(func() -> void: _refresh(procedure, key))
	GameState.state_loaded.connect(_refresh_all)
	_refresh_all.call_deferred()


func _refresh_all() -> void:
	for key: StringName in DONE_TEXT:
		_refresh(get_node("%sProcedure" % key) as RepairProcedure, key)


func _refresh(procedure: RepairProcedure, key: StringName) -> void:
	var step := procedure.current_step
	if procedure.is_done() or step >= procedure.steps.size():
		_boards[procedure].text = DONE_TEXT[key]
	elif step >= 0:
		_boards[procedure].text = "%d/%d · %s" % [step + 1, procedure.steps.size(), procedure.steps[step].get("hint", "")]
