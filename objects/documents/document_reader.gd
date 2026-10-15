class_name DocumentReader
extends CanvasLayer

## Full-screen reader for documents and the journal of read documents.
## Document: ↑↓/wheel scroll, Esc/E close (back to the journal when opened from it).
## Journal: ↑↓ choose, E/Enter open, Esc/J close. The player is locked while open.
## A document is drawn as paper of the complex (docs/ui/style-guide.md, issue #148):
## typewritten body, optional form header, stamps, a handwritten margin note or a fully
## handwritten sheet; redactions are the █ characters of the text itself. Both lie on a
## PaperSheet with a torn edge (#223). The journal is the hero's own notebook: a squared page
## written by hand in ballpoint — headings, objectives, dream sketches and read documents.

signal closed

const SCENE_PATH := "res://objects/documents/document_reader.tscn"
const PLAYER_GROUP := &"player"
const SCROLL_STEP := 60
## Caveat has no arrows, boxes or check marks: the notebook marks with what a pen draws.
const SELECT_MARK := "> "
const UNSELECTED_MARK := "    "
const JOURNAL_TITLE := "Журнал"
const JOURNAL_META := "цели, сны и прочитанные бумаги"
const OBJECTIVES_TITLE := "Что делать"
const DOCUMENTS_TITLE := "Прочитано"
const CURRENT_MARK := "•  "
const DONE_MARK := "—  "
## Struck-out and finished lines of the notebook: the same pen, faded.
const PEN_FADED := Color(UiStyle.PEN, 0.55)
const META_COLOR := Color(0.36, 0.32, 0.26)
const TITLE_SIZE := 25
const BODY_SIZE := 19
const HAND_SIZE := 30
const SMALL_SIZE := 14
const STAMP_SIZE := 24
const NOTE_SIZE := 26
const STAMP_ANGLE := -11.0
const STAMP_STEP := Vector2(-36.0, 64.0)
const HINT_SIZE := 24
## Caveat is small for its size: the notebook is written larger than the typed sheets.
const JOURNAL_TITLE_SIZE := 50
const JOURNAL_META_SIZE := 26
const SECTION_SIZE := 36
const ENTRY_SIZE := 32
const DONE_SIZE := 30
const MARGIN_LEFT := 44
## Text of the notebook starts right of the red margin of PaperSheet.
const JOURNAL_MARGIN_LEFT := 84
const OBJECTIVE_META := &"objective_line"
const EMPTY_JOURNAL := "Журнал пуст. Найденные документы появятся здесь."

@onready var title_label: Label = $Paper/Margin/Rows/Title
@onready var meta_label: Label = $Paper/Margin/Rows/Meta
@onready var scroll: ScrollContainer = $Paper/Margin/Rows/Scroll
@onready var body_label: Label = $Paper/Margin/Rows/Scroll/Body
@onready var list_box: VBoxContainer = $Paper/Margin/Rows/ListScroll/List
@onready var list_scroll: ScrollContainer = $Paper/Margin/Rows/ListScroll
@onready var hint_label: Label = $Paper/Margin/Rows/Hint
@onready var form_box: HBoxContainer = $Paper/Margin/Rows/Form
@onready var marks: Control = $Paper/Marks
@onready var _form_office: Label = $Paper/Margin/Rows/Form/Office
@onready var _form_number: Label = $Paper/Margin/Rows/Form/Number
@onready var _form_rule: ColorRect = $Paper/Margin/Rows/FormRule
@onready var sheet: PaperSheet = $Paper/Sheet
@onready var _margin: MarginContainer = $Paper/Margin

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
	_set_look(false)
	_set_hand(bool(document.get("handwritten", false)))
	_show_form(document.get("form", {}))
	_show_marks(document.get("stamps", []), document.get("note", ""))
	scroll.visible = true
	scroll.scroll_vertical = 0
	list_scroll.visible = false
	hint_label.text = "вверх/вниз — листать    %s / %s — %s" % [
		InputPromptFormatter.action_label(&"ui_cancel"), InputPromptFormatter.action_label(&"interact"),
		"к журналу" if from_journal else "закрыть"]


func show_journal() -> void:
	in_journal = true
	document_id = ""
	title_label.text = JOURNAL_TITLE
	meta_label.text = JOURNAL_META
	meta_label.visible = true
	scroll.visible = false
	list_scroll.visible = true
	_set_look(true)
	_show_form({})
	_show_marks([], "")
	selected = clampi(selected, 0, maxi(DocumentLibrary.read_ids().size() - 1, 0))
	_fill_list()
	hint_label.text = "вверх/вниз — выбор    %s — открыть    %s — закрыть" % [
		InputPromptFormatter.action_label(&"interact"), InputPromptFormatter.action_label(&"ui_cancel")]


func close() -> void:
	get_tree().call_group(PLAYER_GROUP, "set_controls_locked", false)
	closed.emit()
	queue_free()


