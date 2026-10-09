class_name Airlock
extends Node3D

## Two interlocked doors and a cycle panel between them. A door opens only while the other
## is closed; the cycle closes the open door, waits for the ventilation and opens the other.

signal cycle_started
signal cycle_finished

const PROMPT := "ЗАПУСТИТЬ ШЛЮЗОВОЙ ЦИКЛ"

@export var door_a: FacilityDoor
@export var door_b: FacilityDoor
@export var cycle_time := 4.0
@export var section: StringName = &""

var cycling := false

var _panel: Interactable
var _last_opened: FacilityDoor


func _ready() -> void:
	door_a.section = section
	door_b.section = section
	door_a.interlock_partner = door_b
	door_b.interlock_partner = door_a
	door_a.opened.connect(func() -> void: _last_opened = door_a)
	door_b.opened.connect(func() -> void: _last_opened = door_b)
	_panel = $CyclePanel/Interactable
	_panel.prompt = PROMPT
	_panel.interacted.connect(start_cycle)
	GameState.section_power_changed.connect(func(_s: StringName, _p: int) -> void: _refresh())
	door_a.refresh()
	door_b.refresh()
	_refresh()


func lock_reason() -> String:
	if not GameState.is_section_powered(section):
		return FacilityDoor.REASON_NO_POWER
	if cycling:
		return FacilityDoor.REASON_CYCLE
	return ""


func start_cycle() -> bool:
	if not lock_reason().is_empty():
		return false
	var from := door_a if not door_a.is_closed() else door_b
	if from.is_closed():
		from = door_a if _last_opened == door_b or _last_opened == null else door_b
	var to := door_b if from == door_a else door_a
	_run_cycle(from, to)
	return true


func _run_cycle(from: FacilityDoor, to: FacilityDoor) -> void:
	cycling = true
	_set_cycle_lock(true)
	cycle_started.emit()
	if not from.is_closed():
		from.force(false)
		await from.closed
	await get_tree().create_timer(cycle_time).timeout
	to.force(true)
	await to.opened
	_set_cycle_lock(false)
	cycling = false
	cycle_finished.emit()


func _set_cycle_lock(locked: bool) -> void:
	door_a.cycle_lock = locked
	door_b.cycle_lock = locked
	door_a.refresh()
	door_b.refresh()
	_refresh()


func _refresh() -> void:
	var reason := lock_reason()
	_panel.available = reason.is_empty()
	_panel.unavailable_prompt = reason
