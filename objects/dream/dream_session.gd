extends Node

## Dream session (autoload `Dreams`): takes the hero from an immersion chair into the
## dream of a module and back. Canon (docs/world/02-world-rules.md): entering raises the
## instability, death in the dream throws the hero back into the chair and brings the
## awakening closer, the gate is the voluntary exit, subjective time runs faster while the
## complex keeps living in real time. Parameters: data/dreams/dreams.json.

signal entered(module_id: StringName)
signal left(module_id: StringName, reason: Exit)
## The hero is back in reality, after the interdream, and the veil starts to lift (the
## aftertaste effects start here, not under the veil — #166).
signal arrived(module_id: StringName, reason: Exit)
signal seal_restored_signal(module_id: StringName)
## The afterimage of the seal restored this visit shows after the gate (З-Р5, #197): the
## knowledge it carries and its code, outer ring first — for the journal (#196).
signal afterimage_shown(module_id: StringName, knowledge_id: StringName, code: PackedStringArray)
## The interdream of this exit is over (#228): `echo_id` empty — a quiet one.
signal interdream_finished(module_id: StringName, reason: Exit, echo_id: String, seen_seconds: float)

## GATE — voluntary exit, DEATH — killed in the dream, WOKEN — the module was gassed and
## object 2 pulled the connected hero out (chemical protocol).
enum Exit { GATE, DEATH, WOKEN }

const DATA_PATH := "res://data/dreams/dreams.json"
const CHAIR_GROUP := &"immersion_chairs"
const PLAYER_GROUP := &"player"
const MESSAGE_GROUP := &"message_display"
const FADE_SECONDS := 0.6
const RETURNED_PREFIX := "dream/returned/"
const ENTER_LINE := "СИНХРОНИЗАЦИЯ 100%% · %s"
const GATE_LINE := "ВЫХОД ЧЕРЕЗ ВРАТА · СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА"
const DEATH_LINE := "ПРИНУДИТЕЛЬНОЕ ВОЗВРАЩЕНИЕ · НЕСТАБИЛЬНОСТЬ +%d %%"
const WOKEN_LINE := "МОДУЛЬ ЗАПОЛНЕН СНОТВОРНЫМ · ВРЕМЯ НА РЕМОНТ СОКРАЩЕНО"
const TRANSITION_BY_EXIT: Array[DreamTransition.Mode] = [DreamTransition.Mode.GATE, DreamTransition.Mode.DEATH, DreamTransition.Mode.WOKEN]
## A torn interdream cuts to the death/awakening veil, which stays this long to be read.
const HARSH_VEIL_SECONDS := 0.6
const RESYNC_LINE := "Печать восстановлена. Требуется ресинхронизация капсулы — знаки записаны в журнале."

var time_ratio := 15.0
var entry_cost := 8.0
var death_penalty := 15.0
var seal_relief := 35.0
var dreams: Dictionary = {}

var in_dream := false
var module_id: StringName = &""
var real_seconds := 0.0
var subjective_seconds := 0.0
## The main task of the current visit (restoring the seal) is done. Every visit has its own
## main task; how many visits there are is decided by the story, not counted here.
var seal_restored := false
## Changes the scene; replaced in tests. Receives a scene path.
var scene_loader: Callable = _change_scene

var _return_scene := ""
var _return_chair: StringName = &""
var _fade: DreamTransition
var _afterimage: DreamAfterimage
var _interdream: InterdreamOverlay
## Bumped by abort(): an exit still under way stops where it is.
var _serial := 0


func _ready() -> void:
	load_config(_read(DATA_PATH))
	# The veil between the worlds: white on entry and at the gate, noise on death.
	_fade = DreamTransition.new()
	add_child(_fade)
	_afterimage = DreamAfterimage.new()
	add_child(_afterimage)
	# The hero's own short dream between the dream and the chair (#228).
	_interdream = InterdreamOverlay.new()
	add_child(_interdream)
	Containment.hero_woken.connect(func(id: StringName) -> void:
		if in_dream and id == module_id:
			_leave(Exit.WOKEN))


