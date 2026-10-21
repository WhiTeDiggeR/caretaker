class_name ItemCatalog
extends RefCounted

## Items the hero carries (#223), from data/items/*.json. An item is the GameState flag its
## pickup sets, so it is saved with the game; there is no separate inventory to use or drop.
## The journal's «При себе» tab lists the carried ones. See data/items/README.md.

const DATA_DIR := "res://data/items"

static var _items: Dictionary = {}
static var _errors := PackedStringArray()
static var _loaded := false


static func reload() -> void:
	_items.clear()
	_errors.clear()
	_loaded = true
	for file in DirAccess.get_files_at(DATA_DIR):
		if file.get_extension() != "json":
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR.path_join(file)))
		if not parsed is Dictionary:
			_errors.append("%s: not a JSON object" % file)
			continue
		var items: Dictionary = (parsed as Dictionary).get("items", {})
		for flag: String in items:
			var item: Dictionary = items[flag]
			if _items.has(flag):
				_errors.append("%s: duplicate item '%s'" % [file, flag])
			if str(item.get("title", "")).is_empty() or str(item.get("note", "")).is_empty():
				_errors.append("%s/%s: title and note are required" % [file, flag])
			item["flag"] = flag
			_items[flag] = item


static func errors() -> PackedStringArray:
	_ensure()
	return _errors


static func has(flag: StringName) -> bool:
	_ensure()
	return _items.has(String(flag))


## {flag, title, note, sketch, tag, until}; an empty dictionary for an unknown flag.
static func get_item(flag: StringName) -> Dictionary:
	_ensure()
	return _items.get(String(flag), {})


## Items whose flag is set and whose `until` flag (a spent cylinder) is not, in catalogue order.
static func carried() -> Array[Dictionary]:
	_ensure()
	var result: Array[Dictionary] = []
	for flag: String in _items:
		var until := StringName(str(_items[flag].get("until", "")))
		if GameState.has_flag(StringName(flag)) and (until.is_empty() or not GameState.has_flag(until)):
			result.append(_items[flag])
	return result


static func _ensure() -> void:
	if not _loaded:
		reload()
