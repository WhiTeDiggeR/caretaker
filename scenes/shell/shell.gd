extends Node

## Game shell (autoload `Shell`): scene changes behind a loading screen with threaded
## loading, the pause menu (Esc in gameplay, when no terminal, document or message took the
## key), defeat and the rules of when the game may be saved, and entry points of the main
## menu. Screens are built from ShellUI.

signal scene_changed(path: String)
signal paused_changed(paused: bool)
signal defeated(reason: StringName)
## A new game's first scene is in the tree (the hero wakes up in the capsule).
signal new_game_started

const MAIN_MENU := "res://scenes/shell/main_menu.tscn"
## Test range of the opening systems, offered by the main menu in debug builds.
const SANDBOX_SCENE := "res://scenes/sandbox/opening_sandbox.tscn"
const PLAYER_GROUP := &"player"
const DEFEAT_CATASTROPHE := &"catastrophe"
const DEFEAT_GASSED := &"gassed"
## Screen effect the hero falls asleep under, and the shortest fall when it is missing.
const FALL_ASLEEP_EFFECT := &"gas"
const FALL_ASLEEP_MIN_SECONDS := 2.0
const SAVE_BLOCKED_LOADING := "Идёт загрузка."
const SAVE_BLOCKED_DEFEAT := "После поражения сохранить игру нельзя."
const SAVE_BLOCKED_ASLEEP := "Смотритель засыпает — сохранить игру нельзя."
const SAVE_BLOCKED_DREAM := "Во сне сохранить игру нельзя — сначала вернитесь в реальность."
const SAVE_BLOCKED_NO_GAME := "Нет начатой игры."

## Scene a new game starts in. The complex scene until the opening scene exists.
var new_game_scene := "res://scenes/underground_research_complex.tscn"
var loading := false
## Off in unit tests that wake modules without a running game.
var defeat_enabled := true
## Reason of the current defeat, empty while the game goes on.
var defeat_reason: StringName = &""
## True while the gassed hero falls asleep, before the defeat screen opens.
var falling_asleep := false

var _loading_layer: CanvasLayer
var _loading_bar: ProgressBar
var _pause_layer: CanvasLayer
var _defeat_screen: DefeatScreen
var _loading_path := ""
## Save being loaded: applied to the scene once it is in the tree.
var _pending_save: Dictionary = {}
var _starting_new_game := false
var _fall_asleep_serial := 0


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
	Containment.catastrophe.connect(func(_ids: Array[StringName]) -> void: defeat(DEFEAT_CATASTROPHE))
	Containment.hero_gassed.connect(func(_id: StringName) -> void: fall_asleep(DEFEAT_GASSED))


# --- Scene changes -----------------------------------------------------------

## Loads `path` in the background behind the loading screen, then switches to it.
func change_scene(path: String) -> void:
	if loading:
		return
	resume()
	_clear_defeat()
	falling_asleep = false
	# A defeat or a load may interrupt a dream: the new scene starts in reality.
	Dreams.abort()
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
	var new_game_loaded := _starting_new_game
	_starting_new_game = false
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
	if new_game_loaded:
		new_game_started.emit()


func new_game() -> void:
	if loading:
		return
	GameState.reset()
	_starting_new_game = true
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


# --- Defeat and saving ----------------------------------------------------------

func is_defeated() -> bool:
	return defeat_reason != &""


## Stops the game on a defeat and offers the ways back. Ignored outside a running game.
func defeat(reason: StringName) -> void:
	if not defeat_enabled or is_defeated() or loading or get_tree().get_first_node_in_group(PLAYER_GROUP) == null:
		return
	resume()
	falling_asleep = false
	defeat_reason = reason
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_defeat_screen = DefeatScreen.open(self, reason)
	defeated.emit(reason)


## A defeat that comes over the hero: controls lock, the hero sinks to the floor and the
## screen fades out (the ScreenEffects effect started by the same event), then the defeat
## screen opens. A load or a scene change during the fall cancels it.
func fall_asleep(reason: StringName) -> void:
	if not defeat_enabled or is_defeated() or falling_asleep or loading:
		return
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player == null:
		return
	resume()
	falling_asleep = true
	_fall_asleep_serial += 1
	var serial := _fall_asleep_serial
	if player.has_method(&"fall_asleep"):
		player.call(&"fall_asleep")
	await get_tree().create_timer(maxf(ScreenEffects.duration(FALL_ASLEEP_EFFECT), FALL_ASLEEP_MIN_SECONDS)).timeout
	if serial != _fall_asleep_serial or not falling_asleep:
		return
	falling_asleep = false
	defeat(reason)


## Why the game cannot be saved right now, or "" when it can.
func save_block_reason() -> String:
	if loading:
		return SAVE_BLOCKED_LOADING
	if is_defeated():
		return SAVE_BLOCKED_DEFEAT
	if falling_asleep:
		return SAVE_BLOCKED_ASLEEP
	if Dreams.in_dream:
		return SAVE_BLOCKED_DREAM
	if get_tree().get_first_node_in_group(PLAYER_GROUP) == null:
		return SAVE_BLOCKED_NO_GAME
	return ""


func can_save() -> bool:
	return save_block_reason().is_empty()


func _clear_defeat() -> void:
	defeat_reason = &""
	if _defeat_screen:
		_defeat_screen.queue_free()
		_defeat_screen = null
	get_tree().paused = false


# --- Pause -------------------------------------------------------------------

func is_paused() -> bool:
	return _pause_layer != null


func in_gameplay() -> bool:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	return player != null and not bool(player.get("controls_locked"))


func pause() -> void:
	if is_paused() or loading or is_defeated() or falling_asleep:
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


func _add_pause_items(column: VBoxContainer) -> void:
	var save_button := ShellUI.button(column, "Сохранить игру", func() -> void: SaveSlotsScreen.open(self, SaveSlotsScreen.Mode.SAVE))
	var blocked := save_block_reason()
	save_button.disabled = not blocked.is_empty()
	if not blocked.is_empty():
		var note := Label.new()
		note.text = blocked
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_color_override(&"font_color", ShellUI.MUTED)
		column.add_child(note)
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
	if is_defeated():
		# The defeat screen stays until the player picks a way back.
		get_viewport().set_input_as_handled()
		return
	if find_children("*", "SettingsScreen", false, false).size() > 0 or find_children("*", "SaveSlotsScreen", false, false).size() > 0:
		return
	if is_paused():
		resume()
		get_viewport().set_input_as_handled()
	elif in_gameplay():
		pause()
		get_viewport().set_input_as_handled()
