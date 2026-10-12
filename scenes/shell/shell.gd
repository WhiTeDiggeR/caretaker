extends Node

## Game shell (autoload `Shell`): scene changes behind a loading screen with threaded
## loading, the pause menu (Esc in gameplay, when no terminal, document or message took the
## key) and entry points of the main menu. Screens are built from ShellUI (variant A); the
## loading screen is the crystal of variant B (docs/ui/style-guide.md, issue #144).

signal scene_changed(path: String)
signal paused_changed(paused: bool)

const MAIN_MENU := "res://scenes/shell/main_menu.tscn"
## Test range of the opening systems, offered by the main menu in debug builds.
const SANDBOX_SCENE := "res://scenes/sandbox/opening_sandbox.tscn"
const PLAYER_GROUP := &"player"
const LOADING_WORD := "загрузка"
const LOADING_BAR_WIDTH := 360.0
const LOADING_SPACING := 18

## Scene a new game starts in. The complex scene until the opening scene exists.
var new_game_scene := "res://scenes/underground_research_complex.tscn"
var loading := false

var _loading_layer: CanvasLayer
var _loading_bar: ProgressBar
var _pause_layer: CanvasLayer
var _loading_path := ""
## Save being loaded: applied to the scene once it is in the tree.
var _pending_save: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_loading_layer = CanvasLayer.new()
	_loading_layer.layer = 90
	_loading_layer.visible = false
	add_child(_loading_layer)
	_build_loading_screen()


## The crystal breathes while the scene loads; one word and a hairline of progress below it.
func _build_loading_screen() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = ShellUI.theme()
	_loading_layer.add_child(root)
	root.add_child(CrystalBackdrop.new())
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.offset_top = 150.0
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override(&"separation", 18)
	root.add_child(column)
	var word := Label.new()
	word.text = LOADING_WORD
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spaced := UiStyle.FONT_DREAM.duplicate() as FontVariation
	spaced.spacing_glyph = LOADING_SPACING
	word.add_theme_font_override(&"font", spaced)
	word.add_theme_font_size_override(&"font_size", 40)
	word.add_theme_color_override(&"font_color", Color(0.9, 0.95, 0.97, 0.8))
	column.add_child(word)
	_loading_bar = ProgressBar.new()
	_loading_bar.max_value = 1.0
	_loading_bar.show_percentage = false
	_loading_bar.custom_minimum_size = Vector2(LOADING_BAR_WIDTH, 2)
	_loading_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_loading_bar)


# --- Scene changes -----------------------------------------------------------

## Loads `path` in the background behind the loading screen, then switches to it.
func change_scene(path: String) -> void:
	if loading:
		return
	resume()
	loading = true
	_loading_path = path
	_loading_bar.value = 0.0
	_loading_layer.visible = true
	ResourceLoader.load_threaded_request(path)


func _process(_delta: float) -> void:
	if not loading:
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_loading_path, progress)
	if not progress.is_empty():
		_loading_bar.value = float(progress[0])
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	loading = false
	_loading_layer.visible = false
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("Shell: cannot load %s" % _loading_path)
		return
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(_loading_path))
	if not _pending_save.is_empty():
		var save := _pending_save
		_pending_save = {}
		await get_tree().process_frame
		await get_tree().process_frame
		Saves.apply_to_scene(get_tree(), save)
	scene_changed.emit(_loading_path)


func new_game() -> void:
	GameState.reset()
	change_scene(new_game_scene)


## Starts the test range from a clean state (debug builds only).
func start_sandbox() -> void:
	GameState.reset()
	change_scene(SANDBOX_SCENE)


## Loads a save: GameState first (so the scene starts from it), then the scene, then the
## saved objects and the hero.
func load_game(slot: String) -> bool:
	var data := Saves.read(slot)
	if data.is_empty() or str(data.get("scene", "")).is_empty():
		return false
	GameState.from_dict(data["state"])
	_pending_save = data
	change_scene(str(data["scene"]))
	return true


func main_menu() -> void:
	change_scene(MAIN_MENU)


func quit_game() -> void:
	get_tree().quit()


# --- Pause -------------------------------------------------------------------

func is_paused() -> bool:
	return _pause_layer != null


func in_gameplay() -> bool:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	return player != null and not bool(player.get("controls_locked"))


func pause() -> void:
	if is_paused() or loading:
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 80
	add_child(_pause_layer)
	var column := ShellUI.screen(_pause_layer, "Пауза")
	var resume_button := ShellUI.button(column, "Продолжить", resume)
	_add_pause_items(column)
	ShellUI.button(column, "В главное меню", main_menu, "НЕСОХРАНЁННОЕ ПРОПАДЁТ").danger = true
	resume_button.grab_focus.call_deferred()
	paused_changed.emit(true)


func _add_pause_items(column: VBoxContainer) -> void:
	ShellUI.button(column, "Сохранить игру", func() -> void: SaveSlotsScreen.open(self, SaveSlotsScreen.Mode.SAVE))
	ShellUI.button(column, "Загрузить игру", func() -> void: SaveSlotsScreen.open(self, SaveSlotsScreen.Mode.LOAD))
	ShellUI.button(column, "Настройки", open_settings)


func open_settings() -> SettingsScreen:
	return SettingsScreen.open(self)


func resume() -> void:
	if not is_paused():
		return
	_pause_layer.queue_free()
	_pause_layer = null
	get_tree().paused = false
	if get_tree().get_first_node_in_group(PLAYER_GROUP):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	paused_changed.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if find_children("*", "SettingsScreen", false, false).size() > 0 or find_children("*", "SaveSlotsScreen", false, false).size() > 0:
		return
	if is_paused():
		resume()
		get_viewport().set_input_as_handled()
	elif in_gameplay():
		pause()
		get_viewport().set_input_as_handled()
