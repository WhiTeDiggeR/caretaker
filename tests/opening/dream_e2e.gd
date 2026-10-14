extends Node

## End-to-end check of the dream loop with real scene changes: sandbox → chair → Bowser's dream
## (terrace: the line of the silhouette; the arch stays shut) → seal of rings (knowledge, the side
## grate opens) → gate → sandbox → resync panel (#132, #190). Detaches itself from `current_scene` so the scene changes keep it.
## Prints `DREAM_E2E_OK` on success. With `-- capture <dir>` it also saves frames.

const SANDBOX := "res://scenes/sandbox/opening_sandbox.tscn"
const BOWSER_DREAM := "res://scenes/dreams/bowser_dream.tscn"
const SEAL := ^"SealHall/Seal"
const GATE := ^"Bastion/Gate"
const GATE_PROBE_FRAMES := 30
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
	await _until(func() -> bool: return _scene_is(BOWSER_DREAM))
	await _frames(60)
	_check(Dreams.in_dream, "session is in the dream")
	_check(Containment.get_instability(&"module_4") >= start + Dreams.entry_cost - 0.01, "entry raised the instability")
	await _capture("e2e_1_dream")
	var dream := tree.current_scene as BowserDream
	var hud := dream.get_node(^"OpeningHud") as OpeningHud
	var line := BowserDream.silhouette_line()
	await _until(func() -> bool: return GameState.has_flag(StringName(str(line.get("flag", "")))))
	_check(hud.message_text.text == str(line.get("text", "")), "the silhouette of №2 speaks its line on the terrace")
	var player := dream.get_node(^"Player") as Node3D
	var gate := dream.get_node(GATE) as DreamGate
	_check(not gate.is_open() and not dream.side_door_open, "before the seal the arch and the side grate are shut")
	player.global_position = gate.global_position + Vector3(0, 0.9, 0.6)
	await _frames(GATE_PROBE_FRAMES)
	_check(Dreams.in_dream and _scene_is(BOWSER_DREAM), "the shut arch lets nobody out")
	player.global_position = (dream.get_node(BowserDream.SEAL_SLOT) as Node3D).global_position + Vector3(-6, 1, 0)
	await _frames(5)
	# #183: the seal of rings — each lever turns its ring until the glyph of the code is under the mark.
	var seal := dream.get_node(SEAL) as DreamSealRings
	for ring in seal.ring_count:
		while not seal.is_ring_aligned(ring):
			seal.levers[ring].trigger()
	_check(Dreams.seal_restored, "the aligned rings restore the seal")
	var code := DreamKnowledge.code(&"module_4_seal")
	_check(code.size() == 3, "the seal leaves glyphs to remember")
	var after_seal := Containment.get_instability(&"module_4")
	_check(dream.side_door_open and gate.is_open(), "the restored seal opens the side grate and the arch")
	player.global_position = gate.global_position + Vector3(0, 0.9, 0.6)
	await _until(func() -> bool: return _scene_is(SANDBOX))
	await _frames(60)
	_check(not Dreams.in_dream, "gate ended the session")
	var back_player := tree.current_scene.get_node(^"Player") as Node3D
	var back_chair := tree.current_scene.get_node(^"Stations/ImmersionChair") as ImmersionChair
	var offset := back_player.global_position - back_chair.exit_transform().origin
	_check(Vector2(offset.x, offset.z).length() < 0.2, "hero returned to the chair (offset %s)" % offset)
	_check(Containment.get_instability(&"module_4") >= after_seal - 0.01, "returning keeps the session state")
	await _capture("e2e_2_back")
	_check(Dreams.return_text(Dreams.Exit.GATE).contains(Dreams.RESYNC_LINE), "return message asks for a resync")
	var panel := tree.current_scene.get_node(^"Stations/ResyncPanel") as ResyncPanel
	for glyph in code:
		panel.glyph_button(glyph).trigger()
	_check(panel.last_result == DreamKnowledge.Result.SYNCED, "remembered glyphs resync the capsule")
	_check(Containment.is_stable(&"module_4"), "resync brings module 4 to full stability")
	await _capture("e2e_3_resync")
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
