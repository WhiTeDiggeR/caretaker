extends Node

## Dream session (autoload `Dreams`): takes the hero from an immersion chair into the
## dream of a module and back. Canon (docs/world/02-world-rules.md): entering raises the
## instability, death in the dream throws the hero back into the chair and brings the
## awakening closer, the gate is the voluntary exit, subjective time runs faster while the
## complex keeps living in real time. Parameters: data/dreams/dreams.json.

signal entered(module_id: StringName)
signal left(module_id: StringName, reason: Exit)
signal seal_restored(module_id: StringName)

enum Exit { GATE, DEATH }

const DATA_PATH := "res://data/dreams/dreams.json"
const CHAIR_GROUP := &"immersion_chairs"
const PLAYER_GROUP := &"player"
const MESSAGE_GROUP := &"message_display"
const FADE_SECONDS := 0.6
const SEAL_FLAG_PREFIX := "dream/seal/"

var time_ratio := 15.0
var entry_cost := 8.0
var death_penalty := 15.0
var seal_relief := 35.0
var dreams: Dictionary = {}

var in_dream := false
var module_id: StringName = &""
var real_seconds := 0.0
var subjective_seconds := 0.0
## Changes the scene; replaced in tests. Receives a scene path.
var scene_loader: Callable = _change_scene

var _return_scene := ""
var _return_chair: StringName = &""
var _fade: ColorRect


func _ready() -> void:
	load_config(_read(DATA_PATH))
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(1, 1, 1, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


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
	real_seconds = 0.0
	subjective_seconds = 0.0
	Containment.add_instability(id, entry_cost)
	entered.emit(id)
	await _fade_to(1.0)
	scene_loader.call(path)
	await _fade_to(0.0)
	return true


## The hero passed through the gate.
func exit_through_gate() -> void:
	_leave(Exit.GATE)


## The hero died in the dream: thrown back into the chair, the sleeper wakes faster.
func die() -> void:
	if in_dream:
		Containment.add_instability(module_id, death_penalty)
	_leave(Exit.DEATH)


## A restored seal calms the dream.
func restore_seal() -> void:
	if not in_dream or is_seal_restored(module_id):
		return
	GameState.set_flag(StringName(SEAL_FLAG_PREFIX + String(module_id)))
	Containment.stabilize(module_id, seal_relief)
	seal_restored.emit(module_id)


func is_seal_restored(id: StringName) -> bool:
	return GameState.has_flag(StringName(SEAL_FLAG_PREFIX + String(id)))


## Places the player at the chair after returning to the complex. Called once the
## returned scene is ready; public for tests and custom scene loaders.
func arrive_in_reality(scene_root: Node, reason: Exit) -> void:
	for node in scene_root.get_tree().get_nodes_in_group(CHAIR_GROUP):
		if node.get("chair_id") == _return_chair and scene_root.is_ancestor_of(node):
			var player := scene_root.get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
			if player:
				player.global_transform = (node as Node3D).call("exit_transform")
			break
	scene_root.get_tree().call_group(MESSAGE_GROUP, "show_message", return_title(reason), return_text(reason))


func return_title(reason: Exit) -> String:
	return "ПОГРУЖЕНИЕ ЗАВЕРШЕНО" if reason == Exit.GATE else "ВЫБРОС ИЗ СНА"


func return_text(reason: Exit) -> String:
	var text := "В реальности прошло %s; во сне — около %s." % [_duration(real_seconds), _duration(subjective_seconds)]
	if reason == Exit.DEATH:
		text = "Связь со сном прервана. Нестабильность модуля выросла.\n" + text
	return text


func _leave(reason: Exit) -> void:
	if not in_dream:
		return
	in_dream = false
	var id := module_id
	left.emit(id, reason)
	await _fade_to(1.0)
	if not _return_scene.is_empty():
		scene_loader.call(_return_scene)
		await get_tree().process_frame
		await get_tree().process_frame
		if get_tree().current_scene:
			arrive_in_reality(get_tree().current_scene, reason)
	await _fade_to(0.0)


func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _fade_to(alpha: float) -> void:
	if _fade == null or not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_SECONDS)
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
