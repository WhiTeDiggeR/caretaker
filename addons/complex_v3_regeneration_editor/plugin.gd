@tool
extends EditorPlugin

const OPERATIONS_SCRIPT := preload("res://addons/complex_v3_regeneration_editor/regeneration_editor_operations.gd")
const ANCHOR_OPERATIONS_SCRIPT := preload("res://addons/complex_v3_anchor_editor/anchor_editor_operations.gd")
const SETTINGS_PREFIX := "complex_v3_regeneration/"

var _operations: ComplexV3RegenerationEditorOperations
var _anchor_operations: ComplexV3AnchorEditorOperations
var _panel: VBoxContainer
var _sector_label: Label
var _source_label: Label
var _stage_label: Label
var _exit_label: Label
var _status: Label
var _problems_label: Label
var _toolchain_label: Label
var _manifest: LineEdit
var _python: LineEdit
var _svg_root: LineEdit
var _stair_root: LineEdit
var _agent_launcher: LineEdit
var _anchor_id: LineEdit
var _agent_fix_button: Button
var _settings_toggle: Button
var _settings_container: VBoxContainer
var _report_path := ""
var _source_svg := ""
var _saved_versions: Dictionary = {}
var _thread: Thread
var _thread_result: Dictionary = {}
var _mutex := Mutex.new()
var _running := false
var _buttons: Array[Button] = []
var _resolved_toolchain: Dictionary = {}
var _active_context: Dictionary = {}
var _active_action := ""
var _reload_in_progress := false


func _enter_tree() -> void:
	_operations = OPERATIONS_SCRIPT.new()
	_anchor_operations = ANCHOR_OPERATIONS_SCRIPT.new()
	_ensure_editor_settings()
	_build_panel()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _panel)
	scene_changed.connect(_on_scene_changed)
	scene_saved.connect(_on_scene_saved)
	get_editor_interface().get_selection().selection_changed.connect(_refresh_context)
	_on_scene_changed(get_editor_interface().get_edited_scene_root())
	set_process(true)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if scene_saved.is_connected(_on_scene_saved):
		scene_saved.disconnect(_on_scene_saved)
	var selection := get_editor_interface().get_selection()
	if selection.selection_changed.is_connected(_refresh_context):
		selection.selection_changed.disconnect(_refresh_context)
	remove_control_from_docks(_panel)
	_panel.queue_free()


func _process(_delta: float) -> void:
	if not _running or _thread == null or _thread.is_alive():
		return
	_thread.wait_to_finish()
	_mutex.lock()
	var result := _thread_result.duplicate(true)
	_mutex.unlock()
	_running = false
	_finish_cli(int(result.get("exit_code", -1)), result.get("output", PackedStringArray()) as PackedStringArray)


func _build_panel() -> void:
	_panel = VBoxContainer.new()
	_panel.name = "Complex v3 Regeneration"
	var title := Label.new()
	title.text = "Complex v3 Sector Workflow"
	_panel.add_child(title)
	_sector_label = _add_label("Sector: unresolved")
	_source_label = _add_label("Source: unresolved")
	_toolchain_label = _add_label("Toolchain: checking...")
	_add_button("Open Source Plan", _open_source)
	_add_button("Regenerate Sector", func() -> void: _start_cli(false))
	_add_button("Validate Sector", func() -> void: _start_cli(true))
	_status = _add_label("Status: —")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems_label = _add_label("Problems: 0")
	_add_button("Show Report", _open_report)
	_agent_fix_button = _add_button("Agent Fix", _start_agent_fix)
	_agent_fix_button.visible = false
	var separator := HSeparator.new()
	_panel.add_child(separator)
	_settings_toggle = _add_button("Settings ▸", _toggle_settings)
	_settings_toggle.toggle_mode = true
	_settings_container = VBoxContainer.new()
	_settings_container.visible = false
	_panel.add_child(_settings_container)
	_manifest = _add_path("Manifest", "res://tools/complex_v3_regeneration/sector_generation_manifest.json", _settings_container)
	_python = _add_persistent_path("Python", "python_executable", _settings_container)
	_svg_root = _add_persistent_path("SVG tool root", "svg_tool_root", _settings_container)
	_stair_root = _add_persistent_path("Stair tool root", "stair_tool_root", _settings_container)
	_agent_launcher = _add_persistent_path("Agent launcher", "agent_launcher", _settings_container)
	_anchor_id = _add_path("Explicit anchor ID", "", _settings_container)
	_add_button("Bind selected", func() -> void: _binding_action("bind"), _settings_container)
	_add_button("Rebind selected", func() -> void: _binding_action("rebind"), _settings_container)
	_add_button("Unbind selected", func() -> void: _binding_action("unbind"), _settings_container)
	_stage_label = _add_label("Stage: idle", _settings_container)
	_exit_label = _add_label("Exit code: —", _settings_container)
	_refresh_toolchain()


