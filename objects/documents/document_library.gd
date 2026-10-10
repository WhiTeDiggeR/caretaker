class_name DocumentLibrary
extends RefCounted

## Catalogue of readable documents from data/documents/*.json and the journal of read
## documents (kept in GameState, so it is saved). See data/documents/README.md.

const DATA_DIR := "res://data/documents"
const JOURNAL_FLAG := &"journal/read"

static var _documents: Dictionary = {}
static var _errors := PackedStringArray()
static var _loaded := false


static func reload() -> void:
	_documents.clear()
	_errors.clear()
	_loaded = true
	for file in DirAccess.get_files_at(DATA_DIR):
		if file.get_extension() != "json":
			continue
		var path := DATA_DIR.path_join(file)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			_errors.append("%s: not a JSON object" % file)
			continue
		var documents: Dictionary = (parsed as Dictionary).get("documents", {})
		for id: String in documents:
			var document: Dictionary = documents[id]
			if _documents.has(id):
				_errors.append("%s: duplicate document '%s'" % [file, id])
			if str(document.get("title", "")).is_empty() or str(document.get("body", "")).is_empty():
				_errors.append("%s/%s: title and body are required" % [file, id])
			_errors.append_array(StateRules.validate_effects(document.get("on_read", []), "%s/%s" % [file, id]))
			if not bool(document.get("journal", true)) and document.has("on_read"):
				_errors.append("%s/%s: an inspect text (journal: false) never runs on_read; use Interactable.sets_flag" % [file, id])
			document["id"] = id
			_documents[id] = document


static func errors() -> PackedStringArray:
	_ensure()
	return _errors


static func has(id: String) -> bool:
	_ensure()
	return _documents.has(id)


## {id, title, meta, body, on_read, journal}; an empty dictionary for an unknown id.
static func get_document(id: String) -> Dictionary:
	_ensure()
	return _documents.get(id, {})


static func ids() -> Array:
	_ensure()
	return _documents.keys()


## Marks a document as read: appends it to the journal and applies its `on_read` effects
## the first time. Returns true for a newly read document.
static func mark_read(id: String) -> bool:
	if not has(id) or is_read(id) or not bool(get_document(id).get("journal", true)):
		return false
	var journal := read_ids()
	journal.append(id)
	GameState.set_flag(JOURNAL_FLAG, journal)
	StateRules.apply(get_document(id).get("on_read", []))
	return true


static func is_read(id: String) -> bool:
	return id in read_ids()


## Read document ids in reading order.
static func read_ids() -> Array[String]:
	var result: Array[String] = []
	for id: Variant in GameState.get_flag(JOURNAL_FLAG, []):
		result.append(str(id))
	return result


static func _ensure() -> void:
	if not _loaded:
		reload()
