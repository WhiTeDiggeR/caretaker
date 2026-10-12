extends Node

## Headless check of the playtest tools (#169): every moment of data/debug/moments.json loads
## without errors and sets its state, the cheats work, the bug report writes its JSON
## without a screenshot (headless) and the tools remove themselves when disabled (release).
## Detaches itself from `current_scene` so the scene changes keep it.
## Prints `DEBUG_MOMENTS_OK moments=<n>` on success.

const SETTLE_FRAMES := 20
const INSTABILITY_TOLERANCE := 2.0
const SPAWN_TOLERANCE := 1.5
const FALL_LIMIT_Y := -5.0
const REPORT_DIR := "user://bug_reports_check"


## Counts engine and script errors (warnings are not errors).
class ErrorCounter extends Logger:
	var count := 0
	var last := ""
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		count += 1
		last = "%s (%s:%d %s)" % [rationale if not rationale.is_empty() else code, file, line, function]
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _errors := PackedStringArray()
var _logger := ErrorCounter.new()


func _ready() -> void:
	OS.add_logger(_logger)
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	tree.current_scene = null
	_check(is_instance_valid(Debug) and Debug.enabled, "Debug is active in a debug build")
	var data: Dictionary = Debug.data()
	for problem in DebugMoments.validate(data):
		_errors.append("moments data: " + problem)
	var ids: Array[StringName] = Debug.moment_ids()
	for id in ids:
		await _check_moment(id)
		if id == &"dream_seal":
			await _check_invulnerability()
	await _check_cheats()
	await _check_menu()
	await _check_report()
	await _check_release()
	OS.remove_logger(_logger)
	for error in _errors:
		printerr("FAIL ", error)
	if _errors.is_empty():
		print("DEBUG_MOMENTS_OK moments=%d" % ids.size())
	tree.quit(0 if _errors.is_empty() else 1)


func _check_moment(id: StringName) -> void:
	var moment: Dictionary = Debug.moment(id)
	var expect: Dictionary = moment.get("expect", {})
	var state: Dictionary = moment.get("state", {})
	var errors_before := _logger.count
	var loaded: bool = await Debug.go_to_moment(id)
	_check(loaded, "%s: loaded" % id)
	await _frames(SETTLE_FRAMES)
	var scene := get_tree().current_scene
	var expected_scene := str(expect.get("scene", moment["scene"]))
	_check(scene != null and scene.scene_file_path == expected_scene, "%s: scene is %s" % [id, expected_scene])
	_check(Debug.last_moment == id, "%s: remembered as the last moment" % id)
	var flags: Array = (state.get("flags", []) as Array) + (expect.get("flags", []) as Array)
	for flag: Variant in flags:
		_check(GameState.has_flag(StringName(str(flag))), "%s: flag %s" % [id, flag])
	for grant: Variant in state.get("access", []):
		_check(GameState.has_access(StringName(str(grant))), "%s: access %s" % [id, grant])
	var power: Dictionary = state.get("section_power", {})
	for section: String in power:
		_check(GameState.power_name(GameState.get_section_power(StringName(section))) == str(power[section]), "%s: power of %s" % [id, section])
	var instability: Dictionary = state.get("instability", {})
	var dream: Dictionary = moment.get("dream", {})
	for module: String in instability:
		var value := Containment.get_instability(StringName(module))
		var wanted := float(instability[module])
		# A dream entry adds its cost; returning may restore part of it.
		var upper := wanted + INSTABILITY_TOLERANCE + (Dreams.entry_cost if not dream.is_empty() else 0.0)
		_check(value >= wanted - Dreams.seal_relief - INSTABILITY_TOLERANCE and value <= upper, "%s: %s instability %.1f near %.1f" % [id, module, value, wanted])
	if expect.has("objective"):
		_check(String(GameState.objective_id) == str(expect["objective"]), "%s: objective %s, got %s" % [id, expect["objective"], GameState.objective_id])
	_check(Dreams.in_dream == bool(expect.get("in_dream", false)), "%s: in dream %s" % [id, Dreams.in_dream])
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	_check(player != null, "%s: the hero is in the scene" % id)
	if player:
		_check(player.global_position.y > FALL_LIMIT_Y, "%s: the hero stands (y %.1f)" % [id, player.global_position.y])
		var spawn: Dictionary = dream.get("spawn", {}) if not dream.is_empty() else moment.get("spawn", {})
		if spawn.has("node") and str(dream.get("exit", "")).is_empty():
			var anchor := scene.get_node(NodePath(str(spawn["node"]))) as Node3D
			var target := anchor.global_position + _vector(spawn.get("offset", []))
			var offset := player.global_position - target
			_check(Vector2(offset.x, offset.z).length() < SPAWN_TOLERANCE, "%s: the hero at the spawn (offset %s)" % [id, offset])
	_check(_logger.count == errors_before, "%s: loads without errors (%d, last: %s)" % [id, _logger.count - errors_before, _logger.last])


