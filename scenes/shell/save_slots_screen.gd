class_name SaveSlotsScreen
extends CanvasLayer

## Slot list of the pause menu: save into a slot or load one. The autosave slot is
## read-only when saving; saving over a used slot asks first. Look: variant A of the shell
## (docs/ui/style-guide.md, issue #144) — the slot title and objective, the date on the right.

signal closed

enum Mode { SAVE, LOAD }

var mode: Mode = Mode.SAVE
var slot_buttons: Dictionary[String, ShellButton] = {}
var _note: Label
## Set while a confirmed overwrite is carried out.
var overwrite_confirmed := false


static func open(parent: Node, screen_mode: Mode) -> SaveSlotsScreen:
	var screen := SaveSlotsScreen.new()
	screen.mode = screen_mode
	screen.layer = 85
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(screen)
	return screen


func _ready() -> void:
	var column := ShellUI.screen(self, "Сохранить игру" if mode == Mode.SAVE else "Загрузить игру", 820.0)
	for slot in Saves.SLOTS:
		if mode == Mode.SAVE and slot == Saves.AUTO:
			continue
		slot_buttons[slot] = ShellUI.button(column, Saves.slot_title(slot), choose.bind(slot))
	_note = ShellUI.label(column, "", &"ShellNote")
	ShellUI.button(column, "Назад", close)
	refresh()


func refresh() -> void:
	for slot in slot_buttons:
		var used := Saves.exists(slot)
		var objective := Saves.objective(slot)
		slot_buttons[slot].text = Saves.slot_title(slot) + ((" — " + objective) if used and not objective.is_empty() else "")
		slot_buttons[slot].note = Saves.stamp(slot) if used else "ПУСТО"
		slot_buttons[slot].disabled = mode == Mode.LOAD and not used


func choose(slot: String) -> void:
	if mode == Mode.SAVE and Saves.exists(slot) and not overwrite_confirmed:
		ShellUI.confirm(self, "Перезаписать слот?", "Сохранение «%s» от %s будет заменено. Отменить это нельзя." % [Saves.slot_title(slot), Saves.stamp(slot)], "Перезаписать", func() -> void:
			overwrite_confirmed = true
			choose(slot)
			overwrite_confirmed = false)
		return
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
