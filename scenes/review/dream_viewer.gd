class_name DreamViewer
extends Node3D

## Viewing mode of Bowser's dream for the art review (#204): the whole dream at once without
## fight or death. Wraps `bowser_dream.tscn` unchanged: the hero is frozen at the spawn, the
## guards are brought out and stand in the yard, the sleeper is held so the instability does
## not grow. A free camera flies over the dream; keys 1–4 switch the four stages of the sleep
## (sky and light DreamStageMood, sound DreamAudio, ash and embers BowserDreamFx), 5–0 jump to
## the key places, H hides the hints. F9 (ReviewReturn) goes back to the review hall.

const SCENE := "res://scenes/review/dream_viewer.tscn"
const MODULE := &"module_4"
const DREAM_PATH := ^"BowserDream"
const FLY_SPEED := 8.0
const FLY_FAST := 3.0  # speed multiplier with Shift
const LOOK_LIMIT := 89.0  # degrees up and down
const HINT_LAYER := 104
const HINTS_KEY := KEY_H
const STAGE_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
const STAGE_NAMES: Array[String] = ["покой", "тревога", "беспокойство", "предпробуждение"]
const VIEW_KEYS: Array[Key] = [KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
## Key places: `node` of the dream to look at, the camera at node + `from`, aimed at node + `at`.
const VIEWS: Array[Dictionary] = [
	{"title": "двор", "node": ^"Yard", "from": Vector3(-12, 7, 10), "at": Vector3(0, 1, 0)},
	{"title": "ниша героя", "node": ^"Yard/Remains", "from": Vector3(0, 2.2, 5), "at": Vector3(0, 0.8, 0)},
	{"title": "след оператора", "node": ^"Yard/Ambush/OperatorTrace", "from": Vector3(2.5, 2.0, 2.5), "at": Vector3.ZERO},
	{"title": "печать", "node": ^"SealHall/Seal", "from": Vector3(-7, 3.5, 0), "at": Vector3(0, 2, 0)},
	{"title": "мост", "node": ^"Path/Bridge", "from": Vector3(-6, 5, 8), "at": Vector3.ZERO},
	{"title": "арка", "node": ^"Bastion/Gate", "from": Vector3(0, 3, 10), "at": Vector3(0, 2.5, 0)},
]
const HINT_TEXT := "СМОТРОВАЯ СНА · мышь — обзор (клик — захват), WASD — полёт, Q/E — вниз/вверх, Shift — быстрее\n1–4 — стадия: 1 покой · 2 тревога · 3 беспокойство · 4 предпробуждение\n5–0 — точки: 5 двор · 6 ниша героя · 7 след оператора · 8 печать · 9 мост · 0 арка\nH — скрыть подсказки · F9 — в смотровую"

## The camera of the viewer (current while the viewer is open).
var camera: Camera3D
## Stage shown now (DreamStageMood.Stage).
var stage: DreamStageMood.Stage = DreamStageMood.Stage.ALARM
var hints_visible := true

var _dream: BowserDream
var _mood: DreamStageMood
var _hints: CanvasLayer
var _status: Label
var _pitch := 0.0
var _yaw := 0.0
var _view_title := ""


func _enter_tree() -> void:
	# The dream scripts read the session when they get ready: open it before they do, without
	# the chair, the cost of the entry or a way back.
	Dreams.module_id = MODULE
	Dreams.in_dream = true
	Dreams.seal_restored = false
	Containment.set_held(MODULE, true)


func _ready() -> void:
	_dream = get_node(DREAM_PATH) as BowserDream
	_mood = _dream.get_node(^"Mood") as DreamStageMood
	_freeze_hero()
	_stand_guards()
	_build_camera()
	_build_hints()
	set_stage(DreamStageMood.Stage.ALARM)
	go_to_view(0)


func _exit_tree() -> void:
	Containment.set_held(MODULE, false)
	Dreams.abort()
	DreamAudio.refresh()


## Shows `value` at once: sky and light, sound, ash and embers follow the mood.
func set_stage(value: DreamStageMood.Stage) -> void:
	stage = value
	_mood.set_event_stage(value)
	_mood.finish_transition()
	DreamAudio.refresh()
	_update_status()


## Puts the camera at the key place `index` of VIEWS.
func go_to_view(index: int) -> void:
	var view := VIEWS[index]
	var anchor := _dream.get_node(view["node"] as NodePath) as Node3D
	var from := anchor.global_position + (view["from"] as Vector3)
	var at := anchor.global_position + (view["at"] as Vector3)
	camera.global_position = from
	camera.look_at(at, Vector3.UP)
	_pitch = camera.rotation.x
	_yaw = camera.rotation.y
	_view_title = str(view["title"])
	_update_status()


func set_hints_visible(value: bool) -> void:
	hints_visible = value
	_hints.visible = value


func _freeze_hero() -> void:
	var hero := _dream.get_node(^"Player")
	hero.call(&"set_controls_locked", true)
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	_dream.set_physics_process(false)  # no fall, no death
	var hud := _dream.get_node_or_null(^"OpeningHud") as CanvasItem
	if hud:
		hud.visible = false


## The guards come out of their niches (smoke, the brazier of the remains) and stay still.
func _stand_guards() -> void:
	var ambush := _dream.get_node(^"Yard/Ambush") as DreamAmbush
	ambush.start()
	for guard in ambush.guards:
		guard.scale = Vector3.ONE
		guard.process_mode = Node.PROCESS_MODE_DISABLED


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ViewerCamera"
	camera.fov = Settings.fov
	add_child(camera)
	camera.make_current()


func _build_hints() -> void:
	_hints = CanvasLayer.new()
	_hints.name = "Hints"
	_hints.layer = HINT_LAYER
	add_child(_hints)
	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	_hints.add_child(box)
	var help := _label(HINT_TEXT)
	box.add_child(help)
	_status = _label("")
	box.add_child(_status)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.6))
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 4)
	return label


func _update_status() -> void:
	if _status:
		_status.text = "Стадия %d — %s · точка: %s" % [int(stage) + 1, STAGE_NAMES[stage], _view_title]


func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		move.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		move.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		move.x += 1.0
	if Input.is_physical_key_pressed(KEY_E):
		move.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		move.y -= 1.0
	if move == Vector3.ZERO:
		return
	var speed := FLY_SPEED * (FLY_FAST if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	var view := camera.global_basis
	var direction := view.x * move.x + view.z * move.z + Vector3.UP * move.y
	camera.global_position += direction.normalized() * speed * delta


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := Settings.mouse_sensitivity()
		var vertical := -1.0 if Settings.invert_y else 1.0
		_yaw -= motion.relative.x * sensitivity
		_pitch = clampf(_pitch - motion.relative.y * sensitivity * vertical, deg_to_rad(-LOOK_LIMIT), deg_to_rad(LOOK_LIMIT))
		camera.rotation = Vector3(_pitch, _yaw, 0.0)
		return
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if code in STAGE_KEYS:
		set_stage(STAGE_KEYS.find(code) as DreamStageMood.Stage)
	elif code in VIEW_KEYS:
		go_to_view(VIEW_KEYS.find(code))
	elif code == HINTS_KEY:
		set_hints_visible(not hints_visible)
	else:
		return
	get_viewport().set_input_as_handled()
