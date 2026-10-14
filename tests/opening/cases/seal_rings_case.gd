extends RefCounted

## #183: the seal of three rings (B-7, B-10) — positions from the DreamKnowledge code, a wrong
## turn without effect, the aligned rings restore the seal with the same glyphs, the dream
## remembers the rings.

const SEAL := "res://objects/dream/dream_seal_rings.tscn"
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
	c.is_true(code.size() == DreamSealRings.RING_COUNT and not DreamKnowledge.has(KNOWLEDGE), "three glyphs, not yet remembered")
	for ring in DreamSealRings.RING_COUNT:
		c.equal(seal.ring_glyphs(ring).size(), DreamSealRings.POSITIONS, "ring %d has six positions" % ring)
		c.equal(seal.ring_glyphs(ring)[seal.correct_position(ring)], code[ring], "ring %d is right with its code glyph under the mark" % ring)
		c.is_true(not seal.is_ring_aligned(ring), "ring %d starts off its place" % ring)
	c.equal(seal.levers.size(), DreamSealRings.RING_COUNT, "a lever per ring")

	# #194: the glyph inside its image stays muted until its ring comes into place.
	for ring in DreamSealRings.RING_COUNT:
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
	for ring in DreamSealRings.RING_COUNT:
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

	# The test dream has the ring seal in place of the old one.
	var dream := (load(TEST_DREAM) as PackedScene).instantiate()
	c.is_true(dream.get_node(^"Seal") is DreamSealRings, "the test dream has the seal of rings")
	dream.free()
	Dreams.in_dream = false
	Dreams.module_id = &""
	Dreams.seal_restored = false
	GameState.reset()


func _seal(c: OpeningCheck) -> DreamSealRings:
	var seal := (load(SEAL) as PackedScene).instantiate() as DreamSealRings
	seal.knowledge_id = KNOWLEDGE
	c.add(seal)
	return seal
