class_name EventLibrary
extends RefCounted

## Catalogue of scripted events from data/events/*.json (format: data/events/README.md).

const DATA_DIR := "res://data/events"

static var _events: Dictionary = {}
static var _errors := PackedStringArray()
static var _loaded := false


static func reload() -> void:
	_events.clear()
	_errors.clear()
	_loaded = true
	for file in DirAccess.get_files_at(DATA_DIR):
		if file.get_extension() != "json":
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR.path_join(file)))
		if not parsed is Dictionary:
			_errors.append("%s: not a JSON object" % file)
			continue
		var events: Dictionary = (parsed as Dictionary).get("events", {})
		for id: String in events:
			if _events.has(id):
				_errors.append("%s: duplicate event '%s'" % [file, id])
			var steps: Variant = (events[id] as Dictionary).get("steps", [])
			if not steps is Array or (steps as Array).is_empty():
				_errors.append("%s/%s: steps must be a non-empty array" % [file, id])
				continue
			_errors.append_array(validate_steps(steps, "%s/%s" % [file, id]))
			_events[id] = steps


static func validate_steps(steps: Array, where: String) -> PackedStringArray:
	var found := PackedStringArray()
	for index in steps.size():
		var step: Variant = steps[index]
		if not step is Dictionary:
			found.append("%s[%d]: a step is an object" % [where, index])
			continue
		var actions := (step as Dictionary).keys().filter(func(key: String) -> bool: return key in EventSequence.STEP_KEYS)
		if actions.size() != 1:
			found.append("%s[%d]: exactly one action of %s" % [where, index, EventSequence.STEP_KEYS])
			continue
		match str(actions[0]):
			"door":
				if not str((step["door"] as Dictionary).get("action", "")) in EventSequence.DOOR_ACTIONS:
					found.append("%s[%d]: door action is one of %s" % [where, index, EventSequence.DOOR_ACTIONS])
			"power":
				if not str((step["power"] as Dictionary).get("power", "")) in StateRules.POWER_LEVELS:
					found.append("%s[%d]: power is one of %s" % [where, index, StateRules.POWER_LEVELS])
			"effects":
				found.append_array(StateRules.validate_effects(step["effects"], "%s[%d]" % [where, index]))
	return found


static func errors() -> PackedStringArray:
	_ensure()
	return _errors


static func has(id: StringName) -> bool:
	_ensure()
	return _events.has(String(id))


static func steps(id: StringName) -> Array:
	_ensure()
	return _events.get(String(id), [])


static func _ensure() -> void:
	if not _loaded:
		reload()
