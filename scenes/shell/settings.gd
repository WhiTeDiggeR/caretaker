extends Node

## Player settings (autoload `Settings`): volume of the Master/SFX/Ambience buses, mouse
## sensitivity and inversion, field of view, the CRT effect of world screens and the primary
## binding of each remappable action. Actions come in groups: the complex and the dream
## (#189: dream combat — attacks and the dash). A binding is a key or, for the dream group, a
## mouse button; within a group a taken binding swaps, across groups it may repeat (dream
## actions work only in a dream).
## Stored in user://settings.cfg and applied at start.

signal changed

const DEFAULT_PATH := "user://settings.cfg"
const BUSES: Array[StringName] = [&"Master", &"SFX", &"Ambience"]
const BUS_NAMES := {&"Master": "Общая громкость", &"SFX": "Эффекты", &"Ambience": "Фон и эмбиент"}
const BASE_MOUSE_SENSITIVITY := 0.002
const SENSITIVITY_RANGE := Vector2(0.25, 3.0)
const FOV_RANGE := Vector2(60.0, 100.0)
const DEFAULT_FOV := 75.0
## Head bob, strafe roll and landing dip of the camera (#134): 0 = off, 1 = full.
const DEFAULT_HEAD_BOB := 1.0
## Remappable actions of the complex and their names in the settings screen.
const ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"sprint", &"crouch", &"crawl", &"interact", &"journal"]
## Remappable dream combat actions (data/dreams/combat.json, DreamCombat.DASH_ACTION).
const DREAM_ACTIONS: Array[StringName] = [&"dream_attack", &"dream_alt_attack", &"dream_dash"]
const ACTION_NAMES := {
	&"move_forward": "Вперёд", &"move_back": "Назад", &"move_left": "Влево", &"move_right": "Вправо",
	&"jump": "Прыжок / перелезть", &"sprint": "Бег", &"crouch": "Присед", &"crawl": "Ползком (вкл/выкл)", &"interact": "Взаимодействие", &"journal": "Журнал",
	&"dream_attack": "Удар", &"dream_alt_attack": "Дальний образ", &"dream_dash": "Рывок-уклонение",
}
## Mouse buttons are stored as negative binding codes (keys are positive physical keycodes).
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "ЛКМ", MOUSE_BUTTON_RIGHT: "ПКМ", MOUSE_BUTTON_MIDDLE: "СКМ", MOUSE_BUTTON_XBUTTON1: "Мышь 4", MOUSE_BUTTON_XBUTTON2: "Мышь 5"}

var config_path := DEFAULT_PATH
var volume: Dictionary[StringName, float] = {&"Master": 100.0, &"SFX": 100.0, &"Ambience": 100.0}
var mouse_multiplier := 1.0
var invert_y := false
var fov := DEFAULT_FOV
## Scanlines, bloom and roll of the world screens (terminals, monitors); off keeps them flat.
var crt_effects := true
var head_bob := DEFAULT_HEAD_BOB

## Primary binding of each action as configured by the project.
var _default_keys: Dictionary[StringName, int] = {}


func _ready() -> void:
	_ensure_buses()
	for action in all_actions():
		_default_keys[action] = primary_key(action)
	load_settings()


## Every remappable action, the complex first.
static func all_actions() -> Array[StringName]:
	var result: Array[StringName] = ACTIONS.duplicate()
	result.append_array(DREAM_ACTIONS)
	return result


## The remappable actions of the group `action` belongs to.
static func group_of(action: StringName) -> Array[StringName]:
	return DREAM_ACTIONS if action in DREAM_ACTIONS else ACTIONS


func mouse_sensitivity() -> float:
	return BASE_MOUSE_SENSITIVITY * mouse_multiplier


func set_volume(bus: StringName, percent: float) -> void:
	volume[bus] = clampf(percent, 0.0, 100.0)
	_apply_volume(bus)
	changed.emit()


func set_mouse_multiplier(value: float) -> void:
	mouse_multiplier = clampf(value, SENSITIVITY_RANGE.x, SENSITIVITY_RANGE.y)
	changed.emit()


func set_invert_y(value: bool) -> void:
	invert_y = value
	changed.emit()


func set_fov(value: float) -> void:
	fov = clampf(value, FOV_RANGE.x, FOV_RANGE.y)
	changed.emit()


func set_crt_effects(value: bool) -> void:
	crt_effects = value
	changed.emit()


