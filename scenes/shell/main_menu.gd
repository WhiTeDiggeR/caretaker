extends Control

## Main menu: continue, load a chosen save, new game, settings, quit; the test range in
## debug builds.

var continue_button: Button
var load_button: Button
var buttons: VBoxContainer


func _ready() -> void:
	theme = ShellUI.theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var background := ColorRect.new()
	background.color = Color(0.04, 0.045, 0.05)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var stripe := ColorRect.new()
	stripe.color = Color(ShellUI.ACCENT, 0.85)
	stripe.position = Vector2(96, 0)
	stripe.size = Vector2(6, 4000)
	add_child(stripe)
	var column := VBoxContainer.new()
	column.position = Vector2(140, 220)
	column.custom_minimum_size = Vector2(420, 0)
	column.add_theme_constant_override(&"separation", 14)
	add_child(column)
	var title := Label.new()
	title.text = ShellUI.TITLE
	title.add_theme_font_size_override(&"font_size", 64)
	title.add_theme_color_override(&"font_color", ShellUI.TEXT)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Временный смотритель комплекса"
	subtitle.add_theme_color_override(&"font_color", ShellUI.MUTED)
	column.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 36)
	column.add_child(spacer)
	buttons = VBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 10)
	column.add_child(buttons)
	continue_button = ShellUI.button(buttons, "Продолжить", _on_continue)
	load_button = ShellUI.button(buttons, "Загрузить игру", open_load)
	var new_game := ShellUI.button(buttons, "Новая игра", Shell.new_game)
	if OS.is_debug_build():
		ShellUI.button(buttons, "Полигон (отладка)", Shell.start_sandbox)
	ShellUI.button(buttons, "Настройки", func() -> void: SettingsScreen.open(self))
	ShellUI.button(buttons, "Выход", Shell.quit_game)
	refresh()
	(continue_button if not continue_button.disabled else new_game).grab_focus.call_deferred()


func refresh() -> void:
	continue_button.disabled = Saves.latest().is_empty()
	load_button.disabled = continue_button.disabled


## Slot list for loading; focus returns to the menu when it is closed.
func open_load() -> SaveSlotsScreen:
	var screen := SaveSlotsScreen.open(self, SaveSlotsScreen.Mode.LOAD)
	screen.closed.connect(func() -> void:
		if is_inside_tree():
			load_button.grab_focus())
	return screen


func _on_continue() -> void:
	Shell.load_game(Saves.latest())
