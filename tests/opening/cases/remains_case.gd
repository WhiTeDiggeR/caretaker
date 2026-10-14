extends RefCounted

## #186: the remains by the first fight in Bowser's dream — the chain sleeps until the ambush,
## then the chain, the brazier, a ring from the niche and the death trace answer at once; the
## safety hint comes after a timeout or a resolve below half, never once the chain is taken;
## taking the chain gives its image and the one-time strike hint.

const BOWSER_DREAM := "res://scenes/dreams/bowser_dream.tscn"
const BEFORE_LINE := Vector3(52.0, 1.3, 0.0)
const PAST_LINE := Vector3(58.0, 1.3, 0.0)


func run(c: OpeningCheck) -> void:
	Dreams.seal_restored = false
	var rings := [0]
	var count_ring := func(id: StringName) -> void:
		if id == DreamRemains.RING_SOUND:
			rings[0] += 1
	Sfx.requested.connect(count_ring)

	# A: the chain sleeps, the ambush wakes it, the timer safety net fires, the chain is taken.
	var dream := await _open(c)
	var remains := dream.get_node(BowserDream.REMAINS) as DreamRemains
	var ambush := dream.get_node(^"Yard/Ambush") as DreamAmbush
	var hero := dream.get_node(^"Player") as Node3D
	var pickup := remains.pickup
	c.is_true(remains != null and ambush != null, "the remains and the ambush are wired in the yard")
	c.is_true(pickup.dormant and not pickup.awake and not pickup.is_processing(), "the chain lies dormant, no glow or spin")
	c.equal(pickup.interactable.prompt, "ВЗЯТЬ: ЦЕПЬ С ГРУЗОМ", "the chain's prompt")
	c.is_true(not pickup.interactable.prompt.contains("ОРУЖ"), "the prompt does not say «weapon»")
	var inspect := remains.get_node(^"Body/Inspect/Interactable") as Interactable
	c.is_true(inspect != null and inspect.mode == Interactable.Mode.INSPECT and inspect.prompt == DreamRemains.INSPECT_PROMPT, "the remains can be inspected")
	c.is_true(DocumentLibrary.has(inspect.inspect_text_id) and not bool(DocumentLibrary.get_document(inspect.inspect_text_id).get("journal", true)), "the inspect text is data, outside the journal")
	var note := dream.get_node(^"Yard/Remains/Note") as DocumentPickup
	c.is_true(note != null and DocumentLibrary.has(note.document_id) and bool(DocumentLibrary.get_document(note.document_id).get("journal", true)), "the predecessor's note is a journal document")
	c.is_true(not remains.brazier_light.visible, "the brazier is cold before the ambush")
	c.is_true(remains.get_node(remains.death_trace) is MeshInstance3D, "the death trace lies by the wake line")
	remains.echo_seconds = 0.5
	hero.global_position = BEFORE_LINE
	await c.physics_frames(20)
	c.is_true(not ambush.started and not remains.is_awake, "nothing answers before the wake line")
	hero.global_position = PAST_LINE
	await c.physics_frames(3)
	c.is_true(ambush.started, "the wake line (along +X in the yard) starts the ambush")
	c.is_true(remains.is_awake and pickup.awake, "the ambush wakes the chain")
	c.is_true(remains.brazier_light.visible, "the brazier lights with the ambush")
	c.equal(rings[0], 1, "a ring sounds from the niche once")
	c.is_true((remains.get_node(remains.death_trace) as GeometryInstance3D).material_override != null, "the death trace glows white")
	c.is_true(not remains.echo_shown, "no safety hint at once")
	await c.tree.create_timer(0.7).timeout
	c.is_true(remains.echo_shown and _requested(DreamRemains.ECHO_HINT), "the safety hint comes after the timeout")
	var combat := c.tree.get_first_node_in_group(DreamCombat.GROUP) as DreamCombat
	combat.expel = func() -> void: pass
	pickup.take()
	await c.physics_frames(2)
	c.is_true(combat.weapons.has(&"dream_chain") and remains.weapon_taken, "taking the chain gives its image")
	c.equal(DreamCombatData.weapon(&"dream_chain").get("damage"), 34.0, "the chain strikes like the dream blade (34)")
	c.is_true(_requested(&"dream_strike"), "the strike hint follows the chain")
	await _close(c, dream)

	# B: the resolve safety net.
	Hints._queue.clear()
	dream = await _open(c)
	remains = dream.get_node(BowserDream.REMAINS) as DreamRemains
	combat = c.tree.get_first_node_in_group(DreamCombat.GROUP) as DreamCombat
	combat.expel = func() -> void: pass
	(dream.get_node(^"Player") as Node3D).global_position = PAST_LINE
	await c.physics_frames(3)
	combat.take_damage(40.0, PAST_LINE + Vector3.FORWARD)
	c.is_true(not remains.echo_shown, "resolve above half: no hint yet")
	combat.take_damage(15.0, PAST_LINE + Vector3.FORWARD)
	c.is_true(remains.echo_shown, "resolve below half brings the safety hint")
	await _close(c, dream)

	# C: a chain taken before the ambush needs no safety net.
	dream = await _open(c)
	remains = dream.get_node(BowserDream.REMAINS) as DreamRemains
	combat = c.tree.get_first_node_in_group(DreamCombat.GROUP) as DreamCombat
	combat.expel = func() -> void: pass
	remains.echo_seconds = 0.2
	remains.pickup.take()
	(dream.get_node(^"Player") as Node3D).global_position = PAST_LINE
	await c.physics_frames(3)
	combat.take_damage(60.0, PAST_LINE + Vector3.FORWARD)
	await c.tree.create_timer(0.4).timeout
	c.is_true(remains.is_awake and not remains.echo_shown, "no safety hint once the chain is taken")
	await _close(c, dream)
	Sfx.requested.disconnect(count_ring)
	Hints._queue.clear()


func _open(c: OpeningCheck) -> Node3D:
	var dream := (load(BOWSER_DREAM) as PackedScene).instantiate() as Node3D
	c.add(dream)
	await c.physics_frames(3)
	return dream


func _close(c: OpeningCheck, dream: Node3D) -> void:
	dream.queue_free()
	await c.physics_frames(2)


func _requested(id: StringName) -> bool:
	return Hints._queue.has(id) or Hints.was_shown(id)
