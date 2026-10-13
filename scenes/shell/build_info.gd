class_name BuildInfo
extends RefCounted

## Version of the running game for the menu footer and the log (issue #168):
## `application/config/version` from project.godot plus the short commit hash that
## tools/build/export.sh writes to res://build_info.json right before an export.
## In the editor and in builds made without the script the hash reads as «dev».

const PATH := "res://build_info.json"
const DEFAULT_VERSION := "0.0.0"
const DEV_COMMIT := "dev"

static var _logged := false


static func version() -> String:
	var value := str(ProjectSettings.get_setting("application/config/version", ""))
	return value if not value.is_empty() else DEFAULT_VERSION


static func commit() -> String:
	if not FileAccess.file_exists(PATH):
		return DEV_COMMIT
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is Dictionary:
		var value := str((data as Dictionary).get("commit", ""))
		if not value.is_empty():
			return value
	return DEV_COMMIT


## «0.1.0 · 1a2b3c4»
static func label() -> String:
	return "%s · %s" % [version(), commit()]


## Writes the version to the log once per run, so every log file names its build.
static func log_once() -> void:
	if _logged:
		return
	_logged = true
	print("Сборка %s, лог: %s" % [label(), ProjectSettings.globalize_path("user://logs")])
