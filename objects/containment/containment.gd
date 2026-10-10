extends Node

## Containment modules (autoload `Containment`): instability 0–100 % of every prisoner's
## sleep, its stages, awakening and the catastrophe of a forbidden pair waking together.
## Canon (docs/world/02-world-rules.md, #32): a fully stable sleep (0 %) never worsens by
## itself and has no forecast. External causes (damage, story events, Herobrine, failed
## dives — `add_instability`) disturb it; a disturbed sleep keeps worsening until the hero
## intervenes, and the damaged system shows an approximate, dynamically recalculated
## forecast of the awakening. Its expiry starts the emergency phase, not a defeat:
## and the emergency chemical protocol of modules 3–6 (canon, docs/world/02-world-rules.md):
## at the trigger threshold the module warns, seals and fills with sleeping gas; the prisoner
## is held in chemical sleep for a repair window. Reagent is limited: the module must be
## vented and recharged from the stock before it can fire again. Anyone inside without the
## chair falls asleep (defeat); a hero connected to the chair is woken by object 2 and gets
## a shorter window.
## Runs in real time whatever scene is loaded, so the complex keeps living while the
## hero is inside a dream. `time_scale` speeds it up for debugging only. Parameters: data/containment/modules.json.
## State is saved through GameState.set_system_data(&"containment", …).

signal instability_changed(module_id: StringName, value: float)
signal stage_changed(module_id: StringName, stage: int)
signal module_awakened(module_id: StringName)
signal catastrophe(module_ids: Array[StringName])
signal chemical_warning(module_id: StringName, seconds: float)
signal module_sealed(module_id: StringName)
signal repair_window_ended(module_id: StringName)
signal hero_gassed(module_id: StringName)
signal hero_woken(module_id: StringName)
signal reagent_changed

enum Stage { CALM, RESTLESS, ANXIOUS, PRE_WAKE, AWAKE }
enum Chemical { READY, WARNING, SEALED, SPENT }

const DATA_PATH := "res://data/containment/modules.json"
const SYSTEM := &"containment"
const MAX_INSTABILITY := 100.0
const CATASTROPHE_FLAG := &"containment/catastrophe"
const MONITOR_HIDDEN_LINE := "Прочие модули — засекречено / нет связи."
const STABLE_NAME := "СТАБИЛЬНЫЙ СОН"
const LINE_INDENT := "    "
const STABLE_LINE := "Сон стабилен. Угрозы пробуждения нет."
const OFFLINE_LINE := "Прогноза нет: система наблюдения не в сети."
const AWAKE_LINE := "ОБЪЕКТ БОДРСТВУЕТ. Содержание нарушено."
const FORECAST_ARMED := "Прогноз пробуждения: %s. Затем — химический протокол."
const FORECAST_PLAIN := "Прогноз пробуждения: %s."
const WARNING_LINE := "ВНИМАНИЕ: герметизация и подача газа через %s."
const SEALED_LINE := "Химический сон: окно ремонта %s. Нестабильность не растёт."
const SPENT_LINE := "Реагент израсходован: нужна вентиляция и перезарядка."
const VENTING_LINE := "Идёт вентиляция модуля."
const UNCHARGED_LINE := "Химический протокол не заряжен."
const GASSED_FLAG := &"containment/hero_gassed"
const STOCK_KEY := "_reagent_stock"
const CHEMICAL_NAMES: Array[String] = ["ПРОТОКОЛ ГОТОВ", "ВНИМАНИЕ: ГЕРМЕТИЗАЦИЯ", "ХИМИЧЕСКИЙ СОН", "РЕАГЕНТ ИЗРАСХОДОВАН"]
const REASON_NO_GAS := "ВЕНТИЛЯЦИЯ НЕ ТРЕБУЕТСЯ"
const REASON_VENTING := "ИДЁТ ВЕНТИЛЯЦИЯ"
const REASON_GAS := "СНАЧАЛА ВЕНТИЛЯЦИЯ"
const REASON_CHARGED := "ПРОТОКОЛ ЗАРЯЖЕН"
const REASON_NO_STOCK := "НЕТ ЗАПАСА РЕАГЕНТА"
const REASON_SEALED := "МОДУЛЬ ГЕРМЕТИЗИРОВАН"

var thresholds: Array = [25.0, 50.0, 75.0, 100.0]
var stage_names: Array = []
var catastrophe_pairs: Array = []
## Module parameters by id (label, start, growth_per_minute, active_when, visible_when...).
var modules: Dictionary[StringName, Dictionary] = {}
## Chemical protocol parameters: trigger_at, warning_seconds, repair_window_seconds,
## woken_window_factor, vent_seconds, initial_reagent_stock.
var chemical: Dictionary = {}
## Debug multiplier of the real time (sandbox); 1 in the game.
var time_scale := 1.0

