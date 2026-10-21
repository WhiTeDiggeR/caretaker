extends Node

## Cooling of containment modules (autoload `Cooling`, #232): the first external service of a
## dream besides the dives (docs/game_design/08-part2.md, П4–П5). The first text of №2
## (`fails_when`) starts a leak: the pressure of the module's cooling falls for `grace_seconds`
## and nothing else happens yet. Repaired in time — the hero believed №2: no crisis, only the
## seal cracked by the heat (a small `seal_crack_instability`, a long forecast); №2 trust grows.
## Not repaired — the pressure is critical: the capsule overheats, the forecast appears at once
## (`overheat_instability`) and runs fast (`overheat_growth_per_minute` on top of the module's
## own growth) until the repair, so its expiry fires the chemical protocol with its repair
## window (Containment). Either way the repair ends with the training dry test of the protocol
## («Проверка герметизации… норма»), which spends no reagent, and resolves the crisis.
## The repair itself is a RepairProcedure in the module's technical gallery (`repair_flag`).
## Runs in real time whatever scene is loaded (like Containment, same `time_scale`).
## Parameters: data/containment/modules.json → `cooling`. State is saved through
## GameState.set_system_data(&"cooling", …).

signal phase_changed(module_id: StringName, phase: int)

enum Phase { NOMINAL, LEAK, OVERHEAT, DRY_TEST, RESOLVED }

const SYSTEM := &"cooling"
const MESSAGE_GROUP := &"message_display"
const NOMINAL_PRESSURE := 1.0
const DEFAULT_CRITICAL_PRESSURE := 0.3
const COOLING_TITLE := "%s · ОХЛАЖДЕНИЕ"
const DRY_TEST_TITLE := "ХИМИЧЕСКИЙ ПРОТОКОЛ · %s"
const OVERHEAT_TEXT := "Давление контура охлаждения критическое. Перегрев капсулы: сон теряет стабильность. Ремонт — техгалерея модуля."
const DRY_TEST_START_TEXT := "Охлаждение восстановлено. Учебная проверка протокола.\nПроверка герметизации…"
const DRY_TEST_DONE_TEXT := "Проверка герметизации… норма.\nРеагент не расходуется."
const LINE_NOMINAL := "Охлаждение: норма."
const LINE_LEAK := "Давление охлаждения: %d %% · ПАДАЕТ."
const LINE_LEAK_NOTE := "Перегрева нет."
const LINE_OVERHEAT := "Давление охлаждения: КРИТИЧЕСКОЕ. Перегрев капсулы."
const LINE_OVERHEAT_NOTE := "Ремонт: техгалерея модуля."
const LINE_DRY_TEST := "Охлаждение восстановлено. Проверка герметизации…"
const LINE_RESOLVED := "Охлаждение: восстановлено, аварийная подпитка."
const LINE_DRY_TEST_DONE := "Проверка герметизации: норма."

## Cooling parameters by module id (data/containment/modules.json → `cooling`).
var modules: Dictionary[StringName, Dictionary] = {}

## String(id) -> {"phase": int, "timer": float}; String keys survive the JSON round trip.
var _state: Dictionary = {}


func _ready() -> void:
	load_config(_read(Containment.DATA_PATH))
	GameState.state_loaded.connect(_on_state_loaded)
	GameState.flag_changed.connect(_on_flag_changed)
	Containment.module_sealed.connect(_on_module_sealed)
	TerminalProgram.text_providers[&"cooling_status"] = status_lines
	_on_state_loaded()


func load_config(data: Dictionary) -> void:
	modules.clear()
	var raw: Dictionary = data.get("cooling", {})
	for id: String in raw:
		modules[StringName(id)] = raw[id]
	_on_state_loaded()


func _process(delta: float) -> void:
	tick(delta * Containment.time_scale)


## Advances every leaking cooling and every dry test by `seconds` of real time.
func tick(seconds: float) -> void:
	for id: StringName in modules:
		var phase := get_phase(id)
		if phase != Phase.LEAK and phase != Phase.DRY_TEST:
			continue
		var entry := _entry(id)
		entry["timer"] = maxf(float(entry["timer"]) - seconds, 0.0)
		_save()
		if float(entry["timer"]) > 0.0:
			continue
		if phase == Phase.LEAK:
			_overheat(id)
		else:
			_resolve(id)


func get_phase(id: StringName) -> int:
	return int(_entry(id)["phase"])


## Seconds left of the leak before overheating (or of the dry test); 0 otherwise.
func get_timer(id: StringName) -> float:
	return float(_entry(id)["timer"])


## Cooling pressure 0..1 for gauges: nominal, falling during the leak, critical when overheating.
func pressure(id: StringName) -> float:
	var config: Dictionary = modules.get(id, {})
	var critical := float(config.get("critical_pressure", DEFAULT_CRITICAL_PRESSURE))
	match get_phase(id):
		Phase.LEAK:
			var grace := maxf(float(config.get("grace_seconds", 1.0)), 0.001)
			return lerpf(critical, NOMINAL_PRESSURE, get_timer(id) / grace)
		Phase.OVERHEAT:
			return critical
	return NOMINAL_PRESSURE


