class_name RepairProcedure
extends Node

## Multi-step repair driven by RepairControls (data/procedures/README.md).
## Progress is derived from GameState flags, so it survives saves. Controls of later steps
## spring back with a message when used too early; a sequence step rejects a wrong order.
## Completed steps fix their controls; the last step applies `completion_effects` once.

signal step_changed(step_index: int, hint: String)
signal step_completed(step_id: String)
signal message(text: String)
signal completed

const DONE_PREFIX := "proc/"
const DEFAULT_EARLY_ERROR := "Сейчас это ничего не даст."
const DEFAULT_ORDER_ERROR := "Порядок нарушен. Элемент возвращён в исходное положение."
const DEFAULT_FIXED_PROMPT := "ГОТОВО"
const MESSAGE_GROUP := &"message_display"

@export_file("*.json") var procedure_path := ""
## Where RepairControls are searched for (default: the parent).
@export var controls_root: Node
@export var drive_objective := true

var id := ""
var title := ""
var steps: Array = []
var completion_effects: Array = []
var errors := PackedStringArray()
var controls: Dictionary[StringName, RepairControl] = {}
var current_step := -1


func _ready() -> void:
	if not procedure_path.is_empty():
		load_data(_read(procedure_path))
	if controls_root == null:
		controls_root = get_parent()
	for node in controls_root.find_children("*", "RepairControl", true, false):
		var control := node as RepairControl
		controls[control.control_id] = control
	for step: Dictionary in steps:
		for control_id: String in _step_controls(step):
			if not controls.has(StringName(control_id)):
				errors.append("%s: control '%s' is missing" % [id, control_id])
	for error in errors:
		push_error("RepairProcedure: " + error)
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_loaded.connect(_update)
	_update()


func load_data(data: Dictionary) -> void:
	id = str(data.get("id", ""))
	title = str(data.get("title", ""))
	steps = data.get("steps", [])
	completion_effects = data.get("completion_effects", [])
	errors.append_array(validate(data))


static func validate(data: Dictionary) -> PackedStringArray:
	var found := PackedStringArray()
	var where := str(data.get("id", "?"))
	if where == "?" or where.is_empty():
		found.append("procedure has no id")
	if (data.get("steps", []) as Array).is_empty():
		found.append("%s: no steps" % where)
	for step: Dictionary in data.get("steps", []):
		var kinds := ["done_when", "sequence", "all_on"].filter(func(key: String) -> bool: return step.has(key))
		if kinds.size() != 1:
			found.append("%s/%s: a step needs exactly one of done_when, sequence, all_on" % [where, step.get("id", "?")])
	found.append_array(StateRules.validate_effects(data.get("completion_effects", []), where))
	return found


func is_done() -> bool:
	return GameState.has_flag(StringName(DONE_PREFIX + id))


func step_satisfied(index: int) -> bool:
	var step: Dictionary = steps[index]
	if step.has("done_when"):
		return StateRules.check(step["done_when"])
	for control_id: String in _step_controls(step):
		if not GameState.has_flag(RepairControl.flag_for(StringName(control_id))):
			return false
	return true


func _first_open_step() -> int:
	for index in steps.size():
		if not step_satisfied(index):
			return index
	return steps.size()


func _update() -> void:
	var step := _first_open_step()
	for index in steps.size():
		for control_id: String in _step_controls(steps[index]):
			var control: RepairControl = controls.get(StringName(control_id))
			if control:
				if control.fixed_prompt.is_empty():
					control.fixed_prompt = DEFAULT_FIXED_PROMPT
				control.set_fixed(index < step)
	if step != current_step:
		for index in range(maxi(current_step, 0), mini(step, steps.size())):
			if current_step >= 0:
				step_completed.emit(str(steps[index].get("id", "")))
		current_step = step
		if step < steps.size():
			var hint := str(steps[step].get("hint", ""))
			if drive_objective:
				GameState.set_objective(StringName(id), hint)
			step_changed.emit(step, hint)
	if step >= steps.size() and not is_done():
		GameState.set_flag(StringName(DONE_PREFIX + id))
		StateRules.apply(completion_effects)
		completed.emit()


func _on_flag_changed(flag: StringName, value: Variant) -> void:
	if not String(flag).begins_with(RepairControl.FLAG_PREFIX):
		_update()
		return
	var control_id := String(flag).trim_prefix(RepairControl.FLAG_PREFIX)
	var owner_step := _owner_step(control_id)
	if owner_step < 0:
		return
	if value == true and owner_step > current_step:
		_reject(control_id, str(steps[owner_step].get("early_error", DEFAULT_EARLY_ERROR)))
		return
	if value == true and owner_step == current_step and steps[owner_step].has("sequence"):
		var sequence: Array = steps[owner_step]["sequence"]
		for previous: String in sequence.slice(0, sequence.find(control_id)):
			if not GameState.has_flag(RepairControl.flag_for(StringName(previous))):
				_reject(control_id, str(steps[owner_step].get("order_error", DEFAULT_ORDER_ERROR)))
				return
	_update()


func _reject(control_id: String, text: String) -> void:
	_say(text)
	(func() -> void: GameState.clear_flag(RepairControl.flag_for(StringName(control_id)))).call_deferred()


func _say(text: String) -> void:
	message.emit(text)
	if is_inside_tree():
		get_tree().call_group(MESSAGE_GROUP, "show_message", title, text)


func _owner_step(control_id: String) -> int:
	for index in steps.size():
		if control_id in _step_controls(steps[index]):
			return index
	return -1


static func _step_controls(step: Dictionary) -> Array:
	return step.get("sequence", step.get("all_on", []))


static func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