func set_head_bob(value: float) -> void:
	head_bob = clampf(value, 0.0, 1.0)
	changed.emit()


# --- Keys --------------------------------------------------------------------

## Binding code of the first key or mouse button of the action: a physical keycode, a
## negative mouse button index, or KEY_NONE when there is none.
func primary_key(action: StringName) -> int:
	for event in InputMap.action_get_events(action):
		var code := binding_code(event)
		if code != KEY_NONE:
			return code
	return KEY_NONE


static func binding_code(event: InputEvent) -> int:
	if event is InputEventKey:
		return (event as InputEventKey).physical_keycode
	if event is InputEventMouseButton:
		return -(event as InputEventMouseButton).button_index
	return KEY_NONE


static func mouse_code(button: MouseButton) -> int:
	return -int(button)


## Sets the primary binding of `action`. When another action of the same group already uses
## it as its primary binding, the two actions swap. Returns the swapped action or &"".
func remap(action: StringName, physical_keycode: int) -> StringName:
	var previous := primary_key(action)
	var swapped: StringName = &""
	for other in group_of(action):
		if other != action and primary_key(other) == physical_keycode:
			_set_primary(other, previous)
			swapped = other
	_set_primary(action, physical_keycode)
	changed.emit()
	return swapped


func reset_keys() -> void:
	for action in all_actions():
		_set_primary(action, _default_keys[action])
	changed.emit()


static func key_name(physical_keycode: int) -> String:
	if physical_keycode == KEY_NONE:
		return "—"
	if physical_keycode < 0:
		return MOUSE_NAMES.get(-physical_keycode, "Мышь %d" % -physical_keycode)
	if DisplayServer.get_name() == "headless":
		return OS.get_keycode_string(physical_keycode)
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(physical_keycode))


func _set_primary(action: StringName, physical_keycode: int) -> void:
	var events := InputMap.action_get_events(action)
	for event in events:
		if binding_code(event) != KEY_NONE:
			InputMap.action_erase_event(action, event)
			break
	if physical_keycode == KEY_NONE:
		return
	var binding: InputEvent
	if physical_keycode < 0:
		var button := InputEventMouseButton.new()
		button.button_index = -physical_keycode as MouseButton
		binding = button
	else:
		var key := InputEventKey.new()
		key.physical_keycode = physical_keycode as Key
		binding = key
	var rest := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, binding)
	for event in rest:
		InputMap.action_add_event(action, event)


# --- Storage -----------------------------------------------------------------

func save_settings() -> Error:
	var file := ConfigFile.new()
	for bus in BUSES:
		file.set_value("audio", String(bus), volume[bus])
	file.set_value("controls", "mouse_multiplier", mouse_multiplier)
	file.set_value("controls", "invert_y", invert_y)
	file.set_value("video", "fov", fov)
	file.set_value("video", "crt_effects", crt_effects)
	file.set_value("video", "head_bob", head_bob)
	for action in all_actions():
		file.set_value("keys", String(action), primary_key(action))
	return file.save(config_path)


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(config_path) == OK:
		for bus in BUSES:
			volume[bus] = float(file.get_value("audio", String(bus), 100.0))
		mouse_multiplier = float(file.get_value("controls", "mouse_multiplier", 1.0))
		invert_y = bool(file.get_value("controls", "invert_y", false))
		fov = float(file.get_value("video", "fov", DEFAULT_FOV))
		crt_effects = bool(file.get_value("video", "crt_effects", true))
		head_bob = clampf(float(file.get_value("video", "head_bob", DEFAULT_HEAD_BOB)), 0.0, 1.0)
		for action in all_actions():
			var key := int(file.get_value("keys", String(action), _default_keys[action]))
			if key != primary_key(action):
				_set_primary(action, key)
	for bus in BUSES:
		_apply_volume(bus)
	changed.emit()


## Restores every setting to its default (keys included) without saving.
func reset_all() -> void:
	for bus in BUSES:
		volume[bus] = 100.0
		_apply_volume(bus)
	mouse_multiplier = 1.0
	invert_y = false
	fov = DEFAULT_FOV
	crt_effects = true
	head_bob = DEFAULT_HEAD_BOB
	reset_keys()


func _apply_volume(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var percent := volume[bus]
	AudioServer.set_bus_mute(index, percent <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(percent, 0.001) / 100.0))


func _ensure_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, &"Master")
