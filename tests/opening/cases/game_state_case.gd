extends RefCounted

const GameStateScript := preload("res://scenes/game_state.gd")


func run(c: OpeningCheck) -> void:
	c.is_true(c.tree.root.has_node(^"GameState"), "GameState autoload is registered")

	var state: Node = c.add(GameStateScript.new())
	var events: Array[String] = []
	state.objective_changed.connect(func(id: StringName, _text: String) -> void: events.append("objective:%s" % id))
	state.flag_changed.connect(func(flag: StringName, value: Variant) -> void: events.append("flag:%s=%s" % [flag, value]))
	state.section_power_changed.connect(func(section: StringName, power: int) -> void: events.append("power:%s=%d" % [section, power]))
	state.access_changed.connect(func(access: StringName, granted: bool) -> void: events.append("access:%s=%s" % [access, granted]))

	state.set_objective(&"reach_old_cp", "Добраться до резервного пункта управления")
	state.set_objective(&"reach_old_cp", "Добраться до резервного пункта управления")
	c.equal(events.count("objective:reach_old_cp"), 1, "repeated objective emits once")

	c.is_true(not state.has_flag(&"generator_started"), "unknown flag is false")
	state.set_flag(&"generator_started")
	state.set_flag(&"generator_started")
	c.is_true(state.has_flag(&"generator_started"), "flag is set")
	c.equal(events.count("flag:generator_started=true"), 1, "repeated flag emits once")
	state.set_flag(&"staff_pods_seen", 5)
	c.equal(state.get_flag(&"staff_pods_seen"), 5, "flag keeps a non-bool value")
	state.clear_flag(&"staff_pods_seen")
	c.equal(state.get_flag(&"staff_pods_seen", -1), -1, "cleared flag falls back to default")

	c.equal(state.get_section_power(&"old_core"), GameStateScript.Power.OFF, "unknown section is unpowered")
	state.set_section_power(&"emergency_block", GameStateScript.Power.EMERGENCY)
	state.set_section_power(&"emergency_block", GameStateScript.Power.EMERGENCY)
	c.is_true(state.is_section_powered(&"emergency_block"), "emergency power counts as powered")
	c.equal(events.count("power:emergency_block=1"), 1, "repeated power emits once")
	state.set_section_power(&"old_core", GameStateScript.Power.OFF)
	c.equal(events.count("power:old_core=0"), 1, "explicit OFF of a new section is announced")

	c.is_true(state.has_access(&""), "empty requirement is satisfied")
	c.is_true(not state.has_access(&"caretaker"), "access is not granted by default")
	state.grant_access(&"caretaker")
	state.grant_access(&"module_4")
	c.is_true(state.has_access(&"caretaker"), "access is granted")
	state.revoke_access(&"module_4")
	c.is_true(not state.has_access(&"module_4"), "access is revoked")

	var saved: Dictionary = state.to_dict()
	var restored: Node = c.add(GameStateScript.new())
	c.is_true(restored.from_dict(JSON.parse_string(JSON.stringify(saved))), "saved state loads")
	c.equal(restored.to_dict(), saved, "state round-trips through JSON")
	c.equal(restored.objective_id, &"reach_old_cp", "objective id restored")
	c.equal(restored.get_section_power(&"emergency_block"), GameStateScript.Power.EMERGENCY, "power restored")
	c.is_true(restored.has_access(&"caretaker"), "access restored")
	c.is_true(not restored.from_dict({"version": 999}), "unsupported version is rejected")
	c.is_true(restored.has_access(&"caretaker"), "rejected document keeps the state")

	var path := "user://opening_check_save.json"
	c.equal(state.save_to_file(path), OK, "state saves to a file")
	var from_file: Node = c.add(GameStateScript.new())
	c.equal(from_file.load_from_file(path), OK, "state loads from a file")
	c.equal(from_file.to_dict(), restored.to_dict(), "file round-trip keeps the state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	c.equal(from_file.load_from_file(path), ERR_FILE_NOT_FOUND, "missing save is reported")
