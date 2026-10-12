class_name DebugMoments
extends RefCounted

## Playtest moments (#169): data/debug/moments.json describes each moment as a scene, a spawn
## point and the state to set (flags, access, section power, instability, objective chain),
## optionally followed by a dream entry or a return from it. Moments are data, so pointing
## them at the complex later is an edit of the JSON. Format: docs/playtest.md.

const DATA_PATH := "res://data/debug/moments.json"
const VERSION := 1
const DEFAULT_TIME_SCALES: Array[float] = [1.0, 10.0, 60.0]


## The whole document ({} when it is missing or broken).
static func read(path: String = DATA_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DebugMoments: no %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int((parsed as Dictionary).get("version", -1)) != VERSION:
		push_error("DebugMoments: unsupported %s" % path)
		return {}
	return parsed


## Problems of the document (empty when it is valid).
static func validate(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	for moment: Dictionary in data.get("moments", []):
		var id := str(moment.get("id", ""))
		if id.is_empty() or str(moment.get("title", "")).is_empty():
			errors.append("every moment needs id and title")
		if seen.has(id):
			errors.append("duplicate moment %s" % id)
		seen[id] = true
		var scene := str(moment.get("scene", ""))
		if not ResourceLoader.exists(scene):
			errors.append("%s: no scene %s" % [id, scene])
		var dream: Dictionary = moment.get("dream", {})
		if not dream.is_empty() and str(dream.get("module", "")).is_empty():
			errors.append("%s: a dream needs its module" % id)
	if seen.is_empty():
		errors.append("no moments")
	return errors


## Applies the moment's `state` block on top of what the freshly loaded scene set up for
## itself (the sandbox's own sections, for one). `reset: true` clears that first.
static func apply_state(state: Dictionary) -> void:
	if bool(state.get("reset", false)):
		GameState.reset()
	var flags: Variant = state.get("flags", [])
	if flags is Dictionary:
		for flag: String in flags:
			GameState.set_flag(StringName(flag), flags[flag])
	else:
		for flag: Variant in flags:
			GameState.set_flag(StringName(str(flag)))
	for grant: Variant in state.get("access", []):
		GameState.grant_access(StringName(str(grant)))
	var power: Dictionary = state.get("section_power", {})
	for section: String in power:
		var index := GameState.POWER_NAMES.find(str(power[section]))
		if index < 0:
			push_warning("DebugMoments: unknown power %s" % power[section])
			continue
		GameState.set_section_power(StringName(section), index)
	var instability: Dictionary = state.get("instability", {})
	for module: String in instability:
		Containment.set_instability(StringName(module), float(instability[module]))
	var chain := str(state.get("objective_chain", ""))
	if not chain.is_empty():
		Objectives.start(StringName(chain))
		Objectives.evaluate()


## Places the hero: at `position` (world) or at the node `node` of `root` shifted by `offset`
## (world axes); `yaw` in degrees, 0 looks along −Z. An empty spawn keeps the scene's own.
static func place_player(root: Node, player: Node3D, spawn: Dictionary) -> bool:
	if spawn.is_empty() or player == null:
		return spawn.is_empty()
	var origin := Vector3.ZERO
	if spawn.has("node"):
		var anchor := root.get_node_or_null(NodePath(str(spawn["node"]))) as Node3D
		if anchor == null:
			push_error("DebugMoments: no spawn node %s" % spawn["node"])
			return false
		origin = anchor.global_position
	origin += _vector(spawn.get("offset", spawn.get("position", [])))
	player.global_position = origin
	player.rotation = Vector3(0.0, deg_to_rad(float(spawn.get("yaw", 0.0))), 0.0)
	var body := player as CharacterBody3D
	if body:
		body.velocity = Vector3.ZERO
	var camera := player.get_node_or_null(^"Camera3D") as Node3D
	if camera:
		camera.rotation.x = 0.0
	return true


static func time_scales(data: Dictionary) -> Array[float]:
	var scales: Array[float] = []
	for value: Variant in (data.get("cheats", {}) as Dictionary).get("time_scales", []):
		scales.append(float(value))
	return scales if not scales.is_empty() else DEFAULT_TIME_SCALES


static func _vector(raw: Variant) -> Vector3:
	if raw is Array and (raw as Array).size() == 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3.ZERO