func load_config(data: Dictionary) -> void:
	time_ratio = float(data.get("time_ratio", time_ratio))
	entry_cost = float(data.get("entry_cost", entry_cost))
	death_penalty = float(data.get("death_penalty", death_penalty))
	seal_relief = float(data.get("seal_relief", seal_relief))
	dreams = data.get("dreams", {})


func _process(delta: float) -> void:
	if in_dream:
		real_seconds += delta
		subjective_seconds += delta * time_ratio


func dream_scene_for(id: StringName) -> String:
	return str((dreams.get(String(id), {}) as Dictionary).get("scene", ""))


## Starts the dream of `id` from the chair `chair_id` of the current scene.
func enter(id: StringName, chair_id: StringName, dream_scene: String = "") -> bool:
	if in_dream or Containment.is_awake(id):
		return false
	var path := dream_scene if not dream_scene.is_empty() else dream_scene_for(id)
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("Dreams: no dream scene for %s" % id)
		return false
	var current := get_tree().current_scene
	_return_scene = current.scene_file_path if current else ""
	_return_chair = chair_id
	module_id = id
	in_dream = true
	seal_restored = false
	real_seconds = 0.0
	subjective_seconds = 0.0
	Containment.add_instability(id, entry_cost)
	_fade.show_mode(DreamTransition.Mode.ENTER, ENTER_LINE % _module_label(id))
	entered.emit(id)
	await _fade_to(1.0)
	scene_loader.call(path)
	await _fade_to(0.0)
	return true


## Drops the session without a return (a defeat or a loaded save replaces the scene).
func abort() -> void:
	_serial += 1
	in_dream = false
	module_id = &""
	seal_restored = false
	real_seconds = 0.0
	subjective_seconds = 0.0
	_return_scene = ""
	_return_chair = &""
	if _fade:
		_fade.veil = 0.0
	if _afterimage:
		_afterimage.hide_now()
	if _interdream:
		_interdream.stop()


## The hero passed through the gate.
func exit_through_gate() -> void:
	_leave(Exit.GATE)


## The hero died in the dream: thrown back into the chair, the sleeper wakes faster.
func die() -> void:
	if in_dream:
		Containment.add_instability(module_id, death_penalty)
	_leave(Exit.DEATH)


## The main task of the visit (a restored seal) calms and prolongs the sleep, once per visit.
func restore_seal() -> void:
	if not in_dream or seal_restored:
		return
	seal_restored = true
	Containment.stabilize(module_id, seal_relief)
	seal_restored_signal.emit(module_id)


## Places the player at the chair after returning to the complex and tells how long the
## dream took. Called once the returned scene is ready; public for tests and custom loaders.
func arrive_in_reality(scene_root: Node, reason: Exit) -> void:
	_place_at_chair(scene_root)
	scene_root.get_tree().call_group(MESSAGE_GROUP, "show_message", return_title(reason), return_text(reason))


func _place_at_chair(scene_root: Node) -> void:
	for node in scene_root.get_tree().get_nodes_in_group(CHAIR_GROUP):
		if node.get("chair_id") == _return_chair and scene_root.is_ancestor_of(node):
			var player := scene_root.get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
			if player:
				player.global_transform = (node as Node3D).call("exit_transform")
			break


## The interdream that is playing (tests, the review tools).
func interdream() -> InterdreamOverlay:
	return _interdream


## System line of the veil when leaving the dream.
func exit_line(reason: Exit) -> String:
	match reason:
		Exit.DEATH:
			return DEATH_LINE % roundi(death_penalty)
		Exit.WOKEN:
			return WOKEN_LINE
	return GATE_LINE


func _module_label(id: StringName) -> String:
	return str((Containment.modules.get(id, {}) as Dictionary).get("label", id)).to_upper()


