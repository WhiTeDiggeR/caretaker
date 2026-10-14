class_name TerminalScreen
extends CanvasLayer

## Full-screen terminal UI. Types the lines of each screen, then lists its options. Looks like
## the screen of its program's era (ScreenStyle: casing, phosphor, CRT picture, typing).
## Keys: up/down or digits choose, Enter/E confirm, Enter/E while typing shows the whole
## screen, Enter/E on a step screen (no options, a `next`) pages on (#219), Esc leaves. The player's controls are locked while the terminal is open.

signal closed

## A key click every N printed characters (not every one: 140 per second is a buzz).
const TYPE_SOUND_EVERY := 6
## Prompt under a step screen that waits for a key press before the next one (#219).
const NEXT_PROMPT := "%s — далее"
const PLAYER_GROUP := &"player"
const SELECT_MARK := "> "
const HINT_SIZE := 16

@onready var title_label: Label = $Panel/Margin/Rows/Title
@onready var body_label: Label = $Panel/Margin/Rows/Body
@onready var options_box: VBoxContainer = $Panel/Margin/Rows/Options
@onready var hint_label: Label = $Panel/Margin/Rows/Hint
@onready var _panel: PanelContainer = $Panel
@onready var _rule: ColorRect = $Panel/Margin/Rows/Rule
@onready var _crt: ColorRect = $Panel/Crt

var program: TerminalProgram
var style: ScreenStyle
var screen_id := ""
var _typed_sound_step := 0
var view: Dictionary = {}
var selected := 0
var typing := false

var _queue: Array[Dictionary] = []
var _shown_text := ""
var _current := ""
var _typed := 0.0
var _wait := 0.0
## A step screen is printed and waits for a key press to show `view.next`.
var waiting_next := false


## `emergency_power` makes the picture flicker (the section runs on its reserve line).
func open(terminal_program: TerminalProgram, emergency_power: bool = false) -> void:
	program = terminal_program
	_apply_style(ScreenStyle.for_era(program.era), emergency_power)
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
	waiting_next = false
	typing = true
	_clear_options()
	_next_line()


func finish_typing() -> void:
	while typing:
		_shown_text += _current + "\n"
		_current = ""
		_next_line()
	body_label.text = _shown_text


## Shows the next screen of a printed step screen; false when the screen does not wait.
func advance() -> bool:
	if not waiting_next:
		return false
	Sfx.play(&"terminal_beep")
	show_screen(view["next"])
	return true


func choose(option_position: int) -> void:
	var options: Array = view.get("options", [])
	if typing or option_position < 0 or option_position >= options.size():
		return
	var option: Dictionary = options[option_position]
	if not option["available"]:
		Sfx.play(&"terminal_error")
		return
	Sfx.play(&"terminal_beep")
	var target := program.choose(screen_id, option["index"])
	if target == "exit":
		close()
	elif not target.is_empty():
		show_screen(target)


func _process(delta: float) -> void:
	if not typing:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	if style.line_by_line:
		_typed = _current.length()
	else:
		_typed += delta * style.chars_per_second
	var count := mini(int(_typed), _current.length())
	if count / TYPE_SOUND_EVERY != _typed_sound_step:
		_typed_sound_step = count / TYPE_SOUND_EVERY
		Sfx.play(&"terminal_type")
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
	_wait = float(line["wait"]) + (style.line_delay if style.line_by_line else 0.0)
	_typed = 0.0


func _show_options() -> void:
	_clear_options()
	var options: Array = view.get("options", [])
	if options.is_empty() and not str(view.get("next", "")).is_empty():
		waiting_next = true
		var prompt := Label.new()
		options_box.add_child(prompt)
		style.style_label(prompt, style.dim)
		prompt.text = "  " + NEXT_PROMPT % InputPromptFormatter.action_label(&"interact")
		return
	for position in options.size():
		var option: Dictionary = options[position]
		var label := Label.new()
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
		_style_option(label, text, position == selected, option["available"])


## Selected line: inverted on old CRTs, a marker on the others; locked options are dim.
func _style_option(label: Label, text: String, is_selected: bool, available: bool) -> void:
	var color := style.phosphor if available else style.dim
	var inverted := is_selected and style.invert_selection
	style.style_label(label, style.background if inverted else color)
	if inverted:
		label.text = " " + text + " "
		var box := StyleBoxFlat.new()
		box.bg_color = color
		label.add_theme_stylebox_override(&"normal", box)
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		label.remove_theme_constant_override(&"shadow_outline_size")
	else:
		label.text = (SELECT_MARK if is_selected else "  ") + text
		label.remove_theme_stylebox_override(&"normal")
		label.size_flags_horizontal = Control.SIZE_FILL


func _apply_style(screen_style: ScreenStyle, emergency_power: bool) -> void:
	style = screen_style
	_panel.add_theme_stylebox_override(&"panel", style.panel_box())
	style.style_label(title_label, style.title_color, style.title_size, style.title_font)
	style.style_label(body_label, style.phosphor)
	style.style_label(hint_label, style.dim, HINT_SIZE, style.hint_font)
	hint_label.remove_theme_constant_override(&"shadow_outline_size")
	_rule.color = Color(style.dim, 0.7)
	_crt.material = style.crt_material(emergency_power)
	_crt.visible = _crt.material != null


func _clear_options() -> void:
	for child in options_box.get_children():
		child.queue_free()
		options_box.remove_child(child)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton) or not event.is_pressed():
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
	if waiting_next:
		if confirm:
			advance()
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
	elif event is InputEventKey:
		var key := (event as InputEventKey).keycode
		if key >= KEY_1 and key <= KEY_9:
			choose(key - KEY_1)
