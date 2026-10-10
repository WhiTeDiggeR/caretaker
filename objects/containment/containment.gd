extends Node

## Containment modules (autoload `Containment`): instability 0–100 % of every prisoner's
## sleep, its stages, awakening and the catastrophe of a forbidden pair waking together.
## Runs in real time whatever scene is loaded, so the complex keeps living while the
## hero is inside a dream. Parameters: data/containment/modules.json.
## State is saved through GameState.set_system_data(&"containment", …).

signal instability_changed(module_id: StringName, value: float)
signal stage_changed(module_id: StringName, stage: int)
signal module_awakened(module_id: StringName)
signal catastrophe(module_ids: Array[StringName])

enum Stage { CALM, ALARM, UNREST, PRE_WAKE, AWAKE }

const DATA_PATH := "res://data/containment/modules.json"
const SYSTEM := &"containment"
const MAX_INSTABILITY := 100.0
const CATASTROPHE_FLAG := &"containment/catastrophe"
const MONITOR_HIDDEN_LINE := "Прочие модули — засекречено / нет связи."

var thresholds: Array = [25.0, 50.0, 75.0, 100.0]
var stage_names: Array = []
var catastrophe_pairs: Array = []
## Module parameters by id (label, start, growth_per_minute, active_when, visible_when...).
var modules: Dictionary[StringName, Dictionary] = {}

## String(id) -> {"value": float, "held": bool}; String keys survive the JSON round trip.
var _state: Dictionary = {}
var _stages: Dictionary[StringName, int] = {}


func _ready() -> void:
	load_config(_read(DATA_PATH))
	GameState.state_loaded.connect(_on_state_loaded)
	_on_state_loaded()
	TerminalProgram.text_providers[&"containment_monitor"] = monitor_lines


func load_config(data: Dictionary) -> void:
	thresholds = (data.get("stage_thresholds", thresholds) as Array).map(func(v: Variant) -> float: return float(v))
	stage_names = data.get("stage_names", [])
	catastrophe_pairs = data.get("catastrophe_pairs", [])
	modules.clear()
	var raw: Dictionary = data.get("modules", {})
	for id: String in raw:
		modules[StringName(id)] = raw[id]
	_on_state_loaded()


func _process(delta: float) -> void:
	tick(delta)


## Advances every active module by `seconds` of real time.
func tick(seconds: float) -> void:
	for id: StringName in modules:
		var config: Dictionary = modules[id]
		if is_held(id) or is_awake(id) or not StateRules.check(config.get("active_when", {})):
			continue
		var growth := float(config.get("growth_per_minute", 0.0)) * seconds / 60.0
		if growth > 0.0:
			_set_value(id, get_instability(id) + growth)


func get_instability(id: StringName) -> float:
	return float((_state.get(String(id), {}) as Dictionary).get("value", 0.0))


func get_stage(id: StringName) -> int:
	return stage_for(get_instability(id))


func stage_for(value: float) -> int:
	for index in thresholds.size():
		if value < float(thresholds[index]):
			return index
	return Stage.AWAKE


func stage_name(stage: int) -> String:
	return str(stage_names[stage]) if stage >= 0 and stage < stage_names.size() else ""


func is_awake(id: StringName) -> bool:
	return get_instability(id) >= MAX_INSTABILITY


## Raises instability (dream entry, dream death, failures). Returns the new value.
func add_instability(id: StringName, amount: float) -> float:
	if is_awake(id):
		return MAX_INSTABILITY
	_set_value(id, get_instability(id) + amount)
	return get_instability(id)


## Lowers instability (maintenance, a restored seal). An awakened prisoner stays awake.
func stabilize(id: StringName, amount: float) -> float:
	if is_awake(id):
		return MAX_INSTABILITY
	_set_value(id, get_instability(id) - amount)
	return get_instability(id)


## While held (chemical sleep) instability does not grow.
func set_held(id: StringName, held: bool) -> void:
	(_ensure(id))["held"] = held
	_save()


func is_held(id: StringName) -> bool:
	return bool((_state.get(String(id), {}) as Dictionary).get("held", false))


func is_visible_on_monitor(id: StringName) -> bool:
	return StateRules.check((modules.get(id, {}) as Dictionary).get("visible_when", {}))


## Lines for monitors and terminals: only visible modules, the rest hidden in one line so
## the number of cells is never revealed.
func monitor_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for id: StringName in modules:
		if not is_visible_on_monitor(id):
			continue
		var label := str(modules[id].get("label", id))
		lines.append("%s — %d %% — %s" % [label, roundi(get_instability(id)), stage_name(get_stage(id))])
	lines.append(MONITOR_HIDDEN_LINE)
	return lines


func _set_value(id: StringName, value: float) -> void:
	value = clampf(value, 0.0, MAX_INSTABILITY)
	var entry := _ensure(id)
	if is_equal_approx(float(entry["value"]), value):
		return
	entry["value"] = value
	_save()
	instability_changed.emit(id, value)
	_check_stage(id)


func _check_stage(id: StringName) -> void:
	var stage := get_stage(id)
	if _stages.get(id, stage) == stage and _stages.has(id):
		return
	_stages[id] = stage
	stage_changed.emit(id, stage)
	if stage == Stage.AWAKE:
		module_awakened.emit(id)
		_check_catastrophe()


func _check_catastrophe() -> void:
	if GameState.has_flag(CATASTROPHE_FLAG):
		return
	for pair: Array in catastrophe_pairs:
		var awake := pair.all(func(id: Variant) -> bool: return is_awake(StringName(str(id))))
		if awake:
			GameState.set_flag(CATASTROPHE_FLAG)
			var ids: Array[StringName] = []
			for id: Variant in pair:
				ids.append(StringName(str(id)))
			catastrophe.emit(ids)
			return


func _ensure(id: StringName) -> Dictionary:
	var key := String(id)
	if not _state.has(key):
		_state[key] = {"value": float((modules.get(id, {}) as Dictionary).get("start", 0.0)), "held": false}
	return _state[key]


func _save() -> void:
	GameState.set_system_data(SYSTEM, _state)


func _on_state_loaded() -> void:
	_state = GameState.get_system_data(SYSTEM).duplicate(true)
	for id: StringName in modules:
		_ensure(id)
	_stages.clear()
	for id: StringName in modules:
		_stages[id] = get_stage(id)
	_save()


static func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
