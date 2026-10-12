class_name DocumentReader
extends CanvasLayer

## Full-screen reader for documents and the journal of read documents.
## Document: ↑↓/wheel scroll, Esc/E close (back to the journal when opened from it).
## Journal: ↑↓ choose, E/Enter open, Esc/J close. The player is locked while open.
## A document is drawn as paper of the complex (docs/ui/style-guide.md, issue #148):
## typewritten body, optional form header, stamps, a handwritten margin note or a fully
## handwritten sheet; redactions are the █ characters of the text itself.

signal closed

const SCENE_PATH := "res://objects/documents/document_reader.tscn"
const PLAYER_GROUP := &"player"
const SCROLL_STEP := 60
const SELECT_MARK := "> "
const OBJECTIVES_TITLE := "ЦЕЛИ"
const DOCUMENTS_TITLE := "ДОКУМЕНТЫ"
const CURRENT_MARK := ">  "
const DONE_MARK := "—  "
const MUTED := Color(0.38, 0.34, 0.28)
const META_COLOR := Color(0.36, 0.32, 0.26)
const TITLE_SIZE := 25
const BODY_SIZE := 19
const HAND_SIZE := 30
const SMALL_SIZE := 14
const STAMP_SIZE := 24
const NOTE_SIZE := 26
const STAMP_ANGLE := -11.0
const STAMP_STEP := Vector2(-36.0, 64.0)
const GRAIN_ALPHA := 0.16
const OBJECTIVE_META := &"objective_line"
const EMPTY_JOURNAL := "Журнал пуст. Найденные документы появятся здесь."

@onready var title_label: Label = $Paper/Margin/Rows/Title
@onready var meta_label: Label = $Paper/Margin/Rows/Meta
@onready var scroll: ScrollContainer = $Paper/Margin/Rows/Scroll
@onready var body_label: Label = $Paper/Margin/Rows/Scroll/Body
@onready var list_box: VBoxContainer = $Paper/Margin/Rows/List
@onready var hint_label: Label = $Paper/Margin/Rows/Hint
@onready var form_box: HBoxContainer = $Paper/Margin/Rows/Form
@onready var marks: Control = $Paper/Marks
@onready var _form_office: Label = $Paper/Margin/Rows/Form/Office
@onready var _form_number: Label = $Paper/Margin/Rows/Form/Number
@onready var _form_rule: ColorRect = $Paper/Margin/Rows/FormRule
@onready var _grain: TextureRect = $Paper/Grain

var document_id := ""
var in_journal := false
var selected := 0
var _from_journal := false


func _ready() -> void:
	_apply_style()


static func open_document_scene(tree: SceneTree, id: String) -> DocumentReader:
	var reader := _spawn(tree)
	reader.show_document(id)
	return reader


static func open_journal_scene(tree: SceneTree) -> DocumentReader:
	var reader := _spawn(tree)
	reader.show_journal()
	return reader


static func _spawn(tree: SceneTree) -> DocumentReader:
	var reader := (load(SCENE_PATH) as PackedScene).instantiate() as DocumentReader
	tree.root.add_child(reader)
	tree.call_group(PLAYER_GROUP, "set_controls_locked", true)
	return reader


func show_document(id: String, from_journal: bool = false) -> void:
	var document := DocumentLibrary.get_document(id)
	document_id = id
	in_journal = false
	_from_journal = from_journal
	title_label.text = str(document.get("title", ""))
	meta_label.text = str(document.get("meta", ""))
	meta_label.visible = not meta_label.text.is_empty()
	body_label.text = str(document.get("body", ""))
	_set_hand(bool(document.get("handwritten", false)))
	_show_form(document.get("form", {}))
	_show_marks(document.get("stamps", []), document.get("note", ""))
	scroll.visible = true
	scroll.scroll_vertical = 0
	list_box.visible = false
	hint_label.text = "↑↓ — прокрутка    %s / %s — %s" % [
		InputPromptFormatter.action_label(&"ui_cancel"), InputPromptFormatter.action_label(&"interact"),
		"к журналу" if from_journal else "закрыть"]


