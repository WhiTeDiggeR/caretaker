extends Node

## Headless check of the second visit of Bowser's dream «Горн» (#234,
## docs/game_design/09-bowser-dream-v2.md): the visit follows the overheating flag; on the first
## visit nothing of the forge exists. On the second the yard is quiet, the burnt rubble lets the
## hero into the walkable branch «Кузница», the throne seal stands restored, the gate grate is
## open. The sluices keep their order (the feed before the bypass knocks the stone out, the
## quench before the feed blasts steam, a wrong level boils away), the right order records the
## scheme with the visit's level, cools the seal (hot until then) and freezes the moat; the first
## key stone wakes the guards (by the entry stage, a hammerer among them) and busy hands forbid
## the strike. The forge remembers itself across a reload; the coupled seal ends the visit, the
## gate sets the story flags and forgets the forge; the interdream answers the mark of the
## senior. The tuning panel of module 4's cooling takes the scheme in the same order (a water
## hammer otherwise, no instability) and tunes the cooling for good.
## Prints `BOWSER_FORGE_CHECK_OK checks=<n>` on success.

const BOWSER_DREAM := "res://scenes/dreams/bowser_dream.tscn"
const OVERHEAT := &"part2/module4_overheat"
const SAMPLE_STEP := 0.25
const CHEST := 1.0
const KNEE := 0.5
const HEAD_ROOM := 2.0
## Terrace → yard → burnt rubble → gallery round the channel → the Forge hall, on the floor.
const FORGE_ROUTE: Array[Vector3] = [
	Vector3(4, 0, 0), Vector3(25, 0, 0), Vector3(27, 1.2, 0), Vector3(46, 1.2, 0), Vector3(62, 1.2, 0),
	Vector3(62, 1.2, 12), Vector3(62, 1.2, 16), Vector3(82, 1.2, 16), Vector3(82, 1.2, 23),
	Vector3(68, 1.2, 23), Vector3(68, 1.2, 25.5), Vector3(68, 1.2, 29),
]

var _errors := PackedStringArray()
var _checks := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().current_scene = null
	Containment.set_process(false)
	GameState.reset()
	await _check_first_visit()
	GameState.reset()
	GameState.set_flag(OVERHEAT)
	GameState.set_flag(&"part2/recovery_map")
	var dream := await _load_dream()
	_check_second_core(dream)
	_check_route(dream)
	var forge := dream.forge
	_check_sluices(dream, forge)
	await _check_quench(forge)
	await _check_workshop(forge)
	dream.queue_free()
	await _frames(3)
	dream = await _load_dream()
	_check_memory(dream.forge)
	await _check_seal_and_gate(dream)
	_check_interdream()
	await _check_tuning_panel()
	_finish()


func _load_dream() -> BowserDream:
	var dream := (load(BOWSER_DREAM) as PackedScene).instantiate() as BowserDream
	add_child(dream)
	await _frames(5)
	return dream


func _check_first_visit() -> void:
	var dream := await _load_dream()
	_check(BowserDream.story_visit() == BowserDream.VISIT_FIRST and dream.forge == null and dream.get_node_or_null(^"Forge") == null,
			"without the overheating it is the first visit, no forge")
	var seal := dream.get_node(BowserDream.SEAL) as DreamSealRings
	_check(not seal.is_held(), "the throne seal is the puzzle of the first visit")
	_check(not (dream.get_node(BowserDream.WAKE_LINE).get_parent() as DreamAmbush).disarmed, "the yard ambush waits on the first visit")
	var stone := dream.get_node(^"Branches/RubbleSouth/StoneA/Collision") as CollisionShape3D
	_check(not stone.disabled, "the south rubble blocks the yard on the first visit")
	dream.queue_free()
	await _frames(2)


