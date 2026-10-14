extends Node

## Headless check of the review hall (#192): every station refers to an existing scene and
## spot, the hall builds a pad per station, each station loads and F9 (ReviewReturn) brings the
## hero back to the hall, and docs/review/manual_checklist.md lists the same stations.
## Detaches itself from `current_scene` so the scene changes keep it.
## Prints `REVIEW_HUB_OK stations=<n>` on success.

const SETTLE_FRAMES := 10
const TIMEOUT_FRAMES := 1200
const SPAWN_TOLERANCE := 1.5
const PLAYER_GROUP := &"player"


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


func _ready() -> void:
	OS.add_logger(_logger)
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	tree.current_scene = null
	var stations := ReviewStations.STATIONS
	var moments := ReviewStations.moment_index()
	_check_data(stations, moments)
	_check_checklist(stations)
	ReviewHub.open()
	_check(await _wait_for_scene(ReviewHub.SCENE), "the hall loads")
	var hub := tree.current_scene as ReviewHub
	_check(hub != null and hub.pads.size() == stations.size(), "a pad per station")
	for station in stations:
		await _check_station(station, moments)
	OS.remove_logger(_logger)
	if _logger.count > 0:
		_errors.append("%d engine/script errors, last: %s" % [_logger.count, _logger.last])
	for error in _errors:
		printerr("FAIL ", error)
	if _errors.is_empty():
		print("REVIEW_HUB_OK stations=%d" % stations.size())
	tree.quit(0 if _errors.is_empty() else 1)


func _check_data(stations: Array[Dictionary], moments: Dictionary) -> void:
	var ids: Dictionary = {}
	for station in stations:
		var id := str(station.get("id", ""))
		_check(not id.is_empty() and not ids.has(id), "station id %s is unique" % id)
		ids[id] = true
		for key: String in ["issue", "title", "check", "expect"]:
			_check(station.has(key), "%s: has %s" % [id, key])
		if station.has("moment"):
			_check(moments.has(StringName(str(station["moment"]))), "%s: moment %s exists" % [id, station["moment"]])
		var entry := ReviewStations.entry(station, moments)
		_check(ResourceLoader.exists(str(entry.get("scene", ""))), "%s: scene %s exists" % [id, entry.get("scene", "")])
		var dream: Dictionary = entry.get("dream", {})
		if not dream.is_empty():
			_check(ResourceLoader.exists(Dreams.dream_scene_for(StringName(str(dream["module"])))), "%s: dream scene exists" % id)


func _check_checklist(stations: Array[Dictionary]) -> void:
	var text := FileAccess.get_file_as_string(ReviewStations.CHECKLIST)
	_check(not text.is_empty(), "checklist exists")
	var sections := 0
	for line in text.split("\n"):
		if line.begins_with("## "):
			sections += 1
	_check(sections == stations.size(), "checklist has %d sections, stations %d" % [sections, stations.size()])
	for station in stations:
		var heading := "## #%d · %s" % [int(station["issue"]), station["title"]]
		_check(text.contains(heading), "checklist lists «%s»" % heading)


func _check_station(station: Dictionary, moments: Dictionary) -> void:
	var id := str(station["id"])
	var entry := ReviewStations.entry(station, moments)
	var hub := get_tree().current_scene as ReviewHub
	if hub == null:
		_errors.append("%s: not started from the hall" % id)
		return
	_check(hub.travel(station), "%s: trip started" % id)
	await get_tree().process_frame
	for _i in TIMEOUT_FRAMES:
		if not Debug.busy:
			break
		await get_tree().process_frame
	_check(not Debug.busy and Debug.last_moment == ReviewHub.moment_id(station), "%s: loaded" % id)
	await _frames(SETTLE_FRAMES)
	var dream: Dictionary = entry.get("dream", {})
	var expected := str(entry["scene"])
	if not dream.is_empty() and str(dream.get("exit", "")) != "gate":
		expected = Dreams.dream_scene_for(StringName(str(dream["module"])))
	var scene := get_tree().current_scene
	_check(scene != null and scene.scene_file_path == expected, "%s: scene is %s" % [id, expected])
	var spawn: Dictionary = dream.get("spawn", {}) if not dream.is_empty() else entry.get("spawn", {})
	if scene and spawn.has("node"):
		var anchor := scene.get_node_or_null(NodePath(str(spawn["node"]))) as Node3D
		var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
		_check(anchor != null and player != null, "%s: spawn %s and hero found" % [id, spawn["node"]])
		if anchor and player:
			var offset: Array = spawn.get("offset", [0, 0, 0])
			var wanted := anchor.global_position + Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
			_check(player.global_position.distance_to(wanted) < SPAWN_TOLERANCE, "%s: hero at the spot" % id)
	var back := get_tree().root.get_node_or_null(NodePath(String(ReviewReturn.NODE_NAME))) as ReviewReturn
	_check(back != null and back._hint.visible, "%s: the way back is shown" % id)
	var key := InputEventKey.new()
	key.keycode = ReviewReturn.RETURN_KEY
	key.pressed = true
	Input.parse_input_event(key)
	_check(await _wait_for_scene(ReviewHub.SCENE), "%s: F9 returns to the hall" % id)


func _wait_for_scene(path: String) -> bool:
	var tree := get_tree()
	await tree.process_frame
	for _i in TIMEOUT_FRAMES:
		if tree.current_scene and tree.current_scene.scene_file_path == path and not Shell.loading:
			await _frames(SETTLE_FRAMES)
			return true
		await tree.process_frame
	return false


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