## Modules whose chamber the hero is standing in (set by ModuleChamber areas).
var _hero_inside: Dictionary[StringName, bool] = {}

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
	chemical = data.get("chemical", {})
	modules.clear()
	var raw: Dictionary = data.get("modules", {})
	for id: String in raw:
		modules[StringName(id)] = raw[id]
	_on_state_loaded()


func _process(delta: float) -> void:
	tick(delta * time_scale)


## Advances every active module by `seconds` of real time.
func tick(seconds: float) -> void:
	for id: StringName in modules:
		_tick_chemical(id, seconds)
	for id: StringName in modules:
		var config: Dictionary = modules[id]
		if is_stable(id) or is_held(id) or is_awake(id) or not StateRules.check(config.get("active_when", {})):
			continue
		var growth := float(config.get("growth_per_minute", 0.0)) * seconds / 60.0
		if growth > 0.0:
			_set_value(id, get_instability(id) + growth)


func get_instability(id: StringName) -> float:
	return float((_state.get(String(id), {}) as Dictionary).get("value", 0.0))


## A fully stable sleep: no growth and no forecast.
func is_stable(id: StringName) -> bool:
	return get_instability(id) <= 0.0


## Seconds until the forecast expires (the chemical protocol fires, or the prisoner wakes
## when the protocol cannot fire), or -1 when there is no forecast.
func forecast_seconds(id: StringName) -> float:
	if is_stable(id) or is_held(id) or is_awake(id):
		return -1.0
	var rate := float((modules.get(id, {}) as Dictionary).get("growth_per_minute", 0.0)) / 60.0
	if rate <= 0.0 or not StateRules.check((modules.get(id, {}) as Dictionary).get("active_when", {})):
		return -1.0
	var limit := MAX_INSTABILITY
	if has_chemical_protocol(id) and chemical_phase(id) == Chemical.READY and is_charged(id) and not has_gas(id):
		limit = float(chemical.get("trigger_at", 95.0))
	return maxf(limit - get_instability(id), 0.0) / rate


## Approximate forecast for monitors: the damaged system does not give exact numbers.
func forecast_text(id: StringName) -> String:
	var seconds := forecast_seconds(id)
	if seconds < 0.0:
		return "прогноза нет"
	if seconds < 60.0:
		return "меньше минуты"
	var minutes := int(round(seconds / 60.0))
	if minutes < 60:
		return "около %d мин" % minutes
	return "около %d ч %d мин" % [minutes / 60, minutes % 60]


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
## the number of cells is never revealed. Each module gets a header with its stage and
## indented lines saying what happens next; exact percents are never shown.
func monitor_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for id: StringName in modules:
		if not is_visible_on_monitor(id):
			continue
		var label := str(modules[id].get("label", id))
		lines.append("%s — %s" % [label, STABLE_NAME if is_stable(id) else stage_name(get_stage(id))])
		for detail in _status_lines(id):
			lines.append(LINE_INDENT + detail)
	lines.append(MONITOR_HIDDEN_LINE)
	return lines


func _status_lines(id: StringName) -> PackedStringArray:
	if is_awake(id):
		return PackedStringArray([AWAKE_LINE])
	if is_stable(id):
		return PackedStringArray([STABLE_LINE])
	var protocol := has_chemical_protocol(id)
	var phase := chemical_phase(id) if protocol else Chemical.READY
	if phase == Chemical.WARNING:
		return PackedStringArray([WARNING_LINE % _clock(chemical_timer(id))])
	if phase == Chemical.SEALED:
		return PackedStringArray([SEALED_LINE % _clock(chemical_timer(id))])
	var lines := PackedStringArray()
	if forecast_seconds(id) < 0.0:
		lines.append(OFFLINE_LINE)
	elif protocol and is_charged(id) and not has_gas(id):
		lines.append(FORECAST_ARMED % forecast_text(id))
	else:
		lines.append(FORECAST_PLAIN % forecast_text(id))
	if protocol and not is_charged(id):
		if is_venting(id):
			lines.append(VENTING_LINE)
		elif has_gas(id):
			lines.append(SPENT_LINE)
		else:
			lines.append(UNCHARGED_LINE)
	return lines


# --- Chemical protocol -------------------------------------------------------

func has_chemical_protocol(id: StringName) -> bool:
	return bool((modules.get(id, {}) as Dictionary).get("chemical_protocol", false))


func chemical_phase(id: StringName) -> int:
	return int(_chem(id)["phase"])


## Seconds left of the warning or of the repair window; 0 otherwise.
func chemical_timer(id: StringName) -> float:
	return float(_chem(id)["timer"])


func has_gas(id: StringName) -> bool:
	return bool(_chem(id)["gas"])


