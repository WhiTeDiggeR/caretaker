class_name SaveSlotsScreen
extends CanvasLayer

## Slot list of the pause menu: save into a slot or load one. The autosave slot is
## read-only when saving.

signal closed

enum Mode { SAVE, LOAD }

var mode: Mode = Mode.SAVE
var slot_buttons: Dictionary[String, Button] = {}
var _note: Label


static func open(parent: Node, screen_mode: Mode) -> SaveSlotsScreen:
	var screen := SaveSlotsScreen.new()
	screen.mode = screen_mode
	screen.layer = 85
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(screen)
	return screen


func _ready() -> void:
	var column := ShellUI.screen(self, "СОХРАНИТЬ ИГРУ" if mode == Mode.SAVE else "ЗАГРУЗИТЬ ИГРУ", 760.0)
	for slot in Saves.SLOTS:
		if mode == Mode.SAVE and slot == Saves.AUTO:
			continue
		var button := ShellUI.button(column, "", choose.bind(slot))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_buttons[slot] = button
	_note = Label.new()
	_note.add_theme_color_override(&"font_color", ShellUI.MUTED)
	column.add_child(_note)
	ShellUI.button(column, "Назад", close)
	refresh()


func refresh() -> void:
	for slot in slot_buttons:
		slot_buttons[slot].text = Saves.describe(slot)
		slot_buttons[slot].disabled = mode == Mode.LOAD and not Saves.exists(slot)


func choose(slot: String) -> void:
	if mode == Mode.SAVE:
		var result := Saves.write(slot, get_tree())
		_note.text = "Сохранено: %s." % Saves.slot_title(slot) if result == OK else "Не удалось сохранить (ошибка %d)." % result
		refresh()
	else:
		close()
		Shell.load_game(slot)


func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
