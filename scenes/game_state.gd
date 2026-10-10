extends Node

## Global gameplay state of a playthrough (autoload `GameState`).
##
## Holds the current objective, story flags, power state of facility sections and the
## access grants of the hero. Systems read the state and listen to its signals instead of
## searching the scene tree. The whole state round-trips through `to_dict()`/`from_dict()`.

signal objective_changed(objective_id: StringName, text: String)
signal flag_changed(flag: StringName, value: Variant)
signal section_power_changed(section: StringName, power: int)
signal access_changed(access: StringName, granted: bool)
signal state_loaded

enum Power { OFF, EMERGENCY, MAIN }

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://savegame.json"
const POWER_NAMES: Array[String] = ["off", "emergency", "main"]

var objective_id: StringName = &""
var objective_text := ""

var _flags: Dictionary[StringName, Variant] = {}
var _section_power: Dictionary[StringName, int] = {}
var _access: Dictionary[StringName, bool] = {}


func reset() -> void:
	objective_id = &""
	objective_text = ""
	_flags.clear()
	_section_power.clear()
	_access.clear()
	state_loaded.emit()


# --- Objective -------------------------------------------------------------

func set_objective(id: StringName, text: String) -> void:
	if id == objective_id and text == objective_text:
		return
	objective_id = id
	objective_text = text
	objective_changed.emit(id, text)


# --- Flags -----------------------------------------------------------------

func set_flag(flag: StringName, value: Variant = true) -> void:
	if _flags.get(flag) == value and _flags.has(flag):
		return
	_flags[flag] = value
	flag_changed.emit(flag, value)


func get_flag(flag: StringName, default: Variant = false) -> Variant:
	return _flags.get(flag, default)


func has_flag(flag: StringName) -> bool:
	return bool(_flags.get(flag, false))


func clear_flag(flag: StringName) -> void:
	if not _flags.has(flag):
		return
	_flags.erase(flag)
	flag_changed.emit(flag, null)


# --- Section power ---------------------------------------------------------

## Sections that were never set are unpowered.
func get_section_power(section: StringName) -> int:
	return _section_power.get(section, Power.OFF)


func set_section_power(section: StringName, power: int) -> void:
	assert(power >= Power.OFF and power <= Power.MAIN, "unknown power state %d" % power)
	if get_section_power(section) == power and _section_power.has(section):
		return
	_section_power[section] = power
	section_power_changed.emit(section, power)


func is_section_powered(section: StringName) -> bool:
	return get_section_power(section) != Power.OFF


static func power_name(power: int) -> String:
	return POWER_NAMES[power] if power >= 0 and power < POWER_NAMES.size() else "unknown"


# --- Access ----------------------------------------------------------------

func grant_access(access: StringName) -> void:
	if _access.get(access, false):
		return
	_access[access] = true
	access_changed.emit(access, true)


func revoke_access(access: StringName) -> void:
	if not _access.has(access):
		return
	_access.erase(access)
	access_changed.emit(access, false)


## An empty requirement is always satisfied.
func has_access(access: StringName) -> bool:
	return access == &"" or bool(_access.get(access, false))


# --- Serialization ---------------------------------------------------------

func to_dict() -> Dictionary:
	var flags := {}
	for flag: StringName in _flags:
		flags[String(flag)] = _flags[flag]
	var power := {}
	for section: StringName in _section_power:
		power[String(section)] = power_name(_section_power[section])
	var access: Array[String] = []
	for grant: StringName in _access:
		access.append(String(grant))
	access.sort()
	return {
		"version": SAVE_VERSION,
		"objective": {"id": String(objective_id), "text": objective_text},
		"flags": flags,
		"section_power": power,
		"access": access,
	}


## Replaces the whole state. Returns false (and keeps the state) for an unsupported document.
func from_dict(data: Dictionary) -> bool:
	if int(data.get("version", -1)) != SAVE_VERSION:
		push_warning("GameState: unsupported save version %s" % data.get("version"))
		return false
	_flags.clear()
	_section_power.clear()
	_access.clear()
	var objective: Dictionary = data.get("objective", {})
	objective_id = StringName(str(objective.get("id", "")))
	objective_text = str(objective.get("text", ""))
	var flags: Dictionary = data.get("flags", {})
	for flag: String in flags:
		_flags[StringName(flag)] = flags[flag]
	var power: Dictionary = data.get("section_power", {})
	for section: String in power:
		var index := POWER_NAMES.find(str(power[section]))
		if index >= 0:
			_section_power[StringName(section)] = index
	for grant: Variant in data.get("access", []):
		_access[StringName(str(grant))] = true
	state_loaded.emit()
	objective_changed.emit(objective_id, objective_text)
	return true


func save_to_file(path: String = DEFAULT_SAVE_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return OK


func load_from_file(path: String = DEFAULT_SAVE_PATH) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return ERR_PARSE_ERROR
	return OK if from_dict(parsed) else ERR_INVALID_DATA