func _add_label(text: String, parent: Container = null) -> Label:
	var label := Label.new()
	label.text = text
	(parent if parent != null else _panel).add_child(label)
	return label


func _add_path(label_text: String, initial: String, parent: Container = null) -> LineEdit:
	var target := parent if parent != null else _panel
	var label := Label.new()
	label.text = label_text
	target.add_child(label)
	var edit := LineEdit.new()
	edit.text = initial
	target.add_child(edit)
	return edit


func _add_persistent_path(label_text: String, key: String, parent: Container = null) -> LineEdit:
	var edit := _add_path(label_text, str(get_editor_interface().get_editor_settings().get_setting(SETTINGS_PREFIX + key)), parent)
	edit.text_submitted.connect(func(_value: String) -> void: _save_setting(key, edit.text))
	edit.focus_exited.connect(func() -> void: _save_setting(key, edit.text))
	return edit


func _ensure_editor_settings() -> void:
	var settings := get_editor_interface().get_editor_settings()
	for key: String in ["python_executable", "svg_tool_root", "stair_tool_root", "agent_launcher"]:
		var full_key := SETTINGS_PREFIX + key
		if not settings.has_setting(full_key):
			settings.set_setting(full_key, "")
		settings.add_property_info({"name": full_key, "type": TYPE_STRING, "hint": PROPERTY_HINT_GLOBAL_FILE if key in ["python_executable", "agent_launcher"] else PROPERTY_HINT_GLOBAL_DIR})


func _save_setting(key: String, value: String) -> void:
	get_editor_interface().get_editor_settings().set_setting(SETTINGS_PREFIX + key, value.strip_edges())
	_refresh_toolchain()


func _refresh_toolchain() -> void:
	if _operations == null or _toolchain_label == null:
		return
	_resolved_toolchain = _operations.resolve_toolchain({
		"python_executable": _python.text, "svg_tool_root": _svg_root.text,
		"stair_tool_root": _stair_root.text, "agent_launcher": _agent_launcher.text,
	})
	if bool(_resolved_toolchain.get("ok", false)):
		var versions := _resolved_toolchain.get("versions", {}) as Dictionary
		_toolchain_label.text = "Toolchain: Ready · SVG %s · Stairs %s" % [versions.get("svg_to_godot3d", "?"), versions.get("generate_godot_stairs", "?")]
	else:
		_toolchain_label.text = "Toolchain: Not configured · %s" % "; ".join(_resolved_toolchain.get("errors", PackedStringArray()) as PackedStringArray)


func _add_button(text: String, callback: Callable, parent: Container = null) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	(parent if parent != null else _panel).add_child(button)
	_buttons.append(button)
	return button


func _toggle_settings() -> void:
	_settings_container.visible = _settings_toggle.button_pressed
	_settings_toggle.text = "Settings ▾" if _settings_toggle.button_pressed else "Settings ▸"


func _on_scene_changed(root: Node) -> void:
	if root != null and not root.scene_file_path.is_empty() and not _saved_versions.has(root.scene_file_path):
		_saved_versions[root.scene_file_path] = _history_version(root)
	_refresh_context()


