extends RefCounted

## #183: the seal of three rings (B-7, B-10) — positions from the DreamKnowledge code, a wrong
## turn without effect, the aligned rings restore the seal with the same glyphs, the dream
## remembers the rings.

const SEAL := "res://objects/dream/dream_seal_rings.tscn"
const SEAL_ART := "res://loads/props/dream_seal/dream_seal.gltf"
const WHEEL_ART := "res://loads/props/dream_seal_wheel/dream_seal_wheel.gltf"
const TEST_DREAM := "res://scenes/dreams/test_dream.tscn"
const MODULE := &"module_4"
const KNOWLEDGE := &"module_4_seal"


func run(c: OpeningCheck) -> void:
	GameState.reset()
	DreamKnowledge.reload()
	Dreams.in_dream = true
	Dreams.module_id = MODULE
	Dreams.seal_restored = false
	var seal := _seal(c)
	await c.tree.process_frame
	var code := seal.code()
	c.equal(code, DreamKnowledge.prepare(KNOWLEDGE), "the rings take the visit's code from DreamKnowledge")
	c.is_true(code.size() == DreamSealRings.RING_COUNT and seal.ring_count == 3 and not DreamKnowledge.has(KNOWLEDGE), "three glyphs, not yet remembered")
	for ring in seal.ring_count:
		c.equal(seal.ring_glyphs(ring).size(), DreamSealRings.POSITIONS, "ring %d has six positions" % ring)
		c.equal(seal.ring_glyphs(ring)[seal.correct_position(ring)], code[ring], "ring %d is right with its code glyph under the mark" % ring)
		c.is_true(not seal.is_ring_aligned(ring), "ring %d starts off its place" % ring)
	c.equal(seal.levers.size(), seal.ring_count, "a lever per ring")

	# #194: the glyph inside its image stays muted until its ring comes into place.
	for ring in seal.ring_count:
		for sector in DreamSealRings.POSITIONS:
			c.is_true(not seal.is_glyph_revealed(ring, sector), "ring %d glyph %d is muted while the ring is off" % [ring, sector])
	var muted := seal._glyph_images[0][seal.correct_position(0)] as DreamGlyphImage
	var muted_contrast := muted.crack_contrast()
	c.is_true(muted_contrast < 0.3, "a muted glyph barely stands out of its image")
	while not seal.is_ring_aligned(0):
		seal.turn(0)
	c.is_true(seal.is_glyph_revealed(0, seal.correct_position(0)), "the code glyph shows once its ring is in place")
	c.is_true(muted.crack_contrast() > muted_contrast + 1.0, "a shown glyph stands out of its image")
	for sector in DreamSealRings.POSITIONS:
		if sector != seal.correct_position(0):
			c.is_true(not seal.is_glyph_revealed(0, sector), "other glyphs of the ring stay muted")
	c.is_true(not seal.is_glyph_revealed(1, seal.correct_position(1)) or seal.is_ring_aligned(1), "a ring off its place keeps its glyph muted")
	seal.turn(0)
	c.is_true(not seal.is_glyph_revealed(0, seal.correct_position(0)), "turning the ring away mutes the glyph again")

	# A wrong turn costs nothing (B-10).
	var calm := Containment.get_instability(MODULE)
	# From the right position the next turn is surely wrong.
	if posmod(seal.positions[0] + 1, DreamSealRings.POSITIONS) == seal.correct_position(0):
		seal.turn(0)
	var ring_0 := seal.positions[0]
	seal.levers[0].trigger()
	c.equal(seal.positions[0], posmod(ring_0 + 1, DreamSealRings.POSITIONS), "a lever turns its ring by 1/6")
	c.is_true(not seal.is_ring_aligned(0) and not Dreams.seal_restored and not DreamKnowledge.has(KNOWLEDGE), "a wrong position restores nothing")
	c.near(Containment.get_instability(MODULE), calm, 0.001, "a wrong turn has no penalty")
	c.is_true(seal.levers[0].is_available(), "the lever stays usable after a mistake")

	# The dream remembers the rings: another instance and a loaded save show the same positions.
	var remembered := seal.positions.duplicate()
	var twin := _seal(c)
	c.equal(twin.positions, remembered, "the seal keeps its ring positions")
	c.equal(twin.code(), code, "the seal keeps its code within the visit")
	twin.queue_free()
	var saved: Variant = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	seal.turn(2)
	c.is_true(GameState.from_dict(saved), "the saved state loads")
	c.equal(seal.positions, remembered, "loading a save restores the ring positions")

	# Aligning the rings: the crack closes and the seal chain runs.
	for ring in seal.ring_count:
		while not seal.is_ring_aligned(ring):
			c.is_true(not Dreams.seal_restored, "the seal holds while a ring is off")
			seal.levers[ring].trigger()
	c.is_true(seal.is_solved() and Dreams.seal_restored, "the aligned rings restore the seal")
	c.equal(seal.glyphs_under_mark(), code, "the glyphs under the mark are the code")
	c.equal(DreamKnowledge.code(KNOWLEDGE), code, "the remembered glyphs match the rings")
	c.is_true(not seal.levers[0].is_available() and not seal.turn(0), "a restored seal does not turn")
	c.is_true(seal._light.visible and seal._material.emission == DreamSealRings.WHITE, "the restored seal glows white")

	# A new visit: a new code, the rings scrambled again.
	Dreams.seal_restored = false
	var next := _seal(c)
	c.is_true(not next.is_solved() and not Dreams.seal_restored, "a new visit starts with the rings off")
	c.equal(next.code(), DreamKnowledge.prepare(KNOWLEDGE), "a new visit takes a fresh code")
	next.queue_free()
	seal.queue_free()

	# #197: from V3 the code has four glyphs and the seal four rings; the art keeps its three
	# inside and the added ring lies outside, so the code still reads outer → inner.
	await c.tree.process_frame
	for with_art in [false, true]:
		DreamKnowledge.visit_version = &"v3"
		GameState.reset()
		Dreams.seal_restored = false
		var four := _seal(c, with_art)
		var long_code := four.code()
		c.equal(long_code.size(), 4, "a V3 visit has a four-glyph code (art %s)" % with_art)
		c.equal(four.ring_count, 4, "four rings for four glyphs (art %s)" % with_art)
		c.equal(four.levers.size(), 4, "a lever per ring (art %s)" % with_art)
		c.equal(long_code, DreamKnowledge.prepare(KNOWLEDGE), "the rings take the V3 code")
		for ring in four.ring_count:
			c.equal(four.ring_glyphs(ring)[four.correct_position(ring)], long_code[ring], "ring %d of four is right with its code glyph" % ring)
			while not four.is_ring_aligned(ring):
				c.is_true(not Dreams.seal_restored, "four rings: the seal holds while a ring is off")
				four.levers[ring].trigger()
		c.is_true(Dreams.seal_restored and four.glyphs_under_mark() == long_code, "four aligned rings restore the seal with the code")
		c.equal(DreamKnowledge.code(KNOWLEDGE), long_code, "four glyphs are remembered")
		var lever_z := (four.levers[0].get_parent() as Node3D).position.z
		c.is_true(lever_z > four._outer_radius(), "the levers stand outside the widest ring")
		four.queue_free()
		await c.tree.process_frame
	DreamKnowledge.visit_version = &""

	# #197 З-Р5: after the gate the assembled seal lingers about two seconds and is announced
	# with its code for the journal; the glyph stays as faint as in the dream.
	GameState.reset()
	Dreams.seal_restored = false
	var last := _seal(c)
	for ring in last.ring_count:
		while not last.is_ring_aligned(ring):
			last.turn(ring)
	var seal_code := last.code()
	last.queue_free()
	var shown: Array = []
	var on_shown := func(module: StringName, knowledge: StringName, shown_code: PackedStringArray) -> void:
		shown.append([module, knowledge, shown_code])
	Dreams.afterimage_shown.connect(on_shown)
	var afterimage := Dreams._afterimage
	Dreams.exit_through_gate()
	c.is_true(not afterimage.is_showing(), "no afterimage before the veil is down")
	await Dreams.arrived
	c.equal(shown.size(), 1, "the afterimage is announced once after the gate")
	c.equal(shown[0], [MODULE, KNOWLEDGE, seal_code], "the signal carries the module, the knowledge and the code")
	c.is_true(afterimage.is_showing() and afterimage.code == seal_code and afterimage.dream == &"bowser", "the assembled seal shows over the frame")
	var image_tint := afterimage.image_tint(seal_code[0])
	c.is_true(absf(afterimage.glyph_color(seal_code[0]).get_luminance() - image_tint.get_luminance()) < 0.3, "the glyph is not singled out of its image")
	await c.tree.create_timer(DreamAfterimage.SECONDS * 0.5).timeout
	c.is_true(afterimage.is_showing(), "the afterimage holds for a moment")
	await c.tree.create_timer(DreamAfterimage.SECONDS * 0.5 + 0.2).timeout
	c.is_true(not afterimage.is_showing(), "the afterimage melts in about two seconds")
	Dreams.afterimage_shown.disconnect(on_shown)

	# A gate without a restored seal and a death leave no afterimage.
	for exit in [Dreams.Exit.GATE, Dreams.Exit.DEATH]:
		Dreams.in_dream = true
		Dreams.module_id = MODULE
		Dreams.seal_restored = exit == Dreams.Exit.DEATH
		Dreams.afterimage_shown.connect(on_shown)
		if exit == Dreams.Exit.DEATH:
			Dreams.die()
		else:
			Dreams.exit_through_gate()
		await Dreams.arrived
		c.equal(shown.size(), 1, "no afterimage after exit %d" % exit)
		Dreams.afterimage_shown.disconnect(on_shown)
	await c.tree.create_timer(Dreams.FADE_SECONDS + 0.1).timeout
	Dreams.in_dream = true

	# The test dream has the ring seal in place of the old one.
	var dream := (load(TEST_DREAM) as PackedScene).instantiate()
	c.is_true(dream.get_node(^"Seal") is DreamSealRings, "the test dream has the seal of rings")
	dream.free()
	Dreams.in_dream = false
	Dreams.module_id = &""
	Dreams.seal_restored = false
	GameState.reset()


func _seal(c: OpeningCheck, with_art := false) -> DreamSealRings:
	var seal := (load(SEAL) as PackedScene).instantiate() as DreamSealRings
	seal.knowledge_id = KNOWLEDGE
	if with_art:
		seal.radius = 4.0
		seal.art = load(SEAL_ART) as PackedScene
		seal.wheel_art = load(WHEEL_ART) as PackedScene
	c.add(seal)
	return seal
