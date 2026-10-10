extends Node

## End-to-end check of the dream loop with real scene changes: sandbox → chair → test dream
## → gate → sandbox. Detaches itself from `current_scene` so the scene changes keep it.
## Prints `DREAM_E2E_OK` on success. With `-- capture <dir>` it also saves frames.

const SANDBOX := "res://scenes/sandbox/opening_sandbox.tscn"
const TEST_DREAM := "res://scenes/dreams/test_dream.tscn"
const TIMEOUT_FRAMES := 600

var _errors := PackedStringArray()
var _capture_dir := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "capture":
		_capture_dir = args[1]
		DirAccess.make_dir_recursive_absolute(_capture_dir)
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	tree.current_scene = null
	tree.change_scene_to_file(SANDBOX)
	await _until(func() -> bool: return _scene_is(SANDBOX))
	await _frames(5)
	var chair := tree.current_scene.get_node(^"Stations/ImmersionChair") as ImmersionChair
	_check(chair.lock_reason().is_empty(), "sandbox chair is free: %s" % chair.lock_reason())
	var start := Containment.get_instability(&"module_4")
	chair.sit_down()
	await _until(func() -> bool: return _scene_is(TEST_DREAM))
	await _frames(60)
	_check(Dreams.in_dream, "session is in the dream")
	_check(Containment.get_instability(&"module_4") >= start + Dreams.entry_cost - 0.01, "entry raised the instability")
	await _capture("e2e_1_dream")
	var dream := tree.current_scene
	var player := dream.get_node(^"Player") as Node3D
	player.global_position = Vector3(0, 0.9, -38.4)
	await _until(func() -> bool: return _scene_is(SANDBOX))
	await _frames(60)
	_check(not Dreams.in_dream, "gate ended the session")
	var back_player := tree.current_scene.get_node(^"Player") as Node3D
	var back_chair := tree.current_scene.get_node(^"Stations/ImmersionChair") as ImmersionChair
	var offset := back_player.global_position - back_chair.exit_transform().origin
	_check(Vector2(offset.x, offset.z).length() < 0.2, "hero returned to the chair (offset %s)" % offset)
	_check(Containment.get_instability(&"module_4") >= start + Dreams.entry_cost - 0.01, "returning keeps the session state")
	await _capture("e2e_2_back")
	for error in _errors:
		printerr("FAIL ", error)
	if _errors.is_empty():
		print("DREAM_E2E_OK")
	tree.quit(0 if _errors.is_empty() else 1)


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
