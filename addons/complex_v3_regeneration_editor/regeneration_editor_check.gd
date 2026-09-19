extends SceneTree

const OPERATIONS_SCRIPT := preload("res://addons/complex_v3_regeneration_editor/regeneration_editor_operations.gd")


func _init() -> void:
	var operations: RefCounted = OPERATIONS_SCRIPT.new()
	if not OS.get_environment("COMPLEX_V3_SVG_TOOL_ROOT").is_empty():
		var toolchain: Dictionary = operations.resolve_toolchain({})
		_assert(bool(toolchain.get("ok", false)), "configured toolchain was not resolved: %s" % "; ".join(toolchain.get("errors", PackedStringArray()) as PackedStringArray))
	var manifest := "res://addons/complex_v3_regeneration_editor/fixtures/editor_manifest.json"
	var fixture_scene := load("res://addons/complex_v3_regeneration_editor/fixtures/fixture_scene.tscn") as PackedScene
	var fixture_root := fixture_scene.instantiate()
	var metadata_context: Dictionary = operations.resolve_sector({"complex_v3_sector_id": fixture_root.get_meta("complex_v3_sector_id")}, "res://outside.tscn", manifest)
	fixture_root.free()
	_assert(bool(metadata_context.get("ok", false)), "metadata sector resolution failed")
	_assert(metadata_context.get("source_svg") == "res://addons/complex_v3_regeneration_editor/fixtures/source.svg", "source path resolution failed")
	var production_manifest := "res://tools/complex_v3_regeneration/sector_generation_manifest.json"
	var production_context: Dictionary = operations.resolve_sector({"complex_v3_sector_id": "U-CONTROL"}, "", production_manifest)
	_assert(bool(production_context.get("ok", false)), "production sector resolution failed")
	_assert(production_context.get("source_svg") == "res://docs/design/complex_v3/plans/generation/upper/u_control.svg", "production source path is not canonical")
	var path_context: Dictionary = operations.resolve_sector({}, "res://addons/complex_v3_regeneration_editor/fixtures/live/generated.tscn", manifest)
	_assert(bool(path_context.get("ok", false)), "manifest path sector resolution failed")
	var conflict: Dictionary = operations.resolve_sector({"complex_v3_sector_id": "FIXTURE-EDITOR", "sector_id": "OTHER"}, "", manifest)
	_assert(not bool(conflict.get("ok", true)), "conflicting metadata was accepted")
	var invocation: Dictionary = operations.build_cli_invocation(metadata_context, {
		"python": "python-fixture", "manifest": manifest, "report": "user://fixture report.json",
		"svg_tool_root": "C:/SVG Tool", "stair_tool_root": "",
	}, true)
	_assert(bool(invocation.get("ok", false)), "CLI invocation was not built")
	var arguments := invocation.get("arguments", PackedStringArray()) as PackedStringArray
	_assert("--validate-only" in arguments and "--sector" in arguments and "FIXTURE-EDITOR" in arguments, "CLI arguments are incomplete")
	var report: Dictionary = operations.read_report("res://addons/complex_v3_regeneration_editor/fixtures/clean_report.json")
	_assert(bool(report.get("ok", false)) and report.get("last_stage") == "atomic_promotion", "report summary failed")
	_assert(not bool(report.get("offer_agent_fix", true)), "clean result offered Agent Fix")
	_assert(report.get("display_status") == "Clean" and int(report.get("problem_count", -1)) == 0, "clean status summary failed")
	_assert(operations.should_reload(0, report), "clean exit did not request reload")
	_assert(not operations.should_reload(2, report), "failed exit requested reload")
	var allowed_blocked: Dictionary = operations.read_report("res://addons/complex_v3_regeneration_editor/fixtures/allowed_blocked_report.json")
	_assert(bool(allowed_blocked.get("offer_agent_fix", false)), "authored missing-anchor blocker did not offer Agent Fix")
	_assert(allowed_blocked.get("display_status") == "Blocked" and int(allowed_blocked.get("problem_count", 0)) == 1, "blocked status summary failed")
	var denied_blocked: Dictionary = operations.read_report("res://addons/complex_v3_regeneration_editor/fixtures/denied_blocked_report.json")
	_assert(not bool(denied_blocked.get("offer_agent_fix", true)), "generated blocker offered Agent Fix")
	var invalid_source: Dictionary = operations.read_report("res://addons/complex_v3_regeneration_editor/fixtures/invalid_source_report.json")
	_assert(invalid_source.get("display_status") == "Failed", "invalid SVG was not classified as Failed")
	_assert(not bool(invalid_source.get("offer_agent_fix", true)), "invalid SVG offered Agent Fix")
	_assert(operations.has_unsaved_authored_changes("res://fixture.tscn", 6, 5), "unsaved version was not blocked")
	_assert(not operations.has_unsaved_authored_changes("res://fixture.tscn", 5, 5), "saved version was blocked")
	print("COMPLEX_V3_REGENERATION_EDITOR_CHECK_OK")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