func show_journal() -> void:
	in_journal = true
	document_id = ""
	title_label.text = "ЖУРНАЛ"
	meta_label.text = "Цели и прочитанные документы"
	meta_label.visible = true
	scroll.visible = false
	list_box.visible = true
	_show_form({})
	_show_marks([], "")
	selected = clampi(selected, 0, maxi(DocumentLibrary.read_ids().size() - 1, 0))
	_fill_list()
	hint_label.text = "↑↓ — выбор    %s — открыть    %s — закрыть" % [
		InputPromptFormatter.action_label(&"interact"), InputPromptFormatter.action_label(&"ui_cancel")]


func close() -> void:
	get_tree().call_group(PLAYER_GROUP, "set_controls_locked", false)
	closed.emit()
	queue_free()


func _fill_list() -> void:
	for child in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()
	_add_objectives()
	var ids := DocumentLibrary.read_ids()
	if ids.is_empty():
		var empty := Label.new()
		empty.text = EMPTY_JOURNAL
		list_box.add_child(empty)
		return
	for index in ids.size():
		var label := Label.new()
		var title := str(DocumentLibrary.get_document(ids[index]).get("title", ids[index]))
		label.text = (SELECT_MARK if index == selected else "   ") + title
		label.add_theme_font_size_override(&"font_size", 21)
		label.add_theme_color_override(&"font_color", UiStyle.STAMP if index == selected else UiStyle.INK)
		list_box.add_child(label)


## Objectives section above the documents: the current one and the finished ones.
func _add_objectives() -> void:
	var current := GameState.objective_text
	var done := Objectives.completed_texts()
	if current.is_empty() and done.is_empty():
		return
	_add_line(OBJECTIVES_TITLE, 20, MUTED)
	if not current.is_empty():
		_add_line(CURRENT_MARK + current, 21, UiStyle.INK)
	for index in range(done.size() - 1, -1, -1):
		_add_line(DONE_MARK + done[index], 20, MUTED)
	_add_line(DOCUMENTS_TITLE, 20, MUTED)


