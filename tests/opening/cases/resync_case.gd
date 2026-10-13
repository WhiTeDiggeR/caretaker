extends RefCounted

## #132: knowledge from the dream's seal → journal → capsule resync panel.

const PANEL := "res://objects/containment/resync_panel.tscn"
const SEAL := "res://objects/dream/dream_seal.tscn"
const MODULE := &"module_4"
const KNOWLEDGE := &"module_4_seal"


func run(c: OpeningCheck) -> void:
	Containment.set_process(false)
	var glyphs := DreamKnowledge.glyphs()
	c.is_true(glyphs.size() >= 3, "glyph set is configured")
	c.equal(DreamKnowledge.definition(KNOWLEDGE).get("module"), "module_4", "seal knowledge belongs to module 4")

	var panel := (load(PANEL) as PackedScene).instantiate() as ResyncPanel
	c.add(panel)
	var first := panel.glyph_button(glyphs[0])
	c.is_true(first != null, "panel has a button per glyph")
	c.is_true(not first.is_available(), "without knowledge the panel is locked")
	c.equal(first.get_prompt_text(), ResyncPanel.LOCK_NO_KNOWLEDGE, "the lock says what is needed")
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
	for child in journal.list_box.get_children():
		texts.append((child as Label).text)
	c.is_true(DocumentReader.KNOWLEDGE_TITLE in texts, "journal has the dream knowledge section")
	c.is_true("\n".join(texts).contains(DreamKnowledge.code_text(KNOWLEDGE)), "journal shows the glyphs")
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
	for glyph in wrong:
		panel.glyph_button(glyph).trigger()
	c.equal(panel.last_result, DreamKnowledge.Result.WRONG, "reversed glyphs are a mistake")
	var screen := panel.get_node(^"Screen") as WorldScreen
	c.is_true(screen.view.rows.any(func(row: Dictionary) -> bool: return row.get("status") == &"alarm"), "the mistake is an alarm on the screen")
	c.near(Containment.get_instability(MODULE), 40.0 + DreamKnowledge.resync_param("failure_penalty", 0.0), 0.001, "a mistake raises the instability")
	c.equal(panel.entered.size(), 0, "input starts over after a mistake")
	c.equal(DreamKnowledge.active_for(MODULE), KNOWLEDGE, "a mistake does not spend the knowledge")

	# Reset clears a partial input.
	panel.glyph_button(code[0]).trigger()
	c.equal(panel.entered.size(), 1, "partial input is kept")
	(panel.get_node(^"ResetButton/Interactable") as Interactable).trigger()
	c.equal(panel.entered.size(), 0, "reset clears the input")

	# The right sequence brings the sleep to full stability and spends the knowledge.
	for glyph in code:
		panel.glyph_button(glyph).trigger()
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

	# An awake prisoner cannot be resynced.
	Containment.add_instability(MODULE, 100.0)
	c.equal(DreamKnowledge.resync(MODULE, DreamKnowledge.code(KNOWLEDGE)), DreamKnowledge.Result.AWAKE, "an awake prisoner is beyond resync")
	panel.refresh()
	c.equal(first.get_prompt_text(), ResyncPanel.LOCK_AWAKE, "the panel says the prisoner is awake")
	Containment.set_process(true)