func return_title(reason: Exit) -> String:
	match reason:
		Exit.GATE:
			return "ПОГРУЖЕНИЕ ЗАВЕРШЕНО"
		Exit.WOKEN:
			return "ЭКСТРЕННОЕ ПРОБУЖДЕНИЕ"
	return "ВЫБРОС ИЗ СНА"


func return_text(reason: Exit) -> String:
	var text := "В реальности прошло %s; во сне — около %s." % [_duration(real_seconds), _duration(subjective_seconds)]
	if reason == Exit.DEATH:
		text = "Связь со сном прервана. Нестабильность модуля выросла.\n" + text
	elif reason == Exit.WOKEN:
		text = "Модуль заполнен снотворным. Силуэт из сна вытолкнул вас наружу — времени на ремонт меньше.\n" + text
	if not DreamKnowledge.active_for(module_id).is_empty():
		text += "\n" + RESYNC_LINE
	return text


func _leave(reason: Exit) -> void:
	if not in_dream:
		return
	in_dream = false
	var id := module_id
	var serial := _serial
	# Only the gate after a restored seal leaves its afterimage.
	var knowledge := DreamKnowledge.active_for(id) if reason == Exit.GATE and seal_restored else &""
	# Story conditions (objectives) need to know a module's dream was visited.
	# The echo is chosen before the exit sets its own flags.
	var echo := InterdreamEchoes.pick(id, reason)
	GameState.set_flag(StringName(RETURNED_PREFIX + String(id)))
	_fade.show_mode(TRANSITION_BY_EXIT[reason], exit_line(reason))
	left.emit(id, reason)
	if reason == Exit.GATE:
		# White veil with the system line → the corridor rises out of it, the complex loads
		# underneath → the corridor washes back into the white.
		await _fade_to(1.0)
		await _load_return()
		await _play_interdream(id, reason, echo)
	else:
		# Torn: the white (amber) cut over the dream at once, then the veil of the verdict.
		_play_interdream(id, reason, echo)
		await _load_return()
		if _interdream.playing:
			await _interdream.finished
		if serial != _serial:
			return
		_fade.veil = 1.0
		await get_tree().create_timer(HARSH_VEIL_SECONDS).timeout
	if serial != _serial:
		return
	get_tree().call_group(PLAYER_GROUP, "set_controls_locked", false)
	if get_tree().current_scene and not _return_scene.is_empty():
		arrive_in_reality(get_tree().current_scene, reason)
	if not knowledge.is_empty():
		_show_afterimage(id, knowledge)
	arrived.emit(id, reason)
	await _fade_to(0.0)


## Loads the scene the hero left for the dream and places the hero at the chair; the
## controls stay locked while the interdream plays.
func _load_return() -> void:
	if _return_scene.is_empty():
		return
	scene_loader.call(_return_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	if get_tree().current_scene:
		_place_at_chair(get_tree().current_scene)
	get_tree().call_group(PLAYER_GROUP, "set_controls_locked", true)


func _play_interdream(id: StringName, reason: Exit, echo: Dictionary) -> void:
	_interdream.play(echo, reason)
	var result: Array = await _interdream.finished
	InterdreamEchoes.report_seen(echo, float(result[1]))
	interdream_finished.emit(id, reason, str(result[0]), float(result[1]))


func _show_afterimage(id: StringName, knowledge: StringName) -> void:
	var code := DreamKnowledge.code(knowledge)
	if code.is_empty():
		return
	_afterimage.play(StringName(DreamKnowledge.definition(knowledge).get("dream", "")), code)
	afterimage_shown.emit(id, knowledge, code)


func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _fade_to(alpha: float) -> void:
	if _fade == null or not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(_fade, "veil", alpha, FADE_SECONDS)
	await tween.finished


static func _duration(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	if minutes >= 60:
		return "%d ч %d мин" % [minutes / 60, minutes % 60]
	if minutes > 0:
		return "%d мин" % minutes
	return "%d с" % int(seconds)


static func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
