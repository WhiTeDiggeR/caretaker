class_name EventSequence
extends Node

## Scripted event (#133): an ordered list of steps from data/events/*.json, run by an
## EventTrigger, another sequence or a direct `play()` call. Steps reach scene objects
## through `targets` (name → node path), resolved once in `_ready()`; global systems are
## used directly. A finished event sets `event/done/<id>` and, unless `repeatable`, never
## runs again — also after loading a save. Loading a save cancels a running event.
## Format and examples: data/events/README.md.

signal started(event_id: StringName)
signal finished(event_id: StringName)
signal step_started(event_id: StringName, index: int)

const DONE_PREFIX := "event/done/"
const GROUP := &"event_sequences"
const MESSAGE_GROUP := &"message_display"
const SHAKE_STEP := 0.03
const FLICKER_STEP := 0.09
const STEP_KEYS: Array[String] = ["wait", "power", "door", "sound", "message", "hint", "objective", "effects", "shake", "run"]
const DOOR_ACTIONS: Array[String] = ["open", "close", "lock", "unlock"]

@export var event_id: StringName = &""
## Scene objects the steps name in `target`: doors, sound positions.
@export var targets: Dictionary[StringName, NodePath] = {}
## May run again after finishing (no done flag check).
@export var repeatable := false

var running := false
var steps: Array = []

var _nodes: Dictionary[StringName, Node] = {}
var _run_token := 0


func _ready() -> void:
	add_to_group(GROUP)
	# Steps set from code before entering the tree take precedence over the catalogue.
	if steps.is_empty():
		steps = EventLibrary.steps(event_id)
	if steps.is_empty():
		push_error("EventSequence %s: no event '%s' in data/events" % [get_path(), event_id])
	for key: StringName in targets:
		var node := get_node_or_null(targets[key])
		if node == null:
			push_error("EventSequence %s: target '%s' not found" % [event_id, key])
		_nodes[key] = node
	GameState.state_loaded.connect(cancel)


static func done_flag(id: StringName) -> StringName:
	return StringName(DONE_PREFIX + String(id))


func is_done() -> bool:
	return GameState.has_flag(done_flag(event_id))


func can_play() -> bool:
	return not running and (repeatable or not is_done())


## Starts the event. Returns false when it is running or already done.
func play() -> bool:
	if not can_play():
		return false
	_run()
	return true


## Stops a running event where it is (loading a save, a scene leaving).
func cancel() -> void:
	_run_token += 1
	running = false


func _run() -> void:
	_run_token += 1
	var token := _run_token
	running = true
	started.emit(event_id)
	for index in steps.size():
		step_started.emit(event_id, index)
		await _step(steps[index] as Dictionary)
		if token != _run_token or not is_inside_tree():
			return
	running = false
	GameState.set_flag(done_flag(event_id))
	finished.emit(event_id)


func _step(step: Dictionary) -> void:
	if step.has("wait"):
		await get_tree().create_timer(float(step["wait"])).timeout
	elif step.has("power"):
		await _power(step["power"] as Dictionary)
	elif step.has("door"):
		_door(step["door"] as Dictionary)
	elif step.has("sound"):
		_sound(step)
	elif step.has("message"):
		var message: Dictionary = step["message"]
		get_tree().call_group(MESSAGE_GROUP, "show_message", str(message.get("title", "")), str(message.get("text", "")))
	elif step.has("hint"):
		Hints.request(StringName(str(step["hint"])))
	elif step.has("objective"):
		Objectives.start(StringName(str(step["objective"])))
	elif step.has("effects"):
		StateRules.apply(step["effects"])
	elif step.has("shake"):
		await _shake(step["shake"] as Dictionary)
	elif step.has("run"):
		var other := find_event(get_tree(), StringName(str(step["run"])))
		if other == null:
			push_error("EventSequence %s: no sequence '%s' in the scene" % [event_id, step["run"]])
		elif bool(step.get("await", false)):
			if other.play():
				await other.finished
		else:
			other.play()


## Section power with an optional flicker before the final state (lights follow the power).
func _power(power: Dictionary) -> void:
	var section := StringName(str(power["section"]))
	var target := StateRules.POWER_LEVELS.find(str(power["power"]))
	var before := GameState.get_section_power(section)
	var token := _run_token
	for index in int(power.get("flicker", 0)) * 2:
		GameState.set_section_power(section, target if index % 2 == 0 else before)
		await get_tree().create_timer(FLICKER_STEP).timeout
		if token != _run_token:
			return
	GameState.set_section_power(section, target)


func _door(door: Dictionary) -> void:
	var node := _nodes.get(StringName(str(door.get("target", "")))) as FacilityDoor
	if node == null:
		push_error("EventSequence %s: door target '%s' is not a FacilityDoor" % [event_id, door.get("target")])
		return
	match str(door.get("action", "")):
		"open":
			node.force(true)
		"close":
			node.force(false)
		"lock":
			node.emergency_lock = true
		"unlock":
			node.emergency_lock = false


## Plays a catalogue sound (Sfx, #126) when that system is present; silent otherwise.
func _sound(step: Dictionary) -> void:
	var sfx := get_tree().root.get_node_or_null(^"Sfx")
	if sfx == null:
		return
	var at := _nodes.get(StringName(str(step.get("at", "")))) as Node3D
	sfx.call("play", StringName(str(step["sound"])), at)


func _shake(shake: Dictionary) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var strength := float(shake.get("strength", 0.05))
	var steps_left := int(float(shake.get("seconds", 0.6)) / SHAKE_STEP)
	for index in steps_left:
		var fade := 1.0 - float(index) / maxf(steps_left, 1)
		camera.h_offset = randf_range(-strength, strength) * fade
		camera.v_offset = randf_range(-strength, strength) * fade
		await get_tree().create_timer(SHAKE_STEP).timeout
		if not is_instance_valid(camera):
			return
	camera.h_offset = 0.0
	camera.v_offset = 0.0


static func find_event(tree: SceneTree, id: StringName) -> EventSequence:
	for node in tree.get_nodes_in_group(GROUP):
		if (node as EventSequence).event_id == id:
			return node
	return null
