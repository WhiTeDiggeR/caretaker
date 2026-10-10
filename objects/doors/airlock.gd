class_name Airlock
extends Node3D

## Two interlocked doors and a cycle panel between them. The chamber is equalised with one
## side at a time (`synced_door`): only that door opens at once. Reaching the other side
## always takes a cycle — close the open door, ventilate, open the other — even when both
## doors are already closed. Door panels and the inner panel both go through the airlock;
## a door never opens around it and never while the other one is open.

signal cycle_started
signal cycle_finished

const PROMPT := "ЗАПУСТИТЬ ШЛЮЗОВОЙ ЦИКЛ"

@export var door_a: FacilityDoor
@export var door_b: FacilityDoor
@export var cycle_time := 4.0
@export var section: StringName = &""
## Side the chamber is equalised with at start: true — door A, false — door B.
@export var starts_synced_with_a := true

var cycling := false
## The door whose side the chamber was last ventilated for.
var synced_door: FacilityDoor

var _panel: Interactable


func _ready() -> void:
	add_to_group(&"persist")
	door_a.section = section
	door_b.section = section
	door_a.interlock_partner = door_b
	door_b.interlock_partner = door_a
	door_a.operator = request_door
	door_b.operator = request_door
	synced_door = door_a if starts_synced_with_a else door_b
	if door_b.is_open() and not door_a.is_open():
		synced_door = door_b
	_panel = $CyclePanel/Interactable
	_panel.prompt = PROMPT
	_panel.interacted.connect(start_cycle)
	GameState.section_power_changed.connect(func(_s: StringName, _p: int) -> void: _refresh())
	door_a.refresh()
	door_b.refresh()
	_refresh()


func save_state() -> Dictionary:
	return {"synced_with_a": synced_door == door_a}


func load_state(data: Dictionary) -> void:
	synced_door = door_a if bool(data.get("synced_with_a", true)) else door_b
	cycling = false
	_set_cycle_lock(false)


func lock_reason() -> String:
	if not GameState.is_section_powered(section):
		return FacilityDoor.REASON_NO_POWER
	if cycling:
		return FacilityDoor.REASON_CYCLE
	return ""


func start_cycle() -> bool:
	if not lock_reason().is_empty():
		return false
	_run_cycle(synced_door, synced_door.interlock_partner)
	return true


## Called by a door panel: closes the door when it is open; opens it at once when the
## chamber is equalised with its side, otherwise through a full cycle.
func request_door(door: FacilityDoor) -> bool:
	if not lock_reason().is_empty():
		return false
	if door.is_open():
		door.force(false)
		return true
	if not door.is_closed():
		return false
	if door == synced_door:
		door.force(true)
	else:
		_run_cycle(door.interlock_partner, door)
	return true


func _run_cycle(from: FacilityDoor, to: FacilityDoor) -> void:
	cycling = true
	_set_cycle_lock(true)
	cycle_started.emit()
	if not from.is_closed():
		from.force(false)
		await from.closed
	await get_tree().create_timer(cycle_time).timeout
	synced_door = to
	to.force(true)
	await to.opened
	cycling = false
	_set_cycle_lock(false)
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
