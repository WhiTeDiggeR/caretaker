extends Node

## Headless check of the dream viewer (#204): the viewer opens Bowser's dream without the
## chair, the hero stays frozen and the guards stand still, keys 1–4 switch the stage of the
## sky, the sound and the ash, keys 5–0 move the camera to the key places, H hides the hints,
## and leaving the viewer closes the dream session and silences its sound.
## Prints `DREAM_VIEWER_OK checks=<n>` on success.

const SETTLE_FRAMES := 10
const TIMEOUT_FRAMES := 1200
const STAND_SECONDS := 2.5  # longer than the guards' assembly

var _checks := 0
var _errors := PackedStringArray()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	tree.current_scene = null
	GameState.reset()
	Shell.change_scene(DreamViewer.SCENE)
	_check(await _wait_for_scene(DreamViewer.SCENE), "the viewer loads")
	var viewer := tree.current_scene as DreamViewer
	if viewer:
		await _check_viewer(viewer)
	Shell.change_scene(ReviewHub.SCENE)
	_check(await _wait_for_scene(ReviewHub.SCENE), "the hall loads after the viewer")
	_check(not Dreams.in_dream and Dreams.module_id == &"", "leaving closes the dream session")
	_check(DreamAudio.stage == DreamAudio.SILENT, "leaving silences the dream sound")
	_check(not Containment.is_held(DreamViewer.MODULE), "leaving releases the sleeper")
	for error in _errors:
		printerr("FAIL ", error)
	if _errors.is_empty():
		print("DREAM_VIEWER_OK checks=%d" % _checks)
	tree.quit(0 if _errors.is_empty() else 1)


func _check_viewer(viewer: DreamViewer) -> void:
	var dream := viewer.get_node(DreamViewer.DREAM_PATH) as BowserDream
	var mood := dream.get_node(^"Mood") as DreamStageMood
	var fx := dream.get_node(^"Fx") as BowserDreamFx
	var hero := dream.get_node(^"Player") as Node3D
	var ambush := dream.get_node(^"Yard/Ambush") as DreamAmbush
	_check(Dreams.in_dream and Dreams.module_id == DreamViewer.MODULE, "the dream session is open")
	_check(viewer.camera != null and viewer.camera.is_current(), "the viewer camera is current")
	var hero_at := hero.global_position
	await get_tree().create_timer(STAND_SECONDS).timeout
	_check(hero.global_position.distance_to(hero_at) < 0.01, "the hero stays put")
	_check(ambush.started and not ambush.guards.is_empty(), "the guards are out")
	for guard in ambush.guards:
		_check(is_instance_valid(guard) and not guard.is_dead() and not guard.can_process(), "%s stands still" % guard.name)
	_check(Dreams.in_dream, "no death while viewing")
	for index in DreamViewer.STAGE_KEYS.size():
		_press(DreamViewer.STAGE_KEYS[index])
		await get_tree().process_frame
		_check(viewer.stage == index and is_equal_approx(mood.shown_stage, float(index)), "key %d shows stage %d" % [index + 1, index])
		_check(DreamAudio.stage == DreamAudio.MOOD_STAGES[index], "stage %d sounds %s" % [index, DreamAudio.MOOD_STAGES[index]])
		var ash := BowserDreamFx.ASH_RATE[index] / BowserDreamFx.ASH_RATE[3]
		_check(is_equal_approx(fx.ash.amount_ratio, ash), "stage %d ash" % index)
	for index in DreamViewer.VIEWS.size():
		_press(DreamViewer.VIEW_KEYS[index])
		await get_tree().process_frame
		var view := DreamViewer.VIEWS[index]
		var anchor := dream.get_node(view["node"] as NodePath) as Node3D
		var wanted := anchor.global_position + (view["from"] as Vector3)
		_check(viewer.camera.global_position.distance_to(wanted) < 0.01, "key %d: view «%s»" % [index + 5, view["title"]])
	_press(DreamViewer.HINTS_KEY)
	await get_tree().process_frame
	_check(not viewer.hints_visible, "H hides the hints")
	_press(DreamViewer.HINTS_KEY)
	await get_tree().process_frame
	_check(viewer.hints_visible, "H shows the hints again")


func _press(keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = true
	Input.parse_input_event(key)


func _wait_for_scene(path: String) -> bool:
	var tree := get_tree()
	await tree.process_frame
	for _i in TIMEOUT_FRAMES:
		if tree.current_scene and tree.current_scene.scene_file_path == path and not Shell.loading:
			for _f in SETTLE_FRAMES:
				await tree.process_frame
			return true
		await tree.process_frame
	return false


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(message)
