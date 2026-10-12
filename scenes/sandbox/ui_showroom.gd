extends Control

## Showroom of the interface style (issue #151, docs/ui/style-guide.md): every element in
## every state without playing the game. Run with F6. The pages use the same scenes and
## resources as the game; nothing here restyles them.

const PAGES: Array[String] = ["Экраны мира", "Терминалы", "HUD", "Бумага", "Сон", "Оболочка"]
const STATES: Array[String] = ["Норма", "Внимание", "Тревога", "Включение", "Нет питания"]
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160)]
const HUD_SCENE := preload("res://scenes/ui/opening_hud.tscn")
const TERMINAL_SCENE := preload("res://objects/terminal/terminal_screen.tscn")
const DOCUMENTS: Array[String] = ["archive_rebuild_order", "archive_issue_ledger", "senior_note", "staff_memo_anomaly"]
const BACKGROUND := Color(0.05, 0.055, 0.06)
const MENU_WIDTH := 300.0
const SCREEN_SIZE := Vector2(380, 285)
## The three screens share the page: smaller type than a full-screen terminal.
const SCREEN_TEXT_SCALE := 0.75
const SAMPLE_ROWS := {
	"ok": [["ГЕНЕРАТОР Г-1 ...... РАБОТА", &"ok"], ["ДАВЛЕНИЕ МАСЛА ..... 4.2 БАР", &"ok"], ["СЕКЦИЯ А ........... НОРМА", &"ok"], ["СВЯЗЬ С ЦУ ......... НЕТ ОТВЕТА", &"none"]],
	"warn": [["ГЕНЕРАТОР Г-1 ...... ПЕРЕГРЕВ", &"warn"], ["ДАВЛЕНИЕ МАСЛА ..... 5.6 БАР", &"warn"], ["СЕКЦИЯ А ........... НОРМА", &"ok"], ["СВЯЗЬ С ЦУ ......... НЕТ ОТВЕТА", &"none"]],
	"alarm": [["ГЕНЕРАТОР Г-1 ...... ОСТАНОВ", &"alarm"], ["ШИНА ОСН. .......... ОБРЫВ", &"alarm"], ["СЕКЦИЯ А ........... НЕТ ПИТАНИЯ", &"alarm"], ["СВЯЗЬ С ЦУ ......... НЕТ ОТВЕТА", &"none"]],
}

var page := ""
var views: Array[ScreenView] = []

var _content: Control
var _hud: OpeningHud


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = ShellUI.theme()
	var back := ColorRect.new()
	back.color = BACKGROUND
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var menu := VBoxContainer.new()
	menu.position = Vector2(32, 32)
	menu.custom_minimum_size = Vector2(MENU_WIDTH - 48.0, 0)
	menu.add_theme_constant_override(&"separation", 6)
	add_child(menu)
	var title := Label.new()
	title.text = "ВИТРИНА ИНТЕРФЕЙСОВ"
	title.add_theme_font_override(&"font", UiStyle.FONT_DISPLAY)
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", UiStyle.ACCENT)
	menu.add_child(title)
	for name in PAGES:
		_button(menu, name, show_page.bind(name))
	_label(menu, "Эффект ЭЛТ", UiStyle.MUTED, Vector2.ZERO, MENU_WIDTH - 48.0)
	_button(menu, "Вкл. / выкл.", func() -> void:
		Settings.set_crt_effects(not Settings.crt_effects)
		show_page(page))
	_label(menu, "Разрешение окна", UiStyle.MUTED, Vector2.ZERO, MENU_WIDTH - 48.0)
	for resolution in RESOLUTIONS:
		_button(menu, "%d × %d" % [resolution.x, resolution.y], func() -> void: get_window().size = resolution)
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = MENU_WIDTH
	add_child(_content)
	show_page(PAGES[0])


func show_page(name: String) -> void:
	page = name
	views.clear()
	if _hud:
		_hud.queue_free()
		_hud = null
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	match name:
		"Экраны мира":
			_page_screens()
		"Терминалы":
			_page_buttons("Полноэкранный терминал каждой эпохи; Esc закрывает.", ScreenStyle.ERAS.map(func(era: StringName) -> String: return String(era)), open_terminal)
		"HUD":
			_page_hud()
		"Бумага":
			_page_buttons("Документы со шапкой, штампами, вымаркой и рукописным листом; Esc закрывает.", DOCUMENTS, func(id: String) -> void: DocumentReader.open_document_scene(get_tree(), id))
		"Сон":
			_page_buttons("Оверлей между мирами (щелчок — следующий режим скрывает предыдущий).", ["Вход", "Врата", "Смерть во сне", "Экстренное пробуждение", "Скрыть"], show_veil)
		"Оболочка":
			_page_shell()


## Elements of the shell (variant A) and the entries to its screens; the splash and the
## loading screen are variant B.
func _page_shell() -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(32, 32)
	column.custom_minimum_size = Vector2(560, 0)
	column.add_theme_constant_override(&"separation", 2)
	_content.add_child(column)
	ShellUI.label(column, "КНОПКИ-ПУНКТЫ", &"ShellSection")
	ShellUI.button(column, "Продолжить", func() -> void: pass, "11.10.2026 23:14")
	ShellUI.button(column, "Загрузить игру", func() -> void: pass).grab_focus()
	ShellUI.button(column, "Полигон (отладка)", func() -> void: pass, "НЕДОСТУПНО").disabled = true
	ShellUI.button(column, "В главное меню", func() -> void: pass, "НЕСОХРАНЁННОЕ ПРОПАДЁТ").danger = true
	ShellUI.label(column, "ЭКРАНЫ", &"ShellSection")
	ShellUI.button(column, "Настройки", func() -> void: SettingsScreen.open(self))
	ShellUI.button(column, "Слоты сохранений", func() -> void: SaveSlotsScreen.open(self, SaveSlotsScreen.Mode.SAVE))
	ShellUI.button(column, "Подтверждение", func() -> void:
		ShellUI.confirm(self, "Перезаписать слот?", "Сохранение «Слот 1» будет заменено. Отменить это нельзя.", "Перезаписать", func() -> void: pass))
	ShellUI.button(column, "Пауза", func() -> void:
		Shell.pause()
		get_tree().paused = false)
	ShellUI.button(column, "Загрузка (вариант Б, 2 с)", func() -> void:
		Shell._loading_layer.visible = true
		get_tree().create_timer(2.0).timeout.connect(func() -> void: Shell._loading_layer.visible = false))
	ShellUI.button(column, "Главное меню с заставкой (вариант Б)", func() -> void:
		MainMenu.splash_seen = false
		get_tree().change_scene_to_file(Shell.MAIN_MENU))


