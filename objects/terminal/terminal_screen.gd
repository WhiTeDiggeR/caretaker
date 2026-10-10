class_name TerminalScreen
extends CanvasLayer

## Full-screen terminal UI. Types the lines of each screen, then lists its options.
## Keys: up/down or digits choose, Enter/E confirm, Enter/E while typing shows the whole
## screen, Esc leaves. The player's controls are locked while the terminal is open.

signal closed

const CHARS_PER_SECOND := 140.0
const AUTO_NEXT_PAUSE := 0.8
const PLAYER_GROUP := &"player"
const SELECT_MARK := "▶ "
const LOCKED_COLOR := Color(0.45, 0.55, 0.5)
const OPTION_COLOR := Color(0.55, 1.0, 0.75)

@onready var title_label: Label = $Panel/Margin/Rows/Title
@onready var body_label: Label = $Panel/Margin/Rows/Body
@onready var options_box: VBoxContainer = $Panel/Margin/Rows/Options
@onready var hint_label: Label = $Panel/Margin/Rows/Hint

var program: TerminalProgram
var screen_id := ""
var view: Dictionary = {}
var selected := 0
var typing := false

var _queue: Array[Dictionary] = []
var _shown_text := ""
var _current := ""
var _typed := 0.0
var _wait := 0.0
var _auto_next := -1.0


func open(terminal_program: TerminalProgram) -> void:
	program = terminal_program
	title_label.text = program.title
	hint_label.text = "↑↓ / 1–9 — выбор    %s — подтвердить    %s — выйти" % [
		InputPromptFormatter.action_label(&"interact"), InputPromptFormatter.action_label(&"ui_cancel")]
	get_tree().call_group(PLAYER_GROUP, "set_controls_locked", true)
	show_screen(program.start)


func close() -> void:
	get_tree().call_group(PLAYER_GROUP, "set_controls_locked", false)
	closed.emit()
	queue_free()


func show_screen(id: String) -> void:
	view = program.enter(id)
	screen_id = view["id"]
	selected = 0
	_queue = (view["lines"] as Array).duplicate()
	_shown_text = ""
	_current = ""
	_typed = 0.0
	_wait = 0.0
	_auto_next = -1.0
	typing = true
	_clear_options()
	_next_line()


func finish_typing() -> void:
	while typing:
		_shown_text += _current + "\n"
		_current = ""
		_next_line()
	body_label.text = _shown_text


func choose(option_position: int) -> void:
	var options: Array = view.get("options", [])
	if typing or option_position < 0 or option_position >= options.size():
		return
	var option: Dictionary = options[option_position]
	if not option["available"]:
		return
	var target := program.choose(screen_id, option["index"])
	if target == "exit":
		close()
	elif not target.is_empty():
		show_screen(target)


func _process(delta: float) -> void:
	if _auto_next >= 0.0:
		_auto_next -= delta
		if _auto_next < 0.0:
			show_screen(view["next"])
		return
	if not typing:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	_typed += delta * CHARS_PER_SECOND
	var count := mini(int(_typed), _current.length())
	body_label.text = _shown_text + _current.substr(0, count)
	if count >= _current.length():
		_shown_text += _current + "\n"
		_next_line()


func _next_line() -> void:
	if _queue.is_empty():
		typing = false
		body_label.text = _shown_text
		view["options"] = program.complete(screen_id)
		_show_options()
		return
	var line: Dictionary = _queue.pop_front()
	_current = str(line["text"])
	_wait = float(line["wait"])
	_typed = 0.0


func _show_options() -> void:
	_clear_options()
	var options: Array = view.get("options", [])
	if options.is_empty() and not str(view.get("next", "")).is_empty():
		_auto_next = AUTO_NEXT_PAUSE
		return
	for position in options.size():
		var option: Dictionary = options[position]
		var label := Label.new()
		label.add_theme_font_size_override(&"font_size", 22)
		options_box.add_child(label)
	_refresh_options()


func _refresh_options() -> void:
	var options: Array = view.get("options", [])
	for position in options_box.get_child_count():
		var option: Dictionary = options[position]
		var label := options_box.get_child(position) as Label
		var text := "%d. %s" % [position + 1, option["text"]]
		if not option["available"] and not str(option["locked_text"]).is_empty():
			text += " — " + str(option["locked_text"])
		label.text = (SELECT_MARK if position == selected else "   ") + text
		label.add_theme_color_override(&"font_color", OPTION_COLOR if option["available"] else LOCKED_COLOR)


func _clear_options() -> void:
	for child in options_box.get_children():
		child.queue_free()
		options_box.remove_child(child)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"ui_cancel"):
		close()
		return
	var confirm := event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"interact")
	if typing:
		if confirm:
			finish_typing()
		return
	var count := options_box.get_child_count()
	if count == 0:
		return
	if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"move_back"):
		selected = (selected + 1) % count
		_refresh_options()
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"move_forward"):
		selected = (selected - 1 + count) % count
		_refresh_options()
	elif confirm:
		choose(selected)
	else:
		var key := (event as InputEventKey).keycode
		if key >= KEY_1 and key <= KEY_9:
			choose(key - KEY_1)
