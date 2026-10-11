class_name Saves
extends RefCounted

## Save games: the scene, the hero's position and view, the whole GameState and the state of
## every node in the `persist` group (doors, airlocks…) keyed by its path in the scene.
## Nodes in `persist` implement `save_state() -> Dictionary` and `load_state(Dictionary)`.

const VERSION := 1
const AUTO := "auto"
const SLOTS: Array[String] = [AUTO, "slot_1", "slot_2", "slot_3"]
const PERSIST_GROUP := &"persist"
const PLAYER_GROUP := &"player"

static var directory := "user://saves"


static func path_for(slot: String) -> String:
	return directory.path_join(slot + ".json")


static func slot_title(slot: String) -> String:
	return "Автосохранение" if slot == AUTO else "Слот %s" % slot.trim_prefix("slot_")


## Snapshot of the running game.
static func capture(tree: SceneTree) -> Dictionary:
	var scene := tree.current_scene
	var data := {
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"scene": scene.scene_file_path if scene else "",
		"objective": GameState.objective_text,
		"state": GameState.to_dict(),
		"objects": {},
	}
	var player := tree.get_first_node_in_group(PLAYER_GROUP) as Node3D
	if player:
		var camera := player.get_node_or_null(^"Camera3D") as Node3D
		data["player"] = {
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"yaw": player.rotation.y,
			"pitch": camera.rotation.x if camera else 0.0,
		}
	if scene:
		for node in tree.get_nodes_in_group(PERSIST_GROUP):
			if scene.is_ancestor_of(node):
				data["objects"][str(scene.get_path_to(node))] = node.call("save_state")
	return data


static func write(slot: String, tree: SceneTree) -> Error:
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(path_for(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(capture(tree), "\t"))
	return OK


static func read(slot: String) -> Dictionary:
	if not FileAccess.file_exists(path_for(slot)):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path_for(slot)))
	if not parsed is Dictionary or int((parsed as Dictionary).get("version", -1)) != VERSION:
		return {}
	return parsed


static func exists(slot: String) -> bool:
	return not read(slot).is_empty()


static func delete(slot: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(slot)))


## The most recent slot, or "" when there is no save.
static func latest() -> String:
	var best := ""
	var best_time := -1.0
	for slot in SLOTS:
		var data := read(slot)
		if not data.is_empty() and float(data.get("saved_at", 0.0)) > best_time:
			best_time = float(data["saved_at"])
			best = slot
	return best


## One line for the slot list: time and objective, or «пусто».
static func describe(slot: String) -> String:
	var data := read(slot)
	if data.is_empty():
		return "%s — пусто" % slot_title(slot)
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var when := Time.get_datetime_dict_from_unix_time(int(float(data["saved_at"])) + bias)
	var stamp := "%02d.%02d.%04d %02d:%02d" % [when.day, when.month, when.year, when.hour, when.minute]
	var objective := str(data.get("objective", ""))
	return "%s — %s%s" % [slot_title(slot), stamp, (" — " + objective) if not objective.is_empty() else ""]


## Restores objects and the hero into the already loaded scene of `data`.
## GameState is restored separately, before the scene is loaded.
static func apply_to_scene(tree: SceneTree, data: Dictionary) -> void:
	var scene := tree.current_scene
	if scene == null:
		return
	var objects: Dictionary = data.get("objects", {})
	for path: String in objects:
		var node := scene.get_node_or_null(NodePath(path))
		if node and node.has_method("load_state"):
			node.call("load_state", objects[path])
	var player := tree.get_first_node_in_group(PLAYER_GROUP) as Node3D
	var saved: Dictionary = data.get("player", {})
	if player and not saved.is_empty():
		var position: Array = saved["position"]
		player.global_position = Vector3(float(position[0]), float(position[1]), float(position[2]))
		player.rotation.y = float(saved.get("yaw", 0.0))
		var camera := player.get_node_or_null(^"Camera3D") as Node3D
		if camera:
			camera.rotation.x = float(saved.get("pitch", 0.0))
