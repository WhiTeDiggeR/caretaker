class_name BugReport
extends RefCounted

## Bug report of a playtest (#169): `state.json` with the scene, the hero, flags, objectives,
## containment, the dream session and the build, plus `screenshot.png` when a frame can be
## taken (never in headless) and `godot.log` with the tail of the game log (#172) when file
## logging is on. Written to user://bug_reports/<local time>/. The `save` block is a regular
## save (Saves.capture), so the moment can be reproduced from it.

const VERSION := 2
const STATE_FILE := "state.json"
const SCREENSHOT_FILE := "screenshot.png"
const LOG_FILE := "godot.log"
const LOG_TAIL_LINES := 2000
const LOG_ENABLED_SETTING := "debug/file_logging/enable_file_logging"
const LOG_PATH_SETTING := "debug/file_logging/log_path"

static var directory := "user://bug_reports"
## Log to copy; empty means the file log from project settings (tests point it elsewhere).
static var log_path := ""


## Snapshot of the running game; `extra` (cheats, last moment) is merged in at the top level.
static func capture(tree: SceneTree, extra: Dictionary = {}) -> Dictionary:
	var scene := tree.current_scene
	var save := Saves.capture(tree)
	var instability := {}
	for module: StringName in Containment.modules:
		instability[String(module)] = Containment.get_instability(module)
	var step := Objectives.current_step()
	var data := {
		"version": VERSION,
		"created_at": Time.get_datetime_string_from_system(false, true),
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"godot_version": Engine.get_version_info().get("string", ""),
		"build": {"version": BuildInfo.version(), "commit": BuildInfo.commit(), "label": BuildInfo.label()},
		"debug_build": OS.is_debug_build(),
		"os": OS.get_name(),
		"scene": scene.scene_file_path if scene else "",
		"player": save.get("player", {}),
		"objective": {"id": String(GameState.objective_id), "text": GameState.objective_text},
		"objectives": {
			"chain": String(Objectives.active_chain()),
			"step": str(step.get("id", "")),
			"completed": Objectives.is_completed(),
		},
		"flags": (save["state"] as Dictionary).get("flags", {}),
		"access": (save["state"] as Dictionary).get("access", []),
		"section_power": (save["state"] as Dictionary).get("section_power", {}),
		"containment": {"instability": instability, "time_scale": Containment.time_scale},
		"dream": {"in_dream": Dreams.in_dream, "module": String(Dreams.module_id)},
		"screenshot": null,
		"log": null,
		"log_source": "",
		"save": save,
	}
	data.merge(extra, true)
	return data


## Writes a report and returns its folder ("" on failure). `screenshot` may be null.
static func write(tree: SceneTree, screenshot: Image, extra: Dictionary = {}) -> String:
	var folder := directory.path_join(_stamp())
	var suffix := 2
	while DirAccess.dir_exists_absolute(folder):
		folder = directory.path_join("%s_%d" % [_stamp(), suffix])
		suffix += 1
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		push_error("BugReport: cannot create %s" % folder)
		return ""
	var data := capture(tree, extra)
	if screenshot and not screenshot.is_empty():
		if screenshot.save_png(folder.path_join(SCREENSHOT_FILE)) == OK:
			data["screenshot"] = SCREENSHOT_FILE
	else:
		data["screenshot_note"] = "кадр недоступен (%s)" % DisplayServer.get_name()
	_attach_log(folder, data)
	var file := FileAccess.open(folder.path_join(STATE_FILE), FileAccess.WRITE)
	if file == null:
		push_error("BugReport: cannot write %s" % folder.path_join(STATE_FILE))
		return ""
	file.store_string(JSON.stringify(data, "\t"))
	return folder


## The frame as the player sees it (HUD included), or null when nothing is rendered.
static func grab_screenshot(tree: SceneTree) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	return image if image and not image.is_empty() else null


## The log the game writes now, "" when file logging is off.
static func current_log_path() -> String:
	if not log_path.is_empty():
		return log_path
	if not bool(ProjectSettings.get_setting(LOG_ENABLED_SETTING, false)):
		return ""
	return str(ProjectSettings.get_setting(LOG_PATH_SETTING, ""))


## Copies the last LOG_TAIL_LINES lines of the log into the report folder and records it in
## `data`; a missing or unreadable log only leaves a note, the report is written anyway.
static func _attach_log(folder: String, data: Dictionary) -> void:
	var source := current_log_path()
	if source.is_empty():
		data["log_note"] = "файловый лог выключен (%s)" % LOG_ENABLED_SETTING
		return
	data["log_source"] = ProjectSettings.globalize_path(source)
	if not FileAccess.file_exists(source):
		data["log_note"] = "лог не найден"
		return
	var text := FileAccess.get_file_as_string(source)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		data["log_note"] = "лог не читается (ошибка %d)" % FileAccess.get_open_error()
		return
	var lines := text.split("\n")
	if not lines.is_empty() and lines[lines.size() - 1].is_empty():
		lines.remove_at(lines.size() - 1)
	var total := lines.size()
	if total > LOG_TAIL_LINES:
		lines = lines.slice(total - LOG_TAIL_LINES)
	var file := FileAccess.open(folder.path_join(LOG_FILE), FileAccess.WRITE)
	if file == null:
		data["log_note"] = "копия лога не записана (ошибка %d)" % FileAccess.get_open_error()
		return
	file.store_string("\n".join(lines) + ("\n" if not lines.is_empty() else ""))
	file.close()
	data["log"] = LOG_FILE
	data["log_lines"] = lines.size()
	data["log_truncated"] = total > LOG_TAIL_LINES


## Local time as a folder name: 2026-10-12_21-05-33.
static func _stamp() -> String:
	return Time.get_datetime_string_from_system(false, false).replace("T", "_").replace(":", "-")