## Lines for the module post (terminal provider `{cooling_status}`).
func status_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for id: StringName in modules:
		match get_phase(id):
			Phase.NOMINAL:
				lines.append(LINE_NOMINAL)
			Phase.LEAK:
				lines.append(LINE_LEAK % roundi(pressure(id) * 100.0))
				lines.append(LINE_LEAK_NOTE)
			Phase.OVERHEAT:
				lines.append(LINE_OVERHEAT)
				lines.append(LINE_OVERHEAT_NOTE)
			Phase.DRY_TEST:
				lines.append(LINE_DRY_TEST)
			Phase.RESOLVED:
				lines.append(LINE_RESOLVED)
				lines.append(LINE_DRY_TEST_DONE)
	return lines


func _flag(id: StringName, key: String) -> StringName:
	return StringName(str((modules[id].get("flags", {}) as Dictionary).get(key, "")))


func _set_flag_of(id: StringName, key: String, value: Variant = true) -> void:
	var flag := _flag(id, key)
	if not flag.is_empty():
		GameState.set_flag(flag, value)


func _set_phase(id: StringName, phase: int, timer: float = 0.0) -> void:
	var entry := _entry(id)
	entry["phase"] = phase
	entry["timer"] = timer
	_apply_growth(id)
	_save()
	phase_changed.emit(id, phase)


func _start_leak(id: StringName) -> void:
	_set_phase(id, Phase.LEAK, float(modules[id].get("grace_seconds", 0.0)))
	_set_flag_of(id, "leak")


func _overheat(id: StringName) -> void:
	_set_phase(id, Phase.OVERHEAT)
	_set_flag_of(id, "overheat")
	Containment.add_instability(id, float(modules[id].get("overheat_instability", 0.0)))
	Sfx.play(&"alarm_stage")
	_say(COOLING_TITLE % _label(id), OVERHEAT_TEXT)


## The repair procedure finished: decides the branch, then runs the dry test.
func _repaired(id: StringName) -> void:
	var phase := get_phase(id)
	if phase == Phase.LEAK:
		# Believed №2: repaired before the overheating; the heat still cracked the seal.
		_set_flag_of(id, "believed")
		var trust := StringName(str(modules[id].get("trust_flag", "")))
		if not trust.is_empty():
			GameState.set_flag(trust, int(GameState.get_flag(trust, 0)) + int(modules[id].get("trust_bonus", 0)))
		_set_flag_of(id, "overheat")
		Containment.add_instability(id, float(modules[id].get("seal_crack_instability", 0.0)))
	elif phase != Phase.OVERHEAT:
		return
	_set_phase(id, Phase.DRY_TEST, float(modules[id].get("dry_test_seconds", 0.0)))
	Sfx.play(&"terminal_type")
	_say(DRY_TEST_TITLE % _label(id), DRY_TEST_START_TEXT)
	if get_timer(id) <= 0.0:
		_resolve(id)


func _resolve(id: StringName) -> void:
	_set_phase(id, Phase.RESOLVED)
	_set_flag_of(id, "resolved")
	Sfx.play(&"terminal_beep")
	_say(DRY_TEST_TITLE % _label(id), DRY_TEST_DONE_TEXT)


func _apply_growth(id: StringName) -> void:
	if get_phase(id) == Phase.OVERHEAT:
		Containment.growth_bonus[id] = float(modules[id].get("overheat_growth_per_minute", 0.0))
	else:
		Containment.growth_bonus.erase(id)


func _on_flag_changed(flag: StringName, _value: Variant) -> void:
	for id: StringName in modules:
		if flag == StringName(str(modules[id].get("repair_flag", ""))):
			_repaired(id)
		elif get_phase(id) == Phase.NOMINAL and StateRules.check(modules[id].get("fails_when", {})):
			_start_leak(id)


## The chemical protocol fired while the cooling was failing: the hero hesitated too long.
func _on_module_sealed(id: StringName) -> void:
	if modules.has(id) and get_phase(id) in [Phase.LEAK, Phase.OVERHEAT]:
		_set_flag_of(id, "chem")


func _say(title: String, text: String) -> void:
	if is_inside_tree():
		get_tree().call_group(MESSAGE_GROUP, "show_message", title, text)


func _label(id: StringName) -> String:
	return str((Containment.modules.get(id, {}) as Dictionary).get("label", id))


func _entry(id: StringName) -> Dictionary:
	var key := String(id)
	if not _state.has(key):
		_state[key] = {"phase": Phase.NOMINAL, "timer": 0.0}
	return _state[key]


func _save() -> void:
	GameState.set_system_data(SYSTEM, _state)


func _on_state_loaded() -> void:
	_state = GameState.get_system_data(SYSTEM).duplicate(true)
	for id: StringName in modules:
		var phase := get_phase(id)
		# Saves and debug moments that already carry the outcome skip the crisis.
		if phase != Phase.RESOLVED and GameState.has_flag(_flag(id, "resolved")):
			_entry(id)["phase"] = Phase.RESOLVED
		elif phase == Phase.NOMINAL and StateRules.check(modules[id].get("fails_when", {})):
			_entry(id)["phase"] = Phase.LEAK
			_entry(id)["timer"] = float(modules[id].get("grace_seconds", 0.0))
			_set_flag_of(id, "leak")
		_apply_growth(id)
	_save()


static func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
