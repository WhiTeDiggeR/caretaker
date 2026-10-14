class_name ResyncPanel
extends StaticBody3D

## Capsule resync panel of a module (D7, docs/game_design/03-first-dream.md): the hero
## types the glyphs remembered at the dream's seal on eight phase-mark keys (4 × 2, Ф-1…Ф-8)
## and confirms with ВВОД (З-Р7, #196; 07-dream-glyphs.md, 05_resync_panel.svg). ВВОД is
## unavailable until the code is complete; a match calms the sleep, a mistake disturbs it
## (+5, З-4) and the wrong slots stay on the screen for HOLD_SECONDS. СБРОС before ВВОД is
## free. Keys are built from data/dreams/knowledge.json; the code length comes from the data.
## The state is shown on a late-era world screen in the status grammar (issue #165).

const BUTTON_SIZE := Vector3(0.2, 0.16, 0.06)
const BUTTON_COLUMNS := 4
const BUTTON_STEP := Vector2(0.235, 0.22)
const BUTTON_ORIGIN := Vector3(-0.3525, 1.2, 0.18)
const BUTTON_COLOR := Color(0.13, 0.14, 0.15)
const RESET_CAPTION := "СБРОС"
const ENTER_CAPTION := "ВВОД"
const HOLD_SECONDS := 1.5
const NEED_GLYPHS := "НУЖНО %d ЗНАКА"
const CAPTION_SIZE := 26
## Share of the key height the glyph takes; the phase code under it is small.
const KEY_GLYPH_SHARE := 0.66
const KEY_CODE_SIZE := 14
const TITLE := "РЕСИНХРОНИЗАЦИЯ КАПСУЛЫ · %s"
const EMPTY_SLOT := "_"
const LOCK_NO_KNOWLEDGE := "НУЖНЫ ЗНАКИ ИЗ СНА"
const LOCK_AWAKE := "ОБЪЕКТ БОДРСТВУЕТ"
const LOCK_NO_POWER := "НЕТ ПИТАНИЯ"
const NO_KNOWLEDGE_LINES := "Нет данных для ресинхронизации.\nНужны знаки печати из сна модуля:\nпогружение → печать → врата."
const SYNCED_LINE := "СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА.\nСон стабилен."
const WRONG_LINE := "ОШИБКА СИНХРОНИЗАЦИИ.\nНестабильность выросла. Повторите ввод."
const AWAKE_LINE := "Объект бодрствует.\nРесинхронизация невозможна."

@export var module_id: StringName = &"module_4"
## Power section of the panel; none keeps the screen always on.
@export var section: StringName = &""

@onready var _screen: WorldScreen = $Screen
@onready var _reset: Interactable = $ResetButton/Interactable
@onready var _enter: Interactable = $EnterButton/Interactable

var entered := PackedStringArray()
var last_result := -1
## The wrong code kept on the screen after a mistake (empty once the hold is over).
var held := PackedStringArray()
var _buttons: Array[Interactable] = []


func _ready() -> void:
	_reset.prompt = "СБРОСИТЬ ВВОД"
	_caption($ResetButton, RESET_CAPTION)
	_reset.interacted.connect(func() -> void:
		entered.clear()
		_clear_hold()
		refresh())
	_enter.prompt = "ВВОД"
	_caption($EnterButton, ENTER_CAPTION)
	_enter.interacted.connect(enter)
	var glyphs := DreamKnowledge.glyphs()
	for index in glyphs.size():
		_buttons.append(_build_button(glyphs[index], index))
	Containment.stage_changed.connect(func(_id: StringName, _stage: int) -> void: refresh())
	GameState.state_loaded.connect(refresh)
	GameState.section_power_changed.connect(func(_section: StringName, _power: int) -> void: refresh())
	refresh()


## Adds one glyph to the input; extra presses beyond the code length are ignored.
func press(glyph: String) -> void:
	var id := DreamKnowledge.active_for(module_id)
	if id.is_empty() or entered.size() >= DreamKnowledge.code(id).size():
		return
	_clear_hold()
	entered.append(glyph)
	refresh()


## ВВОД: checks a complete input. A mistake keeps the slots on screen for HOLD_SECONDS.
func enter() -> void:
	var id := DreamKnowledge.active_for(module_id)
	if id.is_empty() or entered.size() < DreamKnowledge.code(id).size():
		return
	last_result = DreamKnowledge.resync(module_id, entered)
	if last_result == DreamKnowledge.Result.WRONG:
		held = entered.duplicate()
		var shown := held
		get_tree().create_timer(HOLD_SECONDS).timeout.connect(func() -> void:
			if held == shown:
				held.clear()
				refresh())
	entered.clear()
	refresh()