func _check_second_core(dream: BowserDream) -> void:
	_check(dream.visit == BowserDream.VISIT_SECOND and DreamKnowledge.visit_version == &"v2", "the overheating flag picks the second visit")
	_check(dream.forge != null and dream.forge.get_parent() == dream, "the second visit adds the branch «Кузница»")
	_check((dream.get_node(BowserDream.WAKE_LINE).get_parent() as DreamAmbush).disarmed, "the yard stays quiet: the dream remembers the fight")
	_check(dream.side_door_open, "the grate to the bastion is open from the start")
	var seal := dream.get_node(BowserDream.SEAL) as DreamSealRings
	_check(seal.is_held() and seal.is_restored() and not seal.levers[0].available, "the throne seal stands restored and still")
	_check(not (dream.get_node(^"Branches/RubbleSouth/Art") as Node3D).visible, "the rubble burnt out")
	var mood := dream.get_node(^"Mood") as DreamStageMood
	_check(mood.event_stage == DreamStageMood.Stage.UNREST, "hesitating over №2 makes the entry unrest")
	_check(dream.forge.ambush.stage == BowserDream.STAGE_UNREST, "the forge guards follow the entry stage")
	var count := 0
	var hammer := 0
	for entry in dream.forge.ambush.roster():
		count += int(entry.get("count", 0))
		if str(entry.get("enemy", "")) == "hammer":
			hammer += int(entry.get("count", 0))
	_check(count == 4 and hammer == 1, "unrest: three shades and a hammerer (%d, %d)" % [count, hammer])
	dream.forge.ambush.stage = BowserDream.STAGE_ALARM
	count = 0
	for entry in dream.forge.ambush.roster():
		count += int(entry.get("count", 0))
	_check(count == 3, "alarm: two shades and a hammerer")
	dream.forge.ambush.stage = BowserDream.STAGE_UNREST
	var hammerer := DreamCombatData.enemy(&"hammer")
	_check(int(hammerer.get("health", 0)) == 120 and float(hammerer.get("push", 0.0)) == 2.0 and float(hammerer.get("windup", 0.0)) >= 0.9,
			"the hammerer: 120, a slow wind-up, a 2 m push")


func _check_route(dream: BowserDream) -> void:
	var space := dream.get_world_3d().direct_space_state
	var exclude: Array[RID] = [(dream.get_node(^"Player") as CollisionObject3D).get_rid()]
	for stone in dream.forge.stones():
		exclude.append(stone.get_rid())
	var previous := Vector3.INF
	var blocked := PackedStringArray()
	for i in FORGE_ROUTE.size() - 1:
		var a := FORGE_ROUTE[i]
		var b := FORGE_ROUTE[i + 1]
		var count := maxi(1, ceili(a.distance_to(b) / SAMPLE_STEP))
		for k in count + 1:
			var p := a.lerp(b, float(k) / count)
			var hit := _ray(space, p + Vector3.UP * 3.0, p + Vector3.DOWN * 8.0, exclude)
			if hit.is_empty() or absf((hit["position"] as Vector3).y - p.y) > 0.6:
				_check(false, "floor of the forge route at %s" % p)
				return
			var floor_point: Vector3 = hit["position"]
			if not _ray(space, floor_point + Vector3.UP * 0.05, floor_point + Vector3.UP * HEAD_ROOM, exclude).is_empty():
				_check(false, "head room on the forge route at %s" % floor_point)
				return
			if previous != Vector3.INF:
				var top := maxf(previous.y, floor_point.y)
				for height: float in [KNEE, CHEST]:
					var hit_wall := _ray(space, Vector3(previous.x, top + height, previous.z), Vector3(floor_point.x, top + height, floor_point.z), exclude)
					if not hit_wall.is_empty():
						blocked.append("%s (%s)" % [floor_point, (hit_wall["collider"] as Node).get_path()])
			previous = floor_point
	_check(blocked.is_empty(), "nothing blocks the forge route: %s" % [blocked.slice(0, 3)])


func _check_sluices(dream: BowserDream, forge: BowserForge) -> void:
	_check(forge.level >= 1 and forge.level <= BowserForge.LEVELS, "the quench level is 1…3 (%d)" % forge.level)
	var water := forge.get_node(^"Tank/Water") as MeshInstance3D
	_check(is_equal_approx(water.position.y + (water.mesh as BoxMesh).size.y * 0.5, BowserForge.WATER_TOPS[forge.level]),
			"the tank's water stands at the visit's level")
	_check(forge.seal.coupled and forge.seal.turned_rings(0) == ([0, 1] as Array[int]), "the outer lever of the Forge seal drags the middle ring")
	_check(forge.seal.is_locked() and not forge.seal.levers[1].available and not forge.seal.turn(1), "the hot seal does not turn before the quench")
	var player := dream.get_node(^"Player")
	var combat := _combat()
	var k1 := forge.stone(&"k1")
	var k2 := forge.stone(&"k2")
	_check(k2.take() and DreamKeyStone.held_stone == k2, "a key stone goes into the hands")
	_check(combat != null and combat.hands_busy and not combat.attack(&"dream_chain") and not combat.dash(), "busy hands: no strike, no dash")
	_check(is_equal_approx(float(player.get("speed_scale")), DreamKeyStone.CARRY_SPEED_SCALE), "the hero walks slower with the stone")
	_check(not k1.take(), "one stone at a time")
	_check(forge.ambush.started and forge.ambush.guards.size() == 4, "the first stone wakes the guards (%d)" % forge.ambush.guards.size())
	var hammerers := 0
	for guard in forge.ambush.guards:
		if guard.enemy_type == &"hammer":
			hammerers += 1
	_check(hammerers == 1, "a hammerer is among the guards")
	_check(forge.socket_feed.insert() and not forge.feed_closed, "the feed before the bypass: the lava has nowhere to go")
	_check(not combat.hands_busy and float(player.get("speed_scale")) == 1.0, "the hands are free again")