func _on_scene_saved(path: String) -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root != null and root.scene_file_path == path:
		_saved_versions[path] = _history_version(root)
	_refresh_context()


func _history_version(root: Node) -> int:
	var manager := get_undo_redo()
	var history_id := manager.get_object_history_id(root)
	var history := manager.get_history_undo_redo(history_id)
	return history.get_version() if history != null else -1


func _metadata(root: Node) -> Dictionary:
	var result := {}
	if root == null:
		return result
	for key: String in ["complex_v3_sector_id", "sector_id"]:
		if root.has_meta(key):
			result[key] = root.get_meta(key)
	return result


func _context() -> Dictionary:
	var root := get_editor_interface().get_edited_scene_root()
	return _operations.resolve_sector(_metadata(root), root.scene_file_path if root != null else "", _manifest.text)


func _refresh_context() -> void:
	if _operations == null or _manifest == null:
		return
	var context := _context()
	if bool(context.get("ok", false)):
		_sector_label.text = "Sector: %s" % context["sector_id"]
		_source_svg = str(context["source_svg"])
		_source_label.text = "Source: %s" % _source_svg
	else:
		_sector_label.text = "Sector: unresolved"
		_source_label.text = "Source: unresolved"
		_source_svg = ""


func _start_cli(validate_only: bool) -> void:
	if _running or _reload_in_progress:
		return
	_refresh_toolchain()
	if not bool(_resolved_toolchain.get("ok", false)):
		_show_errors(_resolved_toolchain.get("errors", PackedStringArray()) as PackedStringArray)
		return
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		_show_errors(PackedStringArray(["no edited scene"]))
		return
	if not validate_only:
		var saved_version := int(_saved_versions.get(root.scene_file_path, -1))
		if _operations.has_unsaved_authored_changes(root.scene_file_path, _history_version(root), saved_version):
			_show_errors(PackedStringArray(["Regenerate blocked: save authored scene changes first."]))
			return
	var context := _context()
	if not bool(context.get("ok", false)):
		_show_errors(context.get("errors", PackedStringArray()) as PackedStringArray)
		return
	_report_path = "user://complex_v3_regeneration_reports/%s-last.json" % str(context["sector_id"]).to_lower().replace("/", "-")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_report_path).get_base_dir())
	if FileAccess.file_exists(_report_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_report_path))
	var invocation := _operations.build_cli_invocation(context, {
		"python": str(_resolved_toolchain["python_executable"]), "manifest": _manifest.text, "report": _report_path,
		"svg_tool_root": str(_resolved_toolchain["svg_tool_root"]), "stair_tool_root": str(_resolved_toolchain["stair_tool_root"]),
	}, validate_only)
	if not bool(invocation.get("ok", false)):
		_show_errors(invocation.get("errors", PackedStringArray()) as PackedStringArray)
		return
	_active_context = context.duplicate(true)
	_active_action = "validate" if validate_only else "regenerate"
	_launch_invocation(invocation)


func _start_agent_fix() -> void:
	if _running or _reload_in_progress:
		return
	var report := _operations.read_report(_report_path)
	if not bool(report.get("ok", false)) or not bool(report.get("offer_agent_fix", false)):
		_show_errors(PackedStringArray(["Agent Fix is not available for this report."]))
		return
	_refresh_toolchain()
	if not bool(_resolved_toolchain.get("ok", false)):
		_show_errors(_resolved_toolchain.get("errors", PackedStringArray()) as PackedStringArray)
		return
	var context := _context()
	if not bool(context.get("ok", false)):
		_show_errors(context.get("errors", PackedStringArray()) as PackedStringArray)
		return
	var root := get_editor_interface().get_edited_scene_root()
	var saved_version := int(_saved_versions.get(root.scene_file_path, -1)) if root != null else -1
	if root == null or _operations.has_unsaved_authored_changes(root.scene_file_path, _history_version(root), saved_version):
		_show_errors(PackedStringArray(["Agent Fix blocked: save authored scene changes first."]))
		return
	var invocation := _operations.build_agent_fix_invocation(context, {
		"python": str(_resolved_toolchain["python_executable"]),
		"manifest": _manifest.text,
		"agent_launcher": str(_resolved_toolchain["agent_launcher"]),
		"svg_tool_root": str(_resolved_toolchain["svg_tool_root"]),
		"stair_tool_root": str(_resolved_toolchain["stair_tool_root"]),
	}, _report_path)
	if not bool(invocation.get("ok", false)):
		_show_errors(invocation.get("errors", PackedStringArray()) as PackedStringArray)
		return
	_active_context = context.duplicate(true)
	_active_action = "agent_fix"
	_launch_invocation(invocation)


