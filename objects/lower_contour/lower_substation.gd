extends Node3D

## Substation of the lower circuit on the technical level (#229): diagnose → prepare → energize →
## check (data/procedures/part2_lower_substation.json). The finished procedure gives main power
## to the passenger trunk line of the lower floor (section `lower_main`): the lab, post 2 and the
## short path stand on it. The board above the cabinet shows the current step.

const DONE_TEXT := "МАГИСТРАЛЬ ПОД НАПРЯЖЕНИЕМ\nизоляция в норме"

@onready var procedure: RepairProcedure = $Procedure
@onready var _board: Label3D = $Board


func _ready() -> void:
	procedure.step_changed.connect(func(_index: int, _hint: String) -> void: _refresh())
	procedure.completed.connect(_refresh)
	GameState.state_loaded.connect(_refresh)
	_refresh.call_deferred()


func _refresh() -> void:
	var step := procedure.current_step
	if procedure.is_done() or step >= procedure.steps.size():
		_board.text = DONE_TEXT
	elif step >= 0:
		_board.text = "%d/%d · %s" % [step + 1, procedure.steps.size(), procedure.steps[step].get("hint", "")]