func _fill_list() -> void:
	for child in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()
	var sections := _add_objectives()
	sections = _add_knowledge() or sections
	if sections:
		_add_heading(DOCUMENTS_TITLE)
	var ids := DocumentLibrary.read_ids()
	if ids.is_empty():
		var empty := _add_line(EMPTY_JOURNAL, DONE_SIZE, PEN_FADED)
		empty.remove_meta(OBJECTIVE_META)
		return
	var chosen: Label
	for index in ids.size():
		var title := entry_title(str(DocumentLibrary.get_document(ids[index]).get("title", ids[index])))
		var label := _add_line((SELECT_MARK if index == selected else UNSELECTED_MARK) + title, ENTRY_SIZE, UiStyle.PEN if index == selected else PEN_FADED)
		label.remove_meta(OBJECTIVE_META)
		if index == selected:
			label.add_theme_font_override(&"font", UiStyle.FONT_HAND_BOLD)
			chosen = label
	if chosen:
		_scroll_to.call_deferred(chosen)


## The hero copies a document's title into the notebook in ordinary case.
static func entry_title(title: String) -> String:
	return title.substr(0, 1).to_upper() + title.substr(1).to_lower() if not title.is_empty() else title


func _scroll_to(line: Label) -> void:
	if is_instance_valid(line) and line.is_inside_tree():
		list_scroll.ensure_control_visible(line)


## Objectives section above the documents: the current one and the finished ones.
## Returns true when the section was added.
func _add_objectives() -> bool:
	var current := GameState.objective_text
	var done := Objectives.completed_texts()
	if current.is_empty() and done.is_empty():
		return false
	_add_heading(OBJECTIVES_TITLE)
	if not current.is_empty():
		_add_line(CURRENT_MARK + current, ENTRY_SIZE, UiStyle.PEN)
	for index in range(done.size() - 1, -1, -1):
		_add_line(DONE_MARK + done[index], DONE_SIZE, PEN_FADED)
	return true


## Title of the dream knowledge section (data/dreams/knowledge.json, #200).
static func knowledge_title() -> String:
	return str(DreamKnowledge.text("journal_section"))


## Knowledge remembered in dreams (DreamKnowledge), newest first, each with its sketch
## (DreamSketch); spent entries are muted.
func _add_knowledge() -> bool:
	var entries := DreamKnowledge.journal_entries()
	if entries.is_empty():
		return false
	_add_heading(knowledge_title())
	for entry in entries:
		var used := bool(entry["used"])
		_add_line((DONE_MARK if used else CURRENT_MARK) + str(entry["text"]), DONE_SIZE if used else ENTRY_SIZE, PEN_FADED if used else UiStyle.PEN)
		var sketch := DreamSketch.create(entry)
		sketch.line_color = UiStyle.PENCIL
		sketch.set_meta(OBJECTIVE_META, true)
		list_box.add_child(sketch)
	return true


## A section heading of the notebook: bold hand, underlined by the page's ruling.
func _add_heading(text: String) -> Label:
	var label := _add_line(text, SECTION_SIZE, UiStyle.PEN)
	label.add_theme_font_override(&"font", UiStyle.FONT_HAND_BOLD)
	return label


## A handwritten line of the notebook. Every line but a document entry carries OBJECTIVE_META.
func _add_line(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override(&"font", UiStyle.FONT_HAND)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.set_meta(OBJECTIVE_META, true)
	list_box.add_child(label)
	return label



func _apply_style() -> void:
	var paper_theme := Theme.new()
	paper_theme.default_font = UiStyle.FONT_BODY
	paper_theme.default_font_size = 20
	paper_theme.set_color(&"font_color", &"Label", UiStyle.INK)
	$Paper.theme = paper_theme
	meta_label.add_theme_font_size_override(&"font_size", SMALL_SIZE + 1)
	for label: Label in [_form_office, _form_number]:
		label.add_theme_font_override(&"font", UiStyle.FONT_SCREEN_OLD)
		label.add_theme_font_size_override(&"font_size", SMALL_SIZE)
		label.add_theme_color_override(&"font_color", UiStyle.INK)
	# Key hints are the hero's pencil note on the sheet's corner, not an interface strip.
	hint_label.add_theme_font_override(&"font", UiStyle.FONT_HAND)
	hint_label.add_theme_font_size_override(&"font_size", HINT_SIZE)
	hint_label.add_theme_color_override(&"font_color", UiStyle.PENCIL)
	_set_hand(false)


## A document's own sheet, or the squared notebook page of the journal written in pen.
func _set_look(journal: bool) -> void:
	sheet.ruled = journal
	_margin.add_theme_constant_override(&"margin_left", JOURNAL_MARGIN_LEFT if journal else MARGIN_LEFT)
	title_label.add_theme_font_override(&"font", UiStyle.FONT_HAND_BOLD if journal else UiStyle.FONT_BODY_BOLD)
	title_label.add_theme_font_size_override(&"font_size", JOURNAL_TITLE_SIZE if journal else TITLE_SIZE)
	title_label.add_theme_color_override(&"font_color", UiStyle.PEN if journal else UiStyle.INK)
	meta_label.add_theme_font_override(&"font", UiStyle.FONT_HAND if journal else UiStyle.FONT_MONO)
	meta_label.add_theme_font_size_override(&"font_size", JOURNAL_META_SIZE if journal else SMALL_SIZE + 1)
	meta_label.add_theme_color_override(&"font_color", PEN_FADED if journal else META_COLOR)


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