func _launch_invocation(invocation: Dictionary) -> void:
	_running = true
	_set_buttons_enabled(false)
	_agent_fix_button.visible = false
	_stage_label.text = "Stage: %s" % _active_action
	_exit_label.text = "Exit code: running"
	_status.text = "Status: Running"
	_problems_label.text = "Problems: —"
	_thread_result = {}
	_thread = Thread.new()
	_thread.start(_run_cli.bind(str(invocation["executable"]), invocation["arguments"] as PackedStringArray))


func _run_cli(executable: String, arguments: PackedStringArray) -> void:
	var output := []
	var exit_code := OS.execute(executable, arguments, output, true)
	_mutex.lock()
	_thread_result = {"exit_code": exit_code, "output": PackedStringArray(output)}
	_mutex.unlock()


func _finish_cli(exit_code: int, output: PackedStringArray) -> void:
	_exit_label.text = "Exit code: %d" % exit_code
	var report := _operations.read_report(_report_path)
	if bool(report.get("ok", false)):
		_stage_label.text = "Stage: %s" % report["last_stage"]
		_status.text = "Status: %s" % report["display_status"]
		_problems_label.text = "Problems: %d" % int(report["problem_count"])
		_agent_fix_button.visible = bool(report.get("offer_agent_fix", false))
	else:
		_stage_label.text = "Stage: report_unavailable"
		_show_errors(report.get("errors", PackedStringArray()) as PackedStringArray, output)
	if _active_action != "validate" and _operations.should_reload(exit_code, report):
		_reload_in_progress = true
		_reload_promoted_sector()
	else:
		_set_buttons_enabled(true)


func _reload_promoted_sector() -> void:
	var filesystem := get_editor_interface().get_resource_filesystem()
	filesystem.scan()
	var frames := 0
	while filesystem.is_scanning() and frames < 600:
		await get_tree().process_frame
		frames += 1
	if filesystem.is_scanning():
		_finish_reload(PackedStringArray(["resource import did not finish in time"]))
		return
	await get_tree().process_frame
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or root.scene_file_path != str(_active_context.get("sector_scene", "")):
		_finish_reload(PackedStringArray(["the active scene changed while regeneration was running"]))
		return
	var errors := _replace_loaded_generated_resources(root, _active_context)
	if errors.is_empty() and root.has_method("rebuild_contract_generated"):
		errors.append_array(root.call("rebuild_contract_generated") as PackedStringArray)
	if not errors.is_empty():
		_finish_reload(errors)
		return
	var scene_path := root.scene_file_path
	get_editor_interface().reload_scene_from_path(scene_path)
	for _index: int in range(120):
		await get_tree().process_frame
		var reloaded := get_editor_interface().get_edited_scene_root()
		if reloaded != null and reloaded != root and reloaded.scene_file_path == scene_path:
			var controller := reloaded.get_node_or_null("AnchorController")
			if controller == null or not controller.has_method("apply_bindings"):
				errors.append("reloaded sector has no AnchorController")
			else:
				errors.append_array(controller.call("apply_bindings") as PackedStringArray)
			_finish_reload(errors)
			return
	_finish_reload(PackedStringArray(["sector scene reload did not complete in time"]))


