extends Node

## Runs the headless checks of the opening systems (issues #98-#105).
## Prints `OPENING_CHECKS checks=N failures=0` on success; exits with 1 on any failure.
## A GDScript runtime error inside a case is a failure too (issue #163).

const CASES: Array[String] = [
	"res://tests/opening/cases/game_state_case.gd",
	"res://tests/opening/cases/sandbox_case.gd",
	"res://tests/opening/cases/movement_case.gd",
	"res://tests/opening/cases/climb_case.gd",
	"res://tests/opening/cases/interaction_case.gd",
	"res://tests/opening/cases/door_case.gd",
	"res://tests/opening/cases/power_case.gd",
	"res://tests/opening/cases/terminal_case.gd",
	"res://tests/opening/cases/repair_case.gd",
	"res://tests/opening/cases/document_case.gd",
	"res://tests/opening/cases/containment_case.gd",
	"res://tests/opening/cases/dream_case.gd",
	"res://tests/opening/cases/chemical_case.gd",
	"res://tests/opening/cases/combat_case.gd",
	"res://tests/opening/cases/dream_dash_case.gd",
	"res://tests/opening/cases/ambush_case.gd",
	"res://tests/opening/cases/remains_case.gd",
	"res://tests/opening/cases/props_case.gd",
	"res://tests/opening/cases/breach_case.gd",
	"res://tests/opening/cases/settings_case.gd",
	"res://tests/opening/cases/dream_keys_case.gd",
	"res://tests/opening/cases/saves_case.gd",
	"res://tests/opening/cases/defeat_case.gd",
	"res://tests/opening/cases/sfx_case.gd",
	"res://tests/opening/cases/objectives_case.gd",
	"res://tests/opening/cases/part2_case.gd",
	"res://tests/opening/cases/storage_case.gd",
	"res://tests/opening/cases/part2_upper_case.gd",
	"res://tests/opening/cases/part2_lower_case.gd",
	"res://tests/opening/cases/part2_post2_case.gd",
	"res://tests/opening/cases/feel_case.gd",
	"res://tests/opening/cases/events_case.gd",
	"res://tests/opening/cases/resync_case.gd",
	"res://tests/opening/cases/seal_rings_case.gd",
	"res://tests/opening/cases/shell_ui_case.gd",
	"res://tests/opening/cases/ui_showroom_case.gd",
]


func _ready() -> void:
	# Cases wake modules on purpose; only the defeat case lets that stop the game.
	Shell.defeat_enabled = false
	var total_checks := 0
	var failures := PackedStringArray()
	var script_errors := ScriptErrorLogger.new()
	OS.add_logger(script_errors)
	for path in CASES:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			failures.append("%s: script does not load" % path)
			continue
		var case_root := Node3D.new()
		var case_name := path.get_file().get_basename()
		case_root.name = case_name
		add_child(case_root)
		var context := OpeningCheck.new(get_tree(), case_root)
		context.begin_case(case_name)
		GameState.reset()
		var case: Object = script.new()
		await case.run(context)
		total_checks += context.checks
		failures.append_array(context.failures)
		case_root.queue_free()
		await get_tree().process_frame
		for error in script_errors.take():
			failures.append("%s: %s" % [case_name, error])
	GameState.reset()
	OS.remove_logger(script_errors)
	for failure in failures:
		printerr("FAIL ", failure)
	print("OPENING_CHECKS checks=%d failures=%d" % [total_checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