## Three world screens side by side and the state switcher.
func _page_screens() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(32, 32)
	row.add_theme_constant_override(&"separation", 12)
	_content.add_child(row)
	for index in STATES.size():
		_button(row, STATES[index], set_screen_state.bind(index))
	var grid := HBoxContainer.new()
	grid.position = Vector2(32, 112)
	grid.add_theme_constant_override(&"separation", 24)
	_content.add_child(grid)
	for era in ScreenStyle.ERAS:
		var view := ScreenView.new()
		view.custom_minimum_size = SCREEN_SIZE
		view.text_scale = SCREEN_TEXT_SCALE
		view.setup(ScreenStyle.for_era(era))
		view.module_color = UiStyle.MODULE_BOWSER
		grid.add_child(view)
		views.append(view)
	set_screen_state(0)


func set_screen_state(index: int) -> void:
	for view in views:
		match index:
			3:
				view.set_powered(false)
				view.set_powered(true)
			4:
				view.set_powered(false)
			_:
				view.set_powered(true)
				var rows: Array[Dictionary] = []
				for item: Array in SAMPLE_ROWS[["ok", "warn", "alarm"][index]]:
					rows.append({"text": item[0], "status": item[1]})
				view.show_rows("ПУЛЬТ ПУ-1 · " + String(view.style.era).to_upper(), rows)


func open_terminal(era: String) -> void:
	var program := TerminalProgram.new()
	program.load_data({"id": "showroom", "title": "ВИТРИНА · ЭПОХА " + era.to_upper(), "era": era, "start": "a", "screens": {"a": {
		"lines": ["АВАРИЙНЫЙ РЕЖИМ.", "Питание пульта: аккумулятор.", {"text": "Проверка связи с модулями...", "wait": 0.6}, "ГЕНЕРАТОР Г-1 ........ АВАРИЙНЫЙ ОСТАНОВ"],
		"options": [{"text": "Сводка состояния", "goto": "a"}, {"text": "Протокол", "goto": "a", "requires": {"flag": "never"}, "locked_text": "требуются аварийные полномочия"}, {"text": "Выход", "action": "exit"}]}}})
	var screen := TERMINAL_SCENE.instantiate() as TerminalScreen
	get_tree().root.add_child(screen)
	screen.open(program)


## The real HUD over the page with a prompt, the hold ring, a notice and the chemical line.
func _page_hud() -> void:
	_hud = HUD_SCENE.instantiate() as OpeningHud
	add_child(_hud)
	GameState.set_objective(&"showroom", "Добраться до модуля 4")
	_hud.interact_label.text = "[E] УДЕРЖИВАТЬ · ОТКРЫТЬ ГЕРМОДВЕРЬ"
	_hud.interact_label.visible = true
	_hud.hold_progress.visible = true
	_hud.hold_progress.value = _hud.hold_progress.max_value * 0.6
	_hud.show_journal_notice("Памятка персонала")
	_hud.show_hint("Шлюз открывается только с поста контроля")
	if _hud.alert_label:
		_hud.show_alert(OpeningHud.ALERT_WARNING % ["МОДУЛЬ 4", "00:10"])


func show_veil(mode: String) -> void:
	var veil := Dreams._fade
	match mode:
		"Вход":
			veil.show_mode(DreamTransition.Mode.ENTER, Dreams.ENTER_LINE % "МОДУЛЬ 4")
		"Врата":
			veil.show_mode(DreamTransition.Mode.GATE, Dreams.exit_line(Dreams.Exit.GATE))
		"Смерть во сне":
			veil.show_mode(DreamTransition.Mode.DEATH, Dreams.exit_line(Dreams.Exit.DEATH))
		"Экстренное пробуждение":
			veil.show_mode(DreamTransition.Mode.WOKEN, Dreams.exit_line(Dreams.Exit.WOKEN))
	veil.veil = 0.0 if mode == "Скрыть" else 0.92


func _exit_tree() -> void:
	if Dreams._fade:
		Dreams._fade.veil = 0.0


func _page_buttons(note: String, items: Array, action: Callable) -> void:
	var column := VBoxContainer.new()
	column.position = Vector2(32, 32)
	column.custom_minimum_size = Vector2(520, 0)
	column.add_theme_constant_override(&"separation", 8)
	_content.add_child(column)
	_label(column, note, UiStyle.MUTED)
	for item: String in items:
		_button(column, item, action.bind(item))


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := ShellUI.button(parent, text, action)
	button.focus_mode = Control.FOCUS_NONE
	return button


func _label(parent: Control, text: String, color: Color, at: Vector2 = Vector2.ZERO, width: float = 520.0) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	label.position = at
	label.add_theme_font_override(&"font", UiStyle.FONT_BODY)
	label.add_theme_color_override(&"font_color", color)
	parent.add_child(label)
	return label