func _check_quench(forge: BowserForge) -> void:
	var combat := _combat()
	await get_tree().create_timer(DreamStoneSocket.EJECT_SECONDS + 0.2).timeout
	var k1 := forge.stone(&"k1")
	var k2 := forge.stone(&"k2")
	_check(k2.state == DreamKeyStone.State.GROUND and not forge.socket_feed.is_filled(), "the knocked-out stone rolled back home")
	k1.take()
	_check(forge.socket_bypass.insert() and forge.bypass_open, "a stone in the bypass socket opens the bypass")
	forge.turn_wheel()
	var resolve := combat.resolve
	forge.open_quench()
	_check(forge.dial == 0 and not forge.is_tempered and combat.resolve <= resolve - BowserForge.STEAM_RESOLVE + 0.01,
			"the quench before the feed: steam, the wheel resets, resolve lost")
	k2.take()
	_check(forge.socket_feed.insert() and forge.feed_closed, "after the bypass the feed gate falls")
	forge.turn_wheel()
	while forge.dial == forge.level:
		forge.turn_wheel()
	forge.open_quench()
	_check(not forge.is_tempered and forge.dial == 0, "a wrong level only boils away")
	_check(not GameState.has_flag(&"part2/cooling_scheme"), "no scheme before the right order")
	while forge.dial != forge.level:
		forge.turn_wheel()
	forge.open_quench()
	_check(forge.is_tempered, "the right order at the right level cools the Forge")
	_check(GameState.has_flag(&"part2/cooling_scheme") and DreamKnowledge.scheme_level(BowserForge.SCHEME) == forge.level,
			"the scheme is remembered with the level")
	_check(DreamKnowledge.active_scheme_for(&"module_4") == BowserForge.SCHEME and DreamKnowledge.active_for(&"module_4").is_empty(),
			"the scheme waits for the complex and is no resync code")
	var entries := DreamKnowledge.journal_entries()
	_check(not entries.is_empty() and entries[0].get("sketch") == DreamKnowledge.SKETCH_SCHEME and int(entries[0].get("level", 0)) == forge.level,
			"the journal sketches the scheme")
	_check(str(entries[0].get("text", "")).contains(DreamKnowledge.level_mark(forge.level)), "the journal names the gauge mark")
	_check(not forge.seal.is_locked() and forge.seal.levers[1].available, "the cooled seal turns")
	await _frames(2)
	var crust := forge.get_node(^"Workshop/Moat/Crust/Collision") as CollisionShape3D
	var heat := forge.get_node(^"Workshop/Moat/HeatWall/Collision") as CollisionShape3D
	_check(not crust.disabled and heat.disabled, "the moat freezes over")


func _check_workshop(forge: BowserForge) -> void:
	var mark := forge.get_node(^"Workshop/Mark")
	var interactable: Interactable = null
	for child in mark.get_children():
		if child is Interactable:
			interactable = child
	_check(interactable != null and interactable.mode == Interactable.Mode.INSPECT, "the mark can be read")
	_check(interactable.get_inspect_text().contains("SE 067"), "the mark carries the senior's number")
	interactable.trigger()
	await _frames(1)
	_check(GameState.has_flag(&"part2/senior_mark") and DocumentLibrary.is_read("bowser_senior_mark"), "reading the mark sets its flag and journal entry")
	var space := forge.get_world_3d().direct_space_state
	var across := _ray(space, Vector3(83, 1.2 + CHEST, 19), Vector3(90, 1.2 + CHEST, 19), [])
	_check(across.is_empty(), "the frozen moat lets the hero into the workshop")
	_check(forge.ambush.in_threshold(Vector3(85.5, 1.5, 19)) and forge.ambush.in_threshold(Vector3(68, 1.5, 25.2)),
			"the guards keep out of the workshop and the Forge hall")


func _check_memory(forge: BowserForge) -> void:
	_check(forge.bypass_open and forge.feed_closed and forge.is_tempered, "the dream remembers the sluices after a reload")
	_check(forge.socket_bypass.is_filled() and forge.socket_feed.is_filled(), "the stones stay in their sockets")
	_check(not forge.seal.is_locked(), "the Forge stays cool")


