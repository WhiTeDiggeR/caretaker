class_name ResyncPanel
extends StaticBody3D

## Capsule resync panel of a module (D7, docs/game_design/03-first-dream.md): the hero
## enters the glyphs remembered at the dream's seal. The sequence is checked once it is
## complete; a match calms the sleep, a mistake disturbs it and the input starts over.
## Glyph buttons are built from data/dreams/knowledge.json.

const BUTTON_SIZE := Vector3(0.24, 0.16, 0.06)
const BUTTON_COLUMNS := 3
const BUTTON_STEP := Vector2(0.3, 0.22)
const BUTTON_ORIGIN := Vector3(-0.3, 1.2, 0.18)
const BUTTON_COLOR := Color(0.35, 0.3, 0.45)
const EMPTY_SLOT := "_"
const LOCK_NO_KNOWLEDGE := "НУЖНЫ ЗНАКИ ИЗ СНА"
const LOCK_AWAKE := "ОБЪЕКТ БОДРСТВУЕТ"
const NO_KNOWLEDGE_LINES := "Нет данных для ресинхронизации.\nНужны знаки печати из сна модуля:\nпогружение → печать → врата."
const SYNCED_LINE := "СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА.\nСон стабилен."
const WRONG_LINE := "ОШИБКА СИНХРОНИЗАЦИИ.\nНестабильность выросла. Повторите ввод."
const AWAKE_LINE := "Объект бодрствует.\nРесинхронизация невозможна."

@export var module_id: StringName = &"module_4"

@onready var _status: Label3D = $Status
@onready var _reset: Interactable = $ResetButton/Interactable

var entered := PackedStringArray()
var last_result := -1
var _buttons: Array[Interactable] = []


func _ready() -> void:
	_reset.prompt = "СБРОСИТЬ ВВОД"
	_reset.interacted.connect(func() -> void:
		entered.clear()
		last_result = -1
		refresh())
	var glyphs := DreamKnowledge.glyphs()
	for index in glyphs.size():
		_buttons.append(_build_button(glyphs[index], index))
	Containment.stage_changed.connect(func(_id: StringName, _stage: int) -> void: refresh())
	GameState.state_loaded.connect(refresh)
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
	var lines := PackedStringArray(["РЕСИНХРОНИЗАЦИЯ КАПСУЛЫ · %s" % label])
	var id := DreamKnowledge.active_for(module_id)
	var lock := ""
	if Containment.is_awake(module_id):
		lock = LOCK_AWAKE
		lines.append(AWAKE_LINE)
	elif last_result == DreamKnowledge.Result.SYNCED:
		lines.append(SYNCED_LINE)
	if lock.is_empty() and id.is_empty():
		lock = LOCK_NO_KNOWLEDGE
		if last_result != DreamKnowledge.Result.SYNCED:
			lines.append(NO_KNOWLEDGE_LINES)
	elif lock.is_empty():
		if last_result == DreamKnowledge.Result.WRONG:
			lines.append(WRONG_LINE)
		var slots := PackedStringArray()
		for index in DreamKnowledge.code(id).size():
			slots.append(entered[index] if index < entered.size() else EMPTY_SLOT)
		lines.append("Введите знаки печати:")
		lines.append(DreamKnowledge.SEPARATOR.join(slots))
	_status.text = "\n".join(lines)
	for button in _buttons:
		button.available = lock.is_empty()
		button.unavailable_prompt = lock
	_reset.available = lock.is_empty() and not entered.is_empty()
	_reset.unavailable_prompt = ""


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
	var text := Label3D.new()
	text.text = glyph
	text.pixel_size = 0.0015
	text.font_size = 40
	text.outline_size = 6
	text.position = Vector3(0, 0, BUTTON_SIZE.z * 0.5 + 0.005)
	body.add_child(text)
	var interactable := Interactable.new()
	interactable.prompt = "ВВЕСТИ ЗНАК «%s»" % glyph
	interactable.set_meta(&"glyph", glyph)
	interactable.interacted.connect(press.bind(glyph))
	body.add_child(interactable)
	add_child(body)
	return interactable
