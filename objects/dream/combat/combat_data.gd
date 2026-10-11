class_name DreamCombatData
extends RefCounted

## Parameters of dream combat (data/dreams/combat.json): the hero, weapons («образы») and
## enemies. Test values; see docs/game_design/05-dream-combat.md.

const DATA_PATH := "res://data/dreams/combat.json"

static var _data: Dictionary = {}


static func all() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func hero() -> Dictionary:
	return all().get("hero", {})


static func weapon(id: StringName) -> Dictionary:
	return (all().get("weapons", {}) as Dictionary).get(String(id), {})


static func enemy(id: StringName) -> Dictionary:
	return (all().get("enemies", {}) as Dictionary).get(String(id), {})
