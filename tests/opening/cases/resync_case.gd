extends RefCounted

## #132: knowledge from the dream's seal → journal → capsule resync panel.

const PANEL := "res://objects/containment/resync_panel.tscn"
const SEAL := "res://objects/dream/dream_seal.tscn"
const MODULE := &"module_4"
const KNOWLEDGE := &"module_4_seal"


func run(c: OpeningCheck) -> void:
	Containment.set_process(false)
	var glyphs := DreamKnowledge.glyphs()
	c.equal(glyphs, PackedStringArray(["f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8"]), "eight glyphs by id (#194)")
	for id in glyphs:
		c.equal(DreamKnowledge.label(id), "Ф-%s" % id.substr(1), "glyph %s has its phase code" % id)
		c.is_true(not DreamGlyph.polylines(id).is_empty(), "glyph %s has strokes" % id)
		c.is_true(not str(DreamKnowledge.image(&"bowser", id).get("title", "")).is_empty(), "the Bowser dream sees glyph %s as an image" % id)
	var data := FileAccess.get_file_as_string(DreamKnowledge.DATA_PATH)
	for word in ["КОРОНА", "ЦЕПЬ", "ПЛАМЯ", "КЛЮЧ", "ГЛАЗ", "БАШНЯ"]:
		c.is_true(not data.contains(word), "the old word glyph %s is gone" % word)
	var view := DreamGlyphView.new()
	view.size = Vector2(24, 24)
	c.is_true(view.stroke_width() >= DreamGlyph.MIN_UI_WIDTH, "a 24 px glyph keeps a 2 px stroke")
	view.free()
	DreamKnowledge.visit_version = &"v3"
	c.equal(DreamKnowledge.code_length(KNOWLEDGE), 4, "a V3 visit asks for four glyphs")
	DreamKnowledge.visit_version = &""
	c.equal(DreamKnowledge.code_length(KNOWLEDGE), 3, "by default the code has three glyphs")
	# A save from the word glyphs drops its knowledge without an error.
	GameState.set_system_data(DreamKnowledge.SYSTEM, {"entries": {"module_4_seal": {"code": ["КОРОНА", "ЦЕПЬ", "ПЛАМЯ"], "used": false}}, "order": ["module_4_seal"], "pending": {"module_4_seal": ["КЛЮЧ", "ГЛАЗ", "БАШНЯ"]}})
	c.is_true(not DreamKnowledge.has(KNOWLEDGE) and DreamKnowledge.active_for(MODULE).is_empty(), "old word knowledge is dropped")
	c.is_true(DreamKnowledge.prepare(KNOWLEDGE)[0] in glyphs, "a fresh code replaces the old pending one")
	GameState.reset()
	c.equal(DreamKnowledge.definition(KNOWLEDGE).get("module"), "module_4", "seal knowledge belongs to module 4")

	var panel := (load(PANEL) as PackedScene).instantiate() as ResyncPanel
	c.add(panel)
	var first := panel.glyph_button(glyphs[0])
	c.is_true(first != null, "panel has a button per glyph")
	c.is_true(not first.is_available(), "without knowledge the panel is locked")
	c.equal(first.get_prompt_text(), ResyncPanel.LOCK_NO_KNOWLEDGE, "the lock says what is needed")
	c.equal(first.prompt, "ВВЕСТИ ЗНАК · Ф-1", "the key names the phase code")
	c.is_true(panel.screen_text().contains("Нужны знаки"), "the screen explains how to get the glyphs")

	# A seal restored inside the dream grants the knowledge once.
	var seal := (load(SEAL) as PackedScene).instantiate() as DreamSeal
	seal.knowledge_id = KNOWLEDGE
	c.add(seal)
	Dreams.in_dream = true
	Dreams.module_id = MODULE
	Dreams.seal_restored = false
	(seal.get_node(^"Interactable") as Interactable).trigger()
	Dreams.in_dream = false
	var code := DreamKnowledge.code(KNOWLEDGE)
	c.equal(code.size(), 3, "the seal leaves three glyphs to remember")
	var distinct := {}
	for glyph in code:
		distinct[glyph] = true
		c.is_true(glyph in glyphs, "remembered glyph %s comes from the set" % glyph)
	c.equal(distinct.size(), 3, "glyphs do not repeat")
	c.equal(DreamKnowledge.active_for(MODULE), KNOWLEDGE, "the knowledge is active for module 4")

	# Journal section.
	var journal := DocumentReader.open_journal_scene(c.tree)
	var texts := PackedStringArray()
	var sketches: Array[DreamSketch] = []
	for child in journal.list_box.get_children():
		if child is DreamSketch:
			sketches.append(child)
		else:
			texts.append((child as Label).text)
	c.is_true(DocumentReader.KNOWLEDGE_TITLE in texts, "journal has the dream knowledge section")
	c.is_true(not "\n".join(texts).contains(DreamKnowledge.label(code[0])), "the journal does not name the phase codes")
	c.equal(sketches.size(), 1, "the knowledge entry has a sketch")
	c.equal(sketches[0].sketch, DreamKnowledge.SKETCH_SEAL, "after the first visit the journal sketches the whole seal")
	c.equal(sketches[0].code, code, "the seal sketch holds the visit's code")
	c.equal(sketches[0].dream, &"bowser", "the sketch draws the dream's images")
	c.equal(journal.document_lines().size(), 1, "knowledge lines are not selectable documents")
	journal.close()

	# Saved with the game.
	var saved := GameState.to_dict()
	GameState.reset()
	c.is_true(DreamKnowledge.active_for(MODULE).is_empty(), "reset forgets the knowledge")
	GameState.from_dict(saved)
	c.equal(DreamKnowledge.code(KNOWLEDGE), code, "knowledge survives a save")
	panel.refresh()
	c.is_true(first.is_available(), "with knowledge the panel takes input")

	# A wrong sequence disturbs the sleep and the input starts over.
	Containment.stabilize(MODULE, 100.0)
	Containment.add_instability(MODULE, 40.0)
	var wrong := code.duplicate()
	wrong.reverse()
	var enter := panel.get_node(^"EnterButton/Interactable") as Interactable
	for index in wrong.size():
		c.is_true(not enter.is_available(), "ВВОД waits for a complete code (%d)" % index)
		c.equal(enter.get_prompt_text(), ResyncPanel.NEED_GLYPHS % code.size(), "ВВОД says how many glyphs it needs")
		panel.glyph_button(wrong[index]).trigger()
	c.is_true(enter.is_available(), "a complete code unlocks ВВОД")
	panel.glyph_button(code[0]).trigger()
	c.equal(panel.entered.size(), code.size(), "extra keys beyond the code length are ignored")
	c.near(Containment.get_instability(MODULE), 40.0, 0.001, "typing is free until ВВОД")
	enter.trigger()
	c.equal(panel.last_result, DreamKnowledge.Result.WRONG, "reversed glyphs are a mistake")
	var screen := panel.get_node(^"Screen") as WorldScreen
	c.is_true(screen.view.rows.any(func(row: Dictionary) -> bool: return row.get("status") == &"alarm"), "the mistake is an alarm on the screen")
	c.near(Containment.get_instability(MODULE), 40.0 + DreamKnowledge.resync_param("failure_penalty", 0.0), 0.001, "a mistake raises the instability")
	c.equal(panel.entered.size(), 0, "input starts over after a mistake")
	c.equal(panel.held, wrong, "the wrong slots stay on the screen")
	c.is_true(panel.screen_text().contains(DreamKnowledge.label(wrong[0])), "the screen shows the held slots")
	c.is_true(screen.view.rows.any(func(row: Dictionary) -> bool: return Array(row.get("glyphs", [])) == Array(wrong)), "the held slots are drawn as glyphs")
	c.equal(DreamKnowledge.active_for(MODULE), KNOWLEDGE, "a mistake does not spend the knowledge")

	# Reset clears a partial input.
	panel.glyph_button(code[0]).trigger()
	c.equal(panel.entered.size(), 1, "partial input is kept")
	c.is_true(panel.held.is_empty(), "a new key ends the hold")
	var before := Containment.get_instability(MODULE)
	(panel.get_node(^"ResetButton/Interactable") as Interactable).trigger()
	c.equal(panel.entered.size(), 0, "reset clears the input")
	c.near(Containment.get_instability(MODULE), before, 0.001, "reset before ВВОД is free")

	# The right sequence brings the sleep to full stability and spends the knowledge.
	for glyph in code:
		panel.glyph_button(glyph).trigger()
	enter.trigger()
	c.equal(panel.last_result, DreamKnowledge.Result.SYNCED, "remembered glyphs resync the capsule")
	c.is_true(Containment.is_stable(MODULE) and Containment.forecast_seconds(MODULE) < 0.0, "resync removes the awakening forecast")
	c.is_true(DreamKnowledge.is_used(KNOWLEDGE) and DreamKnowledge.active_for(MODULE).is_empty(), "the knowledge is spent")
	c.is_true(not first.is_available(), "spent knowledge locks the panel again")
	c.is_true(panel.screen_text().contains("СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА"), "the screen confirms the resync")
	c.equal(DreamKnowledge.journal_entries()[0]["used"], true, "the journal marks the knowledge as used")

	# A new visit gives a new knowledge entry.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	DreamKnowledge.grant(KNOWLEDGE, rng)
	c.is_true(not DreamKnowledge.is_used(KNOWLEDGE), "a new visit grants fresh knowledge")
	c.equal(DreamKnowledge.journal_entries().size(), 1, "the journal keeps one entry per knowledge")
	c.equal(DreamKnowledge.journal_entries()[0]["sketch"], DreamKnowledge.SKETCH_IMAGES, "later visits sketch the images one by one")

	# An awake prisoner cannot be resynced.
	Containment.add_instability(MODULE, 100.0)
	c.equal(DreamKnowledge.resync(MODULE, DreamKnowledge.code(KNOWLEDGE)), DreamKnowledge.Result.AWAKE, "an awake prisoner is beyond resync")
	panel.refresh()
	c.equal(first.get_prompt_text(), ResyncPanel.LOCK_AWAKE, "the panel says the prisoner is awake")
	Containment.set_process(true)