func _replace_loaded_generated_resources(root: Node, context: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var sector := context.get("sector", {}) as Dictionary
	var output := str(context.get("output_resource_dir", "")).trim_suffix("/")
	var architecture_path := "%s/Generated/Architecture/%s.tscn" % [output, str(sector.get("scene_name", ""))]
	var architecture := ResourceLoader.load(architecture_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if architecture == null:
		errors.append("generated architecture failed to import: %s" % architecture_path)
	else:
		root.set("generated_architecture_scene", architecture)
	var vertical_value: Variant = sector.get("vertical_generators", [])
	if vertical_value is Array and not (vertical_value as Array).is_empty():
		var generator := (vertical_value as Array)[0] as Dictionary
		var generator_id := str(generator.get("generator_id", ""))
		var stair_path := "%s/Generated/Stairs/%s/%s.tscn" % [output, generator_id, generator_id]
		var stairs := ResourceLoader.load(stair_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
		if stairs == null:
			errors.append("generated stairs failed to import: %s" % stair_path)
		else:
			root.set("generated_stairs_scene", stairs)
	return errors


func _finish_reload(errors: PackedStringArray) -> void:
	_reload_in_progress = false
	if errors.is_empty():
		_status.text = "Status: Clean"
		_problems_label.text = "Problems: 0"
		var root := get_editor_interface().get_edited_scene_root()
		if root != null and not root.scene_file_path.is_empty():
			_saved_versions[root.scene_file_path] = _history_version(root)
	else:
		_status.text = "Status: Failed · %s" % "; ".join(errors)
		_problems_label.text = "Problems: %d" % errors.size()
		_agent_fix_button.visible = false
	_set_buttons_enabled(true)


func _set_buttons_enabled(enabled: bool) -> void:
	for button: Button in _buttons:
		button.disabled = not enabled


func _open_source() -> void:
	_refresh_context()
	if _source_svg.is_empty() or not FileAccess.file_exists(_source_svg):
		_show_errors(PackedStringArray(["source SVG is unresolved or missing"]))
		return
	OS.shell_open(ProjectSettings.globalize_path(_source_svg))


func _open_report() -> void:
	if _report_path.is_empty() or not FileAccess.file_exists(_report_path):
		_show_errors(PackedStringArray(["no regeneration report is available"]))
		return
	OS.shell_open(ProjectSettings.globalize_path(_report_path))


func _binding_action(action: String) -> void:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.size() != 1 or not selected[0] is AnchoredObject3D:
		_show_errors(PackedStringArray(["select exactly one AnchoredObject3D"]))
		return
	var object := selected[0] as AnchoredObject3D
	if action == "unbind":
		_show_errors(_anchor_operations.unbind(get_undo_redo(), object))
		return
	var registry := object.anchor_registry
	if registry == null:
		registry = _single_registry(get_editor_interface().get_edited_scene_root())
	var placement := object.placement.duplicate(true) as ComplexV3AnchorPlacement if object.placement != null else ComplexV3AnchorPlacement.new()
	var errors := _anchor_operations.bind(get_undo_redo(), object, registry, _anchor_id.text.strip_edges(), placement) if action == "bind" else _anchor_operations.rebind(get_undo_redo(), object, registry, _anchor_id.text.strip_edges(), placement)
	_show_errors(errors)


func _single_registry(root: Node) -> ComplexV3AnchorRegistry:
	var registries: Array[ComplexV3AnchorRegistry] = []
	_collect_registries(root, registries)
	return registries[0] if registries.size() == 1 else null


func _collect_registries(node: Node, result: Array[ComplexV3AnchorRegistry]) -> void:
	if node == null:
		return
	if node is ComplexV3AnchorRegistry:
		result.append(node as ComplexV3AnchorRegistry)
	for child: Node in node.get_children():
		_collect_registries(child, result)


func _show_errors(errors: PackedStringArray, output: PackedStringArray = PackedStringArray()) -> void:
	if errors.is_empty():
		_status.text = "Status: Clean"
		_problems_label.text = "Problems: 0"
	else:
		_status.text = "Status: Blocked · %s" % "; ".join(errors)
		_problems_label.text = "Problems: %d" % errors.size()
	if not output.is_empty():
		_status.text += "\n%s" % "\n".join(output)
