extends Node

## Game shell (autoload `Shell`): scene changes behind a loading screen with threaded
## loading, the pause menu (Esc in gameplay, when no terminal, document or message took the
## key) and entry points of the main menu. Screens are built from ShellUI.

signal scene_changed(path: String)
signal paused_changed(paused: bool)

const MAIN_MENU := "res://scenes/shell/main_menu.tscn"
const PLAYER_GROUP := &"player"

## Scene a new game starts in. The complex scene until the opening scene exists.
var new_game_scene := "res://scenes/underground_research_complex.tscn"
var loading := false

var _loading_layer: CanvasLayer
var _loading_bar: ProgressBar
var _pause_layer: CanvasLayer
var _loading_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_loading_layer = CanvasLayer.new()
	_loading_layer.layer = 90
	_loading_layer.visible = false
	add_child(_loading_layer)
	var column := ShellUI.screen(_loading_layer, "ЗАГРУЗКА", 420.0)
	_loading_bar = ProgressBar.new()
	_loading_bar.max_value = 1.0
	_loading_bar.show_percentage = false
	_loading_bar.custom_minimum_size = Vector2(0, 10)
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
	scene_changed.emit(_loading_path)


func new_game() -> void:
	GameState.reset()
	change_scene(new_game_scene)


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
	var column := ShellUI.screen(_pause_layer, "ПАУЗА")
	var resume_button := ShellUI.button(column, "Продолжить", resume)
	_add_pause_items(column)
	ShellUI.button(column, "В главное меню", main_menu)
	resume_button.grab_focus.call_deferred()
	paused_changed.emit(true)


## Extension point for later menu items (settings, saves).
func _add_pause_items(_column: VBoxContainer) -> void:
	pass


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
	if is_paused():
		resume()
		get_viewport().set_input_as_handled()
	elif in_gameplay():
		pause()
		get_viewport().set_input_as_handled()
