@tool
class_name AccessReader
extends StaticBody3D

## Pass reader beside an electronic door (#211): shows which access the door wants and why it
## refuses the player. The player puts the pass to it (press): without `required_access` the
## screen answers with the pass owner and the refusal, a red lamp and an error beep; with the
## access it confirms and opens the linked door. The lamp is green while the access is held,
## dark without section power. Local frame: the reader faces +Z, the origin is its centre.
## A powered door with an access builds its own readers in place of the panels (#220): then a granted
## scan works the door like a panel press (opens or closes it), and a door locked for another reason
## (emergency) refuses on the screen with that reason.

signal scanned(granted: bool)

const PROMPT := "ПРИЛОЖИТЬ ПРОПУСК"
const SOUND_GRANTED := &"terminal_beep"
const SOUND_DENIED := &"terminal_error"
## How long a scan answer stays on the screen before the idle text returns.
const ANSWER_TIME := 3.5
const BODY_SIZE := Vector3(0.24, 0.34, 0.05)
const BODY_COLOR := Color(0.16, 0.17, 0.18)
const SCREEN_COLOR := Color(0.03, 0.06, 0.05)
const PAD_COLOR := Color(0.1, 0.1, 0.11)
const TEXT_IDLE := Color(0.75, 0.85, 0.8)
const TEXT_DENIED := Color(1.0, 0.3, 0.22)
const TEXT_GRANTED := Color(0.35, 1.0, 0.5)
const LAMP_OFF := Color(0.05, 0.05, 0.05)
const LAMP_LOCKED := Color(0.9, 0.15, 0.1)
const LAMP_READY := Color(0.15, 0.85, 0.3)

@export var required_access: StringName = &""
## Power section: without power the reader is dark and refuses with «НЕТ ПИТАНИЯ».
@export var section: StringName = &""
## The door opened on a granted scan (FacilityDoor); optional.
@export var door_path: NodePath
## Name of the access level on the screen.
@export var access_title := "ДОПУСК СТАРШЕГО"
## The player's own pass, named on a refusal.
@export var pass_title := "ПРОПУСК 2-117\nОХРАНА"
## The player's role once the access is held, named on a granted scan.
@export var granted_title := "ВРЕМЕННЫЙ СМОТРИТЕЛЬ"

## The door this reader works; set by the door for its own readers, else found by `door_path`.
var door: FacilityDoor
var interactable: Interactable
var screen: Label3D
var _lamp: StandardMaterial3D
var _answer_timer: SceneTreeTimer
## Last scan answer on the screen: empty — idle text.
var _answer := ""
var _answer_color := TEXT_IDLE


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	if door == null:
		door = get_node_or_null(door_path) as FacilityDoor
	interactable = PropKit.interactable(self, Interactable.Mode.PRESS, PROMPT)
	interactable.interacted.connect(scan)
	GameState.section_power_changed.connect(func(_section: StringName, _power: int) -> void: refresh())
	GameState.access_changed.connect(func(_access: StringName, _granted: bool) -> void: refresh())
	GameState.state_loaded.connect(refresh)
	if door:
		door.state_changed.connect(func(_state: FacilityDoor.State) -> void: refresh())
	refresh()


func is_powered() -> bool:
	return GameState.is_section_powered(section)


func is_granted() -> bool:
	return GameState.has_access(required_access)


## The pass put to the reader. Returns whether the access was granted.
func scan() -> bool:
	if not is_powered():
		return false
	var granted := is_granted()
	var reason := _door_reason()
	if granted and not reason.is_empty():
		_show_answer("%s\nОТКАЗАНО\n%s" % [granted_title, reason], TEXT_DENIED)
		Sfx.play(SOUND_DENIED, self)
	elif granted:
		_show_answer("%s\nДОСТУП РАЗРЕШЁН" % granted_title, TEXT_GRANTED)
		Sfx.play(SOUND_GRANTED, self)
		if door and door.has_readers():
			door.use_from_reader()
		elif door and door.is_closed():
			door.open()
	else:
		_show_answer("%s\nОТКАЗАНО\nНУЖЕН %s" % [pass_title, access_title], TEXT_DENIED)
		Sfx.play(SOUND_DENIED, self)
	scanned.emit(granted)
	return granted


func idle_text() -> String:
	return "СЧИТЫВАТЕЛЬ\n%s" % access_title


## Why the linked door refuses a granted pass (other than the access itself), or empty.
func _door_reason() -> String:
	if door == null:
		return ""
	var reason := door.lock_reason()
	return "" if reason == FacilityDoor.REASON_NO_ACCESS else reason


func _show_answer(text: String, color: Color) -> void:
	_answer = text
	_answer_color = color
	refresh()
	_answer_timer = get_tree().create_timer(ANSWER_TIME)
	var timer := _answer_timer
	timer.timeout.connect(func() -> void:
		if _answer_timer == timer:
			_answer = ""
			refresh())


func refresh() -> void:
	if interactable == null:
		return
	var powered := is_powered()
	var moving := door != null and not (door.is_open() or door.is_closed())
	interactable.available = powered and not moving
	interactable.unavailable_prompt = FacilityDoor.REASON_NO_POWER if not powered else FacilityDoor.REASON_MOVING
	screen.visible = powered
	screen.text = idle_text() if _answer.is_empty() else _answer
	screen.modulate = TEXT_IDLE if _answer.is_empty() else _answer_color
	var lamp_color := LAMP_OFF
	if powered:
		lamp_color = LAMP_READY if is_granted() and _door_reason().is_empty() else LAMP_LOCKED
	_lamp.albedo_color = lamp_color
	_lamp.emission = lamp_color


func _build() -> void:
	for child in get_children():
		if child.has_meta(&"reader_generated"):
			child.free()
	var parts := Node3D.new()
	parts.name = "Parts"
	parts.set_meta(&"reader_generated", true)
	add_child(parts)
	var shape := CollisionShape3D.new()
	shape.set_meta(&"reader_generated", true)
	var box := BoxShape3D.new()
	box.size = BODY_SIZE + Vector3(0.04, 0.04, 0.04)
	shape.shape = box
	add_child(shape)
	var face := BODY_SIZE.z * 0.5
	PropKit.box(parts, Vector3.ZERO, BODY_SIZE, PropKit.material(BODY_COLOR))
	PropKit.box(parts, Vector3(0, 0.07, face), Vector3(0.2, 0.15, 0.004), PropKit.material(SCREEN_COLOR))
	# The pad the pass is put to, with the lamp above it.
	PropKit.box(parts, Vector3(0, -0.1, face), Vector3(0.14, 0.1, 0.006), PropKit.material(PAD_COLOR))
	_lamp = PropKit.material(LAMP_OFF, true)
	PropKit.box(parts, Vector3(0, -0.028, face), Vector3(0.08, 0.016, 0.008), _lamp)
	screen = PropKit.label(parts, Vector3(0, 0.07, face + 0.004), idle_text(), 20, TEXT_IDLE)
	screen.pixel_size = 0.001
	screen.width = 190.0
	screen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.double_sided = false
