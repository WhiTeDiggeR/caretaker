extends Node

## Objective chains (autoload `Objectives`): data/objectives/*.json describe ordered steps,
## each with the on-screen text and a `done_when` condition (StateRules). The active step is
## mirrored into GameState's objective; when its condition holds the next step starts by
## itself. A chain with `next` hands over to that chain when it is done (opening → part2).
## Progress is saved with the game (GameState system data). Format: README.md there.

signal step_started(chain_id: StringName, step_id: StringName)
signal chain_completed(chain_id: StringName)

const DATA_DIR := "res://data/objectives"
const SYSTEM := &"objectives"

## chain id -> {"final_text": String, "next": String, "steps": [{"id", "text", "done_when"}]}
var chains: Dictionary[StringName, Dictionary] = {}

var _chain: StringName = &""
var _index := 0
var _evaluate_queued := false


func _ready() -> void:
	load_all()
	GameState.flag_changed.connect(func(_flag: StringName, _value: Variant) -> void: _queue_evaluate())
	GameState.access_changed.connect(func(_access: StringName, _granted: bool) -> void: _queue_evaluate())
	GameState.section_power_changed.connect(func(_section: StringName, _power: int) -> void: _queue_evaluate())
	GameState.state_loaded.connect(_on_state_loaded)
	_on_state_loaded()


func load_all() -> void:
	chains.clear()
	for file in DirAccess.get_files_at(DATA_DIR):
		if file.get_extension() != "json":
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR.path_join(file)))
		if parsed is Dictionary:
			add_chains((parsed as Dictionary).get("chains", {}))


func add_chains(raw: Dictionary) -> void:
	for id: String in raw:
		chains[StringName(id)] = raw[id]


## Problems in the loaded chains (empty when they are valid).
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for id: StringName in chains:
		var steps: Array = chains[id].get("steps", [])
		if steps.is_empty():
			errors.append("%s: no steps" % id)
		var seen := {}
		for step: Dictionary in steps:
			var step_id := str(step.get("id", ""))
			if step_id.is_empty() or str(step.get("text", "")).is_empty() or not step.has("done_when"):
				errors.append("%s: every step needs id, text and done_when" % id)
			if seen.has(step_id):
				errors.append("%s: duplicate step %s" % [id, step_id])
			seen[step_id] = true
		var next := StringName(str(chains[id].get("next", "")))
		if next != &"" and not chains.has(next):
			errors.append("%s: unknown next chain %s" % [id, next])
	return errors


## Starts a chain from its first step (replaces the active one).
func start(chain_id: StringName) -> void:
	if not chains.has(chain_id):
		push_warning("Objectives: unknown chain %s" % chain_id)
		return
	_chain = chain_id
	_index = 0
	_save()
	_announce()
	_evaluate()


func active_chain() -> StringName:
	return _chain


func current_step() -> Dictionary:
	var steps := _steps()
	return steps[_index] if _index < steps.size() else {}


func is_completed() -> bool:
	return _chain != &"" and _index >= _steps().size()


## Texts of the finished steps of the active chain, oldest first.
func completed_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	var steps := _steps()
	for index in mini(_index, steps.size()):
		texts.append(str(steps[index].get("text", "")))
	return texts


## Checks the active step now (signals evaluate on the next frame).
func evaluate() -> void:
	_evaluate()


func _steps() -> Array:
	return (chains.get(_chain, {}) as Dictionary).get("steps", [])


func _queue_evaluate() -> void:
	if _evaluate_queued or _chain == &"":
		return
	_evaluate_queued = true
	_evaluate.call_deferred()


func _evaluate() -> void:
	_evaluate_queued = false
	if _chain == &"":
		return
	var advanced := false
	var steps := _steps()
	while _index < steps.size() and StateRules.check(steps[_index].get("done_when", {})):
		_index += 1
		advanced = true
	if advanced:
		_save()
		_announce()
		if _index >= steps.size():
			chain_completed.emit(_chain)
	# Also covers saves made when a finished chain had no `next` yet.
	var next := StringName(str(chains.get(_chain, {}).get("next", "")))
	if is_completed() and chains.has(next):
		start(next)


func _announce() -> void:
	var step := current_step()
	if step.is_empty():
		var final_text := str(chains.get(_chain, {}).get("final_text", ""))
		GameState.set_objective(StringName("%s/done" % _chain) if not final_text.is_empty() else &"", final_text)
		return
	GameState.set_objective(StringName(str(step["id"])), str(step["text"]))
	step_started.emit(_chain, StringName(str(step["id"])))


func _save() -> void:
	GameState.set_system_data(SYSTEM, {"chain": String(_chain), "index": _index})


func _on_state_loaded() -> void:
	var data := GameState.get_system_data(SYSTEM)
	_chain = StringName(str(data.get("chain", "")))
	_index = int(data.get("index", 0))
	if not chains.has(_chain):
		_chain = &""
		_index = 0
	_queue_evaluate()