func _check_invulnerability() -> void:
	var combat := get_tree().get_first_node_in_group(&"dream_combat") as DreamCombat
	_check(combat != null, "the dream has combat")
	if combat == null:
		return
	Debug.set_invulnerable(true)
	combat.take_damage(combat.max_resolve * 2.0, combat.player().global_position if combat.player() else Vector3.ZERO)
	await _frames(5)
	_check(Dreams.in_dream, "invulnerable hero stays in the dream")
	_check(is_equal_approx(combat.resolve, combat.max_resolve), "invulnerability refills resolve")
	Debug.set_invulnerable(false)


func _check_cheats() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	Debug.set_noclip(true)
	_check(player != null and not player.is_physics_processing(), "noclip takes the hero's physics over")
	Debug.set_noclip(false)
	_check(player != null and player.is_physics_processing(), "noclip off gives physics back")
	GameState.revoke_access(&"module_3")
	Debug.grant_all_access()
	for grant: Variant in (Debug.data()["cheats"] as Dictionary)["access"]:
		_check(GameState.has_access(StringName(str(grant))), "cheat grants %s" % grant)
	Debug.set_instability(&"module_4", 25.0)
	_check(is_equal_approx(Containment.get_instability(&"module_4"), 25.0), "cheat sets instability")
	Debug.set_time_scale(1.0)
	Debug.cycle_time_scale()
	_check(Containment.time_scale > 1.0, "time speeds up (x%s)" % Containment.time_scale)
	Debug.set_time_scale(1.0)
	await _frames(1)


func _check_menu() -> void:
	Debug.open_menu()
	await _frames(2)
	_check(Debug.is_menu_open() and get_tree().paused, "menu opens and pauses")
	var menu := Debug.get_node_or_null(^"DebugMenu")
	var count := 0
	if menu:
		for id: StringName in Debug.moment_ids():
			if menu.find_child(String(id), true, false) is ShellButton:
				count += 1
	_check(count == Debug.moment_ids().size(), "menu lists every moment (%d)" % count)
	Debug.close_menu()
	await _frames(2)
	_check(not Debug.is_menu_open() and not get_tree().paused, "menu closes and resumes")


func _check_report() -> void:
	BugReport.directory = REPORT_DIR
	var folder: String = await Debug.write_report()
	_check(not folder.is_empty(), "report written")
	if folder.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(BugReport.STATE_FILE)))
	_check(parsed is Dictionary, "report JSON parses")
	if parsed is Dictionary:
		var report: Dictionary = parsed
		for key in ["scene", "player", "flags", "objective", "objectives", "containment", "game_version", "godot_version", "save", "debug"]:
			_check(report.has(key), "report has %s" % key)
		_check(str(report.get("scene", "")) == get_tree().current_scene.scene_file_path, "report names the scene")
		_check(report.get("screenshot") == null and report.has("screenshot_note"), "headless report has no screenshot and says why")
		_check(str((report.get("debug", {}) as Dictionary).get("last_moment", "")) == String(Debug.last_moment), "report names the last moment")
		_check(((report.get("save", {}) as Dictionary).get("state", {}) as Dictionary).has("flags"), "report carries a loadable save")
	_check(not FileAccess.file_exists(folder.path_join(BugReport.SCREENSHOT_FILE)), "no screenshot file in headless")
	_check(not Debug.toast_text().is_empty(), "report shows a notice")
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	DirAccess.remove_absolute(REPORT_DIR)


func _check_release() -> void:
	var tools: Node = (load("res://objects/debug/debug.gd") as GDScript).new()
	tools.set(&"enabled", false)
	get_tree().root.add_child(tools)
	_check(tools.get_child_count() == 0, "disabled tools build nothing")
	await _frames(2)
	_check(not is_instance_valid(tools), "disabled tools remove themselves")


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


static func _vector(raw: Variant) -> Vector3:
	if raw is Array and (raw as Array).size() == 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3.ZERO