func _check_seal_and_gate(dream: BowserDream) -> void:
	var original_loader := Dreams.scene_loader
	Dreams.scene_loader = func(_path: String) -> void: pass
	await Dreams.enter(&"module_4", &"check_chair")
	var seal := dream.forge.seal
	var turns := 0
	for ring in seal.ring_count:
		while not seal.is_ring_aligned(ring) and turns < 60:
			seal.turn(ring)
			turns += 1
	_check(Dreams.seal_restored and seal.is_solved(), "the coupled seal of the Forge can be solved (%d turns)" % turns)
	_check(GameState.has_flag(BowserDream.V2_SEAL_FLAG), "the restored Forge seal is a story flag")
	_check(DreamKnowledge.active_for(&"module_4") == &"module_4_seal", "the Forge seal grants the glyphs for the resync")
	await _frames(2)
	var crust := dream.forge.get_node(^"Channel/Crust/Collision") as CollisionShape3D
	_check(not crust.disabled, "the channel of the gallery crusts over after the seal")
	Dreams.exit_through_gate()
	await _frames(2)
	_check(GameState.has_flag(BowserDream.V2_DONE_FLAG), "the gate after the Forge seal closes the second visit")
	_check(GameState.get_system_data(BowserForge.SYSTEM).is_empty(), "the gate ends the forge's memory of the visit")
	await get_tree().create_timer(6.0).timeout
	Dreams.scene_loader = original_loader
	Dreams.abort()


func _check_interdream() -> void:
	_check(GameState.has_flag(InterdreamEchoes.shown_flag("senior_key")), "the gate after the mark showed the senior's key in the interdream")
	var echo := InterdreamEchoes.pick(&"module_4", Dreams.Exit.GATE)
	_check(str(echo.get("id", "")) == "plate_2_turned", "hesitating shows the plate turned to the wall (%s)" % echo.get("id", ""))
	GameState.set_flag(&"part2/n2_believed")
	GameState.set_flag(InterdreamEchoes.shown_flag("plate_2_turned"))
	echo = InterdreamEchoes.pick(&"module_4", Dreams.Exit.GATE)
	_check(str(echo.get("id", "")) == "plate_2_healed", "believing shows the healed plate (%s)" % echo.get("id", ""))


func _check_tuning_panel() -> void:
	var level := DreamKnowledge.scheme_level(BowserForge.SCHEME)
	_check(level >= 1 and DreamKnowledge.active_scheme_for(&"module_4") == BowserForge.SCHEME, "the scheme waits for the panel")
	var panel := (load("res://objects/containment/cooling_tuning_panel.tscn") as PackedScene).instantiate() as CoolingTuningPanel
	add_child(panel)
	await _frames(1)
	_check(not panel.is_open(), "the panel is shut during the crisis")
	GameState.set_flag(&"part2/module4_crisis_resolved")
	_check(Cooling.can_tune(&"module_4") and panel.is_open(), "after the crisis the panel takes the scheme")
	var instability := Containment.get_instability(&"module_4")
	panel.toggle_feed()
	_check(panel.shock_left() > 0.0 and not panel.feed_closed and not panel.is_open(), "the feed before the bypass is a water hammer")
	panel.toggle_bypass()
	_check(not panel.bypass_open, "the valves do not move while the circuit settles")
	panel._process(CoolingTuningPanel.SHOCK_SECONDS + 1.0)
	_check(panel.is_open(), "the panel opens again after the wait")
	panel.toggle_bypass()
	panel.toggle_feed()
	_check(panel.bypass_open and panel.feed_closed, "bypass open, then the hot feed closed")
	panel.next_level()
	while panel.level == level:
		panel.next_level()
	panel.open_cooling()
	_check(panel.shock_left() > 0.0 and not panel.bypass_open and panel.level == 0, "a wrong level is a water hammer too, the valves go back")
	_check(is_equal_approx(Containment.get_instability(&"module_4"), instability), "a water hammer does not raise the instability")
	panel._process(CoolingTuningPanel.SHOCK_SECONDS + 1.0)
	panel.toggle_bypass()
	panel.toggle_feed()
	while panel.level != level:
		panel.next_level()
	panel.open_cooling()
	_check(Cooling.is_tuned(&"module_4") and GameState.has_flag(&"part2/module4_cooling_tuned"), "the scheme tunes the cooling of module 4")
	_check(DreamKnowledge.is_used(BowserForge.SCHEME) and DreamKnowledge.active_scheme_for(&"module_4").is_empty(), "the scheme is spent")
	_check(" ".join(Cooling.status_lines()).contains("настроено"), "the post shows the tuned cooling")
	_check(not panel.is_open(), "a tuned cooling needs no more tuning")
	panel.queue_free()


func _combat() -> DreamCombat:
	return get_tree().get_first_node_in_group(DreamCombat.GROUP) as DreamCombat


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclude
	return space.intersect_ray(query)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(message)


func _finish() -> void:
	for error in _errors:
		printerr("FAIL ", error)
	if _errors.is_empty():
		print("BOWSER_FORGE_CHECK_OK checks=%d" % _checks)
	get_tree().quit(0 if _errors.is_empty() else 1)
