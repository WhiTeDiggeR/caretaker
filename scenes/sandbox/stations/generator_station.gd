extends Node3D

## Sandbox station for #104: gauges follow the valves and the start lever.

const PRESSURE_PER_VALVE := {&"valve_2": 0.45, &"valve_1": 0.35}
const RPM_WORKING := 0.8

@onready var _procedure: RepairProcedure = $Procedure
@onready var _pressure: RepairGauge = $PressureGauge
@onready var _rpm: RepairGauge = $RpmGauge
@onready var _lever: RepairControl = $StartLever


func _ready() -> void:
	GameState.flag_changed.connect(func(_flag: StringName, _value: Variant) -> void: _refresh())
	GameState.state_loaded.connect(_refresh)
	_lever.interactable.hold_progress_changed.connect(func(ratio: float) -> void: _rpm.value = ratio * RPM_WORKING)
	_lever.interactable.hold_cancelled.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var pressure := 0.0
	for control_id: StringName in PRESSURE_PER_VALVE:
		if GameState.has_flag(RepairControl.flag_for(control_id)):
			pressure += PRESSURE_PER_VALVE[control_id]
	_pressure.value = pressure
	_rpm.value = RPM_WORKING if _procedure.is_done() else 0.0
