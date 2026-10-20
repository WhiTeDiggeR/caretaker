extends RefCounted

## #229: direction «Нижний контур» of part 2 on the sandbox station — the lower circuit
## substation (diagnose → prepare → energize → check) powers the trunk line of the lower floor
## and its short path; an old plate matches the plate «2» from the interdream and points to
## post 2; the lab holds the closed memory sync project, the post the 3+4 regulation (one flag
## with the new control point monitor); the lab and the post close the direction. Camera 2
## stays shut.

const STATION := "res://scenes/sandbox/stations/lower_station.tscn"
const DONE_FLAG := &"part2/dir_lower_done"
const RULE_FLAG := &"part2/rule_3_4"
const TRACE_FLAG := &"part2/dream_trace_2"
const COMPARED_FLAG := &"part2/plate_compared"
const RULE_LINE := "Одновременное снижение стабильности объектов 3 и 4 недопустимо."


func run(c: OpeningCheck) -> void:
	GameState.reset()
	var station := c.add((load(STATION) as PackedScene).instantiate()) as Node3D
	await c.physics_frames(2)
	var procedure := station.get_node(^"Substation/Procedure") as RepairProcedure
	c.is_true(procedure.errors.is_empty(), "the substation procedure loads with all its controls")
	c.equal(procedure.steps.map(func(step: Dictionary) -> String: return step["id"]), ["diagnose", "prepare", "energize", "check"], "the repair follows diagnose → prepare → energize → check")
	var short_path := station.get_node(^"ShortPath") as FacilityDoor
	var trunk := station.get_node(^"TrunkDoor") as FacilityDoor
	var chamber := station.get_node(^"Post2/ChamberDoor") as FacilityDoor
	c.is_true(not short_path.can_operate() and not trunk.can_operate(), "the trunk line and the short path are dead before the repair")
	GameState.set_objective(&"part2_restore", "Восстановить системы")

	# The plate before the interdream trace is just an old plate.
	var plate := station.get_node(^"TrunkPlate") as OldPlate
	var plate_use := plate.get_meta(Interactable.META) as Interactable
	c.equal(plate_use.inspect_text_id, OldPlate.PLAIN_TEXT_ID, "without the trace the plate is just old")
	plate_use.trigger()
	c.is_true(not GameState.has_flag(COMPARED_FLAG), "nothing to compare before the interdream")
	GameState.set_flag(TRACE_FLAG)
	c.equal(plate_use.inspect_text_id, OldPlate.COMPARED_TEXT_ID, "after the interdream the plate is recognised")
	var compared := str(DocumentLibrary.get_document(OldPlate.COMPARED_TEXT_ID).get("body", ""))
	c.is_true(compared.contains("из сна") and compared.contains("Камеру 2"), "the comparison points to camera 2 on the lower floor")
	plate_use.trigger()
	c.is_true(GameState.has_flag(COMPARED_FLAG), "comparing the plates is remembered")

	# Substation: journal first, ground off before the disconnector, the lever, then the check.
	_switch(&"lo_ground")
	await c.tree.process_frame
	await c.tree.process_frame
	c.is_true(not GameState.has_flag(RepairControl.flag_for(&"lo_ground")), "the line waits for the protection journal")
	GameState.set_flag(&"part2/lower_diagnosed")
	_switch(&"lo_disconnector")
	await c.tree.process_frame
	await c.tree.process_frame
	c.is_true(not GameState.has_flag(RepairControl.flag_for(&"lo_disconnector")), "the disconnector on a grounded line springs back")
	_switch(&"lo_test")
	await c.tree.process_frame
	await c.tree.process_frame
	c.is_true(not GameState.has_flag(RepairControl.flag_for(&"lo_test")), "nothing to check before the voltage")
	for control_id: StringName in [&"lo_ground", &"lo_disconnector", &"lo_lever"]:
		_switch(control_id)
	await c.tree.process_frame
	c.is_true(not procedure.is_done() and not trunk.can_operate(), "the line stays off until the check")
	_switch(&"lo_test")
	await c.tree.process_frame
	c.is_true(procedure.is_done() and GameState.get_section_power(&"lower_main") == GameState.Power.MAIN, "the substation powers the trunk line of the lower floor")
	c.is_true(short_path.can_operate() and trunk.can_operate(), "the trunk door and the short path open")
	c.equal(GameState.objective_id, &"part2_restore", "the substation keeps the part 2 objective")
	c.is_true(not chamber.can_operate(), "camera 2 stays shut")

	# The lab: the closed memory sync project.
	var sync_doc := station.get_node(^"EarlyLab/MemorySyncClosed") as DocumentPickup
	var sync_body := str(DocumentLibrary.get_document(sync_doc.document_id).get("body", ""))
	c.is_true(sync_body.contains("синхронизации памяти") and sync_body.contains("закрыть"), "the lab holds the closed memory sync project")
	(station.get_node(^"EarlyLab/ReachedArea") as EventTrigger).fire()
	await c.tree.process_frame
	await c.tree.process_frame
	c.is_true(GameState.has_flag(&"part2/lower_lab_reached"), "entering the lab is remembered")
	c.is_true(not GameState.has_flag(DONE_FLAG), "the direction is not closed before post 2")

	# Post 2: the regulation, the direction closes.
	var rule_doc := station.get_node(^"Post2/Rule34") as DocumentPickup
	c.is_true(str(DocumentLibrary.get_document(rule_doc.document_id).get("body", "")).contains(RULE_LINE), "the post holds the 3+4 regulation")
	(station.get_node(^"Post2/ReachedArea") as EventTrigger).fire()
	await c.tree.process_frame
	await c.tree.process_frame
	c.is_true(GameState.has_flag(DONE_FLAG), "the substation, the lab and the post close «Нижний контур»")
	c.is_true(not GameState.has_flag(&"part2/n2_first_text"), "the first text of №2 is left to the channel")
	DocumentLibrary.mark_read(rule_doc.document_id)
	c.is_true(GameState.has_flag(RULE_FLAG), "the regulation at the post sets the shared flag")
	c.is_true(not chamber.can_operate(), "camera 2 stays shut at the end")

	var saved := JSON.parse_string(JSON.stringify(GameState.to_dict())) as Dictionary
	GameState.reset()
	await c.tree.process_frame
	c.equal(plate_use.inspect_text_id, OldPlate.PLAIN_TEXT_ID, "a fresh state forgets the trace")
	GameState.from_dict(saved)
	await c.tree.process_frame
	c.is_true(procedure.is_done() and trunk.can_operate() and GameState.has_flag(DONE_FLAG), "a save keeps the line powered and the direction closed")
	c.equal(plate_use.inspect_text_id, OldPlate.COMPARED_TEXT_ID, "a save keeps the plate recognised")
	station.queue_free()
	GameState.reset()
	await c.tree.process_frame


func _switch(control_id: StringName) -> void:
	GameState.set_flag(RepairControl.flag_for(control_id))
