@tool
extends EditorPlugin

const OPERATIONS_SCRIPT := preload("res://addons/complex_v3_regeneration_editor/regeneration_editor_operations.gd")
const ANCHOR_OPERATIONS_SCRIPT := preload("res://addons/complex_v3_anchor_editor/anchor_editor_operations.gd")

var _operations: ComplexV3RegenerationEditorOperations
var _anchor_operations: ComplexV3AnchorEditorOperations
var _panel: VBoxContainer
var _sector_label: Label
var _stage_label: Label
var _exit_label: Label
var _status: Label
var _manifest: LineEdit
var _python: LineEdit
var _svg_root: LineEdit
var _stair_root: LineEdit
var _anchor_id: LineEdit
var _report_path := ""
var _source_svg := ""
var _output_resource_dir := ""
var _saved_versions: Dictionary = {}
var _thread: Thread
var _thread_result: Dictionary = {}
var _mutex := Mutex.new()
var _running := false
var _buttons: Array[Button] = []


func _enter_tree() -> void:
	_operations = OPERATIONS_SCRIPT.new()
	_anchor_operations = ANCHOR_OPERATIONS_SCRIPT.new()
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
	_set_buttons_enabled(true)
	_finish_cli(int(result.get("exit_code", -1)), result.get("output", PackedStringArray()) as PackedStringArray)


func _build_panel() -> void:
	_panel = VBoxContainer.new()
	_panel.name = "Complex v3 Regeneration"
	var title := Label.new()
	title.text = "Complex v3 Sector Workflow"
	_panel.add_child(title)
	_sector_label = _add_label("Sector: unresolved")
	_stage_label = _add_label("Stage: idle")
	_exit_label = _add_label("Exit code: —")
	_status = _add_label("Open a sector scene or select a sector root.")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_manifest = _add_path("Manifest", "res://tools/complex_v3_regeneration/sector_generation_manifest.json")
	_python = _add_path("Python", "python")
	_svg_root = _add_path("SVG tool root", "")
	_stair_root = _add_path("Stair tool root", "")
	_add_button("Regenerate Sector", func() -> void: _start_cli(false))
	_add_button("Validate Sector", func() -> void: _start_cli(true))
	_add_button("Open Source SVG", _open_source)
	_add_button("Show Last Report", _open_report)
	var separator := HSeparator.new()
	_panel.add_child(separator)
	_anchor_id = _add_path("Explicit anchor ID", "")
	_add_button("Bind selected", func() -> void: _binding_action("bind"))
	_add_button("Rebind selected", func() -> void: _binding_action("rebind"))
	_add_button("Unbind selected", func() -> void: _binding_action("unbind"))


func _add_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	_panel.add_child(label)
	return label


func _add_path(label_text: String, initial: String) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	_panel.add_child(label)
	var edit := LineEdit.new()
	edit.text = initial
	_panel.add_child(edit)
	return edit


func _add_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	_panel.add_child(button)
	_buttons.append(button)
	return button


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
		_output_resource_dir = str(context["output_resource_dir"])
	else:
		_sector_label.text = "Sector: unresolved"
		_source_svg = ""
		_output_resource_dir = ""


func _start_cli(validate_only: bool) -> void:
	if _running:
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
	var invocation := _operations.build_cli_invocation(context, {
		"python": _python.text, "manifest": _manifest.text, "report": _report_path,
		"svg_tool_root": _svg_root.text, "stair_tool_root": _stair_root.text,
	}, validate_only)
	if not bool(invocation.get("ok", false)):
		_show_errors(invocation.get("errors", PackedStringArray()) as PackedStringArray)
		return
	_running = true
	_set_buttons_enabled(false)
	_stage_label.text = "Stage: external_cli"
	_exit_label.text = "Exit code: running"
	_status.text = "Report: %s" % ProjectSettings.globalize_path(_report_path)
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
		_status.text = "Status: %s\nReport: %s" % [report["status"], ProjectSettings.globalize_path(_report_path)]
	else:
		_stage_label.text = "Stage: report_unavailable"
		_show_errors(report.get("errors", PackedStringArray()) as PackedStringArray, output)
	if _operations.should_reload(exit_code, report):
		get_editor_interface().get_resource_filesystem().scan()
		var root := get_editor_interface().get_edited_scene_root()
		if root != null and (root.scene_file_path == _output_resource_dir or root.scene_file_path.begins_with(_output_resource_dir.trim_suffix("/") + "/")):
			get_editor_interface().reload_scene_from_path(root.scene_file_path)


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
		_status.text = "Operation completed. Editor Undo/Redo is available for binding changes."
	else:
		_status.text = "Blocked: %s" % "; ".join(errors)
	if not output.is_empty():
		_status.text += "\n%s" % "\n".join(output)
