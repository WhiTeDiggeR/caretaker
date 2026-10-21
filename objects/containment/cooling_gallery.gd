extends Node3D

## Technical gallery of a module's cooling (#232): the gauge follows `Cooling.pressure`, the
## board above shows the procedure step or the cooling state, and the emergency repair is a
## RepairProcedure (valves, then the make-up pump) whose flag `proc/<id>` the Cooling autoload
## reads. The gallery tool of the storage shortens the holds (`Containment.service_seconds`).
## The procedure does not drive the objective: the first text of №2 only warns, the choice to
## believe it is the hero's.

const REFRESH_SECONDS := 0.25
const BOARD_LEAK := "ДАВЛЕНИЕ ПАДАЕТ · %s"
const BOARD_OVERHEAT := "ПЕРЕГРЕВ КАПСУЛЫ · %s"
const BOARD_DRY_TEST := "ОХЛАЖДЕНИЕ ВОССТАНОВЛЕНО\nпроверка герметизации…"
const BOARD_RESOLVED := "ОХЛАЖДЕНИЕ ВОССТАНОВЛЕНО\nгерметизация: норма"
const BOARD_NOMINAL := "ОХЛАЖДЕНИЕ: НОРМА"

@export var module_id: StringName = &"module_4"

@onready var _procedure := $Procedure as RepairProcedure
@onready var _gauge := $Gauge as RepairGauge
@onready var _board := $Board as Label3D

var _base_holds: Dictionary[RepairControl, float] = {}
var _elapsed := 0.0


func _ready() -> void:
	for control: RepairControl in _procedure.controls.values():
		_base_holds[control] = control.hold_time
	_procedure.step_changed.connect(func(_index: int, _hint: String) -> void: refresh())
	Cooling.phase_changed.connect(func(_id: StringName, _phase: int) -> void: refresh())
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_loaded.connect(func() -> void:
		_apply_service_time()
		refresh())
	_apply_service_time()
	refresh.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < REFRESH_SECONDS:
		return
	_elapsed = 0.0
	_gauge.value = Cooling.pressure(module_id)


func refresh() -> void:
	_gauge.value = Cooling.pressure(module_id)
	_board.text = board_text()


func board_text() -> String:
	var step := _procedure.current_step
	var hint := str(_procedure.steps[step].get("hint", "")) if step >= 0 and step < _procedure.steps.size() else ""
	match Cooling.get_phase(module_id):
		Cooling.Phase.LEAK:
			return BOARD_LEAK % hint
		Cooling.Phase.OVERHEAT:
			return BOARD_OVERHEAT % hint
		Cooling.Phase.DRY_TEST:
			return BOARD_DRY_TEST
		Cooling.Phase.RESOLVED:
			return BOARD_RESOLVED
	return BOARD_NOMINAL


func _on_flag_changed(flag: StringName, _value: Variant) -> void:
	if flag == StringName(str(Containment.service.get("tool_flag", ""))):
		_apply_service_time()


func _apply_service_time() -> void:
	for control: RepairControl in _base_holds:
		control.hold_time = Containment.service_seconds(_base_holds[control])
		control.interactable.hold_time = control.hold_time
