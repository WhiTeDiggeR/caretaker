extends RefCounted

## #227: the part 2 chain follows the opening, the old control post shows the recovery map
## and marks the finished directions, progress survives saving and loading.

const OLD_CP := "res://data/terminals/opening_old_cp.json"
const DIRECTIONS: Array[StringName] = [&"part2/dir_lower_done", &"part2/dir_upper_done", &"part2/dir_storage_done"]


func run(c: OpeningCheck) -> void:
	GameState.reset()
	await c.tree.process_frame
	c.is_true(Objectives.chains.has(&"part2"), "part2 chain loads")
	Objectives.start(&"opening")
	for step: Dictionary in Objectives.chains[&"opening"]["steps"]:
		GameState.set_flag(StringName(str(step["done_when"]["flag"])))
	await c.tree.process_frame
	c.equal(Objectives.active_chain(), &"part2", "the end of the opening hands over to part2")
	c.equal(GameState.objective_id, &"part2_old_cp", "part2 starts with the way back to the old control post")

	var program := TerminalProgram.load_file(OLD_CP)
	c.equal(program.enter("main")["id"], "main_powered", "without caretaker rights the old post keeps its opening screen")
	GameState.grant_access(&"caretaker")
	var view := program.enter("main")
	c.equal(view["id"], "recovery_map", "after the first dream the old post opens the recovery map")
	var texts := _texts(view)
	c.is_true(texts.has("КАРТА ВОССТАНОВЛЕНИЯ") and texts.filter(func(t: String) -> bool: return t.begins_with("[ ]")).size() == 3, "three open directions are listed")
	program.complete("recovery_map")
	await c.tree.process_frame
	c.equal(GameState.objective_id, &"part2_restore", "the map sets the goal «Восстановить системы»")

	GameState.set_flag(&"part2/dir_upper_done")
	await c.tree.process_frame
	texts = _texts(program.enter("main"))
	c.is_true(texts.has("[+] Верх — восстановлен.") and texts.filter(func(t: String) -> bool: return t.begins_with("[ ]")).size() == 2, "a finished direction is marked")
	c.equal(GameState.objective_id, &"part2_restore", "one direction does not finish the goal")

	var saved := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.set_flag(&"part2/dir_storage_done")
	GameState.set_flag(&"part2/dir_lower_done")
	await c.tree.process_frame
	c.equal(GameState.objective_id, &"part2_monitor", "all three directions, in any order, finish the goal")
	c.is_true(_texts(program.enter("main")).has("Все направления восстановлены."), "the map reports all directions restored")
	GameState.from_dict(saved)
	await c.tree.process_frame
	c.equal(GameState.objective_id, &"part2_restore", "loading restores the part2 step")
	c.is_true(GameState.has_flag(&"part2/dir_upper_done") and not GameState.has_flag(&"part2/dir_lower_done"), "loading restores the direction flags")

	# A save made after the opening was finished, before part2 existed, still moves on.
	for flag: StringName in DIRECTIONS:
		GameState.set_flag(flag)
	GameState.set_flag(&"part2/finale")
	saved = JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	saved["systems"][String(Objectives.SYSTEM)] = {"chain": "opening", "index": (Objectives.chains[&"opening"]["steps"] as Array).size()}
	GameState.from_dict(saved)
	await c.tree.process_frame
	await c.tree.process_frame
	c.equal(Objectives.active_chain(), &"part2", "a finished opening in an old save hands over to part2")
	c.is_true(Objectives.is_completed(), "part2 ends with its finale")
	GameState.reset()
	await c.tree.process_frame


func _texts(view: Dictionary) -> Array:
	return (view["lines"] as Array).map(func(line: Dictionary) -> String: return line["text"])
