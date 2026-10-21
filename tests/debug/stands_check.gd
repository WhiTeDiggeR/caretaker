extends Node

## Headless check of the sandbox test stands (#239): every stand of data/debug/stands.json
## opens through Debug.open_stand without errors, the hero stands at the start, the stand sets
## its progress state and shows its «что проверить» sign; the F10 menu lists every stand.
## With `-- --snapshots=<folder>` (run with a window) it also saves the view from the hero's
## eyes at the start of each stand as <id>.png.
## Prints `DEBUG_STANDS_OK stands=<n>` on success.

const SETTLE_FRAMES := 20
const SNAPSHOT_FRAMES := 30
const FALL_LIMIT_Y := -5.0
const SNAPSHOT_ARG := "--snapshots="


## Counts engine and script errors (warnings are not errors).
class ErrorCounter extends Logger:
	var count := 0
	var last := ""
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		count += 1
		last = "%s (%s:%d %s)" % [rationale if not rationale.is_empty() else code, file, line, function]
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _errors := PackedStringArray()
var _logger := ErrorCounter.new()
var _snapshots := ""


func _ready() -> void:
	OS.add_logger(_logger)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(SNAPSHOT_ARG):
			_snapshots = arg.trim_prefix(SNAPSHOT_ARG)
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	tree.current_scene = null
	var stands: Array[Dictionary] = Debug.stands()
	for problem in DebugStands.validate(stands):
		_errors.append("stands data: " + problem)
	_check(str(stands.back().get("scene", "")) == Shell.SANDBOX_SCENE, "the old sandbox is the last stand")
	if not _snapshots.is_empty():
		DirAccess.make_dir_recursive_absolute(_snapshots)
	for stand in stands:
		await _check_stand(stand)
	await _check_menu()
	OS.remove_logger(_logger)
	for error in _errors:
		printerr("FAIL ", error)
	if _errors.is_empty():
		print("DEBUG_STANDS_OK stands=%d" % stands.size())
	tree.quit(0 if _errors.is_empty() else 1)


func _check_stand(stand: Dictionary) -> void:
	var id := StringName(str(stand["id"]))
	var errors_before := _logger.count
	var opened: bool = await Debug.open_stand(id)
	_check(opened, "%s: opened" % id)
	await _frames(SETTLE_FRAMES)
	var scene := get_tree().current_scene
	_check(scene != null and scene.scene_file_path == str(stand["scene"]), "%s: scene is %s" % [id, stand["scene"]])
	_check(Debug.last_stand == id, "%s: remembered as the last stand" % id)
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	_check(player != null and player.global_position.y > FALL_LIMIT_Y, "%s: the hero stands at the start" % id)
	var state: Dictionary = stand.get("state", {})
	for flag: Variant in state.get("flags", []):
		_check(GameState.has_flag(StringName(str(flag))), "%s: flag %s" % [id, flag])
	for grant: Variant in state.get("access", []):
		_check(GameState.has_access(StringName(str(grant))), "%s: access %s" % [id, grant])
	var power: Dictionary = state.get("section_power", {})
	for section: String in power:
		_check(GameState.power_name(GameState.get_section_power(StringName(section))) == str(power[section]), "%s: power of %s" % [id, section])
	var chain := str(state.get("objective_chain", ""))
	if not chain.is_empty():
		_check(String(Objectives.active_chain()) == chain, "%s: objective chain %s, got %s" % [id, chain, Objectives.active_chain()])
	var stand_node := scene as SandboxStand
	if str(stand["scene"]) != Shell.SANDBOX_SCENE:
		_check(stand_node != null, "%s: the scene is a SandboxStand" % id)
	if stand_node:
		var text := stand_node.sign_label.text if stand_node.sign_label else ""
		_check(text.contains("1. ") and text.contains(str((stand["check"] as Array)[0])), "%s: the sign lists what to check" % id)
	if not _snapshots.is_empty():
		await _frames(SNAPSHOT_FRAMES)
		var image := get_viewport().get_texture().get_image()
		if image:
			image.save_png(_snapshots.path_join("%s.png" % id))
	_check(_logger.count == errors_before, "%s: opens without errors (%d, last: %s)" % [id, _logger.count - errors_before, _logger.last])


func _check_menu() -> void:
	Debug.open_menu()
	await _frames(2)
	var menu := Debug.get_node_or_null(^"DebugMenu")
	var count := 0
	if menu:
		for stand in Debug.stands():
			if menu.find_child(Debug.STAND_BUTTON + str(stand["id"]), true, false) is ShellButton:
				count += 1
	_check(count == Debug.stands().size(), "F10 menu lists every stand (%d)" % count)
	Debug.close_menu()
	await _frames(2)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
