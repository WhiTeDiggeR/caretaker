extends Node

## Runs the headless checks of the opening systems (issues #98-#105).
## Prints `OPENING_CHECKS checks=N failures=0` on success; exits with 1 on any failure.

const CASES: Array[String] = [
	"res://tests/opening/cases/game_state_case.gd",
	"res://tests/opening/cases/sandbox_case.gd",
	"res://tests/opening/cases/movement_case.gd",
	"res://tests/opening/cases/interaction_case.gd",
	"res://tests/opening/cases/door_case.gd",
	"res://tests/opening/cases/power_case.gd",
	"res://tests/opening/cases/terminal_case.gd",
]


func _ready() -> void:
	var total_checks := 0
	var failures := PackedStringArray()
	for path in CASES:
		var case_root := Node3D.new()
		case_root.name = path.get_file().get_basename()
		add_child(case_root)
		var context := OpeningCheck.new(get_tree(), case_root)
		context.begin_case(case_root.name)
		GameState.reset()
		var case: Object = load(path).new()
		await case.run(context)
		total_checks += context.checks
		failures.append_array(context.failures)
		case_root.queue_free()
		await get_tree().process_frame
	GameState.reset()
	for failure in failures:
		printerr("FAIL ", failure)
	print("OPENING_CHECKS checks=%d failures=%d" % [total_checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