func _clear_hold() -> void:
	held.clear()
	last_result = -1


func refresh() -> void:
	var label := str(Containment.modules.get(module_id, {}).get("label", module_id))
	var rows: Array[Dictionary] = []
	var id := DreamKnowledge.active_for(module_id)
	var lock := ""
	if Containment.is_awake(module_id):
		lock = LOCK_AWAKE
		rows.append_array(_rows(AWAKE_LINE, &"warn"))
	elif last_result == DreamKnowledge.Result.SYNCED:
		rows.append_array(_rows(SYNCED_LINE, &"ok"))
	if lock.is_empty() and id.is_empty():
		lock = LOCK_NO_KNOWLEDGE
		if last_result != DreamKnowledge.Result.SYNCED:
			rows.append_array(_rows(NO_KNOWLEDGE_LINES, &""))
	elif lock.is_empty():
		if last_result == DreamKnowledge.Result.WRONG:
			rows.append_array(_rows(WRONG_LINE, &"alarm"))
		var shown := held if entered.is_empty() and not held.is_empty() else entered
		var slots := PackedStringArray()
		var glyphs: Array[String] = []
		for index in DreamKnowledge.code(id).size():
			slots.append(DreamKnowledge.label(shown[index]) if index < shown.size() else EMPTY_SLOT)
			glyphs.append(shown[index] if index < shown.size() else "")
		rows.append({"text": "Введите знаки печати:", "status": &""})
		# The slots are drawn as glyphs (#198); the text is their plain reading for tests.
		rows.append({"text": DreamKnowledge.SEPARATOR.join(slots), "status": &"", "large": true, "glyphs": glyphs})
	var powered := section.is_empty() or GameState.is_section_powered(section)
	_screen.set_powered(powered)
	if powered:
		_screen.show_rows(TITLE % label, rows)
	else:
		lock = LOCK_NO_POWER
	for button in _buttons:
		button.available = lock.is_empty()
		button.unavailable_prompt = lock
	_reset.available = lock.is_empty() and not entered.is_empty()
	_reset.unavailable_prompt = ""
	var needed := DreamKnowledge.code(id).size()
	_enter.available = lock.is_empty() and entered.size() >= needed
	_enter.unavailable_prompt = lock if not lock.is_empty() else NEED_GLYPHS % needed


## A sign under a button.
static func _caption(button: Node3D, text: String) -> void:
	var label := UiStyle.sign_label(text, CAPTION_SIZE)
	label.position = Vector3(0, -0.11, 0.035)
	button.add_child(label)


## Everything the screen shows as plain lines (tests).
func screen_text() -> String:
	return _screen.text()


## A message of several lines: its first line carries the status, the rest is plain.
static func _rows(message: String, status: StringName) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for line in message.split("\n"):
		rows.append({"text": line, "status": status if rows.is_empty() else &""})
	return rows


func glyph_button(glyph: String) -> Interactable:
	for button in _buttons:
		if button.get_meta(&"glyph", "") == glyph:
			return button
	return null


func _build_button(glyph: String, index: int) -> Interactable:
	var body := StaticBody3D.new()
	body.name = "Glyph%d" % index
	body.position = BUTTON_ORIGIN + Vector3(BUTTON_STEP.x * (index % BUTTON_COLUMNS), -BUTTON_STEP.y * (index / BUTTON_COLUMNS), 0)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = BUTTON_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = BUTTON_COLOR
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = BUTTON_SIZE + Vector3(0.02, 0.02, 0.04)
	collision.shape = shape
	body.add_child(collision)
	# The drawn glyph is the key's face; its phase code is only a small service mark (#198).
	var text := UiStyle.sign_label(DreamKnowledge.label(glyph), KEY_CODE_SIZE)
	text.position = Vector3(0, -BUTTON_SIZE.y * 0.38, BUTTON_SIZE.z * 0.5 + 0.005)
	body.add_child(text)
	var mark := DreamGlyph.mesh_instance(glyph, BUTTON_SIZE.y * KEY_GLYPH_SHARE, DreamGlyph.flat_material(UiStyle.SIGN_TEXT))
	mark.position = Vector3(0, BUTTON_SIZE.y * 0.1, BUTTON_SIZE.z * 0.5 + 0.004)
	body.add_child(mark)
	var interactable := Interactable.new()
	interactable.prompt = "ВВЕСТИ ЗНАК · %s" % DreamKnowledge.label(glyph)
	interactable.set_meta(&"glyph", glyph)
	interactable.interacted.connect(press.bind(glyph))
	body.add_child(interactable)
	add_child(body)
	return interactable
