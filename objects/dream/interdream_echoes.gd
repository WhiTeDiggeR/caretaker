class_name InterdreamEchoes
extends RefCounted

## Echoes of the interdream (docs/game_design/10-interdream.md, issue #228): the hero's own
## short dream between someone else's dream and the chair. One echo per exit — the matching
## one with the highest priority; data/dreams/interdream.json. Death never gets an echo (an
## engine rule, not data); the chemical awakening only gets echoes listing "woken".

const DATA_PATH := "res://data/dreams/interdream.json"
const SHOWN_PREFIX := "interdream/shown/"
const EXIT_NAMES: Array[String] = ["gate", "death", "woken"]
const DEFAULT_EXITS: Array[String] = ["gate"]
const PROPS: Array[String] = ["plate_2", "plate_2_healed", "plate_2_turned", "plate_2_flash", "silhouette_far", "silhouette_near", "key_lanyard"]
const ADD_DOCUMENT := "add_document"

static var config: Dictionary = {}
static var _loaded := false


static func reload(data: Dictionary = {}) -> void:
	config = data if not data.is_empty() else _read(DATA_PATH)
	_loaded = true


static func seconds(key: String, fallback: float) -> float:
	_ensure()
	return float(config.get(key, fallback))


static func echoes() -> Dictionary:
	_ensure()
	return config.get("echoes", {})


## The echo for leaving the dream of `module_id` by `exit` (Dreams.Exit): {id, priority,
## props, sounds, mandatory, ...}; an empty dictionary for a quiet interdream.
static func pick(module_id: StringName, exit: int) -> Dictionary:
	var exit_name := EXIT_NAMES[exit] if exit >= 0 and exit < EXIT_NAMES.size() else ""
	if exit_name.is_empty() or exit_name == "death":
		return {}
	var best: Dictionary = {}
	var all := echoes()
	for id: String in all:
		var echo: Dictionary = all[id]
		var exits: Array = echo.get("exits", DEFAULT_EXITS)
		var dreams: Array = echo.get("dreams", [])
		if not exit_name in exits or (not dreams.is_empty() and not String(module_id) in dreams):
			continue
		if not StateRules.check(echo.get("when", {})):
			continue
		if best.is_empty() or int(echo.get("priority", 0)) > int(best.get("priority", 0)):
			best = echo.duplicate()
			best["id"] = id
	return best


static func shown_flag(id: String) -> StringName:
	return StringName(SHOWN_PREFIX + id)


## The echo was on screen for `seen` seconds: from `min_seen_seconds` on it counts as shown —
## its flag is set and its `on_shown` runs; an echo skipped earlier comes back next time.
static func report_seen(echo: Dictionary, seen: float) -> bool:
	if echo.is_empty() or seen < float(echo.get("min_seen_seconds", seconds("min_seen_seconds", 1.5))):
		return false
	GameState.set_flag(shown_flag(str(echo.get("id", ""))))
	var effects: Array = []
	for effect: Dictionary in echo.get("on_shown", []):
		if effect.has(ADD_DOCUMENT):
			DocumentLibrary.mark_read(str(effect[ADD_DOCUMENT]))
		else:
			effects.append(effect)
	StateRules.apply(effects)
	return true


static func validate() -> PackedStringArray:
	var found := PackedStringArray()
	var all := echoes()
	if all.is_empty():
		found.append("interdream: no echoes")
	for id: String in all:
		var echo: Dictionary = all[id]
		for exit: Variant in echo.get("exits", DEFAULT_EXITS):
			if not str(exit) in ["gate", "woken"]:
				found.append("interdream/%s: exit '%s' (gate or woken; death never has an echo)" % [id, exit])
		for prop: Variant in echo.get("props", []):
			if not str(prop) in PROPS:
				found.append("interdream/%s: unknown prop '%s'" % [id, prop])
		for sound: Dictionary in echo.get("sounds", []):
			if not Sfx.sounds.has(StringName(str(sound.get("sfx", "")))):
				found.append("interdream/%s: unknown sound '%s'" % [id, sound.get("sfx", "")])
		var effects: Array = []
		for effect: Dictionary in echo.get("on_shown", []):
			if effect.has(ADD_DOCUMENT):
				if not DocumentLibrary.has(str(effect[ADD_DOCUMENT])):
					found.append("interdream/%s: unknown document '%s'" % [id, effect[ADD_DOCUMENT]])
			else:
				effects.append(effect)
		found.append_array(StateRules.validate_effects(effects, "interdream/" + id))
	return found


static func _ensure() -> void:
	if not _loaded:
		reload()


static func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
