extends Node

## End-to-end check of the game shell with real scene changes. Detaches itself from
## `current_scene` so the scene changes keep it. Prints `SHELL_E2E_OK` on success.
## With `-- capture <dir>` it also saves frames.

const SANDBOX := "res://scenes/sandbox/opening_sandbox.tscn"
const TIMEOUT_FRAMES := 900

var _errors := PackedStringArray()
var _capture_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "capture":
		_capture_dir = args[1]
		DirAccess.make_dir_recursive_absolute(_capture_dir)
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	tree.current_scene = null
	Shell.main_menu()
	_check(Shell.loading, "main menu loads behind the loading screen")
	await _until(func() -> bool: return _scene_is(Shell.MAIN_MENU))
	await _frames(5)
	var menu := tree.current_scene
	_check(menu.continue_button != null, "main menu has the continue button")
	await _capture("shell_1_menu")

	Shell.new_game_scene = SANDBOX
	GameState.set_flag(&"left_over")
	Shell.new_game()
	await _until(func() -> bool: return _scene_is(SANDBOX))
	await _frames(10)
	_check(not GameState.has_flag(&"left_over"), "new game starts from a clean state")

	_press_cancel()
	await _frames(2)
	_check(Shell.is_paused() and tree.paused, "Esc pauses the game")
	await _capture("shell_2_pause")
	var settings := Shell.open_settings()
	await _frames(2)
	await _capture("shell_3_settings")
	_press_cancel()
	await _frames(2)
	_check(not is_instance_valid(settings) or settings.is_queued_for_deletion(), "Esc closes the settings screen")
	_check(Shell.is_paused(), "closing the settings keeps the pause")
	_press_cancel()
	await _frames(2)
	_check(not Shell.is_paused() and not tree.paused, "Esc resumes")

	var memo := tree.current_scene.get_node(^"Stations/DocumentStation/Memo") as DocumentPickup
	memo.read()
	await _frames(2)
	_press_cancel()
	await _frames(2)
	_check(not Shell.is_paused(), "Esc closes a document instead of pausing")
	_check(memo.reader == null, "the document was closed by Esc")

	Shell.pause()
	Shell.main_menu()
	_check(not tree.paused, "leaving to the menu unpauses the tree")
	await _until(func() -> bool: return _scene_is(Shell.MAIN_MENU))

	for error in _errors:
		printerr("FAIL ", error)
	if _errors.is_empty():
		print("SHELL_E2E_OK")
	tree.quit(0 if _errors.is_empty() else 1)


func _press_cancel() -> void:
	var press := InputEventAction.new()
	press.action = &"ui_cancel"
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = &"ui_cancel"
	release.pressed = false
	Input.parse_input_event(release)


func _scene_is(path: String) -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path


func _until(condition: Callable) -> void:
	for _i in TIMEOUT_FRAMES:
		if condition.call():
			return
		await get_tree().process_frame
	_errors.append("timed out waiting")


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _capture(name: String) -> void:
	if _capture_dir.is_empty():
		return
	await _frames(10)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_capture_dir, name])
