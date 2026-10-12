class_name BugReport
extends RefCounted

## Bug report of a playtest (#169): `state.json` with the scene, the hero, flags, objectives,
## containment, the dream session and the build, plus `screenshot.png` when a frame can be
## taken (never in headless). Written to user://bug_reports/<local time>/. The `save` block
## is a regular save (Saves.capture), so the moment can be reproduced from it.

const VERSION := 1
const STATE_FILE := "state.json"
const SCREENSHOT_FILE := "screenshot.png"

static var directory := "user://bug_reports"


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


## Local time as a folder name: 2026-10-12_21-05-33.
static func _stamp() -> String:
	return Time.get_datetime_string_from_system(false, false).replace("T", "_").replace(":", "-")
