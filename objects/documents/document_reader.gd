class_name DocumentReader
extends CanvasLayer

## Full-screen reader for documents and the journal of read documents.
## Document: ↑↓/wheel scroll, Esc/E close (back to the journal when opened from it).
## Journal: ↑↓ choose, E/Enter open, Esc/J close. The player is locked while open.

signal closed

const SCENE_PATH := "res://objects/documents/document_reader.tscn"
const PLAYER_GROUP := &"player"
const SCROLL_STEP := 60
const SELECT_MARK := "▶ "
const EMPTY_JOURNAL := "Журнал пуст. Найденные документы появятся здесь."

@onready var title_label: Label = $Paper/Margin/Rows/Title
@onready var meta_label: Label = $Paper/Margin/Rows/Meta
@onready var scroll: ScrollContainer = $Paper/Margin/Rows/Scroll
@onready var body_label: Label = $Paper/Margin/Rows/Scroll/Body
@onready var list_box: VBoxContainer = $Paper/Margin/Rows/List
@onready var hint_label: Label = $Paper/Margin/Rows/Hint

var document_id := ""
var in_journal := false
var selected := 0
var _from_journal := false


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
	meta_label.text = "Прочитанные документы"
	meta_label.visible = true
	scroll.visible = false
	list_box.visible = true
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
		label.add_theme_font_size_override(&"font_size", 22)
		list_box.add_child(label)


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