func _add_line(text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.set_meta(OBJECTIVE_META, true)
	list_box.add_child(label)



func _apply_style() -> void:
	var paper_theme := Theme.new()
	paper_theme.default_font = UiStyle.FONT_BODY
	paper_theme.default_font_size = 20
	paper_theme.set_color(&"font_color", &"Label", UiStyle.INK)
	$Paper.theme = paper_theme
	title_label.add_theme_font_override(&"font", UiStyle.FONT_BODY_BOLD)
	title_label.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	meta_label.add_theme_font_override(&"font", UiStyle.FONT_MONO)
	meta_label.add_theme_font_size_override(&"font_size", SMALL_SIZE + 1)
	meta_label.add_theme_color_override(&"font_color", META_COLOR)
	for label: Label in [_form_office, _form_number]:
		label.add_theme_font_override(&"font", UiStyle.FONT_SCREEN_OLD)
		label.add_theme_font_size_override(&"font_size", SMALL_SIZE)
		label.add_theme_color_override(&"font_color", UiStyle.INK)
	hint_label.add_theme_font_override(&"font", UiStyle.FONT_MONO)
	hint_label.add_theme_font_size_override(&"font_size", SMALL_SIZE)
	hint_label.add_theme_color_override(&"font_color", META_COLOR)
	_set_hand(false)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.35
	noise.fractal_octaves = 3
	var grain := NoiseTexture2D.new()
	grain.width = 256
	grain.height = 256
	grain.seamless = true
	grain.noise = noise
	_grain.texture = grain
	_grain.modulate = Color(0.35, 0.27, 0.16, GRAIN_ALPHA)


## Typewritten body, or the whole sheet in a hand (notes of the staff).
func _set_hand(handwritten: bool) -> void:
	body_label.add_theme_font_override(&"font", UiStyle.FONT_HAND if handwritten else UiStyle.FONT_SCREEN_OLD)
	body_label.add_theme_font_size_override(&"font_size", HAND_SIZE if handwritten else BODY_SIZE)
	body_label.add_theme_color_override(&"font_color", UiStyle.PENCIL if handwritten else UiStyle.INK)


## Header of an official form: office on the left, form number and copy on the right.
func _show_form(form: Dictionary) -> void:
	_form_office.text = str(form.get("office", ""))
	_form_number.text = "\n".join(PackedStringArray([str(form.get("number", "")), str(form.get("copy", ""))])).strip_edges()
	form_box.visible = not form.is_empty()
	_form_rule.visible = form_box.visible


## Stamps in the upper right corner and a pencil note at the bottom, over the text.
func _show_marks(stamps: Array, note: String) -> void:
	for child in marks.get_children():
		marks.remove_child(child)
		child.queue_free()
	var paper_size := ($Paper as Control).size
	for index in stamps.size():
		var stamp := Label.new()
		stamp.name = "Stamp%d" % index
		stamp.text = str(stamps[index])
		stamp.add_theme_font_override(&"font", UiStyle.FONT_DISPLAY_STRONG)
		stamp.add_theme_font_size_override(&"font_size", STAMP_SIZE)
		stamp.add_theme_color_override(&"font_color", Color(UiStyle.STAMP, 0.8))
		var frame := StyleBoxFlat.new()
		frame.draw_center = false
		frame.border_color = Color(UiStyle.STAMP, 0.75)
		frame.set_border_width_all(3)
		frame.set_content_margin_all(8)
		frame.content_margin_top = 2
		frame.content_margin_bottom = 2
		stamp.add_theme_stylebox_override(&"normal", frame)
		marks.add_child(stamp)
		stamp.reset_size()
		stamp.pivot_offset = stamp.size * 0.5
		stamp.rotation_degrees = STAMP_ANGLE + index * 7.0
		stamp.position = Vector2(paper_size.x - stamp.size.x - 70.0, 96.0) + STAMP_STEP * index
	if not note.is_empty():
		var pencil := Label.new()
		pencil.name = "Note"
		pencil.text = note
		pencil.add_theme_font_override(&"font", UiStyle.FONT_HAND)
		pencil.add_theme_font_size_override(&"font_size", NOTE_SIZE)
		pencil.add_theme_color_override(&"font_color", UiStyle.PENCIL)
		marks.add_child(pencil)
		pencil.reset_size()
		pencil.rotation_degrees = -3.0
		pencil.position = Vector2(paper_size.x - pencil.size.x - 60.0, paper_size.y - pencil.size.y - 64.0)


## Journal lines of read documents (without the objectives section).
func document_lines() -> Array[Label]:
	var lines: Array[Label] = []
	for child in list_box.get_children():
		if child is Label and not child.has_meta(OBJECTIVE_META):
			lines.append(child)
	return lines


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and scroll.visible:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			scroll.scroll_vertical += SCROLL_STEP * (1 if button.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton) or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	var down := event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"move_back")
	var up := event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"move_forward")
	var confirm := event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")
	var cancel := event.is_action_pressed(&"ui_cancel")
	if in_journal:
		var count := DocumentLibrary.read_ids().size()
		if cancel or event.is_action_pressed(&"journal"):
			close()
		elif count > 0 and (down or up):
			selected = (selected + (1 if down else -1) + count) % count
			_fill_list()
		elif count > 0 and confirm:
			show_document(DocumentLibrary.read_ids()[selected], true)
		return
	if down or up:
		scroll.scroll_vertical += SCROLL_STEP * (1 if down else -1)
	elif cancel or confirm:
		if _from_journal:
			show_journal()
		else:
			close()
