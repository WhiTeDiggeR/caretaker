class_name DebugStands
extends RefCounted

## Test stands of the sandbox (#239): data/debug/stands.json lists one small scene per feature
## with its Russian title, what to check there (2–4 items) and the progress state the stand
## sets on load. The F10 menu and the main menu item «Полигон» list them in this order; the
## last entry is the old sandbox with every station («всё вместе»). Format: docs/playtest.md.

const DATA_PATH := "res://data/debug/stands.json"
const VERSION := 1
const MIN_CHECKS := 2
const MAX_CHECKS := 4


## The stands in menu order ([] when the data is missing or broken).
static func list(path: String = DATA_PATH) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		push_error("DebugStands: no %s" % path)
		return result
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int((parsed as Dictionary).get("version", -1)) != VERSION:
		push_error("DebugStands: unsupported %s" % path)
		return result
	for stand: Variant in (parsed as Dictionary).get("stands", []):
		if stand is Dictionary:
			result.append(stand)
	return result


## The stand whose scene is `scene_path` ({} when none).
static func find(scene_path: String, stands: Array[Dictionary] = list()) -> Dictionary:
	for stand in stands:
		if str(stand.get("scene", "")) == scene_path:
			return stand
	return {}


## Problems of the list (empty when it is valid).
static func validate(stands: Array[Dictionary]) -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	var scenes := {}
	for stand in stands:
		var id := str(stand.get("id", ""))
		if id.is_empty() or str(stand.get("title", "")).is_empty():
			errors.append("every stand needs id and title")
		if ids.has(id):
			errors.append("duplicate stand %s" % id)
		ids[id] = true
		var scene := str(stand.get("scene", ""))
		if not ResourceLoader.exists(scene):
			errors.append("%s: no scene %s" % [id, scene])
		if scenes.has(scene):
			errors.append("%s: scene %s is already a stand" % [id, scene])
		scenes[scene] = true
		var checks: Array = stand.get("check", [])
		if checks.size() < MIN_CHECKS or checks.size() > MAX_CHECKS:
			errors.append("%s: %d items to check, want %d–%d" % [id, checks.size(), MIN_CHECKS, MAX_CHECKS])
	if stands.is_empty():
		errors.append("no stands")
	return errors


## The sign text under the stand's title: the numbered items to check and the plate key.
static func sign_text(stand: Dictionary) -> String:
	var lines := PackedStringArray(["Что проверить:"])
	var checks: Array = stand.get("check", [])
	for index in checks.size():
		lines.append("%d. %s" % [index + 1, checks[index]])
	lines.append("H — скрыть, F3 — сбросить стенд")
	return "\n".join(lines)
