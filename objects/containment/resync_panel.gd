class_name ResyncPanel
extends StaticBody3D

## Capsule resync panel of a module (D7, docs/game_design/03-first-dream.md): the hero
## enters the glyphs remembered at the dream's seal. The sequence is checked once it is
## complete; a match calms the sleep, a mistake disturbs it and the input starts over.
## Glyph buttons are built from data/dreams/knowledge.json. The state is shown on a
## late-era world screen in the status grammar, the glyphs on the buttons like a sign plate
## (issue #165).

const BUTTON_SIZE := Vector3(0.24, 0.16, 0.06)
const BUTTON_COLUMNS := 3
const BUTTON_STEP := Vector2(0.3, 0.22)
const BUTTON_ORIGIN := Vector3(-0.3, 1.2, 0.18)
const BUTTON_COLOR := Color(0.13, 0.14, 0.15)
const RESET_CAPTION := "СБРОС"
const CAPTION_SIZE := 26
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

var entered := PackedStringArray()
var last_result := -1
var _buttons: Array[Interactable] = []


func _ready() -> void:
	_reset.prompt = "СБРОСИТЬ ВВОД"
	_caption($ResetButton, RESET_CAPTION)
	_reset.interacted.connect(func() -> void:
		entered.clear()
		last_result = -1
		refresh())
	var glyphs := DreamKnowledge.glyphs()
	for index in glyphs.size():
		_buttons.append(_build_button(glyphs[index], index))
	Containment.stage_changed.connect(func(_id: StringName, _stage: int) -> void: refresh())
	GameState.state_loaded.connect(refresh)
	GameState.section_power_changed.connect(func(_section: StringName, _power: int) -> void: refresh())
	refresh()


## Enters one glyph; the sequence is checked once it has the knowledge's length.
func press(glyph: String) -> void:
	var id := DreamKnowledge.active_for(module_id)
	if id.is_empty():
		return
	entered.append(glyph)
	last_result = -1
	if entered.size() >= DreamKnowledge.code(id).size():
		last_result = DreamKnowledge.resync(module_id, entered)
		entered.clear()
	refresh()


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
		var slots := PackedStringArray()
		for index in DreamKnowledge.code(id).size():
			slots.append(entered[index] if index < entered.size() else EMPTY_SLOT)
		rows.append({"text": "Введите знаки печати:", "status": &""})
		rows.append({"text": DreamKnowledge.SEPARATOR.join(slots), "status": &"", "large": true})
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
	var text := UiStyle.sign_label(glyph)
	text.position = Vector3(0, 0, BUTTON_SIZE.z * 0.5 + 0.005)
	body.add_child(text)
	var interactable := Interactable.new()
	interactable.prompt = "ВВЕСТИ ЗНАК «%s»" % glyph
	interactable.set_meta(&"glyph", glyph)
	interactable.interacted.connect(press.bind(glyph))
	body.add_child(interactable)
	add_child(body)
	return interactable
