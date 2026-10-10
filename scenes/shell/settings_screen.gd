class_name SettingsScreen
extends CanvasLayer

## Settings screen of the main menu and the pause menu. Changes apply at once and are
## saved when the screen closes. A key row waits for the next key (Esc cancels).

signal closed

var waiting_action: StringName = &""
var key_buttons: Dictionary[StringName, Button] = {}
var _note: Label


static func open(parent: Node) -> SettingsScreen:
	var screen := SettingsScreen.new()
	screen.layer = 85
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(screen)
	return screen


func _ready() -> void:
	var column := ShellUI.screen(self, "НАСТРОЙКИ", 760.0)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override(&"separation", 10)
	scroll.add_child(rows)

	_section(rows, "Звук")
	for bus in Settings.BUSES:
		_slider(rows, Settings.BUS_NAMES[bus], 0.0, 100.0, 1.0, Settings.volume[bus], "%d %%",
				func(value: float) -> void: Settings.set_volume(bus, value))
	_section(rows, "Мышь и обзор")
	_slider(rows, "Чувствительность мыши", Settings.SENSITIVITY_RANGE.x, Settings.SENSITIVITY_RANGE.y, 0.05,
			Settings.mouse_multiplier, "×%.2f", Settings.set_mouse_multiplier)
	var invert := CheckBox.new()
	invert.text = "Инвертировать вертикаль"
	invert.button_pressed = Settings.invert_y
	invert.toggled.connect(Settings.set_invert_y)
	rows.add_child(invert)
	_slider(rows, "Поле зрения", Settings.FOV_RANGE.x, Settings.FOV_RANGE.y, 1.0, Settings.fov, "%d°", Settings.set_fov)

	_section(rows, "Клавиши")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 24)
	grid.add_theme_constant_override(&"v_separation", 6)
	rows.add_child(grid)
	for action in Settings.ACTIONS:
		var label := Label.new()
		label.text = Settings.ACTION_NAMES[action]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 40)
		button.pressed.connect(begin_remap.bind(action))
		grid.add_child(button)
		key_buttons[action] = button
	_note = Label.new()
	_note.add_theme_color_override(&"font_color", ShellUI.MUTED)
	rows.add_child(_note)
	ShellUI.button(rows, "Сбросить клавиши", func() -> void:
		Settings.reset_keys()
		_refresh_keys())

	ShellUI.button(column, "Готово", close)
	_refresh_keys()


func begin_remap(action: StringName) -> void:
	waiting_action = action
	key_buttons[action].text = "нажмите клавишу…"
	_note.text = "Esc — отменить."


func finish_remap(physical_keycode: int) -> void:
	var swapped := Settings.remap(waiting_action, physical_keycode)
	_note.text = "Обменялись клавишами с действием «%s»." % Settings.ACTION_NAMES[swapped] if swapped != &"" else ""
	waiting_action = &""
	_refresh_keys()


func close() -> void:
	Settings.save_settings()
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if waiting_action == &"":
		if event.is_action_pressed(&"ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if key.keycode == KEY_ESCAPE:
		waiting_action = &""
		_note.text = ""
		_refresh_keys()
		return
	finish_remap(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)


func _refresh_keys() -> void:
	for action in key_buttons:
		key_buttons[action].text = Settings.key_name(Settings.primary_key(action))


func _section(parent: Control, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_color_override(&"font_color", ShellUI.ACCENT)
	label.add_theme_font_size_override(&"font_size", 24)
	parent.add_child(label)


func _slider(parent: Control, title: String, from: float, to: float, step: float, value: float, format: String, apply: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(280, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = from
	slider.max_value = to
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var shown := Label.new()
	shown.custom_minimum_size = Vector2(80, 0)
	shown.text = format % value
	row.add_child(shown)
	slider.value_changed.connect(func(new_value: float) -> void:
		shown.text = format % new_value
		apply.call(new_value))