func is_venting(id: StringName) -> bool:
	return float(_chem(id)["venting"]) > 0.0


func is_charged(id: StringName) -> bool:
	return bool(_chem(id)["charged"])


func reagent_stock() -> int:
	return int(_state.get(STOCK_KEY, int(chemical.get("initial_reagent_stock", 0))))


func add_reagent_stock(amount: int) -> void:
	_state[STOCK_KEY] = reagent_stock() + amount
	_save()
	reagent_changed.emit()


func set_hero_inside(id: StringName, inside: bool) -> void:
	_hero_inside[id] = inside


func is_hero_inside(id: StringName) -> bool:
	return _hero_inside.get(id, false)


func vent_lock_reason(id: StringName) -> String:
	if chemical_phase(id) == Chemical.SEALED or chemical_phase(id) == Chemical.WARNING:
		return REASON_SEALED
	if is_venting(id):
		return REASON_VENTING
	if not has_gas(id):
		return REASON_NO_GAS
	return ""


## Starts the ventilation of a sealed-off module after its repair window.
func vent(id: StringName) -> bool:
	if not vent_lock_reason(id).is_empty():
		return false
	_chem(id)["venting"] = float(chemical.get("vent_seconds", 30.0))
	_save()
	reagent_changed.emit()
	return true


func recharge_lock_reason(id: StringName) -> String:
	if chemical_phase(id) == Chemical.SEALED or chemical_phase(id) == Chemical.WARNING:
		return REASON_SEALED
	if is_charged(id):
		return REASON_CHARGED
	if has_gas(id) or is_venting(id):
		return REASON_GAS
	if reagent_stock() <= 0:
		return REASON_NO_STOCK
	return ""


## Loads one reagent charge from the stock into a vented module.
func recharge(id: StringName) -> bool:
	if not recharge_lock_reason(id).is_empty():
		return false
	_state[STOCK_KEY] = reagent_stock() - 1
	var chem := _chem(id)
	chem["charged"] = true
	chem["phase"] = Chemical.READY
	_save()
	reagent_changed.emit()
	return true


func _tick_chemical(id: StringName, seconds: float) -> void:
	if not has_chemical_protocol(id) or is_awake(id):
		return
	var chem := _chem(id)
	if float(chem["venting"]) > 0.0:
		chem["venting"] = maxf(float(chem["venting"]) - seconds, 0.0)
		if float(chem["venting"]) <= 0.0:
			chem["gas"] = false
			reagent_changed.emit()
	match int(chem["phase"]):
		Chemical.READY:
			if is_charged(id) and not has_gas(id) and get_instability(id) >= float(chemical.get("trigger_at", 95.0)):
				chem["phase"] = Chemical.WARNING
				chem["timer"] = float(chemical.get("warning_seconds", 10.0))
				chemical_warning.emit(id, chem["timer"])
		Chemical.WARNING:
			chem["timer"] = float(chem["timer"]) - seconds
			if float(chem["timer"]) <= 0.0:
				_seal(id)
		Chemical.SEALED:
			chem["timer"] = float(chem["timer"]) - seconds
			if float(chem["timer"]) <= 0.0:
				chem["timer"] = 0.0
				chem["phase"] = Chemical.SPENT
				set_held(id, false)
				repair_window_ended.emit(id)
	_save()


func _seal(id: StringName) -> void:
	var chem := _chem(id)
	chem["phase"] = Chemical.SEALED
	chem["charged"] = false
	chem["gas"] = true
	# Connected to the chair: object 2 reaches the hero through the dream.
	var woken := Dreams.in_dream and Dreams.module_id == id
	var window := float(chemical.get("repair_window_seconds", 180.0))
	if woken:
		window *= float(chemical.get("woken_window_factor", 0.4))
	# The timer is set before the signals so listeners see the real repair window.
	chem["timer"] = window
	set_held(id, true)
	module_sealed.emit(id)
	if woken:
		hero_woken.emit(id)
	elif is_hero_inside(id):
		GameState.set_flag(GASSED_FLAG)
		hero_gassed.emit(id)
	_save()


func _chem(id: StringName) -> Dictionary:
	var entry := _ensure(id)
	if not entry.has("chem"):
		entry["chem"] = {"phase": Chemical.READY, "timer": 0.0, "gas": false, "charged": has_chemical_protocol(id), "venting": 0.0}
	return entry["chem"]


func _set_value(id: StringName, value: float) -> void:
	value = clampf(value, 0.0, MAX_INSTABILITY)
	var entry := _ensure(id)
	# Exact comparison: an approximate one stops slow growth just below 100 % for ever.
	if float(entry["value"]) == value:
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


static func _clock(seconds: float) -> String:
	var total := maxi(ceili(seconds), 0)
	return "%02d:%02d" % [total / 60, total % 60]


static func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
