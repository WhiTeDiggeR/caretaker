@tool
extends RefCounted
class_name ComplexV3RegenerationEditorOperations

const REPORT_SCHEMA_ID := "caretaker.safe_regeneration_report"
const REPORT_SCHEMA_VERSION := "1.0.0"
const CLEAN_STATUSES := ["success", "noop", "validated"]


func load_json_object(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and not FileAccess.file_exists(path):
		return {"ok": false, "errors": PackedStringArray(["file is missing: %s" % path])}
	var value: Variant = JSON.parse_string(text)
	if not value is Dictionary:
		return {"ok": false, "errors": PackedStringArray(["JSON root must be an object: %s" % path])}
	return {"ok": true, "value": value as Dictionary, "errors": PackedStringArray()}


func resolve_sector(metadata: Dictionary, scene_path: String, manifest_path: String) -> Dictionary:
	var loaded := load_json_object(manifest_path)
	if not bool(loaded.get("ok", false)):
		return loaded
	var manifest := loaded["value"] as Dictionary
	var sectors_value: Variant = manifest.get("sectors")
	if not sectors_value is Array:
		return _blocked("manifest sectors must be an array")
	var declared_ids: Array[String] = []
	for key: String in ["complex_v3_sector_id", "sector_id"]:
		var value := str(metadata.get(key, "")).strip_edges()
		if not value.is_empty() and value not in declared_ids:
			declared_ids.append(value)
	if declared_ids.size() > 1:
		return _blocked("conflicting sector metadata: %s" % ", ".join(declared_ids))
	var path_matches: Array[String] = []
	var normalized_scene := scene_path.replace("\\", "/")
	for sector_value: Variant in sectors_value:
		if not sector_value is Dictionary:
			continue
		var sector := sector_value as Dictionary
		var sector_id := str(sector.get("sector_id", ""))
		var output_root := str(sector.get("output_resource_dir", "")).trim_suffix("/")
		if not sector_id.is_empty() and not output_root.is_empty() and (normalized_scene == output_root or normalized_scene.begins_with(output_root + "/")):
			path_matches.append(sector_id)
	if path_matches.size() > 1:
		return _blocked("scene path matches multiple sector outputs")
	var resolved_id := declared_ids[0] if declared_ids.size() == 1 else (path_matches[0] if path_matches.size() == 1 else "")
	if resolved_id.is_empty():
		return _blocked("sector ID is missing; set complex_v3_sector_id metadata or open a scene under one manifest output")
	if declared_ids.size() == 1 and path_matches.size() == 1 and declared_ids[0] != path_matches[0]:
		return _blocked("sector metadata conflicts with the scene output path")
	var matches: Array[Dictionary] = []
	for sector_value: Variant in sectors_value:
		if sector_value is Dictionary and str((sector_value as Dictionary).get("sector_id", "")) == resolved_id:
			matches.append(sector_value as Dictionary)
	if matches.size() != 1:
		return _blocked("unknown or duplicate sector ID: %s" % resolved_id)
	var sector := matches[0]
	var source_svg := _project_path(manifest_path, str(manifest.get("project_root", ".")), str(sector.get("source_svg", "")))
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"sector_id": resolved_id,
		"sector": sector,
		"source_svg": source_svg,
		"output_resource_dir": str(sector.get("output_resource_dir", "")),
	}


func build_cli_invocation(context: Dictionary, settings: Dictionary, validate_only: bool) -> Dictionary:
	if not bool(context.get("ok", false)):
		return context
	var python := str(settings.get("python", "")).strip_edges()
	var manifest := str(settings.get("manifest", "")).strip_edges()
	var report := str(settings.get("report", "")).strip_edges()
	if python.is_empty() or manifest.is_empty() or report.is_empty():
		return _blocked("python, manifest and report paths are required")
	var backend := str(settings.get("backend", "res://tools/complex_v3_regeneration/regenerate_sector.py"))
	var validator := str(settings.get("composition_validator", "res://tools/complex_v3_composition_validator/validate_composition.py"))
	var arguments := PackedStringArray([
		_globalize(str(settings.get("orchestrator", "res://tools/complex_v3_regeneration/safe_regenerate.py"))),
		"--sector", str(context["sector_id"]),
		"--manifest", _globalize(manifest),
		"--backend", _globalize(backend),
		"--composition-validator", _globalize(validator),
		"--python", python,
		"--report", _globalize(report),
	])
	var svg_root := str(settings.get("svg_tool_root", "")).strip_edges()
	var stair_root := str(settings.get("stair_tool_root", "")).strip_edges()
	if not svg_root.is_empty():
		arguments.append_array(PackedStringArray(["--svg-tool-root", _globalize(svg_root)]))
	if not stair_root.is_empty():
		arguments.append_array(PackedStringArray(["--stair-tool-root", _globalize(stair_root)]))
	if validate_only:
		arguments.append("--validate-only")
	return {"ok": true, "errors": PackedStringArray(), "executable": python, "arguments": arguments, "report": _globalize(report)}


func read_report(path: String) -> Dictionary:
	var loaded := load_json_object(path)
	if not bool(loaded.get("ok", false)):
		return loaded
	var report := loaded["value"] as Dictionary
	if report.get("schema_id") != REPORT_SCHEMA_ID or report.get("schema_version") != REPORT_SCHEMA_VERSION:
		return _blocked("unsupported safe regeneration report schema")
	var stages_value: Variant = report.get("stages", [])
	var last_stage := "none"
	if stages_value is Array and not stages_value.is_empty() and stages_value[-1] is Dictionary:
		last_stage = str((stages_value[-1] as Dictionary).get("stage", "none"))
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"report": report,
		"status": str(report.get("status", "unknown")),
		"last_stage": last_stage,
		"ready": bool(report.get("ready", false)),
		"offer_agent_fix": false,
	}


func has_unsaved_authored_changes(scene_path: String, current_version: int, saved_version: int) -> bool:
	return scene_path.is_empty() or saved_version < 0 or current_version != saved_version


func should_reload(exit_code: int, report_result: Dictionary) -> bool:
	return exit_code == 0 and bool(report_result.get("ok", false)) and bool(report_result.get("ready", false)) and str(report_result.get("status", "")) in CLEAN_STATUSES


func _project_path(manifest_path: String, project_root: String, relative: String) -> String:
	var manifest_absolute := _globalize(manifest_path)
	var absolute := manifest_absolute.get_base_dir().path_join(project_root).path_join(relative).simplify_path()
	return ProjectSettings.localize_path(absolute)


func _globalize(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path


func _blocked(message: String) -> Dictionary:
	return {"ok": false, "errors": PackedStringArray([message])}
